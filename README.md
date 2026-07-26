# Grau

> A free, open-source, native macOS utility for cleaning, inspecting, and managing your Mac's storage.
> CleanMyMac for people who'd rather not pay $40/year.

**Status:** 🚧 work in progress. Planning docs in [`docs/`](./docs). No public release yet.

## What it will do (v1)

- 🧹 **Junk cleaner** — caches, logs, browser data, dev caches, trash
- 📦 **App uninstaller** — uninstalls `.app` bundles *and* their residual data
- 🔍 **Disk lens** — visualize your whole disk, drill down, free space safely
- 🪞 **Duplicates finder** — find byte-identical files anywhere
- 🛠 **Dev mode** — `node_modules`, package manager caches, Docker, iOS Simulators
- 📌 **Menu bar tray** — live storage state, smart notifications

## First principles

1. **The user owns their data.** Grau never silently deletes anything. Everything goes to `~/.Trash`.
2. **Be a good citizen.** Reads what it needs, asks for permissions once, never exfiltrates.
3. **Look and feel native.** Not "designed on iOS." Sidebar, system materials, SF Symbols, smart dark mode.
4. **Be fast.** Scans in seconds, not minutes.

## Build

Native Swift + SwiftUI, macOS 14 (Sonoma)+, Apple Silicon and Intel. No third-party runtime dependencies in v1 except Sparkle for self-update.

## License

[MIT](./LICENSE).
