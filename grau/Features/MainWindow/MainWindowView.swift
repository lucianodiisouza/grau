//
//  MainWindowView.swift
//  grau
//
//  NavigationSplitView with the sidebar of AppSections and a
//  detail view that switches based on the selected section.
//  See docs/DESIGN.md § 2.1.
//

import SwiftUI
import AppKit

struct MainWindowView: View {
    @Environment(AppViewModel.self) private var appVM

    var body: some View {
        @Bindable var bindableVM = appVM

        NavigationSplitView {
            List(
                AppSection.allCases.filter { section in
                    !section.requiresDevMode || appVM.devModeEnabled
                },
                selection: $bindableVM.selectedSection
            ) { section in
                Label(section.title, systemImage: section.systemImage)
                    .tag(section)
            }
            .listStyle(.sidebar)
            .navigationSplitViewColumnWidth(min: 180, ideal: 200, max: 240)
        } detail: {
            // Each section renders its own header inside its own
            // view (so the title can sit next to action buttons
            // like "Scan"). NavigationSplitView would otherwise
            // show that same title again in a macOS title bar
            // above the detail — we hide the window toolbar here
            // and keep the window title in sync via
            // NSApp.mainWindow?.title so Dock / Cmd+Tab / Window
            // menu still report the right name.
            detail
                .toolbar(.hidden, for: .windowToolbar)
        }
        .navigationSplitViewStyle(.balanced)
        // Keep the macOS window title (Dock / Cmd+Tab / Window
        // menu) in sync with the active section, since we're no
        // longer showing it on screen.
        .onChange(of: appVM.selectedSection) { _, newValue in
            NSApp.mainWindow?.title = newValue.title
        }
        .task {
            // Set once on first appearance for the initial section.
            NSApp.mainWindow?.title = appVM.selectedSection.title
        }
        // Sync the Dock icon with this window's visibility: the icon
        // appears while the dashboard is on screen and disappears
        // once the user closes it. See DockIconController.
        .syncDockIconWithWindowVisibility()
    }

    @ViewBuilder
    @MainActor
    private var detail: some View {
        switch appVM.selectedSection {
        case .dashboard:    DashboardView()
        case .clean:        JunkCleanerView()
        case .uninstaller:  UninstallerView()
        case .diskLens:     DiskLensView()
        case .duplicates:   DuplicatesView()
        case .devMode:      DevModeView()
        case .trash:        TrashView()
        case .notifications: NotificationCenterView()
        case .automation:   AutomationView()
        case .settings:     SettingsView()
        }
    }
}

#Preview {
    MainWindowView()
        .environment(AppViewModel())
        .frame(width: 900, height: 600)
}
