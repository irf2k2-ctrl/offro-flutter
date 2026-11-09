# Staging-only MSG91 token-field probe on the latest Staging UI (NEVER merge, never ship)

Branch `staging/msg91-probe-latest-ui`, built from `origin/staging` `8b1ee0c` (1.0.9+56). The redesigned screens are untouched:
the only change inside `login_screen.dart` is 7 added lines (3 imports, 2 probe-capture lines in `_verify`, 2 link lines that
render only when the probe is on). Normal login, `1234` master-OTP behaviour on this base, and every other screen are unchanged.

## What it does
After you press Verify, the redacted SHAPE of MSG91's `verifyOTP` response is captured IN MEMORY and shown on a
"Diagnostic Results" screen (link at the bottom of the OTP screen and of the login screen). Statuses:
`Probe completed` / `Probe failed` / `No diagnostic result yet`; a "Copy Safe Diagnostic Result" button; a Clear button.
Wrong-code attempts are captured too (if the SDK throws instead, only "verify call threw an exception (details withheld)" is kept).

## Safety
* Active only with ALL of: `--dart-define=OTP_TOKEN_PROBE=true`, a debug build, and an `API_BASE_URL` whose https host is exactly
  `offro-backend-staging-d375.up.railway.app`. Otherwise the link is not drawn and nothing is captured.
* Allowlist redaction (same as the reviewed probe): unknown key names -> `<unknown-key#N>`, unknown `type` -> `<other>`, no string
  ever printed (size bucket / JWT shape with allowlisted alg + claim names only).
* The store accepts only a raw response and redacts it itself; it keeps nothing else. In-memory only: no storage, no network,
  no extra logging, cleared when the app restarts. Shown and copied text pass a second scrub (4+ digit runs, split numbers,
  JWT-like strings, e-mails).
* Do NOT type `1234`: on this base it is the existing master-OTP shortcut, skips MSG91, and nothing is captured.

## Commands (run on your machine)
```bash
git clone https://github.com/irf2k2-ctrl/offro-flutter offro_probe && cd offro_probe
git fetch /path/to/staging-probe-latest-ui.bundle staging/msg91-probe-latest-ui:staging/msg91-probe-latest-ui
git checkout staging/msg91-probe-latest-ui
git log --oneline -2                      # tip commit on top of 8b1ee0c
flutter pub get
flutter analyze
flutter test test/otp_token_shape_test.dart test/otp_probe_test.dart
flutter test                              # whole suite (existing tests included)
flutter build apk --debug \
  --dart-define=API_BASE_URL=https://offro-backend-staging-d375.up.railway.app \
  --dart-define=OTP_TOKEN_PROBE=true
# APK: build/app/outputs/flutter-apk/app-debug.apk   (debug build is REQUIRED for the probe to activate)
adb install -r build/app/outputs/flutter-apk/app-debug.apk   # or copy the APK to the phone
```
Sanity: a build WITHOUT `OTP_TOKEN_PROBE=true` (or with a release build) must show no "Diagnostic Results" link.

## On the phone
1. Log in with a number registered on STAGING; wait for the real SMS; type the 4 digits by hand; press Verify.
2. Open "Diagnostic Results" (small underlined link at the bottom of the OTP screen). Expect `Probe completed` and a line
   such as `message: String len=... jwt-like(...)` under "Correct code".
3. Optionally repeat once with a wrong code (go back and request a new OTP if needed); then "Copy Safe Diagnostic Result" and
   paste it to me. It contains no secret by construction.
