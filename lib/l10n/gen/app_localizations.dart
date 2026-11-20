import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_ar.dart';
import 'app_localizations_en.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'gen/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
      : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
    delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
  ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('ar'),
    Locale('en')
  ];

  /// Small label above the OTP heading
  ///
  /// In en, this message translates to:
  /// **'VERIFICATION'**
  String get otpEyebrow;

  /// OTP heading, first part (plain)
  ///
  /// In en, this message translates to:
  /// **'Verify your'**
  String get otpTitleLead;

  /// OTP heading, accent part
  ///
  /// In en, this message translates to:
  /// **'number'**
  String get otpTitleAccent;

  /// OTP explanation; {phone} is the number the code was sent to
  ///
  /// In en, this message translates to:
  /// **'We sent a 4-digit OTP to\n{phone}'**
  String otpSentTo(String phone);

  /// Primary button on the OTP screen
  ///
  /// In en, this message translates to:
  /// **'Verify OTP'**
  String get otpVerifyButton;

  /// Text before the resend link
  ///
  /// In en, this message translates to:
  /// **'Didn\'t receive OTP?'**
  String get otpDidntReceive;

  /// Countdown before resend is available; {seconds} is a number of seconds
  ///
  /// In en, this message translates to:
  /// **'Resend in {seconds}s'**
  String otpResendIn(String seconds);

  /// Resend link
  ///
  /// In en, this message translates to:
  /// **'Resend OTP'**
  String get otpResendAction;

  /// Link that requests the code by SMS (non-India countries)
  ///
  /// In en, this message translates to:
  /// **'Send code by SMS instead'**
  String get otpSmsFallback;

  /// Small label above the role chooser heading
  ///
  /// In en, this message translates to:
  /// **'MAKE OFFRO YOURS'**
  String get roleEyebrow;

  /// Role chooser heading, first part
  ///
  /// In en, this message translates to:
  /// **'How will you use'**
  String get roleTitleLead;

  /// Role chooser heading, brand part (accent)
  ///
  /// In en, this message translates to:
  /// **'OffrO?'**
  String get roleTitleBrand;

  /// Role chooser explanation
  ///
  /// In en, this message translates to:
  /// **'Choose your starting space. You can add another role later from your profile.'**
  String get roleSubtitle;

  /// Role name: customer
  ///
  /// In en, this message translates to:
  /// **'Customer'**
  String get roleCustomer;

  /// Customer role description
  ///
  /// In en, this message translates to:
  /// **'Discover places, products and local offers'**
  String get roleCustomerDesc;

  /// Role name: merchant
  ///
  /// In en, this message translates to:
  /// **'Merchant'**
  String get roleMerchant;

  /// Merchant role description
  ///
  /// In en, this message translates to:
  /// **'Grow your business and manage your storefront'**
  String get roleMerchantDesc;

  /// Role name: influencer
  ///
  /// In en, this message translates to:
  /// **'Influencer'**
  String get roleInfluencer;

  /// Influencer role description
  ///
  /// In en, this message translates to:
  /// **'Create local stories and collaborate with brands'**
  String get roleInfluencerDesc;

  /// Checkbox label
  ///
  /// In en, this message translates to:
  /// **'Remember my choice'**
  String get roleRemember;

  /// Checkbox hint
  ///
  /// In en, this message translates to:
  /// **'You can change this anytime from Profile'**
  String get roleRememberHint;

  /// Button label
  ///
  /// In en, this message translates to:
  /// **'Enter as Customer'**
  String get roleEnterCustomer;

  /// Button label
  ///
  /// In en, this message translates to:
  /// **'Enter as Merchant'**
  String get roleEnterMerchant;

  /// Button label
  ///
  /// In en, this message translates to:
  /// **'Enter as Influencer'**
  String get roleEnterInfluencer;

  /// Button label when no role is selected
  ///
  /// In en, this message translates to:
  /// **'Select a role to continue'**
  String get roleSelectPrompt;

  /// Switch-mode heading, first part
  ///
  /// In en, this message translates to:
  /// **'Switch'**
  String get switchTitleLead;

  /// Switch-mode heading, accent part
  ///
  /// In en, this message translates to:
  /// **'mode'**
  String get switchTitleAccent;

  /// Shows the active mode; {mode} is the role name (Customer / Merchant / Influencer)
  ///
  /// In en, this message translates to:
  /// **'You are currently in {mode} mode'**
  String switchCurrently(String mode);

  /// Customer mode description
  ///
  /// In en, this message translates to:
  /// **'Browse stores, products and offers'**
  String get switchCustomerSubtitle;

  /// Merchant mode description
  ///
  /// In en, this message translates to:
  /// **'Manage store, products and banners'**
  String get switchMerchantSubtitle;

  /// Influencer mode description
  ///
  /// In en, this message translates to:
  /// **'Manage your influencer profile'**
  String get switchInfluencerSubtitle;

  /// Badge on the login hero
  ///
  /// In en, this message translates to:
  /// **'LOCAL, MADE EASY'**
  String get loginBadge;

  /// Small label above the login heading
  ///
  /// In en, this message translates to:
  /// **'WELCOME TO YOUR NEIGHBOURHOOD'**
  String get loginWelcomeEyebrow;

  /// Login heading, first part
  ///
  /// In en, this message translates to:
  /// **'Find more to'**
  String get loginHeroLead;

  /// Login heading, accent word
  ///
  /// In en, this message translates to:
  /// **'love'**
  String get loginHeroAccent;

  /// Login heading, last part
  ///
  /// In en, this message translates to:
  /// **', nearby.'**
  String get loginHeroTail;

  /// Login hero description
  ///
  /// In en, this message translates to:
  /// **'Local stores, thoughtful offers and people worth discovering—all in one place.'**
  String get loginHeroBody;

  /// Tab label
  ///
  /// In en, this message translates to:
  /// **'Login'**
  String get loginTabLogin;

  /// Tab label
  ///
  /// In en, this message translates to:
  /// **'Register'**
  String get loginTabRegister;

  /// Field label
  ///
  /// In en, this message translates to:
  /// **'Your name'**
  String get loginYourName;

  /// Field placeholder
  ///
  /// In en, this message translates to:
  /// **'Enter your full name'**
  String get loginNameHint;

  /// Field label
  ///
  /// In en, this message translates to:
  /// **'Mobile number'**
  String get loginMobile;

  /// Primary button (login)
  ///
  /// In en, this message translates to:
  /// **'Get verification code'**
  String get loginGetCode;

  /// Primary button (register)
  ///
  /// In en, this message translates to:
  /// **'Register & get verification code'**
  String get loginRegisterGetCode;

  /// Divider between the primary button and guest button
  ///
  /// In en, this message translates to:
  /// **'OR'**
  String get loginOr;

  /// Guest button
  ///
  /// In en, this message translates to:
  /// **'Continue as guest'**
  String get loginGuest;

  /// Label above the social links
  ///
  /// In en, this message translates to:
  /// **'FOLLOW THE LOCAL STORY'**
  String get loginFollow;

  /// Skip button
  ///
  /// In en, this message translates to:
  /// **'Skip'**
  String get onboardingSkip;

  /// Slide 1 title (fallback slide)
  ///
  /// In en, this message translates to:
  /// **'Discover Local Deals'**
  String get onboardingSlide1Title;

  /// Slide 1 subtitle (fallback slide)
  ///
  /// In en, this message translates to:
  /// **'Find the best offers from stores near you'**
  String get onboardingSlide1Subtitle;

  /// Slide 2 title (fallback slide)
  ///
  /// In en, this message translates to:
  /// **'Earn Reward Points'**
  String get onboardingSlide2Title;

  /// Slide 2 subtitle (fallback slide)
  ///
  /// In en, this message translates to:
  /// **'Every visit earns you points you can redeem'**
  String get onboardingSlide2Subtitle;

  /// Slide 3 title (fallback slide)
  ///
  /// In en, this message translates to:
  /// **'Get Gift Vouchers'**
  String get onboardingSlide3Title;

  /// Slide 3 subtitle (fallback slide)
  ///
  /// In en, this message translates to:
  /// **'Redeem your points for Amazon & Flipkart vouchers'**
  String get onboardingSlide3Subtitle;

  /// Title of the country picker sheet
  ///
  /// In en, this message translates to:
  /// **'Select country'**
  String get countryPickerTitle;

  /// Profile section title
  ///
  /// In en, this message translates to:
  /// **'My activity'**
  String get profileGroupActivity;

  /// Profile section title
  ///
  /// In en, this message translates to:
  /// **'Account'**
  String get profileGroupAccount;

  /// Profile section title
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get profileGroupLanguage;

  /// Profile section title
  ///
  /// In en, this message translates to:
  /// **'About & legal'**
  String get profileGroupLegal;

  /// Profile section title
  ///
  /// In en, this message translates to:
  /// **'Session'**
  String get profileGroupSession;

  /// Badge under the name for guests
  ///
  /// In en, this message translates to:
  /// **'Browsing as guest'**
  String get profileGuestBadge;

  /// Badge under the name for members
  ///
  /// In en, this message translates to:
  /// **'OffrO member'**
  String get profileMemberBadge;

  /// Row label that opens the language chooser
  ///
  /// In en, this message translates to:
  /// **'App language'**
  String get languageRowLabel;

  /// Title of the language chooser
  ///
  /// In en, this message translates to:
  /// **'Choose language'**
  String get languageSheetTitle;

  /// Note in the language chooser
  ///
  /// In en, this message translates to:
  /// **'The app stays in English until you choose another language.'**
  String get languageSheetNote;

  /// Native name of English (same in every language)
  ///
  /// In en, this message translates to:
  /// **'English'**
  String get languageNameEn;

  /// Native name of Arabic (same in every language)
  ///
  /// In en, this message translates to:
  /// **'العربية'**
  String get languageNameAr;

  /// Accessibility label of the language button
  ///
  /// In en, this message translates to:
  /// **'Change language'**
  String get languageButtonSemantics;

  /// Eyebrow above the Profile title
  ///
  /// In en, this message translates to:
  /// **'Your OffrO'**
  String get profileEyebrow;

  /// Profile screen title
  ///
  /// In en, this message translates to:
  /// **'Profile'**
  String get profileTitle;

  /// Profile statistic label
  ///
  /// In en, this message translates to:
  /// **'Saved'**
  String get profileStatSaved;

  /// Profile statistic label
  ///
  /// In en, this message translates to:
  /// **'Points'**
  String get profileStatPoints;

  /// Bottom navigation: Home tab
  ///
  /// In en, this message translates to:
  /// **'Home'**
  String get navHome;

  /// Bottom navigation: Explore tab
  ///
  /// In en, this message translates to:
  /// **'Explore'**
  String get navExplore;

  /// Bottom navigation: Deals tab
  ///
  /// In en, this message translates to:
  /// **'Deals'**
  String get navDeals;

  /// Bottom navigation: Rewards tab
  ///
  /// In en, this message translates to:
  /// **'Rewards'**
  String get navRewards;

  /// Bottom navigation: Profile tab
  ///
  /// In en, this message translates to:
  /// **'Profile'**
  String get navProfile;

  /// Bottom navigation (merchant): Invoices tab
  ///
  /// In en, this message translates to:
  /// **'Invoices'**
  String get navInvoices;

  /// Bottom navigation (merchant): Activity tab
  ///
  /// In en, this message translates to:
  /// **'Activity'**
  String get navActivity;

  /// Bottom navigation (influencer): Opportunities tab
  ///
  /// In en, this message translates to:
  /// **'Opportunities'**
  String get navOpportunities;

  /// Home header: small label above the selected location
  ///
  /// In en, this message translates to:
  /// **'Exploring'**
  String get homeExploring;

  /// Home header: shown when no location is chosen yet
  ///
  /// In en, this message translates to:
  /// **'Select location'**
  String get homeSelectLocation;

  /// Home search bar placeholder
  ///
  /// In en, this message translates to:
  /// **'Search stores, products or services'**
  String get homeSearchHint;

  /// Small pill on the hero strip; the arrow points in reading direction
  ///
  /// In en, this message translates to:
  /// **'View →'**
  String get homeViewArrow;

  /// City hero card: small badge
  ///
  /// In en, this message translates to:
  /// **'LOCAL DEALS & STORES'**
  String get homeHeroBadge;

  /// City hero card heading, first word; the city name follows on the next line
  ///
  /// In en, this message translates to:
  /// **'Explore'**
  String get homeExploreLead;

  /// City hero card subtitle
  ///
  /// In en, this message translates to:
  /// **'Discover stores, deals & local favorites'**
  String get homeHeroSubtitle;

  /// City hero card button
  ///
  /// In en, this message translates to:
  /// **'Discover stores'**
  String get homeDiscoverStores;

  /// City hero card: fallback name when no city is known
  ///
  /// In en, this message translates to:
  /// **'Your City'**
  String get homeYourCity;

  /// Deal card: ends today
  ///
  /// In en, this message translates to:
  /// **'Ends today'**
  String get homeDealEndsToday;

  /// Deal card: one day left
  ///
  /// In en, this message translates to:
  /// **'1 day left'**
  String get homeDealOneDayLeft;

  /// Deal card: several days left; {days} is a number
  ///
  /// In en, this message translates to:
  /// **'{days} days left'**
  String homeDealDaysLeft(String days);

  /// Exclusive deals section: small label
  ///
  /// In en, this message translates to:
  /// **'Made for OffrO members'**
  String get homeExclusiveEyebrow;

  /// Exclusive deals section title
  ///
  /// In en, this message translates to:
  /// **'Exclusive deals'**
  String get homeExclusiveTitle;

  /// Section action: View all
  ///
  /// In en, this message translates to:
  /// **'View all'**
  String get homeViewAll;

  /// Deal card badge when there is no percentage
  ///
  /// In en, this message translates to:
  /// **'Offer'**
  String get homeDealOffer;

  /// Discount badge; {percent} is a number
  ///
  /// In en, this message translates to:
  /// **'{percent}% off'**
  String homePercentOff(String percent);

  /// Home rewards card: small badge
  ///
  /// In en, this message translates to:
  /// **'OFFRO REWARDS'**
  String get homeRewardsBadge;

  /// Home rewards card: word after the points number
  ///
  /// In en, this message translates to:
  /// **'points'**
  String get homePointsSuffix;

  /// Home rewards card: hint when the user has points
  ///
  /// In en, this message translates to:
  /// **'Tap to view and redeem your rewards'**
  String get homeRewardsTapToView;

  /// Home rewards card: hint when the user has no points
  ///
  /// In en, this message translates to:
  /// **'Visit stores to start earning points'**
  String get homeRewardsEarnHint;

  /// Categories section: small label
  ///
  /// In en, this message translates to:
  /// **'Find what you need'**
  String get homeCategoriesEyebrow;

  /// Categories section title
  ///
  /// In en, this message translates to:
  /// **'Explore categories'**
  String get homeCategoriesTitle;

  /// Section action: See All
  ///
  /// In en, this message translates to:
  /// **'See All'**
  String get homeSeeAll;

  /// Section action: See all (stores)
  ///
  /// In en, this message translates to:
  /// **'See all'**
  String get homeSeeAllLower;

  /// Category name shown to the user: Bakery
  ///
  /// In en, this message translates to:
  /// **'Bakery'**
  String get catBakery;

  /// Category name shown to the user: Automobile
  ///
  /// In en, this message translates to:
  /// **'Automobile'**
  String get catAutomobile;

  /// Category name shown to the user: Restaurant
  ///
  /// In en, this message translates to:
  /// **'Restaurant'**
  String get catRestaurant;

  /// Category name shown to the user: Grocery
  ///
  /// In en, this message translates to:
  /// **'Grocery'**
  String get catGrocery;

  /// Products section: small label
  ///
  /// In en, this message translates to:
  /// **'Across local stores'**
  String get homeProductsEyebrow;

  /// Products section title
  ///
  /// In en, this message translates to:
  /// **'Products near you'**
  String get homeProductsTitle;

  /// Products section action
  ///
  /// In en, this message translates to:
  /// **'Browse all'**
  String get homeBrowseAll;

  /// Error snackbar when a favourite could not be saved; {error} is the reason
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t save favorite: {error}'**
  String homeFavoriteSaveFailed(String error);

  /// Nearby stores section: small label
  ///
  /// In en, this message translates to:
  /// **'Around your neighbourhood'**
  String get homeNearbyEyebrow;

  /// Nearby stores section title
  ///
  /// In en, this message translates to:
  /// **'Stores near you'**
  String get homeStoresNearTitle;

  /// Title of the full nearby stores list
  ///
  /// In en, this message translates to:
  /// **'Nearby Stores'**
  String get homeNearbyStoresTitle;

  /// Store badge: new store
  ///
  /// In en, this message translates to:
  /// **'NEW'**
  String get homeBadgeNew;

  /// Store card offer line; {offer} is the offer text
  ///
  /// In en, this message translates to:
  /// **'Offer · {offer}'**
  String homeOfferInline(String offer);

  /// Store status: open
  ///
  /// In en, this message translates to:
  /// **'Open now'**
  String get homeOpenNow;

  /// Store status: closed
  ///
  /// In en, this message translates to:
  /// **'Closed'**
  String get homeClosed;

  /// Distance filter chip: any distance
  ///
  /// In en, this message translates to:
  /// **'Any distance'**
  String get homeDistanceAny;

  /// Distance filter chip; {km} is a number of kilometres
  ///
  /// In en, this message translates to:
  /// **'Under {km} km'**
  String homeDistanceUnder(String km);

  /// Empty state when no store is within the radius; {km} is a number
  ///
  /// In en, this message translates to:
  /// **'No stores within {km} km'**
  String homeNoStoresWithin(String km);

  /// Empty state hint; it names the Any distance chip
  ///
  /// In en, this message translates to:
  /// **'Try a larger radius or tap Any distance'**
  String get homeTryLargerRadius;

  /// Explore areas section title
  ///
  /// In en, this message translates to:
  /// **'Explore Areas'**
  String get homeExploreAreasTitle;

  /// Explore areas section subtitle
  ///
  /// In en, this message translates to:
  /// **'Discover great places nearby'**
  String get homeExploreAreasSubtitle;

  /// Explore areas action; the arrow points in reading direction
  ///
  /// In en, this message translates to:
  /// **'View all →'**
  String get homeViewAllArrow;

  /// Explore areas card: label under the store count
  ///
  /// In en, this message translates to:
  /// **'Store'**
  String get homeStoreWord;

  /// Name of the Rewards feature inside the 'please login to use ...' message
  ///
  /// In en, this message translates to:
  /// **'My Rewards'**
  String get homeFeatureRewards;

  /// Home error screen: button
  ///
  /// In en, this message translates to:
  /// **'Back to Home'**
  String get homeBackToHome;

  /// Home error screen: button
  ///
  /// In en, this message translates to:
  /// **'Contact Support'**
  String get homeContactSupport;

  /// Home error screen: title when offline
  ///
  /// In en, this message translates to:
  /// **'No internet connection'**
  String get homeNoInternet;

  /// Home error screen: hint when offline
  ///
  /// In en, this message translates to:
  /// **'Check your connection and try again'**
  String get homeCheckConnection;

  /// Home error screen: title on timeout
  ///
  /// In en, this message translates to:
  /// **'Server taking too long'**
  String get homeServerSlow;

  /// Home error screen: hint on timeout
  ///
  /// In en, this message translates to:
  /// **'Cold start — please wait a moment and retry'**
  String get homeColdStart;

  /// Home error screen: title when stores failed to load
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t load stores'**
  String get homeCouldntLoadStores;

  /// Home error screen: hint
  ///
  /// In en, this message translates to:
  /// **'Please try again'**
  String get homePleaseTryAgain;

  /// Home error screen: title when the page content failed to load
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t load this page'**
  String get homeCouldntLoadPage;

  /// Generic button: retry
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get commonRetry;

  /// Generic button: try again
  ///
  /// In en, this message translates to:
  /// **'Try Again'**
  String get commonTryAgain;

  /// Promo banners section title
  ///
  /// In en, this message translates to:
  /// **'Featured Banners'**
  String get homePromoTitle;

  /// Promo banners section subtitle
  ///
  /// In en, this message translates to:
  /// **'Latest offers from our stores'**
  String get homePromoSubtitle;

  /// Clock suffix before noon
  ///
  /// In en, this message translates to:
  /// **'AM'**
  String get timeAm;

  /// Clock suffix after noon
  ///
  /// In en, this message translates to:
  /// **'PM'**
  String get timePm;

  /// Store status sub-label; {time} is a clock time such as 9 PM
  ///
  /// In en, this message translates to:
  /// **'Closes {time}'**
  String storeClosesAt(String time);

  /// Store status sub-label; {time} is a clock time such as 9 AM
  ///
  /// In en, this message translates to:
  /// **'Opens {time}'**
  String storeOpensAt(String time);

  /// Store badge
  ///
  /// In en, this message translates to:
  /// **'JUST OPENED'**
  String get badgeJustOpened;

  /// Store badge
  ///
  /// In en, this message translates to:
  /// **'NEWLY ADDED'**
  String get badgeNewlyAdded;

  /// Store badge
  ///
  /// In en, this message translates to:
  /// **'NEWLY OPENED'**
  String get badgeNewlyOpened;

  /// Store badge
  ///
  /// In en, this message translates to:
  /// **'TRENDING'**
  String get badgeTrending;

  /// Store badge
  ///
  /// In en, this message translates to:
  /// **'POPULAR'**
  String get badgePopular;

  /// Store badge
  ///
  /// In en, this message translates to:
  /// **'TOP RATED'**
  String get badgeTopRated;

  /// Store badge
  ///
  /// In en, this message translates to:
  /// **'MUST VISIT'**
  String get badgeMustVisit;

  /// Store badge
  ///
  /// In en, this message translates to:
  /// **'LIMITED OFFER'**
  String get badgeLimitedOffer;

  /// Guest prompt: title
  ///
  /// In en, this message translates to:
  /// **'Login Required'**
  String get homeLoginRequiredTitle;

  /// Guest prompt: body; {feature} is the name of the feature, e.g. My Rewards
  ///
  /// In en, this message translates to:
  /// **'Please login or register to use {feature}.'**
  String homeLoginRequiredBody(String feature);

  /// Guest prompt: primary button
  ///
  /// In en, this message translates to:
  /// **'Login / Register'**
  String get homeLoginRegister;

  /// Guest prompt: dismiss button
  ///
  /// In en, this message translates to:
  /// **'Maybe later'**
  String get homeMaybeLater;

  /// Snackbar when a refresh failed because the device is offline
  ///
  /// In en, this message translates to:
  /// **'Unable to connect. Please check your internet connection and try again.'**
  String get homeUnableToConnect;

  /// Snackbar when the stores could not be refreshed
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t refresh stores. Please try again.'**
  String get homeRefreshFailed;

  /// Profile menu item
  ///
  /// In en, this message translates to:
  /// **'My Favourites'**
  String get profileFavourites;

  /// Profile menu note
  ///
  /// In en, this message translates to:
  /// **'Stores you saved'**
  String get profileFavouritesNote;

  /// Profile menu note
  ///
  /// In en, this message translates to:
  /// **'Reward points and vouchers'**
  String get profileRewardsNote;

  /// Profile menu item and screen title
  ///
  /// In en, this message translates to:
  /// **'Scan History'**
  String get profileScanHistory;

  /// Profile menu note
  ///
  /// In en, this message translates to:
  /// **'Points earned at stores'**
  String get profileScanHistoryNote;

  /// Profile menu item and screen title
  ///
  /// In en, this message translates to:
  /// **'Notifications'**
  String get profileNotifications;

  /// Profile menu note
  ///
  /// In en, this message translates to:
  /// **'Offers, rewards and account updates'**
  String get profileNotificationsNote;

  /// Profile menu item
  ///
  /// In en, this message translates to:
  /// **'Switch Mode'**
  String get profileSwitchMode;

  /// Profile menu note
  ///
  /// In en, this message translates to:
  /// **'Switch between User & Merchant'**
  String get profileSwitchModeNote;

  /// Profile menu item
  ///
  /// In en, this message translates to:
  /// **'Contact Offro'**
  String get profileContact;

  /// Profile menu note
  ///
  /// In en, this message translates to:
  /// **'Chat with us on WhatsApp'**
  String get profileContactNote;

  /// Profile menu item and dialog title
  ///
  /// In en, this message translates to:
  /// **'About Us'**
  String get profileAboutUs;

  /// About dialog text shown when the admin has not set one
  ///
  /// In en, this message translates to:
  /// **'Offro connects local stores with customers through deals and loyalty points.'**
  String get profileAboutFallback;

  /// Profile menu item and dialog title
  ///
  /// In en, this message translates to:
  /// **'Terms & Conditions'**
  String get profileTerms;

  /// Profile menu item
  ///
  /// In en, this message translates to:
  /// **'Privacy Policy'**
  String get profilePrivacy;

  /// Profile menu note
  ///
  /// In en, this message translates to:
  /// **'Includes delete account'**
  String get profilePrivacyNote;

  /// Profile menu item and dialog title
  ///
  /// In en, this message translates to:
  /// **'Refund Policy'**
  String get profileRefund;

  /// Profile menu item
  ///
  /// In en, this message translates to:
  /// **'Logout'**
  String get profileLogout;

  /// Generic button
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get commonCancel;

  /// Generic button
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get commonClose;

  /// Filter chip: everything
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get commonAll;

  /// Dialog title
  ///
  /// In en, this message translates to:
  /// **'Clear All Notifications?'**
  String get notifClearTitle;

  /// Dialog text
  ///
  /// In en, this message translates to:
  /// **'This will permanently remove all your notifications.'**
  String get notifClearBody;

  /// Button
  ///
  /// In en, this message translates to:
  /// **'Clear All'**
  String get notifClearAll;

  /// Empty state title
  ///
  /// In en, this message translates to:
  /// **'No notifications yet'**
  String get notifEmptyTitle;

  /// Empty state text
  ///
  /// In en, this message translates to:
  /// **'You\'ll see deals and alerts here'**
  String get notifEmptyBody;

  /// Relative time
  ///
  /// In en, this message translates to:
  /// **'just now'**
  String get timeAgoJustNow;

  /// Relative time; {n} is a number of minutes
  ///
  /// In en, this message translates to:
  /// **'{n}m ago'**
  String timeAgoMinutes(String n);

  /// Relative time; {n} is a number of hours
  ///
  /// In en, this message translates to:
  /// **'{n}h ago'**
  String timeAgoHours(String n);

  /// Relative time; {n} is a number of days
  ///
  /// In en, this message translates to:
  /// **'{n}d ago'**
  String timeAgoDays(String n);

  /// Relative time; {n} is a number of weeks
  ///
  /// In en, this message translates to:
  /// **'{n}w ago'**
  String timeAgoWeeks(String n);

  /// Search field hint; {city} is the city name
  ///
  /// In en, this message translates to:
  /// **'Search stores in {city}...'**
  String searchStoresIn(String city);

  /// Empty state; {q} is what the user typed
  ///
  /// In en, this message translates to:
  /// **'No results for \'{q}\''**
  String searchNoResults(String q);

  /// Empty state; {q} is what the user typed
  ///
  /// In en, this message translates to:
  /// **'No results for "{q}"'**
  String searchNoResultsDq(String q);

  /// Empty state
  ///
  /// In en, this message translates to:
  /// **'No stores yet'**
  String get searchNoStores;

  /// Search field hint
  ///
  /// In en, this message translates to:
  /// **'Search store, area, offer...'**
  String get searchStoreAreaOffer;

  /// Search field hint; {category} is a category name
  ///
  /// In en, this message translates to:
  /// **'Search {category} stores...'**
  String catSearchStores(String category);

  /// Empty state; {category} is a category name
  ///
  /// In en, this message translates to:
  /// **'No {category} stores found'**
  String catNoStoresFound(String category);

  /// Empty state detail; {count} is a number, {category} a category name
  ///
  /// In en, this message translates to:
  /// **'Found {count} store(s) in this city, but none matched "{category}".'**
  String catFoundButNone(String count, String category);

  /// Empty state detail; {list} is a comma separated list
  ///
  /// In en, this message translates to:
  /// **'Categories found: {list}'**
  String catCategoriesFound(String list);

  /// Screen title
  ///
  /// In en, this message translates to:
  /// **'Categories'**
  String get catCategoriesTitle;

  /// Search field hint
  ///
  /// In en, this message translates to:
  /// **'Search categories...'**
  String get catSearchCategories;

  /// Empty state
  ///
  /// In en, this message translates to:
  /// **'No categories found'**
  String get catNoCategories;

  /// Screen title
  ///
  /// In en, this message translates to:
  /// **'All categories'**
  String get catAllCategories;

  /// Filter chip
  ///
  /// In en, this message translates to:
  /// **'Ending soon'**
  String get dealsEndingSoon;

  /// Deal status
  ///
  /// In en, this message translates to:
  /// **'Expired'**
  String get dealExpired;

  /// Deal status
  ///
  /// In en, this message translates to:
  /// **'Ends in 1 day'**
  String get dealEndsInOneDay;

  /// Deal status; {days} is a number
  ///
  /// In en, this message translates to:
  /// **'Ends in {days} days'**
  String dealEndsInDays(String days);

  /// Deal card badge when the deal has no category
  ///
  /// In en, this message translates to:
  /// **'LOCAL DEAL'**
  String get dealLocalBadge;

  /// Deal card footer
  ///
  /// In en, this message translates to:
  /// **'AVAILABLE IN STORE'**
  String get dealAvailableInStore;

  /// Screen header: small label
  ///
  /// In en, this message translates to:
  /// **'Fresh around you'**
  String get dealsEyebrow;

  /// Screen header title
  ///
  /// In en, this message translates to:
  /// **'Local deals'**
  String get dealsTitle;

  /// Screen header subtitle; {city} is the city
  ///
  /// In en, this message translates to:
  /// **'Member-only prices and limited offers from verified businesses in {city}.'**
  String dealsSubtitleCity(String city);

  /// Screen header subtitle
  ///
  /// In en, this message translates to:
  /// **'Member-only prices and limited offers from verified businesses nearby.'**
  String get dealsSubtitleNearby;

  /// Search field hint
  ///
  /// In en, this message translates to:
  /// **'Search deals, stores or areas'**
  String get dealsSearch;

  /// Count banner label
  ///
  /// In en, this message translates to:
  /// **'THIS WEEK'**
  String get dealsThisWeek;

  /// Empty state
  ///
  /// In en, this message translates to:
  /// **'No active deals right now'**
  String get dealsNoneActive;

  /// Empty state when a search has no match
  ///
  /// In en, this message translates to:
  /// **'No deals match your search'**
  String get dealsNoMatch;

  /// Screen title
  ///
  /// In en, this message translates to:
  /// **'All Areas'**
  String get areasTitle;

  /// Search field hint
  ///
  /// In en, this message translates to:
  /// **'Search areas...'**
  String get areasSearch;

  /// Empty state
  ///
  /// In en, this message translates to:
  /// **'No areas available'**
  String get areasNone;

  /// Search field hint; {area} is the area name
  ///
  /// In en, this message translates to:
  /// **'Search in {area}...'**
  String areaSearchIn(String area);

  /// Count line, exactly one store; {area} is the area name
  ///
  /// In en, this message translates to:
  /// **'1 store in {area}'**
  String areaStoresOne(String area);

  /// Count line; {count} is a number, {area} the area name
  ///
  /// In en, this message translates to:
  /// **'{count} stores in {area}'**
  String areaStoresMany(String count, String area);

  /// Empty state
  ///
  /// In en, this message translates to:
  /// **'No stores found'**
  String get areaNoStores;

  /// Last card of a store carousel (two lines)
  ///
  /// In en, this message translates to:
  /// **'See All\nStores'**
  String get storeSeeAllStores;

  /// Distance unit: metres
  ///
  /// In en, this message translates to:
  /// **'m'**
  String get unitMeter;

  /// Distance unit: kilometres
  ///
  /// In en, this message translates to:
  /// **'km'**
  String get unitKm;

  /// Store card: points earned per visit; {points} is a number
  ///
  /// In en, this message translates to:
  /// **'{points} pts on visit'**
  String ptsOnVisit(String points);

  /// Store card status pill
  ///
  /// In en, this message translates to:
  /// **'Open Now'**
  String get storeOpenNowCaps;

  /// Store badge
  ///
  /// In en, this message translates to:
  /// **'NEW STORE'**
  String get badgeNewStore;

  /// Discount badge; {amount} is the amount such as 20%
  ///
  /// In en, this message translates to:
  /// **'{amount} off'**
  String offSuffix(String amount);

  /// Name shown when a product has no title
  ///
  /// In en, this message translates to:
  /// **'Product'**
  String get prodTitleFallback;

  /// Product page: small label above the store name
  ///
  /// In en, this message translates to:
  /// **'Listed by'**
  String get prodListedBy;

  /// Product page: link to the store
  ///
  /// In en, this message translates to:
  /// **'View store'**
  String get prodViewStore;

  /// Product page: notice
  ///
  /// In en, this message translates to:
  /// **'Store Currently Inactive'**
  String get prodStoreInactive;

  /// Product page: section title
  ///
  /// In en, this message translates to:
  /// **'Product details'**
  String get prodDetails;

  /// Product page: section title
  ///
  /// In en, this message translates to:
  /// **'Rate & Review'**
  String get prodRateReview;

  /// Rating prompt
  ///
  /// In en, this message translates to:
  /// **'Tap to rate'**
  String get prodTapToRate;

  /// Star rating word
  ///
  /// In en, this message translates to:
  /// **'Poor'**
  String get ratingPoor;

  /// Star rating word
  ///
  /// In en, this message translates to:
  /// **'Fair'**
  String get ratingFair;

  /// Star rating word
  ///
  /// In en, this message translates to:
  /// **'Good'**
  String get ratingGood;

  /// Star rating word
  ///
  /// In en, this message translates to:
  /// **'Great'**
  String get ratingGreat;

  /// Star rating word
  ///
  /// In en, this message translates to:
  /// **'Excellent'**
  String get ratingExcellent;

  /// Review field hint
  ///
  /// In en, this message translates to:
  /// **'Share your experience with this product...'**
  String get prodShareExperience;

  /// Button
  ///
  /// In en, this message translates to:
  /// **'Submit Review'**
  String get prodSubmitReview;

  /// Message after a review was sent
  ///
  /// In en, this message translates to:
  /// **'Thanks for your review!'**
  String get prodThanksReview;

  /// Snackbar
  ///
  /// In en, this message translates to:
  /// **'Please log in to submit a review.'**
  String get reviewLoginRequired;

  /// Snackbar
  ///
  /// In en, this message translates to:
  /// **'Review submitted! Thank you.'**
  String get reviewSubmitted;

  /// Snackbar
  ///
  /// In en, this message translates to:
  /// **'Your session has expired. Please log in again to submit a review.'**
  String get reviewSessionExpired;

  /// Screen title
  ///
  /// In en, this message translates to:
  /// **'All products'**
  String get prodAllProducts;

  /// Empty state
  ///
  /// In en, this message translates to:
  /// **'No products found'**
  String get prodNoProducts;

  /// Search field hint
  ///
  /// In en, this message translates to:
  /// **'Search products...'**
  String get prodSearch;

  /// Product card line; {name} is the store name
  ///
  /// In en, this message translates to:
  /// **'Seller: {name}'**
  String prodSeller(String name);

  /// Product card badge
  ///
  /// In en, this message translates to:
  /// **'BEST SELLER'**
  String get prodBestSeller;

  /// Month name used in short dates
  ///
  /// In en, this message translates to:
  /// **'Jan'**
  String get monthJan;

  /// Month name used in short dates
  ///
  /// In en, this message translates to:
  /// **'Feb'**
  String get monthFeb;

  /// Month name used in short dates
  ///
  /// In en, this message translates to:
  /// **'Mar'**
  String get monthMar;

  /// Month name used in short dates
  ///
  /// In en, this message translates to:
  /// **'Apr'**
  String get monthApr;

  /// Month name used in short dates
  ///
  /// In en, this message translates to:
  /// **'May'**
  String get monthMay;

  /// Month name used in short dates
  ///
  /// In en, this message translates to:
  /// **'Jun'**
  String get monthJun;

  /// Month name used in short dates
  ///
  /// In en, this message translates to:
  /// **'Jul'**
  String get monthJul;

  /// Month name used in short dates
  ///
  /// In en, this message translates to:
  /// **'Aug'**
  String get monthAug;

  /// Month name used in short dates
  ///
  /// In en, this message translates to:
  /// **'Sep'**
  String get monthSep;

  /// Month name used in short dates
  ///
  /// In en, this message translates to:
  /// **'Oct'**
  String get monthOct;

  /// Month name used in short dates
  ///
  /// In en, this message translates to:
  /// **'Nov'**
  String get monthNov;

  /// Month name used in short dates
  ///
  /// In en, this message translates to:
  /// **'Dec'**
  String get monthDec;

  /// Generic error message
  ///
  /// In en, this message translates to:
  /// **'Something went wrong. Please try again.'**
  String get errGeneric;

  /// Error: no connection
  ///
  /// In en, this message translates to:
  /// **'We couldn\'t connect to OffrO right now. Please check your internet connection and try again.'**
  String get errConnect;

  /// Error: timeout
  ///
  /// In en, this message translates to:
  /// **'OffrO is taking too long to respond. Please try again in a moment.'**
  String get errTimeout;

  /// Error: server problem
  ///
  /// In en, this message translates to:
  /// **'OffrO is temporarily unavailable. Please try again in a moment.'**
  String get errUnavailable;

  /// Error: login expired
  ///
  /// In en, this message translates to:
  /// **'Your session has expired. Please log in again.'**
  String get errSession;

  /// Error text produced by the app's API layer
  ///
  /// In en, this message translates to:
  /// **'Network error. Please check your connection and try again.'**
  String get errApiNetwork;

  /// Error text produced by the app's API layer
  ///
  /// In en, this message translates to:
  /// **'Unexpected response from server.'**
  String get errApiUnexpected;

  /// Name shown on the identity card for a guest
  ///
  /// In en, this message translates to:
  /// **'Guest'**
  String get profileGuestName;

  /// Note below the identity card
  ///
  /// In en, this message translates to:
  /// **'Need to update your profile? Contact support, we will help you right away.'**
  String get profileSupportNote;

  /// Screen header eyebrow
  ///
  /// In en, this message translates to:
  /// **'Saved for later'**
  String get favEyebrow;

  /// Header description, exactly one favourite
  ///
  /// In en, this message translates to:
  /// **'1 place you love, all in one spot.'**
  String get favPlacesOne;

  /// Header description; {count} is a number
  ///
  /// In en, this message translates to:
  /// **'{count} places you love, all in one spot.'**
  String favPlacesMany(String count);

  /// Empty state title
  ///
  /// In en, this message translates to:
  /// **'No favourites yet'**
  String get favEmptyTitle;

  /// Empty state body
  ///
  /// In en, this message translates to:
  /// **'Tap the heart on any store to save it here'**
  String get favEmptyBody;

  /// Scanner screen title
  ///
  /// In en, this message translates to:
  /// **'Scan Store QR'**
  String get qrTitle;

  /// Snackbar when the scanned code is not a store code
  ///
  /// In en, this message translates to:
  /// **'❌ Invalid QR'**
  String get qrInvalid;

  /// Dialog title after a successful scan
  ///
  /// In en, this message translates to:
  /// **'Points Added!'**
  String get qrPointsAdded;

  /// Fallback message when the server sends none
  ///
  /// In en, this message translates to:
  /// **'Done!'**
  String get qrDone;

  /// Dialog note below the server message
  ///
  /// In en, this message translates to:
  /// **'🔐 Store QR has been refreshed for security.'**
  String get qrRefreshedNote;

  /// Dialog button
  ///
  /// In en, this message translates to:
  /// **'Great!'**
  String get qrGreat;

  /// Scanner hint
  ///
  /// In en, this message translates to:
  /// **'Point at store QR code'**
  String get qrPointAt;

  /// Fallback when the city is unknown
  ///
  /// In en, this message translates to:
  /// **'your city'**
  String get exploreYourCity;

  /// Eyebrow; {city} is the city name
  ///
  /// In en, this message translates to:
  /// **'Discover {city}'**
  String exploreDiscover(String city);

  /// Screen title
  ///
  /// In en, this message translates to:
  /// **'Explore nearby'**
  String get exploreTitle;

  /// Screen description
  ///
  /// In en, this message translates to:
  /// **'Find independent businesses, useful services and local favourites around you.'**
  String get exploreDesc;

  /// Search field hint
  ///
  /// In en, this message translates to:
  /// **'Search stores, categories or areas'**
  String get exploreSearchHint;

  /// Small note below the search field
  ///
  /// In en, this message translates to:
  /// **'Searches business names, store categories and neighbourhoods.'**
  String get exploreSearchNote;

  /// Section eyebrow
  ///
  /// In en, this message translates to:
  /// **'Explore by area'**
  String get exploreByArea;

  /// Section title; {city} is the city name
  ///
  /// In en, this message translates to:
  /// **'Neighbourhoods in {city}'**
  String exploreNeighbourhoodsIn(String city);

  /// Results eyebrow
  ///
  /// In en, this message translates to:
  /// **'Around you'**
  String get exploreAroundYou;

  /// Results eyebrow when an area is selected
  ///
  /// In en, this message translates to:
  /// **'Neighbourhood'**
  String get exploreNeighbourhood;

  /// Results title, exactly one place
  ///
  /// In en, this message translates to:
  /// **'1 place nearby'**
  String get explorePlacesOne;

  /// Results title; {count} is a number
  ///
  /// In en, this message translates to:
  /// **'{count} places nearby'**
  String explorePlacesMany(String count);

  /// Results title when an area is selected; {area} is the area name
  ///
  /// In en, this message translates to:
  /// **'Stores in {area}'**
  String exploreStoresInArea(String area);

  /// Empty state title
  ///
  /// In en, this message translates to:
  /// **'No matching stores yet'**
  String get exploreNoMatchTitle;

  /// Empty state body
  ///
  /// In en, this message translates to:
  /// **'Try another business name, category or neighbourhood.'**
  String get exploreNoMatchBody;

  /// Store card offer line; {offer} is the offer text
  ///
  /// In en, this message translates to:
  /// **'Offer · {offer}'**
  String exploreOffer(String offer);

  /// Area card count, exactly one
  ///
  /// In en, this message translates to:
  /// **'1 store'**
  String get exploreStoreOne;

  /// Area card count; {count} is a number
  ///
  /// In en, this message translates to:
  /// **'{count} stores'**
  String exploreStoreMany(String count);

  /// Snackbar fallback after redeeming when the server sends no message
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get walletDone;

  /// Balance card badge
  ///
  /// In en, this message translates to:
  /// **'REWARD POINTS'**
  String get walletBadge;

  /// Balance card label
  ///
  /// In en, this message translates to:
  /// **'Available balance'**
  String get walletBalance;

  /// Word shown after the balance number
  ///
  /// In en, this message translates to:
  /// **'points'**
  String get walletPointsWord;

  /// Button
  ///
  /// In en, this message translates to:
  /// **'Redeem'**
  String get walletRedeem;

  /// Balance card footnote; {points} is a number
  ///
  /// In en, this message translates to:
  /// **'{points} pts = ₹20 voucher'**
  String walletVoucherRate(String points);

  /// Balance card status
  ///
  /// In en, this message translates to:
  /// **'Ready to redeem'**
  String get walletReadyToRedeem;

  /// Balance card status; {points} is a number
  ///
  /// In en, this message translates to:
  /// **'{points} pts to go'**
  String walletToGo(String points);

  /// Voucher card cost; {points} is a number
  ///
  /// In en, this message translates to:
  /// **'{points} pts'**
  String walletPtsOnly(String points);

  /// Voucher card description
  ///
  /// In en, this message translates to:
  /// **'Promotional gift voucher · Amazon or Flipkart'**
  String get walletVoucherDesc;

  /// Disabled redeem button; {points} is a number
  ///
  /// In en, this message translates to:
  /// **'Earn {points} more points'**
  String walletEarnMore(String points);

  /// Card title
  ///
  /// In en, this message translates to:
  /// **'How rewards work'**
  String get walletHowTitle;

  /// Rewards rule
  ///
  /// In en, this message translates to:
  /// **'Redeem 200 Reward Points for a ₹20 Promotional Gift Voucher.'**
  String get walletHowLine1;

  /// Rewards rule
  ///
  /// In en, this message translates to:
  /// **'Gift voucher delivery: 3-5 business days.'**
  String get walletHowLine2;

  /// Rewards rule
  ///
  /// In en, this message translates to:
  /// **'Reward points never expire.'**
  String get walletHowLine3;

  /// Rewards disclaimer
  ///
  /// In en, this message translates to:
  /// **'Reward points are promotional loyalty points. They cannot be purchased, transferred, or exchanged for cash.'**
  String get walletHowDisclaimer;

  /// Section title
  ///
  /// In en, this message translates to:
  /// **'Recent activity'**
  String get walletRecent;

  /// Empty state
  ///
  /// In en, this message translates to:
  /// **'No scans yet — points you earn at stores will show up here.'**
  String get walletNoScansHint;

  /// Activity row; {date} is a formatted date
  ///
  /// In en, this message translates to:
  /// **'Earned · {date}'**
  String walletEarnedOn(String date);

  /// Screen eyebrow
  ///
  /// In en, this message translates to:
  /// **'Your local loyalty'**
  String get walletEyebrow;

  /// Screen title
  ///
  /// In en, this message translates to:
  /// **'Rewards'**
  String get walletTitle;

  /// Screen description
  ///
  /// In en, this message translates to:
  /// **'Every local purchase gets you closer to something good.'**
  String get walletDesc;

  /// Section eyebrow
  ///
  /// In en, this message translates to:
  /// **'Ready to use'**
  String get walletVouchersEyebrow;

  /// Section title
  ///
  /// In en, this message translates to:
  /// **'Your vouchers'**
  String get walletVouchersTitle;

  /// Section action
  ///
  /// In en, this message translates to:
  /// **'View history'**
  String get walletViewHistory;

  /// Scan history screen title
  ///
  /// In en, this message translates to:
  /// **'Scan History'**
  String get scanHistoryTitle;

  /// Scan history empty state
  ///
  /// In en, this message translates to:
  /// **'No scans yet'**
  String get scanHistoryEmpty;

  /// Scan history points chip; {points} is a number
  ///
  /// In en, this message translates to:
  /// **'+{points} pts'**
  String walletPtsPlus(String points);

  /// Store page tab
  ///
  /// In en, this message translates to:
  /// **'About'**
  String get storeTabAbout;

  /// Store page tab
  ///
  /// In en, this message translates to:
  /// **'Products'**
  String get storeTabProducts;

  /// Store page tab
  ///
  /// In en, this message translates to:
  /// **'Reviews'**
  String get storeTabReviews;

  /// Store page tab
  ///
  /// In en, this message translates to:
  /// **'Rewards'**
  String get storeTabRewards;

  /// Bottom bar button; {points} is a number
  ///
  /// In en, this message translates to:
  /// **'Scan & Earn {points} pts'**
  String storeScanEarn(String points);

  /// Scan card title
  ///
  /// In en, this message translates to:
  /// **'Scan the store QR'**
  String get storeScanCardTitle;

  /// Scan card body; {points} is a number
  ///
  /// In en, this message translates to:
  /// **'Verify your visit/purchase and earn {points} reward points.'**
  String storeScanCardBody(String points);

  /// Scan card button
  ///
  /// In en, this message translates to:
  /// **'Scan QR'**
  String get storeScanQr;

  /// Rewards tab empty state
  ///
  /// In en, this message translates to:
  /// **'Rewards coming soon'**
  String get storeRewardsSoon;

  /// Rewards card title
  ///
  /// In en, this message translates to:
  /// **'Earn Reward Points'**
  String get storeEarnPointsTitle;

  /// Rewards card body; {points} is a number
  ///
  /// In en, this message translates to:
  /// **'Scan QR after purchase to earn {points} pts'**
  String storeEarnPointsBody(String points);

  /// Rewards card; {points} is a number
  ///
  /// In en, this message translates to:
  /// **'Your Points: {points}'**
  String storeYourPoints(String points);

  /// About section toggle
  ///
  /// In en, this message translates to:
  /// **'Show less'**
  String get storeShowLess;

  /// About section toggle
  ///
  /// In en, this message translates to:
  /// **'Read more →'**
  String get storeReadMore;

  /// Opening-hours status
  ///
  /// In en, this message translates to:
  /// **'Open'**
  String get storeOpenWord;

  /// Opening-hours status
  ///
  /// In en, this message translates to:
  /// **'Closed'**
  String get storeClosedWord;

  /// About row; {amount} is a number
  ///
  /// In en, this message translates to:
  /// **'₹{amount} for two'**
  String storeCostForTwo(String amount);

  /// About row
  ///
  /// In en, this message translates to:
  /// **'Dine-in available'**
  String get storeDineIn;

  /// Highlight chip
  ///
  /// In en, this message translates to:
  /// **'Trending'**
  String get storeChipTrending;

  /// Highlight chip
  ///
  /// In en, this message translates to:
  /// **'Just Opened'**
  String get storeChipJustOpened;

  /// Highlight chip
  ///
  /// In en, this message translates to:
  /// **'Popular'**
  String get storeChipPopular;

  /// Offer pill on the store photo; {pct} is a number
  ///
  /// In en, this message translates to:
  /// **'Offer · {pct}% off'**
  String storeOfferPct(String pct);

  /// Action button
  ///
  /// In en, this message translates to:
  /// **'Call'**
  String get storeCall;

  /// Action button
  ///
  /// In en, this message translates to:
  /// **'WhatsApp'**
  String get storeWhatsApp;

  /// Action button
  ///
  /// In en, this message translates to:
  /// **'Directions'**
  String get storeDirections;

  /// Offers eyebrow, exactly one deal
  ///
  /// In en, this message translates to:
  /// **'Exclusive on OffrO · 1 deal'**
  String get storeExclusiveOne;

  /// Offers eyebrow; {count} is a number
  ///
  /// In en, this message translates to:
  /// **'Exclusive on OffrO · {count} deals'**
  String storeExclusiveMany(String count);

  /// Offers eyebrow
  ///
  /// In en, this message translates to:
  /// **'Exclusive on OffrO'**
  String get storeExclusive;

  /// Offers section title
  ///
  /// In en, this message translates to:
  /// **'Deals from this store'**
  String get storeDealsFromStore;

  /// Offers empty state
  ///
  /// In en, this message translates to:
  /// **'Offers coming soon'**
  String get storeOffersSoon;

  /// Deal chip; {pct} is a number
  ///
  /// In en, this message translates to:
  /// **'{pct}% OFF'**
  String storeDiscOff(String pct);

  /// Deal card big discount label
  ///
  /// In en, this message translates to:
  /// **'OFF'**
  String get storeOffWord;

  /// Products tab eyebrow
  ///
  /// In en, this message translates to:
  /// **'PRODUCTS AVAILABLE AT THIS STORE'**
  String get prodsAvailableEyebrow;

  /// Products tab title
  ///
  /// In en, this message translates to:
  /// **'Featured Products'**
  String get prodsFeatured;

  /// Snackbar tip
  ///
  /// In en, this message translates to:
  /// **'Tip: Long-press a product image to view details and leave a review.'**
  String get prodsTip;

  /// Snackbar; {error} is the error text
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t submit rating: {error}'**
  String prodRatingSubmitFailed(String error);

  /// Product sheet; {date} is the validity date text
  ///
  /// In en, this message translates to:
  /// **'Valid till {date}'**
  String prodValidTill(String date);

  /// Product sheet heading after rating
  ///
  /// In en, this message translates to:
  /// **'Your Rating'**
  String get prodYourRating;

  /// Product sheet heading
  ///
  /// In en, this message translates to:
  /// **'Rate this Product'**
  String get prodRateThis;

  /// Product sheet field hint
  ///
  /// In en, this message translates to:
  /// **'Write a short review (optional)'**
  String get prodReviewHint;

  /// Product sheet button
  ///
  /// In en, this message translates to:
  /// **'Submit Rating'**
  String get prodSubmitRating;

  /// Product sheet message
  ///
  /// In en, this message translates to:
  /// **'Thanks for your rating! ⭐'**
  String get prodThanksRating;

  /// Dialog button
  ///
  /// In en, this message translates to:
  /// **'Got it'**
  String get prodGotIt;

  /// Validation message
  ///
  /// In en, this message translates to:
  /// **'Store not found. Cannot submit review.'**
  String get revStoreNotFound;

  /// Validation message
  ///
  /// In en, this message translates to:
  /// **'Please select a star rating'**
  String get revSelectStar;

  /// Validation message
  ///
  /// In en, this message translates to:
  /// **'Write at least 5 characters'**
  String get revMin5;

  /// Snackbar
  ///
  /// In en, this message translates to:
  /// **'⭐ Review submitted! Thank you.'**
  String get revSubmittedStar;

  /// Message
  ///
  /// In en, this message translates to:
  /// **'Store information unavailable.'**
  String get revUnavailable;

  /// Section eyebrow
  ///
  /// In en, this message translates to:
  /// **'WHAT CUSTOMERS ARE SAYING'**
  String get revEyebrow;

  /// Section title
  ///
  /// In en, this message translates to:
  /// **'Reviews'**
  String get revTitle;

  /// Count, exactly one
  ///
  /// In en, this message translates to:
  /// **'(1 review)'**
  String get revCountOne;

  /// Count; {count} is a number
  ///
  /// In en, this message translates to:
  /// **'({count} reviews)'**
  String revCountMany(String count);

  /// Empty state title
  ///
  /// In en, this message translates to:
  /// **'No reviews yet'**
  String get revNoneTitle;

  /// Card title
  ///
  /// In en, this message translates to:
  /// **'Your Review'**
  String get revYourReview;

  /// Button
  ///
  /// In en, this message translates to:
  /// **'Edit'**
  String get revEdit;

  /// Field hint
  ///
  /// In en, this message translates to:
  /// **'Write a review…'**
  String get revWrite;

  /// Field hint
  ///
  /// In en, this message translates to:
  /// **'Share your experience…'**
  String get revShareExp;

  /// Button
  ///
  /// In en, this message translates to:
  /// **'Submit'**
  String get revSubmit;

  /// Empty state
  ///
  /// In en, this message translates to:
  /// **'No reviews yet.'**
  String get revNoneDot;

  /// Empty state
  ///
  /// In en, this message translates to:
  /// **'Be the first to review.'**
  String get revBeFirst;

  /// Link
  ///
  /// In en, this message translates to:
  /// **'View all reviews →'**
  String get revViewAll;

  /// Sheet title
  ///
  /// In en, this message translates to:
  /// **'All Reviews'**
  String get revAllTitle;

  /// Name shown when the reviewer has none
  ///
  /// In en, this message translates to:
  /// **'Anonymous'**
  String get revAnonymous;

  /// Small deal badge on a store card when there is no percentage
  ///
  /// In en, this message translates to:
  /// **'Deal'**
  String get storeDealWord;

  /// Store card badge
  ///
  /// In en, this message translates to:
  /// **'New Store'**
  String get storeNewStoreTitle;

  /// Store card distance; {n} is a number of metres
  ///
  /// In en, this message translates to:
  /// **'{n}m away'**
  String storeDistAwayM(String n);

  /// Store card distance; {n} is a number of kilometres
  ///
  /// In en, this message translates to:
  /// **'{n}km away'**
  String storeDistAwayKm(String n);

  /// Error text under the location card
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t get a precise GPS fix. Move to an open area or check your signal.'**
  String get locGpsFailed;

  /// Error text under the location card
  ///
  /// In en, this message translates to:
  /// **'Got your position but couldn\'t identify the city.'**
  String get locCityUnknown;

  /// Dialog message
  ///
  /// In en, this message translates to:
  /// **'Your device\'s location services are turned off. Please turn them on in settings.'**
  String get locServicesOff;

  /// Dialog message
  ///
  /// In en, this message translates to:
  /// **'Location permission is turned off for OffrO. Please allow it in app settings.'**
  String get locPermissionOff;

  /// Note under the location card
  ///
  /// In en, this message translates to:
  /// **'Location permission wasn\'t allowed. Tap the card to try again, or choose a city below.'**
  String get locPermissionDenied;

  /// Dialog title
  ///
  /// In en, this message translates to:
  /// **'Location not detected'**
  String get locNotDetected;

  /// Dialog button
  ///
  /// In en, this message translates to:
  /// **'Go to settings'**
  String get locGoToSettings;

  /// Dialog title
  ///
  /// In en, this message translates to:
  /// **'City not supported yet'**
  String get locCityUnsupportedTitle;

  /// Dialog body; {city} is a city name
  ///
  /// In en, this message translates to:
  /// **'OffrO isn\'t available in {city} yet. Please choose another city from the list.'**
  String locCityUnsupportedBody(String city);

  /// Dialog button
  ///
  /// In en, this message translates to:
  /// **'OK'**
  String get commonOk;

  /// Screen title
  ///
  /// In en, this message translates to:
  /// **'Location'**
  String get locTitle;

  /// Search field hint
  ///
  /// In en, this message translates to:
  /// **'Search city, area or locality'**
  String get locSearchHint;

  /// Error text
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t load cities. Check your connection and try again.'**
  String get locCitiesLoadFailed;

  /// Button
  ///
  /// In en, this message translates to:
  /// **'Try again'**
  String get locTryAgain;

  /// Section title
  ///
  /// In en, this message translates to:
  /// **'Popular cities'**
  String get locPopularCities;

  /// Section title
  ///
  /// In en, this message translates to:
  /// **'All cities'**
  String get locAllCities;

  /// Search results heading
  ///
  /// In en, this message translates to:
  /// **'Cities'**
  String get locCities;

  /// Search results heading
  ///
  /// In en, this message translates to:
  /// **'Areas'**
  String get locAreas;

  /// Empty state
  ///
  /// In en, this message translates to:
  /// **'No matching places found.'**
  String get locNoMatch;

  /// Header eyebrow
  ///
  /// In en, this message translates to:
  /// **'Legal'**
  String get legalEyebrow;

  /// Screen title
  ///
  /// In en, this message translates to:
  /// **'Privacy Policy'**
  String get legalPrivacyTitle;

  /// Shown when the policy text is empty
  ///
  /// In en, this message translates to:
  /// **'Privacy policy content is being updated. Please check back later.'**
  String get legalPrivacyUpdating;

  /// Toggle
  ///
  /// In en, this message translates to:
  /// **'Read Less'**
  String get legalReadLess;

  /// Toggle
  ///
  /// In en, this message translates to:
  /// **'Read More'**
  String get legalReadMore;

  /// Section label
  ///
  /// In en, this message translates to:
  /// **'ACCOUNT'**
  String get legalAccountCaps;

  /// Row title
  ///
  /// In en, this message translates to:
  /// **'Request to delete my account'**
  String get legalDeleteRequest;

  /// Row note
  ///
  /// In en, this message translates to:
  /// **'All your data will be permanently removed'**
  String get legalDeleteRequestNote;

  /// Reason option
  ///
  /// In en, this message translates to:
  /// **'I no longer use the app'**
  String get delReasonUnused;

  /// Reason option
  ///
  /// In en, this message translates to:
  /// **'I have privacy concerns'**
  String get delReasonPrivacy;

  /// Reason option
  ///
  /// In en, this message translates to:
  /// **'I have a duplicate account'**
  String get delReasonDuplicate;

  /// Reason option
  ///
  /// In en, this message translates to:
  /// **'Too many notifications or irrelevant content'**
  String get delReasonNoisy;

  /// Reason option
  ///
  /// In en, this message translates to:
  /// **'Other'**
  String get delReasonOther;

  /// Header eyebrow
  ///
  /// In en, this message translates to:
  /// **'Account'**
  String get delEyebrow;

  /// Screen title
  ///
  /// In en, this message translates to:
  /// **'Delete Account'**
  String get delTitle;

  /// Warning banner
  ///
  /// In en, this message translates to:
  /// **'Once your account is deleted, your data cannot be retrieved. Signing up again will create a new account.'**
  String get delWarning;

  /// Label above the reasons
  ///
  /// In en, this message translates to:
  /// **'Select a reason for deleting your account'**
  String get delSelectReason;

  /// Button
  ///
  /// In en, this message translates to:
  /// **'Submit Delete Request'**
  String get delSubmit;

  /// Dialog title
  ///
  /// In en, this message translates to:
  /// **'Delete Account?'**
  String get delConfirmTitle;

  /// Dialog body
  ///
  /// In en, this message translates to:
  /// **'Your account will be marked for deletion. You will be logged out immediately and cannot log in again.\n\nOnce deleted, your data cannot be retrieved. Are you absolutely sure?'**
  String get delConfirmBody;

  /// Dialog button
  ///
  /// In en, this message translates to:
  /// **'Yes, Delete'**
  String get delConfirmYes;

  /// Dialog title
  ///
  /// In en, this message translates to:
  /// **'Deletion Requested'**
  String get delRequestedTitle;

  /// Dialog body
  ///
  /// In en, this message translates to:
  /// **'Your account deletion request has been submitted. You have been logged out.'**
  String get delRequestedBody;

  /// Snackbar; {error} is the error text
  ///
  /// In en, this message translates to:
  /// **'Failed to submit: {error}'**
  String delSubmitFailed(String error);

  /// Loading screen step
  ///
  /// In en, this message translates to:
  /// **'Locating your position...'**
  String get loadStep1;

  /// Loading screen step
  ///
  /// In en, this message translates to:
  /// **'Finding nearby deals...'**
  String get loadStep2;

  /// Loading screen step
  ///
  /// In en, this message translates to:
  /// **'Checking local stores...'**
  String get loadStep3;

  /// Loading screen step
  ///
  /// In en, this message translates to:
  /// **'Loading today\'s offers...'**
  String get loadStep4;

  /// Section title
  ///
  /// In en, this message translates to:
  /// **'Browse by Categories'**
  String get catBrowseTitle;

  /// Tile label
  ///
  /// In en, this message translates to:
  /// **'View'**
  String get catView;

  /// Category name
  ///
  /// In en, this message translates to:
  /// **'Pharmacy'**
  String get catPharmacy;

  /// Category name
  ///
  /// In en, this message translates to:
  /// **'Fashion'**
  String get catFashion;

  /// Category name
  ///
  /// In en, this message translates to:
  /// **'Beauty'**
  String get catBeauty;

  /// Category name
  ///
  /// In en, this message translates to:
  /// **'Electronics'**
  String get catElectronics;

  /// Category name
  ///
  /// In en, this message translates to:
  /// **'Education'**
  String get catEducation;

  /// Category name
  ///
  /// In en, this message translates to:
  /// **'Hospital'**
  String get catHospital;

  /// Category name
  ///
  /// In en, this message translates to:
  /// **'Cafe'**
  String get catCafe;

  /// Category name
  ///
  /// In en, this message translates to:
  /// **'Fitness'**
  String get catFitness;

  /// Category name
  ///
  /// In en, this message translates to:
  /// **'Jewelry'**
  String get catJewelry;

  /// Category subtitle
  ///
  /// In en, this message translates to:
  /// **'500+ places'**
  String get catSubRestaurant;

  /// Category subtitle
  ///
  /// In en, this message translates to:
  /// **'Health essentials'**
  String get catSubPharmacy;

  /// Category subtitle
  ///
  /// In en, this message translates to:
  /// **'New arrivals'**
  String get catSubFashion;

  /// Category subtitle
  ///
  /// In en, this message translates to:
  /// **'Skincare & more'**
  String get catSubBeauty;

  /// Category subtitle
  ///
  /// In en, this message translates to:
  /// **'Trending gadgets'**
  String get catSubElectronics;

  /// Category subtitle
  ///
  /// In en, this message translates to:
  /// **'Learn & grow'**
  String get catSubEducation;

  /// Category subtitle
  ///
  /// In en, this message translates to:
  /// **'Healthcare near you'**
  String get catSubHospital;

  /// Category subtitle
  ///
  /// In en, this message translates to:
  /// **'Coffee & more'**
  String get catSubCafe;

  /// Category subtitle
  ///
  /// In en, this message translates to:
  /// **'Fresh & daily'**
  String get catSubGrocery;

  /// Category subtitle
  ///
  /// In en, this message translates to:
  /// **'Stay strong'**
  String get catSubFitness;

  /// Category subtitle
  ///
  /// In en, this message translates to:
  /// **'Precious finds'**
  String get catSubJewelry;

  /// Category subtitle
  ///
  /// In en, this message translates to:
  /// **'Fresh baked daily'**
  String get catSubBakery;

  /// Deals header, exactly one deal
  ///
  /// In en, this message translates to:
  /// **'1 active deal for you'**
  String get dealsActiveOne;

  /// Deals header; {count} is a number
  ///
  /// In en, this message translates to:
  /// **'{count} active deals for you'**
  String dealsActiveMany(String count);

  /// Area card count, exactly one
  ///
  /// In en, this message translates to:
  /// **'1 Store'**
  String get areaCardStoreOne;

  /// Area card count; {count} is a number
  ///
  /// In en, this message translates to:
  /// **'{count} Stores'**
  String areaCardStoreMany(String count);

  /// Distance with a space; {n} is a number of metres
  ///
  /// In en, this message translates to:
  /// **'{n} m away'**
  String storeDistAwaySpM(String n);

  /// Distance with a space; {n} is a number of kilometres
  ///
  /// In en, this message translates to:
  /// **'{n} km away'**
  String storeDistAwaySpKm(String n);

  /// Fallback offer title in the product dialog
  ///
  /// In en, this message translates to:
  /// **'Special Offer'**
  String get prodSpecialOffer;

  /// Product dialog button
  ///
  /// In en, this message translates to:
  /// **'Download'**
  String get prodDownload;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['ar', 'en'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'ar':
      return AppLocalizationsAr();
    case 'en':
      return AppLocalizationsEn();
  }

  throw FlutterError(
      'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
      'an issue with the localizations generation tool. Please file an issue '
      'on GitHub with a reproducible sample app and the gen-l10n configuration '
      'that was used.');
}
