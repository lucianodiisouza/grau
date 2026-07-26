//
//  DirectorySizer.swift
//  graucore
//
//  Parallel directory size computation. Dedupes hardlinks so
//  shared inodes aren't double-counted. See docs/ARCHITECTURE.md
//  § 4 and docs/REVIEW.md (no separate HardlinkChecker file —
//  logic is inlined here).
//

import Foundation

public struct DirectorySizer: Sendable {

    public var exclusions: PathExclusionsProvider

    public init(exclusions: PathExclusionsProvider = PathExclusions.standard) {
        self.exclusions = exclusions
    }

    public enum SizerEvent: Sendable {
        case progress(URL, ByteSize)            // cumulative running total
        case completed(root: URL, size: ByteSize)
    }

    /// Computes the total size of `root` and all its contents.
    /// Hardlinks are counted once per unique inode. Honors
    /// `Task.isCancelled`. Streams `SizerEvent.progress` for
    /// UI feedback. Returns the final size.
    public func size(
        root: URL,
        followSymlinks: Bool = false
    ) -> AsyncStream<SizerEvent> {
        AsyncStream { continuation in
            let task = Task {
                let seenInodes = SeenInodes()
                let total = await Self.computeSize(
                    url: root,
                    followSymlinks: followSymlinks,
                    exclusions: exclusions,
                    seenInodes: seenInodes,
                    continuation: continuation
                )
                continuation.yield(.completed(root: root, size: total))
                continuation.finish()
            }
            continuation.onTermination = { _ in
                task.cancel()
            }
        }
    }

    /// Synchronous version for small directories. Used by the
    /// SizeCache when mtime is unchanged.
    public func sizeSync(root: URL) throws -> ByteSize {
        let fm = FileManager.default
        var total: Int64 = 0
        var seen: Set<UInt64> = []
        try Self.computeSizeSync(
            url: root, fm: fm, total: &total, seen: &seen, exclusions: exclusions
        )
        return ByteSize(bytes: total)
    }

    private actor SeenInodes {
        private var set: Set<UInt64> = []

        func contains(_ inode: UInt64) -> Bool { set.contains(inode) }
        func insert(_ inode: UInt64) { set.insert(inode) }
        var count: Int {
            get { set.count }
        }
    }

    private static func computeSize(
        url: URL,
        followSymlinks: Bool,
        exclusions: PathExclusionsProvider,
        seenInodes: SeenInodes,
        continuation: AsyncStream<SizerEvent>.Continuation
    ) async -> ByteSize {
        if Task.isCancelled { return .zero }

        let path = url.path
        if exclusions.shouldExclude(absolutePath: path) { return .zero }

        let fm = FileManager.default
        var isDir: ObjCBool = false
        guard fm.fileExists(atPath: path, isDirectory: &isDir) else { return .zero }

        if !isDir.boolValue {
            // File: get size + inode
            let attrs = try? fm.attributesOfItem(atPath: path)
            let size = (attrs?[.size] as? Int64) ?? 0
            if let inode = (attrs?[.systemFileNumber] as? NSNumber)?.uint64Value {
                let already = await seenInodes.contains(inode)
                if already { return .zero }
                await seenInodes.insert(inode)
            }
            let bs = ByteSize(bytes: size)
            continuation.yield(.progress(url, bs))
            return bs
        }

        // Directory: recurse in parallel
        let children: [URL]
        do {
            children = try fm.contentsOfDirectory(
                at: url,
                includingPropertiesForKeys: nil,
                options: [.skipsHiddenFiles, .skipsPackageDescendants]
            )
        } catch {
            return .zero
        }

        let results = await withTaskGroup(
            of: ByteSize.self,
            returning: ByteSize.self
        ) { group in
            for child in children {
                group.addTask {
                    await computeSize(
                        url: child,
                        followSymlinks: followSymlinks,
                        exclusions: exclusions,
                        seenInodes: seenInodes,
                        continuation: continuation
                    )
                }
            }
            var total: ByteSize = .zero
            for await child in group {
                total += child
            }
            return total
        }
        continuation.yield(.progress(url, results))
        return results
    }

    private static func computeSizeSync(
        url: URL,
        fm: FileManager,
        total: inout Int64,
        seen: inout Set<UInt64>,
        exclusions: PathExclusionsProvider
    ) throws {
        let path = url.path
        if exclusions.shouldExclude(absolutePath: path) { return }
        var isDir: ObjCBool = false
        guard fm.fileExists(atPath: path, isDirectory: &isDir) else { return }
        if !isDir.boolValue {
            let attrs = try fm.attributesOfItem(atPath: path)
            let size = (attrs[.size] as? Int64) ?? 0
            if let inode = (attrs[.systemFileNumber] as? NSNumber)?.uint64Value {
                if seen.contains(inode) { return }
                seen.insert(inode)
            }
            total += size
            return
        }
        let children = try fm.contentsOfDirectory(
            at: url,
            includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles, .skipsPackageDescendants]
        )
        for child in children {
            try computeSizeSync(
                url: child, fm: fm, total: &total, seen: &seen, exclusions: exclusions
            )
        }
    }
}
