//
//  AutoCleanRule.swift
//  graucore
//
//  A user-defined "if X happens, do Y" automation. The condition
//  is currently a simple threshold on a gauge (trash size, junk
//  size, disk usage). The action is one of the engine's
//  `AutoCleanAction` cases. A rule can be enabled/disabled and
//  has a minimum-interval between firings so it can't loop.
//
//  Rules persist to `~/.grau/auto-clean.json` via `AutoCleanStore`.
//  v1.7 feature. Phase 12.2.
//

import Foundation

/// The set of conditions that can trigger an auto-clean rule.
public enum AutoCleanCondition: Codable, Sendable, Equatable, Hashable {
    /// Trash size on disk crosses `bytes`. The engine reads
    /// `~/.Trash` recursively.
    case trashSizeExceeds(bytes: Int64)
    /// Junk scan total crosses `bytes`. The engine reads the most
    /// recent `lastJunkScan` summary.
    case junkSizeExceeds(bytes: Int64)
    /// Root volume usage crosses `fraction` (0.0–1.0). The engine
    /// reads `VolumeMonitor`.
    case diskUsageExceeds(fraction: Double)
    /// A specific calendar time of day (HH:MM) is reached. The
    /// engine checks against `Date` rounded to the minute.
    case timeOfDay(hour: Int, minute: Int)

    private enum CodingKeys: String, CodingKey {
        case kind, bytes, fraction, hour, minute
    }

    private enum Kind: String, Codable {
        case trashSize, junkSize, diskUsage, timeOfDay
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let kind = try c.decode(Kind.self, forKey: .kind)
        switch kind {
        case .trashSize:
            self = .trashSizeExceeds(bytes: try c.decode(Int64.self, forKey: .bytes))
        case .junkSize:
            self = .junkSizeExceeds(bytes: try c.decode(Int64.self, forKey: .bytes))
        case .diskUsage:
            self = .diskUsageExceeds(fraction: try c.decode(Double.self, forKey: .fraction))
        case .timeOfDay:
            self = .timeOfDay(
                hour: try c.decode(Int.self, forKey: .hour),
                minute: try c.decode(Int.self, forKey: .minute)
            )
        }
    }

    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .trashSizeExceeds(let bytes):
            try c.encode(Kind.trashSize, forKey: .kind)
            try c.encode(bytes, forKey: .bytes)
        case .junkSizeExceeds(let bytes):
            try c.encode(Kind.junkSize, forKey: .kind)
            try c.encode(bytes, forKey: .bytes)
        case .diskUsageExceeds(let fraction):
            try c.encode(Kind.diskUsage, forKey: .kind)
            try c.encode(fraction, forKey: .fraction)
        case .timeOfDay(let h, let m):
            try c.encode(Kind.timeOfDay, forKey: .kind)
            try c.encode(h, forKey: .hour)
            try c.encode(m, forKey: .minute)
        }
    }

    /// A short, user-facing summary of the condition.
    public var summary: String {
        switch self {
        case .trashSizeExceeds(let b):
            return "Trash > \(ByteSize(bytes: b).humanReadable)"
        case .junkSizeExceeds(let b):
            return "Junk > \(ByteSize(bytes: b).humanReadable)"
        case .diskUsageExceeds(let f):
            return "Disk usage > \(Int(f * 100))%"
        case .timeOfDay(let h, let m):
            return String(format: "At %02d:%02d", h, m)
        }
    }
}

/// The set of actions an auto-clean rule can take. Kept narrow on
/// purpose: only reversible operations. We never auto-delete files.
public enum AutoCleanAction: String, Codable, Sendable, CaseIterable, Hashable {
    /// Run the retention engine. Manifests older than the policy
    /// are deleted (and so are expired notification entries).
    case runRetention
    /// Move the contents of the user's trash to a new manifest,
    /// leaving them in the trash (so the user can still restore).
    /// In practice this re-batches the trash; the manifest is
    /// rewritten with the current items.
    case reindexTrash
    /// Append a synthetic entry to the notification log so the
    /// user sees "auto-clean ran at HH:MM" in the Notification
    /// Center. Doesn't fire a system notification.
    case logSummary

    public var displayName: String {
        switch self {
        case .runRetention: "Prune old manifests & logs"
        case .reindexTrash: "Reindex trash"
        case .logSummary: "Log a summary"
        }
    }
}

/// One user-defined rule. Identified by `id` (UUID) so the order in
/// the array doesn't matter.
public struct AutoCleanRule: Codable, Sendable, Equatable, Identifiable, Hashable {
    public let id: UUID
    public var name: String
    public var condition: AutoCleanCondition
    public var action: AutoCleanAction
    public var enabled: Bool
    /// Minimum seconds between two firings of this rule. Prevents
    /// the rule from looping if the condition stays true.
    public var cooldownSeconds: TimeInterval
    public var createdAt: Date
    public var lastFiredAt: Date?

    public init(
        id: UUID = UUID(),
        name: String,
        condition: AutoCleanCondition,
        action: AutoCleanAction,
        enabled: Bool = true,
        cooldownSeconds: TimeInterval = 6 * 3600,  // 6h default
        createdAt: Date = Date(),
        lastFiredAt: Date? = nil
    ) {
        self.id = id
        self.name = name
        self.condition = condition
        self.action = action
        self.enabled = enabled
        self.cooldownSeconds = cooldownSeconds
        self.createdAt = createdAt
        self.lastFiredAt = lastFiredAt
    }

    /// True if this rule is allowed to fire right now, given the
    /// current time and its cooldown.
    public func canFire(now: Date) -> Bool {
        guard enabled else { return false }
        guard let last = lastFiredAt else { return true }
        return now.timeIntervalSince(last) >= cooldownSeconds
    }
}
