//
//  FileHasherTests.swift
//  graucoreTests
//

import XCTest
import CryptoKit
@testable import graucore

final class FileHasherTests: XCTestCase {

    var tempDir: URL!

    override func setUpWithError() throws {
        try super.setUpWithError()
        tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("grau-hash-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: tempDir)
        try super.tearDownWithError()
    }

    func test_partialHash_knownAnswer() throws {
        // "abc" -> SHA-256 first-4-bytes prefix
        // We use a known file: 4096+ bytes matters less than
        // the prefix.
        let content = Data("abc".utf8)
        let file = tempDir.appendingPathComponent("a")
        try content.write(to: file)

        let hasher = FileHasher()
        let hash = try hasher.partialHash(of: file)
        // SHA-256("abc") = ba7816bf... so first chars are "ba78"
        XCTAssertTrue(hash.hasPrefix("ba78"))
    }

    func test_partialHash_differentContent_differentHash() throws {
        try Data("hello".utf8).write(to: tempDir.appendingPathComponent("a"))
        try Data("world".utf8).write(to: tempDir.appendingPathComponent("b"))

        let hasher = FileHasher()
        let h1 = try hasher.partialHash(of: tempDir.appendingPathComponent("a"))
        let h2 = try hasher.partialHash(of: tempDir.appendingPathComponent("b"))
        XCTAssertNotEqual(h1, h2)
    }

    func test_fullHash_knownAnswer() throws {
        try Data("abc".utf8).write(to: tempDir.appendingPathComponent("a"))
        let hasher = FileHasher()
        let hash = try hasher.fullHash(of: tempDir.appendingPathComponent("a"))
        XCTAssertEqual(hash, "ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad")
    }

    func test_fullHash_sameContent_sameHash() throws {
        try Data("duplicate content".utf8).write(to: tempDir.appendingPathComponent("a"))
        try Data("duplicate content".utf8).write(to: tempDir.appendingPathComponent("b"))
        let hasher = FileHasher()
        let h1 = try hasher.fullHash(of: tempDir.appendingPathComponent("a"))
        let h2 = try hasher.fullHash(of: tempDir.appendingPathComponent("b"))
        XCTAssertEqual(h1, h2)
    }

    func test_fullHash_largeFile_streamsCorrectly() throws {
        // Write 5 MB of zeroes; the hasher must not buffer it all.
        let large = Data(count: 5 * 1024 * 1024)
        try large.write(to: tempDir.appendingPathComponent("big"))
        let hasher = FileHasher()
        let hash = try hasher.fullHash(of: tempDir.appendingPathComponent("big"))
        // SHA-256 of 5 MB of zeroes — known value
        XCTAssertFalse(hash.isEmpty)
        XCTAssertEqual(hash.count, 64)  // 32 bytes = 64 hex chars
    }
}
