//
//  PreferencesKeys.swift
//  grau
//
//  Centralized UserDefaults keys. See docs/ARCHITECTURE.md § 6.2.
//

import Foundation

public enum PreferencesKeys {
    public static let onboarded = "grau.onboarded"
    public static let devModeEnabled = "grau.devModeEnabled"
    public static let downloadsThresholdDays = "grau.downloadsThresholdDays"

    /// Per notification rule, the last time it fired.
    public static func ruleLastFired(_ ruleID: String) -> String {
        "grau.rule.\(ruleID).lastFiredAt"
    }

    /// Per notification rule, the last value seen (used to detect
    /// threshold crossings).
    public static func ruleLastValue(_ ruleID: String) -> String {
        "grau.rule.\(ruleID).lastValue"
    }
}
