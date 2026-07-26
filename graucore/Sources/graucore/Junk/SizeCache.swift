//
//  SizeCache.swift
//  graucore
//
//  mtime-keyed cache of directory sizes. When a path's mtime is
//  unchanged since the last computation, the cached size is used.
//  Persisted to ~/.grau/size-cache.json. See docs/ARCHITECTURE.md
//  § 6.1 and docs/DATA-SOURCES.md § 1.7 (iOS backups use this).
//

import Foundation

public struct SizeCacheEntry: Codable, Sendable, Hashable {
    public let path: String
    public let size: Int64
    public let mtime: Date
    public let lastComputed: Date

    public init(path: String, size: Int64, mtime: Date, lastComputed: Date) {
        self.path = path
        self.size = size
        self.mtime = mtime
        self.lastComputed = lastComputed
    }
}

public struct SizeCache: Codable, Sendable, Hashable {
    public var version: Int
    public var entries: [String: SizeCacheEntry]   // keyed by path
    public var lastFullScan: Date?

    public init(
        version: Int = 1,
        entries: [String: SizeCacheEntry] = [:],
        lastFullScan: Date? = nil
    ) {
        self.version = version
        self.entries = entries
        self.lastFullScan = lastFullScan
    }

    /// Returns the cached size for `path` if the path's current
    /// mtime matches the cached mtime. Otherwise returns nil,
    /// signaling the caller to recompute.
    public func cachedSize(
        for path: URL,
        currentMtime: Date
    ) -> Int64? {
        let key = path.path
        guard let entry = entries[key] else { return nil }
        guard entry.mtime == currentMtime else { return nil }
        return entry.size
    }

    /// Inserts (or updates) an entry.
    public mutating func record(
        path: URL,
        size: Int64,
        mtime: Date
    ) {
        entries[path.path] = SizeCacheEntry(
            path: path.path,
            size: size,
            mtime: mtime,
            lastComputed: Date()
        )
    }

    /// Drops entries whose paths no longer exist.
    public mutating func prune(keeping paths: Set<String>) {
        entries = entries.filter { paths.contains($0.key) }
    }
}

public actor SizeCacheStore {

    private let store: ManifestStore
    private var cache: SizeCache

    public init(store: ManifestStore = ManifestStore()) {
        self.store = store
        let loaded = (try? store.read(SizeCache.self, from: ManifestStore.sizeCacheFile)) ?? nil
        self.cache = loaded ?? SizeCache()
    }

    public func snapshot() -> SizeCache { cache }

    public func cachedSize(for path: URL, currentMtime: Date) -> Int64? {
        cache.cachedSize(for: path, currentMtime: currentMtime)
    }

    public func record(path: URL, size: Int64, mtime: Date) async {
        cache.record(path: path, size: size, mtime: mtime)
        try? store.write(cache, to: ManifestStore.sizeCacheFile)
    }

    public func reset() async {
        cache = SizeCache()
        try? store.write(cache, to: ManifestStore.sizeCacheFile)
    }
}
