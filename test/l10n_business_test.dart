// Phase J, batch 3: Merchant and Influencer screens in English and Arabic.
// Needs the generated localizations (lib/l10n/gen): run `flutter gen-l10n` first.
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:offro_user/core/l10n/l10n.dart';
import 'package:offro_user/core/l10n/locale_controller.dart';
import 'package:offro_user/core/services/error_mapper.dart';
import 'package:offro_user/l10n/gen/app_localizations_ar.dart';
import 'package:offro_user/l10n/gen/app_localizations_en.dart';

Widget app(Widget home, {Locale locale = const Locale('en')}) => MaterialApp(
      locale: locale,
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: home,
    );

Future<T> run<T>(WidgetTester t, Locale l, T Function(BuildContext) f) async {
  late T out;
  await t.pumpWidget(app(Builder(builder: (c) { out = f(c); return const SizedBox(); }), locale: l));
  return out;
}

void main() {
  const ar = Locale('ar');
  const enL = Locale('en');
  final en = AppLocalizationsEn();
  final arL = AppLocalizationsAr();

  group('ARB files (business keys)', () {
    final enArb = jsonDecode(File('lib/l10n/app_en.arb').readAsStringSync()) as Map<String, dynamic>;
    final arArb = jsonDecode(File('lib/l10n/app_ar.arb').readAsStringSync()) as Map<String, dynamic>;
    Iterable<String> bizKeys() => enArb.keys.where((k) => k.startsWith('biz'));
    Set<String> ph(String s) => RegExp(r'\{(\w+)\}').allMatches(s).map((m) => m.group(1)!).toSet();

    test('the business keys exist in both languages with the same placeholders', () {
      expect(bizKeys().length, greaterThan(500));
      for (final k in bizKeys()) {
        expect(arArb.containsKey(k), isTrue, reason: k);
        expect(ph(arArb[k] as String), ph(enArb[k] as String), reason: k);
      }
    });

    test('every business key has a description (translator note)', () {
      for (final k in bizKeys()) {
        expect(enArb['@$k'], isA<Map>(), reason: k);
        expect((enArb['@$k'] as Map)['description'], isNotEmpty, reason: k);
      }
    });

    test('every Arabic business value is translated and uses Western digits only', () {
      final letters = RegExp(r'[\u0600-\u06FF]');
      final arabicIndic = RegExp(r'[\u0660-\u0669\u06F0-\u06F9]');
      for (final k in bizKeys()) {
        final v = arArb[k] as String;
        expect(letters.hasMatch(v), isTrue, reason: '$k is not translated');
        expect(arabicIndic.hasMatch(v), isFalse, reason: k);
      }
    });
  });

  group('English is exactly what the Merchant and Influencer screens showed before', () {
    test('selected texts', () {
      expect(en.bizAddStore, 'Add Store');
      expect(en.bizCreateStore, 'Create Store');
      expect(en.bizSaveChanges, 'Save Changes');
      expect(en.bizMyDeals, 'My Deals');
      expect(en.bizAddDeal, 'Add Deal');
      expect(en.bizDeleteDeal, 'Delete Deal?');
      expect(en.bizPayNow, 'Pay Now');
      expect(en.bizConfirmPayment, 'Confirm Payment');
      expect(en.bizSubscribeStore, 'Subscribe Store');
      expect(en.bizNoInvoicesYet, 'No invoices yet');
      expect(en.bizDownloadPDF, 'Download PDF');
      expect(en.bizBusinessTimeline, 'Business timeline');
      expect(en.bizProductAnalytics, 'Product Analytics');
      expect(en.bizPaymentSuccessful, 'Payment Successful!');
      expect(en.bizCreateCampaignBrief, 'Create campaign brief');
      expect(en.bizAcceptCollaboration, 'Accept collaboration');
      expect(en.bizDecline, 'Decline');
      expect(en.bizSavePublish, 'Save & Publish');
      expect(en.bizDeleteInfluencerProfile, 'Delete Influencer Profile?');
      expect(en.bizYourProfileIsLive, 'Your profile is live');
      expect(en.bizCollaborations, 'Collaborations');
      expect(en.bizCloseCampaign2, 'Close campaign');
      expect(en.bizPublishBrief, 'Publish brief');
      expect(en.bizMERCHANTWORKSPACE, 'MERCHANT WORKSPACE');
      expect(en.bizINFLUENCERWORKSPACE, 'INFLUENCER WORKSPACE');
      expect(en.bizStoreNameRequired, 'Store name required');
      expect(en.bizBannerSubmitted, 'Banner submitted');
      expect(en.bizRenewProduct, 'Renew Product');
      expect(en.bizPremiumListingAnalytics, 'Premium Listing Analytics');
      expect(en.bizChatOnWhatsApp, 'Chat on WhatsApp');
    });

    test('texts with placeholders', () {
      expect(en.bizWelcomeBackName('Sam'), 'Welcome back, Sam');
      expect(en.bizFreeSlotsUsedOf('1', '3'), '1/3 free slots used');
      expect(en.bizPaymentFailedMsg('x'), 'Payment failed: x');
      expect(en.bizGstPct('18'), 'GST (18%)');
      // The money text (symbol included) is passed in, so one translation serves every currency.
      expect(en.bizPayAmount('₹99'), 'Pay ₹99');
      expect(en.bizPayAmount('SAR 99'), 'Pay SAR 99');
      expect(en.bizPricePlusGst('SAR 100', '15', 'VAT'), 'SAR 100 + 15% VAT');
      expect(en.bizPricePlusGst('₹499', '18', 'GST'), '₹499 + 18% GST');
      expect(en.bizBaseGstLine('SAR 100.00', 'SAR 15.00', 'VAT'), 'Base: SAR 100.00  VAT: SAR 15.00');
      expect(en.bizFree0('₹0'), 'Free (₹0)');
      expect(en.bizFree0('SAR 0'), 'Free (SAR 0)');
      expect(en.bizPerDayPrice('SAR 2'), 'SAR 2/day');
      expect(en.bizNDays('30'), '30 Days');
      expect(en.bizPublishByDate('5 Mar 2026'), 'Publish by 5 Mar 2026');
      expect(en.bizSeeAllRequests('4'), 'See all 4 requests');
      expect(en.bizProductsExpiringOne, '1 product expiring soon — tap to renew');
      expect(en.bizProductsExpiringMany('3'), '3 products expiring soon — tap to renew');
      expect(en.bizStoresActiveOne('1'), '1 Store • 1 Active');
      expect(en.bizStoresActiveMany('2', '1'), '2 Stores • 1 Active');
      expect(en.bizDiscountTotalPct('₹10.00', '10', '₹90.00'), '−₹10.00 (10%) off  →  Total: ₹90.00');
      expect(en.bizDiscountTotalAmt('SAR 5', 'SAR 95.00'), '−SAR 5 off  →  Total: SAR 95.00');
      expect(en.bizDeleteDealNamed('Sale'), 'Delete "Sale"?');
    });
  });

  group('Arabic text', () {
    test('placeholders are filled and digits stay Western', () {
      expect(arL.bizWelcomeBackName('سام'), 'مرحبًا بعودتك، سام');
      expect(arL.bizFreeSlotsUsedOf('1', '3'), 'تم استخدام 1/3 من الفتحات المجانية');
      expect(arL.bizSeeAllRequests('4'), contains('4'));
      expect(arL.bizPayAmount('₹99'), 'ادفع ₹99');
      expect(arL.bizPayAmount('SAR 99'), 'ادفع SAR 99');
      expect(arL.bizPricePlusGst('₹499', '18', 'GST'), '₹499 + 18% ضريبة GST');
      expect(arL.bizProductsExpiringMany('3'), contains('3'));
    });

    test('Merchant and Influencer use the same Arabic term for the same word', () {
      // One glossary for both modules: Banner = بانر, Deal = عرض, Store = متجر, Subscription = اشتراك, Campaign = حملة.
      expect(arL.bizBannerSubmitted, contains('بانر'));
      expect(arL.bizBannerApproved, contains('بانر'));
      expect(arL.bizStoreApproved, contains('متجر'));
      expect(arL.bizDealAdded, contains('عرض'));
      expect(arL.bizSubscriptionRequestSent, contains('اشتراك'));
      expect(arL.bizCampaignBrief, contains('حملة'));
      expect(arL.bizCreateCampaignBrief, contains('حملة'));
    });

    test('brand and technical names stay in Latin letters', () {
      expect(arL.bizChatOnWhatsApp, contains('WhatsApp'));
      expect(arL.bizInstagramURL, contains('Instagram'));
      expect(arL.bizDownloadPDF, contains('PDF'));
    });
  });

  group('helpers', () {
    testWidgets('month names in English and Arabic', (t) async {
      expect(await run(t, enL, (c) => monthsShortOf(c.l10n)),
          ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec']);
      final m = await run(t, ar, (c) => monthsShortOf(c.l10n));
      expect(m.toSet().length, 12);
      expect(m.contains('Jan'), isFalse);
    });

    testWidgets('merchant delete-account reasons: display translated, the value sent to the server stays English', (t) async {
      const reasons = [
        'I no longer run my business',
        'I have privacy concerns',
        'I have a duplicate account',
        'The app is not working properly for me',
        'Too many notifications or irrelevant content',
        'Other',
      ];
      for (final r in reasons) {
        expect(await run(t, enL, (c) => localizedDeleteReason(c, r)), r);
        expect(await run(t, ar, (c) => localizedDeleteReason(c, r)), isNot(r));
      }
    });

    test('text without a BuildContext follows the chosen app language', () async {
      SharedPreferences.setMockInitialValues({});
      await LocaleController.instance.setLanguage('en');
      expect(offroNoContext.timeAgoJustNow, 'just now');
      expect(offroNoContext.timeAm, 'AM');
      await LocaleController.instance.setLanguage('ar');
      expect(offroNoContext.timeAgoJustNow, arL.timeAgoJustNow);
      expect(offroNoContext.timeAgoJustNow, isNot('just now'));
      await LocaleController.instance.setLanguage('en');
    });

    test('payment error messages: English unchanged, Arabic with l10n', () {
      expect(friendlyRazorpayError(null), 'Payment could not be completed. Please try again.');
      expect(friendlyRazorpayError('', l10n: en), 'Payment could not be completed. Please try again.');
      expect(friendlyRazorpayError(null, l10n: arL), arL.errPayNoMessage);
      expect(friendlyRazorpayError('Card declined by your bank', l10n: arL), 'Card declined by your bank');
      expect(friendlyRazorpayError('PlatformException(E123)', l10n: arL), arL.errPayGeneric);
      expect(friendlyRazorpayError('PlatformException(E123)'), "We couldn't complete your payment. Please try again.");
    });
  });

  // Ratchet: sentences migrated in this batch must not come back as hard-coded literals in the same file.
  group('no hard-coded copies of migrated Merchant and Influencer text', () {
    String strip(String s) {
      final noBlock = s.replaceAll(RegExp(r'/\*[\s\S]*?\*/'), '');
      return noBlock.split('\n').map((l) => l.replaceAll(RegExp(r'''(?<![:'"])//.*$'''), '')).join('\n');
    }

    int count(String code, String v) {
      final lit = v.replaceAll('\n', r'\n');
      return "'$lit'".allMatches(code).length + '"$lit"'.allMatches(code).length;
    }

    final guard = <String, List<String>>{
    'lib/screens/merchant/merchant_screens.dart': [
      en.bizAdd,
      en.bizNoStoresYetTapTo,
      en.bizSubscribeYourStoreToCreate,
      en.bizNoBannersYetPromoteYour,
      en.bizSubscribeYourStoreToAdd,
      en.bizNoProductsYetAddYour,
      en.bizMERCHANTWORKSPACE,
      en.bizWelcomeBack,
      en.bizCouldnTLoadYourDashboard,
      en.bizLiveStores,
      en.bizLiveBanners,
      en.bizLiveProducts,
      en.bizMANAGEYOURBUSINESS,
      en.bizMyStore,
      en.bizMyBanner,
      en.bizMyProducts,
      en.bizCreatorCollaborations,
      en.bizBriefMatchAndManageLocal,
      en.bizSubscribeYourStoreToWork,
      en.bizLocked,
      en.bizManage,
      en.bizPromotions,
      en.bizMyBanners,
      en.bizNewBanner,
      en.bizCouldnTLoadBanners,
      en.bizNoBannersYet,
      en.bizTapToCreateYourFirst,
      en.bizApprovedLive,
      en.bizRejected,
      en.bizRemovedByAdmin,
      en.bizTurnedOff,
      en.bizPendingApproval,
      en.bizSubmitted,
      en.bizEditBannerTitle,
      en.bizBannerTitle,
      en.bizSave,
      en.bizEditTitle,
      en.bizTurnOffBanner,
      en.bizTurnOnBanner,
      en.bizThisBannerWillBeHidden,
      en.bizThisBannerWillGoLive,
      en.bizTurnOff,
      en.bizTurnOn,
      en.bizExpiredChooseANewStart,
      en.bizRenew,
      en.bizRejectedCreateANewBanner,
      en.bizCreateNew,
      en.bizRemovedByAdmin2,
      en.bizAwaitingAdminApproval,
      en.bizImageTooLargeMax2MB,
      en.bizVideoIsTooLargePlease,
      en.bizVideoIsTooLongPlease,
      en.bizCouldNotReadThisVideo,
      en.bizCouldNotUploadTheVideo,
      en.bizExistingBannerVideoWillBe,
      en.bizTapToReplace,
      en.bizTapToSelectBannerVideo,
      en.biz10801080px11,
      en.bizMax15Sec10MB,
      en.bizBannerTitleRequired,
      en.bizPleaseSelectAStore,
      en.bizPleaseSelectACity,
      en.bizPleaseSelectABannerVideo,
      en.bizPleaseUploadABannerImage,
      en.bizEnterNumberOfDaysMinimum,
      en.bizUntitledDeal,
      en.bizUntitledProduct,
      en.bizCTADestination,
      en.bizChooseWhereThisBannerShould,
      en.bizSelectDeal,
      en.bizSelectProduct,
      en.bizCustomersWillOpenTheSelected,
      en.bizNothingSelectedYetTheBanner,
      en.bizDiscountApplied,
      en.bizPaymentGatewayNotConfiguredContact,
      en.bizCouldNotOpenPaymentPlease,
      en.bizBannerOrderSummary,
      en.bizTitle,
      en.bizDuration,
      en.bizRate,
      en.bizBasePrice,
      en.bizDiscount,
      en.bizTotal,
      en.bizYourBannerWillBeSubmitted,
      en.bizRazorpayCheckoutWillOpenBanner,
      en.bizConfirmSubmit,
      en.bizRenewBanner,
      en.bizCreateBanner,
      en.bizBannerTitle2,
      en.bizEG50OFFAt,
      en.bizSelectStore,
      en.bizUnnamedStore,
      en.bizCityAutoFilledFromStore,
      en.bizImage,
      en.bizVideo,
      en.bizTapToUploadBannerImage,
      en.bizMax2MB,
      en.bizDurationStartDate,
      en.bizNumberOfDays,
      en.bizFromDate,
      en.bizActivePeriod,
      en.bizDiscountCode,
      en.bizHaveAPromoCodeEnter,
      en.bizEGOFFRO20,
      en.bizApply,
      en.bizProceedToCheckout,
      en.bizLive,
      en.bizFilterProducts,
      en.bizEditProduct,
      en.bizAnalytics,
      en.bizDeleteProduct,
      en.bizCatalogue,
      en.bizFilter,
      en.bizNewProduct,
      en.bizSearchProducts,
      en.bizPending,
      en.bizCouldnTLoadProducts,
      en.bizNoProductsYet,
      en.bizNoMatchingProducts,
      en.bizTapNewProductToGet,
      en.bizPaused,
      en.bizFree,
      en.bizPaid,
      en.bizDeactivated,
      en.bizOn,
      en.bizOff,
      en.bizOfferText,
      en.bizOriginalPrice,
      en.bizOfferPrice,
      en.bizProductUpdated,
      en.bizDeleteThisProduct,
      en.bizProductDeleted,
      en.bizLogoTooLargeMax1MB,
      en.bizEnterACode,
      en.bizProductTitleRequired,
      en.bizPleaseSelectAStoreFor,
      en.bizPleaseSelectACityFor,
      en.bizPleaseUploadAProductImage,
      en.bizEnterTheNumberOfDays,
      en.bizProductOrderSummary,
      en.bizPrice,
      en.bizProductWillGoToAdmin,
      en.bizRazorpayOpensProductLiveAfter,
      en.bizSaveProduct,
      en.bizAddProduct,
      en.bizProductTitle,
      en.bizEGRajStore50,
      en.bizEGGet50Off,
      en.bizDiscountIsAutoCalculatedFrom,
      en.bizUploadImage,
      en.biz400400px,
      en.bizMax1MB,
      en.bizValidityDays,
      en.bizStartDate,
      en.bizEndDate,
      en.bizNumberOfDays2,
      en.bizLivePeriod,
      en.bizFree0('₹0'),
      en.bizFreeProduct,
      en.bizYourBusiness,
      en.bizMyStores,
      en.bizTapToAddYourFirst,
      en.bizActive,
      en.bizDraft,
      en.bizInactive,
      en.bizDeleted,
      en.bizRemoved,
      en.bizSubscribe,
      en.bizAwaitingAdminApproval2,
      en.bizQR,
      en.bizGenQR,
      en.bizShowThisToCustomersTo,
      en.bizDeviceLocationIsTurnedOff,
      en.bizUnableToIdentifyTheExact,
      en.bizCity,
      en.bizState,
      en.bizArea,
      en.bizPostalCode,
      en.bizLocationCaptured,
      en.bizImageTooLargeMax2MB2,
      en.bizStoreNameRequired,
      en.bizPleaseSetTheStoreLocation,
      en.bizMobileNumberIsRequired,
      en.bizEnterAValid10Digit,
      en.bizEditStore,
      en.bizAddStore,
      en.bizStoreName,
      en.bizCategory,
      en.bizSelectCategory,
      en.bizStoreLocation,
      en.bizUseGPSOrPasteA,
      en.bizUseCurrentLocation,
      en.bizOrPasteGoogleMapsLink,
      en.bizPasteGoogleMapsLinkHere,
      en.bizResolveLocation,
      en.bizLatitude,
      en.bizLongitude,
      en.bizAutoFilledByGPSOr,
      en.bizPhone,
      en.bizTapToChangeImage,
      en.bizMainStoreImage,
      en.biz800600px43,
      en.bizUploadLogoOptional,
      en.bizTapToChangeLogo,
      en.bizTapToUploadLogo,
      en.biz200200px11,
      en.bizStoreTimingsOptional,
      en.bizOpeningTime,
      en.bizOpenAt,
      en.bizClosingTime,
      en.bizCloseAt,
      en.bizAboutThisStoreDescriptionShown,
      en.bizSaveChanges,
      en.bizCreateStore,
      en.bizConfirmingPayment,
      en.bizPleaseWaitAMoment,
      en.bizSubscriptionRequestSent,
      en.bizFrom,
      en.bizTo,
      en.bizTotalPayable,
      en.bizYourSubscriptionRequestHasBeen,
      en.bizConfirmPayment,
      en.bizRazorpayCheckoutWillOpenAfter,
      en.bizPayNow,
      en.bizSubscribeStore,
      en.bizSelectPlan,
      en.bizStartDate2,
      en.bizHaveADiscountCode,
      en.bizEnterCode,
      en.bizRemove,
      en.bizProceedToPay,
      en.bizRefresh,
      en.bizNoInvoicesYet,
      en.bizPullDownToRefresh,
      en.bizShare,
      en.bizDownloadPDF,
      en.bizAccountRegistered,
      en.bizNewStoreCreated,
      en.bizStoreProfileUpdated,
      en.bizStoreApproved,
      en.bizStoreRejected,
      en.bizStoreSubscriptionActivated,
      en.bizFreeSubscriptionActivated,
      en.bizSubscriptionPaymentReceived,
      en.bizBannerSubmitted,
      en.bizBannerApproved,
      en.bizBannerRejected,
      en.bizBannerPaymentReceived,
      en.bizProductSubmitted,
      en.bizProductApproved,
      en.bizProductRejected,
      en.bizProductPaymentReceived,
      en.bizPaymentReceived,
      en.bizFreePlanActivated,
      en.bizProfileUpdated,
      en.bizQRCodeRegenerated,
      en.bizPayment,
      en.bizApprovedLive2,
      en.bizRejected2,
      en.bizPendingApproval2,
      en.bizBusinessTimeline,
      en.bizNoActivityYet,
      en.bizMerchantAccount,
      en.bizTapPhotoToChange,
      en.bizSwitchBetweenUserMerchantInfluencer,
      en.bizKYCPolicy,
      en.bizMerchantOffers,
      en.bizMyDeals,
      en.bizAddDeal,
      en.bizYouNeedAnActiveStore,
      en.bizNoDealsYet,
      en.bizAddDealsToAttractMore,
      en.bizEditDeal,
      en.bizDeleteDeal,
      en.bizDelete,
      en.bizDealTitleIsRequired,
      en.bizEndDateIsRequired,
      en.bizPleaseAddAnImageBefore,
      en.bizDealUpdated,
      en.bizDealAdded,
      en.bizDealTitleEG20,
      en.bizDescriptionOptional,
      en.bizDealImage,
      en.bizTapToReplaceImage,
      en.bizMax2MBRequired,
      en.bizSelectEndDate,
      en.bizAllYourStoresProductsData,
      en.bizOnceYourAccountIsDeleted,
      en.bizYourMerchantAccountWillBe,
      en.bizThisProduct,
      en.bizCouldNotOpenPayment,
      en.bizSubmittedPayRep,
      en.bizSubmittedWord,
      en.bizUntitledWord,
      en.bizAllProducts,
      en.bizAllStores,
      en.bizBannersTab,
      en.bizPaymentsTab,
      en.bizBillingSubscriptions,
    ],
    'lib/screens/influencer/my_influencer_profile.dart': [
      en.bizWelcomeBack,
      en.bizSave,
      en.bizImageTooLargeMax2MB,
      en.bizPleaseSelectACity,
      en.bizPaymentGatewayNotConfiguredContact,
      en.bizCouldNotOpenPaymentPlease,
      en.bizDiscount,
      en.bizApply,
      en.bizCity,
      en.bizState,
      en.bizPhone,
      en.bizConfirmingPayment,
      en.bizPleaseWaitAMoment,
      en.bizTotalPayable,
      en.bizDelete,
      en.bizCreatorAccount,
      en.bizCREATORWORKSPACE,
      en.bizProfileViews,
      en.bizSavedBy,
      en.bizYourProfileIsLive,
      en.bizYourProfileIsnTLive,
      en.bizMerchantsAndCustomersCanDiscover,
      en.bizOpenYourProfileToReview,
      en.bizMATCHEDFORYOU,
      en.bizCampaignOpportunities,
      en.bizINFLUENCERWORKSPACE,
      en.bizCreateYourLocalProfile,
      en.bizYouLlNeedAnInfluencer,
      en.bizAddInfluencerProfile,
      en.bizNotAdded,
      en.bizContinuePublishingPayNow,
      en.bizMyProfile,
      en.bizBusinessDetails,
      en.bizDisplayName,
      en.bizBio,
      en.bizSocialPages,
      en.bizPrimarySpecialty,
      en.bizNoSpecialtySelected,
      en.bizAccountDetails,
      en.bizDisable,
      en.bizEnable,
      en.bizHideYourProfileFromCustomers,
      en.bizMakeYourProfileVisibleAgain,
      en.bizSwitchToYourCustomerAccount,
      en.bizYourProfileIsSavedAs,
      en.bizPaymentIsBeingProcessedIf,
      en.bizYourLastSubscriptionPaymentAttempt,
      en.bizYourProfileIsNotYet,
      en.bizDeleteInfluencerProfile,
      en.bizIfYouCreateANew,
      en.bizDeleteProfile,
      en.bizREVIEWS,
      en.bizCreatorReviews,
      en.bizNameIsRequired,
      en.bizPleaseSelectAState,
      en.bizPleaseEnterAValid10,
      en.bizProfileImageIsRequiredTo,
      en.bizWeCouldnTConfirmYour,
      en.bizCreatorIdentity,
      en.bizEditProfile,
      en.bizAddProfile,
      en.bizRequiredToPublish,
      en.bizName,
      en.bizEGPriyaSharma,
      en.bizSharingTheBestLocalFood,
      en.bizState2,
      en.bizSelectState,
      en.bizCity2,
      en.bizSelectStateFirst,
      en.bizSelectCity,
      en.bizPrimarySpecialtySelectOneOr,
      en.bizNoCategoriesAvailable,
      en.biz10DigitMobileNumber,
      en.bizSocialLinks,
      en.bizInstagramURL,
      en.bizYouTubeURL,
      en.bizFacebookURL,
      en.bizSaveKeepAsDraft,
      en.bizSavePublish,
      en.bizSavePublishPayToPublish,
      en.bizNoSubscriptionPaymentIsCurrently,
      en.bizSubscriptionFee,
      en.bizDiscountCodeOptional,
      en.bizAOneTimePaymentYou,
      en.bizEnterADiscountCodeFirst,
      en.bizSelectSpecialties,
      en.bizCouldNotOpenPayment,
      en.bizOffrOInfluencer,
    ],
    'lib/screens/merchant/products_phase2.dart': [
      en.bizRenew,
      en.bizPaymentGatewayNotConfiguredContact,
      en.bizDiscount,
      en.bizTotal,
      en.bizDiscountCode,
      en.bizHaveAPromoCodeEnter,
      en.bizEGOFFRO20,
      en.bizApply,
      en.bizPrice,
      en.bizPlan,
      en.bizChecking,
      en.bizDiscountApplied2,
      en.bizChooseALaterEndDate,
      en.bizRenewedSuccessfully,
      en.bizRenewalSummary,
      en.bizNewEndDate,
      en.bizFreeRenewal,
      en.bizRenewFree,
      en.bizRenewed,
      en.bizRenewProduct,
      en.bizNoEndDate,
      en.bizChooseHowLongTheProduct,
      en.bizDaysToAdd,
      en.bizProductAnalytics,
      en.bizCouldnTLoadAnalytics,
      en.bizPleaseCheckYourConnectionAnd,
      en.bizPremiumListingAnalytics,
      en.bizViews,
      en.bizShares,
      en.bizStoreVisits,
      en.bizLastSeen,
      en.bizStoreVisitsCustomersWhoVisited,
      en.bizConversionRate,
      en.bizSimilarProducts,
      en.bizThisStore,
      en.bizAdditionalProduct,
    ],
    'lib/screens/home/influencer_section.dart': [
      en.bizCity,
      en.bizInfluencersAreComingSoon,
      en.bizWeReBringingLocalCreators,
      en.bizPeopleShapingTheCity,
      en.bizLocalVoices,
      en.bizPleaseSelectAStarRating,
      en.bizPleaseLogInToSubmit,
      en.bizPleaseWriteAtLeastA,
      en.bizVERIFIEDLOCALVOICE,
      en.bizRating,
      en.bizRateThisInfluencer,
      en.bizShareYourExperienceOptional,
      en.bizUpdateReview,
    ],
    'lib/screens/payment/payment_success_screen.dart': [
      en.bizPaymentSuccessful,
      en.bizYourPurchaseIsNowPending,
      en.bizAdminWillReviewAndActivate,
    ],
    'lib/screens/collab/collab_screens.dart': [
      en.bizCreateBrief,
      en.bizShareWhatYouNeedAnd,
      en.bizInviteCreators,
      en.bizLocalCreatorsInYourCity,
      en.bizConfirmMatch,
      en.bizReviewWhoAcceptedAndConnect,
      en.bizCreator,
      en.bizCollaborations,
      en.bizWorkWithTrustedLocalCreators,
      en.bizCreateOneClearCampaignBrief,
      en.bizHowItWorks,
      en.bizCreateCampaignBrief,
      en.bizYourCampaigns,
      en.bizCollaborationWorkspace,
      en.bizNoCampaignsYet,
      en.bizCreateYourFirstCampaignBrief,
      en.bizWhenShouldYouUseThis,
      en.bizUseCollaborationsForLaunchesVisits,
      en.bizReviewProposals,
      en.bizCloseCampaign,
      en.bizCreatorsWillNoLongerBe,
      en.bizKeepOpen,
      en.bizCampaign,
      en.bizProposals,
      en.bizCreatorsWhoAccepted,
      en.bizNoProposalsYet,
      en.bizCreatorsInYourCityWill,
      en.bizClosing,
      en.bizCloseCampaign2,
      en.bizChatOnWhatsApp,
      en.bizCouldnTOpenWhatsApp,
      en.bizPleaseSelectAStore2,
      en.bizEnterACampaignTitleAt,
      en.bizSelectACampaignObjective,
      en.bizDescribeWhatTheCreatorShould,
      en.bizSelectTheContentYouNeed,
      en.bizChooseAPublishByDate,
      en.bizChooseAVisitDateFor,
      en.bizVisitDateCanTBe,
      en.bizBriefPublishedMatchingCreatorsCan,
      en.bizCampaignBrief,
      en.bizAddAndActivateAStore,
      en.bizSelectStore2,
      en.bizCampaignTitle,
      en.bizExampleSeasonalMenuLaunch,
      en.bizCampaignObjective,
      en.bizSelectObjective,
      en.bizWhatShouldTheCreatorCommunicate,
      en.bizKeyMessageExperienceAndDetails,
      en.bizRequestedContent,
      en.bizVisitDate,
      en.bizSelectDate,
      en.bizPublishBy,
      en.bizPreferredCreatorSpeciality,
      en.bizSelectSpeciality,
      en.bizNoPaymentProcessing,
      en.bizOffrOConnectsYouWithCreators,
      en.bizPublishing,
      en.bizPublishBrief,
      en.bizMatchedLocally,
      en.bizReviewCollaborationRequestsFromReleva,
      en.bizNoCollaborationRequestsYet,
      en.bizRequestsFromMerchantsInYour,
      en.bizAccepted,
      en.bizDeclined,
      en.bizNewCollaborationRequest,
      en.bizViewBrief,
      en.bizNoCampaignRequestsYet,
      en.bizNewBriefsFromMerchantsIn,
      en.bizCollaborationAccepted,
      en.bizRequestDeclined,
      en.bizCollaborationRequest,
      en.bizBrief,
      en.bizCompleteYourProfileSubscriptionTo,
      en.bizObjective,
      en.bizMessage,
      en.bizPreferredSpeciality,
      en.bizThisCollaborationIsForPromotion,
      en.bizYouAcceptedThisCollaboration,
      en.bizTheMerchantSContactNumber,
      en.bizContactTheMerchantToPlan,
      en.bizThisRequestIsNoLonger,
      en.bizPleaseWait,
      en.bizAcceptCollaboration,
      en.bizDecline,
    ],
    };

    for (final entry in guard.entries) {
      test('${entry.key} has no hard-coded copy of its migrated text', () {
        final code = strip(File(entry.key).readAsStringSync());
        final found = <String>[];
        for (final v in entry.value) {
          if (count(code, v) > 0) found.add(v);
        }
        expect(found, isEmpty);
      });
    }
  });
}
