# Windows Build Context (AI Primer)

## Platform

This covers **x64 Windows** (what you're on). ARM64 has separate CI considerations below.

## Prerequisites (Install These First)

You do **not** need the full Visual Studio IDE. **Visual Studio Build Tools** (command-line only) is sufficient — you can keep VS Code or Neovim as your editor. Do NOT use scoop, winget, or chocolatey for build tools — they don't provide the CMake/MSBuild toolchain Flutter needs.

### Required installs

| What | Exactly | Link |
|------|---------|------|
| **Visual Studio Build Tools** | Install **"Desktop development with C++"** workload. Inside that workload, these components are needed (usually selected by default with the workload): MSVC v143 C++ x64/x86 build tools, Windows 10/11 SDK, C++ CMake tools for Windows, Windows Universal C Runtime. | [visualstudio.microsoft.com/downloads/#build-tools-for-visual-studio-2022](https://visualstudio.microsoft.com/downloads/#build-tools-for-visual-studio-2022) |
| **Flutter SDK** | `pubspec.yaml` requires Dart SDK `^3.8.1` (Flutter ≥3.32). Do NOT install via `choco` or `winget` — use the direct archive from flutter.dev so you control the channel. | `git clone https://github.com/flutter/flutter.git -b stable C:\flutter` then add `C:\flutter\bin` to PATH. Verify: `flutter --version` should show Dart 3.8+ |
| **Git for Windows** | Needed for cloning + git-sourced dep (`os_media_controls` fork) | [git-scm.com](https://git-scm.com) |
| **Windows SDK** | Comes with Build Tools workload above, but if missing: install standalone "Windows 10 SDK" (10.0.20348.0 or later) | [go.microsoft.com/fwlink/?linkid=2271990](https://go.microsoft.com/fwlink/?linkid=2271990) |

### After install

```powershell
flutter doctor -v
```

Every check must pass. If `flutter doctor` shows **"Visual Studio" as missing** even though Build Tools is installed, run:

```powershell
flutter config --msbuild-version 17.0
```

If it still doesn't detect, point it manually:

```powershell
# Typical path for Build Tools
set PATH=C:\Program Files (x86)\Microsoft Visual Studio\2022\BuildTools\MSBuild\Current\Bin;%PATH%
flutter config --msbuild-version 17.0
```

### Optional but recommended

- **Developer Mode** (Windows Settings → Privacy & Security → For developers) — allows symlinks without admin, needed for some Flutter tools.
- **Windows Terminal** — better DX than cmd/PowerShell ISE.
- **VS Code extensions**: Flutter, Dart, Error Lens, GitLens.
- **Neovim**: Install `flutter-tools.nvim` + `dart-vim-plugin` for LSP, hot-reload, debug.

## Common Build Failures & Fixes

### "Exception: Unable to find suitable Visual Studio toolchain"
**Fix:** Run `flutter config --msbuild-version 17.0` or re-run VS Installer and add "Desktop development with C++".

### "linker error: unresolved external symbol sqlite3_..."
Sqlite3 native linking issue. **Fix:** `flutter pub upgrade sqlite3_flutter_libs` or clean build:
```
flutter clean && flutter pub get && flutter run
```

### "Error: The getter 'platform' isn't defined for the type 'FilePicker'"
You're on an old branch still using `FilePicker.platform`. The static API is `FilePicker.pickFiles()` / `FilePicker.getDirectoryPath()`. See `chore/upgrade-packages` branch commit `3572350`.

### "win32 version conflict"
If you see `Because ... depends on win32 ^5.x and ... depends on win32 ^6.x, version solving failed`:
- `file_picker` (older versions) pinned `win32 ^5.x`
- `package_info_plus` >=10.1.0 + `device_info_plus` >=13.1.0 need `win32 ^6.x`
- **Current state:** `file_picker` 12.x + `win32` 6.x are compatible. This should not occur on current `main`.

### "msix build fails"
MSIX packaging needs Visual Studio. **Fix:** Ensure VS installed, then:
```
flutter pub global activate msix
flutter pub global run msix:create
```

### "Build fails with path too long" (Windows MAX_PATH)
**Fix:** Clone to a short path like `C:\dev\finzy`. Or enable long paths in Group Policy / registry.

### "Git-sourced dependency fails to fetch" (os_media_controls)
`os_media_controls` is pinned to `github.com/dkmcgowan/media_controls` fork in `pubspec.yaml`. **Fix:** Ensure SSH or HTTPS auth to GitHub works. If behind a proxy, set `git config --global http.proxy`.

## ARM64 Pin (CI Only)

CI forces Windows ARM64 onto Flutter `master` at pin `7b7832a30f` (parent of flutter/flutter#165323 which regressed ARM64 touch input). Tracked at flutter/flutter#184954. Drop pin when upstream fix lands. You're on x64, so this doesn't affect you directly, but ARM64 CI jobs use a different channel/revision in `.github/workflows/build.yml`.

## sqlite3_flutter_libs 0.6.0+eol

Removed plugin registration on desktop. Generated plugin registrant files auto-updated during `flutter pub get`. No action needed.

## Desktop-Only Init

`window_manager`, `MacOSTitlebarService`, `GamepadService` guarded by `Platform.is*` checks in `main.dart`. On Windows: window positioning via `window_manager`, gamepad via `GamepadService`.

## Key Commands

```powershell
# First time
flutter pub get
dart run build_runner build --delete-conflicting-outputs
dart run slang

# Run
flutter run --dart-define=GIT_COMMIT=$(git rev-parse HEAD)

# Check
flutter analyze
flutter pub run dart_code_linter:metrics check-unused-code lib
flutter pub run dart_code_linter:metrics check-unused-files lib

# MSIX package
flutter pub global run msix:create

# Clean rebuild
flutter clean && flutter pub get && flutter run
```
