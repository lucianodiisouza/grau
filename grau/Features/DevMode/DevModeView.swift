//
//  DevModeView.swift
//  grau
//
//  The Dev Mode feature. Tabbed UI over the six inspectors:
//  Package caches / node_modules / Docker / Simulators /
//  DerivedData / Archives. Hidden unless `devModeEnabled` is on.
//
//  Dev mode is OFF by default and gated behind a Settings toggle.
//  See docs/PLAN.md § 5 and docs/DESIGN.md.
//

import SwiftUI
import graucore

struct DevModeView: View {
    @State private var viewModel = DevModeViewModel()

    var body: some View {
        VStack(spacing: 0) {
            toolbar
            Divider()
            content
        }
    }

    // MARK: - Toolbar

    @ViewBuilder
    private var toolbar: some View {
        HStack {
            Text("Dev Mode")
                .font(.title2.weight(.semibold))
            Spacer()
            if viewModel.isScanning {
                ProgressView().controlSize(.small)
            } else {
                Button {
                    Task { await viewModel.refresh() }
                } label: {
                    Label("Refresh", systemImage: "arrow.clockwise")
                }
                .buttonStyle(.borderless)
            }
        }
        .padding(Spacing.lg)
    }

    // MARK: - Content

    @ViewBuilder
    private var content: some View {
        if viewModel.isScanning && viewModel.report == nil {
            ProgressView("Scanning…")
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if let report = viewModel.report {
            TabView {
                PackageCachesTab(report: report)
                    .tabItem { Label("Packages", systemImage: "shippingbox") }
                NodeModulesTab(report: report)
                    .tabItem { Label("node_modules", systemImage: "puzzlepiece") }
                DockerTab(report: report)
                    .tabItem { Label("Docker", systemImage: "cube.transparent") }
                SimulatorsTab(report: report)
                    .tabItem { Label("Simulators", systemImage: "iphone") }
                DerivedDataTab(report: report)
                    .tabItem { Label("Derived Data", systemImage: "hammer") }
                ArchivesTab(report: report)
                    .tabItem { Label("Archives", systemImage: "archivebox") }
            }
            .padding(Spacing.sm)
        } else if let error = viewModel.errorMessage {
            ErrorStateView(
                title: "Dev scan failed",
                message: error,
                action: {
                    PrimaryButton("Retry") { Task { await viewModel.refresh() } }
                }
            )
        } else {
            EmptyStateView(
                icon: "hammer",
                title: "Dev Mode",
                message: "Scan package caches, node_modules, Docker, simulators, DerivedData, and Xcode archives.",
                action: {
                    PrimaryButton("Scan") {
                        Task { await viewModel.refresh() }
                    }
                }
            )
        }
    }
}

// MARK: - Tab 1: Package caches

private struct PackageCachesTab: View {
    let report: DevReport

    var body: some View {
        let present = report.packageCaches.filter { $0.exists }
        if present.isEmpty {
            EmptyStateView(
                icon: "shippingbox",
                title: "No package caches found",
                message: "Install npm, Yarn, Cargo, or any of the 16 package managers Grau tracks."
            )
        } else {
            ScrollView {
                LazyVStack(spacing: Spacing.md) {
                    ForEach(present) { info in
                        CardView {
                            HStack {
                                VStack(alignment: .leading, spacing: Spacing.xs) {
                                    Text(info.kind.displayName)
                                        .font(.headline)
                                    Text(info.paths.map { $0.path }.joined(separator: "\n"))
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                        .lineLimit(2)
                                }
                                Spacer()
                                Pill(info.size.humanReadable, tone: .info)
                            }
                        }
                    }
                }
                .padding(Spacing.lg)
            }
        }
    }
}

// MARK: - Tab 2: node_modules

private struct NodeModulesTab: View {
    let report: DevReport

    var body: some View {
        if report.nodeModules.isEmpty {
            EmptyStateView(
                icon: "puzzlepiece",
                title: "No node_modules found",
                message: "Grau walked your home and the usual project roots (Code, Developer, Projects, repos, src, work)."
            )
        } else {
            ScrollView {
                LazyVStack(spacing: Spacing.md) {
                    HStack {
                        Text("\(report.nodeModules.count) project(s)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Spacer()
                        Text(report.nodeModules.reduce(ByteSize.zero) { $0 + $1.size }.humanReadable + " total")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.horizontal, Spacing.lg)
                    ForEach(report.nodeModules) { info in
                        CardView {
                            HStack {
                                VStack(alignment: .leading, spacing: Spacing.xs) {
                                    Text(info.projectRoot.lastPathComponent)
                                        .font(.headline)
                                    Text(info.projectRoot.path)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                        .lineLimit(1)
                                        .truncationMode(.middle)
                                }
                                Spacer()
                                Pill(info.size.humanReadable, tone: .info)
                            }
                        }
                    }
                }
                .padding(Spacing.lg)
            }
        }
    }
}

// MARK: - Tab 3: Docker

private struct DockerTab: View {
    let report: DevReport

