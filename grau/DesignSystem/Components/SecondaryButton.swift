//
//  SecondaryButton.swift
//  grau
//
//  Outlined accent button. See docs/DESIGN.md § 2.6.
//

import SwiftUI

public struct SecondaryButton: View {
    public let title: String
    public let action: () -> Void
    public var isEnabled: Bool = true
    public var systemImage: String?

    public init(
        _ title: String,
        systemImage: String? = nil,
        isEnabled: Bool = true,
        action: @escaping () -> Void
    ) {
        self.title = title
        self.systemImage = systemImage
        self.isEnabled = isEnabled
        self.action = action
    }

    public var body: some View {
        Button(action: action) {
            HStack(spacing: Spacing.sm) {
                if let systemImage {
                    Image(systemName: systemImage)
                }
                Text(title)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 32)
            .overlay(
                RoundedRectangle(cornerRadius: Radius.button)
                    .stroke(
                        isEnabled
                            ? Color("grau-accent")
                            : Color("grau-accent").opacity(0.4),
                        lineWidth: 1
                    )
            )
            .foregroundStyle(
                isEnabled
                    ? Color("grau-accent")
                    : Color("grau-accent").opacity(0.4)
            )
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled)
    }
}

#Preview {
    VStack(spacing: Spacing.md) {
        SecondaryButton("Reveal in Finder", systemImage: "folder") {}
        SecondaryButton("Disabled", isEnabled: false) {}
    }
    .padding()
    .frame(width: 240)
}
