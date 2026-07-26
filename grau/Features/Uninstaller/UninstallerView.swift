//
//  UninstallerView.swift
//  grau
//
//  Two-column: app list (left) + residual detail (right).
//  See docs/DESIGN.md § 2.3.
//

import SwiftUI
import graucore

struct UninstallerView: View {
    @Environment(AppViewModel.self) private var appVM
    @State private var viewModel = UninstallerViewModel()

    var body: some View {
        VStack(spacing: 0) {
            toolbar
            Divider()
            content
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .task {
            if viewModel.phase == .idle {
                await viewModel.scan()
            }
        }
        .alert("Uninstall failed", isPresented: .constant(viewModel.errorMessage != nil)) {
            Button("OK") { viewModel.errorMessage = nil }
        } message: {
            Text(viewModel.errorMessage ?? "")
        }
    }

    @ViewBuilder
    private var toolbar: some View {
        HStack {
            Text("Uninstaller")
                .font(.title2.weight(.semibold))
            Spacer()
            if viewModel.phase == .scanning {
                ProgressView().controlSize(.small)
            } else {
                Button {
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
    private var content: some View {
        switch viewModel.phase {
        case .idle, .scanning:
            ProgressView("Scanning…")
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        case .loaded, .confirming, .uninstalling:
            twoColumn
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
    private var twoColumn: some View {
        // NOTE: do NOT use HSplitView here. The host is a
        // NavigationSplitView (MainWindowView), and nesting an
        // AppKit HSplitView inside it makes both split views
        // fight for the window's resize axis — every sidebar
        // click shifts the whole window sideways. An HStack with
        // a divider gives us a fixed two-column layout that
        // cooperates with the parent NavigationSplitView.
        HStack(spacing: 0) {
            appList
                .frame(minWidth: 240, idealWidth: 280, maxWidth: 360)
            Divider()
            detailPane
                .frame(minWidth: 360)
        }
    }

    @ViewBuilder
    private var appList: some View {
        VStack(spacing: 0) {
            List(viewModel.apps, selection: Binding(
                get: { viewModel.selectedApp },
                set: { newValue in
                    if let app = newValue {
                        Task { await viewModel.selectApp(app) }
                    } else {
                        viewModel.selectedApp = nil
                        viewModel.residuals = []
                        viewModel.selectedResidualIDs = []
                    }
                }
            )) { app in
                HStack {
                    Image(systemName: app.isAppleSystemComponent ? "lock.shield" : "app")
                        .foregroundStyle(.secondary)
                    VStack(alignment: .leading) {
                        Text(app.name)
                        Text(app.installedVersion)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .tag(app)
            }
        }
    }

    @ViewBuilder
    private var detailPane: some View {
        Group {
            if let app = viewModel.selectedApp {
                detail(for: app)
            } else {
                ContentUnavailableView(
                    "Select an app",
                    systemImage: "shippingbox",
                    description: Text("Pick an app on the left to see its residual data.")
                )
            }
        }
    }

    @ViewBuilder
    private func detail(for app: InstalledApp) -> some View {
        VStack(alignment: .leading, spacing: Spacing.lg) {
            header(for: app)
            if viewModel.phase == .confirming {
                confirmSheet
            } else if viewModel.phase == .uninstalling {
                ProgressView("Uninstalling…")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                residualsList
            }
        }
        .padding(Spacing.lg)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    @ViewBuilder
    private func header(for app: InstalledApp) -> some View {
        CardView {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: Spacing.xs) {
                    Text(app.name)
                        .font(.headline)
                    Text("Version \(app.installedVersion)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(app.bundleURL.path)
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
                Spacer()
                if app.isAppleSystemComponent {
                    Pill("System", tone: .danger)
                } else if app.hasUninstallHelper {
                    Pill("Has uninstaller", tone: .info)
                }
            }
        }
    }

    @ViewBuilder
    private var residualsList: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            HStack {
                Text("Residual data")
                    .font(.headline)
                Spacer()
                Pill("\(viewModel.selectedResidualIDs.count) selected", tone: .info)
            }
            if viewModel.residuals.isEmpty {
                Text("No residual data found in the standard Library paths.")
                    .foregroundStyle(.secondary)
            } else {
                ScrollView {
                    VStack(spacing: Spacing.sm) {
                        ForEach(viewModel.residuals) { residual in
                            residualRow(residual)
                        }
                    }
                }
            }
            HStack {
                Spacer()
                Text(viewModel.totalSelectedSize.humanReadable + " to free")
                    .foregroundStyle(.secondary)
                PrimaryButton(
                    "Uninstall",
                    systemImage: "trash",
                    isEnabled: appVM.devModeEnabled
                        || !(viewModel.selectedApp?.isAppleSystemComponent ?? true)
                ) {
                    viewModel.startUninstall()
                }
                .frame(width: 140)
            }
        }
    }

    @ViewBuilder
    private func residualRow(_ residual: Residual) -> some View {
        let isSelected = viewModel.selectedResidualIDs.contains(residual.id)
        CardView {
            HStack(alignment: .top) {
                Toggle("", isOn: Binding(
                    get: { isSelected },
                    set: { newValue in
                        if newValue {
                            viewModel.selectedResidualIDs.insert(residual.id)
                        } else {
                            viewModel.selectedResidualIDs.remove(residual.id)
                        }
                    }
                ))
                .labelsHidden()

                VStack(alignment: .leading, spacing: Spacing.xs) {
                    HStack {
                        Text(residual.kind.displayName)
                            .font(.headline)
                        if residual.kind.mayContainUserData {
                            Pill("May contain user data", tone: .warning)
                        }
                    }
                    Text(residual.path.path)
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                    Text(residual.size.humanReadable)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
            }
        }
    }

    @ViewBuilder
    @MainActor
    private var confirmSheet: some View {
        VStack(spacing: Spacing.lg) {
            Spacer()
            Image(systemName: "trash.circle")
                .font(.system(size: 48))
                .foregroundStyle(Color("grau-danger"))
            Text("Uninstall?")
                .font(.title2)
            if let app = viewModel.selectedApp {
                Text("Move \(app.name) and \(viewModel.selectedResidualIDs.count) residuals to Trash.")
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.secondary)
            }
            Text("Original path: \(viewModel.selectedApp?.bundleURL.path ?? "")")
                .font(.caption)
                .foregroundStyle(.tertiary)
                .lineLimit(1)
                .truncationMode(.middle)
            Spacer()
            HStack {
                SecondaryButton("Cancel") { viewModel.cancelUninstall() }
                DestructiveButton("Uninstall", systemImage: "trash") {
                    // Capture `viewModel` explicitly (not `self`).
                    // The View struct is non-Sendable; capturing the
                    // @MainActor viewModel directly avoids the
                    // "non-sendable capture in @Sendable closure"
                    // error under StrictConcurrency.
                    let vm = viewModel
                    Task { await vm.confirmUninstall() }
                }
            }
        }
        .padding(Spacing.xxl)
    }

    @ViewBuilder
    @MainActor
    private func successSheet(_ outcome: Uninstaller.ExecuteOutcome) -> some View {
        VStack(spacing: Spacing.lg) {
            Spacer()
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 56))
                .foregroundStyle(Color("grau-success"))
            Text("Uninstalled \(outcome.app.name)")
                .font(.title2)
            Text("\(outcome.movedCount) items moved to Trash · \(ByteSize(bytes: outcome.freedBytes).humanReadable) freed")
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
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
