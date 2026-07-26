//
//  PermissionPrimerView.swift
//  grau
//
//  The 3-step FDA primer. See docs/PERMISSIONS.md § 5.
//

import SwiftUI

struct PermissionPrimerView: View {
    @Environment(AppViewModel.self) private var appVM
    let coordinator: PermissionCoordinator
    @State private var step: Int = 0

    var body: some View {
        VStack(spacing: Spacing.xl) {
            Spacer()
            content
            Spacer()
            footer
        }
        .padding(Spacing.xxl)
        .frame(maxWidth: 480)
    }

    @ViewBuilder
    private var content: some View {
        switch step {
        case 0: welcome
        case 1: howTo
        default: done
        }
    }

    @ViewBuilder
    private var welcome: some View {
        VStack(spacing: Spacing.lg) {
            Image(systemName: "lock.shield")
                .font(.system(size: 56))
                .foregroundStyle(Color("grau-accent"))
            Text("Grau needs Full Disk Access")
                .font(.title2)
                .multilineTextAlignment(.center)
            Text("To clean system caches, logs, and Mail data, Grau needs permission to read protected files. macOS calls this \"Full Disk Access.\"")
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
    }

    @ViewBuilder
    private var howTo: some View {
        VStack(spacing: Spacing.lg) {
            Image(systemName: "gear")
                .font(.system(size: 56))
                .foregroundStyle(Color("grau-accent"))
            Text("Open System Settings")
                .font(.title2)
                .multilineTextAlignment(.center)
            VStack(alignment: .leading, spacing: Spacing.md) {
                Label("Click **Open System Settings** below.", systemImage: "1.circle")
                Label("Find Grau in the list.", systemImage: "2.circle")
                Label("Toggle it on and enter your password.", systemImage: "3.circle")
            }
            .padding(.horizontal, Spacing.lg)
        }
    }

    @ViewBuilder
    private var done: some View {
        VStack(spacing: Spacing.lg) {
            Image(systemName: coordinator.state.fullDiskAccess
                  ? "checkmark.circle.fill"
                  : "questionmark.circle")
                .font(.system(size: 56))
                .foregroundStyle(coordinator.state.fullDiskAccess
                                 ? Color("grau-success")
                                 : Color("grau-warning"))
            Text(coordinator.state.fullDiskAccess
                 ? "All set"
                 : "Still waiting?")
                .font(.title2)
                .multilineTextAlignment(.center)
            if !coordinator.state.fullDiskAccess {
                Text("Grau didn't detect the toggle yet. It can take a few seconds after you flip it.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
    }

    @ViewBuilder
    private var footer: some View {
        HStack {
            if step > 0 {
                SecondaryButton("Back") { step -= 1 }
            }
            Spacer()
            if step < 2 {
                PrimaryButton("Continue") { step += 1 }
            } else {
                if coordinator.state.fullDiskAccess {
                    PrimaryButton("Done") { appVM.hasOnboarded = true }
                } else {
                    PrimaryButton("Open System Settings") {
                        coordinator.openSystemSettingsAndPoll()
                    }
                }
            }
        }
    }
}
