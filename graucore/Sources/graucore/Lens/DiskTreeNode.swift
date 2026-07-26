//
//  DiskTreeNode.swift
//  graucore
//
//  A node in the disk tree. Leaves are files; non-leaves are
//  directories with a children list. The full tree is never
//  built for the whole disk — see DiskTreeBuilder for the
//  bounded Top-N approach used in v1.
//

import Foundation

public struct DiskTreeNode: Identifiable, Hashable, Sendable {
    public let id: UUID
    public let url: URL
    public let name: String
    public let size: ByteSize
    public var children: [DiskTreeNode]?

    public init(
        id: UUID = UUID(),
        url: URL,
        name: String,
        size: ByteSize,
        children: [DiskTreeNode]? = nil
    ) {
        self.id = id
        self.url = url
        self.name = name
        self.size = size
        self.children = children
    }

    /// True if this node has no children (a leaf).
    public var isLeaf: Bool {
        children == nil || (children?.isEmpty ?? true)
    }

    /// Total size of self + all descendants. Same as `size` since
    /// we store aggregate sizes.
    public var totalSize: ByteSize { size }

    /// Sorted descendants by size descending. Includes the node
    /// itself (as a synthetic "stay here" item) so the user can
    /// see "this dir" alongside the sub-items.
    public var sortedChildren: [DiskTreeNode] {
        (children ?? []).sorted { $0.size > $1.size }
    }
}
