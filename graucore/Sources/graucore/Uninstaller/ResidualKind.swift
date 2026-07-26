//
//  ResidualKind.swift
//  graucore
//
//  Categories of residual data that an app leaves in the user's
//  Library. Note: NO `keychainEntries` (see docs/REVIEW.md B3).
//

import Foundation

public enum ResidualKind: String, CaseIterable, Sendable, Codable {
    case preferences
    case caches
    case appSupport
    case logs
    case savedState
    case cookies
    case containers
    case groupContainers
    case launchAgents

    public var displayName: String {
        switch self {
        case .preferences:      "Preferences"
        case .caches:          "Caches"
        case .appSupport:      "Application Support"
        case .logs:            "Logs"
        case .savedState:      "Saved State"
        case .cookies:         "Cookies"
        case .containers:      "Containers"
        case .groupContainers: "Group Containers"
        case .launchAgents:    "Launch Agents"
        }
    }

    /// True if these residuals may contain user data we should
    /// not auto-delete (e.g. cookies, app support).
    public var mayContainUserData: Bool {
        switch self {
        case .preferences, .caches, .logs, .savedState,
             .launchAgents:
            return false
        case .appSupport, .cookies, .containers,
             .groupContainers:
            return true
        }
    }

    /// Default selection state in the UI.
    public var defaultSelected: Bool {
        switch self {
        case .preferences, .caches, .appSupport, .logs,
             .savedState, .cookies, .launchAgents:
            return true
        case .containers, .groupContainers:
            return false
        }
    }
}
