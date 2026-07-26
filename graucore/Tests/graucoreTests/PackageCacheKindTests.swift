//
//  PackageCacheKindTests.swift
//  graucoreTests
//

import XCTest
@testable import graucore

final class PackageCacheKindTests: XCTestCase {

    func test_allCases_countIs16() {
        XCTAssertEqual(PackageCacheKind.allCases.count, 16)
    }

    func test_displayName_isNotEmptyForAll() {
        for kind in PackageCacheKind.allCases {
            XCTAssertFalse(
                kind.displayName.isEmpty,
                "\(kind.rawValue) has empty display name"
            )
        }
    }

    func test_id_matchesRawValue() {
        for kind in PackageCacheKind.allCases {
            XCTAssertEqual(kind.id, kind.rawValue)
        }
    }

    func test_defaultPaths_areUniqueAndAbsolute() {
        var seen: Set<String> = []
        for kind in PackageCacheKind.allCases {
            for path in kind.defaultPaths {
                XCTAssertTrue(path.isFileURL, "\(path) is not a file URL")
                XCTAssertTrue(path.path.hasPrefix("/"), "\(path) is not absolute")
                XCTAssertTrue(seen.insert(path.path).inserted, "\(path) is duplicated")
            }
        }
    }

    func test_defaultPaths_npm_usesDotNpm() {
        let home = FileManager.default.homeDirectoryForCurrentUser
        XCTAssertEqual(
            PackageCacheKind.npm.defaultPaths,
            [home.appendingPathComponent(".npm", isDirectory: true)]
        )
    }

    func test_defaultPaths_swiftpm_hasTwoCandidates() {
        // SwiftPM has two candidate paths; both must be in defaultPaths
        let paths = PackageCacheKind.swiftpm.defaultPaths
        XCTAssertEqual(paths.count, 2)
    }

    func test_defaultPaths_cocoapods_usesLibraryCaches() {
        let home = FileManager.default.homeDirectoryForCurrentUser
        XCTAssertEqual(
            PackageCacheKind.cocoapods.defaultPaths,
            [home.appendingPathComponent("Library/Caches/CocoaPods", isDirectory: true)]
        )
    }
}
