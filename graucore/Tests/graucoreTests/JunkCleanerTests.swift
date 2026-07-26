//
//  JunkCleanerTests.swift
//  graucoreTests
//

import XCTest
@testable import graucore

final class JunkCleanerTests: XCTestCase {

    var tempDir: URL!
    var manifestDir: URL!

    override func setUpWithError() throws {
        try super.setUpWithError()
        tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("grau-cleaner-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        manifestDir = tempDir.appendingPathComponent("manifests", isDirectory: true)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: tempDir)
        try super.tearDownWithError()
    }

    func test_clean_movesItemsToTrashAndWritesManifest() async throws {
        try Data("a".utf8).write(to: tempDir.appendingPathComponent("file1.txt"))
        try Data("bb".utf8).write(to: tempDir.appendingPathComponent("file2.txt"))

        let results = [
            JunkResult(
                category: .userCache,
                size: ByteSize(bytes: 3),
                items: [
                    JunkItem(
                        path: tempDir.appendingPathComponent("file1.txt"),
                        size: ByteSize(bytes: 1),
                        isDirectory: false
                    ),
                    JunkItem(
                        path: tempDir.appendingPathComponent("file2.txt"),
                        size: ByteSize(bytes: 2),
                        isDirectory: false
                    ),
                ],
                scanDuration: 0.01
            )
        ]

        let cleaner = JunkCleaner()
        let outcome = try await cleaner.clean(
            selectedResults: results,
            manifestDirectory: manifestDir
        )

        XCTAssertEqual(outcome.movedCount, 2)
        XCTAssertEqual(outcome.freedBytes, 3)
        XCTAssertEqual(outcome.manifest.kind, "junk")

        // Items gone from source
        XCTAssertFalse(FileManager.default.fileExists(atPath: tempDir.appendingPathComponent("file1.txt").path))
        XCTAssertFalse(FileManager.default.fileExists(atPath: tempDir.appendingPathComponent("file2.txt").path))
    }

    func test_clean_skipsResultsMarkedSkipped() async throws {
        let results = [
            JunkResult(
                category: .systemCache,
                size: .zero,
                items: [],
                scanDuration: 0,
                skipped: true,
                skipReason: "FDA missing"
            )
        ]
        let cleaner = JunkCleaner()
        let outcome = try await cleaner.clean(
            selectedResults: results,
            manifestDirectory: manifestDir
        )
        XCTAssertEqual(outcome.movedCount, 0)
    }

    func test_clean_emptySelection() async throws {
        let cleaner = JunkCleaner()
        let outcome = try await cleaner.clean(
            selectedResults: [],
            manifestDirectory: manifestDir
        )
        XCTAssertEqual(outcome.movedCount, 0)
        XCTAssertEqual(outcome.freedBytes, 0)
    }
}
