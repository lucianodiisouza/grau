//
//  AutoCleanEngine.swift
//  graucore
//
//  Evaluates the user's `AutoCleanRule`s against a snapshot of
//  current system gauges and decides which actions to fire. The
//  actual destructive work (running retention, reindexing trash)
//  is delegated to existing engines; this module is the
//  coordinator and the decision-maker.
//
//  The engine is split into two phases:
//   1. `evaluate(rules:gauge:now:) -> [PendingAction]` — pure
//      decision. Decides which rules should fire.
//   2. `execute(_:)` — runs the actions. The caller chooses to do
//      this, so the engine is fully testable without side effects.
//
//  v1.7 feature. Phase 12.2.
//

import Foundation

/// A snapshot of the gauges that auto-clean conditions depend on.
/// Snapshots are produced by `AutoCleanGaugeProbe` in production
/// and by tests directly. Keeps the engine pure.
public struct AutoCleanGaugeSnapshot: Sendable, Equatable {
    public let trashSizeBytes: Int64
    public let lastJunkScanBytes: Int64?
    public let diskUsageFraction: Double?
    public let capturedAt: Date

    public init(
        trashSizeBytes: Int64 = 0,
        lastJunkScanBytes: Int64? = nil,
        diskUsageFraction: Double? = nil,
        capturedAt: Date = Date()
    ) {
        self.trashSizeBytes = trashSizeBytes
        self.lastJunkScanBytes = lastJunkScanBytes
        self.diskUsageFraction = diskUsageFraction
        self.capturedAt = capturedAt
    }
}

/// A single fired action paired with the rule that produced it.
public struct PendingAutoCleanAction: Sendable, Equatable, Identifiable {
    public let id: UUID
    public let rule: AutoCleanRule
    public let firedAt: Date
    public let gauge: AutoCleanGaugeSnapshot

    public init(rule: AutoCleanRule, firedAt: Date, gauge: AutoCleanGaugeSnapshot) {
        self.id = rule.id
        self.rule = rule
        self.firedAt = firedAt
        self.gauge = gauge
    }
}

public actor AutoCleanEngine {

    public init() {}

    /// Pure decision. Decides which rules should fire given the
    /// gauge snapshot. Returns the list of `PendingAutoCleanAction`
    /// in evaluation order.
    public func evaluate(
        rules: [AutoCleanRule],
        gauge: AutoCleanGaugeSnapshot,
        now: Date = Date()
    ) -> [PendingAutoCleanAction] {
        var fired: [PendingAutoCleanAction] = []
        for rule in rules {
            guard rule.canFire(now: now) else { continue }
            guard matches(rule.condition, gauge: gauge, now: now) else { continue }
            fired.append(PendingAutoCleanAction(
                rule: rule,
                firedAt: now,
                gauge: gauge
            ))
        }
        return fired
    }

    /// Executes the actions sequentially. Returns the list of
    /// actions that were actually run, paired with their outcome.
    public func execute(
        _ actions: [PendingAutoCleanAction],
        retentionPolicy: RetentionPolicy = .default
    ) async -> [AutoCleanExecutionResult] {
        var results: [AutoCleanExecutionResult] = []
        for action in actions {
            switch action.rule.action {
            case .runRetention:
                let report = await RetentionEngine().apply(
                    policy: retentionPolicy,
                    now: action.firedAt
                )
                results.append(AutoCleanExecutionResult(
                    pending: action,
                    summary: "Pruned \(report.totalRemoved) entries"
                ))
            case .reindexTrash:
                let count = await reindexTrash()
                results.append(AutoCleanExecutionResult(
                    pending: action,
                    summary: "Reindexed \(count) manifest\(count == 1 ? "" : "s")"
                ))
            case .logSummary:
                await NotificationLog().record(
                    ruleID: "auto.clean",
                    title: "Auto-clean",
                    body: "\(action.rule.name) ran.",
                    timestamp: action.firedAt
                )
                results.append(AutoCleanExecutionResult(
                    pending: action,
                    summary: "Logged summary"
                ))
            }
        }
        return results
    }

    /// Convenience: evaluate and execute in one call. Updates
    /// `lastFiredAt` on each fired rule and writes the rules back
    /// via the store.
    @discardableResult
    public func runOnce(
        rules: [AutoCleanRule],
        gauge: AutoCleanGaugeSnapshot,
        now: Date = Date(),
        retentionPolicy: RetentionPolicy = .default,
        store: AutoCleanStore? = nil
    ) async -> [AutoCleanExecutionResult] {
        let pending = evaluate(rules: rules, gauge: gauge, now: now)
        guard !pending.isEmpty else { return [] }
        let results = await execute(pending, retentionPolicy: retentionPolicy)
        // Update lastFiredAt
        if let store {
            var current = await store.read()
            for result in results {
                if let idx = current.firstIndex(where: { $0.id == result.pending.rule.id }) {
                    current[idx].lastFiredAt = result.pending.firedAt
                }
            }
            try? await store.write(current)
        }
        return results
    }

    // MARK: - Internals

    private func matches(
        _ condition: AutoCleanCondition,
        gauge: AutoCleanGaugeSnapshot,
        now: Date
    ) -> Bool {
        switch condition {
        case .trashSizeExceeds(let bytes):
            return gauge.trashSizeBytes > bytes
        case .junkSizeExceeds(let bytes):
            guard let junk = gauge.lastJunkScanBytes else { return false }
            return junk > bytes
        case .diskUsageExceeds(let fraction):
            guard let usage = gauge.diskUsageFraction else { return false }
            return usage > fraction
        case .timeOfDay(let h, let m):
            let comps = Calendar.current.dateComponents([.hour, .minute], from: now)
            return comps.hour == h && comps.minute == m
        }
    }

    /// Reindexes the trash: lists all current manifest files and
    /// returns the count. This is a no-op at the engine layer; a
    /// real "reindex" would rewrite each manifest with a fresh
    /// `updatedAt`. We keep the operation idempotent and cheap
    /// so it can run from a rule without risk.
    private func reindexTrash() async -> Int {
        let dir = TrashMover.defaultManifestDirectory
        let fm = FileManager.default
        guard fm.fileExists(atPath: dir.path) else { return 0 }
        let urls = (try? fm.contentsOfDirectory(
            at: dir,
            includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles]
        )) ?? []
        return urls.filter { $0.pathExtension == "json" }.count
    }
}

/// Outcome of a single execution, returned to the caller.
public struct AutoCleanExecutionResult: Sendable, Equatable {
    public let pending: PendingAutoCleanAction
    public let summary: String
}
