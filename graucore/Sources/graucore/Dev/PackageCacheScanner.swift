//
//  PackageCacheScanner.swift
//  graucore
//
//  Scans the 16 package manager caches and reports their sizes.
//

import Foundation

public struct PackageCacheInfo: Identifiable, Hashable, Sendable {
    public let id: UUID
    public let kind: PackageCacheKind
    public let paths: [URL]
    public let size: ByteSize
    public let exists: Bool

    public init(
        id: UUID = UUID(),
        kind: PackageCacheKind,
        paths: [URL],
        size: ByteSize,
        exists: Bool
    ) {
        self.id = id
        self.kind = kind
        self.paths = paths
        self.size = size
        self.exists = exists
    }
}

public actor PackageCacheScanner {

    public init() {}

    /// Scans all 16 package manager caches. Skips ones that don't
    /// exist on the host.
    public func scan(
        kinds: [PackageCacheKind] = PackageCacheKind.allCases
    ) async -> [PackageCacheInfo] {
        let sizer = DirectorySizer()
        return await withTaskGroup(
            of: PackageCacheInfo.self,
            returning: [PackageCacheInfo].self
        ) { group in
            for kind in kinds {
                group.addTask {
                    var totalBytes: Int64 = 0
                    var existingPaths: [URL] = []
                    var anyExists = false
                    for path in kind.defaultPaths {
                        if !FileManager.default.fileExists(atPath: path.path) {
                            continue
                        }
                        anyExists = true
                        existingPaths.append(path)
                        for await event in sizer.size(root: path) {
                            if case .completed(_, let size) = event {
                                totalBytes += size.bytes
                            }
                        }
                    }
                    return PackageCacheInfo(
                        kind: kind,
                        paths: existingPaths,
                        size: ByteSize(bytes: totalBytes),
                        exists: anyExists
                    )
                }
            }
            var results: [PackageCacheInfo] = []
            for await info in group {
                results.append(info)
            }
            return results.sorted { $0.size > $1.size }
        }
    }
}
