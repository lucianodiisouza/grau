//
//  DuplicateGroup.swift
//  graucore
//

import Foundation

public struct DuplicateGroup: Identifiable, Hashable, Sendable {
    public let id: UUID
    public let hash: String
    public let size: ByteSize
    public let files: [URL]

    public init(id: UUID = UUID(), hash: String, size: ByteSize, files: [URL]) {
        self.id = id
        self.hash = hash
        self.size = size
        self.files = files
    }

    /// How much disk space the user could reclaim by deleting all
    /// but one file in the group.
    public var wastedBytes: ByteSize {
        ByteSize(bytes: size.bytes * Int64(max(files.count - 1, 0)))
    }
}
