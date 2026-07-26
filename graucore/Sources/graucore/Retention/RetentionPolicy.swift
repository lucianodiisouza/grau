//
//  RetentionPolicy.swift
//  graucore
//
//  Per-artifact-kind retention windows. Each window is a number of
//  days; entries older than that age are eligible for pruning by
//  `RetentionEngine`. A window of 0 means "never prune this kind".
//
//  Policy is stored at `~/.grau/retention-policy.json` via
//  `RetentionPolicyStore`. Defaults are applied for any kind not
//  explicitly configured.
//
//  v1.7 feature. Phase 12.1.
//

import Foundation

/// The kind of artifact Grau manages. Each kind has its own
/// retention window.
public enum RetentionKind: String, CaseIterable, Codable, Sendable, Identifiable {
    /// Entries in `~/.grau/notification-log.json`.
    case notificationLog
    /// Per-operation manifest files under
    /// `~/.grau/trash-manifests/*.json`.
    case trashManifest
    /// `scanHistory` array in `~/.grau/state.json`.
    case scanHistory

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .notificationLog: "Notification log"
        case .trashManifest:   "Trash manifests"
        case .scanHistory:     "Scan history"
        }
    }

    /// Default retention in days. Used when a kind is not explicitly
    /// configured. 0 means "never expire". Conservative defaults;
    /// users can opt into more aggressive pruning.
    public var defaultDays: Int {
        switch self {
        case .notificationLog: 90   // ~3 months of notification history
        case .trashManifest:   30   // manifests older than a month are unlikely
                                    // to be restored
        case .scanHistory:     0    // scan history is small; keep forever by default
        }
    }
}

/// A single retention window for one kind.
public struct RetentionWindow: Codable, Sendable, Equatable, Hashable {
    public let kind: RetentionKind
    /// Days to keep. 0 means "never prune".
    public let days: Int

    public init(kind: RetentionKind, days: Int) {
        self.kind = kind
        // Clamp to a sensible range: 0 (forever) or 1..3650 (10y).
        let clamped = max(0, min(days, 3650))
        self.days = clamped
    }
}

/// The full retention configuration. A mapping from `RetentionKind`
/// to its window. `days(for:)` returns the configured days, or the
/// kind's default if absent.
public struct RetentionPolicy: Codable, Sendable, Equatable {
    public private(set) var windows: [RetentionKind: RetentionWindow]

    public init(windows: [RetentionKind: RetentionWindow] = [:]) {
        self.windows = windows
    }

    /// The "no customization" default policy. Each kind resolves to
    /// its `RetentionKind.defaultDays`.
    public static let `default`: RetentionPolicy = RetentionPolicy()

    public func days(for kind: RetentionKind) -> Int {
        if let explicit = windows[kind] {
            return explicit.days
        }
        return kind.defaultDays
    }

    /// True if pruning is disabled for this kind (0 days).
    public func isForever(_ kind: RetentionKind) -> Bool {
        days(for: kind) == 0
    }

    /// Returns a new policy with the given window set for `kind`.
    public func setting(_ window: RetentionWindow) -> RetentionPolicy {
        var copy = self
        copy.windows[window.kind] = window
        return copy
    }

    /// Returns a new policy with the given kind's window cleared
    /// (falls back to default).
    public func clearing(_ kind: RetentionKind) -> RetentionPolicy {
        var copy = self
        copy.windows.removeValue(forKey: kind)
        return copy
    }

    /// All configured windows, sorted by `RetentionKind.allCases` for
    /// stable UI rendering.
    public var sortedWindows: [RetentionWindow] {
        RetentionKind.allCases.map { kind in
            windows[kind] ?? RetentionWindow(kind: kind, days: kind.defaultDays)
        }
    }
}
