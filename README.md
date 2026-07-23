# Codex Pulse

<p align="center">
  <strong>English</strong> ·
  <a href="README.zh-CN.md">简体中文</a> ·
  <a href="README.zh-HK.md">繁體中文（香港）</a> ·
  <a href="README.zh-TW.md">繁體中文（台灣）</a> ·
  <a href="README.ja.md">日本語</a> ·
  <a href="README.ko.md">한국어</a>
</p>

Codex Pulse is a private, local-first macOS desktop accessory built with SwiftUI and AppKit. Its **Usage Overview Panel** and **Task Activity Panel** sit beside the Dock to show local Codex token usage, weekly quota, and recent task status. It reads everything from your Mac and uploads nothing.

<p align="center">
  <a href="https://iwecon.github.io/CodexPulse/">
    <img src="docs/assets/codex-pulse-preview.jpg" alt="Codex Pulse preview: the Usage Overview Panel and Task Activity Panel beside the macOS Dock" width="1200">
  </a>
</p>

<p align="center">
  <a href="https://iwecon.github.io/CodexPulse/">Product page</a>
  ·
  <a href="https://github.com/iwecon/CodexPulse/releases/latest">Download the latest release</a>
  ·
  <a href="https://github.com/iwecon/CodexPulse">View source</a>
</p>

On desktop browsers, the product page includes an interactive macOS desktop demo with a theme menu, draggable windows, live Activity Monitor metrics, Dock-panel controls matching the app, and authentic system app icons adapted for light and dark themes. At widths of 760px and below, it retains the vertical mobile layout.

## Install

