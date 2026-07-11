# Milestone 002: Temp Download Location

**Date:** 2026-07-11
**Status:** COMPLETE (including staging→temp rename)

## What shipped

Configurable temp location for downloads. Files download to a fast local
drive first, then move atomically to the final download location on completion.

## Changes

| File | Change |
|------|--------|
| `lib/services/settings_service.dart` | +2 prefs keys, +6 methods (get/set/has for temp path) |
| `lib/services/download_storage_service.dart` | +temp path state, `getTempDownloadsDirectory()`, `getTempFilePath()`, `moveToFinalLocation()` |
| `lib/services/download_manager_service.dart` | `_DownloadContext.finalFilePath`, temp redirect in `_prepareAndEnqueueDownload`, move-on-complete in `_onDownloadComplete` |
| `lib/screens/settings/settings_screen.dart` | Temp Location row + dialog + picker + reset |
| `lib/i18n/*.i18n.json` | 6 new strings per locale (tempLocation*) |

## Behavior

- **Default (no temp path set):** temp == final, zero overhead — no move occurs
- **Custom temp path:** download to temp dir, `File.rename()` to final (fast if same fs), falls back to `copy()` + `delete()` for cross-filesystem
- **SAF mode (Android):** unaffected — writes directly to content:// URI
- **Cancel/cleanup:** deletes temp file, not the (unwritten) final path
- **DB storage:** always stores relative path to final location — unchanged

## Known

- Cross-fs move copies the full file before deleting temp — doubles disk usage momentarily
- Crash mid-move could leave duplicates — temp dir can be cleaned on next startup (future work)
- Staging location hidden on iOS (same as download location)
