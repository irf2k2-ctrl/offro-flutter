# Phase J – Batch 2 (Customer) – localization inventory

Base: `a235935` (Flutter `origin/staging`). Branch: `phasej/batch2-customer-localization` (uncommitted).

## Counts
- ARB keys: 160 → 479 (**319 new keys**), English and Arabic have identical key sets; no Batch 1 key changed or removed.
- Candidate user-visible English string literals in Customer-scope files (heuristic scan, same script before and after):
  **524 → 172**. What is left is explained below; none of it is customer-visible English text that was skipped by mistake.

| File | before | after |
|---|---:|---:|
| lib/main.dart (customer screens; Home was Batch 1) | 235 | 76 |
| lib/screens/home/explore_tab.dart | 17 | 3 |
| lib/screens/home/profile_tab.dart | 2 | 0 |
| lib/screens/home/support_info_note.dart | 1 | 1 |
| lib/screens/favorites/favorites_page.dart | 5 | 0 |
| lib/screens/qr/qr_page.dart | 8 | 2 |
| lib/screens/wallet/wallet_page.dart (Rewards + Scan History) | 50 | 1 |
| lib/screens/store/store_detail_page.dart | 4 | 7 |
| lib/screens/store/widgets/* (8 files) | 83 | 10 |
| lib/screens/location/location_screen.dart | 30 | 7 |
| lib/core/widgets/store_cards.dart | 14 | 10 |
| lib/screens/legal/privacy_policy_page.dart (+ Delete Account) | 28 | 5 |
| lib/screens/loading/location_loading_screen.dart | 6 | 6 |
| lib/core/services/error_mapper.dart | 41 | 44 |

## What remains, and why
1. **Identity / logic keys kept in English on purpose (display is translated through a helper):** filter value `'All'`, `'Ending soon'`;
   tab identities in `store_detail_page.dart` (`'About'`…); `'Profile'` nav identity; store status `'Open'`/`'Closed'` identity strings;
   badge map keys/fallback labels (`store_header.dart`, `_badgeRibbonMeta`, `store_cards.dart` `'New Store'` etc.); delete-account reason
   values (English is what is sent to the server; shown text is translated); loading-screen step list (shown through `localizedLoadingStep`);
   the `_vmo`-style guards `'months['`; the generated `"<n>% OFF"` string in `store_products_section.dart` (shown through `localizedDiscountLabel`).
2. **Fallback data lists shown through helpers:** the 12 built-in fallback categories and subtitles in `main.dart`.
3. **Data, not UI copy:** city names in `location_screen.dart` (`Mumbai`, `New Delhi`, …), `'Guest'` name passed to `_enterHome` (stored name), URLs/ids/log tags.
4. **English by design, per decision below:** share captions (`Share.share` text in product dialog, `product_share_card.dart`), `error_mapper.dart` English
   branch (the no-`l10n` path keeps the old text exactly), `kProfileSupportNote` constant (reference constant, widget uses `profileSupportNote`).
5. **Backend-supplied text** (error/business messages, legal body, store/product/deal content, merchant-written badges/subtitles) is shown as received.

## Not in this batch (listed so nothing is lost)
- Merchant (`merchant_screens.dart`, `products_phase2.dart`, `payment_success_screen.dart`), Influencer (`influencer_section.dart`, `my_influencer_profile.dart`, `collab_screens.dart`),
  Auth/onboarding/splash (`login_screen.dart`, `onboarding_screen.dart`, `splash_screen.dart`, `location_access_*`), shared notification diagnostics.
- No "My Account" / "Edit Profile" screen exists in the app: the customer profile only has the support note ("contact support to update your profile"), now translated.