Codex Pulse requires macOS 26 or later. GitHub Actions builds separate DMGs for Apple silicon (arm64) and Intel (x86_64), published with each version on [GitHub Releases](https://github.com/iwecon/CodexPulse/releases/latest).

### AI-assisted install

Give the following exact prompt to your coding assistant:

```text
From https://iwecon.github.io/CodexPulse/ to Install CodexPulse. Try Homebrew first, then npm, and finally download and install via the GitHub Release Page.
```

### Homebrew

This repository also serves as a custom tap:

```bash
brew tap iwecon/codex-pulse https://github.com/iwecon/CodexPulse
brew install --cask iwecon/codex-pulse/codex-pulse
```

### npm

The npm package provides an explicit installer CLI. It never mounts a DMG or changes your Applications folder silently during `npm install`:

```bash
npm install -g github:iwecon/CodexPulse
codex-pulse install
```

The default destination is `~/Applications/Codex Pulse.app`. Use `codex-pulse install --force` to reinstall, then `codex-pulse open` to launch the app.

Once npm publishing credentials are configured for this repository, the registry shorthand `npm install -g @iwecon/codex-pulse` is also available.

### Signing

The GitHub release workflow requires a Developer ID Application certificate and private key. It imports them into a temporary keychain on each macOS runner, signs the app with the hardened runtime and a secure timestamp, signs the DMG with a secure timestamp, verifies both signatures, and removes the temporary signing material even if the build fails. Release builds are not notarized.

The Apple account currently intended for releases, `1219i@sina.cn`, must first issue a **Developer ID Application** certificate and export it with its private key as a password-protected PKCS#12 (`.p12`) file. A local Xcode login is not available to GitHub-hosted runners and does not configure CI credentials.

Configure these GitHub Actions repository secrets before running the release workflow:

- `DEVELOPER_ID_APPLICATION_P12_BASE64`: base64 encoding of the exported `.p12` file.
- `DEVELOPER_ID_APPLICATION_P12_PASSWORD`: password used when exporting the `.p12` file.

The workflow fails with a clear error if either secret is absent or the imported file does not contain a usable Developer ID Application identity. Do not add notarization credentials unless notarization is implemented separately.

Local/manual packaging remains ad hoc by default. To sign explicitly, pass `--signing-identity` (preferably the identity's SHA-1) and, when the identity is isolated in a non-default keychain, `--signing-keychain` to `script/package_release.sh`.

## Panel terminology

- **Usage Overview Panel**: appears on the left when the Dock is at the bottom and summarizes the 14-day token-usage trend and Codex weekly quota.
- **Task Activity Panel**: appears on the right when the Dock is at the bottom and shows active and recently completed Codex tasks grouped by project and session.

These are the canonical names used in documentation, requirements, and code discussions because they describe panel responsibilities. With a left or right Dock, the Usage Overview Panel moves above the Task Activity Panel; their identities never change with placement.

## Features

- Codex is currently the only enabled token-usage source. Claude Code and OpenCode scanners remain implemented but disabled, and can later be re-enabled through `UsageSourcePolicy.enabledTools`.
- Shows a 14-day usage trend and today's token consumption beside today's date.
- Shows the Codex weekly quota, remaining percentage, reset time, a remaining-time countdown with graduated detail (including seconds in the final minute), and a daily available percentage based on the exact time remaining.
- The Task Activity Panel dynamically fits visible content and is normally at most 120px tall. Starting from the bottom, it groups all active tasks and tasks completed within the last 10 minutes by project and session. Active tasks are never subject to the 10-minute limit and must all remain visible, allowing the panel to exceed 120px when needed; remaining space is filled with completed tasks from newest to oldest. Active tasks use a rotating ring with a gradient trail. Short transitions accompany task insertion and removal and respect Reduce Motion. Messages lose contrast after three completed minutes and disappear after ten; the latest user message is compactly shown in its natural one or two lines.
- Repositions automatically for bottom, left, and right Dock locations.
- All primary-panel text—including AppKit session-title overlays and project titles—is uniformly white with one subtle black shadow. Primary and secondary text retain distinct brightness levels. Panels remain fully transparent, do not capture the screen, and require no Screen Recording permission.
- Each panel still samples the desktop wallpaper beneath its own region to choose light or dark semantics for other appearance elements. A system appearance change applies an immediate fallback, then clears caches and restores independent regional sampling after the wallpaper transition. Space changes, display wake, and login-session restoration re-check wallpaper files and display options, resampling only when state changes.
- Panels remain above desktop icons and below normal application windows, so they do not cover the active app.
- After the pointer remains still inside either panel for 0.5 seconds, a unified horizontal Liquid Glass control group appears at the panel's inner resize edge; moving the pointer restarts the timer. Both panels use the same fade-in animation. All glass surfaces use continuous corners. The 34px resize segment sits inside the content edge—right-aligned in the left panel and left-aligned in the right panel—and, like the action buttons, responds through a 6px outer inset. Action buttons divide and fill the remaining region. The left panel keeps its left edge fixed and resizes from the right; the right panel does the reverse. With a tall bottom Dock, the interaction area extends upward. After the pointer leaves the combined panel-and-control region, the controls wait one second before fading; returning or actively dragging keeps them visible.
- Entering the 34px resize segment scales the other buttons to 0.98 and fades them out over 0.34 seconds. The outer Liquid Glass background retains its full width while shrinking its 6px inset inward, transitions to a 10px corner radius, and fades to transparent. Only after the animation does the interaction window contract to the resize segment, preventing invisible click interception. Leaving the segment does not restore controls; entering an actual action-button region does. During dragging, only the resize segment remains until pointer release.
- Left/right movement buttons are always present and move a panel to the other logical side; after moving, their direction reverses. When both panels occupy the same side, an additional vertical-swap button changes stacking order. Logical sides map to left/right with a bottom Dock and above/below with a vertical Dock. Panel positions and individual widths persist across launches and are clamped to the current display, Dock, and available space to prevent overlap. When the Usage Overview Panel is on the logical right, its trend and quota layouts mirror and right-align.
- The Task Activity Panel control group includes a text-alignment button that cycles through automatic, left, and right alignment, updates its icon, and persists the choice. Automatic alignment is left on the logical left and right on the logical right. Right alignment also places the duration before the status icon.
- The Usage Overview Panel control group includes a language button. It replaces the action area with a native AppKit vertical wheel picker that supports clicking visible languages, press-dragging, mouse-wheel scrolling, and trackpads. It supports Mainland Simplified Chinese, Hong Kong Traditional Chinese, Taiwan Traditional Chinese, Japanese, Korean, and English. The selection applies to both panels, date formats, and AppKit accessibility labels and tooltips, and is stored only in local `UserDefaults`. Mainland Simplified Chinese is the first-launch default.
- Ordinary panel content stays click-through and does not activate the app. Session titles in the Task Activity Panel are clickable and open the matching Codex conversation in ChatGPT. The separate unified Liquid Glass controls still accept pointer input.
- A non-Debug `.app` configures launch at login on first launch.

Codex quota data is selected from the `rate_limits` snapshot with the newest event timestamp, preventing older sessions from replacing current limits. Quota appears only when a log actually contains that field.

## Resource use

- Initial launch reads existing history. JSONL files are parsed line by line in fixed-size chunks and are never expanded into whole-file `Data` and `String` values at once.
- Codex parsing results are cached per file, so later refreshes parse only new or changed files. The disabled Claude Code and OpenCode implementations retain their own file and database/WAL/SHM caches for incremental scanning if re-enabled.
- Codex task logs are read incrementally from byte cursors. Task-index queries are briefly cached to avoid querying SQLite on every poll.
- Usage and task refreshes pause while the user session is locked or the display sleeps, and active-task animations freeze for the full interval. They resume immediately after unlock and wake.
- Equivalent data does not republish SwiftUI state. Countdown, duration, and activity updates are isolated to their smallest leaf views rather than redrawing a whole panel at high frequency.

Cold launch can still produce a brief memory peak with a large local history, but memory should return to steady state after the first scan. Periodic refreshes should not rescan all historical files.

## Requirements

- macOS 26+
- Xcode 26+ / Swift 6.2+
- SQLite 3

## Run

```bash
swift run "Codex Pulse"
```

The app runs as an accessory without a Dock icon. `swift run`, other raw executables, and Debug builds never read, write, or configure login items. Only a non-Debug `.app` uses macOS `SMAppService` to configure launch at login.

If the user disables the login item in System Settings, the app does not force-enable it during later ordinary launches.

## Release

Pushing a tag such as `v0.1.0` triggers `.github/workflows/release.yml`, which builds on GitHub-hosted macOS 26 arm64 and Intel runners:

- `Codex-Pulse-arm64.dmg`
- `Codex-Pulse-x86_64.dmg`
- `SHA256SUMS`

Each build requires the Developer ID secrets described under [Signing](#signing). The workflow then creates or updates the corresponding GitHub Release. If repository variable `PUBLISH_NPM=true` and npm credential `NPM_TOKEN` are configured, the same version is also published as `@iwecon/codex-pulse`.

## Test

```bash
swift test
```

Tests cover log parsing, date handling, newest Codex quota selection, task state, compact number formatting, launch-at-login eligibility, Dock panel arrangement and control geometry, window levels, wallpaper coordinate mapping and semantic appearance, wallpaper cache invalidation, and refresh-state transitions during lock and sleep.

## Data sources

- Codex usage (enabled): `~/.codex/sessions/**/*.jsonl`
- Codex task index: `~/.codex/state_*.sqlite`
- Claude Code (disabled, entry point retained): `~/.claude/projects/**/*.jsonl`
- OpenCode (disabled, entry point retained): `~/.local/share/opencode/opencode.db`

If an enabled source is missing or cannot be read, only that tool is affected. Codex Pulse never uploads data or modifies original session records. Disabled sources do not access their local files.
