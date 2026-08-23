# AGENTS.md

## Project overview

Codex Pulse is a Swift Package Manager macOS 26+ accessory app. It renders two nonactivating SwiftUI panels beside the Dock and reads local Codex, Claude Code, and OpenCode usage data. The Usage Overview Panel shows a tool only while it has usage inside the visible 14-day window, so uninstalled or dormant tools stay hidden without any setting. It does not send usage data over the network. Only non-Debug `.app` bundles configure launch at login; Debug and raw-executable runs leave startup state untouched.

## Panel terminology

- **Usage Overview Panel** (`用量概览面板`): the functionally named panel that shows the 14-day token-usage trend and Codex weekly limit. It is on the left when the Dock is at the bottom and above the other panel when the Dock is vertical.
- **Task Activity Panel** (`任务活动面板`): the functionally named panel that shows active and recently completed Codex, Claude Code, and OpenCode tasks grouped by project and session. It is on the right when the Dock is at the bottom and below the other panel when the Dock is vertical.

Use these canonical names in documentation, requirements, code review, and new symbol names. Use “left/right panel” or “upper/lower panel” only when discussing physical placement; panel identity does not change with Dock orientation. Existing `leftPanel` and `rightPanel` symbols are positional legacy names for the Usage Overview Panel and Task Activity Panel, respectively.

## Build and test

- Run: `swift run "Codex Pulse"`
- Test: `swift test`
- Package tools version: Swift 6.2
- System dependency: SQLite 3 through the `CSQLite` system-library target

Run the full test suite after changing panel text rendering, wallpaper sampling or cache invalidation, refresh suspension, panel placement or window levels, interaction geometry, parsing, models, task state, launch-at-login behavior, or app lifecycle code.

## Source map

- `Sources/CodexPulse/App.swift`: app lifecycle, shared model, Dock panel placement, and SwiftUI views.
- `Sources/CodexPulse/CodexSessionLink.swift`: session-title overlay windows and their matching adaptive-foreground shadow rendering; Codex titles deep-link into ChatGPT, other tools' titles render as click-through text.
- `Sources/CodexPulse/DockPanelResizing.swift`: panel arrangement and persistence, placement geometry, window levels, pointer dwell, resizing, and interaction controls.
- `Sources/CodexPulse/RefreshActivityGate.swift`: composable refresh suspension for inactive sessions and sleeping displays.
- `Sources/CodexPulse/UsageScanner.swift`: read-only 14-day Claude Code, Codex, and OpenCode usage scanning with in-memory incremental cursors; it creates no derived on-disk cache.
- `Sources/CodexPulse/TaskMonitor.swift`: Codex task-event parsing, visible-task selection, and the shared display order for merged per-tool task lists.
- `Sources/CodexPulse/ClaudeTaskMonitor.swift`: Claude Code turn inference from session transcripts (prompt starts a turn, non-`tool_use` stop reason ends it, interrupt markers abort it, transcript growth counts as activity).
- `Sources/CodexPulse/OpenCodeTaskMonitor.swift`: OpenCode turn inference from its SQLite database (user message plus `parentID`-linked assistant messages; `finish` and completion times decide the state).
- `Sources/CodexPulse/TaskExecutionLayout.swift`: shared task grouping, visible-row selection, and dynamic panel-height planning.
- `Sources/CodexPulse/Models.swift`: usage, rate-window, daily-usage, task, snapshot, and pricing models.
- `Sources/CodexPulse/ToolBarColorSettings.swift`: per-tool usage-bar color overrides — hex persistence, resolution against the built-in adaptive colors, and the floating color-settings window opened from the Usage Overview Panel control group.
- `Sources/CodexPulse/LaunchAtLoginManager.swift`: login startup eligibility and `SMAppService` registration for release app bundles.
- `Sources/CodexPulse/WallpaperAppearance.swift`: wallpaper geometry, candidate sampling, Store directory monitoring, semantic appearance selection, refresh tracking, and decoded-asset caching.
- `Sources/CodexPulse/WallpaperSourceResolver.swift`: typed local wallpaper-source resolution from Store selections, including solid, file-backed, video, Aerial, supported dynamic, and unavailable sources.
- `Tests/CodexPulseTests/DockPanelWidthGeometryTests.swift`: panel arrangement, placement, overlay geometry, dwell timing, and window-level regression tests.
- `Tests/CodexPulseTests/LaunchAtLoginManagerTests.swift`: launch-at-login eligibility regression tests.
- `Tests/CodexPulseTests/ParserTests.swift`: parser and behavior regression tests.
- `Tests/CodexPulseTests/RefreshActivityGateTests.swift`: multi-reason refresh suspension and task-animation pause regression tests.
- `Tests/CodexPulseTests/ToolBarColorTests.swift`: bar-color hex serialization, persistence, and override-resolution regression tests.
- `Tests/CodexPulseTests/WallpaperAppearanceTests.swift`: wallpaper mapping, appearance selection, refresh tracking, and decoded-orientation regression tests.

