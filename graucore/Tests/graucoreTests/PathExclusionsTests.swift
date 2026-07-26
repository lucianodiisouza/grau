//
//  PathExclusionsTests.swift
//  graucoreTests
//

import XCTest
@testable import graucore

final class PathExclusionsTests: XCTestCase {

    func test_excludesSystem() {
        let ex = PathExclusions.standard
        XCTAssertTrue(ex.shouldExclude(absolutePath: "/System/Library/Fonts"))
        XCTAssertTrue(ex.shouldExclude(absolutePath: "/System/Applications"))
    }

    func test_excludesPrivateVarDB() {
        let ex = PathExclusions.standard
        XCTAssertTrue(ex.shouldExclude(absolutePath: "/private/var/db/dslocal/nodes"))
    }

    func test_excludesSpotlight() {
        let ex = PathExclusions.standard
        XCTAssertTrue(ex.shouldExclude(absolutePath: "/.Spotlight-V100"))
    }

    func test_excludesAppleBird_asDirectory() {
        let ex = PathExclusions.standard
        XCTAssertTrue(ex.shouldExclude(absolutePath: "/Users/foo/Library/Caches/com.apple.bird"))
    }

    func test_excludesAppleBird_withContentsInside() {
        let ex = PathExclusions.standard
        XCTAssertTrue(ex.shouldExclude(
            absolutePath: "/Users/foo/Library/Caches/com.apple.bird/cache.db"
        ))
    }

    func test_doesNotExcludeRegularUserPath() {
        let ex = PathExclusions.standard
        XCTAssertFalse(ex.shouldExclude(
            absolutePath: "/Users/foo/Library/Caches/com.example.MyApp/data"
        ))
    }

    func test_doesNotExcludeRegularSystemPath() {
        let ex = PathExclusions.standard
        XCTAssertFalse(ex.shouldExclude(absolutePath: "/Applications/Safari.app"))
    }

    func test_customExclusions_works() {
        // Test that the protocol injection works.
        struct MyExclusions: PathExclusionsProvider {
            func shouldExclude(absolutePath: String) -> Bool {
                absolutePath.hasPrefix("/my-special-prefix")
            }
        }
        let scanner = FileSystemScanner(exclusions: MyExclusions())
        // We don't run the scanner here; we just verify the
        // protocol type is accepted. The full walk test uses
        // this in FileSystemScannerTests.
        _ = scanner
    }
}
