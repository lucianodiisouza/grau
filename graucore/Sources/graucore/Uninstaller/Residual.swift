//
//  Residual.swift
//  graucore
//

import Foundation

public struct Residual: Identifiable, Hashable, Sendable {
    public let id: UUID
    public let kind: ResidualKind
    public let path: URL
    public let size: ByteSize
    public let note: String?

    public init(
        id: UUID = UUID(),
        kind: ResidualKind,
        path: URL,
        size: ByteSize,
        note: String? = nil
    ) {
        self.id = id
        self.kind = kind
        self.path = path
        self.size = size
        self.note = note
    }
}
