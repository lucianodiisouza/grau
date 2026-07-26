//
//  BundleMetadata.swift
//  graucore
//
//  Loads Info.plist from a .app bundle. Defensive — every field
//  is optional; if the plist is missing or malformed, the loader
//  returns nil.
//

import Foundation

public struct BundleMetadata: Sendable {
    public let bundleID: String?
    public let name: String?
    public let shortVersion: String?
    public let buildVersion: String?
    public let groupContainerIDs: [String]   // com.apple.security.application-groups
    public let hasUninstallHelper: Bool
    public let helperPath: URL?

    public init(
        bundleID: String?,
        name: String?,
        shortVersion: String?,
        buildVersion: String?,
        groupContainerIDs: [String],
        hasUninstallHelper: Bool,
        helperPath: URL?
    ) {
        self.bundleID = bundleID
        self.name = name
        self.shortVersion = shortVersion
        self.buildVersion = buildVersion
        self.groupContainerIDs = groupContainerIDs
        self.hasUninstallHelper = hasUninstallHelper
        self.helperPath = helperPath
    }
}

public enum BundleMetadataLoader {

    /// Loads Info.plist from `bundleURL`. Returns nil on any error.
    public static func load(_ bundleURL: URL) -> BundleMetadata? {
        let plistURL = bundleURL.appendingPathComponent("Contents/Info.plist")
        guard let dict = NSDictionary(contentsOf: plistURL) as? [String: Any] else {
            return nil
        }
        let bundleID = dict["CFBundleIdentifier"] as? String
        let name = (dict["CFBundleDisplayName"] as? String)
            ?? (dict["CFBundleName"] as? String)
        let shortVersion = dict["CFBundleShortVersionString"] as? String
        let buildVersion = dict["CFBundleVersion"] as? String

        // com.apple.security.application-groups is an array of strings.
        let groupContainerIDs: [String] = (dict["com.apple.security.application-groups"] as? [String]) ?? []

        // Pre-uninstall helper: Contents/Resources/Uninstall.app
        let helperURL = bundleURL
            .appendingPathComponent("Contents/Resources/Uninstall.app")
        let hasHelper = FileManager.default.fileExists(atPath: helperURL.path)

        return BundleMetadata(
            bundleID: bundleID,
            name: name,
            shortVersion: shortVersion,
            buildVersion: buildVersion,
            groupContainerIDs: groupContainerIDs,
            hasUninstallHelper: hasHelper,
            helperPath: hasHelper ? helperURL : nil
        )
    }
}
