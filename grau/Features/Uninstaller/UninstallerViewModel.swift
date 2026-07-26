//
//  UninstallerViewModel.swift
//  grau
//

import Foundation
import AppKit
import Observation
import graucore

@MainActor
@Observable
final class UninstallerViewModel {
    enum Phase: Equatable {
        case idle
        case scanning
        case loaded
        case confirming
        case uninstalling
        case completed
    }

    private(set) var phase: Phase = .idle
    private(set) var apps: [InstalledApp] = []
    var selectedApp: InstalledApp?
    var residuals: [Residual] = []
    var selectedResidualIDs: Set<UUID> = []
    var errorMessage: String?
    private(set) var lastOutcome: Uninstaller.ExecuteOutcome?

    /// Cache of app icons keyed by bundle URL path, so the SwiftUI
    /// view doesn't have to call `NSWorkspace` on every render. We
    /// pre-warm the cache for every scanned app after `scan()`.
    private(set) var icons: [String: NSImage] = [:]

    private let scanner: AppScanner
    private let finder: ResidualFinder
    private let uninstaller: Uninstaller

    init(
        scanner: AppScanner = AppScanner(),
        finder: ResidualFinder = ResidualFinder(),
        uninstaller: Uninstaller = Uninstaller()
    ) {
        self.scanner = scanner
        self.finder = finder
        self.uninstaller = uninstaller
    }

    /// Look up the cached icon for an app. Returns nil until
    /// `scan()` has warmed the cache, in which case the view should
    /// show a placeholder (the generic app SF Symbol).
    func icon(for app: InstalledApp) -> NSImage? {
        icons[app.bundleURL.path]
    }

    var totalSelectedSize: ByteSize {
        ByteSize(bytes: residuals
            .filter { selectedResidualIDs.contains($0.id) }
            .reduce(0) { $0 + $1.size.bytes }
        )
    }

    func scan() async {
        phase = .scanning
        errorMessage = nil
        let installed = await scanner.scan()
        apps = installed
        warmIconCache(for: installed)
        phase = .loaded
    }

    /// Pre-loads the real `.icns` icon for every scanned app via
    /// `NSWorkspace`. This is cheap (a single disk read per bundle)
    /// and means `icon(for:)` is a pure dictionary lookup in
    /// SwiftUI's render path.
    private func warmIconCache(for apps: [InstalledApp]) {
        for app in apps {
            let key = app.bundleURL.path
            if icons[key] != nil { continue }
            // `icon(forFile:)` resolves through LaunchServices and
            // returns the canonical icon the user sees in Finder,
            // honoring custom .icns / document icons.
            let image = NSWorkspace.shared.icon(forFile: key)
            image.size = NSSize(width: 32, height: 32)
            icons[key] = image
        }
    }

    func selectApp(_ app: InstalledApp) async {
        selectedApp = app
        // Compute residuals for this app.
        let found = await finder.findResiduals(for: app)
        residuals = found
        // Default selection: per ResidualKind.defaultSelected
        selectedResidualIDs = Set(
            found.filter { $0.kind.defaultSelected }.map { $0.id }
        )
    }

    func startUninstall() {
        phase = .confirming
    }

    func cancelUninstall() {
        phase = .loaded
    }

    func confirmUninstall() async {
        guard let app = selectedApp else { return }
        do {
            try uninstaller.validate(app: app)
        } catch {
            errorMessage = error.localizedDescription
            return
        }
        let selected = residuals.filter { selectedResidualIDs.contains($0.id) }
        let plan = uninstaller.buildPlan(app: app, selectedResiduals: selected)
        phase = .uninstalling
        do {
            let outcome = try await uninstaller.execute(plan: plan)
            lastOutcome = outcome
            phase = .completed
        } catch {
            errorMessage = error.localizedDescription
            phase = .loaded
        }
    }

    func dismissCompleted() {
        // Re-scan to remove the just-uninstalled app
        Task { await scan() }
        phase = .loaded
        selectedApp = nil
        residuals = []
        selectedResidualIDs = []
        lastOutcome = nil
    }
}
