//
//  ManifestStoreTests.swift
//  graucoreTests
//

import XCTest
@testable import graucore

final class ManifestStoreTests: XCTestCase {

    var tempDir: URL!

    override func setUpWithError() throws {
        try super.setUpWithError()
        tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("grau-ms-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: tempDir)
        try super.tearDownWithError()
    }

    func test_read_missing_returnsNil() throws {
        let store = ManifestStore()
        let url = tempDir.appendingPathComponent("nope.json")
        let result = try store.read(StateFile.self, from: url)
        XCTAssertNil(result)
    }

    func test_writeAndRead_roundTrips() throws {
        let store = ManifestStore()
        let url = tempDir.appendingPathComponent("state.json")
        let original = StateFile(
            lastJunkScan: LastScanSummary(
                kind: "junk",
                totalBytes: 1234,
                itemCount: 5,
                finishedAt: Date(timeIntervalSince1970: 1_700_000_000)
            )
        )
        try store.write(original, to: url)
        let read = try store.read(StateFile.self, from: url)
        XCTAssertEqual(original, read)
    }

    func test_ensureGrauDirectory_createsDir() throws {
        // ManifestStore uses ~/.grau directly. To avoid touching the
        // user's real ~/.grau, we don't call ensureGrauDirectory
        // here — we just check the static path.
        XCTAssertTrue(ManifestStore.grauDirectory.path.hasSuffix(".grau"))
        XCTAssertTrue(ManifestStore.stateFile.path.hasSuffix(".grau/state.json"))
        XCTAssertTrue(ManifestStore.sizeCacheFile.path.hasSuffix(".grau/size-cache.json"))
    }

    // MARK: - Scan history (v1.6)

    func test_stateFile_defaultHistoryIsEmpty() {
        let s = StateFile()
        XCTAssertTrue(s.scanHistory.isEmpty)
    }

    func test_stateFile_appendingHistory_insertsAtHead() {
        let s = StateFile()
        let s1 = s.appendingHistory(LastScanSummary(
            kind: "junk", totalBytes: 100, itemCount: 1, finishedAt: Date()
        ))
        XCTAssertEqual(s1.scanHistory.count, 1)
        let s2 = s1.appendingHistory(LastScanSummary(
            kind: "junk", totalBytes: 200, itemCount: 2,
            finishedAt: Date(timeIntervalSinceNow: 60)
        ))
        XCTAssertEqual(s2.scanHistory.count, 2)
        // Newest at index 0.
        XCTAssertEqual(s2.scanHistory[0].totalBytes, 200)
        XCTAssertEqual(s2.scanHistory[1].totalBytes, 100)
    }

    func test_stateFile_appendingHistory_trimsToMax() {
        let s = StateFile()
        var copy = s
        for i in 0..<(StateFile.maxHistoryEntries + 5) {
            copy = copy.appendingHistory(LastScanSummary(
                kind: "junk", totalBytes: Int64(i), itemCount: i,
                finishedAt: Date()
            ))
        }
        XCTAssertEqual(copy.scanHistory.count, StateFile.maxHistoryEntries)
        // The newest (highest totalBytes) is at index 0.
        XCTAssertEqual(
            copy.scanHistory[0].totalBytes,
            Int64(StateFile.maxHistoryEntries + 4)
        )
    }

    func test_stateFile_appendingHistory_doesNotMutateOriginal() {
        let s = StateFile()
        _ = s.appendingHistory(LastScanSummary(
            kind: "junk", totalBytes: 1, itemCount: 1, finishedAt: Date()
        ))
        // Original is unchanged.
        XCTAssertTrue(s.scanHistory.isEmpty)
    }

    func test_stateFile_codableRoundTripWithHistory() throws {
        let s = StateFile(
            lastJunkScan: LastScanSummary(
                kind: "junk", totalBytes: 999, itemCount: 9,
                finishedAt: Date(timeIntervalSince1970: 1_700_000_000)
            )
        ).appendingHistory(LastScanSummary(
            kind: "junk", totalBytes: 500, itemCount: 5,
            finishedAt: Date(timeIntervalSince1970: 1_700_001_000)
        ))
        let url = tempDir.appendingPathComponent("state-history.json")
        let store = ManifestStore()
        try store.write(s, to: url)
        let read = try store.read(StateFile.self, from: url)
        XCTAssertEqual(s, read)
    }
}
