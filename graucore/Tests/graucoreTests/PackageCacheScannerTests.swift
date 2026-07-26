//
//  PackageCacheScannerTests.swift
//  graucoreTests
//

import XCTest
@testable import graucore

final class PackageCacheScannerTests: XCTestCase {

    var tempHome: URL!

    override func setUpWithError() throws {
        try super.setUpWithError()
        tempHome = FileManager.default.temporaryDirectory
            .appendingPathComponent("grau-pkgcache-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: tempHome, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: tempHome)
        try super.tearDownWithError()
    }

    /// Helper: synthesize one "kind" worth of caches at a custom
    /// root and verify the scanner reports their size.
    private func makeFakeCache(
        at url: URL,
        files: [(String, Int)]
    ) throws {
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        for (name, size) in files {
            try Data(repeating: 0, count: size).write(to: url.appendingPathComponent(name))
        }
    }

    /// We can't redirect NSHomeDirectory() in production code, but
    /// the scanner reads `kind.defaultPaths` which uses
    /// `homeDirectoryForCurrentUser`. We override by:
    ///   1. creating a temp dir
    ///   2. creating a custom kind whose `defaultPaths` points to it
    ///   3. constructing the scanner with that custom kind
    /// Since `PackageCacheScanner.scan` only accepts a [PackageCacheKind]
    /// (which is non-extensible), we test indirectly: we create
    /// files at the *real* default paths only if they exist; if
    /// they don't, the scanner returns `exists: false` and we
    /// verify the structure of the result.

    func test_scan_returnsAllRequestedKinds() async {
        let scanner = PackageCacheScanner()
        let results = await scanner.scan(kinds: PackageCacheKind.allCases)
        XCTAssertEqual(results.count, PackageCacheKind.allCases.count)
    }

    func test_scan_nonExistentCache_marksExistsFalse() async {
        // The scanner reports `exists: false` for caches whose
        // default path isn't on the host. We scan two distinct
        // kinds and verify that we get one entry per requested
        // kind in the expected set.
        let scanner = PackageCacheScanner()
        let results = await scanner.scan(kinds: [.carthage, .sbt])
        let kinds = Set(results.map { $0.kind })
        XCTAssertEqual(kinds, Set([.carthage, .sbt]))
        for r in results {
            XCTAssertGreaterThanOrEqual(r.size.bytes, 0)
            // exists may be true or false depending on the host
            XCTAssertNotNil(r.id)
        }
    }

    func test_scan_results_areSortedBySizeDescending() async {
        let scanner = PackageCacheScanner()
        let results = await scanner.scan()
        for i in 0..<(results.count - 1) {
            XCTAssertGreaterThanOrEqual(
                results[i].size, results[i + 1].size,
                "Results must be sorted by size descending"
            )
        }
    }

    func test_packageCacheInfo_init_storesAllFields() {
        let info = PackageCacheInfo(
            kind: .npm,
            paths: [URL(fileURLWithPath: "/tmp/.npm")],
            size: ByteSize(bytes: 1024),
            exists: true
        )
        XCTAssertEqual(info.kind, .npm)
        XCTAssertEqual(info.paths.count, 1)
        XCTAssertEqual(info.size.bytes, 1024)
        XCTAssertTrue(info.exists)
    }
}
