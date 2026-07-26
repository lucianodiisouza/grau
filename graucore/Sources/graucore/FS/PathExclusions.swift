//
//  PathExclusions.swift
//  graucore
//
//  Standard list of paths the scanner must skip. Audit verified
//  against macOS 26.5.2 on 2026-07-26 — see
//  docs/PATH-AUDIT-2026-07-26.md. Re-audit before each beta tag.
//

import Foundation

/// Pluggable exclusion strategy. Lets tests inject a custom set
/// without mutating the global `PathExclusions.standard`.
public protocol PathExclusionsProvider: Sendable {
    func shouldExclude(absolutePath: String) -> Bool
}

/// Default set of path exclusions. Used by the scanner unless
/// overridden via the `FileSystemScanner(exclusions:)` initializer.
public struct PathExclusions: PathExclusionsProvider, Sendable {

    /// Absolute path prefixes that the scanner never descends into.
    /// See docs/DATA-SOURCES.md § 7.
    public static let standardPrefixes: Set<String> = [
        "/System",
        "/private/var/db",
        "/.Spotlight-V100",
        "/.fseventsd",
        "/.DocumentRevisions-V100",
        "/.TemporaryItems",
        "/.Trashes",
        "/private/var/folders/.../T/",   // system temp (not per-user)
    ]

    /// Suffix names that are excluded even when their parent is
    /// allowed.
    public static let alwaysSkipSuffixes: Set<String> = [
        ".DS_Store",
        ".localized",
    ]

    /// Apple's own cache subdirectories that we never touch, even
    /// under `~/Library/Caches`. These are managed by system
    /// services and trashing them breaks the system.
    public static let appleUserCacheExclusions: Set<String> = [
        "com.apple.bird",        // iCloud daemon
        "com.apple.QuickLook",   // Quick Look thumbs cache (user-side)
    ]

    public let prefixes: Set<String>
    public let suffixes: Set<String>
    public let appleComponents: Set<String>

    public init(
        prefixes: Set<String> = PathExclusions.standardPrefixes,
        suffixes: Set<String> = PathExclusions.alwaysSkipSuffixes,
        appleComponents: Set<String> = PathExclusions.appleUserCacheExclusions
    ) {
        self.prefixes = prefixes
        self.suffixes = suffixes
        self.appleComponents = appleComponents
    }

    /// The standard exclusion set.
    public static let standard = PathExclusions()

    /// True iff the given absolute path should be excluded by the
    /// scanner. This is the single place to add new exclusions.
    public func shouldExclude(absolutePath: String) -> Bool {
        for prefix in prefixes {
            if absolutePath.hasPrefix(prefix) { return true }
        }
        for suffix in suffixes {
            if absolutePath.hasSuffix("/" + suffix) { return true }
        }
        for apple in appleComponents {
            // Match the apple name as a path component (either as a
            // directory or as the leaf). So /Users/foo/.../com.apple.bird
            // AND /Users/foo/.../com.apple.bird/cache.db are both caught.
            if absolutePath == "/" + apple { return true }
            if absolutePath.hasSuffix("/" + apple) { return true }
            if absolutePath.contains("/" + apple + "/") { return true }
        }
        return false
    }
}
