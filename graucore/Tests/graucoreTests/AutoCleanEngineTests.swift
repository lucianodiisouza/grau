//
//  AutoCleanEngineTests.swift
//  graucoreTests
//

import XCTest
@testable import graucore

final class AutoCleanEngineTests: XCTestCase {

    // MARK: - Rule predicates

    func test_canFire_returnsTrueWhenNeverFired() {
        let rule = AutoCleanRule(
            name: "x",
            condition: .trashSizeExceeds(bytes: 0),
            action: .logSummary
        )
        XCTAssertTrue(rule.canFire(now: Date()))
    }

    func test_canFire_returnsFalseDuringCooldown() {
        var rule = AutoCleanRule(
            name: "x",
            condition: .trashSizeExceeds(bytes: 0),
            action: .logSummary,
            cooldownSeconds: 3600
        )
        rule.lastFiredAt = Date().addingTimeInterval(-100)  // 100s ago
        XCTAssertFalse(rule.canFire(now: Date()))
    }

    func test_canFire_returnsTrueAfterCooldown() {
        var rule = AutoCleanRule(
            name: "x",
            condition: .trashSizeExceeds(bytes: 0),
            action: .logSummary,
            cooldownSeconds: 3600
        )
        rule.lastFiredAt = Date().addingTimeInterval(-7200)  // 2h ago
        XCTAssertTrue(rule.canFire(now: Date()))
    }

    func test_canFire_returnsFalseWhenDisabled() {
        var rule = AutoCleanRule(
            name: "x",
            condition: .trashSizeExceeds(bytes: 0),
            action: .logSummary,
            enabled: false
        )
        XCTAssertFalse(rule.canFire(now: Date()))
        rule.enabled = true
        XCTAssertTrue(rule.canFire(now: Date()))
    }

    // MARK: - Condition evaluation

    func test_evaluate_trashSizeCondition_firesAboveThreshold() {
        let engine = AutoCleanEngine()
        let rule = AutoCleanRule(
            name: "x",
            condition: .trashSizeExceeds(bytes: 1_000_000_000),
            action: .logSummary
        )
        let gauge = AutoCleanGaugeSnapshot(trashSizeBytes: 2_000_000_000)
        let fired = runEval(engine, rules: [rule], gauge: gauge)
        XCTAssertEqual(fired.count, 1)
        XCTAssertEqual(fired.first?.rule.id, rule.id)
    }

    func test_evaluate_trashSizeCondition_doesNotFireAtOrBelowThreshold() {
        let engine = AutoCleanEngine()
        let rule = AutoCleanRule(
            name: "x",
            condition: .trashSizeExceeds(bytes: 1_000_000_000),
            action: .logSummary
        )
        let gaugeEqual = AutoCleanGaugeSnapshot(trashSizeBytes: 1_000_000_000)
        XCTAssertEqual(
            runEval(engine, rules: [rule], gauge: gaugeEqual).count,
            0
        )
        let gaugeBelow = AutoCleanGaugeSnapshot(trashSizeBytes: 999_999_999)
        XCTAssertEqual(
            runEval(engine, rules: [rule], gauge: gaugeBelow).count,
            0
        )
    }

    func test_evaluate_junkSizeCondition_requiresJunkSnapshot() {
        let engine = AutoCleanEngine()
        let rule = AutoCleanRule(
            name: "x",
            condition: .junkSizeExceeds(bytes: 100),
            action: .logSummary
        )
        // Without a junk snapshot, the condition is unmet.
        let noSnapshot = AutoCleanGaugeSnapshot(trashSizeBytes: 0)
        XCTAssertEqual(runEval(engine, rules: [rule], gauge: noSnapshot).count, 0)
        // With a junk snapshot above the threshold, the rule fires.
        let withSnapshot = AutoCleanGaugeSnapshot(
            trashSizeBytes: 0,
            lastJunkScanBytes: 200
        )
        XCTAssertEqual(runEval(engine, rules: [rule], gauge: withSnapshot).count, 1)
    }

