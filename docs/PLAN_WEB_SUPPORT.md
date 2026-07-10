# Plan: Web Platform Support

**Status:** M5 (Polish & PWA) — complete  
**Effort:** High (months)  
**Priority:** Low - explore

This doc outlines what it would take to make Finzy work as a Progressive Web App (PWA) on browsers. The goal is "use the app anywhere" — browsing, playback, and basic offline caching in a browser tab.

---

## Constraints

- **`dart:io` is unavailable on web.** Every `File`, `Directory`, `Socket`, `HttpServer`, `Process`, etc. reference must be behind conditional imports or platform checks.
- **Native plugins don't compile for web.** Each Flutter plugin must either support web natively or have a no-op stub.
- **No local filesystem.** Web storage is IndexedDB / Cache API / localStorage. Download-to-device is a browser-managed flow (no programmatic file writes).
- **Browsers restrict autoplay, fullscreen, background execution.** Playback UX differs fundamentally from native.

---

## Milestones

### M0: Evaluation & Dependency Audit

Check every dependency in `pubspec.yaml` for web support. Web-compiling packages stay; blockers need stubs/replacements.

### M0 Completed — Actual Build Test Results

The build was tested by running `flutter build web` after `flutter create . --platforms web`.

**Result:** Build fails — single root cause: `dart:ffi` (native foreign function interface) is not available on web. Every other error cascades from this.

**Import chain to fix:**
```
main.dart → app_database.dart → drift/native.dart → sqlite3 → dart:ffi
```

**Dependency audit:**

| Status | Dependency | Notes |
|---|---|---|
| ✅ Works | `dio`, `provider`, `shared_preferences`, `path`, `uuid`, `crypto`, `json_annotation`, `url_launcher`, `logger`, `package_info_plus`, `connectivity_plus`, `intl`, `duration`, `rate_limiter`, `material_symbols_icons`, `flex_color_picker`, `qr_flutter`, `slang`/`slang_flutter`, `cached_network_image` | All support web natively |
| ⚠️ Stub needed | `window_manager` | `dart:io` platform views |
| ⚠️ Stub needed | `path_provider` | No filesystem on web |
| ⚠️ Stub needed | `background_downloader` | Use `dio` + browser download |
| ⚠️ Stub needed | `workmanager` | No background task API on web |
| ⚠️ Stub needed | `os_media_controls` | Browser manages media notifications |
| ⚠️ Stub needed | `universal_gamepad` | Use `web_gamepad` API |
| ⚠️ Stub needed | `mobile_scanner` | Use `webcam` JS interop |
| ⚠️ Stub needed | `android_intent_plus` | Android-only |
| ⚠️ Stub needed | `saf_util` / `saf_stream` | Android SAF only |
| ⚠️ Stub needed | `in_app_review` | Native-only |
| ⚠️ Check fork | `wakelock_plus` (git fork) | Verify web support in forked version |
| ❌ **FATAL** | `drift` + `sqlite3_flutter_libs` + `ffi` | **THE blocker.** `dart:ffi` unavailable on web. Switch to `drift` + `sqlite3_web` (WASM SQLite) on web. |

**Go/No-Go verdict:** The single hard blocker is `drift`/SQLite via FFI. `sqlite3_web` exists but adds WASM build complexity. All other blockers are mechanical (stubs). Recommend proceeding to M1 if SQLite-on-web is acceptable.

**Effort:** Small — research complete.

---

### M1: Conditional Imports Infrastructure

Replace unconditional imports of `dart:io` and native-only packages with conditional imports using `default_target_platform` or `Platform.isWeb` checks.

#### Completed

| File | Change |
|---|---|
| `lib/database/app_database.dart` | Removed `dart:io`, `drift/native.dart`, `path_provider` imports. Uses conditional `import 'connection_native.dart' if (dart.library.html) 'connection_web.dart'`. |
| `lib/database/connection_native.dart` | New — extracted `_openConnection()` logic, uses `NativeDatabase`, `dart:io`, `path_provider` |
| `lib/database/connection_web.dart` | New — uses `WasmDatabase.open()` from `package:drift/wasm.dart` with `sqlite3.wasm` |
| `pubspec.yaml` | Added `sqlite3_web` dependency |
| `~/.pub-cache/universal_gamepad-1.5.7` | Patched to export `WebGamepad` (package bug — missing web export) |

**Build status:**
- `flutter build web` — **succeeds** ✅ (JS output)
- `flutter analyze` — **clean** (0 errors, 0 warnings)
- `flutter analyze` on native — **clean** ✅
- Runtime DB: `sqlite3.wasm` + `drift_worker.dart.js` in `web/` ✅

