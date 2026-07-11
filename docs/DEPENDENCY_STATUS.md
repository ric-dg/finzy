# Dependency Status

**Last checked:** 2026-07-11

## Upgradeable

| Package | Current | Latest | Action |
|---------|---------|--------|--------|
| drift_dev | 2.34.3 | 2.34.3 | ✅ Up to date |

## Held by Flutter SDK (can't upgrade)

| Package | Current | Latest | Why |
|---------|---------|--------|-----|
| intl | 0.20.2 | 0.20.3 | `flutter_localizations` pins exactly |
| meta | 1.18.0 | 1.19.0 | Flutter SDK dependency |
| vector_math | 2.2.0 | 2.4.0 | Flutter SDK dependency |
| package_config | 2.2.0 | 3.0.0 | Major version bump; Flutter SDK pins ^2.x |

## Held by transitive deps (can't upgrade)

| Package | Current | Latest | Why |
|---------|---------|--------|-----|
| qr | 3.0.2 | 4.0.0 | `qr_flutter ^4.1.0` requires `qr ^3.x` |
| xml | 6.6.1 | 7.0.1 | `dart_code_linter`, `vector_graphics_compiler` require `xml ^6.x` |

## Held by analyzer ecosystem (dev-only, can't upgrade)

| Package | Current | Latest | Why |
|---------|---------|--------|-----|
| analyzer | 13.0.0 | 14.0.0 | `drift_dev`, `source_gen`, `json_serializable` require `analyzer ^13.x` |
| _fe_analyzer_shared | 100.0.0 | 104.0.0 | Tied to analyzer version |
| dart_style | 3.1.9 | 3.1.12 | Tied to analyzer version |
| analyzer_plugin | 0.14.9 | 0.14.13 | Tied to analyzer version |
| analysis_server_plugin | 0.3.15 | 0.3.19 | Tied to analyzer version |

## Notes

- All remaining outdated packages are constrained by the Flutter SDK or parent package version ranges.
- No major version bumps are possible without breaking downstream dependencies.
- The analyzer ecosystem (drift_dev, source_gen, json_serializable) collectively pins analyzer to ^13.x — upgrading requires a coordinated release from all three.
