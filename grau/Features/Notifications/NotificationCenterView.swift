//
//  NotificationCenterView.swift
//  grau
//
//  In-app log of every notification Grau has fired. Backed by
//  NotificationLog (graucore/Notifications/NotificationLog.swift)
//  which persists to ~/.grau/notification-log.json.
//
//  v1.4 feature. The user can review past alerts and clear the
//  log. The sidebar item is "Notifications" (bell SF Symbol).
//
//  v1.7 (Phase 12.3) adds a "Rule status" header card above the
//  log that shows each rule's current cooldown state.
//

import SwiftUI
import graucore

struct NotificationCenterView: View {
    @State private var viewModel = NotificationCenterViewModel()
    @State private var notificationCoordinator = NotificationCoordinator()
    @State private var refreshTick: Int = 0

    var body: some View {
        VStack(spacing: 0) {
            toolbar
            Divider()
            ruleStatusCard
            Divider()
            content
        }
        .onAppear { refreshTick &+= 1 }
    }

    @ViewBuilder
    private var toolbar: some View {
        HStack {
            Text("Notifications")
                .font(.title2.weight(.semibold))
            Spacer()
            Text("Past alerts Grau has shown you. The log is capped at 200 entries and persists in ~/.grau/.")
                .font(.caption)
                .foregroundStyle(.secondary)
            Spacer()
            Button {
                Task {
                    await viewModel.refresh()
                    refreshTick &+= 1
                }
            } label: {
                Label("Refresh", systemImage: "arrow.clockwise")
            }
            .buttonStyle(.borderless)
            if !viewModel.entries.isEmpty {
                Button(role: .destructive) {
                    Task { await viewModel.clear() }
                } label: {
                    Label("Clear", systemImage: "trash")
                }
                .buttonStyle(.borderless)
            }
        }
        .padding(Spacing.lg)
    }

    @ViewBuilder
    private var ruleStatusCard: some View {
        // Touch refreshTick so this view re-evaluates on each refresh.
        let _ = refreshTick
        CardView {
            VStack(alignment: .leading, spacing: Spacing.sm) {
                Text("Rule status")
                    .font(.headline)
                ForEach(NotificationRuleID.allCases, id: \.self) { rule in
                    HStack(spacing: Spacing.sm) {
                        Image(systemName: iconFor(ruleID: rule.rawValue))
                            .foregroundStyle(tintFor(ruleID: rule.rawValue))
                            .frame(width: 20)
                        Text(rule.displayName)
                        Spacer()
                        if let endsAt = notificationCoordinator.cooldownEndsAt(rule) {
                            Text("Cooling down until \(endsAt.formatted(date: .omitted, time: .shortened))")
                                .font(.caption)
                                .foregroundStyle(Color("grau-warning"))
                        } else if !notificationCoordinator.canFire(rule) {
                            Text("Disabled")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        } else {
                            Text("Ready")
                                .font(.caption)
                                .foregroundStyle(Color("grau-success"))
                        }
                    }
                }
            }
        }
        .padding(Spacing.lg)
    }

    @ViewBuilder
    private var content: some View {
        if viewModel.isLoading {
            ProgressView("Loading…")
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if viewModel.entries.isEmpty {
            EmptyStateView(
                icon: "bell",
                title: "No notifications yet",
                message: "Grau fires an alert when a clean yields more than 1 GB of junk, your disk hits 90%, or your trash crosses 5 GB. Check back after a scan."
            )
        } else {
            ScrollView {
                LazyVStack(spacing: Spacing.md) {
                    ForEach(viewModel.entries) { entry in
                        notificationCard(entry)
                    }
                }
                .padding(Spacing.lg)
            }
        }
    }

    @ViewBuilder
    private func notificationCard(_ entry: NotificationLogEntry) -> some View {
        CardView {
            HStack(alignment: .top, spacing: Spacing.md) {
                Image(systemName: iconFor(ruleID: entry.ruleID))
                    .font(.title2)
                    .foregroundStyle(tintFor(ruleID: entry.ruleID))
                    .frame(width: 28)
                VStack(alignment: .leading, spacing: Spacing.xs) {
                    HStack {
                        Text(entry.title)
                            .font(.headline)
                        Spacer()
                        Text(entry.timestamp.formatted(date: .abbreviated, time: .shortened))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Text(entry.body)
                        .font(.callout)
                    Text(humanLabel(for: entry.ruleID))
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
            }
        }
    }

    private func iconFor(ruleID: String) -> String {
        switch ruleID {
        case "junk.gt1gb":       "trash"
        case "disk.full.90":     "internaldrive"
        case "trash.full.5gb":   "trash.circle"
        default:                 "bell"
        }
    }

    private func tintFor(ruleID: String) -> Color {
        switch ruleID {
        case "junk.gt1gb":       Color("grau-accent")
        case "disk.full.90":     Color("grau-danger")
        case "trash.full.5gb":   Color("grau-warning")
        default:                 Color("grau-gray-500")
        }
    }

    private func humanLabel(for ruleID: String) -> String {
        switch ruleID {
        case "junk.gt1gb":       "Rule: junk > 1 GB"
        case "disk.full.90":     "Rule: disk > 90% full"
        case "trash.full.5gb":   "Rule: trash > 5 GB"
        default:                 "Rule: \(ruleID)"
        }
    }
}

#Preview {
    NotificationCenterView()
        .environment(AppViewModel())
        .frame(width: 800, height: 500)
}
