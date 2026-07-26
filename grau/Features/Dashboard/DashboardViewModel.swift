//
//  DashboardViewModel.swift
//  grau
//
//  View model for the home dashboard. Wires the storage card
//  to VolumeMonitor, the trash card to TrashInfoReader, and
//  the last-scan card to ~/.grau/state.json.
//
//  v1.5 feature. Replaces the Phase 0 fake-data cards with
//  real reads.
//

import Foundation
import Observation
import graucore

@MainActor
@Observable
final class DashboardViewModel {
    private(set) var storageUsed: ByteSize = .zero
    private(set) var storageTotal: ByteSize = .zero
    private(set) var trashItemCount: Int = 0
    private(set) var trashSize: ByteSize = .zero
    private(set) var lastJunkScan: LastScanSummary?
    private(set) var lastClean: LastScanSummary?
    private(set) var isLoading: Bool = false

    private let volumeMonitor: VolumeMonitor
    private let trashReader: TrashInfoReader
    private let manifestStore: ManifestStore

    init(
        volumeMonitor: VolumeMonitor = VolumeMonitor(),
        trashReader: TrashInfoReader = TrashInfoReader(),
        manifestStore: ManifestStore = ManifestStore()
    ) {
        self.volumeMonitor = volumeMonitor
        self.trashReader = trashReader
        self.manifestStore = manifestStore
    }

    /// Reads storage + trash + state.json. Safe to call repeatedly.
    func refresh() async {
        isLoading = true
        defer { isLoading = false }

        // Storage: sum across all mounted volumes.
        let volumes = await volumeMonitor.currentVolumes()
        let used = volumes.reduce(Int64(0)) { $0 + $1.usedBytes }
        let total = volumes.reduce(Int64(0)) { $0 + $1.totalBytes }
        storageUsed = ByteSize(bytes: used)
        storageTotal = ByteSize(bytes: total)

        // Trash: read ~/.Trash/.
        let trash = trashReader.read()
        trashSize = trash.size
        trashItemCount = trash.itemCount

        // State file: last junk scan + last clean.
        if let state = try? manifestStore.read(StateFile.self, from: ManifestStore.stateFile) {
            lastJunkScan = state.lastJunkScan
            lastClean = state.lastClean
        }
    }

    /// Computes the storage-bar fill fraction, clamped to [0, 1].
    var storageFraction: Double {
        guard storageTotal.bytes > 0 else { return 0 }
        let f = Double(storageUsed.bytes) / Double(storageTotal.bytes)
        return min(1, max(0, f))
    }

    /// Bytes free = total - used, never negative.
    var storageFree: ByteSize {
        ByteSize(bytes: max(0, storageTotal.bytes - storageUsed.bytes))
    }
}
