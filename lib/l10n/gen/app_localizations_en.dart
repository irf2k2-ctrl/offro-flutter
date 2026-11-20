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

  @override
  String get profileFavourites => 'My Favourites';

  @override
  String get profileFavouritesNote => 'Stores you saved';

  @override
  String get profileRewardsNote => 'Reward points and vouchers';

  @override
  String get profileScanHistory => 'Scan History';

  @override
  String get profileScanHistoryNote => 'Points earned at stores';

  @override
  String get profileNotifications => 'Notifications';

  @override
  String get profileNotificationsNote => 'Offers, rewards and account updates';

  @override
  String get profileSwitchMode => 'Switch Mode';

  @override
  String get profileSwitchModeNote => 'Switch between User & Merchant';

  @override
  String get profileContact => 'Contact Offro';

  @override
  String get profileContactNote => 'Chat with us on WhatsApp';

  @override
  String get profileAboutUs => 'About Us';

  @override
  String get profileAboutFallback =>
      'Offro connects local stores with customers through deals and loyalty points.';

  @override
  String get profileTerms => 'Terms & Conditions';

  @override
  String get profilePrivacy => 'Privacy Policy';

  @override
  String get profilePrivacyNote => 'Includes delete account';

  @override
  String get profileRefund => 'Refund Policy';

  @override
  String get profileLogout => 'Logout';

  @override
  String get commonCancel => 'Cancel';

  @override
  String get commonClose => 'Close';

  @override
  String get commonAll => 'All';

  @override
  String get notifClearTitle => 'Clear All Notifications?';

  @override
  String get notifClearBody =>
      'This will permanently remove all your notifications.';

  @override
  String get notifClearAll => 'Clear All';

  @override
  String get notifEmptyTitle => 'No notifications yet';

  @override
  String get notifEmptyBody => 'You\'ll see deals and alerts here';

  @override
  String get timeAgoJustNow => 'just now';

  @override
  String timeAgoMinutes(String n) {
    return '${n}m ago';
  }

  @override
  String timeAgoHours(String n) {
    return '${n}h ago';
  }

  @override
  String timeAgoDays(String n) {
    return '${n}d ago';
  }

  @override
  String timeAgoWeeks(String n) {
    return '${n}w ago';
  }

  @override
  String searchStoresIn(String city) {
    return 'Search stores in $city...';
  }

  @override
  String searchNoResults(String q) {
    return 'No results for \'$q\'';
  }

  @override
  String searchNoResultsDq(String q) {
    return 'No results for "$q"';
  }

  @override
  String get searchNoStores => 'No stores yet';

  @override
  String get searchStoreAreaOffer => 'Search store, area, offer...';

  @override
  String catSearchStores(String category) {
    return 'Search $category stores...';
  }

  @override
  String catNoStoresFound(String category) {
    return 'No $category stores found';
  }

  @override
  String catFoundButNone(String count, String category) {
    return 'Found $count store(s) in this city, but none matched "$category".';
  }

  @override
  String catCategoriesFound(String list) {
    return 'Categories found: $list';
  }

  @override
  String get catCategoriesTitle => 'Categories';

  @override
  String get catSearchCategories => 'Search categories...';

  @override
  String get catNoCategories => 'No categories found';

  @override
  String get catAllCategories => 'All categories';

  @override
  String get dealsEndingSoon => 'Ending soon';

  @override
  String get dealExpired => 'Expired';

  @override
  String get dealEndsInOneDay => 'Ends in 1 day';

  @override
  String dealEndsInDays(String days) {
    return 'Ends in $days days';
  }

  @override
  String get dealLocalBadge => 'LOCAL DEAL';

  @override
  String get dealAvailableInStore => 'AVAILABLE IN STORE';

  @override
  String get dealsEyebrow => 'Fresh around you';

  @override
  String get dealsTitle => 'Local deals';

  @override
  String dealsSubtitleCity(String city) {
    return 'Member-only prices and limited offers from verified businesses in $city.';
  }

  @override
  String get dealsSubtitleNearby =>
      'Member-only prices and limited offers from verified businesses nearby.';

  @override
  String get dealsSearch => 'Search deals, stores or areas';

  @override
  String get dealsThisWeek => 'THIS WEEK';

  @override
  String get dealsNoneActive => 'No active deals right now';

  @override
  String get dealsNoMatch => 'No deals match your search';

  @override
  String get areasTitle => 'All Areas';

  @override
  String get areasSearch => 'Search areas...';

  @override
  String get areasNone => 'No areas available';

  @override
  String areaSearchIn(String area) {
    return 'Search in $area...';
  }

  @override
  String areaStoresOne(String area) {
    return '1 store in $area';
  }

  @override
  String areaStoresMany(String count, String area) {
    return '$count stores in $area';
  }

  @override
  String get areaNoStores => 'No stores found';

  @override
  String get storeSeeAllStores => 'See All\nStores';

  @override
  String get unitMeter => 'm';

  @override
  String get unitKm => 'km';

  @override
  String ptsOnVisit(String points) {
    return '$points pts on visit';
  }

  @override
  String get storeOpenNowCaps => 'Open Now';

  @override
  String get badgeNewStore => 'NEW STORE';

  @override
  String offSuffix(String amount) {
    return '$amount off';
  }

  @override
  String get prodTitleFallback => 'Product';

  @override
  String get prodListedBy => 'Listed by';

  @override
  String get prodViewStore => 'View store';

  @override
  String get prodStoreInactive => 'Store Currently Inactive';

  @override
  String get prodDetails => 'Product details';

  @override
  String get prodRateReview => 'Rate & Review';

  @override
  String get prodTapToRate => 'Tap to rate';

  @override
  String get ratingPoor => 'Poor';

  @override
  String get ratingFair => 'Fair';

  @override
  String get ratingGood => 'Good';

  @override
  String get ratingGreat => 'Great';

  @override
  String get ratingExcellent => 'Excellent';

  @override
  String get prodShareExperience =>
      'Share your experience with this product...';

  @override
  String get prodSubmitReview => 'Submit Review';

  @override
  String get prodThanksReview => 'Thanks for your review!';

  @override
  String get reviewLoginRequired => 'Please log in to submit a review.';

  @override
  String get reviewSubmitted => 'Review submitted! Thank you.';

  @override
  String get reviewSessionExpired =>
      'Your session has expired. Please log in again to submit a review.';

  @override
  String get prodAllProducts => 'All products';

  @override
  String get prodNoProducts => 'No products found';

  @override
  String get prodSearch => 'Search products...';

  @override
  String prodSeller(String name) {
    return 'Seller: $name';
  }

  @override
  String get prodBestSeller => 'BEST SELLER';

  @override
  String get monthJan => 'Jan';

  @override
  String get monthFeb => 'Feb';

  @override
  String get monthMar => 'Mar';

  @override
  String get monthApr => 'Apr';

  @override
  String get monthMay => 'May';

  @override
  String get monthJun => 'Jun';

  @override
  String get monthJul => 'Jul';

  @override
  String get monthAug => 'Aug';

  @override
  String get monthSep => 'Sep';

  @override
  String get monthOct => 'Oct';

  @override
  String get monthNov => 'Nov';

  @override
  String get monthDec => 'Dec';

  @override
  String get errGeneric => 'Something went wrong. Please try again.';

  @override
  String get errConnect =>
      'We couldn\'t connect to OffrO right now. Please check your internet connection and try again.';

  @override
  String get errTimeout =>
      'OffrO is taking too long to respond. Please try again in a moment.';

  @override
  String get errUnavailable =>
      'OffrO is temporarily unavailable. Please try again in a moment.';

  @override
  String get errSession => 'Your session has expired. Please log in again.';

  @override
  String get errApiNetwork =>
      'Network error. Please check your connection and try again.';

  @override
  String get errApiUnexpected => 'Unexpected response from server.';

  @override
  String get profileGuestName => 'Guest';

  @override
  String get profileSupportNote =>
      'Need to update your profile? Contact support, we will help you right away.';

  @override
  String get favEyebrow => 'Saved for later';

  @override
  String get favPlacesOne => '1 place you love, all in one spot.';

  @override
  String favPlacesMany(String count) {
    return '$count places you love, all in one spot.';
  }

  @override
  String get favEmptyTitle => 'No favourites yet';

  @override
  String get favEmptyBody => 'Tap the heart on any store to save it here';

  @override
  String get qrTitle => 'Scan Store QR';

  @override
  String get qrInvalid => '❌ Invalid QR';

  @override
  String get qrPointsAdded => 'Points Added!';

  @override
  String get qrDone => 'Done!';

  @override
  String get qrRefreshedNote => '🔐 Store QR has been refreshed for security.';

  @override
  String get qrGreat => 'Great!';

  @override
  String get qrPointAt => 'Point at store QR code';

  @override
  String get exploreYourCity => 'your city';

  @override
  String exploreDiscover(String city) {
    return 'Discover $city';
  }

  @override
  String get exploreTitle => 'Explore nearby';

  @override
  String get exploreDesc =>
      'Find independent businesses, useful services and local favourites around you.';

  @override
  String get exploreSearchHint => 'Search stores, categories or areas';

  @override
  String get exploreSearchNote =>
      'Searches business names, store categories and neighbourhoods.';

  @override
  String get exploreByArea => 'Explore by area';

  @override
  String exploreNeighbourhoodsIn(String city) {
    return 'Neighbourhoods in $city';
  }

  @override
  String get exploreAroundYou => 'Around you';

  @override
  String get exploreNeighbourhood => 'Neighbourhood';

  @override
  String get explorePlacesOne => '1 place nearby';

  @override
  String explorePlacesMany(String count) {
    return '$count places nearby';
  }

  @override
  String exploreStoresInArea(String area) {
    return 'Stores in $area';
  }

  @override
  String get exploreNoMatchTitle => 'No matching stores yet';

  @override
  String get exploreNoMatchBody =>
      'Try another business name, category or neighbourhood.';

  @override
  String exploreOffer(String offer) {
    return 'Offer · $offer';
  }

  @override
  String get exploreStoreOne => '1 store';

  @override
  String exploreStoreMany(String count) {
    return '$count stores';
  }

  @override
  String get walletDone => 'Done';

  @override
  String get walletBadge => 'REWARD POINTS';

  @override
  String get walletBalance => 'Available balance';

  @override
  String get walletPointsWord => 'points';

  @override
  String get walletRedeem => 'Redeem';

  @override
  String walletVoucherRate(String points) {
    return '$points pts = ₹20 voucher';
  }

  @override
  String get walletReadyToRedeem => 'Ready to redeem';

  @override
  String walletToGo(String points) {
    return '$points pts to go';
  }

  @override
  String walletPtsOnly(String points) {
    return '$points pts';
  }

  @override
  String get walletVoucherDesc =>
      'Promotional gift voucher · Amazon or Flipkart';

  @override
  String walletEarnMore(String points) {
    return 'Earn $points more points';
  }

  @override
  String get walletHowTitle => 'How rewards work';

  @override
  String get walletHowLine1 =>
      'Redeem 200 Reward Points for a ₹20 Promotional Gift Voucher.';

  @override
  String get walletHowLine2 => 'Gift voucher delivery: 3-5 business days.';

  @override
  String get walletHowLine3 => 'Reward points never expire.';

  @override
  String get walletHowDisclaimer =>
      'Reward points are promotional loyalty points. They cannot be purchased, transferred, or exchanged for cash.';

  @override
  String get walletRecent => 'Recent activity';

  @override
  String get walletNoScansHint =>
      'No scans yet — points you earn at stores will show up here.';

  @override
  String walletEarnedOn(String date) {
    return 'Earned · $date';
  }

  @override
  String get walletEyebrow => 'Your local loyalty';

  @override
  String get walletTitle => 'Rewards';

  @override
  String get walletDesc =>
      'Every local purchase gets you closer to something good.';

  @override
  String get walletVouchersEyebrow => 'Ready to use';

  @override
  String get walletVouchersTitle => 'Your vouchers';

  @override
  String get walletViewHistory => 'View history';

  @override
  String get scanHistoryTitle => 'Scan History';

  @override
  String get scanHistoryEmpty => 'No scans yet';

  @override
  String walletPtsPlus(String points) {
    return '+$points pts';
  }

  @override
  String get storeTabAbout => 'About';

  @override
  String get storeTabProducts => 'Products';

  @override
  String get storeTabReviews => 'Reviews';

  @override
  String get storeTabRewards => 'Rewards';

  @override
  String storeScanEarn(String points) {
    return 'Scan & Earn $points pts';
  }

  @override
  String get storeScanCardTitle => 'Scan the store QR';

  @override
  String storeScanCardBody(String points) {
    return 'Verify your visit/purchase and earn $points reward points.';
  }

  @override
  String get storeScanQr => 'Scan QR';

  @override
  String get storeRewardsSoon => 'Rewards coming soon';

  @override
  String get storeEarnPointsTitle => 'Earn Reward Points';

  @override
  String storeEarnPointsBody(String points) {
    return 'Scan QR after purchase to earn $points pts';
  }

  @override
  String storeYourPoints(String points) {
    return 'Your Points: $points';
  }

  @override
  String get storeShowLess => 'Show less';

  @override
  String get storeReadMore => 'Read more →';

  @override
  String get storeOpenWord => 'Open';

  @override
  String get storeClosedWord => 'Closed';

  @override
  String storeCostForTwo(String amount) {
    return '₹$amount for two';
  }

  @override
  String get storeDineIn => 'Dine-in available';

  @override
  String get storeChipTrending => 'Trending';

  @override
  String get storeChipJustOpened => 'Just Opened';

  @override
  String get storeChipPopular => 'Popular';

  @override
  String storeOfferPct(String pct) {
    return 'Offer · $pct% off';
  }

  @override
  String get storeCall => 'Call';

  @override
  String get storeWhatsApp => 'WhatsApp';

  @override
  String get storeDirections => 'Directions';

  @override
  String get storeExclusiveOne => 'Exclusive on OffrO · 1 deal';

  @override
  String storeExclusiveMany(String count) {
    return 'Exclusive on OffrO · $count deals';
  }

  @override
  String get storeExclusive => 'Exclusive on OffrO';

  @override
  String get storeDealsFromStore => 'Deals from this store';

  @override
  String get storeOffersSoon => 'Offers coming soon';

  @override
  String storeDiscOff(String pct) {
    return '$pct% OFF';
  }

  @override
  String get storeOffWord => 'OFF';

  @override
  String get prodsAvailableEyebrow => 'PRODUCTS AVAILABLE AT THIS STORE';

  @override
  String get prodsFeatured => 'Featured Products';

  @override
  String get prodsTip =>
      'Tip: Long-press a product image to view details and leave a review.';

  @override
  String prodRatingSubmitFailed(String error) {
    return 'Couldn\'t submit rating: $error';
  }

  @override
  String prodValidTill(String date) {
    return 'Valid till $date';
  }

  @override
  String get prodYourRating => 'Your Rating';

  @override
  String get prodRateThis => 'Rate this Product';

  @override
  String get prodReviewHint => 'Write a short review (optional)';

  @override
  String get prodSubmitRating => 'Submit Rating';

  @override
  String get prodThanksRating => 'Thanks for your rating! ⭐';

  @override
  String get prodGotIt => 'Got it';

  @override
  String get revStoreNotFound => 'Store not found. Cannot submit review.';

  @override
  String get revSelectStar => 'Please select a star rating';

  @override
  String get revMin5 => 'Write at least 5 characters';

  @override
  String get revSubmittedStar => '⭐ Review submitted! Thank you.';

  @override
  String get revUnavailable => 'Store information unavailable.';

  @override
  String get revEyebrow => 'WHAT CUSTOMERS ARE SAYING';

  @override
  String get revTitle => 'Reviews';

  @override
  String get revCountOne => '(1 review)';

  @override
  String revCountMany(String count) {
    return '($count reviews)';
  }

  @override
  String get revNoneTitle => 'No reviews yet';

  @override
  String get revYourReview => 'Your Review';

  @override
  String get revEdit => 'Edit';

  @override
  String get revWrite => 'Write a review…';

  @override
  String get revShareExp => 'Share your experience…';

  @override
  String get revSubmit => 'Submit';

  @override
  String get revNoneDot => 'No reviews yet.';

  @override
  String get revBeFirst => 'Be the first to review.';

  @override
  String get revViewAll => 'View all reviews →';

  @override
  String get revAllTitle => 'All Reviews';

  @override
  String get revAnonymous => 'Anonymous';

  @override
  String get storeDealWord => 'Deal';

  @override
  String get storeNewStoreTitle => 'New Store';

  @override
  String storeDistAwayM(String n) {
    return '${n}m away';
  }

  @override
  String storeDistAwayKm(String n) {
    return '${n}km away';
  }

  @override
  String get locGpsFailed =>
      'Couldn\'t get a precise GPS fix. Move to an open area or check your signal.';

  @override
  String get locCityUnknown =>
      'Got your position but couldn\'t identify the city.';

  @override
  String get locServicesOff =>
      'Your device\'s location services are turned off. Please turn them on in settings.';

  @override
  String get locPermissionOff =>
      'Location permission is turned off for OffrO. Please allow it in app settings.';

  @override
  String get locPermissionDenied =>
      'Location permission wasn\'t allowed. Tap the card to try again, or choose a city below.';

  @override
  String get locNotDetected => 'Location not detected';

  @override
  String get locGoToSettings => 'Go to settings';

  @override
  String get locCityUnsupportedTitle => 'City not supported yet';

  @override
  String locCityUnsupportedBody(String city) {
    return 'OffrO isn\'t available in $city yet. Please choose another city from the list.';
  }

  @override
  String get commonOk => 'OK';

  @override
  String get locTitle => 'Location';

  @override
  String get locSearchHint => 'Search city, area or locality';

  @override
  String get locCitiesLoadFailed =>
      'Couldn\'t load cities. Check your connection and try again.';

  @override
  String get locTryAgain => 'Try again';

  @override
  String get locPopularCities => 'Popular cities';

  @override
  String get locAllCities => 'All cities';

  @override
  String get locCities => 'Cities';

  @override
  String get locAreas => 'Areas';

  @override
  String get locNoMatch => 'No matching places found.';

  @override
  String get legalEyebrow => 'Legal';

  @override
  String get legalPrivacyTitle => 'Privacy Policy';

  @override
  String get legalPrivacyUpdating =>
      'Privacy policy content is being updated. Please check back later.';

  @override
  String get legalReadLess => 'Read Less';

  @override
  String get legalReadMore => 'Read More';

  @override
  String get legalAccountCaps => 'ACCOUNT';

  @override
  String get legalDeleteRequest => 'Request to delete my account';

  @override
  String get legalDeleteRequestNote =>
      'All your data will be permanently removed';

  @override
  String get delReasonUnused => 'I no longer use the app';

  @override
  String get delReasonPrivacy => 'I have privacy concerns';

  @override
  String get delReasonDuplicate => 'I have a duplicate account';

  @override
  String get delReasonNoisy => 'Too many notifications or irrelevant content';

  @override
  String get delReasonOther => 'Other';

  @override
  String get delEyebrow => 'Account';

  @override
  String get delTitle => 'Delete Account';

  @override
  String get delWarning =>
      'Once your account is deleted, your data cannot be retrieved. Signing up again will create a new account.';

  @override
  String get delSelectReason => 'Select a reason for deleting your account';

  @override
  String get delSubmit => 'Submit Delete Request';

  @override
  String get delConfirmTitle => 'Delete Account?';

  @override
  String get delConfirmBody =>
      'Your account will be marked for deletion. You will be logged out immediately and cannot log in again.\n\nOnce deleted, your data cannot be retrieved. Are you absolutely sure?';

  @override
  String get delConfirmYes => 'Yes, Delete';

  @override
  String get delRequestedTitle => 'Deletion Requested';

  @override
  String get delRequestedBody =>
      'Your account deletion request has been submitted. You have been logged out.';

  @override
  String delSubmitFailed(String error) {
    return 'Failed to submit: $error';
  }

  @override
  String get loadStep1 => 'Locating your position...';

  @override
  String get loadStep2 => 'Finding nearby deals...';

  @override
  String get loadStep3 => 'Checking local stores...';

  @override
  String get loadStep4 => 'Loading today\'s offers...';

  @override
  String get catBrowseTitle => 'Browse by Categories';

  @override
  String get catView => 'View';

  @override
  String get catPharmacy => 'Pharmacy';

  @override
  String get catFashion => 'Fashion';

  @override
  String get catBeauty => 'Beauty';

  @override
  String get catElectronics => 'Electronics';

  @override
  String get catEducation => 'Education';

  @override
  String get catHospital => 'Hospital';

  @override
  String get catCafe => 'Cafe';

  @override
  String get catFitness => 'Fitness';

  @override
  String get catJewelry => 'Jewelry';

  @override
  String get catSubRestaurant => '500+ places';

  @override
  String get catSubPharmacy => 'Health essentials';

  @override
  String get catSubFashion => 'New arrivals';

  @override
  String get catSubBeauty => 'Skincare & more';

  @override
  String get catSubElectronics => 'Trending gadgets';

  @override
  String get catSubEducation => 'Learn & grow';

  @override
  String get catSubHospital => 'Healthcare near you';

  @override
  String get catSubCafe => 'Coffee & more';

  @override
  String get catSubGrocery => 'Fresh & daily';

  @override
  String get catSubFitness => 'Stay strong';

  @override
  String get catSubJewelry => 'Precious finds';

  @override
  String get catSubBakery => 'Fresh baked daily';

  @override
  String get dealsActiveOne => '1 active deal for you';

  @override
  String dealsActiveMany(String count) {
    return '$count active deals for you';
  }

  @override
  String get areaCardStoreOne => '1 Store';

  @override
  String areaCardStoreMany(String count) {
    return '$count Stores';
  }

  @override
  String storeDistAwaySpM(String n) {
    return '$n m away';
  }

  @override
  String storeDistAwaySpKm(String n) {
    return '$n km away';
  }

  @override
  String get prodSpecialOffer => 'Special Offer';

  @override
  String get prodDownload => 'Download';
}
