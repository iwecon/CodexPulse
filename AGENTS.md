# AGENTS.md

## Project overview

Codex Pulse is a Swift Package Manager macOS 26+ accessory app. It renders two nonactivating SwiftUI panels beside the Dock and currently reads only local Codex usage data. Claude Code and OpenCode scanner implementations remain available but disabled. It does not send usage data over the network. Only non-Debug `.app` bundles configure launch at login; Debug and raw-executable runs leave startup state untouched.

## Panel terminology

- **Usage Overview Panel** (`用量概览面板`): the functionally named panel that shows the 14-day token-usage trend and Codex weekly limit. It is on the left when the Dock is at the bottom and above the other panel when the Dock is vertical.
- **Task Activity Panel** (`任务活动面板`): the functionally named panel that shows active and recently completed Codex tasks grouped by project and session. It is on the right when the Dock is at the bottom and below the other panel when the Dock is vertical.

Use these canonical names in documentation, requirements, code review, and new symbol names. Use “left/right panel” or “upper/lower panel” only when discussing physical placement; panel identity does not change with Dock orientation. Existing `leftPanel` and `rightPanel` symbols are positional legacy names for the Usage Overview Panel and Task Activity Panel, respectively.

## Build and test

- Run: `swift run "Codex Pulse"`
- Test: `swift test`
- Package tools version: Swift 6.2
- System dependency: SQLite 3 through the `CSQLite` system-library target

Run the full test suite after changing parsing, models, task state, launch-at-login behavior, or app lifecycle code.

## Source map

- `Sources/CodexPulse/App.swift`: app lifecycle, shared model, Dock panel placement, and SwiftUI views.
- `Sources/CodexPulse/UsageScanner.swift`: local Claude Code, Codex, and OpenCode usage scanning.
- `Sources/CodexPulse/TaskMonitor.swift`: Codex task-event parsing and visible-task selection.
- `Sources/CodexPulse/TaskExecutionLayout.swift`: shared task grouping, visible-row selection, and dynamic panel-height planning.
- `Sources/CodexPulse/Models.swift`: usage, rate-window, daily-usage, task, snapshot, and pricing models.
- `Sources/CodexPulse/LaunchAtLoginManager.swift`: login startup eligibility and `SMAppService` registration for release app bundles.
- `Tests/CodexPulseTests/LaunchAtLoginManagerTests.swift`: launch-at-login eligibility regression tests.
- `Tests/CodexPulseTests/ParserTests.swift`: parser and behavior regression tests.

## Implementation constraints

- Keep Codex as the only enabled usage source in `UsageSourcePolicy.enabledTools` unless a future product requirement explicitly re-enables another source. Preserve the disabled Claude Code and OpenCode scanner entry points so they can be restored without rebuilding their parsers.
- Keep all source-data access read-only. Never rewrite or delete files under `~/.claude`, `~/.codex`, or `~/.local/share/opencode`.
- Preserve actor isolation for `UsageScanner` and `TaskMonitor`; UI mutations remain on `MainActor`.
- Keep JSONL processing bounded-memory: read files in fixed-size chunks, parse complete lines individually, and never restore whole-file `Data(contentsOf:)` plus `String` loading. Keep per-line Foundation parsing inside a short-lived autorelease pool.
- Preserve per-file Claude/Codex scan caches. Unchanged files must reuse cached aggregates; changed, new, and removed files must invalidate or remove only their own cache entries. Do not restore periodic full-history parsing.
- OpenCode scan caching must account for the SQLite database and its WAL/SHM companions so read-only caching never hides new writes.
- Keep task-event monitoring incremental from the last byte offset. Bound incomplete-line buffers and discard cursors and pending state for threads that leave the monitored set.
- Avoid publishing equivalent snapshots or task arrays to the observable UI model. Time-based updates must stay in the smallest leaf view that needs them; do not wrap an entire panel in a high-frequency `TimelineView`.
- Treat polling and animation rates as a performance budget. The task activity indicator should not exceed 12 FPS and idle pointer polling should not exceed 4 Hz without new profiling evidence and a documented reason.
- Codex rate limits must be selected by the event observation timestamp, not filesystem enumeration order. Older session files must never overwrite a newer `rate_limits` snapshot.
- Treat `used_percent` as consumed quota. The UI derives remaining quota as `100 - used_percent`.
- Preserve per-session cumulative-token delta handling when changing Codex token parsing.
- Keep the app as an accessory app with borderless, nonactivating, click-through panels unless the product behavior is intentionally changed.
- Panel placement must continue to support bottom, left, and right Dock positions and multiple Spaces.

## Launch-at-login behavior

- Non-Debug `.app` bundles use `SMAppService.mainApp`.
- Debug builds and SwiftPM/raw-executable runs never read, write, or configure login startup state.
- Do not repeatedly override a user's decision to disable or remove the login item.
- Changes to `SMAppService` usage must be verified against the selected macOS SDK because ServiceManagement behavior is platform-version dependent.

## Code style

- Prefer focused types and small helpers over adding unrelated responsibilities to `App.swift`.
- Use Foundation and system frameworks before adding dependencies.
- Keep user-facing strings in Simplified Chinese unless the surrounding UI establishes another convention.
- Add a regression test for parsing or ordering bugs before considering the fix complete.
- Add regression coverage when changing streaming, cache invalidation, or incremental cursor behavior. For performance-sensitive scanner changes, validate both cold-scan peak and steady-state physical footprint against a realistically large local dataset; RSS alone includes reclaimable allocator pages and is not the acceptance metric.
- Avoid global formatting or unrelated refactors in focused changes.

## Documentation

Update `README.md` when user-visible behavior, requirements, supported data sources, run commands, or startup behavior changes. Update this file when architecture, invariants, or contributor workflows change.
