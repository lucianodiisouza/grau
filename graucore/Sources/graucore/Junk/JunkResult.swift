//
//  JunkResult.swift
//  graucore
//
//  The output of scanning one JunkCategory. Carries the total size,
//  the top-N largest items, scan duration, and a "skipped" flag
//  for FDA-required categories when FDA is missing.
//

import Foundation

public struct JunkResult: Sendable, Hashable {
    public let category: JunkCategory
    public let size: ByteSize
    public let items: [JunkItem]              // top N by size, capped
    public let scanDuration: TimeInterval
    public let skipped: Bool
    public let skipReason: String?

    public init(
        category: JunkCategory,
        size: ByteSize,
        items: [JunkItem],
        scanDuration: TimeInterval,
        skipped: Bool = false,
        skipReason: String? = nil
    ) {
        self.category = category
        self.size = size
        self.items = items
        self.scanDuration = scanDuration
        self.skipped = skipped
        self.skipReason = skipReason
    }
}

public struct JunkItem: Identifiable, Hashable, Sendable {
    public let id: UUID
    public let path: URL
    public let size: ByteSize
    public let isDirectory: Bool

    public init(id: UUID = UUID(), path: URL, size: ByteSize, isDirectory: Bool) {
        self.id = id
        self.path = path
        self.size = size
        self.isDirectory = isDirectory
    }
}
