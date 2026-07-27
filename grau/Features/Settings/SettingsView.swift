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
    @State private var permissionCoordinator: PermissionCoordinator
    @State private var permissionState: PermissionState = .unknown
    @State private var notificationCoordinator: NotificationCoordinator
    @State private var refreshTick: Int = 0

    @MainActor
    init() {
        // Both PermissionCoordinator and NotificationCoordinator
        // are @MainActor — construct in the struct's init
        // (implicitly @MainActor for a SwiftUI View).
        // See docs/TROUBLESHOOTING.md#strict-concurrency.
        _permissionCoordinator = State(wrappedValue: PermissionCoordinator())
        _notificationCoordinator = State(wrappedValue: NotificationCoordinator())
    }

    var body: some View {
        // Single scrolling page instead of a TabView. Settings is
        // something the user opens once and tweaks a couple of
        // times — hunting through tabs to discover that
        // Notifications or Developer even exist is worse than just
        // scrolling. About stays at the top as a small hero;
        // the rest of the sections follow.
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.lg) {
                aboutHero
                privacySection
                notificationsSection
                developerSection
            }
            .padding(Spacing.lg)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(width: 560, height: 480)
        .task {
            await permissionCoordinator.refresh()
            permissionState = permissionCoordinator.state
        }
    }

    @ViewBuilder
    @MainActor
    private var aboutHero: some View {
        HStack(alignment: .top, spacing: Spacing.md) {
            Image(systemName: "circle.hexagongrid.fill")
                .font(.system(size: 40))
                .foregroundStyle(Color("grau-accent"))
            VStack(alignment: .leading, spacing: 2) {
                Text("Grau")
                    .font(.title2.weight(.semibold))
                Text("v1.7.0 · MIT")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
    }

    @ViewBuilder
    @MainActor
    private var privacySection: some View {
        @Bindable var bindableAppVM = appVM
        VStack(alignment: .leading, spacing: Spacing.md) {
            sectionHeader("Privacy", systemImage: "lock")
            GroupBox {
                VStack(alignment: .leading, spacing: Spacing.sm) {
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
                            let permissionCoordinator = permissionCoordinator
                            Task {
                                await permissionCoordinator.refresh()
                                permissionState = permissionCoordinator.state
                            }
                        }
                    }
                }
                .padding(Spacing.sm)
            }
        }
    }

    @ViewBuilder
    @MainActor
    private var notificationsSection: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            sectionHeader("Notifications", systemImage: "bell")
            Text("Each rule fires when its threshold is crossed. The cooldown is the minimum gap between two fires — useful when a gauge hovers around its threshold.")
                .font(.caption)
                .foregroundStyle(.secondary)
            ForEach(NotificationRuleID.allCases, id: \.self) { rule in
                ruleCard(for: rule)
            }
        }
    }

    @ViewBuilder
    @MainActor
    private func ruleCard(for rule: NotificationRuleID) -> some View {
        GroupBox {
            VStack(alignment: .leading, spacing: Spacing.sm) {
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
            .padding(Spacing.sm)
        }
    }

    @MainActor
    private func cooldownText(for rule: NotificationRuleID) -> String {
        let seconds = notificationCoordinator.cooldownSeconds(for: rule)
        return NotificationCooldown(ruleID: rule.rawValue, seconds: seconds).humanReadable
    }

    @MainActor
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
    @MainActor
    private var developerSection: some View {
        @Bindable var bindableAppVM = appVM
        VStack(alignment: .leading, spacing: Spacing.md) {
            sectionHeader("Developer", systemImage: "hammer")
            GroupBox {
                VStack(alignment: .leading, spacing: Spacing.sm) {
                    Toggle("Show developer features", isOn: $bindableAppVM.devModeEnabled)
                    Text("Adds the Dev Mode item to the sidebar (node_modules, Docker, package caches, simulators, DerivedData).")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(Spacing.sm)
            }
            GroupBox {
                VStack(alignment: .leading, spacing: Spacing.sm) {
                    Stepper("Old downloads threshold: \(appVM.downloadsThresholdDays) days",
                            value: $bindableAppVM.downloadsThresholdDays,
                            in: 30...365)
                }
                .padding(Spacing.sm)
            }
        }
    }

    @ViewBuilder
    @MainActor
    private func sectionHeader(_ title: String, systemImage: String) -> some View {
        HStack(spacing: Spacing.xs) {
            Image(systemName: systemImage)
                .foregroundStyle(.secondary)
            Text(title)
                .font(.headline)
            Spacer()
        }
    }
}
