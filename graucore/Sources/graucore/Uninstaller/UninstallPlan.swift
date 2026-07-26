//
//  UninstallPlan.swift
//  graucore
//
//  The output of planning an uninstall: the app + the selected
//  residuals + the total size. Lives in memory only; persisted
//  via the manifest written by TrashMover after execution.
//

import Foundation

public struct UninstallPlan: Sendable, Hashable {
    public let app: InstalledApp
    public let residuals: [Residual]
    public let totalSize: ByteSize

    public init(app: InstalledApp, residuals: [Residual], totalSize: ByteSize) {
        self.app = app
        self.residuals = residuals
        self.totalSize = totalSize
    }
}
