# Remote translations (staging and production)

Published Arabic **App** translations can override the Arabic text bundled in the app. Bundled ARB files are never changed
and remain the fallback for everything. Translators edit and publish in the dashboard of the SAME environment the app talks to;
after a build with the switch on is released, new translations reach the app without a new APK.

## Switch (build time)
| Build | `--dart-define=ENABLE_REMOTE_TRANSLATIONS` | `API_BASE_URL` | Result |
|---|---|---|---|
| Any build made the old way | absent (default `false`) | anything | bundled only |
| Staging | `true` | exactly `https://offro-backend-staging-d375.up.railway.app` | remote Arabic ON, staging server only |
| Production | `true` | exactly the production API origin (`kRemoteProductionHost`) | remote Arabic ON, production server only |
| Flag set on any other host | `true` | anything else | bundled only (host allowlist) |

Both conditions are checked in `lib/core/l10n/remote/remote_translation_config.dart` and AGAIN inside `RemoteTranslationService`.
The allowlist is exact: `https`, the exact host, no user-info, no custom port (443 is fine), no query/fragment; no sub-domain, no
trailing dot, no look-alike host. A build requests only paths on its own `API_BASE_URL`, so a staging build never reads production
and a production build never reads staging. The temporary master-OTP rule (`isStagingApiUrl` in `staging_gate.dart`) is separate and
unchanged.

> **Production host: UNVERIFIED, owner must verify.** It is configured in exactly one place:
> `lib/core/l10n/remote/remote_translation_config.dart`, constant `kRemoteProductionHost` (currently
> `offro-backend-production.up.railway.app`). That value came from a comment in `lib/core/constants/app_constants.dart` (line 10);
> nothing in this repo proves it. The real production `API_BASE_URL` is NOT stored in the repo (it is a build-time
> `--dart-define`; `codemagic.yaml` builds iOS against staging, and `525ce55ce_build_release_offro.ps1` passes no define).
> How to verify, then fix the constant (and the pinned value in `test/remote_translation_environments_test.dart`) if needed:
> 1. Railway -> production service -> Settings -> Networking -> the public domain used by the live app.
> 2. The exact `--dart-define=API_BASE_URL=...` of the build that is live in the store (your build notes/CI history). Optionally
>    inspect the released APK: `unzip -p app-release.apk lib/arm64-v8a/libapp.so | strings | findstr /i railway.app`
>    (string constants normally appear there).
> 3. Open `https://<host>/translations/manifest` (JSON, `schema: 1`) and sign in to the dashboard of that same backend ->
>    Translations -> Overview must say **production**.
> A wrong value fails safe: production builds just keep bundled text.

When off, `main.dart` installs the plain generated `AppLocalizations.delegate`, `RemoteTranslationService` does nothing (no
request, no cache read, no listeners).

## Flow
1. `main()` loads the language, then `RemoteTranslationService.init()` loads the cached published set (if fresh and written by the
   same environment) so Arabic shows the last published text at once, even offline; `attach()` starts listening for "Arabic
   selected" and "app resumed".
2. A refresh runs on startup, when Arabic is selected, and on resume (throttled). English users make no requests.
3. Refresh: `GET /translations/manifest` -> kill switch / Arabic published? -> same version+hash as in use: only the cache
   timestamp is refreshed -> else `GET /translations/ar?track=app`, validate, write cache, switch overrides in one step.
4. `MaterialApp` rebuilds (it listens to the service) and `RemoteAwareLocalizationsDelegate` reloads: `AppLocalizationsArRemote`
   (generated) returns the remote text per key or the bundled Arabic.
5. Kill switch ON, Arabic unpublished: cache and overrides removed, UI returns to bundled Arabic live. Network/HTTP/format errors:
   whatever is in use stays in use; nothing is shown to the user and the app always opens with bundled text.

## What the app does NOT do
* It never requests the `legal` track. Legal text edited in the dashboard is stored and versioned but is **not delivered to the app**
  (a separate, tested change would be needed).
* It sends no credentials, cookies or tokens with translation requests (only `Accept: application/json`).
* It does not touch OTP, login, registration or role selection.

## ETag (conditional requests)
Both requests are conditional. The backend sends an `ETag` with `/translations/manifest` (changes with the manifest) and
`/translations/ar` (the file hash) and answers **304** when `If-None-Match` matches.
* The app stores the ETag it received, together with the exact body it belongs to, in `SharedPreferences`, **labelled with the
  environment** (`staging` / `production`). Language ETag: inside `remote_l10n_cache_v1_ar`. Manifest (body + ETag):
  `remote_l10n_manifest_v1`. Storage survives app restarts.
* Next request: `If-None-Match: <stored ETag>`. **304** -> the stored, previously validated copy is used (nothing downloaded). **200** ->
  the new body is validated, stored with its new ETag and applied.
* Only a well-formed ETag (quoted, printable, <= 200 chars, strong or weak) is stored or sent. A server that sends none, or a
  malformed one, simply gets unconditional requests, as before.
* A 304 is accepted only if the app actually sent `If-None-Match`; otherwise it counts as a failure. A language 304 is also checked
  against the manifest (stored version must not be older; same version must have the same hash), else it is rejected.
* **The existing version + SHA-256 hash validation is unchanged** and still decides what is applied (same version+hash = no
  download; newer = download; inconsistent = rejected).
* No cross-environment reuse: a stored ETag/body whose environment label differs (or is missing) is ignored and replaced. Kill
  switch or unpublish removes the stored language set and its ETag.
* Network failure, timeout, HTTP error or bad data: the set in use (stored or bundled) stays; ETags are never damaged by a failure.
* Headers sent: only `Accept` and, when a stored ETag exists, `If-None-Match`. No credentials.

## Validation (second line of defence, mirrors the backend rules)
Language code, key names (must be a bundled key), non-empty text, max 2000 chars, no control/hidden/bidi-override characters
(ZWNJ/ZWJ/LRM/RLM/ALM allowed), no HTML, placeholders identical to the bundled definition. Bad entries are skipped (bundled text
stays); a file that is structurally wrong, stale, inconsistent with the manifest hash, or >25% invalid is rejected whole.

## Cache
`SharedPreferences` key `remote_l10n_cache_v1_ar` (validated data only) with an `environment` label (`staging` / `production`).
A cache whose label does not match the running build, or has none, is ignored and replaced by the next refresh (a staging APK
installed over a production app shares storage; this keeps the two apart). Used when fresher than 14 days (age = last time the
backend confirmed the version). Removed on kill switch / unpublish. Corrupt or expired cache = bundled text. The first launch after
updating from the earlier staging-only build ignores its unlabelled cache once and downloads again.

## Regenerating the override layer
After `flutter gen-l10n` (any ARB key/placeholder change): `python tools/gen_remote_l10n.py` (`--check` verifies). The test
`test/remote_translation_localizations_test.dart` also fails when the generated files drift from `lib/l10n/app_en.arb`.

## Build (Windows CMD, from the project root)
Staging: `tools\build_staging_apk.cmd`, or
```
flutter pub get
flutter build apk --release --dart-define=API_BASE_URL=https://offro-backend-staging-d375.up.railway.app --dart-define=ENABLE_REMOTE_TRANSLATIONS=true
```
Production (only after the go-live checklist, with the owner-verified production host): `tools\build_production_apk.cmd <production-api-origin>`, or
```
flutter build apk --release --dart-define=API_BASE_URL=<production-api-origin> --dart-define=ENABLE_REMOTE_TRANSLATIONS=true
```
Keep your usual production signing / razorpay patch steps exactly as you do today.
