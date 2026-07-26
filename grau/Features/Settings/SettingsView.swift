//
//  SettingsView.swift
//  grau
//
//  Settings window content. For now: Privacy + Developer sections.
//  Other sections land in later phases.
//

import SwiftUI
import graucore

struct SettingsView: View {
    @Environment(AppViewModel.self) private var appVM
    @State private var permissionCoordinator = PermissionCoordinator()
    @State private var permissionState: PermissionState = .unknown

    var body: some View {
        TabView {
            privacyTab
                .tabItem { Label("Privacy", systemImage: "lock") }
            developerTab
                .tabItem { Label("Developer", systemImage: "hammer") }
            aboutTab
                .tabItem { Label("About", systemImage: "info.circle") }
        }
        .frame(width: 560, height: 400)
        .task {
            await permissionCoordinator.refresh()
            permissionState = permissionCoordinator.state
        }
    }

    @ViewBuilder
    private var privacyTab: some View {
        @Bindable var bindableAppVM = appVM
        Form {
            Section("Full Disk Access") {
                HStack {
                    Image(systemName: permissionState.fullDiskAccess
                          ? "checkmark.circle.fill"
                          : "exclamationmark.triangle.fill")
                        .foregroundStyle(permissionState.fullDiskAccess
                                         ? Color("grau-success")
                                         : Color("grau-warning"))
                    Text(permissionState.fullDiskAccess
                         ? "Granted — system caches and logs are accessible"
                         : "Not granted — System Cache and Logs are skipped")
                }
                HStack {
                    Button("Open System Settings") {
                        permissionCoordinator.openSystemSettingsAndPoll()
                    }
                    Button("Re-check") {
                        Task {
                            await permissionCoordinator.refresh()
                            permissionState = permissionCoordinator.state
                        }
                    }
                }
            }
            Section("Notifications") {
                Text("Grau notifies you about junk to clean, low disk space, and big trash. All rules are toggleable per-rule in a future update.")
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .padding()
    }

    @ViewBuilder
    private var developerTab: some View {
        @Bindable var bindableAppVM = appVM
        Form {
            Section {
                Toggle("Show developer features", isOn: $bindableAppVM.devModeEnabled)
                Text("Adds the Dev Mode item to the sidebar (node_modules, Docker, package caches, simulators, DerivedData).")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } header: {
                Text("Dev Mode")
            }
            Section {
                Stepper("Old downloads threshold: \(appVM.downloadsThresholdDays) days",
                        value: $bindableAppVM.downloadsThresholdDays,
                        in: 30...365)
            } header: {
                Text("Junk cleaner")
            }
        }
        .formStyle(.grouped)
        .padding()
    }

    @ViewBuilder
    private var aboutTab: some View {
        VStack(spacing: Spacing.lg) {
            Image(systemName: "circle.hexagongrid.fill")
                .font(.system(size: 64))
                .foregroundStyle(Color("grau-accent"))
            Text("Grau")
                .font(.title)
            Text("v0.2.0-beta.1")
                .foregroundStyle(.secondary)
            Text("A free, open-source, native macOS utility for cleaning, inspecting, and managing your Mac's storage.")
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
                .padding(.horizontal, Spacing.xxl)
            Spacer()
            Text("MIT — see LICENSE")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .padding()
    }
}