## Implementation constraints

- Keep every usage source enabled in `UsageSourcePolicy.enabledTools`; visibility is decided per tool by `Snapshot.activeTools` (usage inside the visible 14-day window), not by settings. Do not add a user-facing source toggle unless a future product requirement explicitly calls for one.
- The multi-tool trend renders stacked per-tool segments with fixed OKLab hues (`Tool.barHueDegrees`; a `nil` hue renders achromatic, used for OpenCode's monochrome brand) whose lightness follows the panel's text polarity via `AdaptiveTextColor.barColor`. With one or zero active tools the trend keeps the single-color accent ramp and the date row; with several it shows the per-tool legend instead. Users may override any tool's bar color from the Usage Overview Panel control group's color button (`ToolBarColorSettings`): an override is a fixed color used in both panel appearances, persisted as `#RRGGBB` in local `UserDefaults`, resettable per tool or all at once, and recolors the stacked segments, both legends, the single-tool accent ramp, and the Codex quota bar.
- Task Activity Panel status indicators (running ring and completion checkmark) are colored per session: `AdaptiveTextColor.sessionHueDegrees` derives a stable OKLab hue from the thread ID (FNV-1a, quantized to 12 hues) and `sessionStatusColor` renders it with the same polarity-adaptive lightness as trend-bar colors. Keep the hue deterministic across launches so a session never changes color.
- The weekly-limit section remains Codex-only: local rate-limit data exists only in Codex rollout files (Claude Code does not persist quota data locally). Hide the section when Codex is dormant; keep it as the empty-state anchor when no tool is active.
- Keep all source-data access read-only. Never rewrite or delete files under `~/.claude`, `~/.codex`, or `~/.local/share/opencode`.
- Preserve actor isolation for `UsageScanner` and `TaskMonitor`; UI mutations remain on `MainActor`.
- Treat session inactivity and display sleep as independent refresh-suspension reasons. Resume refresh loops only after every active reason clears. Preserve cancellation and post-await activity checks so an in-flight scan cannot publish after suspension, and keep task-status animation paused for the full suspended interval.
- Keep JSONL processing bounded-memory: read files in fixed-size chunks, parse complete lines individually, and never restore whole-file `Data(contentsOf:)` plus `String` loading. Keep per-line Foundation parsing inside a short-lived autorelease pool.
- Usage derivation must remain memory-only: do not create a local database, serialized snapshot, imported-session cache, or other derived on-disk usage store. Cold launch considers only files/rows that can contain the visible 14-day window, and `Snapshot.usage` is the same rolling 14-day total shown by the panel rather than a lifetime total.
- Preserve per-file Claude caches and complete-line Codex byte cursors in memory. After Codex cold aggregation, release every per-event candidate and retain only the 14-day summary, window-scoped deduplication fingerprints, rate limits, and each active file's byte offset, continuity hash, and single cumulative parser baseline. Unchanged files must be zero-read and continuous appends must parse only the suffix after the last complete line. Crossing a day boundary, changing the weekly quota window, or detecting removal, truncation, or replacement may rebuild Codex's bounded 14-day summary instead of retaining rollback-ready event history. Cold Codex files that start inside the window and end on a complete line use balanced, shell-free parallel batches of the built-in macOS `grep`/`awk` streaming prefilter; keep arguments below platform limits, verify source versions after filtering, and retry files appended during filtering before falling back. Ordinary session content and full turn contexts must not enter the app process. `token_count` rows use the allocation-light narrow byte parser for timestamps, counters, and rate limits rather than Foundation object-tree decoding. Keep transient allocation pressure bounded during realistically large cold scans. Do not restore periodic full-history parsing.
- OpenCode scan caching must account for the SQLite database and its WAL/SHM companions so read-only caching never hides new writes. Restrict cold queries to the 14-day window and, when the source provides `message_session_time_created_id_idx`, scan that covering index for recent candidate IDs before point-reading changed rows; retain the compatible full-query fallback for older schemas. After a source-version change, decode only rows whose IDs are new or whose `time_updated` changed; remove deleted or expired rows from memory.
- Keep task-event monitoring incremental from the last byte offset. Bound incomplete-line buffers and discard cursors and pending state for threads that leave the monitored set.
- The Task Activity Panel merges tasks from all three tools through `TaskMonitor.sortedForDisplay`. A Codex Goal-only automatic continuation has no displayable user event because its injected internal context stays hidden; inherit the same session's latest real user message until an inserted conversation replaces it, so the task row never falls back to a dash. Claude Code and OpenCode have no explicit task events: their turn boundaries are inferred from local session records, and a running turn whose session shows no activity past the monitor's stale interval (slightly above the ten-minute Bash tool-call ceiling) is dropped. For Claude Code, transcript byte growth counts as activity even when the appended lines parse to no events — do not judge liveness by parsed events alone.
- Only Codex session titles are clickable deep links; Claude Code and OpenCode session titles must stay click-through like the rest of the panel content.
- Avoid publishing equivalent snapshots or task arrays to the observable UI model. Time-based updates must stay in the smallest leaf view that needs them; do not wrap an entire panel in a high-frequency `TimelineView`.
- Treat polling and animation rates as a performance budget. The task activity indicator should not exceed 12 FPS and idle pointer polling should not exceed 4 Hz without new profiling evidence and a documented reason.
- Codex rate limits must be selected by the event observation timestamp, not filesystem enumeration order. Older session files must never overwrite a newer `rate_limits` snapshot.
- Only the account-level Codex quota belongs in the weekly-limit section. Accept legacy `rate_limits` records without `limit_id` and current records whose `limit_id` is `codex`; ignore named/model-specific limits even when they reuse the same window duration.
- Treat `used_percent` as consumed quota. The UI derives remaining quota as `100 - used_percent`.
- Preserve per-session cumulative-token delta handling when changing Codex token parsing.
- Keep the app as an accessory app with borderless, nonactivating, click-through panels unless the product behavior is intentionally changed.
- Panel placement must continue to support bottom, left, and right Dock positions and multiple Spaces.
- Keep content, session-link, and interaction windows below normal application windows. Session-link hit targets must remain above content panels, and interaction controls must remain above both.
- Keep panel text, including the AppKit session-link overlays and language picker, adaptive between black and white using the sampled wallpaper contrast, with one subtle opposite-color shadow. Preserve the SwiftUI primary/secondary brightness hierarchy through the local semantic appearance. Do not reintroduce fixed-color text, outlines, or multi-copy text rendering unless a future product requirement explicitly changes the contrast treatment.
- Keep wallpaper appearance sampling file-based and read-only. Do not replace it with screen capture or introduce Screen Recording permission. Preserve separate per-panel area-averaged RGB sampling, desktop scaling/clipping/fill-color semantics, transparent-pixel compositing, AppKit-to-image coordinate orientation, luminance hysteresis, and system-appearance fallback.
- Keep wallpaper Store monitoring read-only, debounced, cancellable, and scoped to the Store directory so atomic `Index.plist` replacement is observed. Deliver file-system events on the main queue before touching the `@MainActor` monitor or panel controller. Monitoring failure must silently retain the five-second polling fallback. Resolve Store selections once into typed solid, static-image, phase-unknown candidate, or unavailable sources using public property-list APIs and local assets only. Solid selections are authoritative; only explicit Pictures/Photos/Movies selections may use the workspace URL fallback. Never substitute a stale workspace URL for known dynamic, Aerial, extension, or procedural selections, and never download assets.
- Resample wallpaper appearance only when wallpaper identity or options, screen identity or size, or sampled panel regions change. Reuse the decoded wallpaper when only geometry or display options change; invalidate it when the wallpaper URL, modification date, or file size changes. Cancel superseded work and reject stale generations before applying appearance results.
- When the system appearance changes, apply its semantic appearance immediately as a fallback, then invalidate and resample the wallpaper after the desktop transition settles. Space changes, session activation, and display wake should re-check state without forcing redundant decoding.

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