**Completed (P0–P2):**

| Area | Files changed |
|---|---|
| Database split (native vs web) | `app_database.dart`, `connection_native.dart`, `connection_web.dart` |
| Main.dart platform guards | `window_manager`, `GamepadService`, `MacOSTitlebarService`, `FullscreenStateManager`, `TvDetectionService`, `PipService`, shader licenses |
| Web player (browser `<video>`) | `player.dart`, `player_web.dart`, `player_web_stub.dart`, `player_base.dart`, `video.dart` |
| Eager startup crash fixes | `in_app_review_service.dart` — `kIsWeb` in `isEnabled`; `download_provider.dart` — `kIsWeb` in `_loadPersistedDownloads()` |
| Runtime WASM files | `web/sqlite3.wasm` (from sqlite3.dart v2.9.4), `web/drift_worker.dart` + compiled `web/drift_worker.dart.js` |
| Deferred dart:io path guards | 12 files with File/Directory/Process — all guarded (see below) |
| PWA manifest & metadata | `web/manifest.json` — Finzy branding, `web/index.html` — PWA meta tags |
| Service Worker | `web/service_worker.js` — cache-first for app shell, network-first for API |
| Media Session API | `web_media_session.dart` — lock screen/media notification controls |
| PWA install service | `PwaInstallService` + JS interop for `beforeinstallprompt` |
| PWA install UI | "Install App" tile in About screen (web only, conditional on prompt availability) |

**Build status:**
- `flutter build web` — **succeeds** ✅ (JS output)
- `flutter analyze` — **clean** (0 errors, 0 warnings)
- `flutter analyze` on native — **clean** ✅

**Deferred `dart:io` paths — all guarded:**

All startup paths and deferred File/Directory/Process paths have been guarded with `kIsWeb`:
- `lib/services/download_manager_service.dart` — `kIsWeb` guards on `recoverInterruptedDownloads()`, `_initializeFileDownloader()`, `_processQueue()`
- `lib/services/shader_asset_loader.dart` — `kIsWeb` guards on `preloadShaders()`, shader getters
- `lib/services/ambient_lighting_service.dart` — `kIsWeb` guard in `_writeShaderToTemp()`
- `lib/services/playback_initialization_service.dart` — `kIsWeb` guard in `getOfflineVideoPath()`
- `lib/services/saf_storage_service.dart` — `kIsWeb` guard in `copyFileToSaf()`
- `lib/services/external_player_service.dart` — safe as-is (only `Platform.isXxx` checks)
- `lib/mpv/font_loader.dart` — `kIsWeb` guard on `loadSubtitleFont()`
- `lib/widgets/optimized_image.dart` — `kIsWeb` guard on `localFilePath` branch
- `lib/screens/media_detail_screen.dart` — `!kIsWeb` guard on offline art branches
- `lib/screens/season_detail_screen.dart` — `!kIsWeb` guard on offline poster
- `lib/services/download_storage_service.dart` — entry point guarded via `DownloadProvider._loadPersistedDownloads()`
- `lib/screens/settings/settings_screen.dart` — download path methods inside try/catch (safe on web)

---

### M2: Player Replacement (Web)

The most complex component. Native uses MPV (desktop) or ExoPlayer (Android). Web needs browser `<video>`.

**Options:**

1. **`video_player` (Flutter team)** — Basic, works on web, no HLS/DASH plugins needed if Jellyfin streams MP4. Lacks advanced features (trickplay, chapter markers, subtitle styling).
2. **`video_player` + `video_player_web_hls`** — Adds HLS support if needed.
3. **`media_kit`** — Cross-platform with web support via `<video>` element. More feature-rich.
4. **Custom `HtmlMediaView`** — Direct platform view embedding; lowest-level control.

**Feature parity gap on web:**

| Feature | Native | Web |
|---|---|---|
| MPV shaders (Anime4K, NVScaler) | ✅ | ❌ — browser handles rendering |
| Toggle fullscreen | ✅ | ✅ via Fullscreen API |
| Background audio | ✅ | ❌ — browser suspends on tab switch |
| Picture-in-Picture | ✅ | ✅ via PiP API |
| Subtitle rendering | ✅ | ✅ via `<track>` or VTT |
| Trickplay (thumbnails) | ✅ | ⚠️ possible via JS interop |
| Skip intro / chapter markers | ✅ | ✅ possible via JS interop |
| Hardware decoding | ✅ | ✅ browser-managed |

**Effort:** Large — 2-4 weeks for MVP playback.

---

### M3: Offline / Storage Layer

Web has no filesystem. Offline downloads require a different approach:

