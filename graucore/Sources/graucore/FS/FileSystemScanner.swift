//
//  FileSystemScanner.swift
//  graucore
//
//  AsyncStream-based filesystem walker. Honors Task cancellation.
//  Skips paths in PathExclusions. The single primitive every
//  feature uses. See docs/ARCHITECTURE.md § 4 and
//  docs/REVIEW.md S4 (struct, not actor).
//

import Foundation

/// A filesystem walker that yields URLs as it descends. Created per
/// scan; cheap to allocate. Honors `Task.isCancelled` between
/// batches.
public struct FileSystemScanner: Sendable {

    /// Custom exclusion set, primarily for testing. Production code
    /// uses the default (`PathExclusions.standard`).
    public var exclusions: PathExclusionsProvider

    public init(exclusions: PathExclusionsProvider = PathExclusions.standard) {
        self.exclusions = exclusions
    }

    public enum WalkEvent: Sendable {
        case file(URL)
        case directory(URL)
        case error(URL, Error)
    }

    /// Walks `root` recursively. Yields every file and directory
    /// (including intermediate ones) as events. Honors
    /// `Task.isCancelled` between batches. Skips paths in
    /// `exclusions`.
    public func walk(
        root: URL,
        followSymlinks: Bool = false
    ) -> AsyncStream<WalkEvent> {
        AsyncStream { continuation in
            let task = Task {
                await Self.walkRecursive(
                    url: root,
                    followSymlinks: followSymlinks,
                    exclusions: exclusions,
                    continuation: continuation
                )
                continuation.finish()
            }
            continuation.onTermination = { _ in
                task.cancel()
            }
        }
    }

    /// Collects every file URL in `root` into an array. Skips
    /// paths in `exclusions`. Honors cancellation.
    public func collectFiles(
        root: URL,
        followSymlinks: Bool = false
    ) async throws -> [URL] {
        var result: [URL] = []
        for await event in walk(root: root, followSymlinks: followSymlinks) {
            try Task.checkCancellation()
            if case .file(let url) = event {
                result.append(url)
            }
        }
        return result
    }

    private static func walkRecursive(
        url: URL,
        followSymlinks: Bool,
        exclusions: PathExclusionsProvider,
        continuation: AsyncStream<WalkEvent>.Continuation
    ) async {
        if Task.isCancelled { return }

        let path = url.path
        if exclusions.shouldExclude(absolutePath: path) { return }

        let fm = FileManager.default
        var isDir: ObjCBool = false
        guard fm.fileExists(atPath: path, isDirectory: &isDir) else { return }

        if isDir.boolValue {
            continuation.yield(.directory(url))
            do {
                let contents = try fm.contentsOfDirectory(
                    at: url,
                    includingPropertiesForKeys: [.isSymbolicLinkKey],
                    options: [.skipsHiddenFiles, .skipsPackageDescendants]
                )
                for child in contents {
                    if Task.isCancelled { return }
                    let isSymlink = (try? child.resourceValues(forKeys: [.isSymbolicLinkKey]).isSymbolicLink) ?? false
                    if isSymlink && !followSymlinks { continue }
                    await walkRecursive(
                        url: child,
                        followSymlinks: followSymlinks,
                        exclusions: exclusions,
                        continuation: continuation
                    )
                }
            } catch {
                continuation.yield(.error(url, error))
            }
        } else {
            continuation.yield(.file(url))
        }
    }
}

/// Pluggable exclusion strategy. The protocol is defined in
/// `PathExclusions.swift` next to the concrete `PathExclusions`
/// implementation.