    func test_evaluate_diskUsageCondition_firesAboveFraction() {
        let engine = AutoCleanEngine()
        let rule = AutoCleanRule(
            name: "x",
            condition: .diskUsageExceeds(fraction: 0.9),
            action: .logSummary
        )
        let high = AutoCleanGaugeSnapshot(diskUsageFraction: 0.95)
        XCTAssertEqual(runEval(engine, rules: [rule], gauge: high).count, 1)
        let low = AutoCleanGaugeSnapshot(diskUsageFraction: 0.85)
        XCTAssertEqual(runEval(engine, rules: [rule], gauge: low).count, 0)
    }

    func test_evaluate_timeOfDayCondition_firesOnlyAtExactTime() {
        let engine = AutoCleanEngine()
        let rule = AutoCleanRule(
            name: "x",
            condition: .timeOfDay(hour: 3, minute: 0),
            action: .logSummary
        )
        var comps = DateComponents()
        comps.year = 2026; comps.month = 7; comps.day = 26
        comps.hour = 3; comps.minute = 0
        comps.second = 0
        let atThree = Calendar.current.date(from: comps)!
        let gauge = AutoCleanGaugeSnapshot(capturedAt: atThree)
        XCTAssertEqual(
            runEvalAt(engine, rules: [rule], gauge: gauge, now: atThree).count,
            1
        )

        comps.hour = 3; comps.minute = 1
        let justAfter = Calendar.current.date(from: comps)!
        let gauge2 = AutoCleanGaugeSnapshot(capturedAt: justAfter)
        XCTAssertEqual(
            runEvalAt(engine, rules: [rule], gauge: gauge2, now: justAfter).count,
            0
        )
    }

    func test_evaluate_skipsDisabledRules() {
        let engine = AutoCleanEngine()
        let rule = AutoCleanRule(
            name: "x",
            condition: .trashSizeExceeds(bytes: 0),
            action: .logSummary,
            enabled: false
        )
        let gauge = AutoCleanGaugeSnapshot(trashSizeBytes: 999_999_999_999)
        XCTAssertEqual(runEval(engine, rules: [rule], gauge: gauge).count, 0)
    }

    func test_evaluate_respectsCooldown() async {
        let engine = AutoCleanEngine()
        var rule = AutoCleanRule(
            name: "x",
            condition: .trashSizeExceeds(bytes: 0),
            action: .logSummary,
            cooldownSeconds: 60
        )
        rule.lastFiredAt = Date().addingTimeInterval(-10)
        let gauge = AutoCleanGaugeSnapshot(trashSizeBytes: 999_999_999_999)
        let fired = await engine.evaluate(rules: [rule], gauge: gauge)
        XCTAssertEqual(fired.count, 0)
    }

    func test_evaluate_multipleRules_returnsEachThatFires() {
        let engine = AutoCleanEngine()
        let r1 = AutoCleanRule(
            name: "a",
            condition: .trashSizeExceeds(bytes: 100),
            action: .logSummary
        )
        let r2 = AutoCleanRule(
            name: "b",
            condition: .diskUsageExceeds(fraction: 0.5),
            action: .logSummary,
            enabled: false
        )
        let r3 = AutoCleanRule(
            name: "c",
            condition: .trashSizeExceeds(bytes: 50),
            action: .logSummary
        )
        let gauge = AutoCleanGaugeSnapshot(
            trashSizeBytes: 200,
            diskUsageFraction: 0.95
        )
        let fired = runEval(engine, rules: [r1, r2, r3], gauge: gauge)
        XCTAssertEqual(fired.count, 2)
        let ids = fired.map(\.rule.id)
        XCTAssertTrue(ids.contains(r1.id))
        XCTAssertTrue(ids.contains(r3.id))
    }

    // MARK: - Execute

