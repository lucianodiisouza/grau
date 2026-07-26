//
//  MainWindowView.swift
//  grau
//
//  NavigationSplitView with the sidebar of AppSections and a
//  detail view that switches based on the selected section.
//  See docs/DESIGN.md § 2.1.
//

import SwiftUI

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
            .navigationTitle("Grau")
            .navigationSplitViewColumnWidth(min: 180, ideal: 200, max: 240)
        } detail: {
            detail
                .navigationTitle(appVM.selectedSection.title)
        }
        .navigationSplitViewStyle(.balanced)
    }

    @ViewBuilder
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
