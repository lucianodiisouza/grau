//
//  NotificationCooldown.swift
//  graucore
//
//  Per-rule notification cooldown. A rule can only fire once per
//  `seconds` interval, regardless of how many times the
//  threshold is crossed. This prevents notification spam when a
//  gauge (e.g. trash size) hovers around its threshold.
//
//  Backed by UserDefaults via the key `grau.rule.<id>.cooldown`.
//  The default cooldown is 24h. Users can configure per-rule
//  cooldowns in Settings (see grau/Features/Settings).
//
//  v1.7 feature. Phase 12.3.
//

import Foundation

/// A cooldown policy: how long after a rule fires before it can
/// fire again. The value is stored in seconds; 0 disables the
/// cooldown (fire on every transition).
public struct NotificationCooldown: Sendable, Equatable, Hashable {
    /// Identifier of the rule this cooldown applies to. Matches
    /// `NotificationRuleID.rawValue`.
    public let ruleID: String
    /// Cooldown in seconds. 0 means "no cooldown".
    public let seconds: TimeInterval

    public init(ruleID: String, seconds: TimeInterval) {
        self.ruleID = ruleID
        // Clamp to [0, 30 days]. Negative values disable cooldown
        // (treated as 0).
        self.seconds = max(0, min(seconds, 30 * 24 * 3600))
    }

    /// Default cooldown: 24h. A new rule gets this on first run.
    public static let defaultSeconds: TimeInterval = 24 * 3600

    /// Human-readable summary. Used in the Settings UI.
    public var humanReadable: String {
        if seconds == 0 { return "No cooldown" }
        let hours = Int(seconds / 3600)
        if hours < 24 {
            return hours == 1 ? "1 hour" : "\(hours) hours"
        }
        let days = hours / 24
        return days == 1 ? "1 day" : "\(days) days"
    }
}

public enum NotificationCooldownDefaults {
    /// Returns the default `seconds` for a given rule id. Currently
    /// all rules share the same 24h default, but the function is
    /// shaped to allow per-rule overrides in the future.
    public static func defaultSeconds(for ruleID: String) -> TimeInterval {
        NotificationCooldown.defaultSeconds
    }

    /// The UserDefaults key for a rule's cooldown seconds.
    public static func userDefaultsKey(for ruleID: String) -> String {
        "grau.rule.\(ruleID).cooldown"
    }
}
