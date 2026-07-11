# Contributing

## Quick Start

```bash
git clone https://github.com/dkmcgowan/finzy.git
cd finzy
flutter pub get
dart run build_runner build --delete-conflicting-outputs
dart run slang
flutter run
```

## Prerequisites

- **Flutter SDK** 3.44.6+ (Dart SDK ^3.8.1)
- **Windows:** VS Build Tools with "Desktop development with C++" (not scoop/winget)
- **macOS:** Xcode
- **Linux:** Standard GTK/WebKit dev packages (see Flutter Linux docs)

## Development Workflow

### Branch Model

- **`main`** is the only long-lived branch. No `develop`.
- Create feature branches: `feat/*`, `fix/*`, `chore/*`, `docs/*`.
- Each branch = one PR = one logical change.

### Branch Naming

```
feat/temp-download-location
fix/dpad-focus-restore
chore/upgrade-packages
docs/update-readme
```

### PR Process

1. Branch off `main`
2. Make changes, run checks (see below)
3. Push and open PR against `main`
4. CI must pass: format, analyze, build
5. Squash-merge to `main`

### Remotes

- `origin` → `ric-dg/finzy` (your fork)
- `upstream` → `dkmcgowan/finzy` (main repo)

## Code Quality Checks

CI runs on every PR. These must pass:

```bash
# 1. Format (only files you edited)
dart format --set-exit-if-changed lib/path/to/changed_file.dart

# 2. Analyze (zero errors, zero warnings)
flutter analyze

# 3. Build
flutter build windows --release  # or your target platform
```

**Important:** Do NOT bulk-reformat. Local `dart format` may be stricter than CI. Only format files you actually edited.

## Code Generation

After editing relevant files, regenerate:

| What you edit | What to run |
|---------------|-------------|
| `@JsonSerializable` models | `dart run build_runner build --delete-conflicting-outputs` |
| Drift tables / `app_database.dart` | `dart run build_runner build --delete-conflicting-outputs` |
| `lib/i18n/*.i18n.json` | `dart run slang` |
| `pubspec.yaml` | `flutter pub get` |

**Never hand-edit `*.g.dart` files.** They're excluded from analyzer and format checks.

## Internationalization (i18n)

This project uses `slang` with JSON sources.

### Adding New Strings

1. Edit `lib/i18n/en.i18n.json` (English is the source of truth):
   ```json
   {
     "section": {
       "myNewString": "My new text"
     }
   }
   ```
2. Add translations to other locale files (`de.i18n.json`, `fr.i18n.json`, etc.)
3. Run `dart run slang`
4. Use in code: `Text(t.section.myNewString)`

### Adding New Languages

1. Create `lib/i18n/[locale].i18n.json`
2. Copy structure from `en.i18n.json`, translate values
3. Run `dart run slang`

### Parameterized Strings

```json
{
  "downloadsMigrated": "Migrated ${count} downloads"
}
```

Use `${count}` for interpolation. All parameters must be in the JSON value.

## Commit Style

Use conventional commits:

```
feat: add configurable download location
fix: resolve path mismatch on location change
chore: upgrade drift_dev to 2.34.3
docs: update contributing guide
refactor: extract download path utils
```

Subject under 72 chars. Body explains **why**, not **what**.

## Common Pitfalls

1. **Bulk reformatting** — Only format files you edited. CI tolerates pre-existing format diffs.
2. **Breaking D-pad** — Android TV is first-class. Test with D-pad if touching UI.
3. **Provider ordering** — `MultiProvider` in `main.dart` has a specific order. Check before inserting.
4. **Schema version** — If you change `app_database.dart`, bump `schemaVersion` and add a migration.
5. **i18n** — Always run `dart run slang` after editing JSON files. Check `strings.g.dart` timestamp.
6. **Generated files** — Run `build_runner` after model or drift changes. Don't commit stale generated code.

## Architecture

See [CLAUDE.md](../CLAUDE.md) for authoritative architecture documentation.

See [PROJECT_STRUCTURE.md](PROJECT_STRUCTURE.md) for directory layout.

See [AI_GUIDE.md](AI_GUIDE.md) for detailed guidance for AI assistants.

## Release Process

Releases are automated via GitHub Actions:

1. Push a tag (`v0.5.0`)
2. `release.yml` builds for all platforms
3. `upload-*.yml` workflows publish to stores
4. `update-cask.yml` and `update-winget.yml` update package manager manifests

See `scripts/release.sh` for changelog generation (requires `.env` with API keys).
