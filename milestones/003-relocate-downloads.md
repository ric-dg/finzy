# Milestone 003: Relocate Existing Downloads to New Location

## Goal

Allow users to change their download location and have existing downloads continue to work. Currently, paths in the DB are stored relative to the app base directory (`appBaseDir/downloads/...`). Changing the download location to a custom path breaks all existing entries because they still resolve against the old base.

## Problem

| Component | Current Behavior |
|-----------|-----------------|
| `toRelativePath()` | Strips `_getBaseAppDir()` prefix → `downloads/Movies/video.mkv` |
| `toAbsolutePath()` | Prepends `_getBaseAppDir()` → always resolves to app sandbox |
| Custom download path | Only affects where **new** downloads go; existing DB entries still point to app sandbox |

**Result:** After changing download location, existing downloads become invisible — the DB path resolves to a location where no file exists.

## Approach

Fix path resolution to be relative to the **download directory** (not the app base dir), add auto-migration when location changes, and add a "Verify Downloads" rescan utility.

---

## Changes

### 1. Fix Path Resolution (`download_storage_service.dart`)

**`toRelativePath(absolutePath)`** — Strip `getDownloadsDirectory().path` instead of `_getBaseAppDir().path`:

```dart
// BEFORE
Future<String> toRelativePath(String absolutePath) async {
  final baseDir = await _getBaseAppDir();
  if (absolutePath.startsWith(baseDir.path)) {
    var relative = absolutePath.substring(baseDir.path.length);
    if (relative.startsWith('/') || relative.startsWith('\\')) {
      relative = relative.substring(1);
    }
    return relative;
  }
  return absolutePath;
}

// AFTER
Future<String> toRelativePath(String absolutePath) async {
  final downloadDir = await getDownloadsDirectory();
  if (absolutePath.startsWith(downloadDir.path)) {
    var relative = absolutePath.substring(downloadDir.path.length);
    if (relative.startsWith('/') || relative.startsWith('\\')) {
      relative = relative.substring(1);
    }
    return relative;
  }
  // Fallback: already relative or from a different base
  return absolutePath;
}
```

**`toAbsolutePath(relativePath)`** — Prepend `getDownloadsDirectory().path` instead of `_getBaseAppDir().path`:

```dart
// BEFORE
Future<String> toAbsolutePath(String relativePath) async {
  if (path.isAbsolute(relativePath)) return relativePath;
  final baseDir = await _getBaseAppDir();
  return path.join(baseDir.path, relativePath);
}

// AFTER
Future<String> toAbsolutePath(String relativePath) async {
  if (path.isAbsolute(relativePath)) return relativePath;
  final downloadDir = await getDownloadsDirectory();
  return path.join(downloadDir.path, relativePath);
}
```

**`ensureAbsolutePath(storedPath)`** — Add backward-compat for old-format paths:

```dart
// AFTER
Future<String> ensureAbsolutePath(String storedPath) async {
  if (path.isAbsolute(storedPath)) {
    if (await File(storedPath).exists()) return storedPath;
    // Old absolute path — try extracting relative from 'downloads/' onward
    final downloadsIndex = storedPath.indexOf('downloads/');
    if (downloadsIndex != -1) {
      final relativePart = storedPath.substring(downloadsIndex);
      // Try new resolution first
      final newPath = await toAbsolutePath(relativePart);
      if (await File(newPath).exists()) return newPath;
      // Fallback: old resolution against app base dir
      final baseDir = await _getBaseAppDir();
      final oldPath = path.join(baseDir.path, relativePart);
      if (await File(oldPath).exists()) return oldPath;
    }
    return storedPath;
  }
  // Relative path
  final newPath = await toAbsolutePath(storedPath);
  if (await File(newPath).exists()) return newPath;
  // Old-format relative path (starts with 'downloads/') — try old resolution
  if (storedPath.startsWith('downloads/') || storedPath.startsWith('downloads\\')) {
    final baseDir = await _getBaseAppDir();
    final oldPath = path.join(baseDir.path, storedPath);
    if (await File(oldPath).exists()) return oldPath;
  }
  return newPath;
}
```

