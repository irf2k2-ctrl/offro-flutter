// lib/core/l10n/remote/remote_translation_config.dart
//
// Phase K: the build-time switch for remote (admin-published) translations.
//
//   flutter build apk --release \
//     --dart-define=API_BASE_URL=https://offro-backend-staging-d375.up.railway.app \
//     --dart-define=ENABLE_REMOTE_TRANSLATIONS=true            (staging only)
//
// Default OFF. Two independent conditions must BOTH hold, so a production build can never switch it on by accident:
//   1. the build was made with ENABLE_REMOTE_TRANSLATIONS=true, and
//   2. its API_BASE_URL is exactly the staging backend (the same strict check that guards the staging-only master OTP).
// Without both, the app uses only the translations bundled in the app, exactly as before Phase K.
//
// When remote translations are promoted to production later, change [remoteTranslationsAllowed] deliberately in its own change.

import '../../constants/app_constants.dart' show kBaseUrl;
import '../../services/staging_gate.dart' show isStagingApiUrl;

/// Build-time flag. Default false.
const bool kEnableRemoteTranslations =
    bool.fromEnvironment('ENABLE_REMOTE_TRANSLATIONS', defaultValue: false);

/// Whether remote translations may run for the given flag and backend URL. Pure, so it can be tested for every combination.
bool remoteTranslationsAllowed(
        {bool flag = kEnableRemoteTranslations, String baseUrl = kBaseUrl}) =>
    flag && isStagingApiUrl(baseUrl);
