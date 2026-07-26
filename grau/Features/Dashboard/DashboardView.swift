//
//  DashboardView.swift
//  grau
//
//  Home screen. Vertical stack of cards. See docs/DESIGN.md § 2.2.
//  Real data wiring lands in Phase 1 (Task 1.7) when the storage
//  card reads from VolumeMonitor and the last-scan card reads
//  ~/.grau/state.json.
//

import SwiftUI

struct DashboardView: View {
    @Environment(AppViewModel.self) private var appVM

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
            }
            .padding(Spacing.xxl)
            .frame(maxWidth: .infinity, alignment: .leading)
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

    private var storageCard: some View {
        CardView {
            VStack(alignment: .leading, spacing: Spacing.md) {
                HStack {
                    Text("Storage")
                        .font(.headline)
                    Spacer()
                    Pill("Scaffold data", tone: .neutral)
                }
                StorageBar(used: fakeUsed, total: fakeTotal)
                HStack {
                    Text(fakeFreeText + " free")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text(fakeUsedText + " of " + fakeTotalText)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private var trashCard: some View {
        CardView {
            VStack(alignment: .leading, spacing: Spacing.sm) {
                Text("Trash")
                    .font(.headline)
                Text("8 items")
                    .font(.title2)
                Text("142 MB")
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

    private var lastScanCard: some View {
        CardView {
            VStack(alignment: .leading, spacing: Spacing.sm) {
                Text("Last junk scan")
                    .font(.headline)
                Text("Never")
                    .font(.title2)
                Text("Phase 1 will wire this to ~/.grau/state.json")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                Spacer().frame(height: Spacing.sm)
                PrimaryButton("Scan now", systemImage: "magnifyingglass") {
                    // Wired in Phase 1 Task 1.7
                }
            }
        }
    }

    private var quickActions: some View {
        CardView {
            VStack(alignment: .leading, spacing: Spacing.md) {
                Text("Quick actions")
                    .font(.headline)
                HStack(spacing: Spacing.md) {
                    quickActionButton("Scan Junk", systemImage: "trash", disabled: false)
                    quickActionButton("Find Duplicates", systemImage: "doc.on.doc", disabled: true)
                    quickActionButton("View Disk", systemImage: "circle.grid.3x3", disabled: true)
                    quickActionButton("Open Dev Mode", systemImage: "hammer", disabled: true)
                }
            }
        }
    }

    @ViewBuilder
    private func quickActionButton(
        _ title: String,
        systemImage: String,
        disabled: Bool
    ) -> some View {
        Button {
            // Wired in the relevant phase
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

    // MARK: - Fake data (replaced in Phase 1)

    private let fakeUsed: Int64 = 237_400_000_000
    private let fakeTotal: Int64 = 500_100_000_000
    private var fakeFreeText: String {
        ByteCountFormatter.string(fromByteCount: fakeTotal - fakeUsed, countStyle: .file)
    }
    private var fakeUsedText: String {
        ByteCountFormatter.string(fromByteCount: fakeUsed, countStyle: .file)
    }
    private var fakeTotalText: String {
        ByteCountFormatter.string(fromByteCount: fakeTotal, countStyle: .file)
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
