//
//  JunkCleanerViewModel.swift
//  grau
//
//  @MainActor @Observable VM that wires the UI to the engines.
//

import Foundation
import Observation
import graucore

@MainActor
@Observable
final class JunkCleanerViewModel {
    enum Phase: Equatable {
        case idle
        case scanning
        case showingResults
        case confirming
        case cleaning
        case completed
    }

    private(set) var phase: Phase = .idle
    private(set) var results: [JunkResult] = []
    private(set) var lastOutcome: JunkCleaner.CleanupOutcome?
    var errorMessage: String?
    var selectedCategories: Set<JunkCategory> = []

    private let scanner: JunkScanner
    private let cleaner: JunkCleaner
    private let permissionChecker: PermissionChecker
    private let manifestStore: ManifestStore

    init(
        scanner: JunkScanner = JunkScanner(),
        cleaner: JunkCleaner = JunkCleaner(),
        permissionChecker: PermissionChecker = PermissionChecker(),
        manifestStore: ManifestStore = ManifestStore()
    ) {
        self.scanner = scanner
        self.cleaner = cleaner
        self.permissionChecker = permissionChecker
        self.manifestStore = manifestStore
        // Initialize default selections
        for def in JunkDefinitions.standard where def.defaultSelected {
            selectedCategories.insert(def.id)
        }
    }

    /// Total size of selected categories that are not skipped.
    var selectedSize: ByteSize {
        ByteSize(bytes: results
            .filter { selectedCategories.contains($0.category) && !$0.skipped }
            .reduce(0) { $0 + $1.size.bytes })
    }

    /// True if any selected category is userCaution (triggers the
    /// extra confirmation step in the UI).
    var hasUserCautionSelection: Bool {
        for def in JunkDefinitions.standard
        where selectedCategories.contains(def.id) {
            if def.safety == .userCaution { return true }
        }
        return false
    }

    func scan() async {
        phase = .scanning
        errorMessage = nil
        let fda = await permissionChecker.hasFullDiskAccess()
        let r = await scanner.scan(
            definitions: JunkDefinitions.standard,
            fdaGranted: fda
        )
        results = r
        phase = .showingResults
    }

    func startClean() {
        phase = .confirming
    }

    func cancelClean() {
        phase = .showingResults
    }

    func confirmClean() async {
        let selected = results.filter { selectedCategories.contains($0.category) }
        phase = .cleaning
        do {
            let outcome = try await cleaner.clean(selectedResults: selected)
            // Persist last-clean summary
            let summary = LastScanSummary(
                kind: "junk",
                totalBytes: outcome.freedBytes,
                itemCount: outcome.movedCount,
                finishedAt: Date()
            )
            var state = (try? manifestStore.read(StateFile.self, from: ManifestStore.stateFile)) ?? StateFile()
            state.lastJunkScan = summary
            state.lastClean = summary
            try? manifestStore.write(state, to: ManifestStore.stateFile)
            lastOutcome = outcome
            phase = .completed
            // Re-scan to update the size display
            await scan()
        } catch {
            errorMessage = error.localizedDescription
            phase = .showingResults
        }
    }

    func dismissCompleted() {
        phase = .showingResults
    }
}
