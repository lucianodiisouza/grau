//
//  AppIconView.swift
//  grau
//
//  Renders the real .icns icon for an installed app, with a
//  sensible SF Symbol fallback while the icon cache is being
//  warmed (very first frame after `scan()`) or when the bundle
//  has no icon (rare, mostly Apple's own system frameworks).
//

import SwiftUI
import AppKit

struct AppIconView: View {
    let image: NSImage?
    let isSystem: Bool
    var size: CGFloat = 32

    var body: some View {
        Group {
            if let image, image.size.width > 0 {
                Image(nsImage: image)
                    .resizable()
                    .interpolation(.high)
                    .aspectRatio(contentMode: .fit)
            } else {
                fallback
            }
        }
        .frame(width: size, height: size)
    }

    @ViewBuilder
    private var fallback: some View {
        // We have to fabricate a "missing icon" placeholder. For
        // system components prefer `lock.shield`; for everything
        // else use a neutral `app` glyph. The full square uses the
        // system fill so it reads as a placeholder, not real data.
        ZStack {
            RoundedRectangle(cornerRadius: size * 0.22, style: .continuous)
                .fill(Color.secondary.opacity(0.15))
            Image(systemName: isSystem ? "lock.shield" : "app")
                .font(.system(size: size * 0.5))
                .foregroundStyle(.secondary)
        }
    }
}
