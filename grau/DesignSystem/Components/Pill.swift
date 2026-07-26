//
//  Pill.swift
//  grau
//
//  Status badge with text + tinted background. See docs/DESIGN.md § 2.5.
//

import SwiftUI

public struct Pill: View {
    public let text: String
    public let tone: Tone

    public enum Tone {
        case info
        case success
        case warning
        case danger
        case neutral

        var color: Color {
            switch self {
            case .info: Color("grau-accent")
            case .success: Color("grau-success")
            case .warning: Color("grau-warning")
            case .danger: Color("grau-danger")
            case .neutral: Color("grau-gray-500")
            }
        }
    }

    public init(_ text: String, tone: Tone = .info) {
        self.text = text
        self.tone = tone
    }

    public var body: some View {
        Text(text)
            .font(.caption)
            .foregroundStyle(tone.color)
            .padding(.horizontal, Spacing.sm)
            .padding(.vertical, 4)
            .background(tone.color.opacity(0.12))
            .clipShape(Capsule())
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("\(text), \(tone.accessibilityDescription)")
    }
}

private extension Pill.Tone {
    var accessibilityDescription: String {
        switch self {
        case .info: "info"
        case .success: "success"
        case .warning: "warning"
        case .danger: "danger"
        case .neutral: "neutral"
        }
    }
}

#Preview {
    VStack(alignment: .leading, spacing: Spacing.sm) {
        Pill("12.4 GB", tone: .info)
        Pill("Healthy", tone: .success)
        Pill("Outdated", tone: .warning)
        Pill("Destructive", tone: .danger)
        Pill("Off", tone: .neutral)
    }
    .padding()
}
