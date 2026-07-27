//
//  DashboardView.swift
//  grau
//
//  Home screen. Vertical stack of cards. Reads from
//  DashboardViewModel (storage via VolumeMonitor, trash via
//  TrashInfoReader, last scan via ~/.grau/state.json).
//  See docs/DESIGN.md § 2.2.
//

import SwiftUI
import graucore

struct DashboardView: View {
    @Environment(AppViewModel.self) private var appVM
    @State private var viewModel: DashboardViewModel

    @MainActor
    init() {
        // DashboardViewModel is @MainActor — construct in the
        // struct's init (implicitly @MainActor for a SwiftUI View).
        // See docs/TROUBLESHOOTING.md#strict-concurrency.
        _viewModel = State(wrappedValue: DashboardViewModel())
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.xl) {
                greeting
                storageCard
                HStack(alignment: .top, spacing: Spacing.xl) {
                    trashCard
                        .frame(maxWidth: .infinity)
                    lastScanCard
                        .frame(maxWidth: .infinity)
                }
                quickActions
                if !viewModel.scanHistory.isEmpty {
                    recentScansCard
                }
            }
            .padding(Spacing.xxl)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .task {
            await viewModel.refresh()
        }
        .refreshable {
            await viewModel.refresh()
        }
    }

    // MARK: - Sections

    private var greeting: some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            Text("Good \(timeOfDay)")
                .font(.system(size: 28, weight: .semibold))
            Text("Grau")
                .font(.title2)
                .foregroundStyle(.secondary)
        }
    }

    @ViewBuilder
    @MainActor
    private var storageCard: some View {
        CardView {
            VStack(alignment: .leading, spacing: Spacing.md) {
                HStack {
                    Text("Storage")
                        .font(.headline)
                    Spacer()
                    if viewModel.storageTotal.bytes > 0 {
                        Pill(
                            "\(Int(viewModel.storageFraction * 100))% used",
                            tone: viewModel.storageFraction >= 0.9 ? .danger : .info
                        )
                    }
                }
                if viewModel.storageTotal.bytes > 0 {
                    StorageBar(
                        used: viewModel.storageUsed.bytes,
                        total: viewModel.storageTotal.bytes
                    )
                    HStack {
                        Text(viewModel.storageFree.humanReadable + " free")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        Spacer()
                        Text("\(viewModel.storageUsed.humanReadable) of \(viewModel.storageTotal.humanReadable)")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                } else {
                    ProgressView()
                        .frame(maxWidth: .infinity)
                }
            }
        }
    }

    @ViewBuilder
    @MainActor
    private var trashCard: some View {
        CardView {
            VStack(alignment: .leading, spacing: Spacing.sm) {
                Text("Trash")
                    .font(.headline)
                Text(trashItemCountText)
                    .font(.title2)
                Text(viewModel.trashSize.humanReadable)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Spacer().frame(height: Spacing.sm)
                SecondaryButton("Open in Finder", systemImage: "folder") {
                    NSWorkspace.shared.activateFileViewerSelecting(
                        [URL(fileURLWithPath: NSHomeDirectory() + "/.Trash")]
                    )
                }
            }
        }
    }

    @MainActor
    private var trashItemCountText: String {
        let n = viewModel.trashItemCount
        return n == 1 ? "1 item" : "\(n) items"
    }

    @ViewBuilder
    @MainActor
    private var lastScanCard: some View {
        CardView {
            VStack(alignment: .leading, spacing: Spacing.sm) {
                Text("Last junk scan")
                    .font(.headline)
                if let last = viewModel.lastJunkScan {
                    Text(last.totalBytes > 0
                         ? ByteSize(bytes: last.totalBytes).humanReadable
                         : "0 B")
                        .font(.title2)
                    Text("\(last.itemCount) item(s) · \(last.finishedAt.formatted(date: .abbreviated, time: .shortened))")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    Text("Never")
                        .font(.title2)
                    Text("Run a scan from the Clean tab")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
                Spacer().frame(height: Spacing.sm)
                PrimaryButton("Scan now", systemImage: "magnifyingglass") {
                    appVM.selectedSection = .clean
                }
            }
        }
    }

    @ViewBuilder
    @MainActor
    private var quickActions: some View {
        CardView {
            VStack(alignment: .leading, spacing: Spacing.md) {
                Text("Quick actions")
                    .font(.headline)
                HStack(spacing: Spacing.md) {
                    quickActionButton(
                        "Scan Junk",
                        systemImage: "trash",
                        disabled: false,
                        action: { appVM.selectedSection = .clean }
                    )
                    quickActionButton(
                        "Find Duplicates",
                        systemImage: "doc.on.doc",
                        disabled: false,
                        action: { appVM.selectedSection = .duplicates }
                    )
                    quickActionButton(
                        "View Disk",
                        systemImage: "circle.grid.3x3",
                        disabled: false,
                        action: { appVM.selectedSection = .diskLens }
                    )
                    quickActionButton(
                        "Open Dev Mode",
                        systemImage: "hammer",
                        disabled: !appVM.devModeEnabled,
                        action: { appVM.selectedSection = .devMode }
                    )
                }
            }
        }
    }

    @ViewBuilder
    @MainActor
    private func quickActionButton(
        _ title: String,
        systemImage: String,
        disabled: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button {
            action()
        } label: {
            VStack(spacing: Spacing.xs) {
                Image(systemName: systemImage)
                    .font(.system(size: 22))
                Text(title)
                    .font(.caption)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, Spacing.md)
        }
        .buttonStyle(.plain)
        .disabled(disabled)
        .opacity(disabled ? 0.4 : 1.0)
    }

    @ViewBuilder
    @MainActor
    private var recentScansCard: some View {
        CardView {
            VStack(alignment: .leading, spacing: Spacing.sm) {
                HStack {
                    Text("Recent scans")
                        .font(.headline)
                    Spacer()
                    Text("Last \(viewModel.scanHistory.count) of \(StateFile.maxHistoryEntries) max")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
                ForEach(Array(viewModel.scanHistory.prefix(5).enumerated()), id: \.offset) { _, summary in
                    HStack {
                        Pill(humanLabel(for: summary.kind), tone: .info)
                        Text(ByteSize(bytes: summary.totalBytes).humanReadable)
                            .font(.callout)
                        Text("·")
                            .foregroundStyle(.tertiary)
                        Text("\(summary.itemCount) items")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Spacer()
                        Text(summary.finishedAt.formatted(date: .abbreviated, time: .shortened))
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    }
                    .padding(.vertical, 2)
                }
            }
        }
    }

    private func humanLabel(for kind: String) -> String {
        switch kind {
        case "junk":         "Junk"
        case "uninstall":    "Uninstall"
        case "duplicates":   "Duplicates"
        case "dev":          "Dev mode"
        default:             kind.capitalized
        }
    }

    private var timeOfDay: String {
        let hour = Calendar.current.component(.hour, from: .now)
        switch hour {
        case 5..<12:  return "morning"
        case 12..<18: return "afternoon"
        default:     return "evening"
        }
    }
}

#Preview {
    DashboardView()
        .environment(AppViewModel())
        .frame(width: 800, height: 600)
}
