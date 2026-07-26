//
//  PackageCacheKind.swift
//  graucore
//
//  The 16 package manager caches Grau tracks in v1.
//

import Foundation

public enum PackageCacheKind: String, CaseIterable, Sendable, Codable, Identifiable {
    case npm
    case yarnClassic
    case yarnBerry
    case pnpm
    case bun
    case cocoapods
    case carthage
    case swiftpm
    case maven
    case gradle
    case sbt
    case ivy
    case cargo
    case gem
    case pip
    case poetry

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .npm:        "npm"
        case .yarnClassic: "Yarn (classic)"
        case .yarnBerry:  "Yarn (berry)"
        case .pnpm:       "pnpm"
        case .bun:        "Bun"
        case .cocoapods:  "CocoaPods"
        case .carthage:   "Carthage"
        case .swiftpm:    "SwiftPM"
        case .maven:      "Maven"
        case .gradle:     "Gradle"
        case .sbt:        "sbt"
        case .ivy:        "Ivy"
        case .cargo:      "Cargo"
        case .gem:        "RubyGems"
        case .pip:        "pip"
        case .poetry:     "Poetry"
        }
    }

    /// The default paths to check for this cache. Some of these
    /// (e.g. SwiftPM, Gradle) have multiple candidate paths; we
    /// check each and sum.
    public var defaultPaths: [URL] {
        let home = FileManager.default.homeDirectoryForCurrentUser
        switch self {
        case .npm:
            return [home.appendingPathComponent(".npm", isDirectory: true)]
        case .yarnClassic:
            return [home.appendingPathComponent("Library/Caches/yarn", isDirectory: true)]
        case .yarnBerry:
            return [home.appendingPathComponent(".yarn/cache", isDirectory: true)]
        case .pnpm:
            return [home.appendingPathComponent("Library/pnpm", isDirectory: true)]
        case .bun:
            return [home.appendingPathComponent(".bun", isDirectory: true)]
        case .cocoapods:
            return [home.appendingPathComponent("Library/Caches/CocoaPods", isDirectory: true)]
        case .carthage:
            return [home.appendingPathComponent("Library/Caches/org.carthage.Carthage", isDirectory: true)]
        case .swiftpm:
            return [
                home.appendingPathComponent("Library/Caches/org.swift.swiftpm", isDirectory: true),
                home.appendingPathComponent("Library/org.swift.swiftpm", isDirectory: true),
            ]
        case .maven:
            return [home.appendingPathComponent(".m2", isDirectory: true)]
        case .gradle:
            return [home.appendingPathComponent(".gradle", isDirectory: true)]
        case .sbt:
            // sbt uses .sbt for boot scripts and shares .ivy2
            // with Ivy. We attribute the .ivy2 dir to Ivy to
            // avoid double-counting across the two kinds.
            return [
                home.appendingPathComponent(".sbt", isDirectory: true),
            ]
        case .ivy:
            return [home.appendingPathComponent(".ivy2", isDirectory: true)]
        case .cargo:
            return [home.appendingPathComponent(".cargo/registry", isDirectory: true)]
        case .gem:
            return [home.appendingPathComponent(".gem", isDirectory: true)]
        case .pip:
            return [home.appendingPathComponent("Library/Caches/pip", isDirectory: true)]
        case .poetry:
            return [home.appendingPathComponent("Library/Caches/pypoetry", isDirectory: true)]
        }
    }
}
