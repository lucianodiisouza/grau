//
//  DuplicateSelection.swift
//  graucore
//
//  Safe-selection logic for duplicate groups. Never auto-selects
//  the only copy of a file. Default: keep the oldest by mtime.
//

import Foundation

public struct DuplicateSelection: Sendable {

    public init() {}

    /// Given a duplicate group, returns the URLs that should be
    /// **kept**. Default: keep the oldest by mtime.
    public func keepURLs(in group: DuplicateGroup) -> [URL] {
        guard group.files.count > 1 else { return group.files }
        let fm = FileManager.default
        let dated = group.files.map { url -> (URL, Date) in
            let mtime = (try? fm.attributesOfItem(atPath: url.path)[.modificationDate] as? Date) ?? .distantPast
            return (url, mtime)
        }
        let oldest = dated.min { $0.1 < $1.1 }?.0
        return oldest.map { [$0] } ?? Array(group.files.prefix(1))
    }

    /// The opposite of keepURLs: the URLs that would be **removed**
    /// if we kept the selection above.
    public func removeURLs(in group: DuplicateGroup) -> [URL] {
        let keep = Set(keepURLs(in: group))
        return group.files.filter { !keep.contains($0) }
    }

    /// Total bytes that would be freed by removing all-but-one
    /// in every group.
    public func totalWasted(_ groups: [DuplicateGroup]) -> ByteSize {
        ByteSize(bytes: groups.reduce(0) { $0 + $1.wastedBytes.bytes })
    }
}
