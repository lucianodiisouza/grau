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

    /// When the app was last launched, from Spotlight's
    /// `kMDItemLastUsedDate` attribute. `nil` when Spotlight has
    /// no record (the app was never launched, Spotlight is
    /// disabled, or the index is cold). Used for the "Latest
    /// Opened" sort option in the Uninstaller view; not
    /// populated by `AppScanner.scan()` — the view fetches it
    /// in a background pass (see `AppScanner.loadLastUsedDates`).
    public let lastUsedDate: Date?

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
        bundleSize: Int64 = 0,
        lastUsedDate: Date? = nil
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
        self.lastUsedDate = lastUsedDate
    }

    /// True if the bundle ID starts with "com.apple." — these are
    /// Apple system components. We refuse to uninstall them unless
    /// the user explicitly opts in.
    public var isAppleSystemComponent: Bool {
        id.hasPrefix("com.apple.")
    }

    /// Returns a copy of this app with `lastUsedDate` replaced.
    /// Used by the Uninstaller view's background Spotlight pass
    /// (`UninstallerViewModel.loadLastUsedDates`) to stream the
    /// "last opened" timestamp into each entry without forcing
    /// the caller to rebuild the struct by hand. `lastUsedDate`
    /// is `let` on the struct, so a copy is the only way to
    /// "mutate" it.
    public func withLastUsedDate(_ date: Date?) -> InstalledApp {
        InstalledApp(
            id: id,
            name: name,
            installedVersion: installedVersion,
            bundleURL: bundleURL,
            iconData: iconData,
            lastModified: lastModified,
            groupContainerIDs: groupContainerIDs,
            hasUninstallHelper: hasUninstallHelper,
            helperPath: helperPath,
            bundleSize: bundleSize,
            lastUsedDate: date
        )
    }
}
