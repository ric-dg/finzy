# Web Headless Testing

These scripts use Playwright to test the Flutter web build in a headless browser.
They verify app state, persistence, database, and playback flow — useful for CI
or local smoke-testing after web changes.

## Setup

```bash
pip install playwright
playwright install chromium
cd build/web
python3 -m http.server 8000 &
```

## Scripts

### `test_web_headless.py`
- Launches Playwright, navigates to `http://localhost:8000`
- Waits for Flutter canvas to render
- Basic smoke test: app loads without crash

### `test_web_app_state.py`
- Checks that server registry, auth state, and UI elements are present
- Validates that offline mode button appears when no server is reachable

### `test_web_persistence.py`
- Loads the app, checks that `localStorage` / `SharedPreferences` data persists
- Reloads the page and verifies state is restored

### `test_web_db_and_player.py`
- Verifies SQLite via Drift (sqlite3_wasm) initializes correctly
- Checks API cache table is created and queryable
- Navigates to player screen and verifies it mounts

### `test_web_playback.py`
- Checks playback controls render
- Verifies progress tracking events fire

### `test_web_player_flow.py`
- End-to-end flow: app load → navigate library → select item → player screen
- Verifies back navigation returns to item detail

All scripts should call `page.waitForSelector('flt-canvas')` to confirm the Flutter
app has mounted, and use `page.evaluate()` for JS interop checks
(e.g. `window.isPwaInstallable()`).
