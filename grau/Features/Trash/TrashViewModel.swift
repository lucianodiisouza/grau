//
//  TrashViewModel.swift
//  grau
//
//  View model for the in-app trash restore UI. v1.3 adds kind
//  + date filters so the user can narrow down past cleans.
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

    /// User-facing filter. `nil` = no filter (show all). v1.3
    /// adds kind filter; date filter is the next iteration.
    var kindFilter: String? = nil
    /// Inclusive lower bound for the timestamp. `nil` = no bound.
    var dateFrom: Date? = nil
    /// Inclusive upper bound for the timestamp. `nil` = no bound.
    var dateTo: Date? = nil

    private let restorer: TrashRestore

    init(restorer: TrashRestore = TrashRestore()) {
        self.restorer = restorer
    }

    /// Manifests after applying the kind + date filters.
    var filteredManifests: [TrashManifestSummary] {
        manifests.filter { summary in
            if let k = kindFilter, summary.kind != k { return false }
            if let from = dateFrom, summary.timestamp < from { return false }
            if let to = dateTo, summary.timestamp > to { return false }
            return true
        }
    }

    /// The set of distinct kinds currently in the manifest list.
    /// Drives the filter chip UI.
    var availableKinds: [String] {
        let set = Set(manifests.map { $0.kind })
        return set.sorted()
    }

    func refresh() async {
        isLoading = true
        defer { isLoading = false }
        let m = await restorer.listManifests()
        self.manifests = m
    }

    func clearFilters() {
        kindFilter = nil
        dateFrom = nil
        dateTo = nil
    }

    func restore(manifestID: UUID) async {
        restoringID = manifestID
        let outcome = await restorer.restore(manifestID: manifestID)
        lastOutcomes[manifestID] = outcome
        restoringID = nil
    }
}
