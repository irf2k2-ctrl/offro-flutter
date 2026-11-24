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
  String get onboardingSlide3Subtitle => 'Redeem your points for gift vouchers';

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
    return 'No results for \"$q\"';
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
    return 'Found $count store(s) in this city, but none matched \"$category\".';
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
  String walletVoucherRate(String points, String amount) {
    return '$points pts = $amount voucher';
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
  String get walletVoucherDesc => 'Promotional Gift Voucher';

  @override
  String walletVoucherDescPartners(String partners) {
    return 'Promotional Gift Voucher · $partners';
  }

  @override
  String get walletRewardsUnavailable => 'Gift voucher redemption isn\'t available for your country yet.';

  @override
  String walletEarnMore(String points) {
    return 'Earn $points more points';
  }

  @override
  String get walletHowTitle => 'How rewards work';

  @override
  String walletHowLine1(String points, String amount) {
    return 'Redeem $points Reward Points for a $amount Promotional Gift Voucher.';
  }

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
  String get locNoCitiesYet => 'No cities are available for your country yet.';

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

  @override
  String get bizAdd => 'Add';

  @override
  String get bizNoStoresYetTapTo => 'No stores yet — tap to add your first';

  @override
  String get bizSubscribeYourStoreToCreate =>
      'Subscribe your store to create banners.';

  @override
  String get bizNoBannersYetPromoteYour =>
      'No banners yet — promote your store';

  @override
  String get bizSubscribeYourStoreToAdd =>
      'Subscribe your store to add products.';

  @override
  String get bizNoProductsYetAddYour =>
      'No products yet — add your first product';

  @override
  String get bizMERCHANTWORKSPACE => 'MERCHANT WORKSPACE';

  @override
  String get bizWelcomeBack => 'Welcome back';

  @override
  String get bizCouldnTLoadYourDashboard => 'Couldn\'t load your dashboard';

  @override
  String get bizLiveStores => 'Live stores';

  @override
  String get bizLiveBanners => 'Live banners';

  @override
  String get bizLiveProducts => 'Live products';

  @override
  String get bizMANAGEYOURBUSINESS => 'MANAGE YOUR BUSINESS';

  @override
  String get bizMyStore => 'My Store';

  @override
  String get bizMyBanner => 'My Banner';

  @override
  String get bizMyProducts => 'My Products';

  @override
  String get bizCreatorCollaborations => 'Creator collaborations';

  @override
  String get bizBriefMatchAndManageLocal =>
      'Brief, match and manage local creators';

  @override
  String get bizSubscribeYourStoreToWork =>
      'Subscribe your store to work with creators.';

  @override
  String get bizLocked => 'Locked';

  @override
  String get bizManage => 'Manage';

  @override
  String get bizPromotions => 'Promotions';

  @override
  String get bizMyBanners => 'My Banners';

  @override
  String get bizNewBanner => 'New Banner';

  @override
  String get bizCouldnTLoadBanners => 'Couldn\'t load banners';

  @override
  String get bizNoBannersYet => 'No banners yet';

  @override
  String get bizTapToCreateYourFirst => 'Tap + to create your first banner';

  @override
  String get bizApprovedLive => 'Approved — Live';

  @override
  String get bizRejected => 'Rejected';

  @override
  String get bizRemovedByAdmin => 'Removed by Admin';

  @override
  String get bizTurnedOff => 'Turned Off';

  @override
  String get bizPendingApproval => 'Pending Approval';

  @override
  String get bizSubmitted => 'Submitted';

  @override
  String get bizEditBannerTitle => 'Edit Banner Title';

  @override
  String get bizBannerTitle => 'Banner title';

  @override
  String get bizSave => 'Save';

  @override
  String get bizEditTitle => 'Edit Title';

  @override
  String get bizTurnOffBanner => 'Turn Off Banner?';

  @override
  String get bizTurnOnBanner => 'Turn On Banner?';

  @override
  String get bizThisBannerWillBeHidden =>
      'This banner will be hidden from stores until you turn it back on.';

  @override
  String get bizThisBannerWillGoLive =>
      'This banner will go live again in stores.';

  @override
  String get bizTurnOff => 'Turn Off';

  @override
  String get bizTurnOn => 'Turn On';

  @override
  String get bizExpiredChooseANewStart => 'Expired · Choose a new start date';

  @override
  String get bizRenew => 'Renew';

  @override
  String get bizRejectedCreateANewBanner =>
      'Rejected · Create a new banner to resubmit';

  @override
  String get bizCreateNew => 'Create new';

  @override
  String get bizRemovedByAdmin2 => 'Removed by admin';

  @override
  String get bizAwaitingAdminApproval => 'Awaiting admin approval';

  @override
  String get bizImageTooLargeMax2MB => 'Image too large. Max 2MB.';

  @override
  String get bizVideoIsTooLargePlease =>
      'Video is too large. Please select a video up to 10 MB.';

  @override
  String get bizVideoIsTooLongPlease =>
      'Video is too long. Please select a video up to 15 seconds.';

  @override
  String get bizCouldNotReadThisVideo =>
      'Could not read this video. Please select another video.';

  @override
  String get bizCouldNotUploadTheVideo =>
      'Could not upload the video. Please try again.';

  @override
  String get bizExistingBannerVideoWillBe =>
      'Existing banner video will be reused';

  @override
  String get bizTapToReplace => 'Tap to replace';

  @override
  String get bizTapToSelectBannerVideo => 'Tap to select banner video';

  @override
  String get biz10801080px11 => '📐 1080×1080px (1:1)';

  @override
  String get bizMax15Sec10MB => 'Max 15 sec · 10 MB';

  @override
  String get bizBannerTitleRequired => 'Banner title required';

  @override
  String get bizPleaseSelectAStore => 'Please select a store';

  @override
  String get bizPleaseSelectACity => 'Please select a city';

  @override
  String get bizPleaseSelectABannerVideo => 'Please select a banner video';

  @override
  String get bizPleaseUploadABannerImage => 'Please upload a banner image';

  @override
  String get bizEnterNumberOfDaysMinimum => 'Enter number of days (minimum 1)';

  @override
  String get bizUntitledDeal => 'Untitled deal';

  @override
  String get bizUntitledProduct => 'Untitled product';

  @override
  String get bizCTADestination => 'CTA destination';

  @override
  String get bizChooseWhereThisBannerShould =>
      'Choose where this banner should take the customer.';

  @override
  String get bizSelectDeal => 'Select Deal';

  @override
  String get bizSelectProduct => 'Select Product';

  @override
  String get bizCustomersWillOpenTheSelected =>
      'Customers will open the selected store.';

  @override
  String get bizNothingSelectedYetTheBanner =>
      'Nothing selected yet — the banner will open the store.';

  @override
  String get bizDiscountApplied => '✅ Discount applied!';

  @override
  String get bizPaymentGatewayNotConfiguredContact =>
      'Payment gateway not configured. Contact support.';

  @override
  String get bizCouldNotOpenPaymentPlease =>
      'Could not open payment. Please try again.';

  @override
  String get bizBannerOrderSummary => 'Banner Order Summary';

  @override
  String get bizTitle => 'Title';

  @override
  String get bizDuration => 'Duration';

  @override
  String get bizPeriod => 'Period';

  @override
  String get bizRate => 'Rate';

  @override
  String get bizBasePrice => 'Base Price';

  @override
  String get bizDiscount => 'Discount';

  @override
  String get bizTotal => 'Total';

  @override
  String get bizYourBannerWillBeSubmitted =>
      'Your banner will be submitted for admin review after confirmation.';

  @override
  String get bizRazorpayCheckoutWillOpenBanner =>
      'Razorpay checkout will open. Banner goes live after admin approval.';

  @override
  String get bizConfirmSubmit => 'Confirm Submit';

  @override
  String get bizRenewBanner => 'Renew Banner';

  @override
  String get bizCreateBanner => 'Create Banner';

  @override
  String get bizBannerTitle2 => 'Banner Title *';

  @override
  String get bizEG50OFFAt => 'e.g. 50% OFF at Raj Store';

  @override
  String get bizSelectStore => 'Select Store *';

  @override
  String get bizUnnamedStore => 'Unnamed Store';

  @override
  String get bizCityAutoFilledFromStore => 'City auto-filled from store';

  @override
  String get bizImage => 'Image';

  @override
  String get bizVideo => 'Video';

  @override
  String get bizTapToUploadBannerImage => 'Tap to upload banner image';

  @override
  String get bizMax2MB => '📦 Max 2MB';

  @override
  String get bizDurationStartDate => 'Duration & Start Date';

  @override
  String get bizNumberOfDays => 'Number of Days';

  @override
  String get bizFromDate => 'From Date';

  @override
  String get bizActivePeriod => 'Active period:';

  @override
  String get bizDiscountCode => 'Discount Code';

  @override
  String get bizHaveAPromoCodeEnter => 'Have a promo code? Enter it below.';

  @override
  String get bizEGOFFRO20 => 'e.g. OFFRO20';

  @override
  String get bizApply => 'Apply';

  @override
  String get bizProceedToCheckout => 'Proceed to Checkout';

  @override
  String get bizLive => 'Live';

  @override
  String get bizFilterProducts => 'Filter Products';

  @override
  String get bizEditProduct => 'Edit Product';

  @override
  String get bizAnalytics => 'Analytics';

  @override
  String get bizDeleteProduct => 'Delete Product';

  @override
  String get bizCatalogue => 'Catalogue';

  @override
  String get bizFilter => 'Filter';

  @override
  String get bizNewProduct => 'New Product';

  @override
  String get bizSearchProducts => 'Search products…';

  @override
  String get bizPending => 'Pending';

  @override
  String get bizCouldnTLoadProducts => 'Couldn\'t load products';

  @override
  String get bizNoProductsYet => 'No products yet';

  @override
  String get bizNoMatchingProducts => 'No matching products';

  @override
  String get bizTapNewProductToGet => 'Tap + New Product to get started';

  @override
  String get bizPaused => 'Paused';

  @override
  String get bizFree => 'Free';

  @override
  String get bizPaid => 'Paid';

  @override
  String get bizDeactivated => 'Deactivated';

  @override
  String get bizOn => 'On';

  @override
  String get bizOff => 'Off';

  @override
  String get bizOfferText => 'Offer Text';

  @override
  String get bizOriginalPrice => 'Original Price';

  @override
  String get bizOfferPrice => 'Offer Price';

  @override
  String get bizProductUpdated => 'Product updated!';

  @override
  String get bizDeleteThisProduct => 'Delete this product?';

  @override
  String get bizProductDeleted => 'Product deleted.';

  @override
  String get bizLogoTooLargeMax1MB => 'Logo too large. Max 1MB.';

  @override
  String get bizEnterACode => 'Enter a code';

  @override
  String get bizProductTitleRequired => 'Product title required';

  @override
  String get bizPleaseSelectAStoreFor =>
      'Please select a store for this product';

  @override
  String get bizPleaseSelectACityFor => 'Please select a city for this product';

  @override
  String get bizPleaseUploadAProductImage => 'Please upload a product image';

  @override
  String get bizEnterTheNumberOfDays => 'Enter the number of days (minimum 1)';

  @override
  String get bizProductOrderSummary => 'Product Order Summary';

  @override
  String get bizPrice => 'Price';

  @override
  String get bizProductWillGoToAdmin =>
      'Product will go to admin review. No payment needed.';

  @override
  String get bizRazorpayOpensProductLiveAfter =>
      'Razorpay opens. Product live after admin approval.';

  @override
  String get bizSaveProduct => 'Save Product';

  @override
  String get bizAddProduct => 'Add Product';

  @override
  String get bizProductTitle => 'Product Title *';

  @override
  String get bizEGRajStore50 => 'e.g. Raj Store ₹50 Off';

  @override
  String get bizEGGet50Off => 'e.g. Get ₹50 off on orders above ₹299';

  @override
  String get bizDiscountIsAutoCalculatedFrom =>
      'Discount is auto-calculated from prices';

  @override
  String get bizUploadImage => 'Upload Image';

  @override
  String get biz400400px => '📐 400×400px';

  @override
  String get bizMax1MB => '📦 Max 1MB';

  @override
  String get bizValidityDays => 'Validity (Days)';

  @override
  String get bizStartDate => 'Start date';

  @override
  String get bizEndDate => 'End date';

  @override
  String get bizNumberOfDays2 => 'Number of days';

  @override
  String get bizLivePeriod => 'Live period:';

  @override
  String bizFree0(String amount) {
    return 'Free ($amount)';
  }

  @override
  String get bizFreeProduct => 'Free product';

  @override
  String get bizYourBusiness => 'Your business';

  @override
  String get bizMyStores => 'My Stores';

  @override
  String get bizTapToAddYourFirst => 'Tap + to add your first store';

  @override
  String get bizActive => 'Active';

  @override
  String get bizDraft => 'Draft';

  @override
  String get bizInactive => 'Inactive';

  @override
  String get bizDeleted => 'Deleted';

  @override
  String get bizRemoved => 'Removed';

  @override
  String get bizSubscribe => 'Subscribe';

  @override
  String get bizAwaitingAdminApproval2 => 'Awaiting Admin Approval';

  @override
  String get bizQR => 'QR';

  @override
  String get bizGenQR => 'Gen QR';

  @override
  String get bizShowThisToCustomersTo =>
      'Show this to customers to earn points';

  @override
  String get bizDeviceLocationIsTurnedOff =>
      'Device location is turned off. Turn it on and try again.';

  @override
  String get bizUnableToIdentifyTheExact =>
      'Unable to identify the exact location from this Google Maps link. Please open Google Maps, drop a pin on the exact location, tap Share → Copy link, and try again.';

  @override
  String get bizCity => 'City';

  @override
  String get bizState => 'State';

  @override
  String get bizArea => 'Area';

  @override
  String get bizPostalCode => 'Postal code';

  @override
  String get bizLocationCaptured => 'Location captured';

  @override
  String get bizImageTooLargeMax2MB2 => 'Image too large. Max 2MB allowed.';

  @override
  String get bizStoreNameRequired => 'Store name required';

  @override
  String get bizPleaseSetTheStoreLocation =>
      'Please set the store location using \"Use current location\" or a Google Maps link';

  @override
  String get bizMobileNumberIsRequired => 'Mobile number is required';

  @override
  String get bizEnterAValid10Digit =>
      'Enter a valid 10-digit mobile number (starts with 6–9)';

  @override
  String get bizEditStore => 'Edit Store';

  @override
  String get bizAddStore => 'Add Store';

  @override
  String get bizStoreName => 'Store Name *';

  @override
  String get bizCategory => 'Category';

  @override
  String get bizSelectCategory => 'Select category';

  @override
  String get bizStoreLocation => 'Store location';

  @override
  String get bizUseGPSOrPasteA => 'Use GPS or paste a Maps link.';

  @override
  String get bizUseCurrentLocation => 'Use current location';

  @override
  String get bizOrPasteGoogleMapsLink => 'or paste Google Maps link';

  @override
  String get bizPasteGoogleMapsLinkHere => 'Paste Google Maps link here';

  @override
  String get bizResolveLocation => 'Resolve Location';

  @override
  String get bizLatitude => 'Latitude';

  @override
  String get bizLongitude => 'Longitude';

  @override
  String get bizAutoFilledByGPSOr =>
      'Auto-filled by GPS or Google Maps — you can edit any value. Edited values are saved as entered.';

  @override
  String get bizPhone => 'Phone';

  @override
  String get bizTapToChangeImage => 'Tap to change image';

  @override
  String get bizMainStoreImage => 'Main Store Image';

  @override
  String get biz800600px43 => '📐 800×600px (4:3)';

  @override
  String get bizUploadLogoOptional => 'Upload Logo [Optional]';

  @override
  String get bizTapToChangeLogo => 'Tap to change logo';

  @override
  String get bizTapToUploadLogo => 'Tap to upload logo';

  @override
  String get biz200200px11 => '📐 200×200px (1:1)';

  @override
  String get bizStoreTimingsOptional => 'Store Timings [Optional]';

  @override
  String get bizOpeningTime => 'Opening Time';

  @override
  String get bizOpenAt => 'Open at';

  @override
  String get bizClosingTime => 'Closing Time';

  @override
  String get bizCloseAt => 'Close at';

  @override
  String get bizAboutThisStoreDescriptionShown =>
      'About this store (description shown to customers)';

  @override
  String get bizSaveChanges => 'Save Changes';

  @override
  String get bizCreateStore => 'Create Store';

  @override
  String get bizConfirmingPayment => 'Confirming payment...';

  @override
  String get bizPleaseWaitAMoment => 'Please wait a moment';

  @override
  String get bizSubscriptionRequestSent => 'Subscription Request Sent';

  @override
  String get bizPlan => 'Plan';

  @override
  String get bizFrom => 'From';

  @override
  String get bizTo => 'To';

  @override
  String get bizTotalPayable => 'Total Payable';

  @override
  String get bizYourSubscriptionRequestHasBeen =>
      '✅  Your subscription request has been submitted.';

  @override
  String get bizConfirmPayment => 'Confirm Payment';

  @override
  String get bizRazorpayCheckoutWillOpenAfter =>
      'Razorpay checkout will open. After payment, admin will approve your store.';

  @override
  String get bizPayNow => 'Pay Now';

  @override
  String get bizSubscribeStore => 'Subscribe Store';

  @override
  String get bizSelectPlan => 'Select Plan';

  @override
  String get bizStartDate2 => 'Start Date';

  @override
  String get bizHaveADiscountCode => 'Have a discount code?';

  @override
  String get bizEnterCode => 'Enter code';

  @override
  String get bizDiscount2 => 'Discount:';

  @override
  String get bizRemove => 'Remove';

  @override
  String get bizProceedToPay => 'Proceed to Pay';

  @override
  String get bizRefresh => 'Refresh';

  @override
  String get bizNoInvoicesYet => 'No invoices yet';

  @override
  String get bizPullDownToRefresh => 'Pull down to refresh';

  @override
  String get bizShare => 'Share';

  @override
  String get bizDownloadPDF => 'Download PDF';

  @override
  String get bizAccountRegistered => 'Account registered';

  @override
  String get bizNewStoreCreated => 'New store created';

  @override
  String get bizStoreProfileUpdated => 'Store profile updated';

  @override
  String get bizStoreApproved => 'Store approved';

  @override
  String get bizStoreRejected => 'Store rejected';

  @override
  String get bizStoreSubscriptionActivated => 'Store subscription activated';

  @override
  String get bizFreeSubscriptionActivated => 'Free subscription activated';

  @override
  String get bizSubscriptionPaymentReceived => 'Subscription payment received';

  @override
  String get bizBannerSubmitted => 'Banner submitted';

  @override
  String get bizBannerApproved => 'Banner approved';

  @override
  String get bizBannerRejected => 'Banner rejected';

  @override
  String get bizBannerPaymentReceived => 'Banner payment received';

  @override
  String get bizProductSubmitted => 'Product submitted';

  @override
  String get bizProductApproved => 'Product approved';

  @override
  String get bizProductRejected => 'Product rejected';

  @override
  String get bizProductPaymentReceived => 'Product payment received';

  @override
  String get bizPaymentReceived => 'Payment received';

  @override
  String get bizFreePlanActivated => 'Free plan activated';

  @override
  String get bizProfileUpdated => 'Profile updated';

  @override
  String get bizQRCodeRegenerated => 'QR code regenerated';

  @override
  String get bizPayment => 'Payment';

  @override
  String get bizApprovedLive2 => '✅ Approved — Live';

  @override
  String get bizRejected2 => '❌ Rejected';

  @override
  String get bizPendingApproval2 => '⏳ Pending Approval';

  @override
  String get bizBusinessTimeline => 'Business timeline';

  @override
  String get bizNoActivityYet => 'No activity yet';

  @override
  String get bizMerchantAccount => 'Merchant account';

  @override
  String get bizTapPhotoToChange => 'Tap photo to change';

  @override
  String get bizSwitchBetweenUserMerchantInfluencer =>
      'Switch between User, Merchant & Influencer';

  @override
  String get bizKYCPolicy => 'KYC Policy';

  @override
  String get bizMerchantOffers => 'Merchant offers';

  @override
  String get bizMyDeals => 'My Deals';

  @override
  String get bizAddDeal => 'Add Deal';

  @override
  String get bizYouNeedAnActiveStore =>
      'You need an active store to add deals.';

  @override
  String get bizNoDealsYet => 'No deals yet';

  @override
  String get bizAddDealsToAttractMore => 'Add deals to attract more customers';

  @override
  String get bizEditDeal => 'Edit Deal';

  @override
  String get bizDeleteDeal => 'Delete Deal?';

  @override
  String get bizDelete => 'Delete';

  @override
  String get bizDealTitleIsRequired => 'Deal title is required';

  @override
  String get bizEndDateIsRequired => 'End date is required';

  @override
  String get bizPleaseAddAnImageBefore => 'Please add an image before saving.';

  @override
  String get bizDealUpdated => 'Deal updated!';

  @override
  String get bizDealAdded => 'Deal added!';

  @override
  String get bizDealTitleEG20 => 'Deal Title (e.g. 20% off on all items)';

  @override
  String get bizDescriptionOptional => 'Description (optional)';

  @override
  String get bizDealImage => 'Deal Image';

  @override
  String get bizTapToReplaceImage => 'Tap to replace image';

  @override
  String get bizMax2MBRequired => '📦 Max 2MB · Required';

  @override
  String get bizSelectEndDate => 'Select End Date';

  @override
  String get bizAllYourStoresProductsData =>
      'All your stores, products & data will be permanently removed';

  @override
  String get bizINoLongerRunMy => 'I no longer run my business';

  @override
  String get bizTheAppIsNotWorking => 'The app is not working properly for me';

  @override
  String get bizOnceYourAccountIsDeleted =>
      'Once your account is deleted, your stores, products, banners and data cannot be retrieved. Signing up again will create a new account.';

  @override
  String get bizYourMerchantAccountWillBe =>
      'Your merchant account will be marked for deletion. You will be logged out immediately and cannot log in again.\n\nOnce deleted, your stores, products and data cannot be retrieved. Are you absolutely sure?';

  @override
  String get bizChecking => 'Checking…';

  @override
  String get bizDiscountApplied2 => 'Discount applied!';

  @override
  String get bizChooseALaterEndDate =>
      'Choose a later end date (add at least 1 day)';

  @override
  String get bizRenewedSuccessfully => '✅ Renewed successfully!';

  @override
  String get bizRenewalSummary => 'Renewal Summary';

  @override
  String get bizNewEndDate => 'New end date';

  @override
  String get bizFreeRenewal => 'Free renewal';

  @override
  String get bizRenewFree => 'Renew free';

  @override
  String get bizRenewed => 'Renewed!';

  @override
  String get bizRenewProduct => 'Renew Product';

  @override
  String get bizNoEndDate => 'No end date';

  @override
  String get bizChooseHowLongTheProduct =>
      'Choose how long the product stays live.';

  @override
  String get bizDaysToAdd => 'Days to add';

  @override
  String get bizProductAnalytics => 'Product Analytics';

  @override
  String get bizCouldnTLoadAnalytics => 'Couldn\'t load analytics';

  @override
  String get bizPleaseCheckYourConnectionAnd =>
      'Please check your connection and try again.';

  @override
  String get bizPremiumListingAnalytics => 'Premium Listing Analytics';

  @override
  String get bizViews => '👁️ Views';

  @override
  String get bizShares => '🔗 Shares';

  @override
  String get bizStoreVisits => '🛒 Store Visits';

  @override
  String get bizLastSeen => '📅 Last Seen';

  @override
  String get bizStoreVisitsCustomersWhoVisited =>
      'Store Visits: customers who visited the store';

  @override
  String get bizConversionRate => 'Conversion Rate';

  @override
  String get bizSimilarProducts => 'Similar Products';

  @override
  String get bizPaymentSuccessful => 'Payment Successful!';

  @override
  String get bizYourPurchaseIsNowPending =>
      'Your purchase is now pending admin approval.';

  @override
  String get bizAdminWillReviewAndActivate =>
      'Admin will review and activate your purchase within 24 hours.';

  @override
  String get bizInfluencersAreComingSoon => 'Influencers are coming soon ✨';

  @override
  String get bizWeReBringingLocalCreators =>
      'We\'re bringing local creators and their recommendations to OffrO. Stay tuned!';

  @override
  String get bizPeopleShapingTheCity => 'People shaping the city';

  @override
  String get bizLocalVoices => 'Local Voices';

  @override
  String get bizPleaseSelectAStarRating => 'Please select a star rating first';

  @override
  String get bizPleaseLogInToSubmit => 'Please log in to submit a review';

  @override
  String get bizPleaseWriteAtLeastA => 'Please write at least a few words';

  @override
  String get bizVERIFIEDLOCALVOICE => 'VERIFIED LOCAL VOICE';

  @override
  String get bizRating => 'Rating';

  @override
  String get bizRateThisInfluencer => 'Rate this influencer';

  @override
  String get bizShareYourExperienceOptional =>
      'Share your experience (optional)';

  @override
  String get bizUpdateReview => 'Update Review';

  @override
  String get bizCreatorAccount => 'Creator account';

  @override
  String get bizCREATORWORKSPACE => 'CREATOR WORKSPACE';

  @override
  String get bizProfileViews => 'Profile views';

  @override
  String get bizSavedBy => 'Saved by';

  @override
  String get bizYourProfileIsLive => 'Your profile is live';

  @override
  String get bizYourProfileIsnTLive => 'Your profile isn\'t live yet';

  @override
  String get bizMerchantsAndCustomersCanDiscover =>
      'Merchants and customers can discover you.';

  @override
  String get bizOpenYourProfileToReview =>
      'Open your profile to review and publish it.';

  @override
  String get bizMATCHEDFORYOU => 'MATCHED FOR YOU';

  @override
  String get bizCampaignOpportunities => 'Campaign opportunities';

  @override
  String get bizINFLUENCERWORKSPACE => 'INFLUENCER WORKSPACE';

  @override
  String get bizCreateYourLocalProfile => 'Create your local profile.';

  @override
  String get bizYouLlNeedAnInfluencer =>
      'You\'ll need an Influencer profile to use the Influencer module — it\'s how customers and merchants discover you on OffrO.';

  @override
  String get bizAddInfluencerProfile => '+ Add influencer profile';

  @override
  String get bizNotAdded => 'Not added';

  @override
  String get bizContinuePublishingPayNow => 'Continue Publishing / Pay Now';

  @override
  String get bizMyProfile => 'My profile';

  @override
  String get bizBusinessDetails => 'Business Details';

  @override
  String get bizDisplayName => 'Display Name';

  @override
  String get bizBio => 'Bio';

  @override
  String get bizSocialPages => 'Social Pages';

  @override
  String get bizPrimarySpecialty => 'Primary Specialty';

  @override
  String get bizNoSpecialtySelected => 'No specialty selected';

  @override
  String get bizAccountDetails => 'Account Details';

  @override
  String get bizDisable => 'Disable';

  @override
  String get bizEnable => 'Enable';

  @override
  String get bizHideYourProfileFromCustomers =>
      'Hide your profile from customers';

  @override
  String get bizMakeYourProfileVisibleAgain =>
      'Make your profile visible again';

  @override
  String get bizSwitchToYourCustomerAccount =>
      'Switch to your Customer account';

  @override
  String get bizYourProfileIsSavedAs =>
      'Your profile is saved as a draft. Complete the one-time subscription payment from Edit Profile → Save & Publish to make it visible to customers.';

  @override
  String get bizPaymentIsBeingProcessedIf =>
      'Payment is being processed. If you completed a payment and this doesn\'t update, try Save & Publish again.';

  @override
  String get bizYourLastSubscriptionPaymentAttempt =>
      'Your last subscription payment attempt failed. Please try Save & Publish again to complete payment.';

  @override
  String get bizYourProfileIsNotYet => 'Your profile is not yet published.';

  @override
  String get bizDeleteInfluencerProfile => 'Delete Influencer Profile?';

  @override
  String get bizAreYouSureYouWant =>
      'Are you sure you want to delete your influencer profile? This action cannot be undone.';

  @override
  String get bizIfYouCreateANew =>
      'If you create a new influencer profile in the future, a new subscription payment will be required.';

  @override
  String get bizDeleteProfile => 'Delete Profile';

  @override
  String get bizREVIEWS => 'REVIEWS';

  @override
  String get bizCreatorReviews => 'Creator reviews';

  @override
  String get bizNameIsRequired => 'Name is required';

  @override
  String get bizPleaseSelectAState => 'Please select a state';

  @override
  String get bizPleaseEnterAValid10 =>
      'Please enter a valid 10-digit mobile number.';

  @override
  String get bizProfileImageIsRequiredTo =>
      'Profile image is required to publish your influencer profile.';

  @override
  String get bizWeCouldnTConfirmYour =>
      'We couldn\'t confirm your payment. If money was deducted, it will be verified shortly — please try Save & Publish again in a moment.';

  @override
  String get bizCreatorIdentity => 'Creator identity';

  @override
  String get bizEditProfile => 'Edit profile';

  @override
  String get bizAddProfile => 'Add profile';

  @override
  String get bizRequiredToPublish => 'Required to publish';

  @override
  String get bizName => 'Name *';

  @override
  String get bizEGPriyaSharma => 'e.g. Priya Sharma';

  @override
  String get bizSharingTheBestLocalFood =>
      'Sharing the best local food, cafés, shops and great offers around your city.';

  @override
  String get bizState2 => 'State *';

  @override
  String get bizSelectState => 'Select state';

  @override
  String get bizCity2 => 'City *';

  @override
  String get bizSelectStateFirst => 'Select state first';

  @override
  String get bizSelectCity => 'Select city';

  @override
  String get bizPrimarySpecialtySelectOneOr =>
      'Primary Specialty (select one or more)';

  @override
  String get bizNoCategoriesAvailable => 'No categories available';

  @override
  String get biz10DigitMobileNumber => '10-digit mobile number';

  @override
  String get bizSocialLinks => 'Social Links';

  @override
  String get bizInstagramURL => 'Instagram URL';

  @override
  String get bizYouTubeURL => 'YouTube URL';

  @override
  String get bizFacebookURL => 'Facebook URL';

  @override
  String get bizSaveKeepAsDraft => 'Save (keep as draft)';

  @override
  String get bizSavePublish => 'Save & Publish';

  @override
  String get bizSavePublishPayToPublish => 'Save & Publish (Pay to Publish)';

  @override
  String get bizNoSubscriptionPaymentIsCurrently =>
      'No subscription payment is currently required to publish your profile.';

  @override
  String get bizSubscriptionFee => 'Subscription Fee';

  @override
  String get bizDiscountCodeOptional => 'Discount code (optional)';

  @override
  String get bizAOneTimePaymentYou =>
      'A one-time payment — you won\'t be charged again for editing or re-publishing this profile.';

  @override
  String get bizEnterADiscountCodeFirst => 'Enter a discount code first';

  @override
  String get bizSelectSpecialties => 'Select specialties';

  @override
  String get bizCreateBrief => 'Create brief';

  @override
  String get bizShareWhatYouNeedAnd => 'Share what you need and where.';

  @override
  String get bizInviteCreators => 'Invite creators';

  @override
  String get bizLocalCreatorsInYourCity =>
      'Local creators in your city see it.';

  @override
  String get bizConfirmMatch => 'Confirm match';

  @override
  String get bizReviewWhoAcceptedAndConnect =>
      'Review who accepted and connect.';

  @override
  String get bizCreator => 'Creator';

  @override
  String get bizCollaborations => 'Collaborations';

  @override
  String get bizWorkWithTrustedLocalCreators =>
      'Work with trusted local creators.';

  @override
  String get bizCreateOneClearCampaignBrief =>
      'Create one clear campaign brief, review matched creators and confirm a collaboration without managing conversations across multiple apps.';

  @override
  String get bizHowItWorks => 'How it works';

  @override
  String get bizCreateCampaignBrief => 'Create campaign brief';

  @override
  String get bizYourCampaigns => 'Your campaigns';

  @override
  String get bizCollaborationWorkspace => 'Collaboration workspace';

  @override
  String get bizNoCampaignsYet => 'No campaigns yet';

  @override
  String get bizCreateYourFirstCampaignBrief =>
      'Create your first campaign brief to invite local creators.';

  @override
  String get bizWhenShouldYouUseThis => 'When should you use this?';

  @override
  String get bizUseCollaborationsForLaunchesVisits =>
      'Use collaborations for launches, visits and creator content. Regular store updates and discounts belong in Banners or Deals instead.';

  @override
  String get bizReviewProposals => 'Review proposals';

  @override
  String get bizCloseCampaign => 'Close campaign?';

  @override
  String get bizCreatorsWillNoLongerBe =>
      'Creators will no longer be able to accept this brief.';

  @override
  String get bizKeepOpen => 'Keep open';

  @override
  String get bizCampaign => 'Campaign';

  @override
  String get bizProposals => 'Proposals';

  @override
  String get bizCreatorsWhoAccepted => 'Creators who accepted';

  @override
  String get bizNoProposalsYet => 'No proposals yet';

  @override
  String get bizCreatorsInYourCityWill =>
      'Creators in your city will appear here once they accept your brief.';

  @override
  String get bizClosing => 'Closing…';

  @override
  String get bizCloseCampaign2 => 'Close campaign';

  @override
  String get bizChatOnWhatsApp => 'Chat on WhatsApp';

  @override
  String get bizCouldnTOpenWhatsApp => 'Couldn\'t open WhatsApp.';

  @override
  String get bizPleaseSelectAStore2 => 'Please select a store.';

  @override
  String get bizEnterACampaignTitleAt =>
      'Enter a campaign title (at least 3 characters).';

  @override
  String get bizSelectACampaignObjective => 'Select a campaign objective.';

  @override
  String get bizDescribeWhatTheCreatorShould =>
      'Describe what the creator should communicate (at least 10 characters).';

  @override
  String get bizSelectTheContentYouNeed => 'Select the content you need.';

  @override
  String get bizChooseAPublishByDate => 'Choose a publish-by date.';

  @override
  String get bizChooseAVisitDateFor =>
      'Choose a visit date for the store visit.';

  @override
  String get bizVisitDateCanTBe =>
      'Visit date can\'t be after the publish-by date.';

  @override
  String get bizBriefPublishedMatchingCreatorsCan =>
      'Brief published. Matching creators can now see it.';

  @override
  String get bizCampaignBrief => 'Campaign brief';

  @override
  String get bizAddAndActivateAStore =>
      'Add and activate a store before creating a campaign brief.';

  @override
  String get bizSelectStore2 => 'Select store';

  @override
  String get bizCampaignTitle => 'Campaign title';

  @override
  String get bizExampleSeasonalMenuLaunch => 'Example: Seasonal menu launch';

  @override
  String get bizCampaignObjective => 'Campaign objective';

  @override
  String get bizSelectObjective => 'Select objective';

  @override
  String get bizWhatShouldTheCreatorCommunicate =>
      'What should the creator communicate?';

  @override
  String get bizKeyMessageExperienceAndDetails =>
      'Key message, experience and details they should know...';

  @override
  String get bizRequestedContent => 'Requested content';

  @override
  String get bizVisitDate => 'Visit date';

  @override
  String get bizSelectDate => 'Select date';

  @override
  String get bizPublishBy => 'Publish by';

  @override
  String get bizPreferredCreatorSpeciality => 'Preferred creator speciality';

  @override
  String get bizSelectSpeciality => 'Select speciality';

  @override
  String get bizNoPaymentProcessing => 'No payment processing';

  @override
  String get bizOffrOConnectsYouWithCreators =>
      'OffrO connects you with creators. Any compensation is agreed directly between you and the creator.';

  @override
  String get bizPublishing => 'Publishing…';

  @override
  String get bizPublishBrief => 'Publish brief';

  @override
  String get bizMatchedLocally => 'Matched locally';

  @override
  String get bizReviewCollaborationRequestsFromReleva =>
      'Review collaboration requests from relevant merchants in your city.';

  @override
  String get bizNoCollaborationRequestsYet => 'No collaboration requests yet';

  @override
  String get bizRequestsFromMerchantsInYour =>
      'Requests from merchants in your city will appear here.';

  @override
  String get bizAccepted => 'Accepted';

  @override
  String get bizDeclined => 'Declined';

  @override
  String get bizNewCollaborationRequest => 'New collaboration request';

  @override
  String get bizViewBrief => 'View brief';

  @override
  String get bizNoCampaignRequestsYet => 'No campaign requests yet';

  @override
  String get bizNewBriefsFromMerchantsIn =>
      'New briefs from merchants in your city will appear here.';

  @override
  String get bizCollaborationAccepted => 'Collaboration accepted.';

  @override
  String get bizRequestDeclined => 'Request declined.';

  @override
  String get bizCollaborationRequest => 'Collaboration request';

  @override
  String get bizBrief => 'Brief';

  @override
  String get bizCompleteYourProfileSubscriptionTo =>
      'Complete your profile subscription to accept collaborations.';

  @override
  String get bizObjective => 'Objective';

  @override
  String get bizMessage => 'Message';

  @override
  String get bizPreferredSpeciality => 'Preferred speciality';

  @override
  String get bizThisCollaborationIsForPromotion =>
      'This collaboration is for promotion on your Instagram. There is no in-app chat.';

  @override
  String get bizYouAcceptedThisCollaboration =>
      'You accepted this collaboration';

  @override
  String get bizTheMerchantSContactNumber =>
      'The merchant\'s contact number is not available.';

  @override
  String get bizContactTheMerchantToPlan =>
      'Contact the merchant to plan your visit:';

  @override
  String get bizThisRequestIsNoLonger => 'This request is no longer open.';

  @override
  String get bizPleaseWait => 'Please wait…';

  @override
  String get bizAcceptCollaboration => 'Accept collaboration';

  @override
  String get bizDecline => 'Decline';

  @override
  String bizFreeSlotsUsedOf(String used, String limit) {
    return '$used/$limit free slots used';
  }

  @override
  String bizWelcomeBackName(String name) {
    return 'Welcome back, $name';
  }

  @override
  String bizBannerSubmittedMsg(String message) {
    return '✅ Banner submitted! $message';
  }

  @override
  String get bizBannerFallbackDeal =>
      'If this deal is later removed, the banner opens the store instead.';

  @override
  String get bizBannerFallbackProduct =>
      'If this product is later removed, the banner opens the store instead.';

  @override
  String bizPaymentFailedMsg(String error) {
    return 'Payment failed: $error';
  }

  @override
  String bizToggleFailed(String error) {
    return 'Toggle failed: $error';
  }

  @override
  String bizFreeProductSlotsUsed(String used, String limit) {
    return '$used / $limit free product slots used';
  }

  @override
  String bizAdditionalProductsCharged(String price) {
    return 'Additional products are charged at $price per day of validity.';
  }

  @override
  String bizDeleteProductBody(String title) {
    return '\"$title\" will be permanently removed and cannot be reactivated. Any payment already made for this product will not be refunded.';
  }

  @override
  String get bizThisProduct => 'This product';

  @override
  String bizDeleteError(String error) {
    return 'Error deleting: $error';
  }

  @override
  String bizCodeAppliedPct(String value) {
    return '✅ Code applied — $value% off!';
  }

  @override
  String bizCodeAppliedAmt(String value) {
    return '✅ Code applied — $value off!';
  }

  @override
  String bizMaxValidity(String days) {
    return 'Maximum validity is $days days';
  }

  @override
  String bizProductSubmittedMsg(String message) {
    return '✅ Product submitted! $message';
  }

  @override
  String bizPaymentErrorMsg(String error) {
    return 'Payment error: $error';
  }

  @override
  String get bizCouldNotOpenPayment =>
      'Could not open payment. Please try again.';

  @override
  String bizMaxDays(String days) {
    return 'Maximum $days days';
  }

  @override
  String bizFreeSlotsRemaining(String remaining, String limit) {
    return 'You have $remaining of $limit free product slots remaining.';
  }

  @override
  String bizFreeSlotsAllUsed(String limit, String price) {
    return 'You have used all $limit free product slots.\nPrice is $price per day + GST for the days you choose.';
  }

  @override
  String bizLocationUpdatedTo(String city) {
    return 'Location updated to $city';
  }

  @override
  String bizCouldNotGetLocation(String error) {
    return 'Could not get location: $error';
  }

  @override
  String get bizLocationPermissionNeeded =>
      'Location permission is required for current location. Allow it and try again.';

  @override
  String get bizSetStoreLocationFirst =>
      'Please set the store\'s location using \"Use Current Location\" or a Google Maps link before creating the store.';

  @override
  String get bizStoreLocationIncomplete =>
      'The store location looks incomplete. Use \"Use Current Location\" or a Google Maps link to set a valid location.';

  @override
  String bizPaymentCancelledOrFailed(String error) {
    return 'Payment cancelled or failed: $error';
  }

  @override
  String bizExternalWallet(String name) {
    return 'External wallet: $name';
  }

  @override
  String bizDiscountAppliedPct(String value) {
    return '✅ $value% discount applied!';
  }

  @override
  String bizDiscountAppliedAmt(String value) {
    return '✅ $value discount applied!';
  }

  @override
  String get bizSubmittedPayRep =>
      '✅  Your subscription request has been submitted.\n\nPlease pay the amount to your Offro representative.\nThe admin will activate your store once payment is confirmed.';

  @override
  String bizEndDateExceedsStore(String date) {
    return 'End date cannot exceed store expiry ($date)';
  }

  @override
  String bizCurrentEndDate(String date) {
    return 'Current end date: $date';
  }

  @override
  String bizFreeSlotAvailable(String used, String limit) {
    return 'A free product slot is available ($used of $limit in use), so this renewal is free.';
  }

  @override
  String bizAllFreeSlotsUsedRenew(String limit, String price) {
    return 'You are using all $limit free product slots. Renewing costs $price per day added + GST.';
  }

  @override
  String bizViewersVisitedStore(String pct) {
    return '$pct% of viewers visited the store (tapped Sold by)';
  }

  @override
  String get bizProductsExpiringOne => '1 product expiring soon — tap to renew';

  @override
  String bizProductsExpiringMany(String n) {
    return '$n products expiring soon — tap to renew';
  }

  @override
  String bizMoreFromStore(String store) {
    return 'More from $store';
  }

  @override
  String get bizThisStore => 'this store';

  @override
  String bizPurchasePendingNamed(String store) {
    return 'Your \"$store\" purchase is now pending admin approval.';
  }

  @override
  String bizNoInfluencersInCity(String city) {
    return 'No influencers available in $city yet';
  }

  @override
  String bizSeeAllCount(String count) {
    return 'See all ($count)';
  }

  @override
  String bizReviewsFor(String name) {
    return 'Reviews for $name';
  }

  @override
  String bizPublishByDate(String date) {
    return 'Publish by $date';
  }

  @override
  String bizSeeAllRequests(String count) {
    return 'See all $count requests';
  }

  @override
  String get bizDeclinedCanAccept =>
      'You declined this request. You can still accept it while it is open.';

  @override
  String get bizDeclinedRequest => 'You declined this request.';

  @override
  String get errPayNoMessage =>
      'Payment could not be completed. Please try again.';

  @override
  String get errPayGeneric =>
      'We couldn\'t complete your payment. Please try again.';

  @override
  String get errPayCancelled =>
      'Payment cancelled. You haven\'t been charged. You can try again whenever you\'re ready.';

  @override
  String get errPayPending =>
      'We haven\'t received confirmation of your payment yet. Please check again shortly before paying a second time.';

  @override
  String get errPayNetwork =>
      'Payment couldn\'t be completed because of a connection problem. Please check your internet and try again.';

  @override
  String bizStoresActiveOne(String active) {
    return '1 Store • $active Active';
  }

  @override
  String bizStoresActiveMany(String count, String active) {
    return '$count Stores • $active Active';
  }

  @override
  String bizNLive(String n) {
    return '$n Live';
  }

  @override
  String bizNPending(String n) {
    return '$n Pending';
  }

  @override
  String get bizSubmittedWord => 'Submitted';

  @override
  String bizBannersStatusOne(String status) {
    return '1 Banner • $status';
  }

  @override
  String bizBannersStatusMany(String count, String status) {
    return '$count Banners • $status';
  }

  @override
  String bizNDays(String n) {
    return '$n Days';
  }

  @override
  String bizStartEndRange(String from, String end) {
    return 'Start: $from   →   End: $end';
  }

  @override
  String bizFromDateLabel(String date) {
    return 'From: $date';
  }

  @override
  String bizUntilDateLabel(String date) {
    return 'Until: $date';
  }

  @override
  String bizInvoiceColon(String no) {
    return 'Invoice: $no';
  }

  @override
  String bizPerDayPrice(String amount) {
    return '$amount/day';
  }

  @override
  String bizGstPct(String pct) {
    return 'GST ($pct%)';
  }

  @override
  String bizPayAmount(String amount) {
    return 'Pay $amount';
  }

  @override
  String bizPricePerDayTimesDays(String price, String days) {
    return '$price/day × $days days';
  }

  @override
  String bizDiscountTotalPct(String amount, String pct, String total) {
    return '−$amount ($pct%) off  →  Total: $total';
  }

  @override
  String bizDiscountTotalAmt(String amount, String total) {
    return '−$amount off  →  Total: $total';
  }

  @override
  String get bizResultOne => '1 result';

  @override
  String bizResultMany(String n) {
    return '$n results';
  }

  @override
  String bizExpiredOn(String date) {
    return 'Expired $date';
  }

  @override
  String bizExpiresOn(String date) {
    return 'Expires $date';
  }

  @override
  String bizErrorColon(String error) {
    return 'Error: $error';
  }

  @override
  String bizDayTimesPriceOne(String days, String price) {
    return '$days day × $price/day';
  }

  @override
  String bizDayTimesPriceMany(String days, String price) {
    return '$days days × $price/day';
  }

  @override
  String bizFailedColon(String error) {
    return 'Failed: $error';
  }

  @override
  String get bizDealCountOne => '1 Deal';

  @override
  String bizDealCountMany(String n) {
    return '$n Deals';
  }

  @override
  String bizPricePlusGst(String price, String pct, String tax) {
    return '$price + $pct% $tax';
  }

  @override
  String bizPlanPeriodLine(String plan, String from, String end) {
    return 'Plan: $plan  •  $from – $end';
  }

  @override
  String bizBaseGstLine(String base, String gst, String tax) {
    return 'Base: $base  $tax: $gst';
  }

  @override
  String bizDiscountCodeLine(String code, String amount) {
    return 'Discount ($code): −$amount';
  }

  @override
  String bizBannerTitleLine(String title) {
    return 'Banner: $title';
  }

  @override
  String bizProductTitleLine(String title) {
    return 'Product: $title';
  }

  @override
  String get bizUntitledWord => 'Untitled';

  @override
  String bizEndsOn(String date) {
    return 'Ends $date';
  }

  @override
  String bizDeleteDealNamed(String title) {
    return 'Delete \"$title\"?';
  }

  @override
  String bizMaxDateLine(String date) {
    return 'Max: $date';
  }

  @override
  String bizRenewAmount(String amount) {
    return 'Renew · $amount';
  }

  @override
  String bizCodeAppliedNamed(String code) {
    return 'Code \'$code\' applied';
  }

  @override
  String bizNActive(String n) {
    return '$n active';
  }

  @override
  String bizVisitOn(String date) {
    return 'Visit $date';
  }

  @override
  String bizCallPhone(String phone) {
    return 'Call $phone';
  }

  @override
  String get bizAllProducts => 'All Products';

  @override
  String get bizAllStores => 'All Stores';

  @override
  String get bizBannersTab => 'Banners';

  @override
  String get bizPaymentsTab => 'Payments';

  @override
  String get bizAdditionalProduct => 'Additional product';

  @override
  String get bizBillingSubscriptions => 'Billing & subscriptions';

  @override
  String bizTillDate(String date) {
    return 'Till: $date';
  }

  @override
  String bizExpDate(String date) {
    return 'Exp: $date';
  }

  @override
  String get bizOneDayWord => '1 day';

  @override
  String bizDaysCountWord(String n) {
    return '$n days';
  }

  @override
  String get bizProposalOne => '1 proposal';

  @override
  String bizProposalMany(String n) {
    return '$n proposals';
  }

  @override
  String get bizInfluencerSubscription => 'Influencer Subscription';

  @override
  String get bizOffrOInfluencer => 'OffrO Influencer';

  @override
  String get authEnterOtp4 => 'Enter 4-digit OTP';

  @override
  String get authOtpIncorrect => 'Incorrect OTP. Please try again.';

  @override
  String get authOtpVerifyFailed =>
      'Unable to verify OTP right now. Please try again.';

  @override
  String get authCodeSentSms => 'Code sent by SMS.';

  @override
  String get authOtpResent => 'OTP resent successfully.';

  @override
  String get authResendFailed => 'Resend failed.';

  @override
  String get authOtpResendFailed =>
      'Unable to resend OTP right now. Please try again.';

  @override
  String get authSettingUpAccount => 'Setting up your account...';

  @override
  String authPreparingDashboard(String dots) {
    return 'Preparing your business dashboard$dots';
  }

  @override
  String get authLoadingBusinessData =>
      'Loading stores, products and activity...';

  @override
  String get authEnterYourName => 'Enter your name';

  @override
  String get authAcceptTermsRequired =>
      'Please tick the box to accept the Terms & Conditions and Privacy Policy and consent to WhatsApp updates from OffrO, to continue';

  @override
  String get authAlreadyRegistered =>
      'This number is already registered. Please login.';

  @override
  String get authNotRegistered =>
      'Number not registered. Please register first.';

  @override
  String get authOtpSendFailed =>
      'Unable to send OTP right now. Please try again.';

  @override
  String get authLoginFailed => 'Login failed — please try again.';

  @override
  String get authAgreeTo => 'I agree to the';

  @override
  String get authAnd => 'and';

  @override
  String get authConsentWhatsApp =>
      'and consent to receive updates and promotional messages from OffrO via WhatsApp.';

  @override
  String get authMerchantTermsTitle => 'Merchant Terms & Conditions';

  @override
  String get authMerchantTermsEmpty =>
      'Merchant terms and conditions will be posted here.';

  @override
  String get authAgreeMerchantTerms => 'I agree to the Merchant Terms';

  @override
  String get authAcceptContinue => 'Accept & Continue';

  @override
  String get phoneEnterNumber => 'Enter your mobile number';

  @override
  String get phoneInvalid10 => 'Enter a valid 10-digit mobile number';

  @override
  String phoneInvalidCountry(String country) {
    return 'Enter a valid $country mobile number';
  }

  @override
  String get countryNameIN => 'India';

  @override
  String get countryNameJO => 'Jordan';

  @override
  String get countryNameNP => 'Nepal';

  @override
  String get countryNamePH => 'Philippines';

  @override
  String get countryNameSA => 'Saudi Arabia';

  @override
  String get locGateTitle => 'Allow location access';

  @override
  String get locGateBody =>
      'OffrO needs your location to show nearby and relevant content.';

  @override
  String get locGateBlockedMsg =>
      'Location permission is turned off for OffrO. You can allow it in app settings, or choose your city manually.';

  @override
  String get locGateServiceOffMsg =>
      'Your device\'s location services are off. Turn them on, or choose your city manually.';

  @override
  String get locGateDeniedMsg =>
      'Location permission wasn\'t allowed. You can still choose your city manually.';

  @override
  String get locGateOpenSettings => 'Open app settings';

  @override
  String get locGateAllow => 'Allow location';

  @override
  String get locGateChooseManually => 'Choose city manually';

  @override
  String get locCardChecking => 'Checking location…';

  @override
  String get locCardServicesOff => 'Location services are off';

  @override
  String get locCardServicesOffSub =>
      'Turn on your device location to see places near you';

  @override
  String get locCardEnablePerm => 'Enable location permissions';

  @override
  String get locCardEnablePermSub => 'for more relevant suggestions near you';

  @override
  String get locCardBlocked => 'Location permission is blocked';

  @override
  String get locCardBlockedSub => 'Allow location for OffrO in app settings';

  @override
  String get locCardDetecting => 'Detecting your location…';

  @override
  String locCardTapRetry(String error) {
    return '$error Tap to retry.';
  }

  @override
  String get splashTagline => 'Discover · Save · Earn';

  @override
  String get commonBack => 'Back';

  @override
  String get stateErrorTitle => 'Couldn\'t load this';

  @override
  String get stateErrorMessage => 'Check your connection and try again.';

  @override
  String get notifDiagTitle => 'Notification Diagnostics';

  @override
  String get notifDiagRegStatusTitle => 'FCM Registration Status';

  @override
  String get notifDiagCopy => 'Copy';

  @override
  String get notifDiagRecheck => 'Re-check';

  @override
  String get notifDiagTokenCopied => 'FCM token copied';

  @override
  String get notifDiagCopiedToClipboard => 'Diagnostics copied to clipboard';

  @override
  String get notifDiagClear => 'Clear';

  @override
  String get notifDiagClearLogTitle => 'Clear Log?';

  @override
  String get notifDiagClearLogBody =>
      'This will remove all notification event entries.';

  @override
  String get notifDiagEmptyTitle => 'No events logged yet';

  @override
  String get notifDiagEmptyHint =>
      'Send a notification and check back\nto see which handlers fired';

  @override
  String get notifDiagRefresh => 'Refresh';

  @override
  String get notifDiagChecking => 'Checking...';

  @override
  String notifDiagSecondsAgo(String n) {
    return '${n}s ago';
  }
}
