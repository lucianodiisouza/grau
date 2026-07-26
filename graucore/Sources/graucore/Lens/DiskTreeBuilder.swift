//
//  DiskTreeBuilder.swift
//  graucore
//
//  Builds a partial disk tree: for a given root, returns the
//  top-N largest immediate children. The user can drill into
//  any child to expand it further (lazy expansion).
//
//  v1 ships a Top-N list view, NOT a full treemap. The full
//  treemap lands in v1.1 per docs/REVIEW.md S3.
//
//  @MainActor so the cache is read/written on the main thread
//  (SwiftUI's render path) without actor-hop overhead. The
//  underlying I/O is still done off-main via TaskGroup.
//

import Foundation

@MainActor
@Observable
public final class DiskTreeBuilder {

    /// Cache of `topFolders` results, keyed by the absolute path
    /// of the folder whose children we measured. The instance
    /// lives for the lifetime of the app (held by AppViewModel),
    /// so re-entering Disk Lens — or drilling back up — is O(1).
    public private(set) var cache: [String: [DiskTreeNode]] = [:]

    public init() {}

    /// Builds a single-level Top-N list of the largest immediate
    /// children of `root`. Returns the cached result if available.
    /// Set `force` to bypass the cache (e.g. explicit Refresh).
    public func topFolders(
        at root: URL,
        limit: Int = 20,
        followSymlinks: Bool = false,
        force: Bool = false
    ) async -> [DiskTreeNode] {
        let key = root.standardizedFileURL.path
        if !force, let cached = cache[key] {
            return Array(cached.prefix(limit))
        }

        let fm = FileManager.default
        guard let contents = try? fm.contentsOfDirectory(
            at: root,
            includingPropertiesForKeys: [.isDirectoryKey, .fileSizeKey],
            options: [.skipsHiddenFiles, .skipsPackageDescendants]
        ) else {
            cache[key] = []
            return []
        }

        let symlinks = contents.filter { url in
            (try? url.resourceValues(forKeys: [.isSymbolicLinkKey]).isSymbolicLink) ?? false
        }
        let candidateURLs = contents.filter { !symlinks.contains($0) || followSymlinks }

        let sizer = DirectorySizer()
        let sizes = await withTaskGroup(
            of: (URL, Int64).self,
            returning: [URL: Int64].self
        ) { group in
            for url in candidateURLs {
                group.addTask {
                    var isDir: ObjCBool = false
                    let exists = FileManager.default.fileExists(atPath: url.path, isDirectory: &isDir)
                    if exists && isDir.boolValue {
                        var total: Int64 = 0
                        for await event in sizer.size(root: url) {
                            if case .completed(_, let size) = event {
                                total = size.bytes
                            }
                        }
                        return (url, total)
                    } else if exists {
                        let size = (try? FileManager.default.attributesOfItem(atPath: url.path)[.size] as? Int64) ?? 0
                        return (url, size)
                    }
                    return (url, 0)
                }
            }
            var out: [URL: Int64] = [:]
            for await (url, size) in group {
                if size > 0 { out[url] = size }
            }
            return out
        }

        let nodes = sizes
            .sorted { $0.value > $1.value }
            .map { (url, size) in
                DiskTreeNode(
                    url: url,
                    name: url.lastPathComponent,
                    size: ByteSize(bytes: size)
                )
            }
        cache[key] = nodes
        return Array(nodes.prefix(limit))
    }

    /// Builds the size of a single path (used when drilling into
    /// a subdirectory).
    public func size(of path: URL) async -> ByteSize {
        let sizer = DirectorySizer()
        for await event in sizer.size(root: path) {
            if case .completed(_, let size) = event {
                return size
            }
        }
        return .zero
    }
}
