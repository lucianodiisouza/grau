//
//  ResidualFinder.swift
//  graucore
//
//  Given an InstalledApp, find all its residual data in the user's
//  Library. The group containers are looked up via the app's
//  com.apple.security.application-groups entitlement, NOT
//  derived from the bundle ID (see docs/REVIEW.md B4).
//

import Foundation

public actor ResidualFinder {

    private let sizer: DirectorySizer

    public init(sizer: DirectorySizer = DirectorySizer()) {
        self.sizer = sizer
    }

    /// Finds all residuals for the given app. Sizes each residual
    /// directory in parallel; total size is the sum.
    public func findResiduals(for app: InstalledApp) async -> [Residual] {
        let home = FileManager.default.homeDirectoryForCurrentUser
        let library = home.appendingPathComponent("Library", isDirectory: true)
        let bundleID = app.id
        let paths = candidatePaths(
            for: bundleID,
            groupContainerIDs: app.groupContainerIDs,
            in: library
        )
        var residuals: [Residual] = []
        for (kind, path) in paths {
            if let residual = await sizeResidual(kind: kind, path: path) {
                residuals.append(residual)
            }
        }
        return residuals
    }

    private func candidatePaths(
        for bundleID: String,
        groupContainerIDs: [String],
        in library: URL
    ) -> [(ResidualKind, URL)] {
        var paths: [(ResidualKind, URL)] = []
        paths.append((.preferences, library.appendingPathComponent("Preferences/\(bundleID).plist")))
        paths.append((.caches, library.appendingPathComponent("Caches/\(bundleID)")))
        paths.append((.appSupport, library.appendingPathComponent("Application Support/\(bundleID)")))
        paths.append((.logs, library.appendingPathComponent("Logs/\(bundleID)")))
        paths.append((.savedState, library.appendingPathComponent("Saved Application State/\(bundleID).savedState")))
        paths.append((.cookies, library.appendingPathComponent("Cookies/\(bundleID).binarycookies")))
        paths.append((.containers, library.appendingPathComponent("Containers/\(bundleID)")))
        for groupID in groupContainerIDs {
            paths.append((
                .groupContainers,
                library.appendingPathComponent("Group Containers/\(groupID)")
            ))
        }
        // Launch agent: rare, but cheap to check.
        paths.append((.launchAgents, library.appendingPathComponent("LaunchAgents/\(bundleID).plist")))
        return paths
    }

    private func sizeResidual(kind: ResidualKind, path: URL) async -> Residual? {
        let fm = FileManager.default
        var isDir: ObjCBool = false
        guard fm.fileExists(atPath: path.path, isDirectory: &isDir) else {
            return nil
        }

        if isDir.boolValue {
            let sizer = DirectorySizer()
            var totalBytes: Int64 = 0
            for await event in sizer.size(root: path) {
                if case .completed(_, let size) = event {
                    totalBytes = size.bytes
                }
            }
            if totalBytes > 0 {
                return Residual(kind: kind, path: path, size: ByteSize(bytes: totalBytes))
            } else {
                return nil
            }
        } else {
            // File (e.g. preferences .plist)
            let size = (try? fm.attributesOfItem(atPath: path.path)[.size] as? Int64) ?? 0
            if size > 0 {
                return Residual(kind: kind, path: path, size: ByteSize(bytes: size))
            } else {
                return nil
            }
        }
    }
}
