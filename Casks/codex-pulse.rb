cask "codex-pulse" do
  arch arm: "arm64", intel: "x86_64"

  version :latest
  sha256 :no_check

  url "https://github.com/iwecon/CodexPulse/releases/latest/download/Codex-Pulse-#{arch}.dmg"
  name "Codex Pulse"
  desc "Codex usage and task activity panels beside the macOS Dock"
  homepage "https://iwecon.github.io/CodexPulse/"

  depends_on macos: ">= :tahoe"

  app "Codex Pulse.app"

  caveats "Codex Pulse requires macOS 26 or later."

  zap trash: [
    "~/Library/Preferences/com.iwecon.CodexPulse.plist",
    "~/Library/Saved Application State/com.iwecon.CodexPulse.savedState",
  ]
end
