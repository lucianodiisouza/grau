//
//  InstalledApp.swift
//  graucore
//
//  A user-installed .app bundle. Note: NO `architecture` field
//  (carried over from the macapps plan but irrelevant for a
//  cleaner app — see docs/REVIEW.md).
//

import Foundation

public struct InstalledApp: Identifiable, Hashable, Sendable {
    public let id: String                // CFBundleIdentifier, or path-hash if missing
    public let name: String              // CFBundleDisplayName || CFBundleName
    public let installedVersion: String  // CFBundleShortVersionString
    public let bundleURL: URL
    public let iconData: Data?
    public let lastModified: Date?
    public let groupContainerIDs: [String]  // from com.apple.security.application-groups
    public let hasUninstallHelper: Bool
    public let helperPath: URL?

    public init(
        id: String,
        name: String,
        installedVersion: String,
        bundleURL: URL,
        iconData: Data? = nil,
        lastModified: Date? = nil,
        groupContainerIDs: [String] = [],
        hasUninstallHelper: Bool = false,
        helperPath: URL? = nil
    ) {
        self.id = id
        self.name = name
        self.installedVersion = installedVersion
        self.bundleURL = bundleURL
        self.iconData = iconData
        self.lastModified = lastModified
        self.groupContainerIDs = groupContainerIDs
        self.hasUninstallHelper = hasUninstallHelper
        self.helperPath = helperPath
    }

    /// True if the bundle ID starts with "com.apple." — these are
    /// Apple system components. We refuse to uninstall them unless
    /// the user explicitly opts in.
    public var isAppleSystemComponent: Bool {
        id.hasPrefix("com.apple.")
    }
}
