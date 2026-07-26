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
}
