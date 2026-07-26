//
//  TrashView.swift
//  grau
//
//  Lists past clean/uninstall/duplicates operations by reading
//  the JSON manifests in ~/.grau/trash-manifests/. The user can
//  restore a whole batch (each item goes back to its
//  `originalPath` if it isn't already occupied).
//
//  v1.1 feature. See docs/REVIEW.md S2.
//

import SwiftUI
import graucore

struct TrashView: View {
    @State private var viewModel = TrashViewModel()

    var body: some View {
        VStack(spacing: 0) {
            toolbar
            Divider()
            content
        }
    }

    @ViewBuilder
    private var toolbar: some View {
        HStack {
            Text("Trash")
                .font(.title2.weight(.semibold))
            Spacer()
            Text("Grau moves to your macOS Trash and keeps a manifest here for one-click restore.")
                .font(.caption)
                .foregroundStyle(.secondary)
            Spacer()
            Button {
                Task { await viewModel.refresh() }
            } label: {
                Label("Refresh", systemImage: "arrow.clockwise")
            }
            .buttonStyle(.borderless)
        }
        .padding(Spacing.lg)
    }

    @ViewBuilder
    private var content: some View {
        if viewModel.isLoading {
            ProgressView("Loading…")
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if viewModel.manifests.isEmpty {
            EmptyStateView(
                icon: "arrow.uturn.backward.circle",
                title: "No trashed items yet",
                message: "Run a clean, uninstall, or duplicate-trash to see entries here."
            )
        } else {
            ScrollView {
                LazyVStack(spacing: Spacing.md) {
                    ForEach(viewModel.manifests) { summary in
                        manifestCard(summary)
                    }
                }
                .padding(Spacing.lg)
            }
        }
    }

    @ViewBuilder
    private func manifestCard(_ summary: TrashManifestSummary) -> some View {
        CardView {
            VStack(alignment: .leading, spacing: Spacing.sm) {
                HStack {
                    Pill(kindLabel(summary.kind), tone: .info)
                    Text(summary.timestamp.formatted(date: .abbreviated, time: .shortened))
                        .font(.callout)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text(ByteSize(bytes: summary.totalSize).humanReadable)
                        .font(.headline)
                }
                Text("\(summary.itemCount) item(s)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                if viewModel.restoringID == summary.id {
                    ProgressView("Restoring…")
                } else if let outcome = viewModel.lastOutcomes[summary.id] {
                    outcomeRow(outcome)
                } else {
                    HStack {
                        Spacer()
                        Button {
                            Task { await viewModel.restore(manifestID: summary.id) }
                        } label: {
                            Label("Restore all", systemImage: "arrow.uturn.backward")
                        }
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func outcomeRow(_ outcome: TrashRestoreOutcome) -> some View {
        if outcome.failed.isEmpty {
            HStack {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.green)
                Text("Restored \(outcome.restored) item(s)")
                    .font(.callout)
                Spacer()
            }
        } else {
            VStack(alignment: .leading, spacing: Spacing.xs) {
                HStack {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(.orange)
                    Text("Restored \(outcome.restored), \(outcome.failed.count) failed")
                        .font(.callout)
                    Spacer()
                }
                ForEach(Array(outcome.failed.prefix(3).enumerated()), id: \.offset) { _, failure in
                    Text(failure.originalPath)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
            }
        }
    }

    private func kindLabel(_ kind: String) -> String {
        switch kind {
        case "junk":         "Junk"
        case "uninstall":    "Uninstall"
        case "duplicates":   "Duplicates"
        case "dev":          "Dev mode"
        default:             kind.capitalized
        }
    }
}

#Preview {
    TrashView()
        .environment(AppViewModel())
        .frame(width: 800, height: 500)
}
