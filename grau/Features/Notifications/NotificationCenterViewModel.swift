//
//  NotificationCenterViewModel.swift
//  grau
//
//  View model for the in-app Notification Center.
//

import Foundation
import Observation
import graucore

@MainActor
@Observable
final class NotificationCenterViewModel {
    private(set) var entries: [NotificationLogEntry] = []
    private(set) var isLoading: Bool = false

    private let log: NotificationLog

    init(log: NotificationLog = NotificationLog()) {
        self.log = log
    }

    func refresh() async {
        isLoading = true
        defer { isLoading = false }
        entries = await log.read()
    }

    func clear() async {
        await log.clear()
        entries = []
    }
}
