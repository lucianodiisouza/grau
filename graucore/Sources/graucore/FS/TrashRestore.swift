//
//  TrashRestore.swift
//  graucore
//
//  Lists and restores past trashing operations from the JSON
//  manifests written by `TrashMover`. A "restore" moves each item
//  from `~/.Trash/<trashRelativePath>` back to its `originalPath`.
//

import Foundation

public struct TrashManifestSummary: Identifiable, Hashable, Sendable {
    public let id: UUID
    public let timestamp: Date
    public let kind: String
    public let totalSize: Int64
    public let itemCount: Int
    public let manifestURL: URL

    public init(
        id: UUID,
        timestamp: Date,
        kind: String,
        totalSize: Int64,
        itemCount: Int,
        manifestURL: URL
    ) {
        self.id = id
        self.timestamp = timestamp
        self.kind = kind
        self.totalSize = totalSize
        self.itemCount = itemCount
        self.manifestURL = manifestURL
    }
}

public struct TrashRestoreOutcome: Sendable {
    public let restored: Int
    public let failed: [(originalPath: String, error: String)]
}

public enum TrashRestoreError: Error, CustomStringConvertible {
    case manifestNotFound(UUID)
    case trashItemMissing(original: String, currentTrashPath: String)
    case originalPathOccupied(String)
    case moveFailed(original: String, underlying: String)

    public var description: String {
        switch self {
        case .manifestNotFound(let id):
            return "Manifest not found: \(id)"
        case .trashItemMissing(let o, let t):
            return "Trash item missing: \(o) → \(t)"
        case .originalPathOccupied(let p):
            return "Original path already occupied: \(p)"
        case .moveFailed(let p, let e):
            return "Move failed for \(p): \(e)"
        }
    }
}

public actor TrashRestore {

    public init() {}

    /// Lists every manifest in `~/.grau/trash-manifests/`, sorted
    /// newest first. Returns an empty array if the directory
    /// doesn't exist yet (i.e. the user has never trashed anything).
    public func listManifests() async -> [TrashManifestSummary] {
        let dir = TrashMover.defaultManifestDirectory
        let fm = FileManager.default
        guard fm.fileExists(atPath: dir.path) else { return [] }
        guard let urls = try? fm.contentsOfDirectory(
            at: dir,
            includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles]
        ) else { return [] }

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        var summaries: [TrashManifestSummary] = []
        for url in urls where url.pathExtension == "json" {
            guard let data = try? Data(contentsOf: url),
                  let manifest = try? decoder.decode(TrashManifest.self, from: data)
            else { continue }
            summaries.append(TrashManifestSummary(
                id: manifest.id,
                timestamp: manifest.timestamp,
                kind: manifest.kind,
                totalSize: manifest.totalSize,
                itemCount: manifest.items.count,
                manifestURL: url
            ))
        }
        return summaries.sorted { $0.timestamp > $1.timestamp }
    }

    /// Reads a specific manifest by id.
    public func manifest(id: UUID) async -> TrashManifest? {
        let summaries = await listManifests()
        guard let s = summaries.first(where: { $0.id == id }) else { return nil }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try? decoder.decode(
            TrashManifest.self,
            from: Data(contentsOf: s.manifestURL)
        )
    }

    /// Restores every item in the given manifest. For each item:
    ///   1. Look up the current location in `~/.Trash/<trashRelativePath>`.
    ///   2. If `originalPath` is occupied, skip with `.originalPathOccupied`.
    ///   3. Move the file out of the trash back to `originalPath`.
    /// Returns a `TrashRestoreOutcome` with counts.
    public func restore(manifestID: UUID) async -> TrashRestoreOutcome {
        guard let manifest = await manifest(id: manifestID) else {
            return TrashRestoreOutcome(
                restored: 0,
                failed: [("(manifest \(manifestID))", TrashRestoreError.manifestNotFound(manifestID).description)]
            )
        }
        let fm = FileManager.default
        let trashRoot = NSHomeDirectory() + "/.Trash/"
        var restoredCount = 0
        var failures: [(originalPath: String, error: String)] = []

        for item in manifest.items {
            let currentTrashPath = trashRoot + item.trashRelativePath
            let originalURL = URL(fileURLWithPath: item.originalPath)

            // Step 1: confirm the file is still in the trash.
            if !fm.fileExists(atPath: currentTrashPath) {
                failures.append((item.originalPath, TrashRestoreError.trashItemMissing(
                    original: item.originalPath,
                    currentTrashPath: currentTrashPath
                ).description))
                continue
            }
            // Step 2: if the destination is occupied, skip.
            if fm.fileExists(atPath: originalURL.path) {
                failures.append((item.originalPath, TrashRestoreError.originalPathOccupied(
                    item.originalPath
                ).description))
                continue
            }
            // Ensure the parent directory exists.
            let parent = originalURL.deletingLastPathComponent()
            try? fm.createDirectory(at: parent, withIntermediateDirectories: true)
            // Step 3: move the file out of the trash.
            do {
                try fm.moveItem(at: URL(fileURLWithPath: currentTrashPath), to: originalURL)
                restoredCount += 1
            } catch {
                failures.append((item.originalPath, TrashRestoreError.moveFailed(
                    original: item.originalPath,
                    underlying: error.localizedDescription
                ).description))
            }
        }
        return TrashRestoreOutcome(restored: restoredCount, failed: failures)
    }
}
