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
    public var hasOnboarded: Bool {
        get { UserDefaults.standard.bool(forKey: Self.hasOnboardedKey) }
        set { UserDefaults.standard.set(newValue, forKey: Self.hasOnboardedKey) }
    }

    /// Whether the developer features are visible in the sidebar.
    public var devModeEnabled: Bool {
        get { UserDefaults.standard.bool(forKey: Self.devModeKey) }
        set { UserDefaults.standard.set(newValue, forKey: Self.devModeKey) }
    }

    public init() {
        // UserDefaults default for devModeEnabled is false.
        // If the key is not set, bool(forKey:) returns false. Good.
    }

    // MARK: - Keys

    private static let hasOnboardedKey = "grau.onboarded"
    private static let devModeKey = "grau.devModeEnabled"
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
    case settings

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .dashboard:    "Dashboard"
        case .clean:        "Clean"
        case .uninstaller:  "Uninstaller"
        case .diskLens:     "Disk Lens"
        case .duplicates:   "Duplicates"
        case .devMode:      "Dev Mode"
        case .settings:     "Settings"
        }
    }

    public var systemImage: String {
        switch self {
        case .dashboard:    "rectangle.grid.2x2"
        case .clean:        "trash"
        case .uninstaller:  "shippingbox"
        case .diskLens:     "circle.grid.3x3"
        case .duplicates:   "doc.on.doc"
        case .devMode:      "hammer"
        case .settings:     "gear"
        }
    }

    /// Whether this section is always shown. `.devMode` is only
    /// shown when the user has enabled "Show developer features" in
    /// Settings.
    public var requiresDevMode: Bool {
        self == .devMode
    }
}
