# Remote translations (Phase K) - staging only

Published Arabic **App** translations can override the Arabic text bundled in the app. Bundled ARB files are never changed
and remain the fallback for everything.

## Switch (build time)
| Build | `--dart-define=ENABLE_REMOTE_TRANSLATIONS` | `API_BASE_URL` | Result |
|---|---|---|---|
| Production (no flag) | absent (default `false`) | production | bundled only |
| Staging | `true` | exactly `https://offro-backend-staging-d375.up.railway.app` | remote Arabic ON |
| Flag set by mistake on any other backend | `true` | anything else | still bundled only (host guard) |

Both conditions are checked in `lib/core/l10n/remote/remote_translation_config.dart`. When off, `main.dart` installs the plain
generated `AppLocalizations.delegate`, `RemoteTranslationService` does nothing (no request, no cache read, no listeners).

## Flow
1. `main()` loads the language, then `RemoteTranslationService.init()` loads the cached published set (if fresh) so Arabic shows
   the last published text at once, even offline; `attach()` starts listening for "Arabic selected" and "app resumed".
2. A refresh runs on startup, when Arabic is selected, and on resume (throttled). English users make no requests.
3. Refresh: `GET /translations/manifest` -> kill switch / Arabic published? -> same version+hash as in use: only the cache
   timestamp is refreshed -> else `GET /translations/ar?track=app`, validate, write cache, switch overrides in one step.
4. `MaterialApp` rebuilds (it listens to the service) and `RemoteAwareLocalizationsDelegate` reloads: `AppLocalizationsArRemote`
   (generated) returns the remote text per key or the bundled Arabic.
5. Kill switch ON, Arabic unpublished: cache and overrides removed, UI returns to bundled Arabic live. Network/HTTP/format errors:
   whatever is in use stays in use; nothing is shown to the user.

## Validation (second line of defence, mirrors the backend rules)
Language code, key names (must be a bundled key), non-empty text, max 2000 chars, no control/hidden/bidi-override characters
(ZWNJ/ZWJ/LRM/RLM/ALM allowed), no HTML, placeholders identical to the bundled definition. Bad entries are skipped (bundled text
stays); a file that is structurally wrong, stale, inconsistent with the manifest hash, or >25% invalid is rejected whole.

## Cache
`SharedPreferences` key `remote_l10n_cache_v1_ar` (validated data only). Used when fresher than 14 days (age = last time the
backend confirmed the version). Removed on kill switch / unpublish. Corrupt or expired cache = bundled text.

## Regenerating the override layer
After `flutter gen-l10n` (any ARB key/placeholder change): `python tools/gen_remote_l10n.py` (`--check` verifies). The test
`test/remote_translation_localizations_test.dart` also fails when the generated files drift from `lib/l10n/app_en.arb`.

## Build (Windows CMD, from the project root)
`tools\build_staging_apk.cmd`, or:
```
flutter pub get
flutter build apk --release --dart-define=API_BASE_URL=https://offro-backend-staging-d375.up.railway.app --dart-define=ENABLE_REMOTE_TRANSLATIONS=true
```

iOS staging (Codemagic, `codemagic.yaml` workflow `ios-app-store`) uses the same two `--dart-define` values in its `flutter build ipa` step, so TestFlight builds receive published translations too.
After a publish the app picks up the new version on start-up, when Arabic is selected, and when it returns to the foreground (at most every 5 minutes). The language file is served with `Cache-Control: no-cache` + ETag, so a new version is never hidden by a cached copy.