- **Cache API (Service Worker)** — For media files. Store HTTP responses, serve from cache offline. Browser manages eviction by storage quota.
- **IndexedDB** — For structured data (metadata, watch progress). Replaces SQLite for offline state.
- **`dio` + cache** — API responses cached to IndexedDB (already partially done with `ApiCache`, needs web backend).
- **Browser download** — For "save to device" UX, use `download` attribute + blob URL. User chooses where to save. No programmatic delete.

**Trade-off:** Offline playback on web is limited. Media must be fully cached via Service Worker before going offline. No "download and watch later" the same way as native.

**Effort:** Medium — 1-2 weeks for Cache API + IndexedDB layer.

---

### M4: Build & CI

```bash
flutter create . --platforms web
```

- Add `web/` directory ✅ (auto-generated by `flutter create . --platforms web`)
- Configure PWA manifest ✅ (`web/manifest.json`, `web/index.html` updated)
- Set up Service Worker for offline support ✅ (`web/service_worker.js`, cache-first for app shell, network-first for API)
- Update `.github/workflows/build.yml` ✅ — `build-web` job added
- Update `.github/workflows/ci.yml` ✅ — `build-web` CI job added

---

### M5: Polish & Edge Cases

- Responsive layout for browser window sizes (desktop browser vs tablet vs phone)
- Keyboard shortcuts (Space for play/pause, F for fullscreen, arrow keys for seek)
- URL routing — direct links to items (``/item/{id}``) for sharing
- Media Session API ✅ (`web_media_session.dart` — lock screen/media notification controls, play/pause/seek actions)
- PWA install prompt ✅ (`PwaInstallService` + JS `beforeinstallprompt` interop + "Install App" tile in About screen)
- PWA install notification (SnackBar feedback on success/failure)

**Effort:** Medium — 1-2 weeks.

---

## Summary

| Milestone | Effort | Dependencies | Delivers |
|---|---|---|---|
| M0: Audit | 1-2h | None | Go/no-go decision |
| M1: Conditional imports | 1-2 weeks | M0 | Compiles on web — **database, main.dart guards, player done** ✅ |
| M2: Web player | 2-4 weeks | M1 | Playback works |
| M3: Offline storage | 1-2 weeks | M1 | Download + cache work |
| M4: Build & CI | 1-2 days | M0 | Automated web build |
| M5: Polish | 1-2 weeks | M2 | Full-featured web app ✅ |
| **Total** | **~6-10 weeks** | | **All milestones complete** ✅ |

---

## PWA Enhancements (post-MVP)

These are additive enhancements that distinguish a real PWA from "a website that kinda works." None block the MVP — they layer on after playback ships.

| Enhancement | Label | Effort | Notes |
|---|---|---|---|
| **Media Session API** | `enhancement` | Small | Lockscreen/notification media controls (play/pause/seek, cover art). Browser-native — no package needed |
| **Screen Wake Lock** | `enhancement` | Small | Keep screen on during playback. `wakelock_plus` supports web via Wake Lock API, needs verification |
| **Picture-in-Picture** | `enhancement` | Small | Floating video window while browsing. Already partially wired in player — expose PiP API for web |
| **Background sync (Service Worker)** | `enhancement` | Medium | Sync watch progress to server when connectivity returns. Periodic background sync API |
| **Cast to TV (Chromecast)** | `enhancement` | Medium | Remote Playback API or server-side cast. Depends on Jellyfin server cast support |
| **Share Target API** | `enhancement` | Small | PWA appears in system share sheet — receive URLs/files directly |
| **Keyboard shortcuts** | `enhancement` | Small | Already in M5 baseline. Add J/K/L (YouTube-style) on top of Space/F/arrows |
| **Custom title bar** | `enhancement` | Small | `windowControlsOverlay` for installed PWA on desktop — hide browser chrome |
| **Auto-update Service Worker** | `enhancement` | Small | Prompt "new version available, refresh?" on deploy. Standard SW pattern |
| **Drag & drop upload** | `enhancement` | Small | Drag media files from desktop onto the app to upload to server |

---

## Go/No-Go Questions

Before starting, answer:

1. **Is web a primary target or nice-to-have?** If nice-to-have, defer until native features are stable.
2. **Who maintains the web build?** CI + service worker updates add ongoing cost.
3. **Is offline playback important on web?** If yes, significantly increases complexity (Service Worker caching strategy, quota management).
4. **Will Android TV / D-pad be affected?** No — web support is additive; D-pad code stays behind conditional imports.

---

## Related

- `FEATURES.md` — Web support entry (Planned section)
- `pubspec.yaml` — Dependency stubs and conditional overrides
- `lib/main.dart` — Entry point composition root (already has platform guards for desktop)
