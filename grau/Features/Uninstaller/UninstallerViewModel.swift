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

    /// Sort options for the app list. Order in this enum is the
    /// order shown in the dropdown picker.
    enum SortOrder: String, CaseIterable, Identifiable {
        /// Most recently used apps first (Spotlight
        /// `kMDItemLastUsedDate`, descending). Apps that have
        /// never been launched sink to the bottom.
        case lastOpened
        /// Largest bundle first.
        case size
        /// Most recently installed first (bundle mtime, descending).
        case installDate
        /// A → Z by app name.
        case alphabetical

        var id: String { rawValue }
        var displayName: String {
            switch self {
            case .lastOpened:    "Latest Opened"
            case .size:          "Size"
            case .installDate:   "Install Date"
            case .alphabetical:  "Alphabetical"
            }
        }
    }

    private(set) var phase: Phase = .idle
    private(set) var apps: [InstalledApp] = []
    var selectedApp: InstalledApp?
    var residuals: [Residual] = []
    var selectedResidualIDs: Set<UUID> = []
    var errorMessage: String?
    private(set) var lastOutcome: Uninstaller.ExecuteOutcome?

    /// User-controlled search text. Filters the visible list by
    /// app name (case-insensitive substring match).
    var searchText: String = ""

    /// User-controlled sort order. Defaults to alphabetical (the
    /// most predictable — and what `AppScanner.scan()` already
    /// produces — so opening the screen "just works" until the
    /// user picks a different sort).
    var sortOrder: SortOrder = .alphabetical

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

    /// Same as `sizeTask` but for the Spotlight `kMDItemLastUsedDate`
    /// pass. Cancelled/restarted the same way.
    private var lastUsedTask: Task<Void, Never>?

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

    /// The list the view renders. Filters by `searchText` (if any)
    /// and sorts by `sortOrder`. `selectedApp` is rewritten to the
    /// filtered/sorted identity so the detail pane still highlights
    /// the right row after a sort change.
    var visibleApps: [InstalledApp] {
        let filtered: [InstalledApp]
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        if query.isEmpty {
            filtered = apps
        } else {
            filtered = apps.filter { $0.name.localizedCaseInsensitiveContains(query) }
        }
        return filtered.sorted(by: compareForSort)
    }

    private func compareForSort(_ lhs: InstalledApp, _ rhs: InstalledApp) -> Bool {
        switch sortOrder {
        case .alphabetical:
            // Standard Finder-style: locale-aware, case-insensitive,
            // and stable when names are equal (fall back to bundle id
            // so the order is deterministic).
            let lhsName = lhs.name.localizedCaseInsensitiveCompare(rhs.name)
            if lhsName != .orderedSame { return lhsName == .orderedAscending }
            return lhs.id < rhs.id
        case .size:
            // Largest first. Tiebreak by name so the order is stable
            // as sizes stream in.
            if lhs.bundleSize != rhs.bundleSize { return lhs.bundleSize > rhs.bundleSize }
            return lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
        case .installDate:
            // Newest first. Apps with no mtime sink to the bottom.
            switch (lhs.lastModified, rhs.lastModified) {
            case let (l?, r?): return l > r
            case (_?, nil):    return true
            case (nil, _?):    return false
            case (nil, nil):   return lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
            }
        case .lastOpened:
            // Newest first. Apps that have never been launched
            // (Spotlight returned nil) sink to the bottom.
            switch (lhs.lastUsedDate, rhs.lastUsedDate) {
            case let (l?, r?): return l > r
            case (_?, nil):    return true
            case (nil, _?):    return false
            case (nil, nil):   return lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
            }
        }
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
        // Cancel any in-flight background passes from a previous
        // scan before we tear down the cached state.
        sizeTask?.cancel()
        lastUsedTask?.cancel()
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
        // Same idea for the Spotlight "last opened" lookup. The
        // MDItem call is cheap but synchronous, and we may have
        // hundreds of apps, so we keep it off the initial render
        // path. The user can sort by "Latest Opened" before the
        // pass finishes — apps whose date hasn't streamed in yet
        // sort to the bottom (no date = treat as never used).
        lastUsedTask = Task { [weak self] in
            await self?.loadLastUsedDates()
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

    /// Fetches Spotlight's `kMDItemLastUsedDate` for every app
    /// concurrently, and writes each result back into the matching
    /// entry of `apps`. Apps that have never been launched stay
    /// with `lastUsedDate == nil` and sink to the bottom when the
    /// user sorts by "Latest Opened". Honors `Task.isCancelled` so
    /// a fresh `scan()` can abort the previous pass.
    private func loadLastUsedDates() async {
        let snapshot = apps
        await withTaskGroup(of: (Int, Date?).self) { group in
            for (idx, app) in snapshot.enumerated() {
                let url = app.bundleURL
                group.addTask {
                    (idx, LastUsedDateLoader.lastUsedDate(for: url))
                }
            }
            for await (idx, date) in group {
                if Task.isCancelled { return }
                guard idx < apps.count else { continue }
                // `apps` is the source of truth and the view's
                // @Observable binding — replacing an entry triggers
                // a row re-render and (if "Latest Opened" is the
                // current sort) a list re-order.
                apps[idx] = apps[idx].withLastUsedDate(date)
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
