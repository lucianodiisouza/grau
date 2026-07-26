//
//  JunkScanner.swift
//  graucore
//
//  Scans one or more JunkDefinitions in parallel. Honors
//  Task.isCancelled. Yields JunkResult per category as it
//  completes. The 8-critical-modules list per docs/ARCHITECTURE.md
//  § 5.1 includes this.
//

import Foundation

public actor JunkScanner {

    private let sizer: DirectorySizer
    private let sizeCacheStore: SizeCacheStore

    public init(
        sizer: DirectorySizer = DirectorySizer(),
        sizeCacheStore: SizeCacheStore = SizeCacheStore()
    ) {
        self.sizer = sizer
        self.sizeCacheStore = sizeCacheStore
    }

    /// Maximum number of items kept per category in a `JunkResult`.
    /// Larger lists are sliced down to the top N by size.
    public static let topItemsLimit = 1_000

    /// Scans all `definitions`. Categories with `requiresFDA = true`
    /// are skipped (and reported with `skipped: true`) when
    /// `fdaGranted` is `false`.
    public func scan(
        definitions: [JunkDefinition],
        fdaGranted: Bool
    ) async -> [JunkResult] {
        await withTaskGroup(of: JunkResult.self) { group in
            for definition in definitions {
                group.addTask { [self] in
                    await scanCategory(definition, fdaGranted: fdaGranted)
                }
            }
            var results: [JunkResult] = []
            for await result in group {
                results.append(result)
            }
            return results.sorted { $0.category.displayName < $1.category.displayName }
        }
    }

    private func scanCategory(
        _ definition: JunkDefinition,
        fdaGranted: Bool
    ) async -> JunkResult {
        if Task.isCancelled {
            return JunkResult(
                category: definition.id,
                size: .zero,
                items: [],
                scanDuration: 0,
                skipped: true,
                skipReason: "Cancelled"
            )
        }
        if definition.requiresFDA && !fdaGranted {
            return JunkResult(
                category: definition.id,
                size: .zero,
                items: [],
                scanDuration: 0,
                skipped: true,
                skipReason: "Full Disk Access not granted"
            )
        }

        let start = Date()
        var totalSize: Int64 = 0
        var allItems: [JunkItem] = []

        for path in definition.paths {
            if Task.isCancelled { break }
            // Try cache first
            if let mtime = try? FileManager.default
                .attributesOfItem(atPath: path.path)[.modificationDate] as? Date,
               let cached = await sizeCacheStore.cachedSize(
                for: path, currentMtime: mtime
               ) {
                totalSize += cached
                continue
            }
            // Compute
            let sizer = DirectorySizer()
            var items: [JunkItem] = []
            for await event in sizer.size(root: path) {
                if Task.isCancelled { break }
                switch event {
                case .progress(let url, let size):
                    items.append(JunkItem(path: url, size: size, isDirectory: false))
                case .completed(_, let size):
                    totalSize += size.bytes
                    if let mtime = try? FileManager.default
                        .attributesOfItem(atPath: path.path)[.modificationDate] as? Date {
                        await sizeCacheStore.record(path: path, size: size.bytes, mtime: mtime)
                    }
                }
            }
            allItems.append(contentsOf: items)
        }

        // Keep only the top N by size
        let topItems = allItems
            .sorted { $0.size > $1.size }
            .prefix(Self.topItemsLimit)

        return JunkResult(
            category: definition.id,
            size: ByteSize(bytes: totalSize),
            items: Array(topItems),
            scanDuration: Date().timeIntervalSince(start)
        )
    }
}
