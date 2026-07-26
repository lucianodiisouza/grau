# Homebrew Cask formula for Grau.
#
# This file lives in homebrew-cask/ in the grau repo for review,
# but the canonical copy is in the homebrew/homebrew-cask tap.
# Submit it via `brew tap` flow:
#   brew tap lucianodiisouza/grau
#   brew install --cask grau
#
# Update the version + sha256 on every release. The sha256 is the
# shasum of Grau-<version>.dmg in the GitHub release.
#
# Validate with:
#   brew audit --new grau

cask "grau" do
  version "1.1.0"
  sha256 "<SHA256_OF_Grau-#{version}.dmg>"

  url "https://github.com/lucianodiisouza/grau/releases/download/v#{version}/Grau-#{version}.dmg"
  name "Grau"
  desc "Free, open-source native macOS utility for cleaning, inspecting, and managing storage"
  homepage "https://github.com/lucianodiisouza/grau"

  livecheck do
    url :url
    strategy :github_latest_release
  end

  app "Grau.app"

  zap trash: [
    "~/.grau/",
    "~/Library/Application Support/Grau",
    "~/Library/Logs/grau",
    "~/Library/Preferences/app.grau.mac.plist",
  ]

  caveats <<~EOS
    Grau is unsigned by default. On first launch, right-click
    Grau.app and choose Open to bypass Gatekeeper. To remove
    the warning entirely, build from source or use a notarized
    release from the GitHub Releases page.
  EOS
end
