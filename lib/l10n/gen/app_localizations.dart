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
