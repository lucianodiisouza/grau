//
//  AppScanner.swift
//  graucore
//
//  Walks the standard install directories and returns
//  InstalledApp entries. Skips /System/Applications.
//

import Foundation

public actor AppScanner {

    public static let defaultSearchPaths: [URL] = [
        URL(fileURLWithPath: "/Applications", isDirectory: true),
        URL(fileURLWithPath: "/Applications/Utilities", isDirectory: true),
        FileManager.default
            .homeDirectoryForCurrentUser
            .appendingPathComponent("Applications", isDirectory: true),
    ]

    public let searchPaths: [URL]

    public init(searchPaths: [URL] = AppScanner.defaultSearchPaths) {
        self.searchPaths = searchPaths
    }

    /// Scans the search paths and returns every installed app that
    /// has a parseable Info.plist. Results are sorted by name.
    public func scan() async -> [InstalledApp] {
        let fm = FileManager.default
        var collected: [InstalledApp] = []
        for base in searchPaths {
            guard let enumerator = fm.enumerator(
                at: base,
                includingPropertiesForKeys: [.isDirectoryKey],
                options: [.skipsHiddenFiles, .skipsPackageDescendants]
            ) else { continue }

            for case let url as URL in enumerator {
                guard url.pathExtension == "app" else { continue }
                if url.path.contains("/System/Applications/") { continue }
                if let app = makeInstalledApp(at: url) {
                    collected.append(app)
                }
            }
        }
        // Dedupe by bundle id (or path if no id), prefer first
        var seen = Set<String>()
        var unique: [InstalledApp] = []
        for app in collected.sorted(by: { $0.name.lowercased() < $1.name.lowercased() }) {
            if seen.insert(app.id).inserted {
                unique.append(app)
            }
        }
        return unique
    }

    private func makeInstalledApp(at bundleURL: URL) -> InstalledApp? {
        guard let meta = BundleMetadataLoader.load(bundleURL) else { return nil }
        let name = meta.name ?? bundleURL.deletingPathExtension().lastPathComponent
        let version = meta.shortVersion ?? "unknown"
        let id = meta.bundleID
            ?? "grau.path.\(bundleURL.path.hashValue)"
        let lastModified = (try? FileManager.default
            .attributesOfItem(atPath: bundleURL.path)[.modificationDate] as? Date) ?? nil
        return InstalledApp(
            id: id,
            name: name,
            installedVersion: version,
            bundleURL: bundleURL,
            iconData: nil,         // icon rendering is in the app target
            lastModified: lastModified,
            groupContainerIDs: meta.groupContainerIDs,
            hasUninstallHelper: meta.hasUninstallHelper,
            helperPath: meta.helperPath
        )
    }
}
