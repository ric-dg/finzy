# Plan: Web Platform Support

**Status:** Not started  
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

**Key blockers (need stubs or alternatives):**

| Dependency | Issue | Approach |
|---|---|---|
| `window_manager` | Web-only imports (`dart:io`) | Stub — all methods no-op; web has no window chrome controls |
| `path_provider` | `dart:io` paths | Replace with `path_provider_web` or stub; web uses transient storage |
| `drift` + `sqlite3_flutter_libs` | Native SQLite | Use `drift` with `sqlite3_web` (WASM-based) or `SharedPreferencesDrift` for simple KV |
| `background_downloader` | Native only | Replace with `dio` streaming + browser download API (FileSaver) |
| `workmanager` | Native only | Web runs in foreground only; no background task API |
| `wakelock_plus` (git fork) | Check fork for web | May work; if not, sync API call |
| `os_media_controls` | Native only | No-op stub; browser manages media notifications |
| `universal_gamepad` | Native only | Stub or use `web_gamepad` API directly |
| `mobile_scanner` | Native only | Stub or use `webcam` API directly |
| `android_intent_plus` | Android only | No-op stub |
| `saf_util` / `saf_stream` | Android SAF | No-op stub |
| `in_app_review` | Native only | No-op stub |
| `flutter_svg` | Check version | Likely works, verify |
| `file_picker` | Has web support | Verify version |
| `cached_network_image` | Has web support | Verify version |
| `connectivity_plus` | Has web support | Verify version |
| `dio` | Full web support | ✅ No change |
| `provider` | Full web support | ✅ No change |

**Effort:** Small — research & document, 1-2 hours.

---

### M1: Conditional Imports Infrastructure

Replace unconditional imports of `dart:io` and native-only packages with conditional imports using `default_target_platform` or `Platform.isWeb` checks.

**Files to touch (representative sample):**

- `lib/main.dart` — Guard `window_manager` init, `GamepadService`, `MacOSTitlebarService`
- `lib/services/download_manager_service.dart` — Guard all `File`, `Directory`, `Platform` usage
- `lib/services/download_storage_service.dart` — Web won't have real downloads; stub to browser download
- `lib/services/api_cache.dart` — `File` usage needs IndexedDB or memory cache fallback
- `lib/database/app_database.dart` — Two backends: drift+sqlite3 (native) vs drift+sqlite3_web (web)
- `lib/services/offline_watch_sync_service.dart` — `File` usage
- `lib/mpv/` — Entire player layer; web uses `HtmlMediaView` or `video_player` package
- `lib/focus/` — D-pad navigation irrelevant on web; should be no-op wrappers
- `lib/widgets/focusable_*` — Conditional render based on platform; web uses pointer/click
- `lib/services/playback_initialization_service.dart` — Player init differs

**Effort:** Large — 40-60 files likely need conditional import guards.

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
| M1: Conditional imports | 1-2 weeks | M0 | Compiles on web (no features) |
| M2: Web player | 2-4 weeks | M1 | Playback works |
| M3: Offline storage | 1-2 weeks | M1 | Download + cache work |
| M4: Build & CI | 1-2 days | M0 | Automated web build |
| M5: Polish | 1-2 weeks | M2 | Full-featured web app |
| **Total** | **~6-10 weeks** | | |

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
