//
//  AutoCleanStore.swift
//  graucore
//
//  Persists the list of `AutoCleanRule`s to
//  `~/.grau/auto-clean.json`. Read returns the default rule set
//  (a single, disabled rule) when the file is missing or
//  unreadable, so callers always have a valid set to render.
//
//  v1.7 feature. Phase 12.2.
//

import Foundation

public actor AutoCleanStore {

    public init() {}

    /// `~/.grau/auto-clean.json`.
    public static var rulesFile: URL {
        ManifestStore.grauDirectory
            .appendingPathComponent("auto-clean.json", isDirectory: false)
    }

    /// Default rule set installed on first run. The user can
    /// delete or disable any of these.
    public static let defaultRules: [AutoCleanRule] = [
        AutoCleanRule(
            name: "Prune old manifests weekly",
            condition: .timeOfDay(hour: 3, minute: 0),
            action: .runRetention,
            enabled: false
        ),
        AutoCleanRule(
            name: "Reindex trash when large",
            condition: .trashSizeExceeds(bytes: 10_000_000_000),  // 10 GB
            action: .reindexTrash,
            enabled: false
        )
    ]

    public func read() async -> [AutoCleanRule] {
        let url = Self.rulesFile
        let fm = FileManager.default
        guard fm.fileExists(atPath: url.path) else { return Self.defaultRules }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        guard let data = try? Data(contentsOf: url),
              let rules = try? decoder.decode([AutoCleanRule].self, from: data)
        else { return Self.defaultRules }
        return rules
    }

    public func write(_ rules: [AutoCleanRule]) async throws {
        try ManifestStore.ensureGrauDirectory()
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(rules)
        try data.write(to: Self.rulesFile, options: .atomic)
    }

    /// Inserts a new rule. Returns the new full list.
    @discardableResult
    public func add(_ rule: AutoCleanRule) async throws -> [AutoCleanRule] {
        var current = await read()
        current.append(rule)
        try await write(current)
        return current
    }

    /// Replaces the rule with the same id. If the id isn't present
    /// the rule is appended. Returns the new full list.
    @discardableResult
    public func upsert(_ rule: AutoCleanRule) async throws -> [AutoCleanRule] {
        var current = await read()
        if let idx = current.firstIndex(where: { $0.id == rule.id }) {
            current[idx] = rule
        } else {
            current.append(rule)
        }
        try await write(current)
        return current
    }

    /// Removes the rule with the given id. Returns the new list.
    @discardableResult
    public func remove(id: UUID) async throws -> [AutoCleanRule] {
        var current = await read()
        current.removeAll { $0.id == id }
        try await write(current)
        return current
    }
}
