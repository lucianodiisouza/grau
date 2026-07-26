//
//  VolumeInfo.swift
//  graucore
//
//  A mounted volume's metadata.
//

import Foundation

public struct VolumeInfo: Hashable, Sendable, Identifiable {
    public let url: URL
    public let name: String
    public let totalBytes: Int64
    public let freeBytes: Int64
    public let isRemovable: Bool
    public let isReadOnly: Bool

    public var id: URL { url }

    public var usedBytes: Int64 {
        max(totalBytes - freeBytes, 0)
    }

    public var usageFraction: Double {
        guard totalBytes > 0 else { return 0 }
        return min(max(Double(usedBytes) / Double(totalBytes), 0), 1)
    }

    public init(
        url: URL,
        name: String,
        totalBytes: Int64,
        freeBytes: Int64,
        isRemovable: Bool,
        isReadOnly: Bool
    ) {
        self.url = url
        self.name = name
        self.totalBytes = totalBytes
        self.freeBytes = freeBytes
        self.isRemovable = isRemovable
        self.isReadOnly = isReadOnly
    }
}
