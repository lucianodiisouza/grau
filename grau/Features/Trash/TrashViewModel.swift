//
//  TrashViewModel.swift
//  grau
//
//  View model for the in-app trash restore UI.
//

import Foundation
import Observation
import graucore

@MainActor
@Observable
final class TrashViewModel {
    private(set) var manifests: [TrashManifestSummary] = []
    private(set) var isLoading: Bool = false
    private(set) var restoringID: UUID?
    /// Per-manifest outcome of the last restore attempt.
    var lastOutcomes: [UUID: TrashRestoreOutcome] = [:]

    private let restorer: TrashRestore

    init(restorer: TrashRestore = TrashRestore()) {
        self.restorer = restorer
    }

    func refresh() async {
        isLoading = true
        defer { isLoading = false }
        let m = await restorer.listManifests()
        self.manifests = m
    }

    func restore(manifestID: UUID) async {
        restoringID = manifestID
        let outcome = await restorer.restore(manifestID: manifestID)
        lastOutcomes[manifestID] = outcome
        restoringID = nil
    }
}
