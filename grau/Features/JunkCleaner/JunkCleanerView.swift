//
//  JunkCleanerView.swift
//  grau
//
//  The Clean tab. See docs/DESIGN.md § 2.3.
//

import SwiftUI
import graucore

struct JunkCleanerView: View {
    @Environment(AppViewModel.self) private var appVM
    @State private var viewModel: JunkCleanerViewModel

    @MainActor
    init() {
        // JunkCleanerViewModel is @MainActor — construct in the
        // struct's init (implicitly @MainActor for a SwiftUI View).
        // See docs/TROUBLESHOOTING.md#strict-concurrency.
        _viewModel = State(wrappedValue: JunkCleanerViewModel())
    }

    var body: some View {
        @Bindable var bindableVM = viewModel

        VStack(spacing: 0) {
            toolbar
            Divider()
            content
        }
        .task {
            // Auto-scan on first appearance.
            if viewModel.results.isEmpty && viewModel.phase == .idle {
                await viewModel.scan()
            }
        }
        .alert("Cleanup failed", isPresented: .constant(viewModel.errorMessage != nil)) {
            Button("OK") { viewModel.errorMessage = nil }
        } message: {
            Text(viewModel.errorMessage ?? "")
        }
    }

    @ViewBuilder
    @MainActor
    private var toolbar: some View {
        HStack {
            Text("Clean")
                .font(.title2.weight(.semibold))
            Spacer()
            if viewModel.phase == .scanning {
                ProgressView().controlSize(.small)
            } else {
                Button {
                    let viewModel = viewModel
                    Task { await viewModel.scan() }
                } label: {
                    Label("Scan", systemImage: "arrow.clockwise")
                }
                .buttonStyle(.borderless)
            }
        }
        .padding(Spacing.lg)
    }

