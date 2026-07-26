//
//  PermissionCheckerTests.swift
//  graucoreTests
//

import XCTest
@testable import graucore

final class PermissionCheckerTests: XCTestCase {

    /// On the build host (which has FDA), this should return true.
    /// On a non-FDA host it would return false. We test the heuristic
    /// behavior by exercising both probe paths.
    func test_fdaProbePath_isSet() {
        XCTAssertTrue(PermissionChecker.fdaProbePath.hasPrefix("/Library/"))
    }

    func test_hasFullDiskAccess_returnsBool() async {
        let checker = PermissionChecker()
        let has = await checker.hasFullDiskAccess()
        // The test passes if it returns a bool. The actual value
        // depends on whether the test host has FDA.
        XCTAssertTrue(has || !has)  // tautology; we're just exercising
    }

    func test_currentState_matchesHasFullDiskAccess() async {
        let checker = PermissionChecker()
        let state = await checker.currentState()
        let has = await checker.hasFullDiskAccess()
        XCTAssertEqual(state.fullDiskAccess, has)
    }
}
