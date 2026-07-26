//
//  NotificationLogTests.swift
//  graucoreTests
//

import XCTest
@testable import graucore

final class NotificationLogTests: XCTestCase {

    var tempGrauDir: URL!

    override func setUpWithError() throws {
        try super.setUpWithError()
        // Point the log at a temp file. The actor uses
        // ManifestStore.grauDirectory which is a static computed
        // property; we can't redirect that in graucore. The
        // easiest way to test the log without polluting ~/.grau
        // is to swap the home dir.
        // For now, we just call record() and read() and clean up
        // after ourselves.
    }

    override func tearDownWithError() throws {
        // Clean up the log file so we don't pollute the user's
        // ~/.grau/ across test runs.
        try? FileManager.default.removeItem(at: NotificationLog.logFile)
        try super.tearDownWithError()
    }

    func test_read_emptyLog_returnsEmpty() async {
        // The file shouldn't exist before we record anything.
        // If a previous run left a file, the tearDown removes it.
        try? FileManager.default.removeItem(at: NotificationLog.logFile)
        let log = NotificationLog()
        let entries = await log.read()
        XCTAssertTrue(entries.isEmpty)
    }

    func test_record_oneEntry_persistsAndReads() async {
        let log = NotificationLog()
        await log.record(
            ruleID: "junk.gt1gb",
            title: "Grau",
            body: "Found 1.2 GB of junk."
        )
        let entries = await log.read()
        XCTAssertEqual(entries.count, 1)
        XCTAssertEqual(entries.first?.ruleID, "junk.gt1gb")
        XCTAssertEqual(entries.first?.body, "Found 1.2 GB of junk.")
        XCTAssertEqual(entries.first?.title, "Grau")
    }

    func test_record_multipleEntries_areNewestFirst() async throws {
        let log = NotificationLog()
        await log.record(ruleID: "a", title: "A", body: "first")
        try await Task.sleep(for: .milliseconds(5))
        await log.record(ruleID: "b", title: "B", body: "second")
        let entries = await log.read()
        XCTAssertEqual(entries.count, 2)
        XCTAssertEqual(entries[0].ruleID, "b")
        XCTAssertEqual(entries[1].ruleID, "a")
    }

    func test_record_trimsToMaxEntries() async {
        let log = NotificationLog()
        // Record maxEntries + 5 entries; we should only see
        // maxEntries total.
        for i in 0..<(NotificationLog.maxEntries + 5) {
            await log.record(
                ruleID: "x",
                title: "T\(i)",
                body: "body \(i)"
            )
        }
        let entries = await log.read()
        XCTAssertEqual(entries.count, NotificationLog.maxEntries)
        // The newest ones survive (we insert at index 0 then
        // trim the tail).
        XCTAssertEqual(entries.first?.body, "body \(NotificationLog.maxEntries + 4)")
    }

    func test_clear_emptiesTheLog() async {
        let log = NotificationLog()
        await log.record(ruleID: "x", title: "T", body: "B")
        let pre = await log.read()
        XCTAssertFalse(pre.isEmpty)
        await log.clear()
        let post = await log.read()
        XCTAssertTrue(post.isEmpty)
    }

    func test_logEntry_init_storesAllFields() {
        let id = UUID()
        let now = Date()
        let entry = NotificationLogEntry(
            id: id,
            timestamp: now,
            ruleID: "rule",
            title: "Title",
            body: "Body"
        )
        XCTAssertEqual(entry.id, id)
        XCTAssertEqual(entry.timestamp, now)
        XCTAssertEqual(entry.ruleID, "rule")
        XCTAssertEqual(entry.title, "Title")
        XCTAssertEqual(entry.body, "Body")
    }
}