    @ViewBuilder
    @MainActor
    private var content: some View {
        switch viewModel.phase {
        case .idle:
            EmptyStateView(
                icon: "trash",
                title: "Ready to scan",
                message: "We'll check your caches, logs, downloads, and iOS backups."
            )
        case .scanning:
            ProgressView("Scanning…")
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        case .showingResults:
            resultsList
        case .confirming:
            confirmSheet
        case .cleaning:
            ProgressView("Cleaning…")
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        case .completed:
            if let outcome = viewModel.lastOutcome {
                successSheet(outcome)
            } else {
                ProgressView("Cleaning…")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
    }

    @ViewBuilder
    @MainActor
    private var resultsList: some View {
        VStack(spacing: 0) {
            ScrollView {
                LazyVStack(spacing: Spacing.md) {
                    summaryHeader
                    ForEach(viewModel.results, id: \.category) { result in
                        categoryRow(result)
                    }
                }
                .padding(Spacing.lg)
            }
            Divider()
            bottomActionBar
        }
    }

    @ViewBuilder
    @MainActor
    private var summaryHeader: some View {
        CardView {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: Spacing.xs) {
                    Text("Total cleanable")
                        .font(.headline)
                    Text(viewModel.selectedSize.humanReadable)
                        .font(.title2)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Pill(
                    "\(viewModel.selectedCategories.count) of \(viewModel.results.count) selected",
                    tone: .info
                )
            }
        }
    }

    @ViewBuilder
    @MainActor
    private func categoryRow(_ result: JunkResult) -> some View {
        let isSelected = viewModel.selectedCategories.contains(result.category)
        let definition = JunkDefinitions.definition(for: result.category)

        CardView {
            HStack(alignment: .top) {
                Toggle("", isOn: Binding(
                    get: { isSelected },
                    set: { newValue in
                        if newValue {
                            viewModel.selectedCategories.insert(result.category)
                        } else {
                            viewModel.selectedCategories.remove(result.category)
                        }
                    }
                ))
                .labelsHidden()
                .disabled(result.skipped)

                VStack(alignment: .leading, spacing: Spacing.xs) {
                    HStack {
                        Text(result.category.displayName)
                            .font(.headline)
                        if result.skipped {
                            Pill("Permission required", tone: .warning)
                        } else if let def = definition, def.safety == .userCaution {
                            Pill("Opt-in", tone: .warning)
                        } else {
                            Pill("Safe", tone: .success)
                        }
                    }
                    if let def = definition {
                        Text("Includes: \(def.paths.count) path\(def.paths.count == 1 ? "" : "s")")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    }
                    if result.skipped {
                        Text(result.skipReason ?? "Skipped")
                            .font(.caption)
                            .foregroundStyle(Color("grau-warning"))
                    } else {
                        Text(result.size.humanReadable)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
                Spacer()
            }
        }
        .opacity(result.skipped ? 0.6 : 1.0)
    }

    @ViewBuilder
    @MainActor
    private var bottomActionBar: some View {
        HStack {
            Text("\(viewModel.selectedCategories.count) selected")
                .font(.callout)
                .foregroundStyle(.secondary)
            Spacer()
            Text(viewModel.selectedSize.humanReadable + " to free")
                .font(.callout)
                .foregroundStyle(.secondary)
            PrimaryButton(
                "Clean Selected",
                systemImage: "trash",
                isEnabled: !viewModel.selectedCategories.isEmpty
                    && viewModel.selectedSize.bytes > 0
            ) {
                viewModel.startClean()
            }
            .frame(width: 180)
        }
        .padding(Spacing.lg)
    }

    @ViewBuilder
    @MainActor
    private var confirmSheet: some View {
        VStack(spacing: Spacing.lg) {
            Spacer()
            Image(systemName: "trash.circle")
                .font(.system(size: 48))
                .foregroundStyle(Color("grau-warning"))
            Text("Move to Trash?")
                .font(.title2)
            Text("\(viewModel.selectedCategories.count) categories, \(viewModel.selectedSize.humanReadable)")
                .foregroundStyle(.secondary)
            if viewModel.hasUserCautionSelection {
                Text("One or more selected categories contain user data (downloads, iOS backups). Deletion is permanent once the Trash is emptied.")
                    .font(.callout)
                    .foregroundStyle(Color("grau-warning"))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, Spacing.xxl)
            } else {
                Text("These items can be recovered from the Trash until you empty it.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, Spacing.xxl)
            }
            Spacer()
            HStack {
                SecondaryButton("Cancel") {
                    viewModel.cancelClean()
                }
                PrimaryButton(
                    "Move to Trash",
                    systemImage: "trash",
                    isEnabled: !viewModel.selectedCategories.isEmpty
                ) {
                    let viewModel = viewModel
                    Task { await viewModel.confirmClean() }
                }
            }
        }
        .padding(Spacing.xxl)
    }

    @ViewBuilder
    @MainActor
    private func successSheet(_ outcome: JunkCleaner.CleanupOutcome) -> some View {
        VStack(spacing: Spacing.lg) {
            Spacer()
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 56))
                .foregroundStyle(Color("grau-success"))
            Text("Freed \(ByteSize(bytes: outcome.freedBytes).humanReadable)")
                .font(.title2)
            Text("\(outcome.movedCount) items moved to Trash")
                .foregroundStyle(.secondary)
            Spacer()
            HStack {
                SecondaryButton("Open Trash", systemImage: "folder") {
                    NSWorkspace.shared.activateFileViewerSelecting(
                        [URL(fileURLWithPath: NSHomeDirectory() + "/.Trash")]
                    )
                }
                PrimaryButton("Done") {
                    viewModel.dismissCompleted()
                }
            }
        }
        .padding(Spacing.xxl)
    }
}

extension JunkCleaner.CleanupOutcome {
    /// Convenience accessors (already on the struct; this is just
    /// documenting the cross-module shape).
    var freedBytes: Int64 { manifest.totalSize }
    var movedCount: Int { manifest.items.count }
}

#Preview {
    JunkCleanerView()
        .environment(AppViewModel())
        .frame(width: 800, height: 600)
}
