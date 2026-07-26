//
//  NotificationCoordinator.swift
//  grau
//
//  Smart notifications with state-transition dedupe.
//  See docs/PERMISSIONS.md § 3.3.1.
//

import Foundation
import Observation
import UserNotifications
import graucore

/// Rule IDs. The string is used as a UserDefaults key suffix.
public enum NotificationRuleID: String, CaseIterable {
    case junkGt1GB = "junk.gt1gb"
    case diskFull90 = "disk.full.90"
    case trashFull5GB = "trash.full.5gb"

    public var defaultEnabled: Bool {
        switch self {
        case .junkGt1GB, .diskFull90: return true
        case .trashFull5GB: return false
        }
    }
}

@MainActor
@Observable
final class NotificationCoordinator {
    private let volumeMonitor: VolumeMonitor
    private let trashReader: TrashInfoReader
    private let log: NotificationLog
    private var monitorTask: Task<Void, Never>?

    /// Thresholds in bytes (or fractions, for disk).
    private let junkThreshold: Int64 = 1_000_000_000      // 1 GB
    private let trashThreshold: Int64 = 5_000_000_000     // 5 GB
    private let diskThresholdFraction: Double = 0.90      // 90%

    init(
        volumeMonitor: VolumeMonitor = VolumeMonitor(),
        trashReader: TrashInfoReader = TrashInfoReader(),
        log: NotificationLog = NotificationLog()
    ) {
        self.volumeMonitor = volumeMonitor
        self.trashReader = trashReader
        self.log = log
    }

    func requestAuthorizationIfNeeded() async {
        do {
            try await UNUserNotificationCenter.current()
                .requestAuthorization(options: [.alert, .sound, .badge])
        } catch {
            // User declined or system error. Notifications silently off.
        }
    }

    func start(interval: TimeInterval = 6 * 60 * 60) {  // 6h
        monitorTask?.cancel()
        monitorTask = Task { [weak self] in
            await self?.requestAuthorizationIfNeeded()
            while !Task.isCancelled {
                await self?.evaluate()
                try? await Task.sleep(for: .seconds(interval))
            }
        }
    }

    func stop() {
        monitorTask?.cancel()
        monitorTask = nil
    }

    /// Called by JunkCleanerViewModel when a scan completes.
    func notifyJunkScanResult(totalBytes: Int64) async {
        guard isEnabled(.junkGt1GB) else { return }
        let previous = lastValue(for: .junkGt1GB) ?? 0
        let now = Double(totalBytes)
        // Fire when crossing UP through 1 GB
        if previous < Double(junkThreshold) && now >= Double(junkThreshold) {
            await fire(
                id: .junkGt1GB,
                title: "Grau",
                body: "Found \(ByteSize(bytes: totalBytes).humanReadable) of cleanable junk.",
                value: now
            )
        } else {
            recordValue(.junkGt1GB, value: now)
        }
    }

    private func evaluate() async {
        // Disk usage
        let volumes = await volumeMonitor.currentVolumes()
        if let root = volumes.first(where: { $0.url.path == "/" }) {
            let fraction = root.usageFraction
            if isEnabled(.diskFull90) {
                let previous = lastValue(for: .diskFull90) ?? 0
                if previous < diskThresholdFraction && fraction >= diskThresholdFraction {
                    await fire(
                        id: .diskFull90,
                        title: "Grau",
                        body: "Your disk is \(Int(fraction * 100))% full.",
                        value: fraction
                    )
                } else {
                    recordValue(.diskFull90, value: fraction)
                }
            }
        }
        // Trash size
        if isEnabled(.trashFull5GB) {
            let trash = trashReader.read()
            let bytes = Double(trash.size.bytes)
            let previous = lastValue(for: .trashFull5GB) ?? 0
            if previous < Double(trashThreshold) && bytes >= Double(trashThreshold) {
                await fire(
                    id: .trashFull5GB,
                    title: "Grau",
                    body: "Trash has \(trash.size.humanReadable) waiting.",
                    value: bytes
                )
            } else {
                recordValue(.trashFull5GB, value: bytes)
            }
        }
    }

    // MARK: - Rule state (UserDefaults)

    private func isEnabled(_ id: NotificationRuleID) -> Bool {
        let key = "grau.rule.\(id.rawValue).enabled"
        if UserDefaults.standard.object(forKey: key) == nil {
            return id.defaultEnabled
        }
        return UserDefaults.standard.bool(forKey: key)
    }

    private func lastValue(for id: NotificationRuleID) -> Double? {
        let key = "grau.rule.\(id.rawValue).lastValue"
        guard UserDefaults.standard.object(forKey: key) != nil else { return nil }
        return UserDefaults.standard.double(forKey: key)
    }

    private func recordValue(_ id: NotificationRuleID, value: Double) {
        let key = "grau.rule.\(id.rawValue).lastValue"
        UserDefaults.standard.set(value, forKey: key)
    }

    private func recordFired(_ id: NotificationRuleID) {
        let key = "grau.rule.\(id.rawValue).lastFiredAt"
        UserDefaults.standard.set(Date(), forKey: key)
    }

    // MARK: - Firing

    private func fire(
        id: NotificationRuleID,
        title: String,
        body: String,
        value: Double
    ) async {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        let request = UNNotificationRequest(
            identifier: "grau.\(id.rawValue).\(UUID().uuidString)",
            content: content,
            trigger: nil  // immediate
        )
        do {
            try await UNUserNotificationCenter.current().add(request)
            recordFired(id)
            recordValue(id, value: value)
            // Also append to the persistent log so the in-app
            // Notification Center can show past entries.
            await log.record(ruleID: id.rawValue, title: title, body: body)
        } catch {
            // Ignore; no auth or system error.
        }
    }
}
