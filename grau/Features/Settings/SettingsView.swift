//
//  SettingsView.swift
//  grau
//
//  Settings window content. v1.7 adds a Notifications tab with
//  per-rule cooldowns (Phase 12.3).
//

import SwiftUI
import graucore

struct SettingsView: View {
    @Environment(AppViewModel.self) private var appVM
    @State private var permissionCoordinator = PermissionCoordinator()
    @State private var permissionState: PermissionState = .unknown
    @State private var notificationCoordinator = NotificationCoordinator()
    @State private var refreshTick: Int = 0

    var body: some View {
        TabView {
            privacyTab
                .tabItem { Label("Privacy", systemImage: "lock") }
            notificationsTab
                .tabItem { Label("Notifications", systemImage: "bell") }
            developerTab
                .tabItem { Label("Developer", systemImage: "hammer") }
            aboutTab
                .tabItem { Label("About", systemImage: "info.circle") }
        }
        .frame(width: 560, height: 440)
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
        }
        .formStyle(.grouped)
        .padding()
    }

    @ViewBuilder
    private var notificationsTab: some View {
        Form {
            Section {
                Text("Each rule fires when its threshold is crossed. The cooldown is the minimum gap between two fires — useful when a gauge hovers around its threshold.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } header: {
                Text("Per-rule cooldowns")
            }
            ForEach(NotificationRuleID.allCases, id: \.self) { rule in
                Section {
                    HStack {
                        Text(rule.displayName)
                        Spacer()
                        Text(cooldownText(for: rule))
                            .foregroundStyle(.secondary)
                            .monospacedDigit()
                    }
                    Picker(
                        "Cooldown",
                        selection: cooldownBinding(for: rule)
                    ) {
                        Text("No cooldown").tag(0.0)
                        Text("1 hour").tag(3600.0)
                        Text("6 hours").tag(6 * 3600.0)
                        Text("12 hours").tag(12 * 3600.0)
                        Text("1 day (default)").tag(24 * 3600.0)
                        Text("3 days").tag(3 * 24 * 3600.0)
                        Text("1 week").tag(7 * 24 * 3600.0)
                    }
                    .pickerStyle(.menu)
                    if let endsAt = notificationCoordinator.cooldownEndsAt(rule) {
                        Text("Cooling down until \(endsAt.formatted(date: .omitted, time: .shortened)).")
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    }
                }
            }
        }
        .formStyle(.grouped)
        .padding()
        // Force re-render of the "Cooling down until…" line each
        // time the user opens the tab so it doesn't go stale.
        .onAppear { refreshTick &+= 1 }
    }

    private func cooldownText(for rule: NotificationRuleID) -> String {
        let seconds = notificationCoordinator.cooldownSeconds(for: rule)
        return NotificationCooldown(ruleID: rule.rawValue, seconds: seconds).humanReadable
    }

    private func cooldownBinding(for rule: NotificationRuleID) -> Binding<TimeInterval> {
        Binding(
            get: { notificationCoordinator.cooldownSeconds(for: rule) },
            set: { newValue in
                notificationCoordinator.setCooldownSeconds(newValue, for: rule)
                refreshTick &+= 1
            }
        )
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
            Text("v1.7.0")
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
