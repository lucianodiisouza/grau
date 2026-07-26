//
//  PermissionKind.swift
//  graucore
//
//  The permissions Grau cares about. See docs/PERMISSIONS.md.
//

import Foundation

public enum PermissionKind: String, CaseIterable, Sendable {
    /// Full Disk Access (TCC). Required to read /Library/Caches,
    /// /private/var/log, Mail data, and other apps' sandboxed data.
    case fullDiskAccess

    /// User Notifications. Used by the menu bar notifications.
    case notifications

    /// AppleEvents. We do NOT use these in v1 (see PERMISSIONS.md
    /// § 3.2). Listed here for completeness / v2 use.
    case automation
}

public enum NotificationPermission: String, Sendable, Equatable {
    case notRequested
    case denied
    case provisional
    case authorized
}

public struct PermissionState: Equatable, Sendable {
    public var fullDiskAccess: Bool
    public var notifications: NotificationPermission
    public var appleEventsPromptedForFinder: Bool

    public init(
        fullDiskAccess: Bool = false,
        notifications: NotificationPermission = .notRequested,
        appleEventsPromptedForFinder: Bool = false
    ) {
        self.fullDiskAccess = fullDiskAccess
        self.notifications = notifications
        self.appleEventsPromptedForFinder = appleEventsPromptedForFinder
    }

    public static let unknown = PermissionState()
}
