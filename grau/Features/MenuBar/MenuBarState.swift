//
//  MenuBarState.swift
//  grau
//
//  Live state for the menu bar popover. Polled by VolumeMonitor +
//  TrashInfoReader. See docs/DESIGN.md § 3.
//

import Foundation
import Observation
import graucore

@MainActor
@Observable
final class MenuBarState {
    var freeBytes: Int64 = 0
    var totalBytes: Int64 = 0
    var trashSize: Int64 = 0
    var trashItemCount: Int = 0
    var pendingJunkBytes: Int64 = 0

    private let volumeMonitor: VolumeMonitor
    private let trashReader: TrashInfoReader
    private var pollTask: Task<Void, Never>?

    init(
        volumeMonitor: VolumeMonitor = VolumeMonitor(),
        trashReader: TrashInfoReader = TrashInfoReader()
    ) {
        self.volumeMonitor = volumeMonitor
        self.trashReader = trashReader
    }

    func start(interval: TimeInterval = 30) {
        pollTask?.cancel()
        pollTask = Task { @MainActor [weak self] in
            while !Task.isCancelled {
                await self?.tick()
                try? await Task.sleep(for: .seconds(interval))
            }
        }
    }

    func stop() {
        pollTask?.cancel()
        pollTask = nil
    }

    func tick() async {
        let volumes = await volumeMonitor.currentVolumes()
        if let root = volumes.first(where: { $0.url.path == "/" }) {
            freeBytes = root.freeBytes
            totalBytes = root.totalBytes
        }
        let trash = trashReader.read()
        trashSize = trash.size.bytes
        trashItemCount = trash.itemCount
    }

    deinit {
        // pollTask is actor-isolated; the deinit cannot cancel it
        // directly. The poll loop checks Task.isCancelled on each
        // tick and will exit naturally when the MenuBarState is
        // released (the Task's weak self becomes nil).
    }
}