### 2. Auto-Migration on Location Change (`download_storage_service.dart`)

New method `migrateDownloadPaths()`:

```dart
/// Migrate all download paths from old base to new download directory.
/// Called when the user changes the download location.
/// Moves files from old location to new location and updates DB paths.
Future<MigrationResult> migrateDownloadPaths(AppDatabase database) async {
  final results = MigrationResult();
  final items = await database.getAllDownloadedMedia();

  for (final item in items) {
    if (item.videoFilePath == null) continue;
    final storedPath = item.videoFilePath!;

    // Skip SAF URIs
    if (isSafUri(storedPath)) {
      results.unchanged++;
      continue;
    }

    // Resolve old absolute path (may use old appBaseDir resolution)
    final oldAbsPath = await _resolveOldPath(storedPath);
    // Compute new relative path (relative to current download dir)
    final newRelPath = await toRelativePath(oldAbsPath);
    final newAbsPath = await toAbsolutePath(newRelPath);

    // Already correct?
    if (newRelPath == storedPath) {
      results.unchanged++;
      continue;
    }

    // File exists at new location already (user moved manually)?
    if (await File(newAbsPath).exists()) {
      await _updatePath(database, item, newRelPath);
      results.moved++;
      continue;
    }

    // File exists at old location? Move it.
    if (oldAbsPath != newAbsPath && await File(oldAbsPath).exists()) {
      await File(newAbsPath).parent.create(recursive: true);
      try {
        await File(oldAbsPath).rename(newAbsPath);
      } on FileSystemException {
        // Cross-fs: copy + delete
        await File(oldAbsPath).copy(newAbsPath);
        await File(oldAbsPath).delete();
      }
      await _updatePath(database, item, newRelPath);
      results.moved++;
      continue;
    }

    // File not found anywhere
    results.missing++;
  }

  return results;
}
```

Helper to resolve old-format paths:

```dart
/// Resolve a stored path using the OLD logic (app base dir).
Future<String> _resolveOldPath(String storedPath) async {
  if (path.isAbsolute(storedPath)) return storedPath;
  final baseDir = await _getBaseAppDir();
  return path.join(baseDir.path, storedPath);
}
```

Helper to update DB entry:

```dart
Future<void> _updatePath(AppDatabase db, DownloadedMediaItem item, String newRelPath) async {
  await db.updateVideoFilePath(item.globalKey, newRelPath);
}
```

`MigrationResult` data class:

```dart
class MigrationResult {
  int moved = 0;
  int unchanged = 0;
  int missing = 0;
  int errors = 0;
  int get total => moved + unchanged + missing + errors;
}
```

### 3. Wire Migration into Settings Flow

**`settings_screen.dart`** — `_selectDownloadLocation()` calls migration after saving:

```dart
// After saving the new path:
await _settingsService.setCustomDownloadPath(selectedPath, type: pathType);
await DownloadStorageService.instance.refreshCustomPath();

// Migrate existing downloads to new location
final result = await DownloadStorageService.instance.migrateDownloadPaths(
  // Need access to AppDatabase — inject via constructor or Provider
);
if (result.moved > 0) {
  showSuccessSnackBar(context, t.settings.downloadsMigrated(count: result.moved));
}
```

**`settings_screen.dart`** — `_resetDownloadLocation()` also calls migration:

```dart
await _settingsService.setCustomDownloadPath(null);
await DownloadStorageService.instance.refreshCustomPath();
// Migrate back to default location
await DownloadStorageService.instance.migrateDownloadPaths(database);
```

### 4. "Verify Downloads" Button

**New method** in `download_storage_service.dart`:

