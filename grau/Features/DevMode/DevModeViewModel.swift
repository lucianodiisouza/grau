//
//  DevModeViewModel.swift
//  grau
//
//  View model for the Dev Mode feature. Wraps `DevReportGenerator`
//  and tracks the latest report + scan state.
//

import Foundation
import Observation
import graucore

@MainActor
@Observable
final class DevModeViewModel {
    private(set) var report: DevReport?
    private(set) var isScanning: Bool = false
    var errorMessage: String?

    private let generator: DevReportGenerator

    init(generator: DevReportGenerator = DevReportGenerator()) {
        self.generator = generator
    }

    /// Runs the full dev-mode report generation. The six inspectors
    /// run in parallel inside `DevReportGenerator.generate()` so the
    /// user gets the full picture in roughly the time of the slowest
    /// single scan.
    func refresh() async {
        isScanning = true
        errorMessage = nil
        let r = await generator.generate()
        self.report = r
        isScanning = false
    }
}