    func test_execute_logSummary_appendsToNotificationLog() async {
        let engine = AutoCleanEngine()
        let rule = AutoCleanRule(
            name: "Hello",
            condition: .trashSizeExceeds(bytes: 0),
            action: .logSummary
        )
        let pending = PendingAutoCleanAction(
            rule: rule,
            firedAt: Date(),
            gauge: AutoCleanGaugeSnapshot(trashSizeBytes: 1)
        )
        let results = await engine.execute([pending])
        XCTAssertEqual(results.count, 1)
        XCTAssertTrue(results.first?.summary.contains("Logged") ?? false)

        // Confirm a notification log entry was written.
        let entries = await NotificationLog().read()
        let match = entries.first { $0.ruleID == "auto.clean" }
        XCTAssertNotNil(match)
        XCTAssertTrue(match?.body.contains("Hello") ?? false)
    }

    // MARK: - Condition summary

    func test_condition_summary_humanReadable() {
        let trash = AutoCleanCondition.trashSizeExceeds(bytes: 5_000_000_000)
        XCTAssertTrue(trash.summary.contains("5"))
        let junk = AutoCleanCondition.junkSizeExceeds(bytes: 1_000_000)
        XCTAssertTrue(junk.summary.contains("MB") || junk.summary.contains("1"))
        let disk = AutoCleanCondition.diskUsageExceeds(fraction: 0.9)
        XCTAssertTrue(disk.summary.contains("90%"))
        let tod = AutoCleanCondition.timeOfDay(hour: 3, minute: 0)
        XCTAssertTrue(tod.summary.contains("03:00"))
    }

    // MARK: - Codable

    func test_condition_codable_roundTrip() throws {
        let cases: [AutoCleanCondition] = [
            .trashSizeExceeds(bytes: 1234),
            .junkSizeExceeds(bytes: 5678),
            .diskUsageExceeds(fraction: 0.91),
            .timeOfDay(hour: 22, minute: 30)
        ]
        let encoder = JSONEncoder()
        let decoder = JSONDecoder()
        for original in cases {
            let data = try encoder.encode(original)
            let decoded = try decoder.decode(AutoCleanCondition.self, from: data)
            XCTAssertEqual(original, decoded)
        }
    }

    func test_rule_codable_roundTrip() throws {
        var rule = AutoCleanRule(
            name: "x",
            condition: .trashSizeExceeds(bytes: 100),
            action: .runRetention,
            createdAt: Date(timeIntervalSince1970: 1_700_000_000)
        )
        rule.lastFiredAt = Date(timeIntervalSince1970: 1_700_000_500)
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let data = try encoder.encode(rule)
        let decoded = try decoder.decode(AutoCleanRule.self, from: data)
        XCTAssertEqual(rule, decoded)
    }

    // MARK: - Store

    func test_store_returnsDefaultsWhenFileMissing() async {
        let store = AutoCleanStore()
        let rules = await store.read()
        // Two sensible defaults.
        XCTAssertEqual(rules.count, 2)
    }

    // MARK: - Helpers

    private func runEval(
        _ engine: AutoCleanEngine,
        rules: [AutoCleanRule],
        gauge: AutoCleanGaugeSnapshot
    ) -> [PendingAutoCleanAction] {
        let semaphore = DispatchSemaphore(value: 0)
        var out: [PendingAutoCleanAction] = []
        Task {
            out = await engine.evaluate(rules: rules, gauge: gauge)
            semaphore.signal()
        }
        semaphore.wait()
        return out
    }

    private func runEvalAt(
        _ engine: AutoCleanEngine,
        rules: [AutoCleanRule],
        gauge: AutoCleanGaugeSnapshot,
        now: Date
    ) -> [PendingAutoCleanAction] {
        let semaphore = DispatchSemaphore(value: 0)
        var out: [PendingAutoCleanAction] = []
        Task {
            out = await engine.evaluate(rules: rules, gauge: gauge, now: now)
            semaphore.signal()
        }
        semaphore.wait()
        return out
    }
}