```dart
/// Verify all download paths resolve to existing files.
/// Attempts to find missing files in the download directory.
Future<VerificationResult> verifyDownloadPaths(AppDatabase database) async {
  final results = VerificationResult();
  final downloadDir = await getDownloadsDirectory();
  final items = await database.getAllDownloadedMedia();

  for (final item in items) {
    if (item.videoFilePath == null) continue;
    final storedPath = item.videoFilePath!;
    if (isSafUri(storedPath)) { results.valid++; continue; }

    final absPath = await getReadablePath(storedPath);
    if (await File(absPath).exists()) {
      results.valid++;
      continue;
    }

    // File missing — try to find by filename in download dir
    final fileName = path.basename(absPath);
    final found = await _findFileInDirectory(downloadDir, fileName);
    if (found != null) {
      final newRelPath = await toRelativePath(found);
      await _updatePath(database, item, newRelPath);
      results.repaired++;
    } else {
      results.missing++;
    }
  }
  return results;
}
```

**UI** — Add to downloads settings section:

```dart
ListTile(
  leading: const AppIcon(Symbols.check_circle_rounded, fill: 1),
  title: Text(t.settings.verifyDownloads),
  subtitle: Text(t.settings.verifyDownloadsDescription),
  onTap: () async {
    final result = await DownloadStorageService.instance.verifyDownloadPaths(database);
    if (result.repaired > 0) {
      showSuccessSnackBar(context, t.settings.downloadsRepaired(count: result.repaired));
    }
    if (result.missing > 0) {
      showAppSnackBar(context, t.settings.downloadsMissing(count: result.missing));
    }
  },
)
```

### 5. i18n Strings

Add to `en.i18n.json` (and other locales):

```json
"downloadsMigrated": "{count} downloads moved to new location",
"verifyDownloads": "Verify Downloads",
"verifyDownloadsDescription": "Check that all downloaded files are accessible",
"downloadsRepaired": "{count} downloads repaired",
"downloadsMissing": "{count} downloads not found on disk"
```

---

## Files to Modify

| File | Change |
|------|--------|
| `lib/services/download_storage_service.dart` | Fix `toRelativePath`/`toAbsolutePath`/`ensureAbsolutePath`; add `migrateDownloadPaths()`/`verifyDownloadPaths()`/`_resolveOldPath()`/`_findFileInDirectory()`/`MigrationResult`/`VerificationResult` |
| `lib/screens/settings/settings_screen.dart` | Call `migrateDownloadPaths()` after location change/reset; add "Verify Downloads" ListTile |
| `lib/i18n/en.i18n.json` (+ 8 locales) | Add migration/verification strings |
| `lib/i18n/strings*.g.dart` | Regenerate via `dart run slang` |

## Files NOT Modified

- `lib/database/app_database.dart` — No schema change needed. Paths are just strings.
- `lib/services/download_manager_service.dart` — `_onDownloadComplete` already calls `toRelativePath(ctx.filePath)` where `ctx.filePath` comes from `getDownloadsDirectory()`-based methods. The fixed `toRelativePath` handles this correctly.
- `lib/services/settings_service.dart` — No change needed.

## Edge Cases

| Scenario | Behavior |
|----------|----------|
| Default → Custom | Auto-move from `appBaseDir/downloads/` to `customDir/` |
| Custom → Default | Auto-move from `customDir/` to `appBaseDir/downloads/` |
| Custom A → Custom B | Auto-move from `dirA/` to `dirB/` |
| Files moved manually first | "Verify Downloads" repairs DB paths |
| File missing | Skipped, counted in `missing` |
| SAF URIs | Skipped (not affected) |
| Cross-falls move | Copy + delete fallback (same as `moveToFinalLocation`) |
| Migration fails mid-way | Partial — already-migrated entries are fine, remaining still work via `ensureAbsolutePath` fallback |
| App restarts during migration | Migration runs again on next location change (idempotent — checks `newRelPath == storedPath`) |

## Verification

1. `flutter analyze` — clean
2. `flutter build windows --release` — passes
3. Manual test flow:
   - Download a file with default location
   - Change to custom location → verify file moved, playback works
   - Change back to default → verify file moved back, playback works
   - Use "Verify Downloads" after manually moving files → paths updated
