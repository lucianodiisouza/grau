//
//  TrashInfo.swift
//  graucore
//
//  Sizes the user's ~/.Trash. Resolves symlinks (Apple Silicon
//  multi-volume setups can have ~/.Trash point at a non-boot
//  volume). Capped walk so a Trash full of millions of files
//  doesn't make Grau hang.
//

import Foundation

public struct TrashInfo: Hashable, Sendable {
    public let size: ByteSize
    public let itemCount: Int
    public let isCapped: Bool
    public let path: URL

    public init(size: ByteSize, itemCount: Int, isCapped: Bool, path: URL) {
        self.size = size
        self.itemCount = itemCount
        self.isCapped = isCapped
        self.path = path
    }
}

public struct TrashInfoReader: Sendable {

    /// Maximum number of items to enumerate when computing the
    /// trash size. Beyond this we report `isCapped = true` and
    /// stop the walk.
    public static let maxItems = 10_000

    public init() {}

    public static var defaultTrashPath: URL {
        let home = FileManager.default.homeDirectoryForCurrentUser
        return home.appendingPathComponent(".Trash", isDirectory: true)
    }

    /// Resolves symlinks. On a normal Mac this is a no-op; on Apple
    /// Silicon with a non-boot home volume, `~/.Trash` may be a
    /// symlink to the data volume.
    public static func resolveTrashPath() -> URL {
        let raw = defaultTrashPath
        let resolved = raw.resolvingSymlinksInPath()
        return resolved
    }

    /// Synchronous size of the trash. Capped at `maxItems`.
    public func read(trashPath: URL? = nil) -> TrashInfo {
        let path = trashPath ?? Self.resolveTrashPath()
        guard FileManager.default.fileExists(atPath: path.path) else {
            return TrashInfo(size: .zero, itemCount: 0, isCapped: false, path: path)
        }
        let fm = FileManager.default
        guard let enumerator = fm.enumerator(
            at: path,
            includingPropertiesForKeys: [.fileSizeKey, .isRegularFileKey],
            options: [.skipsHiddenFiles, .skipsPackageDescendants]
        ) else {
            return TrashInfo(size: .zero, itemCount: 0, isCapped: false, path: path)
        }

        var totalBytes: Int64 = 0
        var count = 0
        var capped = false
        for case let url as URL in enumerator {
            count += 1
            if count > Self.maxItems {
                capped = true
                break
            }
            let size = (try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0
            totalBytes += Int64(size)
        }
        return TrashInfo(
            size: ByteSize(bytes: totalBytes),
            itemCount: count,
            isCapped: capped,
            path: path
        )
    }
}
