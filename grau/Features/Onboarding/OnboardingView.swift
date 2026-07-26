//
//  OnboardingView.swift
//  grau
//
//  First-launch 3-screen tour. Shown only when hasOnboarded is
//  false. The first screen mentions the FDA primer; the actual
//  FDA grant happens in the primer view (which is shown after
//  the user clicks through the welcome).
//

import SwiftUI

struct OnboardingView: View {
    @Environment(AppViewModel.self) private var appVM
    @State private var step: Int = 0

    var body: some View {
        VStack(spacing: Spacing.xl) {
            Spacer()
            content
            Spacer()
            footer
        }
        .padding(Spacing.xxl)
        .frame(maxWidth: 560)
    }

    @ViewBuilder
    private var content: some View {
        switch step {
        case 0: welcome
        case 1: principle
        default: ready
        }
    }

    @ViewBuilder
    private var welcome: some View {
        VStack(spacing: Spacing.lg) {
            Image(systemName: "trash.circle")
                .font(.system(size: 56))
                .foregroundStyle(Color("grau-accent"))
            Text("Welcome to Grau")
                .font(.largeTitle)
            Text("A native macOS utility for cleaning, inspecting, and managing your Mac's storage. CleanMyMac for people who'd rather not pay $40/year.")
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
    }

    @ViewBuilder
    private var principle: some View {
        VStack(spacing: Spacing.lg) {
            Image(systemName: "trash.slash")
                .font(.system(size: 56))
                .foregroundStyle(Color("grau-success"))
            Text("Nothing is ever permanently deleted")
                .font(.title2)
                .multilineTextAlignment(.center)
            VStack(alignment: .leading, spacing: Spacing.md) {
                Label("Grau never silently deletes anything.", systemImage: "1.circle")
                Label("Every cleanup moves files to your Trash.", systemImage: "2.circle")
                Label("Empty the Trash yourself, on your own schedule.", systemImage: "3.circle")
            }
            .padding(.horizontal, Spacing.lg)
        }
    }

    @ViewBuilder
    private var ready: some View {
        VStack(spacing: Spacing.lg) {
            Image(systemName: "checkmark.seal")
                .font(.system(size: 56))
                .foregroundStyle(Color("grau-accent"))
            Text("One last thing")
                .font(.title2)
                .multilineTextAlignment(.center)
            Text("Grau needs Full Disk Access to clean system caches. On the next screen we'll send you to System Settings to grant it.")
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
    }

    @ViewBuilder
    private var footer: some View {
        HStack {
            if step > 0 {
                Button("Skip") {
                    appVM.hasOnboarded = true
                    appVM.persist()
                }
                .buttonStyle(.borderless)
            }
            Spacer()
            if step < 2 {
                PrimaryButton("Continue") { step += 1 }
            } else {
                PrimaryButton("Get started") {
                    appVM.hasOnboarded = true
                    appVM.persist()
                }
            }
        }
    }
}
