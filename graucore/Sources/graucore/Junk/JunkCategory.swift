//
//  JunkCategory.swift
//  graucore
//
//  The 5 user-facing junk categories. See docs/DATA-SOURCES.md § 1
//  and docs/REVIEW.md S2 (5 not 11).
//

import Foundation

public enum JunkCategory: String, CaseIterable, Sendable, Codable, Identifiable {
    case userCache
    case systemCache
    case logs
    case oldDownloads
    case iosBackups

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .userCache:     "User Cache"
        case .systemCache:   "System Cache"
        case .logs:          "Logs"
        case .oldDownloads:  "Old Downloads"
        case .iosBackups:    "iOS Backups"
        }
    }

    /// Whether this category is opt-in (userCaution). The UI
    /// initialises its checkbox from `JunkDefinition.defaultSelected`
    /// but the documentation intent is the same.
    public var requiresExplicitOptIn: Bool {
        switch self {
        case .userCache, .systemCache, .logs: return false
        case .oldDownloads, .iosBackups:     return true
        }
    }
}

public enum SafetyLevel: String, Sendable, Codable {
    /// Deleting is always safe.
    case safe
    /// Deleting is safe if the user understands what they're
    /// deleting (e.g., downloads older than N days).
    case safeWithCare
    /// Explicit opt-in required.
    case userCaution
}
