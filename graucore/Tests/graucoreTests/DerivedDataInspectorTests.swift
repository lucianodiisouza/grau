//
//  DerivedDataInspectorTests.swift
//  graucoreTests
//

import XCTest
@testable import graucore

final class DerivedDataInspectorTests: XCTestCase {

    var fakeDD: URL!

    override func setUpWithError() throws {
        try super.setUpWithError()
        let raw = FileManager.default.temporaryDirectory
            .appendingPathComponent("grau-dd-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: raw, withIntermediateDirectories: true)
        fakeDD = raw.resolvingSymlinksInPath().standardizedFileURL
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: fakeDD)
        try super.tearDownWithError()
    }

    @discardableResult
    private func makeProjectDir(
        name: String,
        bytes: Int
    ) throws -> URL {
        let dir = fakeDD.appendingPathComponent(name, isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        try Data(repeating: 0, count: bytes).write(to: dir.appendingPathComponent("build.o"))
        return dir
    }

    func test_splitProjectName_typicalXcodeFolder() {
        let (project, hash) = DerivedDataInfo.splitProjectName("MyApp-abcdef1234567890")
        XCTAssertEqual(project, "MyApp")
        XCTAssertEqual(hash, "abcdef1234567890")
    }

    func test_splitProjectName_noHash_returnsWhole() {
        let (project, hash) = DerivedDataInfo.splitProjectName("MyApp")
        XCTAssertEqual(project, "MyApp")
        XCTAssertNil(hash)
    }

    func test_splitProjectName_hashWithVariousLengths() {
        // Various 8+ char hashes
        let (project, hash) = DerivedDataInfo.splitProjectName("MyApp-abcdefgh")
        XCTAssertEqual(project, "MyApp")
        XCTAssertEqual(hash, "abcdefgh")

        let (p2, h2) = DerivedDataInfo.splitProjectName("MyApp-12345678")
        XCTAssertEqual(p2, "MyApp")
        XCTAssertEqual(h2, "12345678")
    }

    func test_splitProjectName_shortTokenNoMatch() {
        // Need at least 8 chars in the hash to be considered a hash
        let (project, hash) = DerivedDataInfo.splitProjectName("MyApp-abc")
        XCTAssertEqual(project, "MyApp-abc")
        XCTAssertNil(hash)
    }

    func test_listProjects_missingRoot_returnsEmpty() async {
        let inspector = DerivedDataInspector(
            derivedDataPath: FileManager.default.temporaryDirectory
                .appendingPathComponent("grau-dd-missing-\(UUID().uuidString)")
        )
        let results = await inspector.listProjects()
        XCTAssertTrue(results.isEmpty)
    }

    func test_listProjects_emptyRoot_returnsEmpty() async {
        let inspector = DerivedDataInspector(derivedDataPath: fakeDD)
        let results = await inspector.listProjects()
        XCTAssertTrue(results.isEmpty)
    }

    func test_listProjects_singleProject() async throws {
        let dir = try makeProjectDir(name: "MyApp-abcdef1234567890", bytes: 1234)
        let inspector = DerivedDataInspector(derivedDataPath: fakeDD)
        let results = await inspector.listProjects()
        XCTAssertEqual(results.count, 1)
        // Compare the last path component to dodge /var vs /private/var
        XCTAssertEqual(results[0].path.lastPathComponent, dir.lastPathComponent)
        XCTAssertEqual(results[0].folderName, "MyApp-abcdef1234567890")
        XCTAssertEqual(results[0].projectName, "MyApp")
        XCTAssertEqual(results[0].size.bytes, 1234)
    }

    func test_listProjects_resultsSortedBySizeDescending() async throws {
        try makeProjectDir(name: "Small-aaaaaaaaaaaa", bytes: 50)
        try makeProjectDir(name: "Big-bbbbbbbbbbbb", bytes: 5000)
        let inspector = DerivedDataInspector(derivedDataPath: fakeDD)
        let results = await inspector.listProjects()
        XCTAssertEqual(results.count, 2)
        XCTAssertGreaterThanOrEqual(results[0].size, results[1].size)
        XCTAssertEqual(results[0].projectName, "Big")
    }

    func test_listProjects_lastModifiedIsRecorded() async throws {
        try makeProjectDir(name: "MyApp-abcdef", bytes: 10)
        let inspector = DerivedDataInspector(derivedDataPath: fakeDD)
        let results = await inspector.listProjects()
        XCTAssertNotNil(results.first?.lastModified)
    }
}
