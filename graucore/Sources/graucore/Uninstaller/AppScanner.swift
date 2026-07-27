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
    ///
    /// `bundleSize` is left as `0` on the returned entries — the
    /// caller is expected to populate it incrementally (computing
    /// the size of every `.app` synchronously would block the scan
    /// for several seconds on systems with large apps like Xcode).
    /// Use `scan(withSizes:)` to compute sizes in parallel before
    /// returning, or use `size(for:)` to compute a single bundle.
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

    /// Variant of `scan()` that also computes each bundle's size
    /// in parallel before returning. Slower to return the list, but
    /// every entry has a real `bundleSize` populated. Honors
    /// `Task.isCancelled`.
    public func scan(withSizes: Void) async -> [InstalledApp] {
        var apps = await scan()
        await withTaskGroup(of: (Int, Int64).self) { group in
            for (idx, app) in apps.enumerated() {
                let url = app.bundleURL
                group.addTask {
                    let size = Self.computeBundleSize(at: url)
                    return (idx, size)
                }
            }
            for await (idx, size) in group {
                if Task.isCancelled { break }
                apps[idx] = apps[idx].withBundleSize(size)
            }
        }
        return apps
    }

    /// Computes the size of a single `.app` bundle on disk. Counts
    /// hardlinks once. Returns 0 on error (e.g. bundle deleted
    /// between scan and size). Uses an *empty* exclusion set so
    /// every file inside the bundle is counted, even if the path
    /// happens to start with something `PathExclusions.standard`
    /// would normally skip (e.g. a symlinked framework).
    public static func computeBundleSize(at bundleURL: URL) -> Int64 {
        do {
            let sizer = DirectorySizer(
                exclusions: PathExclusions(
                    prefixes: [],
                    suffixes: [],
                    appleComponents: []
                )
            )
            return try sizer.sizeSync(root: bundleURL).bytes
        } catch {
            return 0
        }
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

private extension InstalledApp {
    /// Returns a copy with `bundleSize` replaced. We can't mutate
    /// the struct in place from the caller's context because
    /// `bundleSize` is `let`, so this gives us a clean replacement.
    func withBundleSize(_ size: Int64) -> InstalledApp {
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
            bundleSize: size,
            lastUsedDate: lastUsedDate
        )
    }
}
