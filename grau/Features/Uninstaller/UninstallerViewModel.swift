//
//  UninstallerViewModel.swift
//  grau
//

import Foundation
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
        phase = .loaded
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
