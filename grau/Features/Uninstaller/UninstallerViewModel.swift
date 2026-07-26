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

    /// Per-app bundle size, filled in incrementally after `scan()`
    /// returns. Keyed by `InstalledApp.id`. A missing key means
    /// "still computing"; a present key (even with `bytes == 0`)
    /// means "done — bundle is empty or unreadable".
    private(set) var bundleSizes: [String: ByteSize] = [:]

    /// The Task that's currently streaming bundle sizes in the
    /// background, so a fresh `scan()` can cancel the previous one.
    private var sizeTask: Task<Void, Never>?

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

    /// Total size that will be freed if the user confirms the
    /// uninstall: the bundle itself plus every selected residual.
    /// The bundle is always counted (it goes to Trash no matter
    /// which residuals are checked) so this is never less than
    /// `selectedApp?.bundleSize` once the size has been computed.
    /// Returns `.zero` if no app is selected.
    var totalSelectedSize: ByteSize {
        guard let app = selectedApp else { return .zero }
        let bundleBytes = bundleSizes[app.id]?.bytes ?? 0
        let residualBytes = residuals
            .filter { selectedResidualIDs.contains($0.id) }
            .reduce(Int64(0)) { $0 + $1.size.bytes }
        return ByteSize(bytes: bundleBytes + residualBytes)
    }

    func scan() async {
        phase = .scanning
        errorMessage = nil
        // Cancel any in-flight sizing from a previous scan.
        sizeTask?.cancel()
        bundleSizes.removeAll()
        let installed = await scanner.scan()
        apps = installed
        warmIconCache(for: installed)
        phase = .loaded
        // Kick off bundle size computation in the background so the
        // list renders immediately and rows fill in as each size
        // resolves. A 30 GB Xcode.app would otherwise block the
        // list for a couple of seconds.
        sizeTask = Task { [weak self] in
            await self?.computeBundleSizes()
        }
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

    /// Returns the cached bundle size for `app`, or `nil` if the
    /// background sizing pass hasn't finished yet. The view
    /// renders a "—" placeholder while nil.
    func bundleSize(for app: InstalledApp) -> ByteSize? {
        bundleSizes[app.id]
    }

    /// True once the size for `app` has been computed (even if
    /// the result is 0 — e.g. unreadable bundle). False while the
    /// background pass is still running.
    func hasComputedSize(for app: InstalledApp) -> Bool {
        bundleSizes[app.id] != nil
    }

    private func computeBundleSizes() async {
        // Snapshot the current apps so a concurrent scan() doesn't
        // race us. We mutate `bundleSizes` on the main actor.
        let snapshot = apps
        await withTaskGroup(of: (String, Int64).self) { group in
            for app in snapshot {
                let url = app.bundleURL
                let id = app.id
                group.addTask {
                    let bytes = AppScanner.computeBundleSize(at: url)
                    return (id, bytes)
                }
            }
            for await (id, bytes) in group {
                if Task.isCancelled { return }
                bundleSizes[id] = ByteSize(bytes: bytes)
            }
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
