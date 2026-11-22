// lib/core/l10n/remote/remote_translation_config.dart
//
// Remote (admin-published) translations: the build-time switch and the exact HTTPS host allowlist.
//
//   Staging build:
//     flutter build apk --release \
//       --dart-define=API_BASE_URL=https://offro-backend-staging-d375.up.railway.app \
//       --dart-define=ENABLE_REMOTE_TRANSLATIONS=true
//   Production build:
//     flutter build apk --release \
//       --dart-define=API_BASE_URL=<the production API origin, see [kRemoteProductionHost]> \
//       --dart-define=ENABLE_REMOTE_TRANSLATIONS=true
//
// Default OFF. Two independent conditions must BOTH hold:
//   1. the build was made with ENABLE_REMOTE_TRANSLATIONS=true (approved configuration), and
//   2. its API_BASE_URL is, character for character, one of the two known translation servers (below).
// A build only ever talks to the single host in its own API_BASE_URL, so a staging build talks only to staging and a production
// build only to production; there is no code path that reads from the other environment. Without both conditions the app uses only
// the translations bundled in the app, exactly as before.
//
// This file does NOT touch the staging-only master OTP rule (`isStagingApiUrl` in staging_gate.dart), which stays exactly as it was.

import '../../constants/app_constants.dart' show kBaseUrl;
import '../../services/staging_gate.dart' show kStagingApiHost;

/// The staging translation server (same host as the staging backend).
const String kRemoteStagingHost = kStagingApiHost;

/// The production translation server (the production backend).
///
/// RELEASE BLOCKER: this value came from a comment in app_constants.dart and has NOT been verified against the real Railway
/// production domain. The owner must confirm it (it must be exactly the host the production app already uses as API_BASE_URL)
/// before any production build is released. A wrong value fails SAFE: remote translations simply stay off in production builds.
const String kRemoteProductionHost = 'offro-backend-production.up.railway.app';

/// Build-time flag. Default false.
const bool kEnableRemoteTranslations =
    bool.fromEnvironment('ENABLE_REMOTE_TRANSLATIONS', defaultValue: false);

enum RemoteTranslationEnvironment { staging, production }

/// Which translation server [url] is, or null when it is neither. EXACT match only: https, the exact host, no user-info, no custom
/// port (443 is the same as none), no query or fragment. No sub-domain, no trailing dot, no look-alike host; the host name
/// appearing in a path, in user-info or inside a longer host does not count. Empty, blank or unparsable values give null.
RemoteTranslationEnvironment? remoteTranslationEnvironmentOf(String url) {
  final u = Uri.tryParse(url.trim());
  if (u == null) return null;
  if (u.scheme != 'https' ||
      u.userInfo.isNotEmpty ||
      (u.hasPort && u.port != 443) ||
      u.hasQuery ||
      u.hasFragment) {
    return null;
  }
  if (u.host == kRemoteStagingHost) return RemoteTranslationEnvironment.staging;
  if (u.host == kRemoteProductionHost) {
    return RemoteTranslationEnvironment.production;
  }
  return null;
}

/// True only for an allowlisted translation server (see [remoteTranslationEnvironmentOf]).
bool isRemoteTranslationsApiUrl(String url) =>
    remoteTranslationEnvironmentOf(url) != null;

/// Whether remote translations may run for the given flag and backend URL. Pure, so it can be tested for every combination.
bool remoteTranslationsAllowed(
        {bool flag = kEnableRemoteTranslations, String baseUrl = kBaseUrl}) =>
    flag && isRemoteTranslationsApiUrl(baseUrl);
