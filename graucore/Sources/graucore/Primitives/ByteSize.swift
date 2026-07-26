//
//  ByteSize.swift
//  graucore
//
//  A 64-bit size type with a human-readable string. Replaces raw
//  Int64 throughout the codebase. See docs/ARCHITECTURE.md § 6.1.
//

import Foundation

public struct ByteSize: Hashable, Sendable, Codable, Comparable {
    public let bytes: Int64

    public init(bytes: Int64) {
        self.bytes = bytes
    }

    public static let zero = ByteSize(bytes: 0)

    public static func < (lhs: ByteSize, rhs: ByteSize) -> Bool {
        lhs.bytes < rhs.bytes
    }

    public static func + (lhs: ByteSize, rhs: ByteSize) -> ByteSize {
        ByteSize(bytes: lhs.bytes + rhs.bytes)
    }

    public static func += (lhs: inout ByteSize, rhs: ByteSize) {
        lhs = lhs + rhs
    }

    /// Human-readable file size using the user's preferred units.
    public var humanReadable: String {
        ByteCountFormatter.string(fromByteCount: bytes, countStyle: .file)
    }

    /// "12.4 GB" — used in UI pill labels.
    public var compactLabel: String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        formatter.allowedUnits = [.useKB, .useMB, .useGB, .useTB]
        formatter.includesUnit = true
        formatter.includesCount = true
        return formatter.string(fromByteCount: bytes)
    }
}

extension ByteSize: ExpressibleByIntegerLiteral {
    public init(integerLiteral value: Int64) {
        self.init(bytes: value)
    }
}
