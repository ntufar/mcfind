# McFind — Improvement Ideas & New Feature Proposals

> Extensive brainstorm with technical specifications. Each item lists motivation, a concrete
> technical approach grounded in the current architecture (`IndexDatabase.swift`,
> `FileIndexer.swift`, `FileMonitor.swift`, `SearchViewModel.swift`, `TableView.swift`),
> priority, and a rough effort estimate.
>
> Status: proposal document — nothing here is committed. Items graduate into `SPEC.md`
> checkboxes when accepted.

---

## Table of Contents

1. [Search Engine](#1-search-engine)
2. [Indexing & Monitoring](#2-indexing--monitoring)
3. [User Interface & UX](#3-user-interface--ux)
4. [Power-User Features](#4-power-user-features)
5. [Automation & Integrations](#5-automation--integrations)
6. [Performance & Robustness](#6-performance--robustness)
7. [Distribution & Infrastructure](#7-distribution--infrastructure)
8. [Suggested Priority Matrix](#8-suggested-priority-matrix)

---

## 1. Search Engine

### 1.1 Replace `LIKE '%…%'` with a trigram/FTS5 index — **highest-impact perf change**

**Problem.** The current substring search (`name_normalized LIKE '%query%' OR path_normalized
LIKE '%query%'`) cannot use the B-tree indexes when the pattern has a leading wildcard — every
query is a full table scan of 500K+ rows. It's fast enough today only because SQLite scans are
cheap, but latency grows linearly with index size and burns CPU on every keystroke.

**Approach.** SQLite ships FTS5 with a built-in `trigram` tokenizer (SQLite ≥ 3.34; macOS 14
bundles ≥ 3.39) designed exactly for substring matching:

```sql
CREATE VIRTUAL TABLE files_fts USING fts5(
    name, path,
    content='files', content_rowid='rowid',
    tokenize="trigram case_sensitive 0"
);
-- keep in sync via triggers or in applyChanges():
CREATE TRIGGER files_ai AFTER INSERT ON files BEGIN
    INSERT INTO files_fts(rowid, name, path) VALUES (new.rowid, new.name, new.path);
END;
-- + AFTER DELETE / AFTER UPDATE triggers
```

Query becomes `SELECT ... FROM files WHERE rowid IN (SELECT rowid FROM files_fts WHERE
files_fts MATCH ?)` with the query wrapped as a trigram string. Queries shorter than 3 chars
fall back to the existing `LIKE` path (trigram needs ≥3 chars).

- Keep the existing ranking `ORDER BY` (exact > prefix > substring > path) on the outer query.
- External-content FTS5 (`content='files'`) avoids duplicating name/path text; index overhead
  is roughly 2–3× the text size, i.e. tens of MB for 500K files — acceptable.
- Migration: schema version bump, build FTS table in background on first launch after update
  (reuse the existing progress UI), searchable via `LIKE` fallback until built.
- Note the trigram tokenizer folds ASCII case only; keep feeding it the existing
  `name_normalized`/`path_normalized` columns so Unicode case-insensitivity (Greek, Russian…)
  is preserved.

**Effort:** 2–3 days. **Priority:** High.

---

### 1.2 File content search (full-text) — the biggest missing feature vs. competitors

**Problem.** `SPEC.md` known limitation: "No file content search." This is the #1 gap vs.
Spotlight and the most requested class of feature for search tools.

**Approach.** Separate, opt-in content index. Never block or bloat the filename index.

- **Storage:** second SQLite database `content.db` (same App Support dir) with FTS5
  (`porter unicode61` tokenizer for prose; `trigram` optional mode for code):

  ```sql
  CREATE VIRTUAL TABLE content_fts USING fts5(path UNINDEXED, body, tokenize='porter unicode61');
  CREATE TABLE content_meta (path TEXT PRIMARY KEY, mtime REAL, size INTEGER, sha1 TEXT);
  ```

- **Extraction:** plain-text types (`public.plain-text`, source code, md, json, csv, xml, log)
  read directly with size cap (default 2 MB/file, configurable). Rich types (pdf, docx, rtf,
  html) via `NSAttributedString(url:options:)` and `PDFDocument.string` (PDFKit) — both are
  system frameworks, no third-party deps.
- **Pipeline:** piggyback on the existing FSEvents 5-second debounce flush: after
  `applyChanges(inserts:deletes:)`, enqueue changed paths whose UTType is in the content
  allowlist onto a low-QoS (`.background`) extraction queue. `content_meta.mtime` guards
  against re-extracting unchanged files.
- **Query syntax:** `content:invoice` or a "Search file contents" toggle in the UI; results
  merged under a section header, ranked by FTS5 `bm25()`.
- **Settings:** master toggle (default OFF), per-UTType toggles, max file size, excluded paths
  reuse `IndexSettings` hierarchy. Show content DB size in settings with a "Delete content
  index" button.
- **Snippets:** FTS5 `snippet(content_fts, 1, '«', '»', '…', 12)` for the preview pane / result
  subtitle.

**Effort:** 1.5–2 weeks for v1 (plain text + pdf). **Priority:** High.

---

### 1.3 Structured query language (filters as first-class syntax)

**Problem.** Size filters exist as a UI dropdown; date and type filters are unimplemented.
Power users of Everything expect composable query syntax.

**Approach.** A small tokenizer in `SearchViewModel` that strips `key:value` tokens before the
text match and compiles them to SQL `WHERE` clauses:

| Token | Example | SQL |
|---|---|---|
| `ext:` | `ext:pdf,docx` | `file_extension IN (?,?)` (needs new indexed column, see 2.2) |
| `kind:` | `kind:image` | `kind = ?` (UTType-derived category column, see 1.4) |
| `size:` | `size:>10mb size:<1gb` | `size > ? AND size < ?` |
| `dm:` (date modified) | `dm:today`, `dm:>2026-01-01`, `dm:last7d` | `modified_date >= ?` |
| `path:` / `inpath:` | `path:Projects` | restrict `LIKE` to path only |
| `is:` | `is:dir`, `is:file` | `is_directory = 1/0` |
| `tag:` | `tag:Important` | joins tags table (see 4.3) |
| negation | `-ext:log`, `!node_modules` | `NOT (…)` |

Grammar: whitespace-separated tokens; unrecognized tokens are plain text terms (AND-ed).
Quoted strings `"annual report"` are exact phrases. This is deliberately Everything-compatible
where it's cheap to be (`size:`, `ext:`, `dm:`).

- Parser is a pure function `parseQuery(String) -> ParsedQuery { textTerms, predicates }` —
  unit-testable with zero UI/DB dependencies.
- Autocomplete: when the user types a known prefix (`ext:`), show a completion menu (NSMenu
  under the search field) with common values.

**Effort:** 3–4 days incl. tests. **Priority:** High (unlocks 1.4, date filters, and makes
the existing size filter composable).

---

### 1.4 File type / kind filters (images, documents, code, …)

**Approach.** Add a `kind INTEGER` column at index time, derived once from the extension via a
static `[String: Kind]` lookup (not `UTType` per file during indexing — too slow at 20K
files/s; build the table from UTType conformance once at launch):

```swift
enum FileKind: Int { case folder, image, video, audio, document, archive, code, app, other }
```

```sql
ALTER TABLE files ADD COLUMN kind INTEGER NOT NULL DEFAULT 0;
CREATE INDEX idx_kind ON files(kind);
```

UI: segmented filter chips under the search bar (`All | Folders | Images | Docs | Code | …`),
mirroring `kind:` query tokens. Backfill migration runs in background using the same
UPDATE-in-batches pattern as the normalized-column migration already shipped.

**Effort:** 1–2 days. **Priority:** High (already an unchecked SPEC item).

---

### 1.5 Date filters

Covered by `dm:` tokens (1.3) plus a UI dropdown next to the size filter: Today / Yesterday /
Last 7 days / Last 30 days / This year / Custom range (two `DatePicker`s in a popover).
`modified_date` is already stored as REAL (epoch); add `CREATE INDEX idx_modified ON
files(modified_date)` so date-only queries (empty text) don't scan.

**Effort:** 1 day on top of 1.3. **Priority:** High (unchecked SPEC item).

---

### 1.6 Search history + saved searches (smart folders)

- **History:** ring buffer of last 100 committed queries (a query "commits" when the user
  opens/reveals a result or presses Enter — not every keystroke). Store in a small
  `search_history` table (query TEXT, last_used REAL, use_count INTEGER) in the index DB.
  UI: dropdown under the search field (`NSMenu` on focus / ⌘Y), fuzzy-matched as you type.
- **Saved searches:** named queries persisted as JSON in UserDefaults
  (`[{name, query, createdAt}]`), shown in a sidebar section or a bookmarks-style menu.
  Because filters are query syntax (1.3), a saved search is just a string — no extra model.
- Privacy: "Clear search history" button in settings; history excluded from any future
  snapshot/export features.

**Effort:** 2–3 days. **Priority:** Medium.

---

### 1.7 Frecency ranking (learn from opens)

**Problem.** Ranking is purely lexical. The file you open every day should outrank a
same-named file you never touch.

**Approach.** `access_log(path TEXT PRIMARY KEY, open_count INTEGER, last_opened REAL)`
updated whenever the user opens/reveals a result. Ranking adds a bounded boost term:

```
score = lexical_rank_bucket * 1000 + min(open_count, 50) * frecency_decay(last_opened)
```

computed in the ORDER BY via a join (LEFT JOIN access_log). Cap the table at ~2000 rows
(evict lowest score). Toggle in settings ("Rank frequently opened files higher", default ON).

**Effort:** 1–2 days. **Priority:** Medium. Cheap, big perceived-quality win.

---

### 1.8 Remove the 1000-result cap via lazy paging

**Problem.** Hard `LIMIT 1000` silently hides results.

**Approach.** `TableView` already wraps `NSTableView`, which virtualizes rows. Two options:

- **Option A (simple):** raise limit to 10K and load `FileItem`s lazily — store only
  (rowid, name, path) tuples from SQL, resolve icon/size lazily in
  `tableView(_:viewFor:row:)` (icons are already resolved per-row today).
- **Option B (correct):** keyset pagination — fetch 500 rows, and when
  `NSTableView` scrolls near the end (`NSScrollView` bounds-change notification), fetch the
  next page `WHERE (rank, rowid) > (lastRank, lastRowid)`. Show "N+ results" in the status
  bar until the true count is known (background `COUNT(*)`).

Recommend A first (an afternoon), B only if profiling shows memory pressure.

**Effort:** 0.5–2 days. **Priority:** Medium.

---

### 1.9 Fuzzy / typo-tolerant matching (optional mode)

For queries with 0 results, run a second-chance pass: split the query into trigram FTS query
with `OR` semantics, rank by number of matched trigrams (approximates edit distance), show
under a "Did you mean…" divider. Zero new storage if 1.1 ships. Keep it out of the hot path —
only fires on empty result sets.

**Effort:** 1–2 days after 1.1. **Priority:** Low.

---

## 2. Indexing & Monitoring

### 2.1 Persist FSEvents `lastEventId` — catch changes made while the app was closed

**Problem (known limitation).** Changes made while McFind isn't running are only caught by the
next full/incremental reindex. FSEvents solves this natively and the app doesn't use it yet.

**Approach.** FSEvents streams accept a `sinceWhen` event ID:

1. On every debounce flush, store `FSEventStreamGetLatestEventId(stream)` into a `meta` table
   in the index DB (single row, `key='last_event_id'`).
2. On launch, create the stream with `sinceWhen: savedEventId` instead of
   `kFSEventStreamEventIdSinceNow`. The kernel replays every change since that ID — the app
   receives the same callbacks as if it had been running, and the existing buffered-write path
   handles them unchanged.
3. Guard rails: if the replayed history was purged (callback delivers
   `kFSEventStreamEventFlagHistoryDone` never arriving / `kFSEventStreamEventFlagMustScanSubDirs`
   or the event ID is older than the volume's UUID-scoped journal), fall back to the existing
   incremental scan. Also store the volume UUID; if it changes, full rescan.

This can *replace* most launch-time incremental scans → dramatically faster startup with a
fresher index.

**Effort:** 2 days incl. edge cases. **Priority:** High — best robustness/perf ratio in
this document.

---

### 2.2 File-level FSEvents for in-place content modifications

**Problem (known limitation).** "Files content-modified in-place (no directory mtime change)
are only caught on next full reindex."

**Approach.** Recreate the stream with `kFSEventStreamCreateFlagFileEvents`. Callbacks then
deliver per-file paths with `ItemModified`/`ItemRenamed`/`ItemRemoved` flags instead of
per-directory hints, which (a) fixes in-place modification staleness and (b) shrinks work per
event — no directory re-stat needed for single-file changes. The existing 5-second buffer
keeps write amplification identical. Measure memory/CPU first (file-level events are chattier);
keep the flag behind a hidden default (`defaults write com.ntufar.mcfind FileLevelFSEvents`)
for one release.

Also add `file_extension TEXT` as a real indexed column while touching the schema (currently
derived in `FileItem`), enabling `ext:` filters (1.3) without `LIKE '%.pdf'` hacks.

**Effort:** 2–3 days. **Priority:** High.

---

### 2.3 Multiple index roots & external drives

**Problem.** Home-directory-only is the top line of "Known Limitations" and the biggest
functional gap vs. Everything.

**Approach.**

- **Schema:** add a `volumes` table and scope files to a root:

  ```sql
  CREATE TABLE roots (
      id INTEGER PRIMARY KEY,
      path TEXT NOT NULL,           -- e.g. /Volumes/Media or /Users/ntufar
      volume_uuid TEXT,             -- URLResourceValues.volumeUUIDString
      is_removable INTEGER,
      last_event_id INTEGER,        -- per-root FSEvents resume point (see 2.1)
      enabled INTEGER NOT NULL DEFAULT 1
  );
  ALTER TABLE files ADD COLUMN root_id INTEGER NOT NULL DEFAULT 1;
  ```

- **FSEvents:** one stream per root (streams take an array of paths but per-root streams make
  eject handling trivial — invalidate just that stream).
- **Mount/unmount:** observe `NSWorkspace.didMountNotification` / `didUnmountNotification`.
  On unmount, keep the rows (searchable, shown greyed-out with an "offline" badge — Everything
  behaves this way and users love it) or purge, per a per-root setting. On remount, match by
  `volume_uuid` (mount point paths change), rewrite `roots.path`, run incremental scan.
- **Settings UI:** "Indexed Locations" list with +/− (NSOpenPanel folder picker), per-root
  enable toggle, per-root file count and DB share.
- **Search:** unchanged — `path` remains absolute. Offline results get `isOffline` in
  `FileItem` (root lookup), disabling Open/QuickLook but keeping Copy Path.

**Effort:** 1–1.5 weeks. **Priority:** High (already a SPEC unchecked item).

---

### 2.4 User-customizable skip patterns (gitignore-style)

**Approach.** Settings text list of glob patterns, one per line, matched with `fnmatch()` (or
translate to regex once at index start). Two scopes: *directory prune* patterns (skip
traversal — like today's hardcoded list) and *file ignore* patterns. The built-in skip list
becomes the default content, individually toggleable, so users can *un-skip* e.g.
`node_modules` if they want. Persist in UserDefaults as `[String]`; `FileIndexer` compiles
them to a `[NSRegularExpression]` (or simple suffix/name sets for the fast common cases) at
scan start.

**Effort:** 2 days. **Priority:** Medium (unchecked SPEC item).

---

### 2.5 Index statistics dashboard

Settings tab or window showing: total files/dirs, DB size on disk, last full index time &
duration, files/sec of last scan, top 10 largest indexed directories (by descendant count —
one `GROUP BY` over path prefixes), FSEvents flushes in last hour, freelist page ratio (data
already computed for the VACUUM heuristic). All queries run on the existing DB queue and are
read-only. Charts optional — start with a plain grid; Swift Charts if it grows.

**Effort:** 2 days. **Priority:** Low-Medium (great debugging/support tool).

---

### 2.6 Export / import index & settings profiles

- **Index export:** `VACUUM INTO '/path/backup.db'` — SQLite does consistent online backup in
  one statement. Import = validate schema version + replace file + relaunch indexer in
  verify mode.
- **Settings profiles:** serialize `IndexSettings` + skip patterns + UI prefs to a JSON file
  (`.mcfindsettings`), with an importer that diff-previews changes before applying.

**Effort:** 1–2 days. **Priority:** Low.

---

## 3. User Interface & UX

### 3.1 Menu bar quick search (Spotlight-style panel) — **flagship UX feature**

**Problem.** Search tools live or die by "invoke instantly from anywhere." Today McFind is a
regular window app.

**Approach.**

- `NSStatusItem` with the app icon; click opens a borderless floating `NSPanel`
  (`.nonactivatingPanel`, `level = .floating`, `collectionBehavior =
  [.canJoinAllSpaces, .fullScreenAuxiliary]`) hosting a compact SwiftUI search view (reuses
  `SearchViewModel` — it's already UI-agnostic).
- **Global hotkey** (default ⌥Space, customizable): `RegisterEventHotKey` (Carbon — still the
  sanctioned API, no Accessibility permission needed) or the tiny `KeyboardShortcuts` SPM
  package (MIT, by Sindre Sorhus) which wraps it with a settings recorder UI.
- Panel behavior: opens centered on the active screen, search field focused, Esc closes,
  Enter opens top hit, ⌘Enter reveals in Finder, ↑/↓ navigate, ⌘O opens the full window with
  the query carried over.
- "Run as menu-bar-only app" mode: `NSApp.setActivationPolicy(.accessory)` toggle in settings
  (no Dock icon; the main window still openable from the panel).
- Results limited to top 8 in the panel for speed; same DB queue, same ranked query.

**Effort:** 3–5 days. **Priority:** High — likely the single most user-visible improvement.

### 3.2 Launch at login

One-liner on macOS 13+: `SMAppService.mainApp.register()` / `.unregister()`, toggle in
settings, reflect actual status via `SMAppService.mainApp.status`. Pairs with 3.1 (start as
accessory in menu bar).

**Effort:** 0.5 day. **Priority:** High (trivial + expected of this app category).

### 3.3 Preview pane

Right-hand split (`HSplitView` / `NSSplitViewController`) with:

- `QLPreviewView` (Quartz framework — embeddable Quick Look, unlike the Space-key panel) for
  live preview of the selected file.
- Metadata section: full path (click-to-copy, middle-truncated), size, created/modified dates
  (`URLResourceValues`), UTType description, macOS tags, and — if content indexing (1.2) is
  on — the matching text snippet.
- Toggle: ⌘⇧P and a toolbar button; width persisted to UserDefaults.
- Debounce selection→preview by ~150 ms so arrow-key scrubbing doesn't thrash Quick Look.

**Effort:** 2–3 days. **Priority:** Medium-High (unchecked SPEC item).

### 3.4 Sortable columns

`NSTableView` already supports `sortDescriptorPrototype` per column. Clicking Name/Size/
Modified re-sorts by re-issuing the SQL with a different `ORDER BY` (never sort 1000+
`FileItem`s in memory — let SQLite do it; `idx_modified` from 1.5 and an `idx_size` make it
free). Default remains relevance; a "Relevance" state returns after editing the query.

**Effort:** 1 day. **Priority:** Medium.

### 3.5 Thumbnail/grid view for images & media

Alternate view mode (⌘1 list / ⌘2 grid) using `NSCollectionView`; thumbnails via
`QLThumbnailGenerator.shared.generateBestRepresentation` with an `NSCache<NSString, NSImage>`
(cost-limited ~200 MB) and cancellation of off-screen requests. Auto-suggest grid when
`kind:image` filter is active.

**Effort:** 3–4 days. **Priority:** Low-Medium.

### 3.6 Customizable keyboard shortcuts

Settings table of actions (Open, Reveal, Copy Path, Rename, Trash, Quick Look, Re-index…)
with recorder controls (same `KeyboardShortcuts` package as 3.1 handles both global and
in-app if adopted; otherwise store `(keyEquivalent, modifierMask)` in UserDefaults and apply
in `KeyEventHandling.swift` + menu items).

**Effort:** 2 days. **Priority:** Low (unchecked SPEC item).

### 3.7 Polish backlog (small, batchable)

- **Dark mode refinements:** audit alternating-row and status-bar colors against
  `NSColor.controlAlternatingRowBackgroundColors` / semantic colors instead of literals.
- **Path bar** at the bottom (Finder-style clickable breadcrumb of the selected file).
- **Copy as file URL / POSIX path / tilde-abbreviated** submenu.
- **"Open With…" submenu** in the context menu (`NSWorkspace.urlsForApplications(toOpen:)`).
- **Drag out of the app with multi-select count badge** (already multi-select; badge is
  `NSDraggingItem` imageComponents).
- **Undo for rename and trash** (`NSFileManager` returns the resulting URL for trash —
  `UndoManager` restores by moving back).
- **VoiceOver / accessibility pass:** row accessibility labels = "name, folder, modified date".

**Effort:** ~0.5 day each. **Priority:** Rolling.

---

## 4. Power-User Features

### 4.1 Duplicate file finder

Three-stage pipeline over the *existing index* (no new scan needed for stage 1):

1. **Size grouping:** `SELECT size FROM files WHERE is_directory=0 GROUP BY size HAVING
   COUNT(*)>1 AND size > 0` — instant, index-only.
2. **Partial hash:** for each candidate group, hash first+last 64 KB
   (`CryptoKit.SHA256`), on the `.utility` queue with progress UI.
3. **Full hash:** only for partial-hash collisions.

Results UI: grouped outline view, "keep newest / keep in folder X" batch selection helpers,
Move to Trash (never hard delete). Store hashes in `content_meta` (shared with 1.2) keyed by
(path, mtime, size) so re-runs are incremental.

**Effort:** 4–5 days. **Priority:** Medium (long-standing FEATURES.md wish).

### 4.2 Empty folder detection

Pure SQL over the existing index — a directory is empty iff no rows have it as a path prefix:

```sql
SELECT d.path FROM files d
WHERE d.is_directory = 1
AND NOT EXISTS (SELECT 1 FROM files f WHERE f.path GLOB d.path || '/*' LIMIT 1);
```

(With 2.2's extension column and a `path` index this is tolerable; if slow, maintain a
`child_count` column updated in `applyChanges`.) UI: a tool window listing them with
batch-trash. Verify against the live filesystem before showing (index may lag ≤5 s).

**Effort:** 1–2 days. **Priority:** Low-Medium.

### 4.3 macOS tags — read, search, write

- **Read at index time:** `URLResourceValues.tagNames` during scan; store in a join table
  `tags(path TEXT, tag TEXT)` with an index on `tag`. Adds one `getResourceValue` call per
  file — benchmark; if it drops indexing below ~10K files/s, fetch tags lazily only for
  results + maintain via FSEvents (tag changes touch the file's extended attributes and emit
  events with `FileEvents` flag from 2.2).
- **Search:** `tag:Important` token (1.3); tag chips shown in the results row / preview pane.
- **Write:** context-menu "Tags…" submenu mirroring Finder's colors
  (`try url.setResourceValues(...)`).

**Effort:** 3 days. **Priority:** Medium (unchecked SPEC item).

### 4.4 Bookmarks / pins

`pins(path TEXT PRIMARY KEY, pinned_at REAL, sort_order INTEGER)` table; ⌘D toggles pin on
selection; pinned section shows above results when the search field is empty (turns the empty
state into a launcher). Also feeds the widget's "Pinned Files" source
(`WIDGET_SPEC.md` §3.3 open question — this resolves it).

**Effort:** 1–2 days. **Priority:** Medium.

### 4.5 Batch rename

For multi-selections: Finder-style sheet with Replace Text / Add Text / Sequence formats,
live preview table (old → new), conflict detection (target exists / duplicate targets) before
enabling Apply. Runs on a background queue, updates the index rows in the same transaction
pattern as `applyChanges` (don't wait for the FSEvents round-trip — apply optimistically, let
events reconcile).

**Effort:** 3 days. **Priority:** Low-Medium.

### 4.6 Export results

Toolbar/menu "Export Results…" → CSV / JSON / plain path list of the *current* result set
(re-run the query without `LIMIT` streaming straight to `FileHandle`, never materializing in
RAM). CSV columns: path, name, size, modified ISO-8601, kind.

**Effort:** 1 day. **Priority:** Low.

---

## 5. Automation & Integrations

### 5.1 `mcfind` command-line tool

Ship a small CLI in the app bundle (`McFind.app/Contents/MacOS/mcfind` + settings button that
symlinks it into `/usr/local/bin`), opening the index **read-only**
(`SQLITE_OPEN_READONLY`, safe under WAL alongside the app as sole writer — same argument as
`WIDGET_SPEC.md` Option A):

```
mcfind [query] [--ext pdf] [--kind image] [--limit N] [--json|--print0|--paths]
```

`--print0` composes with `xargs -0`. Shares the query parser (1.3) via a small internal
SwiftPM package (`McFindCore`) extracted from the app target — which is also the right
long-term home for `IndexDatabase` + parser + ranking, making them testable without Xcode UI
targets.

**Effort:** 3–4 days (incl. the `McFindCore` extraction, which pays for itself in tests).
**Priority:** Medium-High for developer audience.

### 5.2 MCP server — expose search to AI agents

A natural fit given the name. A `mcfind mcp` subcommand of the CLI (5.1) speaking MCP over
stdio, exposing tools:

- `search(query, limit)` → ranked results with paths/sizes/dates (same parser & ranking)
- `stats()` → index counts, last index time

Read-only DB access, same binary, ~200 lines with the Swift MCP SDK (or hand-rolled JSON-RPC
— the stdio protocol is small). Lets Claude Code / any MCP client do instant local file
lookup instead of `find`/`mdfind` scans. Document a sample `.mcp.json` snippet in SETUP.md.

**Effort:** 2 days on top of 5.1. **Priority:** Medium — high differentiation, low cost.

### 5.3 App Intents (Shortcuts + Spotlight)

`AppIntent` "Search McFind" (parameter: query; result: file entities) → usable from
Shortcuts, Spotlight, and eventually Apple Intelligence surfaces. Also `OpenIntent` on a
`FileEntity` to reveal in app. macOS 14 target already supports the modern App Intents stack.

**Effort:** 2–3 days. **Priority:** Low-Medium.

### 5.4 Services menu & Finder round-trip

- **Services:** "Search in McFind" service (NSServices Info.plist entry) — select text
  anywhere → ⇧⌘ service → opens McFind with the query.
- **Reveal counterpart:** `mcfind://search?q=…` URL scheme is already specced for the widget
  (`WIDGET_SPEC.md` §4.2.5) — implement it once, and the widget, CLI (`mcfind --open`),
  Services, and App Intents all reuse it.

**Effort:** 1 day. **Priority:** Low.

---

## 6. Performance & Robustness

### 6.1 Test suite & CI enforcement

The repo has CI for builds but the docs list only a *manual* testing checklist. Highest-value
targets, in order:

1. **`IndexDatabase` unit tests** (in-memory `:memory:` or temp-dir DB): insert/search/
   applyChanges/migration paths, Unicode normalization cases (Greek/Russian examples from
   SPEC), ranking order assertions.
2. **Query parser tests** (pure function once 1.3 lands).
3. **`FileIndexer` integration test:** build a fixture tree in `NSTemporaryDirectory()`,
   index it, assert counts and skip-list behavior; mutate files, pump FSEvents (or call the
   buffer-flush directly), assert index converges.
4. **Performance regression test:** `XCTest.measure` on search latency against a generated
   100K-row DB; fail CI on >2× baseline.

Add `xcodebuild test` to `macos.yml`. Extracting `McFindCore` (5.1) makes 1–2 runnable via
`swift test` without a Mac UI session.

**Effort:** 3–5 days initial. **Priority:** High — prerequisite for confidently landing 1.1,
2.1, 2.3.

### 6.2 Schema versioning & integrity self-healing

Formalize migrations: `PRAGMA user_version` gate + ordered migration list (the normalized-
column migration becomes migration #1). On launch, run `PRAGMA quick_check` (fast) — on
corruption, rename the DB aside and trigger a full reindex with a user notification instead
of crashing or silently missing results. Log migration/check timings.

**Effort:** 1–2 days. **Priority:** Medium-High.

### 6.3 Indexing throughput

- Replace per-file `FileManager` attribute calls with
  `FileManager.enumerator(at:includingPropertiesForKeys:)` pre-fetching
  (`.isDirectoryKey, .fileSizeKey, .contentModificationDateKey`) — one stat per file instead
  of several (verify current code; if already done, profile with Instruments' File Activity).
- Consider `fts_content`-style delayed indexing: insert rows first, build FTS/normalized
  columns in a second pass so first-launch searchability arrives sooner.
- `PRAGMA mmap_size = 268435456` for read path; benchmark before adopting.

**Effort:** 1–3 days investigation-led. **Priority:** Medium.

### 6.4 Memory & energy audit

- Instruments run during: cold index of 500K files, 1-hour idle with FSEvents churn
  (simulated with a script touching files), rapid-typing search session. Publish numbers in
  FEATURES.md "Performance Characteristics" (they're currently estimates).
- Adopt `ProcessInfo.thermalState` / low-power awareness: pause background content extraction
  (1.2) and VACUUM when on battery + low power mode.

**Effort:** 2 days. **Priority:** Medium.

### 6.5 Crash & error reporting (opt-in)

Local-first: install an `NSSetUncaughtExceptionHandler` + signal handler writing a report to
`~/Library/Logs/McFind/`, and a "Help → Report a Problem" that opens a prefilled GitHub issue
URL with the last report + app/OS version attached (user reviews before sending — privacy
preserved, no third-party SDK, no server).

**Effort:** 1 day. **Priority:** Medium.

---

## 7. Distribution & Infrastructure

### 7.1 Notarization + Developer ID signing (unblocks everything else)

Currently ad-hoc signed (Gatekeeper friction: right-click-open dance for every user).
`WIDGET_SPEC.md` already documents that the widget is blocked on Apple Developer Program
membership — the same membership unblocks: notarized DMG (`notarytool submit --wait` step in
`release.yml`, credentials via GitHub secrets), the widget, App Groups, iCloud-anything, and
eventual App Store. This is the single infrastructure decision gating the most items.

**Effort:** 1–2 days of pipeline work once the account exists. **Priority:** High.

### 7.2 Sparkle auto-updates

Standard for non-App-Store macOS apps: Sparkle 2 via SPM, `SUFeedURL` pointing at an
`appcast.xml` generated in `release.yml` (`generate_appcast` against the GitHub Releases DMG),
EdDSA key in CI secrets. Settings: "Automatically check for updates" toggle. Requires 7.1
(Sparkle + unsigned apps is a bad combo).

**Effort:** 1–2 days. **Priority:** High (users on 0.2.x never learn 0.3.x exists).

### 7.3 Homebrew cask

`brew install --cask mcfind` — a cask PR to homebrew/cask (needs a stable versioned DMG URL,
already provided by GitHub Releases; notarization strongly preferred). Add a `bump-cask-pr`
step to the release workflow afterward.

**Effort:** 0.5 day. **Priority:** Medium.

### 7.4 Localization

Wrap UI strings in `String(localized:)` / `LocalizedStringKey` now (cheap while the surface is
small); ship a String Catalog (`.xcstrings`). Given the Unicode-search care already invested
(Greek, Romanian, Russian), Romanian/Russian/Turkish translations are on-brand first targets.

**Effort:** 1 day plumbing + per-language. **Priority:** Low.

### 7.5 DocC + contribution guide

- DocC catalog for `McFindCore` (once extracted, 5.1) published to GitHub Pages next to the
  existing site.
- `CONTRIBUTING.md`: build steps (condensed from DEVELOPMENT.md), CHANGELOG rule (from
  `.claude/rules.md`), test expectations (6.1), release checklist link.

**Effort:** 1 day. **Priority:** Low (both are unchecked SPEC items).

---

## 8. Suggested Priority Matrix

| # | Item | Impact | Effort | Notes |
|---|------|--------|--------|-------|
| 3.1 | Menu bar quick search + global hotkey | ★★★★★ | 3–5 d | Flagship UX |
| 2.1 | FSEvents `lastEventId` persistence | ★★★★★ | 2 d | Fresh index at launch, cheap |
| 7.1 | Notarization / Developer ID | ★★★★★ | 1–2 d | Gates widget, Sparkle, trust |
| 1.1 | FTS5 trigram search | ★★★★ | 2–3 d | Scales search past 1M files |
| 6.1 | Test suite + CI tests | ★★★★ | 3–5 d | Prerequisite for the rest |
| 1.3 | Query language (`ext:` `dm:` `size:`…) | ★★★★ | 3–4 d | Unlocks 1.4/1.5/4.3 |
| 1.4 + 1.5 | Kind & date filters | ★★★★ | 2–3 d | Existing SPEC items |
| 3.2 | Launch at login | ★★★ | 0.5 d | Trivial |
| 7.2 | Sparkle auto-update | ★★★★ | 1–2 d | After 7.1 |
| 2.3 | Multiple roots / external drives | ★★★★ | 1–1.5 w | Top known limitation |
| 1.2 | Content search (FTS5) | ★★★★ | 1.5–2 w | Biggest new capability |
| 2.2 | File-level FSEvents | ★★★ | 2–3 d | Fixes staleness limitation |
| 3.3 | Preview pane | ★★★ | 2–3 d | |
| 5.1 + 5.2 | CLI + MCP server | ★★★ | 5–6 d | Differentiator for devs |
| 1.7 | Frecency ranking | ★★★ | 1–2 d | Perceived quality |
| 4.1 | Duplicate finder | ★★★ | 4–5 d | |
| 1.6 | History + saved searches | ★★ | 2–3 d | |
| 4.3 | macOS tags | ★★ | 3 d | |
| 4.4 | Pins/bookmarks | ★★ | 1–2 d | Also feeds widget spec |
| Rest | §3.7 polish, exports, localization… | ★–★★ | rolling | Batch into releases |

**Suggested release theming:**

- **v0.4 — "Always at hand":** 3.1 menu bar search, 3.2 launch at login, 2.1 event-ID resume,
  7.1 notarization, 7.2 Sparkle.
- **v0.5 — "Filters":** 1.3 query language, 1.4 kind, 1.5 dates, 1.6 history, 3.4 sorting,
  6.1 tests.
- **v0.6 — "Everywhere":** 2.3 multiple roots/external drives, 2.2 file-level events,
  2.4 custom skip patterns.
- **v0.7 — "Inside files":** 1.2 content search, 3.3 preview pane, 1.1 trigram (if not
  earlier).
- **v0.8 — "Power tools":** 4.1 duplicates, 4.3 tags, 5.1/5.2 CLI + MCP, widget
  (per `WIDGET_SPEC.md`, unblocked by 7.1).
