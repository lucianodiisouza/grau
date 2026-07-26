//
//  AppViewModel.swift
//  grau
//
//  Top-level view model. Owns the long-lived state (scan results,
//  permission state, menu bar state). Phase 1 wires in the real
//  engines; for now it is a placeholder with empty state.
//

import Foundation
import Observation

@MainActor
@Observable
public final class AppViewModel {
    // MARK: - Top-level state

    /// Currently-selected sidebar item. Drives which feature view
    /// the main window renders.
    public var selectedSection: AppSection = .dashboard

    /// Whether the user has completed the first-run onboarding.
    /// Stored property (not computed) so the @Observable system
    /// tracks writes and SwiftUI views re-render. Persisted on write.
    public var hasOnboarded: Bool {
        didSet { UserDefaults.standard.set(hasOnboarded, forKey: Self.hasOnboardedKey) }
    }

    /// Whether the developer features are visible in the sidebar.
    /// Persisted on write.
    public var devModeEnabled: Bool {
        didSet { UserDefaults.standard.set(devModeEnabled, forKey: Self.devModeKey) }
    }

    /// Threshold in days for the Old Downloads category. Default 90.
    /// Persisted on write.
    public var downloadsThresholdDays: Int {
        didSet { UserDefaults.standard.set(downloadsThresholdDays, forKey: Self.downloadsThresholdDaysKey) }
    }

    public init() {
        // Read persisted state once at init time. The `didSet` hooks
        // on the stored properties above mirror every write back to
        // UserDefaults, so callers no longer need to invoke persist().
        self.hasOnboarded = UserDefaults.standard.bool(forKey: Self.hasOnboardedKey)
        self.devModeEnabled = UserDefaults.standard.bool(forKey: Self.devModeKey)
        let storedDays = UserDefaults.standard.integer(forKey: Self.downloadsThresholdDaysKey)
        self.downloadsThresholdDays = storedDays == 0 ? 90 : storedDays
    }

    // MARK: - Keys

    private static let hasOnboardedKey = "grau.onboarded"
    private static let devModeKey = "grau.devModeEnabled"
    private static let downloadsThresholdDaysKey = "grau.downloadsThresholdDays"
}

/// Top-level navigation sections. Dev mode is hidden unless the
/// `devModeEnabled` flag is on. See docs/DESIGN.md and REVIEW.md S9.
public enum AppSection: String, CaseIterable, Identifiable, Hashable {
    case dashboard
    case clean
    case uninstaller
    case diskLens
    case duplicates
    case devMode
    case trash
    case notifications
    case automation
    case settings

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .dashboard:       "Dashboard"
        case .clean:           "Clean"
        case .uninstaller:     "Uninstaller"
        case .diskLens:        "Disk Lens"
        case .duplicates:      "Duplicates"
        case .devMode:         "Dev Mode"
        case .trash:           "Trash"
        case .notifications:   "Notifications"
        case .automation:      "Automation"
        case .settings:        "Settings"
        }
    }

    public var systemImage: String {
        switch self {
        case .dashboard:       "rectangle.grid.2x2"
        case .clean:           "trash"
        case .uninstaller:     "shippingbox"
        case .diskLens:        "circle.grid.3x3"
        case .duplicates:      "doc.on.doc"
        case .devMode:         "hammer"
        case .trash:           "arrow.uturn.backward.circle"
        case .notifications:   "bell"
        case .automation:      "wand.and.stars"
        case .settings:        "gear"
        }
    }

    /// Whether this section is always shown. `.devMode` is only
    /// shown when the user has enabled "Show developer features" in
    /// Settings.
    public var requiresDevMode: Bool {
        self == .devMode
    }
}
