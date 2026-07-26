//
//  SizeCacheTests.swift
//  graucoreTests
//

import XCTest
@testable import graucore

final class SizeCacheTests: XCTestCase {

    func test_cachedSize_returnsNilForMissingEntry() {
        let cache = SizeCache()
        let result = cache.cachedSize(
            for: URL(fileURLWithPath: "/tmp/foo"),
            currentMtime: Date()
        )
        XCTAssertNil(result)
    }

    func test_cachedSize_returnsValueWhenMtimeMatches() {
        let path = URL(fileURLWithPath: "/tmp/foo")
        let mtime = Date()
        var cache = SizeCache()
        cache.record(path: path, size: 1024, mtime: mtime)
        let result = cache.cachedSize(for: path, currentMtime: mtime)
        XCTAssertEqual(result, 1024)
    }

    func test_cachedSize_returnsNilWhenMtimeDiffers() {
        let path = URL(fileURLWithPath: "/tmp/foo")
        let originalMtime = Date(timeIntervalSince1970: 1000)
        let newMtime = Date(timeIntervalSince1970: 2000)
        var cache = SizeCache()
        cache.record(path: path, size: 1024, mtime: originalMtime)
        let result = cache.cachedSize(for: path, currentMtime: newMtime)
        XCTAssertNil(result)
    }

    func test_record_updatesExistingEntry() {
        let path = URL(fileURLWithPath: "/tmp/foo")
        let mtime = Date()
        var cache = SizeCache()
        cache.record(path: path, size: 100, mtime: mtime)
        cache.record(path: path, size: 200, mtime: mtime)
        let result = cache.cachedSize(for: path, currentMtime: mtime)
        XCTAssertEqual(result, 200)
    }

    func test_prune_keepsOnlyListedPaths() {
        let path1 = URL(fileURLWithPath: "/tmp/a")
        let path2 = URL(fileURLWithPath: "/tmp/b")
        let mtime = Date()
        var cache = SizeCache()
        cache.record(path: path1, size: 100, mtime: mtime)
        cache.record(path: path2, size: 200, mtime: mtime)
        cache.prune(keeping: [path1.path])
        XCTAssertNotNil(cache.entries[path1.path])
        XCTAssertNil(cache.entries[path2.path])
    }

    func test_codable_roundTrip() throws {
        let path = URL(fileURLWithPath: "/tmp/x")
        let mtime = Date(timeIntervalSince1970: 1_700_000_000)
        var cache = SizeCache()
        cache.record(path: path, size: 999, mtime: mtime)
        cache.lastFullScan = mtime
        let data = try JSONEncoder().encode(cache)
        let decoded = try JSONDecoder().decode(SizeCache.self, from: data)
        XCTAssertEqual(decoded.entries[path.path]?.size, 999)
        XCTAssertEqual(decoded.lastFullScan, mtime)
    }
}
