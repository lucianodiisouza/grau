//
//  PermissionCoordinator.swift
//  grau
//
//  Manages the FDA state and the polling re-check after the user
//  opens System Settings. See docs/PERMISSIONS.md § 2.5 and § 6.
//

import AppKit
import Foundation
import Observation
import graucore

@MainActor
@Observable
final class PermissionCoordinator {
    private(set) var state: PermissionState = .unknown
    private let checker: PermissionChecker
    private var pollTask: Task<Void, Never>?

    init(checker: PermissionChecker = PermissionChecker()) {
        self.checker = checker
    }

    func refresh() async {
        let fda = await checker.hasFullDiskAccess()
        state.fullDiskAccess = fda
    }

    /// Opens System Settings to the Privacy pane and polls for
    /// the FDA toggle to flip. Times out after ~60s of waiting.
    func openSystemSettingsAndPoll() {
        let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_AllFiles")!
        NSWorkspace.shared.open(url)

        pollTask?.cancel()
        pollTask = Task { [weak self] in
            guard let self else { return }
            // Polling schedule: 5, 7, 9, 12, 16, 22, 30, 45, 60 s
            let delays: [Int] = [5, 7, 9, 12, 16, 22, 30, 45, 60]
            for delay in delays {
                if Task.isCancelled { return }
                try? await Task.sleep(for: .seconds(delay))
                await self.refresh()
                if self.state.fullDiskAccess { return }
            }
        }
    }

    func cancelPolling() {
        pollTask?.cancel()
        pollTask = nil
    }
}
