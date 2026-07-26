//
//  ManifestStore.swift
//  graucore
//
//  JSON read/write of ~/.grau/ files: state.json, size-cache.json,
//  trash-manifests/*.json. See docs/ARCHITECTURE.md § 6.2.
//

import Foundation

public struct ManifestStore: Sendable {

    public init() {}

    /// `~/.grau/`. Created on first use.
    public static var grauDirectory: URL {
        FileManager.default
            .homeDirectoryForCurrentUser
            .appendingPathComponent(".grau", isDirectory: true)
    }

    /// `~/.grau/state.json`.
    public static var stateFile: URL {
        grauDirectory.appendingPathComponent("state.json")
    }

    /// `~/.grau/size-cache.json`.
    public static var sizeCacheFile: URL {
        grauDirectory.appendingPathComponent("size-cache.json")
    }

    /// Ensures `~/.grau/` exists.
    public static func ensureGrauDirectory() throws {
        try FileManager.default.createDirectory(
            at: grauDirectory,
            withIntermediateDirectories: true
        )
    }

    // MARK: - Generic JSON

    public func read<T: Decodable>(_ type: T.Type, from url: URL) throws -> T? {
        let fm = FileManager.default
        guard fm.fileExists(atPath: url.path) else { return nil }
        let data = try Data(contentsOf: url)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(T.self, from: data)
    }

    public func write<T: Encodable>(_ value: T, to url: URL) throws {
        try Self.ensureGrauDirectory()
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(value)
        try data.write(to: url, options: .atomic)
    }
}

// MARK: - Last-scan summary

public struct LastScanSummary: Codable, Sendable, Equatable {
    public let kind: String            // "junk" | "uninstall" | "duplicates" | ...
    public let totalBytes: Int64
    public let itemCount: Int
    public let finishedAt: Date

    public init(kind: String, totalBytes: Int64, itemCount: Int, finishedAt: Date) {
        self.kind = kind
        self.totalBytes = totalBytes
        self.itemCount = itemCount
        self.finishedAt = finishedAt
    }
}

public struct StateFile: Codable, Sendable, Equatable {
    public var lastJunkScan: LastScanSummary?
    public var lastClean: LastScanSummary?
    /// Last N scan summaries, newest first. Capped at
    /// `maxHistoryEntries` (10) by the writer.
    public var scanHistory: [LastScanSummary]

    /// Cap for the scanHistory list. Older entries are dropped
    /// from the tail.
    public static let maxHistoryEntries: Int = 10

    public init(
        lastJunkScan: LastScanSummary? = nil,
        lastClean: LastScanSummary? = nil,
        scanHistory: [LastScanSummary] = []
    ) {
        self.lastJunkScan = lastJunkScan
        self.lastClean = lastClean
        self.scanHistory = scanHistory
    }

    /// Appends a new summary to the history and trims to the
    /// max entries. Returns a new `StateFile` (state is a
    /// value type, so callers must use the returned value).
    public func appendingHistory(_ summary: LastScanSummary) -> StateFile {
        var copy = self
        copy.scanHistory.insert(summary, at: 0)
        if copy.scanHistory.count > Self.maxHistoryEntries {
            copy.scanHistory = Array(copy.scanHistory.prefix(Self.maxHistoryEntries))
        }
        return copy
    }
}
