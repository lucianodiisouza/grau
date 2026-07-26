//
//  PrimaryButton.swift
//  grau
//
//  Filled accent button. See docs/DESIGN.md § 2.6.
//

import SwiftUI

public struct PrimaryButton: View {
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
            .background(
                isEnabled
                    ? Color("grau-accent")
                    : Color("grau-accent").opacity(0.4)
            )
            .foregroundStyle(.white)
            .clipShape(RoundedRectangle(cornerRadius: Radius.button))
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled)
        .focusable(false)
    }
}

#Preview {
    VStack(spacing: Spacing.md) {
        PrimaryButton("Clean Junk", systemImage: "trash") {}
        PrimaryButton("Disabled", isEnabled: false) {}
    }
    .padding()
    .frame(width: 240)
}
