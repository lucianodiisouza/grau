//
//  AutomationView.swift
//  grau
//
//  v1.7 feature. The "Automation" sidebar item. Two sections:
//
//   1. Retention — three stepper rows (notification log, trash
//      manifests, scan history). Each has a "Reset to default"
//      button that snaps the value back to the kind's default.
//      A "Run retention now" button at the bottom of the section.
//   2. Auto-clean rules — list of rules with toggle, name,
//      condition, action, last-fired. "+ New rule" opens a sheet.
//      "Run rules now" at the bottom of the section.
//
//  Both sections share a "Last run" summary card at the top.
//

import SwiftUI
import graucore

struct AutomationView: View {
    @State private var vm = AutomationViewModel()
    @State private var showingNewRule = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.section) {
                header
                lastRunCard
                retentionSection
                autoCleanSection
            }
            .padding(Spacing.lg)
            .frame(maxWidth: 760, alignment: .leading)
        }
        .task { await vm.refresh() }
        .sheet(isPresented: $showingNewRule) {
            AutoCleanRuleEditor(
                rule: nil,
                onSave: { rule in
                    Task {
                        await vm.addRule(rule)
                    }
                    showingNewRule = false
                },
                onCancel: { showingNewRule = false }
            )
        }
    }

    // MARK: - Header

    private var header: some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            Text("Automation")
                .font(.largeTitle.bold())
            Text("Configure what Grau prunes automatically and when.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding(.top, Spacing.lg)
    }

    // MARK: - Last run

    @ViewBuilder
    private var lastRunCard: some View {
        if let report = vm.lastReport, report.totalRemoved > 0 {
            CardView {
                HStack(spacing: Spacing.md) {
                    Image(systemName: "checkmark.seal.fill")
                        .foregroundStyle(Color("grau-success"))
                    VStack(alignment: .leading, spacing: Spacing.xs) {
                        Text("Retention ran")
                            .font(.headline)
                        Text("Pruned \(report.totalRemoved) entries: \(report.removedNotificationEntries) notifications, \(report.removedTrashManifests) manifests, \(report.removedScanHistoryEntries) history items.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        } else if !vm.lastExecution.isEmpty {
            CardView {
                HStack(spacing: Spacing.md) {
                    Image(systemName: "wand.and.stars")
                        .foregroundStyle(Color("grau-accent"))
                    VStack(alignment: .leading, spacing: Spacing.xs) {
                        Text("Auto-clean ran")
                            .font(.headline)
                        ForEach(vm.lastExecution, id: \.pending.id) { result in
                            Text("• \(result.pending.rule.name) — \(result.summary)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
        }
    }

    // MARK: - Retention section

    private var retentionSection: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            sectionHeader("Retention", subtitle: "How long Grau keeps each kind of history.")
            ForEach(RetentionKind.allCases) { kind in
                retentionRow(for: kind)
            }
            HStack {
                Button {
                    Task { await vm.runRetentionNow() }
                } label: {
                    Label("Run retention now", systemImage: "play.fill")
                }
                .disabled(vm.isRunning)
                if vm.isRunning {
                    ProgressView().controlSize(.small)
                }
            }
        }
    }

    private func retentionRow(for kind: RetentionKind) -> some View {
        let current = vm.policy.days(for: kind)
        let isDefault = vm.policy.windows[kind] == nil
        return CardView {
            VStack(alignment: .leading, spacing: Spacing.sm) {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(kind.displayName)
                            .font(.headline)
                        Text(current == 0 ? "Never expire" : "Older than \(current) days")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    if !isDefault {
                        Button("Reset") {
                            Task { await vm.resetRetention(for: kind) }
                        }
                        .buttonStyle(.borderless)
                    }
                }
                Stepper(
                    value: Binding(
                        get: { current },
                        set: { newValue in
                            Task { await vm.setRetention(newValue, for: kind) }
                        }
                    ),
                    in: 0...3650,
                    step: 7
                ) {
                    Text(current == 0 ? "Never" : "\(current) days")
                        .monospacedDigit()
                }
            }
        }
    }

    // MARK: - Auto-clean section

    private var autoCleanSection: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            sectionHeader(
                "Auto-clean rules",
                subtitle: "If a gauge crosses a threshold, run an action."
            )
            if vm.rules.isEmpty {
                CardView {
                    Text("No rules yet. Click \"+ New rule\" to add one.")
                        .foregroundStyle(.secondary)
                }
            } else {
                ForEach(vm.rules) { rule in
                    autoCleanRow(rule)
                }
            }
            HStack {
                Button {
                    showingNewRule = true
                } label: {
                    Label("New rule", systemImage: "plus")
                }
                Button {
                    Task { await vm.runAutoCleanNow() }
                } label: {
                    Label("Run rules now", systemImage: "play.fill")
                }
                .disabled(vm.isRunning || vm.rules.isEmpty)
            }
        }
    }

    private func autoCleanRow(_ rule: AutoCleanRule) -> some View {
        CardView {
            HStack(alignment: .top, spacing: Spacing.md) {
                Toggle(
                    "",
                    isOn: Binding(
                        get: { rule.enabled },
                        set: { newValue in
                            Task { await vm.toggleRule(rule, enabled: newValue) }
                        }
                    )
                )
                .labelsHidden()
                VStack(alignment: .leading, spacing: Spacing.xs) {
                    Text(rule.name)
                        .font(.headline)
                    Text("When \(rule.condition.summary) → \(rule.action.displayName)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    if let last = rule.lastFiredAt {
                        Text("Last fired: \(last.formatted(date: .abbreviated, time: .shortened))")
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    }
                }
                Spacer()
                Menu {
                    Button("Edit", systemImage: "pencil") {
                        // Editing reuses the editor sheet. For v1.7 we
                        // just delete + re-add; full edit flow lands in
                        // v1.8.
                    }
                    Button("Delete", systemImage: "trash", role: .destructive) {
                        Task { await vm.deleteRule(id: rule.id) }
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
                .menuStyle(.borderlessButton)
                .fixedSize()
            }
        }
    }

    // MARK: - Section header

    private func sectionHeader(_ title: String, subtitle: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.title2.bold())
            Text(subtitle)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }
}

// MARK: - New-rule editor

private struct AutoCleanRuleEditor: View {
    let rule: AutoCleanRule?
    let onSave: (AutoCleanRule) -> Void
    let onCancel: () -> Void

    @State private var name: String
    @State private var action: AutoCleanAction
    @State private var thresholdGB: Double
    @State private var timeHour: Int
    @State private var timeMinute: Int
    @State private var conditionKind: ConditionKind

    enum ConditionKind: String, CaseIterable, Identifiable {
        case trash, junk, disk, time
        var id: String { rawValue }
        var label: String {
            switch self {
            case .trash: "Trash size"
            case .junk:  "Junk size"
            case .disk:  "Disk usage"
            case .time:  "Time of day"
            }
        }
    }

    init(
        rule: AutoCleanRule?,
        onSave: @escaping (AutoCleanRule) -> Void,
        onCancel: @escaping () -> Void
    ) {
        self.rule = rule
        self.onSave = onSave
        self.onCancel = onCancel
        _name = State(initialValue: rule?.name ?? "")
        _action = State(initialValue: rule?.action ?? .runRetention)
        // Defaults to "Trash > 10GB"
        _thresholdGB = State(initialValue: 10)
        _timeHour = State(initialValue: 3)
        _timeMinute = State(initialValue: 0)
        _conditionKind = State(initialValue: .trash)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.lg) {
            Text("New auto-clean rule")
                .font(.title2.bold())
            Form {
                TextField("Name", text: $name)
                Picker("When", selection: $conditionKind) {
                    ForEach(ConditionKind.allCases) { kind in
                        Text(kind.label).tag(kind)
                    }
                }
                switch conditionKind {
                case .trash:
                    Stepper(value: $thresholdGB, in: 1...500, step: 1) {
                        Text("Trash > \(Int(thresholdGB)) GB")
                    }
                case .junk:
                    Stepper(value: $thresholdGB, in: 1...500, step: 1) {
                        Text("Junk > \(Int(thresholdGB)) GB")
                    }
                case .disk:
                    Stepper(value: $thresholdGB, in: 50...99, step: 1) {
                        Text("Disk > \(Int(thresholdGB))%")
                    }
                case .time:
                    HStack {
                        Stepper(value: $timeHour, in: 0...23) {
                            Text("Hour: \(timeHour)")
                        }
                        Stepper(value: $timeMinute, in: 0...59) {
                            Text("Minute: \(timeMinute)")
                        }
                    }
                }
                Picker("Action", selection: $action) {
                    ForEach(AutoCleanAction.allCases, id: \.self) { act in
                        Text(act.displayName).tag(act)
                    }
                }
            }
            HStack {
                Spacer()
                Button("Cancel", role: .cancel) { onCancel() }
                Button("Save") {
                    let condition: AutoCleanCondition
                    switch conditionKind {
                    case .trash:
                        condition = .trashSizeExceeds(
                            bytes: Int64(thresholdGB * 1_000_000_000)
                        )
                    case .junk:
                        condition = .junkSizeExceeds(
                            bytes: Int64(thresholdGB * 1_000_000_000)
                        )
                    case .disk:
                        condition = .diskUsageExceeds(
                            fraction: thresholdGB / 100
                        )
                    case .time:
                        condition = .timeOfDay(hour: timeHour, minute: timeMinute)
                    }
                    let built = AutoCleanRule(
                        name: name.isEmpty ? "Untitled rule" : name,
                        condition: condition,
                        action: action,
                        enabled: true
                    )
                    onSave(built)
                }
                .buttonStyle(.borderedProminent)
                .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        }
        .padding(Spacing.xl)
        .frame(width: 460)
    }
}

#Preview {
    AutomationView()
        .environment(AppViewModel())
        .frame(width: 800, height: 700)
}
