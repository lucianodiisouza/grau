//
//  RetentionPolicyTests.swift
//  graucoreTests
//

import XCTest
@testable import graucore

final class RetentionPolicyTests: XCTestCase {

    func test_defaultPolicy_returnsDefaultDaysPerKind() {
        let policy = RetentionPolicy.default
        XCTAssertEqual(policy.days(for: .notificationLog), 90)
        XCTAssertEqual(policy.days(for: .trashManifest), 30)
        XCTAssertEqual(policy.days(for: .scanHistory), 0)
    }

    func test_setting_returnsNewPolicyWithWindow() {
        let policy = RetentionPolicy.default
            .setting(RetentionWindow(kind: .notificationLog, days: 7))
        XCTAssertEqual(policy.days(for: .notificationLog), 7)
        XCTAssertEqual(policy.days(for: .trashManifest), 30)
    }

    func test_clearing_fallsBackToDefault() {
        let policy = RetentionPolicy.default
            .setting(RetentionWindow(kind: .trashManifest, days: 5))
            .clearing(.trashManifest)
        XCTAssertEqual(policy.days(for: .trashManifest), 30)
    }

    func test_isForever_trueForZero() {
        let policy = RetentionPolicy.default
        XCTAssertTrue(policy.isForever(.scanHistory))
    }

    func test_isForever_falseForPositive() {
        let policy = RetentionPolicy.default
        XCTAssertFalse(policy.isForever(.notificationLog))
    }

    func test_window_clampsToMaxTenYears() {
        let window = RetentionWindow(kind: .trashManifest, days: 100_000)
        XCTAssertEqual(window.days, 3650)
    }

    func test_window_clampsToZeroFloor() {
        let window = RetentionWindow(kind: .trashManifest, days: -7)
        XCTAssertEqual(window.days, 0)
    }

    func test_sortedWindows_includesEveryKind() {
        let policy = RetentionPolicy.default
        let sorted = policy.sortedWindows
        XCTAssertEqual(sorted.count, RetentionKind.allCases.count)
        // Sorted by RetentionKind.allCases — same order.
        XCTAssertEqual(sorted.map(\.kind), Array(RetentionKind.allCases))
    }

    func test_setting_replacesPreviousValue() {
        let policy = RetentionPolicy.default
            .setting(RetentionWindow(kind: .notificationLog, days: 7))
            .setting(RetentionWindow(kind: .notificationLog, days: 14))
        XCTAssertEqual(policy.days(for: .notificationLog), 14)
    }

    func test_equality_respectsWindows() {
        let a = RetentionPolicy.default.setting(RetentionWindow(kind: .trashManifest, days: 7))
        let b = RetentionPolicy.default.setting(RetentionWindow(kind: .trashManifest, days: 7))
        let c = RetentionPolicy.default
        XCTAssertEqual(a, b)
        XCTAssertNotEqual(a, c)
    }
}
