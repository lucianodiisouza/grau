//
//  ArchivesInspectorTests.swift
//  graucoreTests
//

import XCTest
@testable import graucore

final class ArchivesInspectorTests: XCTestCase {

    var fakeArchives: URL!

    override func setUpWithError() throws {
        try super.setUpWithError()
        let raw = FileManager.default.temporaryDirectory
            .appendingPathComponent("grau-archives-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: raw, withIntermediateDirectories: true)
        fakeArchives = raw.resolvingSymlinksInPath().standardizedFileURL
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: fakeArchives)
        try super.tearDownWithError()
    }

    @discardableResult
    private func makeArchive(
        date: String,
        name: String,
        bytes: Int
    ) throws -> URL {
        let dateDir = fakeArchives.appendingPathComponent(date, isDirectory: true)
        try FileManager.default.createDirectory(at: dateDir, withIntermediateDirectories: true)
        let archive = dateDir.appendingPathComponent(name)
        try FileManager.default.createDirectory(at: archive, withIntermediateDirectories: true)
        try Data(repeating: 0, count: bytes).write(to: archive.appendingPathComponent("data.tar"))
        return archive
    }

    func test_listArchives_missingRoot_returnsEmpty() async {
        let inspector = ArchivesInspector(
            archivesPath: FileManager.default.temporaryDirectory
                .appendingPathComponent("grau-archives-missing-\(UUID().uuidString)")
        )
        let results = await inspector.listArchives()
        XCTAssertTrue(results.isEmpty)
    }

    func test_listArchives_emptyRoot_returnsEmpty() async {
        let inspector = ArchivesInspector(archivesPath: fakeArchives)
        let results = await inspector.listArchives()
        XCTAssertTrue(results.isEmpty)
    }

    func test_listArchives_singleArchive() async throws {
        let archive = try makeArchive(
            date: "2026-07-26",
            name: "MyApp 1.0 (1).xcarchive",
            bytes: 4096
        )
        let inspector = ArchivesInspector(archivesPath: fakeArchives)
        let results = await inspector.listArchives()
        XCTAssertEqual(results.count, 1)
        // Compare the last path component to dodge /var vs /private/var
        XCTAssertEqual(results[0].path.lastPathComponent, archive.lastPathComponent)
        XCTAssertEqual(results[0].size.bytes, 4096)
        XCTAssertEqual(results[0].name, "MyApp 1.0 (1).xcarchive")
    }

    func test_listArchives_skipsNonXcarchiveFiles() async throws {
        let dateDir = fakeArchives.appendingPathComponent("2026-07-26", isDirectory: true)
        try FileManager.default.createDirectory(at: dateDir, withIntermediateDirectories: true)
        // Create a non-archive file
        try Data("not an archive".utf8).write(
            to: dateDir.appendingPathComponent("readme.txt")
        )
        // And a real archive
        _ = try makeArchive(
            date: "2026-07-26",
            name: "MyApp.xcarchive",
            bytes: 100
        )
        let inspector = ArchivesInspector(archivesPath: fakeArchives)
        let results = await inspector.listArchives()
        XCTAssertEqual(results.count, 1)
        XCTAssertEqual(results[0].name, "MyApp.xcarchive")
    }

    func test_listArchives_multipleDates() async throws {
        try makeArchive(date: "2026-07-25", name: "Old.xcarchive", bytes: 100)
        try makeArchive(date: "2026-07-26", name: "New.xcarchive", bytes: 200)
        let inspector = ArchivesInspector(archivesPath: fakeArchives)
        let results = await inspector.listArchives()
        XCTAssertEqual(results.count, 2)
    }

    func test_listArchives_resultsSortedBySizeDescending() async throws {
        try makeArchive(date: "2026-07-25", name: "Small.xcarchive", bytes: 50)
        try makeArchive(date: "2026-07-26", name: "Big.xcarchive", bytes: 9_999)
        let inspector = ArchivesInspector(archivesPath: fakeArchives)
        let results = await inspector.listArchives()
        XCTAssertEqual(results.count, 2)
        XCTAssertGreaterThanOrEqual(results[0].size, results[1].size)
    }
}
