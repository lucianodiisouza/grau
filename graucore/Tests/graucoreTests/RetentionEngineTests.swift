//
//  RetentionEngineTests.swift
//  graucoreTests
//

import XCTest
@testable import graucore

final class RetentionEngineTests: XCTestCase {

    private let fm = FileManager.default
    private let manifestDir = TrashMover.defaultManifestDirectory
    private let stateFile = ManifestStore.stateFile
    private let logFile = NotificationLog.logFile
    private let policyFile = RetentionPolicyStore.policyFile

    override func setUp() {
        // Snapshot any existing files so we can restore them after
        // the test (the engine reads/writes ~/.grau/ in place).
        snapshotAndRemove(logFile)
        snapshotAndRemove(stateFile)
        snapshotAndRemove(policyFile)
        if fm.fileExists(atPath: manifestDir.path) {
            snapshotAndRemoveDir(manifestDir)
        }
    }

    override func tearDown() {
        restoreIfSnapshot(logFile)
        restoreIfSnapshot(stateFile)
        restoreIfSnapshot(policyFile)
        if fm.fileExists(atPath: manifestDir.path) {
            try? fm.removeItem(at: manifestDir)
        }
        restoreIfSnapshotDir(manifestDir)
    }

    // MARK: - pruneNotificationLog

    func test_pruneNotificationLog_dropsEntriesOlderThanCutoff() async {
        let log = NotificationLog()
        let old = Date().addingTimeInterval(-100 * 86_400)
        let recent = Date().addingTimeInterval(-5 * 86_400)
        await log.record(
            ruleID: "old",
            title: "Old",
            body: "x",
            timestamp: old
        )
        await log.record(
            ruleID: "new",
            title: "New",
            body: "y",
            timestamp: recent
        )
        let engine = RetentionEngine()
        let cutoff = Date().addingTimeInterval(-30 * 86_400)
        let removed = await engine.pruneNotificationLog(olderThan: cutoff)
        XCTAssertEqual(removed, 1)
        let remaining = await log.read()
        XCTAssertEqual(remaining.count, 1)
        XCTAssertEqual(remaining.first?.ruleID, "new")
    }

    func test_pruneNotificationLog_returnsZeroWhenAllKept() async {
        let log = NotificationLog()
        await log.record(ruleID: "new", title: "New", body: "x")
        let engine = RetentionEngine()
        let removed = await engine.pruneNotificationLog(olderThan: Date.distantPast)
        XCTAssertEqual(removed, 0)
    }

    // MARK: - pruneTrashManifests

    func test_pruneTrashManifests_removesFilesOlderThanCutoff() async {
        // Write two manifest files: one old, one recent.
        try? fm.createDirectory(at: manifestDir, withIntermediateDirectories: true)
        let old = makeManifestJSON(
            id: UUID(),
            timestamp: Date().addingTimeInterval(-100 * 86_400),
            kind: "junk",
            items: 0
        )
        let recent = makeManifestJSON(
            id: UUID(),
            timestamp: Date().addingTimeInterval(-5 * 86_400),
            kind: "junk",
            items: 0
        )
        try? old.data.write(to: manifestDir.appendingPathComponent(old.filename))
        try? recent.data.write(to: manifestDir.appendingPathComponent(recent.filename))
        let engine = RetentionEngine()
        let cutoff = Date().addingTimeInterval(-30 * 86_400)
        let removed = await engine.pruneTrashManifests(olderThan: cutoff)
        XCTAssertEqual(removed, 1)
        let remaining = try? fm.contentsOfDirectory(at: manifestDir, includingPropertiesForKeys: nil)
        XCTAssertEqual(remaining?.count, 1)
    }

    func test_pruneTrashManifests_returnsZeroWhenNoneExpired() async {
        try? fm.createDirectory(at: manifestDir, withIntermediateDirectories: true)
        let recent = makeManifestJSON(
            id: UUID(),
            timestamp: Date(),
            kind: "junk",
            items: 0
        )
        try? recent.data.write(to: manifestDir.appendingPathComponent(recent.filename))
        let engine = RetentionEngine()
        let removed = await engine.pruneTrashManifests(olderThan: Date.distantPast)
        XCTAssertEqual(removed, 0)
    }

    // MARK: - pruneScanHistory

    func test_pruneScanHistory_dropsEntriesOlderThanCutoff() async {
        let old = LastScanSummary(
            kind: "junk",
            totalBytes: 1024,
            itemCount: 1,
            finishedAt: Date().addingTimeInterval(-100 * 86_400)
        )
        let recent = LastScanSummary(
            kind: "junk",
            totalBytes: 2048,
            itemCount: 2,
            finishedAt: Date().addingTimeInterval(-5 * 86_400)
        )
        var state = StateFile()
        state.scanHistory = [old, recent]
        let store = ManifestStore()
        try? store.write(state, to: stateFile)

        let engine = RetentionEngine()
        let cutoff = Date().addingTimeInterval(-30 * 86_400)
        let removed = await engine.pruneScanHistory(olderThan: cutoff)
        XCTAssertEqual(removed, 1)
        let reloaded = try? store.read(StateFile.self, from: stateFile)
        XCTAssertEqual(reloaded?.scanHistory.count, 1)
        XCTAssertEqual(reloaded?.scanHistory.first?.itemCount, 2)
    }

    // MARK: - apply (full)

