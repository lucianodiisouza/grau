//
//  NodeModulesFinder.swift
//  graucore
//
//  Walks configured roots and finds all `node_modules` directories,
//  reporting their size and the project root (parent of
//  node_modules).
//

import Foundation

public struct NodeModulesInfo: Identifiable, Hashable, Sendable {
    public let id: UUID
    public let path: URL
    public let projectRoot: URL
    public let size: ByteSize
    public let lastModified: Date?

    public init(
        id: UUID = UUID(),
        path: URL,
        projectRoot: URL,
        size: ByteSize,
        lastModified: Date? = nil
    ) {
        self.id = id
        self.path = path
        self.projectRoot = projectRoot
        self.size = size
        self.lastModified = lastModified
    }
}

public actor NodeModulesFinder {

    public nonisolated let defaultRoots: [URL]

    public init(
        defaultRoots: [URL] = NodeModulesFinder.defaultUserRoots()
    ) {
        self.defaultRoots = defaultRoots
    }

    public static func defaultUserRoots() -> [URL] {
        let home = FileManager.default.homeDirectoryForCurrentUser
        var roots: [URL] = [home]  // always include home
        // Add common project dirs if they exist
        for dirName in ["Code", "Developer", "Projects", "repos", "src", "work"] {
            let path = home.appendingPathComponent(dirName, isDirectory: true)
            if FileManager.default.fileExists(atPath: path.path) {
                roots.append(path)
            }
        }
        return roots
    }

    /// Walks each root to depth `maxDepth` and returns every
    /// `node_modules` directory found.
    public func find(maxDepth: Int = 6) async -> [NodeModulesInfo] {
        let sizer = DirectorySizer()
        return await withTaskGroup(
            of: [NodeModulesInfo].self,
            returning: [NodeModulesInfo].self
        ) { group in
            for root in defaultRoots {
                group.addTask {
                    await Self.walkForNodeModules(
                        root: root, maxDepth: maxDepth, currentDepth: 0, sizer: sizer
                    )
                }
            }
            var results: [NodeModulesInfo] = []
            for await sublist in group {
                results.append(contentsOf: sublist)
            }
            return results.sorted { $0.size > $1.size }
        }
    }

    private static func walkForNodeModules(
        root: URL,
        maxDepth: Int,
        currentDepth: Int,
        sizer: DirectorySizer
    ) async -> [NodeModulesInfo] {
        if currentDepth > maxDepth { return [] }
        if Task.isCancelled { return [] }
        if PathExclusions.standard.shouldExclude(absolutePath: root.path) { return [] }
        let fm = FileManager.default
        guard let contents = try? fm.contentsOfDirectory(
            at: root,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles, .skipsPackageDescendants]
        ) else { return [] }

        var results: [NodeModulesInfo] = []
        var childRoots: [URL] = []
        for child in contents {
            var isDir: ObjCBool = false
            guard fm.fileExists(atPath: child.path, isDirectory: &isDir),
                  isDir.boolValue else { continue }
            if child.lastPathComponent == "node_modules" {
                var totalBytes: Int64 = 0
                for await event in sizer.size(root: child) {
                    if case .completed(_, let size) = event {
                        totalBytes = size.bytes
                    }
                }
                let mtime = (try? fm.attributesOfItem(atPath: child.path)[.modificationDate] as? Date) ?? nil
                results.append(NodeModulesInfo(
                    path: child,
                    projectRoot: child.deletingLastPathComponent(),
                    size: ByteSize(bytes: totalBytes),
                    lastModified: mtime
                ))
                // Don't recurse INTO node_modules
            } else {
                childRoots.append(child)
            }
        }
        // Recurse in parallel
        if currentDepth + 1 <= maxDepth {
            let nested = await withTaskGroup(
                of: [NodeModulesInfo].self,
                returning: [NodeModulesInfo].self
            ) { group in
                for child in childRoots {
                    group.addTask {
                        await walkForNodeModules(
                            root: child,
                            maxDepth: maxDepth,
                            currentDepth: currentDepth + 1,
                            sizer: sizer
                        )
                    }
                }
                var all: [NodeModulesInfo] = []
                for await sublist in group {
                    all.append(contentsOf: sublist)
                }
                return all
            }
            results.append(contentsOf: nested)
        }
        return results
    }
}
