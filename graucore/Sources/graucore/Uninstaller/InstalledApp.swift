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

    /// Total size of the `.app` bundle on disk, in bytes. Defaults
    /// to `0` (unknown) when the caller has not yet computed it —
    /// `AppScanner.scan()` returns apps with this set to 0, and the
    /// caller fills it in incrementally (see `UninstallerViewModel`).
    /// Use `bundleSize > 0` as the "known" signal in the UI.
    public let bundleSize: Int64

    public init(
        id: String,
        name: String,
        installedVersion: String,
        bundleURL: URL,
        iconData: Data? = nil,
        lastModified: Date? = nil,
        groupContainerIDs: [String] = [],
        hasUninstallHelper: Bool = false,
        helperPath: URL? = nil,
        bundleSize: Int64 = 0
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
        self.bundleSize = bundleSize
    }

    /// True if the bundle ID starts with "com.apple." — these are
    /// Apple system components. We refuse to uninstall them unless
    /// the user explicitly opts in.
    public var isAppleSystemComponent: Bool {
        id.hasPrefix("com.apple.")
    }
}
