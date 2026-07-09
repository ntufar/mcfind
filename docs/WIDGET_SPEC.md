# McFind macOS Widget — Requirements & Implementation Plan

> Proposal for a WidgetKit extension that surfaces McFind search/results on the macOS Desktop, Notification Center, and (optionally) StandBy.

## 1. Goals

- Let users glance at recent/pinned files without opening McFind.
- Let users jump straight into a search from the widget (deep link into the app).
- Keep the widget fast and battery-friendly — it must not run its own file indexer.

## 2. Non-Goals

- The widget will **not** perform live filesystem scanning or FSEvents monitoring itself.
- The widget will **not** support typing a live query inside the widget (WidgetKit has no text input). Interaction is limited to taps/clicks that deep-link into the main app.
- No iOS/iPadOS counterpart in this phase (macOS only, matching the app's current platform).

## 3. Requirements

### 3.1 Functional

| ID | Requirement |
|----|-------------|
| W1 | Widget available in Notification Center widget gallery in three sizes: Small, Medium, Large. |
| W2 | Small widget shows: app icon/title + count of indexed files + last index time. |
| W3 | Medium widget shows: up to 4 recent/pinned files (name, icon, relative path) + index status. |
| W4 | Large widget shows: up to 8 recent/pinned files, same layout as Medium. |
| W5 | Tapping a file row deep-links into McFind and reveals/selects that file in the results table. |
| W6 | Tapping the widget's empty/header area launches McFind to the search bar (focused, empty query). |
| W7 | Widget reflects "not indexed yet" / "indexing in progress" / "N files indexed" states. |
| W8 | User can configure widget content source via `WidgetConfigurationIntent`: "Recently Modified", "Recently Added to Index", or "Pinned Files" (if pinning exists — see 3.3). |
| W9 | Widget updates on a timeline (not real-time) — acceptable staleness is a few minutes. |

### 3.2 Non-Functional

| ID | Requirement |
|----|-------------|
| N1 | Widget extension process must not open the SQLite index for writing — read-only access. |
| N2 | Widget must render in <100ms from cached snapshot data (WidgetKit placeholder/snapshot contract). |
| N3 | No noticeable battery/CPU impact — timeline reloads budgeted, not polling. |
| N4 | Widget must work correctly even if McFind.app is not currently running. |
| N5 | Widget must respect the existing "which folders are indexed" settings (don't leak file names from folders the user excluded — moot since it's the same index, but the query must not bypass any future privacy filters). |

### 3.3 Open Product Questions (need a decision before/at design time)

1. Does McFind need a "pinned files" concept, or is "recent" (by `dateModified` or by "recently added to index") sufficient for v1? Recommend **v1 ships with "Recently Modified" and "Recently Added" only**, defer pinning.
2. Should the widget show search results for a *fixed* saved query (e.g. user picks "*.pdf" in widget config) in addition to recency lists? Recommend **defer to v2**.

## 4. Architecture

### 4.1 Current state (relevant facts from the codebase)

- McFind is a single-target SwiftUI macOS app (`McFind.xcodeproj`, target `McFind`).
- `McFind/McFind.entitlements` currently sets `com.apple.security.app-sandbox = false` — the app is **not sandboxed**.
- The index lives in a private SQLite DB at `~/Library/Application Support/McFind/index.db`, opened directly by `IndexDatabase.swift` via raw `SQLite3` C API (WAL mode, `synchronous=NORMAL`).
- Settings are plain `UserDefaults.standard` (`AppSettings.swift`, `IndexSettings.swift`) — not currently in a shared/App Group suite.
- `FileItem` (`FileItem.swift`) is the in-memory row model; it uses `NSImage`/`NSWorkspace` for icons, which is fine in-process but not something to share via App Group directly (recompute icons per-process instead).

### 4.2 Required changes to enable a widget

WidgetKit extensions are **always sandboxed**, regardless of whether the host app is. To let a sandboxed extension read data produced by the (currently unsandboxed) main app, the standard mechanism is an **App Group**:

1. **Add an App Group entitlement** (`group.com.ntufar.mcfind`) to both the main app and the new widget extension target. This requires an Apple Developer Program team/App ID capability — needs the signing account that already produces the notarized/signed builds (see `CODE_SIGNING.md`).
2. **Move the SQLite index** (or a read-only copy/export of it) into the App Group's shared container: `FileManager.default.containerURL(forSecurityApplicationGroupIdentifier:)`. Two options:
   - **Option A (shared DB)**: Move `index.db` itself into the shared container; both the app and widget open the same file (widget opens read-only, `SQLITE_OPEN_READONLY`, safe under WAL as long as the app remains the sole writer).
   - **Option B (snapshot export)**: Main app periodically writes a small denormalized JSON/plist snapshot (e.g. last 20 recent files + counts) into the shared container; the widget reads only that snapshot, never touches SQLite. Simpler, more robust against WAL/locking edge cases, avoids giving the sandboxed widget any SQLite dependency.
   - **Recommendation: Option B for v1.** It's far less risky (no cross-process SQLite locking/schema-migration coupling) and matches WidgetKit's "cheap timeline provider" model. Revisit Option A only if the widget needs arbitrary querying later.
3. **Move `UserDefaults.standard` settings the widget needs (e.g. indexed file count, last index date) to an App Group suite** (`UserDefaults(suiteName: "group.com.ntufar.mcfind")`), or include them in the Option B snapshot file. Prefer folding everything into the snapshot to keep one source of truth.
4. **New Xcode target**: `McFindWidget` (WidgetKit Extension), added to `McFind.xcodeproj`, embedded in the main app's build product.
5. **Deep linking**: Add a custom URL scheme (e.g. `mcfind://reveal?path=...` and `mcfind://search`) handled by `McFindApp.swift` via `.onOpenURL`, since the widget's `Link`/`widgetURL` triggers app launch with a URL, not direct method calls.
6. **Sandbox review for the main app**: adding an App Group to an unsandboxed app is allowed (sandbox itself stays off), but confirm the entitlement doesn't force sandboxing — it doesn't; App Groups can be used by non-sandboxed apps too. No change needed to `com.apple.security.app-sandbox` in the main app.

### 4.3 New components

```
McFindWidget/                         (new Xcode target: Widget Extension)
├── McFindWidgetBundle.swift          @main WidgetBundle
├── McFindWidget.swift                Widget struct (kind: "com.mcfind.widget")
├── Provider.swift                    TimelineProvider / AppIntentTimelineProvider
├── McFindWidgetEntry.swift           TimelineEntry model (files, counts, state)
├── Views/
│   ├── SmallWidgetView.swift
│   ├── MediumWidgetView.swift
│   └── LargeWidgetView.swift
├── ConfigurationIntent.swift         AppIntent-based configuration (source picker)
└── Info.plist

McFind/ (shared additions)
├── SharedContainer.swift             App-Group container URL + snapshot read/write helpers (used by both targets)
├── WidgetSnapshot.swift              Codable struct: files[], indexedCount, lastIndexDate, indexState
└── McFindApp.swift                   + .onOpenURL handler for mcfind:// deep links
```

`WidgetSnapshot` and `SharedContainer` should live in a small shared Swift file (or a shared framework target if code-signing tooling makes a plain file group awkward) so both `McFind` and `McFindWidget` targets compile it without duplicating logic.

### 4.4 Data flow

1. Main app's `IndexDatabase`/`FileIndexer`, after a batch commit or FSEvents flush, calls `SharedContainer.writeSnapshot(...)` with the latest "recently modified" / "recently added" top-N lists and index stats. Debounced (e.g. same 5s window as FSEvents flush) so it's not written on every single file change.
2. `WidgetCenter.shared.reloadTimelines(ofKind: "com.mcfind.widget")` is called after each snapshot write so WidgetKit knows to refresh, subject to the OS's own budget/throttling.
3. Widget's `TimelineProvider.getTimeline` reads the snapshot file (cheap JSON decode), builds 1 entry (plus maybe a couple future entries with relative-date labels refreshed), and returns it.
4. Widget's `getSnapshot`/`placeholder` return synthetic/last-known data so the widget gallery preview and initial render never block on disk I/O errors.

## 5. Implementation Plan

### Phase 0 — Groundwork (no visible feature yet)
1. Register/confirm the App Group ID with the Apple Developer account tied to this project's signing identity; add the App Group capability to the main app target's entitlements and provisioning.
2. Add `SharedContainer.swift` + `WidgetSnapshot.swift` to the `McFind` target only (no new target yet). Have `FileIndexer`/`IndexDatabase` write a snapshot on each debounce flush and on full-index completion. No UI changes.
3. Verify manually that the snapshot file appears at the App Group container path and updates as expected (unit test around `WidgetSnapshot` encode/decode; integration check via `IndexDatabaseTests.swift`-style test if feasible without a real container in CI — likely needs a protocol-abstracted container path for testability).

### Phase 1 — Widget extension skeleton
4. Add new `McFindWidget` target (Widget Extension template) to `McFind.xcodeproj`; wire up shared App Group entitlement on this target too.
5. Implement `Provider` reading `WidgetSnapshot` via `SharedContainer`; implement `placeholder`/`getSnapshot`/`getTimeline` with graceful "no data yet" state.
6. Implement `SmallWidgetView` (index stats only) — simplest slice, validates the whole pipeline end-to-end before investing in row layouts.
7. Ship as a hidden/internal build; manually add widget to Notification Center and confirm it reflects real indexing activity.

### Phase 2 — Medium/Large layouts + deep linking
8. Implement `MediumWidgetView`/`LargeWidgetView` file-row lists (icon via `NSWorkspace` computed in-widget-process from the path — cheap, no need to serialize icons in the snapshot).
9. Add `mcfind://` URL scheme to the main app's Info.plist / `McFindApp.swift`; implement `.onOpenURL` to focus search or reveal+select a specific path in `SearchViewModel`/`ContentView`/`TableView`.
10. Wire `widgetURL`/`Link` per-row in Medium/Large views to the deep link.

### Phase 3 — Configuration & polish
11. Add `AppIntent`-based `ConfigurationIntent` (source: Recently Modified vs Recently Added) per requirement W8; extend `WidgetSnapshot` to carry both lists (or recompute both cheaply — prefer storing both since it's small data).
12. Handle empty states (never indexed, indexing in progress, zero results) across all three sizes.
13. Add Dark Mode / accent color / Dynamic Type pass; verify against macOS widget size classes on Sonoma+ (matches app's existing macOS 14+ minimum).
14. Update `docs/FEATURES.md`, `docs/SPEC.md`, `README.md`, and `CHANGELOG.md`.

### Phase 4 — Testing & release
15. Unit tests for `WidgetSnapshot` codable round-trip and for the "which files go into recent lists" selection logic (pure function, testable without WidgetKit).
16. Manual QA matrix: fresh install (no index yet), mid-indexing, fully indexed, app force-quit while widget present, App Group container missing/corrupted snapshot (must not crash — fall back to placeholder).
17. Update `scripts/create-dmg.sh` / notarization pipeline (`CODE_SIGNING.md`, `DEPLOYMENT.md`) to include the new extension bundle; confirm both targets are signed with the same App Group entitlement and the same Developer ID.
18. Add to release notes; ship behind a version bump per existing `RELEASE_NOTES_vX.Y.Z.md` convention.

## 6. Risks / Watch-outs

- **Code signing**: adding a new target + App Group means the Developer ID provisioning must cover both bundle IDs (`com.ntufar.mcfind` and `com.ntufar.mcfind.widget` or similar) with the shared App Group — coordinate with whatever produces the notarized releases (`CODE_SIGNING.md`, `DEPLOYMENT.md`, GitHub Actions `macos.yml`/`release.yml`).
- **Main app is currently unsandboxed**: double check Apple's current App Review / notarization stance on mixing a sandboxed widget extension with a non-sandboxed host — this has been long-supported (share extensions/widgets on non-sandboxed hosts exist), but worth a quick spike before Phase 1 to avoid rework.
- **WAL/locking** if Option A (shared DB) is ever adopted instead of snapshotting — cross-process readers on WAL are supported by SQLite but add operational risk; Option B avoids this entirely.
- **Snapshot write frequency**: must piggyback on the existing FSEvents debounce (`FileMonitor.swift`) rather than introduce a second timer, to avoid extra disk churn.
- **WidgetKit reload budget**: macOS throttles `reloadTimelines`; don't call it more than once per debounce flush, and rely on timeline-based relative dates rather than forcing reloads for cosmetic freshness.

## 7. Effort Estimate (rough)

| Phase | Estimate |
|-------|----------|
| 0 — Groundwork (App Group, snapshot writer) | 0.5–1 day |
| 1 — Widget skeleton + Small size | 1 day |
| 2 — Medium/Large + deep linking | 1–1.5 days |
| 3 — Configuration & polish | 1 day |
| 4 — Testing, signing, release | 0.5–1 day |
| **Total** | **~4–5.5 days** |
