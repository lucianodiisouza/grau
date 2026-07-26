//
//  JunkDefinition.swift
//  graucore
//
//  One definitional entry per category. Tells the scanner where to
//  walk, whether FDA is required, what the safety level is, and
//  the default UI selection state. See docs/DATA-SOURCES.md § 1.
//

import Foundation

public struct JunkDefinition: Sendable, Hashable {
    public let id: JunkCategory
    public let displayName: String
    public let paths: [URL]
    public let requiresFDA: Bool
    public let safety: SafetyLevel
    public let defaultSelected: Bool

    public init(
        id: JunkCategory,
        displayName: String,
        paths: [URL],
        requiresFDA: Bool,
        safety: SafetyLevel,
        defaultSelected: Bool
    ) {
        self.id = id
        self.displayName = displayName
        self.paths = paths
        self.requiresFDA = requiresFDA
        self.safety = safety
        self.defaultSelected = defaultSelected
    }
}

public enum JunkDefinitions {
    /// The standard 5-category set. Audited on 2026-07-26.
    /// See docs/PATH-AUDIT-2026-07-26.md.
    public static let standard: [JunkDefinition] = [
        JunkDefinition(
            id: .userCache,
            displayName: "User Cache",
            paths: [
                URL(fileURLWithPath: NSHomeDirectory())
                    .appendingPathComponent("Library/Caches", isDirectory: true)
            ],
            requiresFDA: false,
            safety: .safe,
            defaultSelected: true
        ),
        JunkDefinition(
            id: .systemCache,
            displayName: "System Cache",
            paths: [
                URL(fileURLWithPath: "/Library/Caches", isDirectory: true),
                // QuickLook user cache (we treat as system since it
                // is shared across users; the exact location depends
                // on macOS version)
                URL(fileURLWithPath: NSHomeDirectory())
                    .appendingPathComponent("Library/Caches/com.apple.QuickLook.thumbnailcache", isDirectory: true),
            ],
            requiresFDA: true,
            safety: .safe,
            defaultSelected: true
        ),
        JunkDefinition(
            id: .logs,
            displayName: "Logs",
            paths: [
                URL(fileURLWithPath: NSHomeDirectory())
                    .appendingPathComponent("Library/Logs", isDirectory: true),
                URL(fileURLWithPath: "/private/var/log", isDirectory: true),
            ],
            requiresFDA: true,
            safety: .safe,
            defaultSelected: true
        ),
        JunkDefinition(
            id: .oldDownloads,
            displayName: "Old Downloads",
            paths: [
                URL(fileURLWithPath: NSHomeDirectory())
                    .appendingPathComponent("Downloads", isDirectory: true)
            ],
            requiresFDA: false,
            safety: .userCaution,
            defaultSelected: false
        ),
        JunkDefinition(
            id: .iosBackups,
            displayName: "iOS Backups",
            paths: [
                URL(fileURLWithPath: NSHomeDirectory())
                    .appendingPathComponent("Library/Application Support/MobileSync/Backup", isDirectory: true)
            ],
            requiresFDA: false,
            safety: .userCaution,
            defaultSelected: false
        ),
    ]

    public static func definition(for category: JunkCategory) -> JunkDefinition? {
        standard.first { $0.id == category }
    }
}
