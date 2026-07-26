//
//  ByteSizeTests.swift
//  graucoreTests
//

import XCTest
@testable import graucore

final class ByteSizeTests: XCTestCase {

    func test_zero() {
        XCTAssertEqual(ByteSize.zero, ByteSize(bytes: 0))
        XCTAssertEqual(ByteSize.zero.bytes, 0)
    }

    func test_equality() {
        XCTAssertEqual(ByteSize(bytes: 1024), ByteSize(bytes: 1024))
        XCTAssertNotEqual(ByteSize(bytes: 1024), ByteSize(bytes: 2048))
    }

    func test_comparable() {
        XCTAssertLessThan(ByteSize(bytes: 100), ByteSize(bytes: 200))
        XCTAssertGreaterThan(ByteSize(bytes: 1_000_000), ByteSize(bytes: 1))
    }

    func test_addition() {
        let sum = ByteSize(bytes: 100) + ByteSize(bytes: 200)
        XCTAssertEqual(sum, ByteSize(bytes: 300))
    }

    func test_integerLiteral() {
        let size: ByteSize = 4096
        XCTAssertEqual(size, ByteSize(bytes: 4096))
    }

    func test_codable() throws {
        let size = ByteSize(bytes: 1_234_567_890)
        let data = try JSONEncoder().encode(size)
        let decoded = try JSONDecoder().decode(ByteSize.self, from: data)
        XCTAssertEqual(size, decoded)
    }

    func test_humanReadable_isNonEmpty() {
        XCTAssertFalse(ByteSize(bytes: 0).humanReadable.isEmpty)
        XCTAssertFalse(ByteSize(bytes: 1_500_000_000).humanReadable.isEmpty)
    }

    func test_compactLabel_containsUnit() {
        let label = ByteSize(bytes: 5_500_000_000).compactLabel
        XCTAssertTrue(label.contains("GB") || label.contains("MB"))
    }
}
