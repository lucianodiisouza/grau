//
//  NotificationLog.swift
//  graucore
//
//  Persistent log of every notification Grau has fired. The
//  app's NotificationCoordinator calls `record(...)` after a
//  successful `UNUserNotificationCenter.add(...)`. The log is
//  capped at `maxEntries` (default 200) so ~/.grau/ doesn't
//  grow unbounded.
//
//  v1.4 feature. The log is what powers the new
//  Notification Center UI in the app.
//

import Foundation

public struct NotificationLogEntry: Identifiable, Codable, Hashable, Sendable {
    public let id: UUID
    public let timestamp: Date
    public let ruleID: String
    public let title: String
    public let body: String

    public init(
        id: UUID = UUID(),
        timestamp: Date = Date(),
        ruleID: String,
        title: String,
        body: String
    ) {
        self.id = id
        self.timestamp = timestamp
        self.ruleID = ruleID
        self.title = title
        self.body = body
    }
}

public actor NotificationLog {
    public static let maxEntries: Int = 200

    public init() {}

    /// `~/.grau/notification-log.json`.
    public static var logFile: URL {
        ManifestStore.grauDirectory
            .appendingPathComponent("notification-log.json", isDirectory: false)
    }

    /// Reads every entry, newest first. Returns an empty array
    /// if the file doesn't exist or is unreadable.
    public func read() async -> [NotificationLogEntry] {
        let url = Self.logFile
        let fm = FileManager.default
        guard fm.fileExists(atPath: url.path) else { return [] }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        guard let data = try? Data(contentsOf: url),
              let entries = try? decoder.decode([NotificationLogEntry].self, from: data)
        else { return [] }
        return entries.sorted { $0.timestamp > $1.timestamp }
    }

    /// Records a new entry, then trims the log to `maxEntries`.
    public func record(
        ruleID: String,
        title: String,
        body: String,
        timestamp: Date = Date()
    ) async {
        var entries = await read()
        entries.insert(
            NotificationLogEntry(
                timestamp: timestamp,
                ruleID: ruleID,
                title: title,
                body: body
            ),
            at: 0
        )
        if entries.count > Self.maxEntries {
            entries = Array(entries.prefix(Self.maxEntries))
        }
        let url = Self.logFile
        try? ManifestStore.ensureGrauDirectory()
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        if let data = try? encoder.encode(entries) {
            try? data.write(to: url, options: .atomic)
        }
    }

    /// Clears every entry. Returns silently on read/write errors.
    public func clear() async {
        let url = Self.logFile
        try? FileManager.default.removeItem(at: url)
    }

    /// Replaces the entire log with `entries`, sorted newest first
    /// and trimmed to `maxEntries`. Used by the retention engine to
    /// prune old entries. No-op if the input is empty (the file is
    /// removed so we don't leave a stale `[]` on disk).
    public func replace(with entries: [NotificationLogEntry]) async {
        let url = Self.logFile
        if entries.isEmpty {
            try? FileManager.default.removeItem(at: url)
            return
        }
        let trimmed = Array(entries.prefix(Self.maxEntries))
            .sorted { $0.timestamp > $1.timestamp }
        try? ManifestStore.ensureGrauDirectory()
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        if let data = try? encoder.encode(trimmed) {
            try? data.write(to: url, options: .atomic)
        }
    }
}
