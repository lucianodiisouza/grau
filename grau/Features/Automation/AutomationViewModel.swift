//
//  AutomationViewModel.swift
//  grau
//
//  Wires the Automation tab UI to the retention + auto-clean
//  engines in graucore. Exposes the user's policy, the rules,
//  and a "Run now" button that fires every enabled rule with
//  the live gauge snapshot.
//
//  v1.7 feature. Phase 12.
//

import Foundation
import Observation
import graucore

@MainActor
@Observable
final class AutomationViewModel {

    private(set) var policy: RetentionPolicy = .default
    private(set) var rules: [AutoCleanRule] = []
    private(set) var lastReport: RetentionReport?
    private(set) var lastExecution: [AutoCleanExecutionResult] = []
    private(set) var isRunning: Bool = false
    var errorMessage: String?

    private let policyStore = RetentionPolicyStore()
    private let ruleStore = AutoCleanStore()
    private let retentionEngine = RetentionEngine()
    private let autoCleanEngine = AutoCleanEngine()

    init() {}

    /// Reads policy + rules from disk. Called on view appear and
    /// after every mutation.
    func refresh() async {
        policy = await policyStore.read()
        rules = await ruleStore.read()
    }

    // MARK: - Retention

    /// Updates a single retention window. Persists immediately.
    func setRetention(_ days: Int, for kind: RetentionKind) async {
        let window = RetentionWindow(kind: kind, days: days)
        policy = policy.setting(window)
        do {
            try await policyStore.write(policy)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    /// Resets a single kind to its default.
    func resetRetention(for kind: RetentionKind) async {
        policy = policy.clearing(kind)
        do {
            try await policyStore.write(policy)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    /// Runs the retention engine with the current policy and
    /// reports the result. Updates `lastReport`.
    func runRetentionNow() async {
        isRunning = true
        defer { isRunning = false }
        lastReport = await retentionEngine.apply(policy: policy)
    }

    // MARK: - Auto-clean rules

    func addRule(_ rule: AutoCleanRule) async {
        rules = (try? await ruleStore.add(rule)) ?? rules
    }

    func updateRule(_ rule: AutoCleanRule) async {
        rules = (try? await ruleStore.upsert(rule)) ?? rules
    }

    func toggleRule(_ rule: AutoCleanRule, enabled: Bool) async {
        var copy = rule
        copy.enabled = enabled
        await updateRule(copy)
    }

    func deleteRule(id: UUID) async {
        rules = (try? await ruleStore.remove(id: id)) ?? rules
    }

    /// Runs every enabled rule whose condition is met. Updates
    /// `lastExecution` with the results.
    func runAutoCleanNow() async {
        isRunning = true
        defer { isRunning = false }
        let gauge = await liveGauge()
        lastExecution = await autoCleanEngine.runOnce(
            rules: rules,
            gauge: gauge,
            retentionPolicy: policy,
            store: ruleStore
        )
        // Refresh rules to pick up updated `lastFiredAt`.
        rules = await ruleStore.read()
    }

    /// Captures the current system gauges. Used by `runAutoCleanNow`.
    /// Falls back to "no data" (gauge: 0) if the probe fails so the
    /// rule still has something to evaluate.
    private func liveGauge() async -> AutoCleanGaugeSnapshot {
        let trashReader = TrashInfoReader()
        let trash = trashReader.read()
        let monitor = VolumeMonitor()
        let volumes = await monitor.currentVolumes()
        let diskFraction = volumes.first(where: { $0.url.path == "/" })?.usageFraction
        let store = ManifestStore()
        let state = try? store.read(StateFile.self, from: ManifestStore.stateFile)
        let junkBytes = state?.lastJunkScan?.totalBytes
        return AutoCleanGaugeSnapshot(
            trashSizeBytes: trash.size.bytes,
            lastJunkScanBytes: junkBytes,
            diskUsageFraction: diskFraction
        )
    }
}