    func test_apply_skipsKindsSetToForever() async {
        // Default policy has scanHistory = 0 (forever). Recording
        // a very old scan should NOT be pruned by apply().
        let ancient = LastScanSummary(
            kind: "junk",
            totalBytes: 0,
            itemCount: 0,
            finishedAt: Date().addingTimeInterval(-365 * 86_400)
        )
        var state = StateFile()
        state.scanHistory = [ancient]
        let store = ManifestStore()
        try? store.write(state, to: stateFile)

        let engine = RetentionEngine()
        let report = await engine.apply(policy: .default, now: Date())
        XCTAssertEqual(report.removedScanHistoryEntries, 0)
    }

    func test_apply_reportsAllKinds() async {
        // Set up: one old notification, one old manifest, one old scan
        // with the corresponding policy set to 1 day.
        let log = NotificationLog()
        await log.record(
            ruleID: "old",
            title: "Old",
            body: "x",
            timestamp: Date().addingTimeInterval(-10 * 86_400)
        )

        try? fm.createDirectory(at: manifestDir, withIntermediateDirectories: true)
        let oldManifest = makeManifestJSON(
            id: UUID(),
            timestamp: Date().addingTimeInterval(-10 * 86_400),
            kind: "junk",
            items: 0
        )
        try? oldManifest.data.write(to: manifestDir.appendingPathComponent(oldManifest.filename))

        var state = StateFile()
        state.scanHistory = [LastScanSummary(
            kind: "junk",
            totalBytes: 0,
            itemCount: 0,
            finishedAt: Date().addingTimeInterval(-10 * 86_400)
        )]
        let store = ManifestStore()
        try? store.write(state, to: stateFile)

        let policy = RetentionPolicy()
            .setting(RetentionWindow(kind: .notificationLog, days: 1))
            .setting(RetentionWindow(kind: .trashManifest, days: 1))
            .setting(RetentionWindow(kind: .scanHistory, days: 1))

        let engine = RetentionEngine()
        let report = await engine.apply(policy: policy, now: Date())
        XCTAssertEqual(report.removedNotificationEntries, 1)
        XCTAssertEqual(report.removedTrashManifests, 1)
        XCTAssertEqual(report.removedScanHistoryEntries, 1)
        XCTAssertEqual(report.totalRemoved, 3)
    }

    // MARK: - RetentionPolicyStore

    func test_policyStore_returnsDefaultWhenFileMissing() async {
        let store = RetentionPolicyStore()
        let policy = await store.read()
        XCTAssertEqual(policy, .default)
    }

    func test_policyStore_writesAndReads() async throws {
        let store = RetentionPolicyStore()
        let policy = RetentionPolicy.default
            .setting(RetentionWindow(kind: .notificationLog, days: 14))
        try await store.write(policy)
        let reloaded = await store.read()
        XCTAssertEqual(reloaded.days(for: .notificationLog), 14)
    }

    func test_policyStore_update_appliesTransform() async throws {
        let store = RetentionPolicyStore()
        let final = try await store.update { policy in
            policy.setting(RetentionWindow(kind: .scanHistory, days: 365))
        }
        XCTAssertEqual(final.days(for: .scanHistory), 365)
        let reloaded = await store.read()
        XCTAssertEqual(reloaded.days(for: .scanHistory), 365)
    }

    // MARK: - Helpers

    private struct Snapshot {
        let original: URL?
        let contents: Data?
    }

    private var snapshots: [URL: Snapshot] = [:]

    private func snapshotAndRemove(_ url: URL) {
        let original: URL? = nil  // we don't snapshot directories here
        let contents: Data? = fm.fileExists(atPath: url.path)
            ? (try? Data(contentsOf: url))
            : nil
        snapshots[url] = Snapshot(original: original, contents: contents)
        try? fm.removeItem(at: url)
    }

    private func restoreIfSnapshot(_ url: URL) {
        guard let snap = snapshots[url] else { return }
        if let data = snap.contents {
            try? ManifestStore.ensureGrauDirectory()
            try? data.write(to: url)
        }
        snapshots.removeValue(forKey: url)
    }

    private func snapshotAndRemoveDir(_ dir: URL) {
        let snap = (try? Data(contentsOf: dir.appendingPathComponent(".dummy-snapshot")))
        if snap != nil {
            try? fm.removeItem(at: dir.appendingPathComponent(".dummy-snapshot"))
        }
        snapshots[dir] = Snapshot(original: nil, contents: nil)
        // Save the dir by renaming it aside.
        let backup = dir.deletingLastPathComponent()
            .appendingPathComponent("grau-test-backup-\(UUID().uuidString)", isDirectory: true)
        try? fm.moveItem(at: dir, to: backup)
        snapshots[dir] = Snapshot(original: backup, contents: nil)
    }

    private func restoreIfSnapshotDir(_ dir: URL) {
        guard let snap = snapshots[dir], let backup = snap.original else { return }
        try? fm.removeItem(at: dir)
        try? fm.moveItem(at: backup, to: dir)
        snapshots.removeValue(forKey: dir)
    }

    /// Build a JSON-serialised TrashManifest file pair (data + filename).
    private func makeManifestJSON(
        id: UUID,
        timestamp: Date,
        kind: String,
        items: Int
    ) -> (data: Data, filename: String) {
        let manifest = TrashManifest(
            id: id,
            timestamp: timestamp,
            kind: kind,
            totalSize: 0,
            items: (0..<items).map { i in
                TrashManifestItem(
                    originalPath: "/tmp/\(i)",
                    trashRelativePath: "f\(i)",
                    size: 1
                )
            }
        )
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = (try? encoder.encode(manifest)) ?? Data()
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        let ts = formatter.string(from: timestamp).replacingOccurrences(of: ":", with: "-")
        return (data, "\(ts)-\(kind).json")
    }
}
