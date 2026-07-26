//
//  DirectorySizerTests.swift
//  graucoreTests
//

import XCTest
@testable import graucore

final class DirectorySizerTests: XCTestCase {

    var tempDir: URL!

    override func setUpWithError() throws {
        try super.setUpWithError()
        tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("grau-tests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: tempDir)
        try super.tearDownWithError()
    }

    func test_sizeSync_emptyDirectory_isZero() throws {
        let sizer = DirectorySizer()
        let size = try sizer.sizeSync(root: tempDir)
        XCTAssertEqual(size, .zero)
    }

    func test_sizeSync_sumsFiles() throws {
        try Data(repeating: 0, count: 1000).write(to: tempDir.appendingPathComponent("a"))
        try Data(repeating: 0, count: 2000).write(to: tempDir.appendingPathComponent("b"))
        let sizer = DirectorySizer()
        let size = try sizer.sizeSync(root: tempDir)
        XCTAssertEqual(size.bytes, 3000)
    }

    func test_sizeSync_recursesIntoSubdirectories() throws {
        let sub = tempDir.appendingPathComponent("sub", isDirectory: true)
        try FileManager.default.createDirectory(at: sub, withIntermediateDirectories: true)
        try Data(repeating: 0, count: 500).write(to: sub.appendingPathComponent("nested"))
        try Data(repeating: 0, count: 1500).write(to: tempDir.appendingPathComponent("top"))
        let sizer = DirectorySizer()
        let size = try sizer.sizeSync(root: tempDir)
        XCTAssertEqual(size.bytes, 2000)
    }

    func test_sizeSync_skipsCustomExclusions() throws {
        struct TestExclusions: PathExclusionsProvider {
            func shouldExclude(absolutePath: String) -> Bool {
                absolutePath.contains("/Skip/")
            }
        }
        let excluded = tempDir.appendingPathComponent("Skip", isDirectory: true)
        try FileManager.default.createDirectory(at: excluded, withIntermediateDirectories: true)
        try Data(repeating: 0, count: 9999).write(to: excluded.appendingPathComponent("x"))
        try Data(repeating: 0, count: 100).write(to: tempDir.appendingPathComponent("y"))

        let sizer = DirectorySizer(exclusions: TestExclusions())
        let size = try sizer.sizeSync(root: tempDir)
        XCTAssertEqual(size.bytes, 100)
    }

    func test_size_completes_withCorrectTotal() async throws {
        try Data(repeating: 0, count: 100).write(to: tempDir.appendingPathComponent("a"))
        try Data(repeating: 0, count: 200).write(to: tempDir.appendingPathComponent("b"))
        let sub = tempDir.appendingPathComponent("sub", isDirectory: true)
        try FileManager.default.createDirectory(at: sub, withIntermediateDirectories: true)
        try Data(repeating: 0, count: 50).write(to: sub.appendingPathComponent("c"))

        let sizer = DirectorySizer()
        var total: ByteSize = .zero
        for await event in sizer.size(root: tempDir) {
            if case .completed(_, let size) = event {
                total = size
            }
        }
        XCTAssertEqual(total.bytes, 350)
    }
}
