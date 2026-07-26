//
//  NotificationCooldownTests.swift
//  graucoreTests
//

import XCTest
@testable import graucore

final class NotificationCooldownTests: XCTestCase {

    func test_init_clampsToMaxThirtyDays() {
        let c = NotificationCooldown(ruleID: "x", seconds: 31 * 24 * 3600)
        XCTAssertEqual(c.seconds, 30 * 24 * 3600)
    }

    func test_init_negativeSecondsBecomesZero() {
        let c = NotificationCooldown(ruleID: "x", seconds: -100)
        XCTAssertEqual(c.seconds, 0)
    }

    func test_humanReadable_zeroIsNoCooldown() {
        let c = NotificationCooldown(ruleID: "x", seconds: 0)
        XCTAssertEqual(c.humanReadable, "No cooldown")
    }

    func test_humanReadable_hoursUnderDay() {
        let c = NotificationCooldown(ruleID: "x", seconds: 3 * 3600)
        XCTAssertEqual(c.humanReadable, "3 hours")
        let oneHour = NotificationCooldown(ruleID: "x", seconds: 3600)
        XCTAssertEqual(oneHour.humanReadable, "1 hour")
    }

    func test_humanReadable_daysAtOrAboveOneDay() {
        let c = NotificationCooldown(ruleID: "x", seconds: 2 * 24 * 3600)
        XCTAssertEqual(c.humanReadable, "2 days")
        let oneDay = NotificationCooldown(ruleID: "x", seconds: 24 * 3600)
        XCTAssertEqual(oneDay.humanReadable, "1 day")
    }

    func test_defaultSeconds_is24Hours() {
        XCTAssertEqual(
            NotificationCooldown.defaultSeconds,
            24 * 3600
        )
        XCTAssertEqual(
            NotificationCooldownDefaults.defaultSeconds(for: "any.id"),
            24 * 3600
        )
    }

    func test_userDefaultsKey_isStable() {
        XCTAssertEqual(
            NotificationCooldownDefaults.userDefaultsKey(for: "junk.gt1gb"),
            "grau.rule.junk.gt1gb.cooldown"
        )
    }

    func test_equality_respectsAllFields() {
        let a = NotificationCooldown(ruleID: "x", seconds: 100)
        let b = NotificationCooldown(ruleID: "x", seconds: 100)
        let c = NotificationCooldown(ruleID: "x", seconds: 200)
        let d = NotificationCooldown(ruleID: "y", seconds: 100)
        XCTAssertEqual(a, b)
        XCTAssertNotEqual(a, c)
        XCTAssertNotEqual(a, d)
    }
}
