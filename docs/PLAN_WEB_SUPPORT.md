# Plan: Web Platform Support

**Status:** M1 (Conditional imports) — complete  
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

**Remaining (deferred paths — crash when user navigates to feature, not at startup):**

Files that construct `File`/`Directory`/`Process` objects (need `kIsWeb` guards):
- `lib/services/download_manager_service.dart` — `File`, `Platform.isWindows`
- `lib/services/download_storage_service.dart` — `File`, `Directory`, `Platform.isAndroid`
- `lib/services/shader_asset_loader.dart` — `File`, `Directory`, `path_provider`
- `lib/services/ambient_lighting_service.dart` — `Socket`/`dart:io`
- `lib/services/external_player_service.dart` — `Process`, `Platform`
- `lib/services/playback_initialization_service.dart` — `File` (offline media paths)
- `lib/services/saf_storage_service.dart` — Android SAF only
- `lib/mpv/font_loader.dart` — `File` (subtitle font loading)
- `lib/widgets/optimized_image.dart` — `File` (disk cache)
- `lib/screens/settings/settings_screen.dart` — `Platform` checks
- `lib/screens/media_detail_screen.dart` — `Platform` + local path
- `lib/screens/season_detail_screen.dart` — `Platform` + local path

Files with only `Platform.isXxx` checks (safe on web — stub returns `false`):
- `lib/services/jellyfin_client.dart`, `offline_watch_sync_service.dart`, `watch_next_service.dart`, `keyboard_shortcuts_service.dart`, `macos_titlebar_service.dart`, `macos_window_service.dart`, `fullscreen_state_manager.dart`, `gamepad_service.dart`, `pip_service.dart`, `platform_detector.dart`
- Various screen/widget files with TV/desktop-specific `Platform` checks

**Effort:** Medium — ~12 files with File/Directory/Process need guards. ~20 Platform-only files are safe as-is.

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

- Add `web/` directory (auto-generated)
- Configure PWA manifest (`web/manifest.json`) — app name, icons, theme color, display mode
- Set up Service Worker for offline support
- Update `.github/workflows/build.yml` — add `flutter build web` job (deploy to Pages / Cloudflare / etc.)
- Update `.github/workflows/ci.yml` — add web analysis + build check

**Effort:** Small — 1-2 days.

---

### M5: Polish & Edge Cases

- Responsive layout for browser window sizes (desktop browser vs tablet vs phone)
- Keyboard shortcuts (Space for play/pause, F for fullscreen, arrow keys for seek)
- URL routing — direct links to items (``/item/{id}``) for sharing
- Media Session API — browser media notification controls
- PWA install prompt

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
| M5: Polish | 1-2 weeks | M2 | Full-featured web app |
| **Total** | **~6-10 weeks** | | |

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
