//
//  RetentionEngine.swift
//  graucore
//
//  Applies a `RetentionPolicy` to all the artifacts Grau manages:
//  notification log entries, trash manifests, and the scan history
//  in state.json. Each kind has a per-kind applier that knows how
//  to read, filter, and write its artifact back.
//
//  The engine is pure in the sense that it returns a `RetentionReport`
//  describing what was removed, and is also destructive when run as
//  `apply(_:)` — which is the only entry point a user (or an
//  AutoClean rule) should call.
//
//  Time is injectable via `now:` so tests can pin "now" without
//  monkey-patching `Date()`.
//
//  v1.7 feature. Phase 12.1.
//

import Foundation

/// A summary of what one `apply(...)` call removed. Useful for the
/// Automation UI ("Pruned 12 notification entries, 3 manifests").
public struct RetentionReport: Sendable, Equatable {
    public let removedNotificationEntries: Int
    public let removedTrashManifests: Int
    public let removedScanHistoryEntries: Int

    public static let empty = RetentionReport(
        removedNotificationEntries: 0,
        removedTrashManifests: 0,
        removedScanHistoryEntries: 0
    )

    public var totalRemoved: Int {
        removedNotificationEntries
            + removedTrashManifests
            + removedScanHistoryEntries
    }
}

public actor RetentionEngine {

    public init() {}

    /// Applies the policy to every artifact kind and returns a
    /// report. Safe to call repeatedly; the second call is a no-op
    /// if the policy hasn't changed.
    public func apply(
        policy: RetentionPolicy,
        now: Date = Date()
    ) async -> RetentionReport {
        var report = RetentionReport.empty

        // 1. Notification log
        if !policy.isForever(.notificationLog) {
            let cutoff = now.addingTimeInterval(
                -Double(policy.days(for: .notificationLog)) * 86_400
            )
            let removed = await pruneNotificationLog(olderThan: cutoff)
            report = RetentionReport(
                removedNotificationEntries: removed,
                removedTrashManifests: report.removedTrashManifests,
                removedScanHistoryEntries: report.removedScanHistoryEntries
            )
        }

        // 2. Trash manifests
        if !policy.isForever(.trashManifest) {
            let cutoff = now.addingTimeInterval(
                -Double(policy.days(for: .trashManifest)) * 86_400
            )
            let removed = await pruneTrashManifests(olderThan: cutoff)
            report = RetentionReport(
                removedNotificationEntries: report.removedNotificationEntries,
                removedTrashManifests: removed,
                removedScanHistoryEntries: report.removedScanHistoryEntries
            )
        }

        // 3. Scan history (in state.json)
        if !policy.isForever(.scanHistory) {
            let cutoff = now.addingTimeInterval(
                -Double(policy.days(for: .scanHistory)) * 86_400
            )
            let removed = await pruneScanHistory(olderThan: cutoff)
            report = RetentionReport(
                removedNotificationEntries: report.removedNotificationEntries,
                removedTrashManifests: report.removedTrashManifests,
                removedScanHistoryEntries: removed
            )
        }

        return report
    }

    // MARK: - Per-kind appliers

    /// Reads the notification log, drops entries older than `cutoff`,
    /// writes the survivors back. Returns the count of removed entries.
    public func pruneNotificationLog(olderThan cutoff: Date) async -> Int {
        let log = NotificationLog()
        let entries = await log.read()
        let kept = entries.filter { $0.timestamp >= cutoff }
        let removed = entries.count - kept.count
        if removed == 0 { return 0 }
        await log.replace(with: kept)
        return removed
    }

    /// Reads the manifests dir, deletes JSON files whose embedded
    /// timestamp is older than `cutoff`. Returns the count removed.
    public func pruneTrashManifests(olderThan cutoff: Date) async -> Int {
        let dir = TrashMover.defaultManifestDirectory
        let fm = FileManager.default
        guard fm.fileExists(atPath: dir.path) else { return 0 }
        guard let urls = try? fm.contentsOfDirectory(
            at: dir,
            includingPropertiesForKeys: [.contentModificationDateKey],
            options: [.skipsHiddenFiles]
        ) else { return 0 }

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        var removed = 0
        for url in urls where url.pathExtension == "json" {
            // Prefer the embedded timestamp over the file mtime —
            // mtime can be touched by a restore attempt.
            let timestamp: Date? = {
                guard let data = try? Data(contentsOf: url) else { return nil }
                return try? decoder.decode(TrashManifest.self, from: data).timestamp
            }()
            let date = timestamp
                ?? (try? url.resourceValues(forKeys: [.contentModificationDateKey])
                    .contentModificationDate)
                ?? Date.distantPast
            if date < cutoff {
                if (try? fm.removeItem(at: url)) != nil {
                    removed += 1
                }
            }
        }
        return removed
    }

    /// Reads state.json, drops scanHistory entries older than
    /// `cutoff`, writes it back. Returns the count removed.
    public func pruneScanHistory(olderThan cutoff: Date) async -> Int {
        let url = ManifestStore.stateFile
        let store = ManifestStore()
        guard let state = try? store.read(StateFile.self, from: url) else {
            return 0
        }
        let kept = state.scanHistory.filter { $0.finishedAt >= cutoff }
        let removed = state.scanHistory.count - kept.count
        if removed == 0 { return 0 }
        var next = state
        next.scanHistory = kept
        try? store.write(next, to: url)
        return removed
    }
}
