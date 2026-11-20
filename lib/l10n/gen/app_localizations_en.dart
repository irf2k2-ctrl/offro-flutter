// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get otpEyebrow => 'VERIFICATION';

  @override
  String get otpTitleLead => 'Verify your';

  @override
  String get otpTitleAccent => 'number';

  @override
  String otpSentTo(String phone) {
    return 'We sent a 4-digit OTP to\n$phone';
  }

  @override
  String get otpVerifyButton => 'Verify OTP';

  @override
  String get otpDidntReceive => 'Didn\'t receive OTP?';

  @override
  String otpResendIn(String seconds) {
    return 'Resend in ${seconds}s';
  }

  @override
  String get otpResendAction => 'Resend OTP';

  @override
  String get otpSmsFallback => 'Send code by SMS instead';

  @override
  String get roleEyebrow => 'MAKE OFFRO YOURS';

  @override
  String get roleTitleLead => 'How will you use';

  @override
  String get roleTitleBrand => 'OffrO?';

  @override
  String get roleSubtitle =>
      'Choose your starting space. You can add another role later from your profile.';

  @override
  String get roleCustomer => 'Customer';

  @override
  String get roleCustomerDesc => 'Discover places, products and local offers';

  @override
  String get roleMerchant => 'Merchant';

  @override
  String get roleMerchantDesc =>
      'Grow your business and manage your storefront';

  @override
  String get roleInfluencer => 'Influencer';

  @override
  String get roleInfluencerDesc =>
      'Create local stories and collaborate with brands';

  @override
  String get roleRemember => 'Remember my choice';

  @override
  String get roleRememberHint => 'You can change this anytime from Profile';

  @override
  String get roleEnterCustomer => 'Enter as Customer';

  @override
  String get roleEnterMerchant => 'Enter as Merchant';

  @override
  String get roleEnterInfluencer => 'Enter as Influencer';

  @override
  String get roleSelectPrompt => 'Select a role to continue';

  @override
  String get switchTitleLead => 'Switch';

  @override
  String get switchTitleAccent => 'mode';

  @override
  String switchCurrently(String mode) {
    return 'You are currently in $mode mode';
  }

  @override
  String get switchCustomerSubtitle => 'Browse stores, products and offers';

  @override
  String get switchMerchantSubtitle => 'Manage store, products and banners';

  @override
  String get switchInfluencerSubtitle => 'Manage your influencer profile';

  @override
  String get loginBadge => 'LOCAL, MADE EASY';

  @override
  String get loginWelcomeEyebrow => 'WELCOME TO YOUR NEIGHBOURHOOD';

  @override
  String get loginHeroLead => 'Find more to';

  @override
  String get loginHeroAccent => 'love';

  @override
  String get loginHeroTail => ', nearby.';

  @override
  String get loginHeroBody =>
      'Local stores, thoughtful offers and people worth discovering—all in one place.';

  @override
  String get loginTabLogin => 'Login';

  @override
  String get loginTabRegister => 'Register';

  @override
  String get loginYourName => 'Your name';

  @override
  String get loginNameHint => 'Enter your full name';

  @override
  String get loginMobile => 'Mobile number';

  @override
  String get loginGetCode => 'Get verification code';

  @override
  String get loginRegisterGetCode => 'Register & get verification code';

  @override
  String get loginOr => 'OR';

  @override
  String get loginGuest => 'Continue as guest';

  @override
  String get loginFollow => 'FOLLOW THE LOCAL STORY';

  @override
  String get onboardingSkip => 'Skip';

  @override
  String get onboardingSlide1Title => 'Discover Local Deals';

  @override
  String get onboardingSlide1Subtitle =>
      'Find the best offers from stores near you';

  @override
  String get onboardingSlide2Title => 'Earn Reward Points';

  @override
  String get onboardingSlide2Subtitle =>
      'Every visit earns you points you can redeem';

  @override
  String get onboardingSlide3Title => 'Get Gift Vouchers';

  @override
  String get onboardingSlide3Subtitle =>
      'Redeem your points for Amazon & Flipkart vouchers';

  @override
  String get countryPickerTitle => 'Select country';

  @override
  String get profileGroupActivity => 'My activity';

  @override
  String get profileGroupAccount => 'Account';

  @override
  String get profileGroupLanguage => 'Language';

  @override
  String get profileGroupLegal => 'About & legal';

  @override
  String get profileGroupSession => 'Session';

  @override
  String get profileGuestBadge => 'Browsing as guest';

  @override
  String get profileMemberBadge => 'OffrO member';

  @override
  String get languageRowLabel => 'App language';

  @override
  String get languageSheetTitle => 'Choose language';

  @override
  String get languageSheetNote =>
      'The app stays in English until you choose another language.';

  @override
  String get languageNameEn => 'English';

  @override
  String get languageNameAr => 'العربية';

  @override
  String get languageButtonSemantics => 'Change language';

  @override
  String get profileEyebrow => 'Your OffrO';

  @override
  String get profileTitle => 'Profile';

  @override
  String get profileStatSaved => 'Saved';

  @override
  String get profileStatPoints => 'Points';

  @override
  String get navHome => 'Home';

  @override
  String get navExplore => 'Explore';

  @override
  String get navDeals => 'Deals';

  @override
  String get navRewards => 'Rewards';

  @override
  String get navProfile => 'Profile';

  @override
  String get navInvoices => 'Invoices';

  @override
  String get navActivity => 'Activity';

  @override
  String get navOpportunities => 'Opportunities';

  @override
  String get homeExploring => 'Exploring';

  @override
  String get homeSelectLocation => 'Select location';

  @override
  String get homeSearchHint => 'Search stores, products or services';

  @override
  String get homeViewArrow => 'View →';

  @override
  String get homeHeroBadge => 'LOCAL DEALS & STORES';

  @override
  String get homeExploreLead => 'Explore';

  @override
  String get homeHeroSubtitle => 'Discover stores, deals & local favorites';

  @override
  String get homeDiscoverStores => 'Discover stores';

  @override
  String get homeYourCity => 'Your City';

  @override
  String get homeDealEndsToday => 'Ends today';

  @override
  String get homeDealOneDayLeft => '1 day left';

  @override
  String homeDealDaysLeft(String days) {
    return '$days days left';
  }

  @override
  String get homeExclusiveEyebrow => 'Made for OffrO members';

  @override
  String get homeExclusiveTitle => 'Exclusive deals';

  @override
  String get homeViewAll => 'View all';

  @override
  String get homeDealOffer => 'Offer';

  @override
  String homePercentOff(String percent) {
    return '$percent% off';
  }

  @override
  String get homeRewardsBadge => 'OFFRO REWARDS';

  @override
  String get homePointsSuffix => 'points';

  @override
  String get homeRewardsTapToView => 'Tap to view and redeem your rewards';

  @override
  String get homeRewardsEarnHint => 'Visit stores to start earning points';

  @override
  String get homeCategoriesEyebrow => 'Find what you need';

  @override
  String get homeCategoriesTitle => 'Explore categories';

  @override
  String get homeSeeAll => 'See All';

  @override
  String get homeSeeAllLower => 'See all';

  @override
  String get catBakery => 'Bakery';

  @override
  String get catAutomobile => 'Automobile';

  @override
  String get catRestaurant => 'Restaurant';

  @override
  String get catGrocery => 'Grocery';

  @override
  String get homeProductsEyebrow => 'Across local stores';

  @override
  String get homeProductsTitle => 'Products near you';

  @override
  String get homeBrowseAll => 'Browse all';

  @override
  String homeFavoriteSaveFailed(String error) {
    return 'Couldn\'t save favorite: $error';
  }

  @override
  String get homeNearbyEyebrow => 'Around your neighbourhood';

  @override
  String get homeStoresNearTitle => 'Stores near you';

  @override
  String get homeNearbyStoresTitle => 'Nearby Stores';

  @override
  String get homeBadgeNew => 'NEW';

  @override
  String homeOfferInline(String offer) {
    return 'Offer · $offer';
  }

  @override
  String get homeOpenNow => 'Open now';

  @override
  String get homeClosed => 'Closed';

  @override
  String get homeDistanceAny => 'Any distance';

  @override
  String homeDistanceUnder(String km) {
    return 'Under $km km';
  }

  @override
  String homeNoStoresWithin(String km) {
    return 'No stores within $km km';
  }

  @override
  String get homeTryLargerRadius => 'Try a larger radius or tap Any distance';

  @override
  String get homeExploreAreasTitle => 'Explore Areas';

  @override
  String get homeExploreAreasSubtitle => 'Discover great places nearby';

  @override
  String get homeViewAllArrow => 'View all →';

  @override
  String get homeStoreWord => 'Store';

  @override
  String get homeFeatureRewards => 'My Rewards';

  @override
  String get homeBackToHome => 'Back to Home';

  @override
  String get homeContactSupport => 'Contact Support';

  @override
  String get homeNoInternet => 'No internet connection';

  @override
  String get homeCheckConnection => 'Check your connection and try again';

  @override
  String get homeServerSlow => 'Server taking too long';

  @override
  String get homeColdStart => 'Cold start — please wait a moment and retry';

  @override
  String get homeCouldntLoadStores => 'Couldn\'t load stores';

  @override
  String get homePleaseTryAgain => 'Please try again';

  @override
  String get homeCouldntLoadPage => 'Couldn\'t load this page';

  @override
  String get commonRetry => 'Retry';

  @override
  String get commonTryAgain => 'Try Again';

  @override
  String get homePromoTitle => 'Featured Banners';

  @override
  String get homePromoSubtitle => 'Latest offers from our stores';

  @override
  String get timeAm => 'AM';

  @override
  String get timePm => 'PM';

  @override
  String storeClosesAt(String time) {
    return 'Closes $time';
  }

  @override
  String storeOpensAt(String time) {
    return 'Opens $time';
  }

  @override
  String get badgeJustOpened => 'JUST OPENED';

  @override
  String get badgeNewlyAdded => 'NEWLY ADDED';

  @override
  String get badgeNewlyOpened => 'NEWLY OPENED';

  @override
  String get badgeTrending => 'TRENDING';

  @override
  String get badgePopular => 'POPULAR';

  @override
  String get badgeTopRated => 'TOP RATED';

  @override
  String get badgeMustVisit => 'MUST VISIT';

  @override
  String get badgeLimitedOffer => 'LIMITED OFFER';

  @override
  String get homeLoginRequiredTitle => 'Login Required';

  @override
  String homeLoginRequiredBody(String feature) {
    return 'Please login or register to use $feature.';
  }

  @override
  String get homeLoginRegister => 'Login / Register';

  @override
  String get homeMaybeLater => 'Maybe later';

  @override
  String get homeUnableToConnect =>
      'Unable to connect. Please check your internet connection and try again.';

  @override
  String get homeRefreshFailed => 'Couldn\'t refresh stores. Please try again.';
}
