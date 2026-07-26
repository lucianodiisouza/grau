//
//  DestructiveButton.swift
//  grau
//
//  Filled danger-tone button for destructive actions.
//  See docs/DESIGN.md § 2.6.
//

import SwiftUI

public struct DestructiveButton: View {
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
                    ? Color("grau-danger")
                    : Color("grau-danger").opacity(0.4)
            )
            .foregroundStyle(.white)
            .clipShape(RoundedRectangle(cornerRadius: Radius.button))
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled)
    }
}

#Preview {
    DestructiveButton("Uninstall", systemImage: "trash") {}
        .padding()
        .frame(width: 240)
}