    var body: some View {
        let info = report.docker
        VStack(spacing: Spacing.lg) {
            if !info.dockerInstalled {
                EmptyStateView(
                    icon: "cube.transparent",
                    title: "Docker not installed",
                    message: "Install Docker Desktop to see build-cache and reclaimable disk usage here."
                )
            } else if info.stoppedContainers == 0
                        && info.danglingImages == 0
                        && info.unusedVolumes == 0
                        && info.buildCacheSize == .zero
                        && info.reclaimable == .zero {
                // Likely daemon-down (we report zeros in that case)
                EmptyStateView(
                    icon: "cube.transparent",
                    title: "Docker daemon not running",
                    message: "Start Docker Desktop and tap Refresh to see disk usage."
                )
            } else {
                CardView {
                    VStack(alignment: .leading, spacing: Spacing.md) {
                        Text("Build cache")
                            .font(.headline)
                        HStack {
                            Text("Size")
                            Spacer()
                            Pill(info.buildCacheSize.humanReadable, tone: .info)
                        }
                        HStack {
                            Text("Reclaimable")
                            Spacer()
                            Pill(info.reclaimable.humanReadable, tone: .success)
                        }
                    }
                }
                .padding(.horizontal, Spacing.lg)
                Spacer()
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(Spacing.lg)
    }
}

// MARK: - Tab 4: Simulators

private struct SimulatorsTab: View {
    let report: DevReport

    var body: some View {
        if report.simulators.isEmpty {
            EmptyStateView(
                icon: "iphone",
                title: "No simulators found",
                message: "Open Xcode and download a simulator runtime to see entries here."
            )
        } else {
            ScrollView {
                LazyVStack(spacing: Spacing.md) {
                    ForEach(report.simulators) { sim in
                        CardView {
                            HStack {
                                VStack(alignment: .leading, spacing: Spacing.xs) {
                                    Text(sim.name)
                                        .font(.headline)
                                    Text(sim.runtime)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                        .lineLimit(1)
                                }
                                Spacer()
                                if sim.isBooted {
                                    Pill("Booted", tone: .warning)
                                }
                                Pill(sim.size.humanReadable, tone: .info)
                            }
                        }
                    }
                }
                .padding(Spacing.lg)
            }
        }
    }
}

// MARK: - Tab 5: DerivedData

private struct DerivedDataTab: View {
    let report: DevReport

    var body: some View {
        if report.derivedData.isEmpty {
            EmptyStateView(
                icon: "hammer",
                title: "No DerivedData found",
                message: "Build a project in Xcode to populate ~/Library/Developer/Xcode/DerivedData."
            )
        } else {
            ScrollView {
                LazyVStack(spacing: Spacing.md) {
                    ForEach(report.derivedData) { info in
                        CardView {
                            HStack {
                                VStack(alignment: .leading, spacing: Spacing.xs) {
                                    Text(info.projectName)
                                        .font(.headline)
                                    Text(info.folderName)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                        .lineLimit(1)
                                        .truncationMode(.middle)
                                }
                                Spacer()
                                Pill(info.size.humanReadable, tone: .info)
                            }
                        }
                    }
                }
                .padding(Spacing.lg)
            }
        }
    }
}

// MARK: - Tab 6: Archives

private struct ArchivesTab: View {
    let report: DevReport

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(Color("grau-warning"))
                Text("Archives are required for shipping. Only delete ones you have already uploaded to App Store Connect / TestFlight.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
            }
            .padding(Spacing.lg)
            Divider()
            if report.archives.isEmpty {
                EmptyStateView(
                    icon: "archivebox",
                    title: "No archives found",
                    message: "Archive a build in Xcode (Product > Archive) to see entries here."
                )
            } else {
                ScrollView {
                    LazyVStack(spacing: Spacing.md) {
                        ForEach(report.archives) { info in
                            CardView {
                                HStack {
                                    VStack(alignment: .leading, spacing: Spacing.xs) {
                                        Text(info.name)
                                            .font(.callout)
                                            .lineLimit(1)
                                            .truncationMode(.middle)
                                        if let date = info.date {
                                            Text(date.formatted(date: .abbreviated, time: .omitted))
                                                .font(.caption)
                                                .foregroundStyle(.secondary)
                                        }
                                    }
                                    Spacer()
                                    Pill(info.size.humanReadable, tone: .info)
                                }
                            }
                        }
                    }
                    .padding(Spacing.lg)
                }
            }
        }
    }
}

#Preview {
    DevModeView()
        .environment(AppViewModel())
        .frame(width: 900, height: 600)
}
