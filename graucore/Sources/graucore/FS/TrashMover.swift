//
//  TrashMover.swift
//  graucore
//
//  The ONLY module in the codebase that performs destructive IO.
//  Uses FileManager.trashItem (NOT NSWorkspace.dispose) for
//  atomicity and speed. Writes a TrashManifest per move batch.
//  See docs/REVIEW.md B7.
//

import Foundation

public struct TrashMover: Sendable {

    public init() {}

    public enum MoveError: Error, CustomStringConvertible {
        case trashFailed(URL, underlying: Error)
        case manifestWriteFailed(URL, underlying: Error)

        public var description: String {
            switch self {
            case .trashFailed(let url, let err):
                return "Failed to move \(url.path) to Trash: \(err.localizedDescription)"
            case .manifestWriteFailed(let url, let err):
                return "Failed to write manifest at \(url.path): \(err.localizedDescription)"
            }
        }
    }

    /// Moves the given items to the user's Trash. Each item is
    /// moved individually so that a single failure does not abort
    /// the whole batch. Returns a `TrashManifest` describing what
    /// was moved, written to `~/.grau/trash-manifests/<ts>-<kind>.json`.
    @discardableResult
    public func trash(
        items: [URL],
        kind: String,
        manifestDirectory: URL? = nil
    ) async throws -> TrashManifest {
        let manifestDir = manifestDirectory ?? Self.defaultManifestDirectory
        try FileManager.default.createDirectory(
            at: manifestDir,
            withIntermediateDirectories: true
        )

        let id = UUID()
        let timestamp = Date()
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        let timestampString = formatter.string(from: timestamp)
            .replacingOccurrences(of: ":", with: "-")
        let manifestPath = manifestDir
            .appendingPathComponent("\(timestampString)-\(kind).json")

        var manifestItems: [TrashManifestItem] = []
        let fm = FileManager.default
        let trashRoot = NSHomeDirectory() + "/.Trash/"
        for item in items {
            if Task.isCancelled { break }
            do {
                var resultingItemURL: NSURL?
                try fm.trashItem(at: item, resultingItemURL: &resultingItemURL)
                let resultingURL = resultingItemURL as URL? ?? item
                let size = (try? fm
                    .attributesOfItem(atPath: resultingURL.path)[.size] as? Int64) ?? 0
                let original = item.path
                let trashRelative = resultingURL.path.hasPrefix(trashRoot)
                    ? String(resultingURL.path.dropFirst(trashRoot.count))
                    : resultingURL.lastPathComponent
                manifestItems.append(TrashManifestItem(
                    originalPath: original,
                    trashRelativePath: trashRelative,
                    size: size
                ))
            } catch {
                // Per-item failure is non-fatal; we log it via the
                // manifest. Future: surface to UI as a partial-result
                // banner.
                NSLog("Grau: failed to trash %@: %@", item.path, "\(error)")
            }
        }

        let totalSize = manifestItems.reduce(Int64(0)) { $0 + $1.size }
        let manifest = TrashManifest(
            id: id,
            timestamp: timestamp,
            kind: kind,
            totalSize: totalSize,
            items: manifestItems
        )

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        do {
            let data = try encoder.encode(manifest)
            try data.write(to: manifestPath, options: .atomic)
        } catch {
            throw MoveError.manifestWriteFailed(manifestPath, underlying: error)
        }

        return manifest
    }

    /// Returns `~/.grau/trash-manifests/`. Created on first use.
    public static var defaultManifestDirectory: URL {
        FileManager.default
            .homeDirectoryForCurrentUser
            .appendingPathComponent(".grau/trash-manifests", isDirectory: true)
    }
}

// MARK: - Manifest types

public struct TrashManifest: Codable, Sendable, Equatable {
    public let id: UUID
    public let timestamp: Date
    public let kind: String
    public let totalSize: Int64
    public let items: [TrashManifestItem]

    public init(
        id: UUID,
        timestamp: Date,
        kind: String,
        totalSize: Int64,
        items: [TrashManifestItem]
    ) {
        self.id = id
        self.timestamp = timestamp
        self.kind = kind
        self.totalSize = totalSize
        self.items = items
    }
}

public struct TrashManifestItem: Codable, Sendable, Equatable {
    public let originalPath: String
    public let trashRelativePath: String
    public let size: Int64

    public init(originalPath: String, trashRelativePath: String, size: Int64) {
        self.originalPath = originalPath
        self.trashRelativePath = trashRelativePath
        self.size = size
    }
}
