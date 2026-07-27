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
    @State private var viewModel: UninstallerViewModel

    @MainActor
    init() {
        // UninstallerViewModel is @MainActor — construct in the
        // struct's init (implicitly @MainActor for a SwiftUI View).
        // See docs/TROUBLESHOOTING.md#strict-concurrency.
        _viewModel = State(wrappedValue: UninstallerViewModel())
    }

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
    @MainActor
    private var toolbar: some View {
        // Use @Bindable to derive a Binding to the view model's
        // properties without copying the whole struct. SwiftUI's
        // TextField needs a `Binding<String>`, not a plain `String`.
        @Bindable var bindableVM = viewModel

        HStack(spacing: Spacing.md) {
            Text("Uninstaller")
                .font(.title2.weight(.semibold))
            Spacer()
            // Search field. Bound directly to the view model so the
            // filter is reactive. We render a custom field instead
            // of `.roundedBorder` so the magnifier icon and clear
            // button can sit inline (Finder-style).
            HStack(spacing: Spacing.xs) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)
                TextField("Search apps", text: $bindableVM.searchText)
                    .textFieldStyle(.plain)
                    .frame(minWidth: 140, idealWidth: 180)
                if !viewModel.searchText.isEmpty {
                    Button {
                        viewModel.searchText = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.borderless)
                }
            }
            .padding(.horizontal, Spacing.sm)
            .padding(.vertical, 4)
            .background(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(Color.secondary.opacity(0.1))
            )
            // Sort picker. A Menu (vs. a Picker) reads more like a
            // dropdown and matches the user's request for a "dropdown".
            Menu {
                ForEach(UninstallerViewModel.SortOrder.allCases) { order in
                    Button {
                        viewModel.sortOrder = order
                    } label: {
                        if viewModel.sortOrder == order {
                            Label(order.displayName, systemImage: "checkmark")
                        } else {
                            Text(order.displayName)
                        }
                    }
                }
            } label: {
                HStack(spacing: Spacing.xs) {
                    Image(systemName: "arrow.up.arrow.down")
                    Text(viewModel.sortOrder.displayName)
                }
            }
            .menuStyle(.borderlessButton)
            .fixedSize()
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
    @MainActor
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
    @MainActor
    private var appList: some View {
        // ScrollView + LazyVStack instead of List. SwiftUI's
        // List (including `.sidebar` style) reserves a leading
        // indent for the system sidebar look — here the list is
        // its own column, so that indent shows up as a ~20pt gap
        // on unselected rows that disappears the moment a row is
        // selected. Building the rows ourselves gives us full
        // control: the icon sits at the same leading edge whether
        // the row is highlighted or not, and the selected
        // highlight extends edge-to-edge so it doesn't "blink" in
        // when the user picks a row.
        let rows = viewModel.visibleApps
        if rows.isEmpty {
            // Distinguish "no apps" (scan is still loading or
            // really nothing's installed) from "no matches" (the
            // current search/sort produced nothing).
            if viewModel.apps.isEmpty {
                EmptyStateView(
                    icon: "shippingbox",
                    title: "No installed apps found",
                    message: "Run a scan to populate the list."
                )
            } else {
                VStack(spacing: Spacing.sm) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 24))
                        .foregroundStyle(.secondary)
                    Text("No apps match \u{201C}\(viewModel.searchText)\u{201D}")
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        } else {
            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(rows) { app in
                        appRow(for: app)
                    }
                }
            }
        }
    }

    @ViewBuilder
    @MainActor
    private func appRow(for app: InstalledApp) -> some View {
        let isSelected = viewModel.selectedApp == app
        HStack(spacing: Spacing.sm) {
            AppIconView(
                image: viewModel.icon(for: app),
                isSystem: app.isAppleSystemComponent
            )
            VStack(alignment: .leading) {
                Text(app.name)
                Text(app.installedVersion)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            // Bundle size column. Renders "—" while the background
            // sizing pass is still running so the row width stays
            // stable as values stream in.
            if let size = viewModel.bundleSize(for: app) {
                Text(size.compactLabel)
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            } else if !viewModel.hasComputedSize(for: app) {
                Text("—")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.tertiary)
                    .lineLimit(1)
            }
        }
        .padding(.horizontal, Spacing.md)
        .padding(.vertical, Spacing.sm)
        .frame(maxWidth: .infinity, alignment: .leading)
        // The selection highlight extends edge-to-edge of the row
        // (no horizontal padding on the background) so the icon
        // sits at the same leading edge whether the row is
        // highlighted or not. Any inset on the highlight would
        // look like the highlight "moved" relative to the icon
        // when the user picks a row — that's the blink the user
        // reported.
        .background {
            if isSelected {
                Color.accentColor.opacity(0.25)
            }
        }
        .contentShape(Rectangle())
        .onTapGesture {
            if isSelected {
                viewModel.selectedApp = nil
                viewModel.residuals = []
                viewModel.selectedResidualIDs = []
            } else {
                let viewModel = viewModel
                Task { await viewModel.selectApp(app) }
            }
        }
    }

    @ViewBuilder
    @MainActor
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
    @MainActor
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
    @MainActor
    private func header(for app: InstalledApp) -> some View {
        CardView {
            HStack(alignment: .top, spacing: Spacing.md) {
                AppIconView(
                    image: viewModel.icon(for: app),
                    isSystem: app.isAppleSystemComponent,
                    size: 56
                )
                VStack(alignment: .leading, spacing: Spacing.xs) {
                    Text(app.name)
                        .font(.headline)
                    HStack(spacing: Spacing.xs) {
                        Text("Version \(app.installedVersion)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        if let size = viewModel.bundleSize(for: app) {
                            Text("·")
                                .font(.caption)
                                .foregroundStyle(.tertiary)
                            Text(size.compactLabel)
                                .font(.caption.monospacedDigit())
                                .foregroundStyle(.secondary)
                        } else if !viewModel.hasComputedSize(for: app) {
                            Text("·")
                                .font(.caption)
                                .foregroundStyle(.tertiary)
                            Text("—")
                                .font(.caption.monospacedDigit())
                                .foregroundStyle(.tertiary)
                        }
                    }
                    Text(app.bundleURL.path)
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                        .lineLimit(1)
                        .truncationMode(.middle)
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
    @MainActor
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
    @MainActor
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
