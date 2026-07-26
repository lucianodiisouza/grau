//
//  Uninstaller.swift
//  graucore
//
//  Builds an UninstallPlan from a selected app + residual
//  selection, executes it via TrashMover.
//

import AppKit
import Foundation

public struct Uninstaller: Sendable {

    private let trashMover: TrashMover

    public init(trashMover: TrashMover = TrashMover()) {
        self.trashMover = trashMover
    }

    public struct ExecuteOutcome: Sendable {
        public let app: InstalledApp
        public let movedCount: Int
        public let freedBytes: Int64
        public let manifest: TrashManifest
    }

    public enum UninstallError: Error, CustomStringConvertible {
        case systemApp(InstalledApp)
        case appRunning(InstalledApp)
        case alreadyCancelled

        public var description: String {
            switch self {
            case .systemApp(let app):
                return "\(app.name) is a system component and can't be uninstalled."
            case .appRunning(let app):
                return "\(app.name) is running. Quit it and try again."
            case .alreadyCancelled:
                return "Uninstall was cancelled."
            }
        }
    }

    /// Builds a plan without executing. Caller can inspect, then call
    /// `execute(plan:)`.
    public func buildPlan(
        app: InstalledApp,
        selectedResiduals: [Residual]
    ) -> UninstallPlan {
        let total = selectedResiduals.reduce(Int64(0)) { $0 + $1.size.bytes }
        return UninstallPlan(
            app: app,
            residuals: selectedResiduals,
            totalSize: ByteSize(bytes: total)
        )
    }

    /// Validates that the app is safe to uninstall. Throws
    /// `UninstallError` if not.
    public func validate(app: InstalledApp) throws {
        if app.isAppleSystemComponent {
            throw UninstallError.systemApp(app)
        }
        if isAppRunning(app) {
            throw UninstallError.appRunning(app)
        }
    }

    /// Executes the plan: trashes the app bundle and the
    /// selected residual paths, writes a manifest.
    @discardableResult
    public func execute(
        plan: UninstallPlan,
        manifestDirectory: URL? = nil
    ) async throws -> ExecuteOutcome {
        try validate(app: plan.app)
        if Task.isCancelled { throw UninstallError.alreadyCancelled }

        var urls: [URL] = [plan.app.bundleURL]
        urls.append(contentsOf: plan.residuals.map { $0.path })

        let manifest = try await trashMover.trash(
            items: urls,
            kind: "uninstall",
            manifestDirectory: manifestDirectory
        )
        return ExecuteOutcome(
            app: plan.app,
            movedCount: manifest.items.count,
            freedBytes: manifest.totalSize,
            manifest: manifest
        )
    }

    /// Cheap check for whether the app is currently running. We
    /// look for the bundle's executable in the running-process list.
    public func isAppRunning(_ app: InstalledApp) -> Bool {
        // The CFBundleExecutable from the plist
        let plistURL = app.bundleURL.appendingPathComponent("Contents/Info.plist")
        guard let dict = NSDictionary(contentsOf: plistURL) as? [String: Any],
              let executable = dict["CFBundleExecutable"] as? String else {
            return false
        }
        let execName = executable
        // NSWorkspace.runningApplications is the cheap API.
        for running in NSWorkspace.shared.runningApplications {
            if running.executableURL?.lastPathComponent == execName {
                return true
            }
        }
        return false
    }
}
