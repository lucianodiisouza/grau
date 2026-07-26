//
//  DuplicatesView.swift
//  grau
//
//  Pick a root, scan, list duplicate groups, multi-select files
//  to trash. Safe defaults via DuplicateSelection (keep oldest).
//

import SwiftUI
import graucore

struct DuplicatesView: View {
    @Environment(AppViewModel.self) private var appVM
    @State private var rootPath: URL = FileManager.default.homeDirectoryForCurrentUser
    @State private var scanner = DuplicateScanner()
    @State private var selection = DuplicateSelection()
    @State private var groups: [DuplicateGroup] = []
    @State private var selectedFileIDs: Set<URLHashID> = []
    @State private var phaseLabel: String = "Idle"
    @State private var isScanning = false
    @State private var wasCancelled = false

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
            Text("Duplicates")
                .font(.title2.weight(.semibold))
            Spacer()
            Text(phaseLabel)
                .font(.caption)
                .foregroundStyle(.secondary)
            if isScanning {
                Button {
                    Task { await scanner.cancel() }
                } label: {
                    Label("Stop", systemImage: "stop.circle")
                }
                .buttonStyle(.borderless)
                .tint(.red)
                ProgressView().controlSize(.small)
            } else {
                Button {
                    Task { await scan() }
                } label: {
                    Label("Scan", systemImage: "magnifyingglass")
                }
                .buttonStyle(.borderless)
            }
        }
        .padding(Spacing.lg)
    }

    @ViewBuilder
    private var content: some View {
        VStack(spacing: 0) {
            summaryHeader
            Divider()
            if isScanning {
                ProgressView("Scanning…")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if groups.isEmpty {
                EmptyStateView(
                    icon: "doc.on.doc",
                    title: "No duplicates found",
                    message: "Pick a root and tap Scan. We compare SHA-256, so this is exact-match only."
                )
            } else {
                groupList
            }
        }
    }

    @ViewBuilder
    private var summaryHeader: some View {
        CardView {
            HStack {
                VStack(alignment: .leading, spacing: Spacing.xs) {
                    Text("Root")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(rootPath.path)
                        .font(.callout)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: Spacing.xs) {
                    Text("\(groups.count) groups")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(selection.totalWasted(groups).humanReadable + " recoverable")
                        .font(.headline)
                }
            }
        }
        .padding(.horizontal, Spacing.lg)
        .padding(.vertical, Spacing.sm)
    }

    @ViewBuilder
    private var groupList: some View {
        ScrollView {
            LazyVStack(spacing: Spacing.md) {
                ForEach(groups) { group in
                    groupCard(group)
                }
            }
            .padding(Spacing.lg)
        }
    }

    @ViewBuilder
    private func groupCard(_ group: DuplicateGroup) -> some View {
        CardView {
            VStack(alignment: .leading, spacing: Spacing.sm) {
                HStack {
                    Pill(group.size.humanReadable, tone: .info)
                    Text("\(group.files.count) copies · \(group.wastedBytes.humanReadable) wasted")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                    Spacer()
                }
                ForEach(Array(group.files.enumerated()), id: \.element) { index, file in
                    HStack {
                        Toggle("", isOn: Binding(
                            get: { selectedFileIDs.contains(URLHashID(file)) },
                            set: { isOn in
                                if isOn {
                                    selectedFileIDs.insert(URLHashID(file))
                                } else {
                                    selectedFileIDs.remove(URLHashID(file))
                                }
                            }
                        ))
                        .labelsHidden()
                        Text(file.path)
                            .font(.caption)
                            .lineLimit(1)
                            .truncationMode(.middle)
                            .foregroundStyle(.secondary)
                        Spacer()
                        if index == 0 {
                            Pill("Keep", tone: .success)
                        }
                    }
                }
            }
        }
    }

    private func scan() async {
        isScanning = true
        wasCancelled = false
        phaseLabel = "Sizing…"
        groups = []
        selectedFileIDs = []

        for await event in await scanner.scan(root: rootPath) {
            switch event {
            case .phaseStarted(let p):
                phaseLabel = label(for: p)
            case .phaseProgress(let p, let scanned, let total):
                phaseLabel = "\(label(for: p)) \(scanned)/\(total)"
            case .phaseCompleted(let p):
                phaseLabel = "\(label(for: p)) done"
            case .duplicateFound(let group):
                groups.append(group)
                // Pre-select: keep the oldest, mark the others for removal
                let keep = Set(selection.keepURLs(in: group))
                for url in group.files where !keep.contains(url) {
                    selectedFileIDs.insert(URLHashID(url))
                }
            }
        }
        // Detect cancellation: the stream ended with a partial set
        // of groups AND we don't see .done. The simplest signal is
        // an empty groups list AND the scan didn't reach Full hash.
        if phaseLabel.contains("Partial hash") || phaseLabel.contains("Sizing") {
            wasCancelled = true
            phaseLabel = "Cancelled"
        }
        isScanning = false
    }

    private func label(for phase: DuplicateScanner.Phase) -> String {
        switch phase {
        case .sizing:         "Sizing"
        case .partialHashing: "Partial hash"
        case .fullHashing:    "Full hash"
        case .done:           "Done"
        }
    }
}

/// URL doesn't conform to Hashable in some contexts inside Set
/// because of Foundation bridging. This is a stable hash.
private struct URLHashID: Hashable {
    let url: URL
    init(_ url: URL) { self.url = url }
    func hash(into hasher: inout Hasher) {
        hasher.combine(url.absoluteString)
    }
    static func == (lhs: URLHashID, rhs: URLHashID) -> Bool {
        lhs.url == rhs.url
    }
}

#Preview {
    DuplicatesView()
        .environment(AppViewModel())
        .frame(width: 800, height: 600)
}
