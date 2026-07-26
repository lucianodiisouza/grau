//
//  JunkCleaner.swift
//  graucore
//
//  Takes a selection of JunkResults and moves their items to the
//  Trash via TrashMover. Writes one TrashManifest per call.
//

import Foundation

public struct JunkCleaner: Sendable {

    private let trashMover: TrashMover

    public init(trashMover: TrashMover = TrashMover()) {
        self.trashMover = trashMover
    }

    public struct CleanupOutcome: Sendable {
        public let manifest: TrashManifest
        public let movedCount: Int
        public let freedBytes: Int64
    }

    /// Moves all items in the selected categories to the user's
    /// Trash. Items that fail are logged but the batch continues.
    /// Skipped categories are ignored.
    @discardableResult
    public func clean(
        selectedResults: [JunkResult],
        manifestDirectory: URL? = nil
    ) async throws -> CleanupOutcome {
        var urls: [URL] = []
        for result in selectedResults where !result.skipped {
            for item in result.items {
                urls.append(item.path)
            }
        }
        let manifest = try await trashMover.trash(
            items: urls,
            kind: "junk",
            manifestDirectory: manifestDirectory
        )
        return CleanupOutcome(
            manifest: manifest,
            movedCount: manifest.items.count,
            freedBytes: manifest.totalSize
        )
    }
}
