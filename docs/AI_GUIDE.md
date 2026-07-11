# AI Assistant Guide

**For:** Claude, Copilot, Cursor, or any AI coding assistant working on this codebase.

This is a dense, opinionated guide. Read it fully before making changes.

---

## The One Rule

**Don't break the build or the analyzer.** CI gates: zero analyzer errors, zero warnings, clean format. If you can't fix a warning you introduce, dial the rule down in `analysis_options.yaml` rather than letting it ship — and mention the rule change in the PR.

## Before You Change Anything

1. **Read the file you're editing.** Understand its conventions, imports, and patterns.
2. **Read neighboring files.** This codebase has strong internal consistency — match it.
3. **Check for existing primitives.** Especially for focus/navigation (see `lib/focus/`, `lib/widgets/focusable_*.dart`). Don't reinvent.
4. **Check `CLAUDE.md`** for architecture context — it's the authoritative source for DI wiring, server model, playback, offline, and TV navigation patterns.

## Code Generation

Three codegen systems run on this project. After editing relevant files, you **must** regenerate:

| You edit... | Run this |
|-------------|----------|
| Any `@JsonSerializable` model | `dart run build_runner build --delete-conflicting-outputs` |
| Any `drift` table or `app_database.dart` | `dart run build_runner build --delete-conflicting-outputs` |
| Any `lib/i18n/*.i18n.json` | `dart run slang` |
| `pubspec.yaml` | `flutter pub get` (then build_runner if needed) |

**Never hand-edit `*.g.dart` files.** They're excluded from analyzer and format checks. Regenerate from sources.

After running `build_runner`, check `lib/i18n/strings.g.dart` — it gets a new timestamp every run. Only commit it if the content actually changed.

## Branch Model

- **`main`** is the only long-lived branch. No `develop`.
- Feature branches → PR → `main`. Branch naming: `feat/*`, `fix/*`, `chore/*`, `docs/*`.
- The `upstream` remote points to `dkmcgowan/finzy`. The `origin` remote points to the fork (`ric-dg/finzy`).
- PRs are the unit of review. Each PR should be one logical change.

## Commit Style

Conventional commits: `feat:`, `fix:`, `chore:`, `docs:`, `refactor:`, `test:`. Keep subject under 72 chars. Body explains **why**, not **what**.

## Common Mistakes to Avoid

### 1. Bulk reformatting
Local `dart format` may be stricter than CI (CI uses Flutter-pinned Dart on Linux). Pre-existing format diffs exist across the tree — CI tolerates them. **Only format files you actually edited.** A "small" PR with 1000+ line diff is almost always formatter noise.

### 2. Breaking D-pad navigation
Android TV is a first-class target. Every focusable widget, dialog, list, grid, or tab strip must work with D-pad. Reference patterns:
- **Dialogs:** `lib/screens/libraries/filters_bottom_sheet.dart`
- **Detail pages:** `lib/screens/hub_detail_screen.dart`, `FocusableDetailScreenMixin`
- **Tabbed screens:** `lib/screens/libraries/libraries_screen.dart`, `TabNavigationMixin`
- **Primitives:** `lib/focus/dpad_navigator.dart`, `focus_memory_tracker.dart`, `focusable_wrapper.dart`

### 3. Adding providers out of order
`MultiProvider` in `main.dart` encodes dependency order via `ChangeNotifierProxyProvider` / `ProxyProvider2`. Adding a provider in the wrong position silently breaks wiring. Check the existing order before inserting.

### 4. Ignoring platform guards
Desktop-only code (`window_manager`, `MacOSTitlebarService`, `GamepadService`) is guarded by `Platform.is*` in `main()`. Don't remove these guards. Android TV cold start delays network work by 2 seconds — mirror this pattern if adding resume-time network work.

### 5. Not testing offline mode
Downloads use temp→final file movement. Cancellation deletes the temp file. SAF mode (Android) writes to `content://` URIs directly. Always consider: what happens if the network drops mid-operation?

## File Conventions

| Location | Contains |
|----------|----------|
| `lib/main.dart` | Composition root, DI wiring, `MultiProvider` tree |
| `lib/screens/` | Top-level routes. `main_screen.dart` is the post-auth shell |
| `lib/screens/*/tabs/` | Tab content within a screen |
| `lib/widgets/` | Shared widgets. `focusable_*.dart` for D-pad-aware versions |
| `lib/services/` | Business logic, API clients, persistence |
| `lib/providers/` | `ChangeNotifier`s exposed to UI via `provider` |
| `lib/database/` | Drift (SQLite) schema and migrations |
| `lib/mpv/` | Player abstraction (libmpv desktop, ExoPlayer Android) |
| `lib/focus/` | Focus management, D-pad navigation, input mode tracking |
| `lib/i18n/` | slang JSON sources + generated `.g.dart` files |
| `lib/models/` | Data models with `@JsonSerializable` |
| `lib/theme/` | Design tokens, theme configuration |
| `lib/constants/` | Static constants, API config |
| `lib/utils/` | Pure utility functions |
| `lib/mixins/` | Shared UI mixins (tab navigation, grid focus, etc.) |
| `docs/` | Design docs, plans, release notes |
| `milestones/` | Checkpoint files for in-progress work |
| `scripts/` | Build, release, and utility scripts |
| `tool/` | i18n translation-fill helpers |
| `server/` | Standalone Go WebSocket relay (out of scope for app changes) |

## Testing Checklist (Before Submitting)

- [ ] `flutter analyze` — zero errors, zero warnings
- [ ] `dart run build_runner build --delete-conflicting-outputs` — regenerates cleanly
- [ ] `dart run slang` — if i18n changed
- [ ] Build passes: `flutter build windows --release` (or your target platform)
- [ ] D-pad navigation works (if you touched any UI)
- [ ] Offline mode not broken (if you touched services/downloads)
- [ ] No secrets, keys, or tokens in code
- [ ] Generated files (`*.g.dart`) not hand-edited

## Architecture Quick Reference

**DI:** `main.dart` → `MultiProvider` tree → screens receive concrete instances via constructor.

**Server model:** Single-server product. `MultiServer*` naming is Plex heritage. Treat it as registry/persistence for the current server, not concurrent connections.

**Player:** `lib/mpv/player/` — `player_native.dart` (libmpv on desktop/iOS/macOS), `player_android.dart` (ExoPlayer). Shared `Player` abstraction.

**Downloads:** `DownloadManagerService` + `DownloadStorageService`. Files go to temp location, move to final on completion. `background_downloader` + `workmanager` handle platform side.

**Offline:** Drift DB (`app_database.dart`) with `DownloadedMedia`, `DownloadQueue`, `ApiCache`, `OfflineWatchProgress` tables. Schema version in `app_database.dart` — bump on changes.

**i18n:** slang with JSON sources. Access via `t.section.key` after `LocaleSettings.setLocale(...)`. Always regenerate after editing JSON.

**Focus/TV:** `InputModeTracker` wraps `MaterialApp`. Distinguish keyboard/D-pad from pointer. Focus rings only in keyboard mode. See `lib/focus/` for primitives.
