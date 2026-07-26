//
//  FileSystemScannerTests.swift
//  graucoreTests
//

import XCTest
@testable import graucore

final class FileSystemScannerTests: XCTestCase {

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

    func test_walk_emptyDirectory_yieldsOnlyTheRoot() async throws {
        let scanner = FileSystemScanner()
        var events: [FileSystemScanner.WalkEvent] = []
        for await event in scanner.walk(root: tempDir) {
            events.append(event)
        }
        XCTAssertEqual(events.count, 1) // just the root directory event
    }

    func test_walk_yieldsFiles() async throws {
        try Data("hello".utf8).write(to: tempDir.appendingPathComponent("a.txt"))
        try Data("world".utf8).write(to: tempDir.appendingPathComponent("b.txt"))
        let sub = tempDir.appendingPathComponent("sub", isDirectory: true)
        try FileManager.default.createDirectory(at: sub, withIntermediateDirectories: true)
        try Data("!".utf8).write(to: sub.appendingPathComponent("c.txt"))

        let scanner = FileSystemScanner()
        var fileURLs: [URL] = []
        for await event in scanner.walk(root: tempDir) {
            if case .file(let url) = event {
                fileURLs.append(url)
            }
        }
        XCTAssertEqual(fileURLs.count, 3)
    }

    func test_walk_skipsCustomExclusions() async throws {
        // Use a custom exclusion set so we can test exclusion behavior
        // in the temp dir (the real /System path doesn't exist here).
        struct TestExclusions: PathExclusionsProvider {
            func shouldExclude(absolutePath: String) -> Bool {
                absolutePath.contains("/AppleDir/")
            }
        }
        let excluded = tempDir.appendingPathComponent("AppleDir", isDirectory: true)
        try FileManager.default.createDirectory(at: excluded, withIntermediateDirectories: true)
        try Data("x".utf8).write(to: excluded.appendingPathComponent("nope.txt"))
        try Data("y".utf8).write(to: tempDir.appendingPathComponent("yes.txt"))

        let scanner = FileSystemScanner(exclusions: TestExclusions())
        var fileURLs: [URL] = []
        for await event in scanner.walk(root: tempDir) {
            if case .file(let url) = event {
                fileURLs.append(url)
            }
        }
        let names = fileURLs.map { $0.lastPathComponent }
        XCTAssertTrue(names.contains("yes.txt"))
        XCTAssertFalse(names.contains("nope.txt"))
    }

    func test_walk_skipsAppleCaches() async throws {
        let bird = tempDir.appendingPathComponent("com.apple.bird", isDirectory: true)
        try FileManager.default.createDirectory(at: bird, withIntermediateDirectories: true)
        try Data("x".utf8).write(to: bird.appendingPathComponent("cache.db"))

        try Data("y".utf8).write(to: tempDir.appendingPathComponent("regular.txt"))

        let scanner = FileSystemScanner()
        var fileURLs: [URL] = []
        for await event in scanner.walk(root: tempDir) {
            if case .file(let url) = event {
                fileURLs.append(url)
            }
        }
        let names = fileURLs.map { $0.lastPathComponent }
        XCTAssertTrue(names.contains("regular.txt"))
        XCTAssertFalse(names.contains("cache.db"))
    }

    func test_collectFiles_returnsAllFiles() async throws {
        try Data("a".utf8).write(to: tempDir.appendingPathComponent("a.txt"))
        try Data("b".utf8).write(to: tempDir.appendingPathComponent("b.txt"))

        let scanner = FileSystemScanner()
        let files = try await scanner.collectFiles(root: tempDir)
        XCTAssertEqual(files.count, 2)
    }
}
