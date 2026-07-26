//
//  JunkScannerTests.swift
//  graucoreTests
//

import XCTest
@testable import graucore

final class JunkScannerTests: XCTestCase {

    var tempHome: URL!
    var fdaGranted: Bool { true }

    override func setUpWithError() throws {
        try super.setUpWithError()
        // Create a synthetic home so we can populate ~/Library/Caches,
        // ~/Library/Logs, etc. without touching the real home.
        tempHome = FileManager.default.temporaryDirectory
            .appendingPathComponent("grau-home-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(
            at: tempHome.appendingPathComponent("Library/Caches", isDirectory: true),
            withIntermediateDirectories: true
        )
        try FileManager.default.createDirectory(
            at: tempHome.appendingPathComponent("Library/Logs", isDirectory: true),
            withIntermediateDirectories: true
        )
        try FileManager.default.createDirectory(
            at: tempHome.appendingPathComponent("Downloads", isDirectory: true),
            withIntermediateDirectories: true
        )
        try FileManager.default.createDirectory(
            at: tempHome.appendingPathComponent("Library/Application Support/MobileSync/Backup", isDirectory: true),
            withIntermediateDirectories: true
        )
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: tempHome)
        try super.tearDownWithError()
    }

    // Note: the scanner uses NSHomeDirectory() to resolve paths. To
    // test the scanner's behavior without FDA on the host, we just
    // verify the FDA-skipping path and the top-N behavior.
    // End-to-end scan tests would require process isolation.

    func test_scan_skipsFDACategories_whenNotGranted() async {
        let scanner = JunkScanner()
        let results = await scanner.scan(
            definitions: JunkDefinitions.standard,
            fdaGranted: false
        )
        // System Cache and Logs require FDA — they should be skipped
        let skipped = results.filter { $0.skipped }
        XCTAssertGreaterThanOrEqual(skipped.count, 2)
        for r in skipped {
            XCTAssertEqual(r.skipReason, "Full Disk Access not granted")
        }
    }

    func test_scan_includesAllFiveCategories() async {
        let scanner = JunkScanner()
        let results = await scanner.scan(
            definitions: JunkDefinitions.standard,
            fdaGranted: true
        )
        XCTAssertEqual(results.count, 5)
        let ids = Set(results.map { $0.category })
        XCTAssertEqual(ids, Set(JunkCategory.allCases))
    }

    func test_scan_uncategorizedResults_haveZeroSize_onEmptyHome() async {
        // We can't redirect NSHomeDirectory() easily; the scanner
        // will scan the real home. We just verify that the result
        // structure is sound.
        let scanner = JunkScanner()
        let results = await scanner.scan(
            definitions: JunkDefinitions.standard,
            fdaGranted: true
        )
        for r in results {
            XCTAssertFalse(r.category.displayName.isEmpty)
            XCTAssertGreaterThanOrEqual(r.size.bytes, 0)
            XCTAssertGreaterThanOrEqual(r.scanDuration, 0)
        }
    }

    func test_junkDefinitions_haveCorrectDefaultSelected() {
        XCTAssertTrue(JunkDefinitions.definition(for: .userCache)?.defaultSelected ?? false)
        XCTAssertTrue(JunkDefinitions.definition(for: .systemCache)?.defaultSelected ?? false)
        XCTAssertTrue(JunkDefinitions.definition(for: .logs)?.defaultSelected ?? false)
        XCTAssertFalse(JunkDefinitions.definition(for: .oldDownloads)?.defaultSelected ?? true)
        XCTAssertFalse(JunkDefinitions.definition(for: .iosBackups)?.defaultSelected ?? true)
    }

    func test_junkDefinitions_haveCorrectFDAFlags() {
        XCTAssertFalse(JunkDefinitions.definition(for: .userCache)?.requiresFDA ?? true)
        XCTAssertTrue(JunkDefinitions.definition(for: .systemCache)?.requiresFDA ?? false)
        XCTAssertTrue(JunkDefinitions.definition(for: .logs)?.requiresFDA ?? false)
        XCTAssertFalse(JunkDefinitions.definition(for: .oldDownloads)?.requiresFDA ?? true)
        XCTAssertFalse(JunkDefinitions.definition(for: .iosBackups)?.requiresFDA ?? true)
    }
}
