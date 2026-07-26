//
//  DiskLensView.swift
//  grau
//
//  Top-N folders list with drill. v1 ships this; the treemap
//  is deferred to v1.1 per docs/REVIEW.md S3.
//

import SwiftUI
import graucore

struct DiskLensView: View {
    @Environment(AppViewModel.self) private var appVM
    @State private var currentPath: URL = URL(fileURLWithPath: "/")
    @State private var nodes: [DiskTreeNode] = []
    @State private var isLoading = false
    @State private var viewMode: ViewMode = .list

    enum ViewMode: String, CaseIterable, Identifiable {
        case list, treemap
        var id: String { rawValue }
        var systemImage: String {
            switch self {
            case .list:    "list.bullet"
            case .treemap: "square.grid.3x3.fill"
            }
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            toolbar
            Divider()
            content
        }
        .task {
            await reload()
        }
    }

    @ViewBuilder
    private var toolbar: some View {
        HStack {
            Text("Disk Lens")
                .font(.title2.weight(.semibold))
            Spacer()
            Picker("View", selection: $viewMode) {
                ForEach(ViewMode.allCases) { mode in
                    Image(systemName: mode.systemImage)
                        .tag(mode)
                        .help(mode == .list ? "List" : "Treemap")
                }
            }
            .pickerStyle(.segmented)
            .frame(maxWidth: 110)
            Button {
                Task {
                    currentPath = URL(fileURLWithPath: "/")
                    await reload()
                }
            } label: {
                Label("Root", systemImage: "rectangle.connected.to.line.below")
            }
            .buttonStyle(.borderless)
            Button {
                Task { await reload(force: true) }
            } label: {
                Label("Refresh", systemImage: "arrow.clockwise")
            }
            .buttonStyle(.borderless)
        }
        .padding(Spacing.lg)
    }

    @ViewBuilder
    private var content: some View {
        VStack(alignment: .leading, spacing: 0) {
            breadcrumb
            Divider()
            if isLoading {
                ProgressView("Scanning…")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if nodes.isEmpty {
                EmptyStateView(
                    icon: "circle.grid.3x3",
                    title: "Empty folder",
                    message: "Nothing to show here. Try a different path."
                )
            } else if viewMode == .treemap {
                DiskTreemapView(
                    nodes: nodes,
                    onSelect: { node in
                        currentPath = node.url
                        Task { await reload() }
                    },
                    onReveal: { node in
                        NSWorkspace.shared.activateFileViewerSelecting([node.url])
                    }
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding(Spacing.md)
            } else {
                nodeList
            }
        }
    }

    @ViewBuilder
    private var breadcrumb: some View {
        HStack(spacing: 4) {
            Text(currentPath.path)
                .font(.callout)
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .truncationMode(.head)
            Spacer()
        }
        .padding(.horizontal, Spacing.lg)
        .padding(.vertical, Spacing.sm)
    }

    @ViewBuilder
    private var nodeList: some View {
        ScrollView {
            LazyVStack(spacing: 4) {
                ForEach(nodes) { node in
                    nodeRow(node)
                }
            }
            .padding(Spacing.md)
        }
    }

    @ViewBuilder
    private func nodeRow(_ node: DiskTreeNode) -> some View {
        HStack(spacing: Spacing.md) {
            Image(systemName: "folder")
                .foregroundStyle(Color("grau-accent"))
            VStack(alignment: .leading, spacing: 0) {
                Text(node.name)
                    .font(.body)
                if let _ = node.size.humanReadable as String? {
                    Text(node.size.humanReadable)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer()
            Button {
                currentPath = node.url
                Task { await reload() }
            } label: {
                Image(systemName: "chevron.right")
                    .foregroundStyle(.tertiary)
            }
            .buttonStyle(.borderless)
            .help("Drill into \(node.name)")
        }
        .padding(.horizontal, Spacing.lg)
        .padding(.vertical, Spacing.sm)
        .contentShape(Rectangle())
        .onTapGesture(count: 2) {
            currentPath = node.url
            Task { await reload() }
        }
        .contextMenu {
            Button("Reveal in Finder") {
                NSWorkspace.shared.activateFileViewerSelecting([node.url])
            }
            Button("Move to Trash") {
                try? FileManager.default.trashItem(at: node.url, resultingItemURL: nil)
                Task { await reload() }
            }
        }
    }

    private func reload(force: Bool = false) async {
        isLoading = true
        // Reading from the shared builder: cache hits are
        // synchronous, so `isLoading` flips false almost immediately
        // when the path was already measured. Cold paths still pay
        // the full I/O cost once, then are free thereafter.
        nodes = await appVM.diskTreeBuilder.topFolders(
            at: currentPath,
            limit: 50,
            force: force
        )
        isLoading = false
    }
}

#Preview {
    DiskLensView()
        .environment(AppViewModel())
        .frame(width: 800, height: 600)
}
