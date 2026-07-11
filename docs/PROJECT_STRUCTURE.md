# Project Structure

## Overview

Finzy is a Flutter app (Dart) forked from Plezy (a Plex client), adapted for Jellyfin. Targets: iOS, Android (phone + TV), macOS, Windows, Linux, Web (PWA).

## Repository Layout

```
finzy/
├── lib/                    # Main Dart source
│   ├── main.dart           # Composition root, DI, MultiProvider tree
│   ├── constants/          # Static config, API constants
│   ├── data/               # Static data files (ISO codes, etc.)
│   ├── database/           # Drift (SQLite) schema + migrations
│   ├── focus/              # Focus management, D-pad navigation
│   ├── i18n/               # slang JSON sources + generated .g.dart
│   ├── mixins/             # Shared UI mixins
│   ├── models/             # Data models (@JsonSerializable)
│   ├── mpv/                # Player abstraction layer
│   │   ├── player/         # Player implementations
│   │   │   └── platform/   # Platform-specific player code
│   │   └── ...
│   ├── navigation/         # Navigation utilities
│   ├── providers/          # ChangeNotifiers exposed to UI
│   ├── screens/            # Top-level routes
│   │   ├── downloads/      # Download management screens
│   │   ├── libraries/      # Library browsing + tabs
│   │   ├── livetv/         # Live TV + EPG + tabs
│   │   ├── playlist/       # Playlist management
│   │   ├── profile/        # User profile
│   │   └── settings/       # Settings (includes download location config)
│   ├── services/           # Business logic, API clients, persistence
│   ├── theme/              # Design tokens, Material theme
│   ├── utils/              # Pure utility functions
│   └── widgets/            # Shared widgets
│       └── video_controls/ # Playback UI (controls, sheets, helpers)
├── android/                # Android platform code
├── ios/                    # iOS platform code
├── macos/                  # macOS platform code
├── windows/                # Windows platform code + CMakeLists.txt
├── linux/                  # Linux platform code + packaging
├── web/                    # Web platform (PWA)
├── assets/                 # Static assets (icons, shaders, fonts)
├── docs/                   # Design docs, plans, release notes
├── milestones/             # In-progress work checkpoints
├── scripts/                # Build, release, utility scripts
├── tool/                   # i18n translation helpers (Dart/Python)
├── server/                 # Standalone Go WebSocket relay (companion)
├── Casks/                  # Homebrew cask manifest
├── winget/                 # Windows Package Manager manifests
├── .github/                # CI workflows, issue templates
├── CLAUDE.md               # AI assistant guidance (authoritative)
├── analysis_options.yaml   # Linter config (flutter_lints + dart_code_linter)
├── pubspec.yaml            # Dependencies, SDK constraints
└── pubspec.lock            # Locked dependency versions
```

## Key Files

| File | Purpose |
|------|---------|
| `lib/main.dart` | App entry point. Instantiates singletons, wires `MultiProvider` tree, routes to `SetupScreen` → `MainScreen`. |
| `lib/database/app_database.dart` | Drift schema. 4 tables: `DownloadedMedia`, `DownloadQueue`, `ApiCache`, `OfflineWatchProgress`. Schema version managed here. |
| `lib/services/jellyfin_client.dart` | Jellyfin REST API wrapper via `dio`. Single source of truth for all API calls. |
| `lib/services/download_storage_service.dart` | File storage: temp/final paths, move-to-final, path resolution, migration, verification. |
| `lib/services/download_manager_service.dart` | Download orchestration: queue, progress, temp→final completion, cancellation. |
| `lib/services/settings_service.dart` | SharedPreferences keys and accessors for all app settings. |
| `lib/screens/settings/settings_screen.dart` | Settings UI. Download location config, temp location, verify downloads. |
| `lib/widgets/side_navigation_rail.dart` | Desktop/TV sidebar navigation. |
| `lib/focus/input_mode_tracker.dart` | Distinguishes keyboard/D-pad from pointer input. Wraps `MaterialApp`. |
| `lib/mpv/player/player_native.dart` | libmpv player (desktop, iOS, macOS). |
| `lib/mpv/player/player_android.dart` | ExoPlayer player (Android). |
| `analysis_options.yaml` | Linter rules, metric thresholds, formatter page width (120). |
| `CLAUDE.md` | Authoritative AI guidance: architecture, commands, gotchas, patterns. |

## Code Generation

| System | Trigger | Command |
|--------|---------|---------|
| **drift** (SQLite) | Edit `app_database.dart` or drift tables | `dart run build_runner build --delete-conflicting-outputs` |
| **json_serializable** | Edit `@JsonSerializable` models | Same as above |
| **slang** (i18n) | Edit `lib/i18n/*.i18n.json` | `dart run slang` |

All generated files (`*.g.dart`) are committed to the repo. Never hand-edit them.

## Dependencies

### Direct (app)

| Package | Version | Notes |
|---------|---------|-------|
| `drift` | 2.34.1 | SQLite ORM |
| `dio` | 5.10.0 | HTTP client |
| `provider` | 6.1.5+1 | State management |
| `file_picker` | 12.0.0-beta.7 | File/directory selection |
| `background_downloader` | 9.5.5 | Download engine |
| `wakelock_plus` | 1.4.0 | Screen wake lock |
| `slang` | 4.18.0 | i18n |
| `window_manager` | 0.5.2 | Desktop window control |
| `mobile_scanner` | 7.2.0 | QR code scanning (Quick Connect) |

### Git-sourced

| Package | Source | Notes |
|---------|--------|-------|
| `os_media_controls` | `github.com/dkmcgowan/media_controls` | OS media controls (not on pub.dev) |

### Overrides

| Package | Version | Reason |
|---------|---------|--------|
| `source_gen` | ^4.1.2 | Required for build_runner compatibility with newer analyzer |

See `docs/DEPENDENCY_STATUS.md` for full upgrade status.

## CI/CD

Workflows in `.github/workflows/`:

| Workflow | Trigger | What it does |
|----------|---------|--------------|
| `ci.yml` | PRs | Format check, analyze, unused code/files check |
| `build.yml` | PRs + push | Build for all platforms |
| `release.yml` | Tags | Build + create GitHub release |
| `generate-icons.yml` | Manual | Regenerate app icons |
| `update-cask.yml` | Release | Update Homebrew cask |
| `update-winget.yml` | Release | Update WinGet manifest |
| `upload-*.yml` | Release | Upload to stores (Google Play, Apple, Amazon, Microsoft) |

## Platform Notes

- **Windows:** Requires VS Build Tools with "Desktop development with C++" workload. Do NOT use scoop/winget for build tools.
- **Android TV:** First-class target. All UI must work with D-pad navigation.
- **Web:** PWA with conditional imports for `dart:io` code. SQLite via `sqlite3.wasm`.
- **ARM64:** CI pins Flutter `master` channel for ARM64 builds (stable doesn't support it yet).
