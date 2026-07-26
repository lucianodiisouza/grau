//
//  RetentionPolicyStore.swift
//  graucore
//
//  Persists the user's `RetentionPolicy` to
//  `~/.grau/retention-policy.json`. Read returns the default policy
//  when the file is missing or unreadable, so callers never need to
//  handle the "uninitialized" case.
//
//  v1.7 feature. Phase 12.1.
//

import Foundation

public actor RetentionPolicyStore {

    public init() {}

    /// `~/.grau/retention-policy.json`.
    public static var policyFile: URL {
        ManifestStore.grauDirectory
            .appendingPathComponent("retention-policy.json", isDirectory: false)
    }

    public func read() async -> RetentionPolicy {
        let url = Self.policyFile
        let fm = FileManager.default
        guard fm.fileExists(atPath: url.path) else { return .default }
        let decoder = JSONDecoder()
        guard let data = try? Data(contentsOf: url),
              let policy = try? decoder.decode(RetentionPolicy.self, from: data)
        else { return .default }
        return policy
    }

    public func write(_ policy: RetentionPolicy) async throws {
        try ManifestStore.ensureGrauDirectory()
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(policy)
        try data.write(to: Self.policyFile, options: .atomic)
    }

    /// Reads, mutates, and writes atomically. Returns the new policy.
    @discardableResult
    public func update(_ transform: (RetentionPolicy) -> RetentionPolicy) async throws -> RetentionPolicy {
        let current = await read()
        let updated = transform(current)
        try await write(updated)
        return updated
    }
}
