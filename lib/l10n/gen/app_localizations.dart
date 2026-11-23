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
  /// **'No results for \"{q}\"'**
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
  /// **'Found {count} store(s) in this city, but none matched \"{category}\".'**
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

  /// Merchant/Influencer text
  ///
  /// In en, this message translates to:
  /// **'Add'**
  String get bizAdd;

  /// Merchant/Influencer text
  ///
  /// In en, this message translates to:
  /// **'No stores yet — tap to add your first'**
  String get bizNoStoresYetTapTo;

  /// Merchant/Influencer text
  ///
  /// In en, this message translates to:
  /// **'Subscribe your store to create banners.'**
  String get bizSubscribeYourStoreToCreate;

  /// Merchant/Influencer text
  ///
  /// In en, this message translates to:
  /// **'No banners yet — promote your store'**
  String get bizNoBannersYetPromoteYour;

  /// Merchant/Influencer text
  ///
  /// In en, this message translates to:
  /// **'Subscribe your store to add products.'**
  String get bizSubscribeYourStoreToAdd;

  /// Merchant/Influencer text
  ///
  /// In en, this message translates to:
  /// **'No products yet — add your first product'**
  String get bizNoProductsYetAddYour;

  /// Merchant/Influencer text
  ///
  /// In en, this message translates to:
  /// **'MERCHANT WORKSPACE'**
  String get bizMERCHANTWORKSPACE;

  /// Merchant/Influencer text
  ///
  /// In en, this message translates to:
  /// **'Welcome back'**
  String get bizWelcomeBack;

  /// Merchant/Influencer text
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t load your dashboard'**
  String get bizCouldnTLoadYourDashboard;

  /// Merchant/Influencer text
  ///
  /// In en, this message translates to:
  /// **'Live stores'**
  String get bizLiveStores;

  /// Merchant/Influencer text
  ///
  /// In en, this message translates to:
  /// **'Live banners'**
  String get bizLiveBanners;

  /// Merchant/Influencer text
  ///
  /// In en, this message translates to:
  /// **'Live products'**
  String get bizLiveProducts;

  /// Merchant/Influencer text
  ///
  /// In en, this message translates to:
  /// **'MANAGE YOUR BUSINESS'**
  String get bizMANAGEYOURBUSINESS;

  /// Merchant/Influencer text
  ///
  /// In en, this message translates to:
  /// **'My Store'**
  String get bizMyStore;

  /// Merchant/Influencer text
  ///
  /// In en, this message translates to:
  /// **'My Banner'**
  String get bizMyBanner;

  /// Merchant/Influencer text
  ///
  /// In en, this message translates to:
  /// **'My Products'**
  String get bizMyProducts;

  /// Merchant/Influencer text
  ///
  /// In en, this message translates to:
  /// **'Creator collaborations'**
  String get bizCreatorCollaborations;

  /// Merchant/Influencer text
  ///
  /// In en, this message translates to:
  /// **'Brief, match and manage local creators'**
  String get bizBriefMatchAndManageLocal;

  /// Merchant/Influencer text
  ///
  /// In en, this message translates to:
  /// **'Subscribe your store to work with creators.'**
  String get bizSubscribeYourStoreToWork;

  /// Merchant/Influencer text
  ///
  /// In en, this message translates to:
  /// **'Locked'**
  String get bizLocked;

  /// Merchant/Influencer text
  ///
  /// In en, this message translates to:
  /// **'Manage'**
  String get bizManage;

  /// Merchant/Influencer text
  ///
  /// In en, this message translates to:
  /// **'Promotions'**
  String get bizPromotions;

  /// Merchant/Influencer text
  ///
  /// In en, this message translates to:
  /// **'My Banners'**
  String get bizMyBanners;

  /// Merchant/Influencer text
  ///
  /// In en, this message translates to:
  /// **'New Banner'**
  String get bizNewBanner;

  /// Merchant/Influencer text
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t load banners'**
  String get bizCouldnTLoadBanners;

  /// Merchant/Influencer text
  ///
  /// In en, this message translates to:
  /// **'No banners yet'**
  String get bizNoBannersYet;

  /// Merchant/Influencer text
  ///
  /// In en, this message translates to:
  /// **'Tap + to create your first banner'**
  String get bizTapToCreateYourFirst;

  /// Merchant/Influencer text
  ///
  /// In en, this message translates to:
  /// **'Approved — Live'**
  String get bizApprovedLive;

  /// Merchant/Influencer text
  ///
  /// In en, this message translates to:
  /// **'Rejected'**
  String get bizRejected;

  /// Merchant/Influencer text
  ///
  /// In en, this message translates to:
  /// **'Removed by Admin'**
  String get bizRemovedByAdmin;

  /// Merchant/Influencer text
  ///
  /// In en, this message translates to:
  /// **'Turned Off'**
  String get bizTurnedOff;

  /// Merchant/Influencer text
  ///
  /// In en, this message translates to:
  /// **'Pending Approval'**
  String get bizPendingApproval;

  /// Merchant/Influencer text
  ///
  /// In en, this message translates to:
  /// **'Submitted'**
  String get bizSubmitted;

  /// Merchant/Influencer text
  ///
  /// In en, this message translates to:
  /// **'Edit Banner Title'**
  String get bizEditBannerTitle;

  /// Merchant/Influencer text
  ///
  /// In en, this message translates to:
  /// **'Banner title'**
  String get bizBannerTitle;

  /// Merchant/Influencer text
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get bizSave;

  /// Merchant/Influencer text
  ///
  /// In en, this message translates to:
  /// **'Edit Title'**
  String get bizEditTitle;

  /// Merchant/Influencer text
  ///
  /// In en, this message translates to:
  /// **'Turn Off Banner?'**
  String get bizTurnOffBanner;

  /// Merchant/Influencer text
  ///
  /// In en, this message translates to:
  /// **'Turn On Banner?'**
  String get bizTurnOnBanner;

  /// Merchant/Influencer text
  ///
  /// In en, this message translates to:
  /// **'This banner will be hidden from stores until you turn it back on.'**
  String get bizThisBannerWillBeHidden;

  /// Merchant/Influencer text
  ///
  /// In en, this message translates to:
  /// **'This banner will go live again in stores.'**
  String get bizThisBannerWillGoLive;

  /// Merchant/Influencer text
  ///
  /// In en, this message translates to:
  /// **'Turn Off'**
  String get bizTurnOff;

  /// Merchant/Influencer text
  ///
  /// In en, this message translates to:
  /// **'Turn On'**
  String get bizTurnOn;

  /// Merchant/Influencer text
  ///
  /// In en, this message translates to:
  /// **'Expired · Choose a new start date'**
  String get bizExpiredChooseANewStart;

  /// Merchant/Influencer text
  ///
  /// In en, this message translates to:
  /// **'Renew'**
  String get bizRenew;

  /// Merchant/Influencer text
  ///
  /// In en, this message translates to:
  /// **'Rejected · Create a new banner to resubmit'**
  String get bizRejectedCreateANewBanner;

  /// Merchant/Influencer text
  ///
  /// In en, this message translates to:
  /// **'Create new'**
  String get bizCreateNew;

  /// Merchant/Influencer text
  ///
  /// In en, this message translates to:
  /// **'Removed by admin'**
  String get bizRemovedByAdmin2;

  /// Merchant/Influencer text
  ///
  /// In en, this message translates to:
  /// **'Awaiting admin approval'**
  String get bizAwaitingAdminApproval;

  /// Merchant/Influencer text
  ///
  /// In en, this message translates to:
  /// **'Image too large. Max 2MB.'**
  String get bizImageTooLargeMax2MB;

  /// Merchant/Influencer text
  ///
  /// In en, this message translates to:
  /// **'Video is too large. Please select a video up to 10 MB.'**
  String get bizVideoIsTooLargePlease;

  /// Merchant/Influencer text
  ///
  /// In en, this message translates to:
  /// **'Video is too long. Please select a video up to 15 seconds.'**
  String get bizVideoIsTooLongPlease;

  /// Merchant/Influencer text
  ///
  /// In en, this message translates to:
  /// **'Could not read this video. Please select another video.'**
  String get bizCouldNotReadThisVideo;

  /// Merchant/Influencer text
  ///
  /// In en, this message translates to:
  /// **'Could not upload the video. Please try again.'**
  String get bizCouldNotUploadTheVideo;

  /// Merchant/Influencer text
  ///
  /// In en, this message translates to:
  /// **'Existing banner video will be reused'**
  String get bizExistingBannerVideoWillBe;

  /// Merchant/Influencer text
  ///
  /// In en, this message translates to:
  /// **'Tap to replace'**
  String get bizTapToReplace;

  /// Merchant/Influencer text
  ///
  /// In en, this message translates to:
  /// **'Tap to select banner video'**
  String get bizTapToSelectBannerVideo;

  /// Merchant/Influencer text
  ///
  /// In en, this message translates to:
  /// **'📐 1080×1080px (1:1)'**
  String get biz10801080px11;

  /// Merchant/Influencer text
  ///
  /// In en, this message translates to:
  /// **'Max 15 sec · 10 MB'**
  String get bizMax15Sec10MB;

  /// Merchant/Influencer text
  ///
  /// In en, this message translates to:
  /// **'Banner title required'**
  String get bizBannerTitleRequired;

  /// Merchant/Influencer text
  ///
  /// In en, this message translates to:
  /// **'Please select a store'**
  String get bizPleaseSelectAStore;

  /// Merchant/Influencer text
  ///
  /// In en, this message translates to:
  /// **'Please select a city'**
  String get bizPleaseSelectACity;

  /// Merchant/Influencer text
  ///
  /// In en, this message translates to:
  /// **'Please select a banner video'**
  String get bizPleaseSelectABannerVideo;

  /// Merchant/Influencer text
  ///
  /// In en, this message translates to:
  /// **'Please upload a banner image'**
  String get bizPleaseUploadABannerImage;

  /// Merchant/Influencer text
  ///
  /// In en, this message translates to:
  /// **'Enter number of days (minimum 1)'**
  String get bizEnterNumberOfDaysMinimum;

  /// Merchant/Influencer text
  ///
  /// In en, this message translates to:
  /// **'Untitled deal'**
  String get bizUntitledDeal;

  /// Merchant/Influencer text
  ///
  /// In en, this message translates to:
  /// **'Untitled product'**
  String get bizUntitledProduct;

  /// Merchant/Influencer text
  ///
  /// In en, this message translates to:
  /// **'CTA destination'**
  String get bizCTADestination;

  /// Merchant/Influencer text
  ///
  /// In en, this message translates to:
  /// **'Choose where this banner should take the customer.'**
  String get bizChooseWhereThisBannerShould;

  /// Merchant/Influencer text
  ///
  /// In en, this message translates to:
  /// **'Select Deal'**
  String get bizSelectDeal;

  /// Merchant/Influencer text
  ///
  /// In en, this message translates to:
  /// **'Select Product'**
  String get bizSelectProduct;

  /// Merchant/Influencer text
  ///
  /// In en, this message translates to:
  /// **'Customers will open the selected store.'**
  String get bizCustomersWillOpenTheSelected;

  /// Merchant/Influencer text
  ///
  /// In en, this message translates to:
  /// **'Nothing selected yet — the banner will open the store.'**
  String get bizNothingSelectedYetTheBanner;

  /// Merchant/Influencer text
  ///
  /// In en, this message translates to:
  /// **'✅ Discount applied!'**
  String get bizDiscountApplied;

  /// Merchant/Influencer text
  ///
  /// In en, this message translates to:
  /// **'Payment gateway not configured. Contact support.'**
  String get bizPaymentGatewayNotConfiguredContact;

  /// Merchant/Influencer text
  ///
  /// In en, this message translates to:
  /// **'Could not open payment. Please try again.'**
  String get bizCouldNotOpenPaymentPlease;

  /// Merchant/Influencer text
  ///
  /// In en, this message translates to:
  /// **'Banner Order Summary'**
  String get bizBannerOrderSummary;

  /// Merchant/Influencer text
  ///
  /// In en, this message translates to:
  /// **'Title'**
  String get bizTitle;

  /// Merchant/Influencer text
  ///
  /// In en, this message translates to:
  /// **'Duration'**
  String get bizDuration;

  /// Merchant/Influencer text
  ///
  /// In en, this message translates to:
  /// **'Period'**
  String get bizPeriod;

  /// Merchant/Influencer text
  ///
  /// In en, this message translates to:
  /// **'Rate'**
  String get bizRate;

  /// Merchant/Influencer text
  ///
  /// In en, this message translates to:
  /// **'Base Price'**
  String get bizBasePrice;

  /// Merchant/Influencer text
  ///
  /// In en, this message translates to:
  /// **'Discount'**
  String get bizDiscount;

  /// Merchant/Influencer text
  ///
  /// In en, this message translates to:
  /// **'Total'**
  String get bizTotal;

  /// Merchant/Influencer text
  ///
  /// In en, this message translates to:
  /// **'Your banner will be submitted for admin review after confirmation.'**
  String get bizYourBannerWillBeSubmitted;

  /// Merchant/Influencer text
  ///
  /// In en, this message translates to:
  /// **'Razorpay checkout will open. Banner goes live after admin approval.'**
  String get bizRazorpayCheckoutWillOpenBanner;

  /// Merchant/Influencer text
  ///
  /// In en, this message translates to:
  /// **'Confirm Submit'**
  String get bizConfirmSubmit;

  /// Merchant/Influencer text
  ///
  /// In en, this message translates to:
  /// **'Renew Banner'**
  String get bizRenewBanner;

  /// Merchant/Influencer text
  ///
  /// In en, this message translates to:
  /// **'Create Banner'**
  String get bizCreateBanner;

  /// Merchant/Influencer text
  ///
  /// In en, this message translates to:
  /// **'Banner Title *'**
  String get bizBannerTitle2;

  /// Merchant/Influencer text
  ///
  /// In en, this message translates to:
  /// **'e.g. 50% OFF at Raj Store'**
  String get bizEG50OFFAt;

  /// Merchant/Influencer text
  ///
  /// In en, this message translates to:
  /// **'Select Store *'**
  String get bizSelectStore;

  /// Merchant/Influencer text
  ///
  /// In en, this message translates to:
  /// **'Unnamed Store'**
  String get bizUnnamedStore;

  /// Merchant/Influencer text
  ///
  /// In en, this message translates to:
  /// **'City auto-filled from store'**
  String get bizCityAutoFilledFromStore;

  /// Merchant/Influencer text
  ///
  /// In en, this message translates to:
  /// **'Image'**
  String get bizImage;

  /// Merchant/Influencer text
  ///
  /// In en, this message translates to:
  /// **'Video'**
  String get bizVideo;

  /// Merchant/Influencer text
  ///
  /// In en, this message translates to:
  /// **'Tap to upload banner image'**
  String get bizTapToUploadBannerImage;

  /// Merchant/Influencer text
  ///
  /// In en, this message translates to:
  /// **'📦 Max 2MB'**
  String get bizMax2MB;

  /// Merchant/Influencer text
  ///
  /// In en, this message translates to:
  /// **'Duration & Start Date'**
  String get bizDurationStartDate;

  /// Merchant/Influencer text
  ///
  /// In en, this message translates to:
  /// **'Number of Days'**
  String get bizNumberOfDays;

  /// Merchant/Influencer text
  ///
  /// In en, this message translates to:
  /// **'From Date'**
  String get bizFromDate;

  /// Merchant/Influencer text
  ///
  /// In en, this message translates to:
  /// **'Active period:'**
  String get bizActivePeriod;

  /// Merchant/Influencer text
  ///
  /// In en, this message translates to:
  /// **'Discount Code'**
  String get bizDiscountCode;

  /// Merchant/Influencer text
  ///
  /// In en, this message translates to:
  /// **'Have a promo code? Enter it below.'**
  String get bizHaveAPromoCodeEnter;

  /// Merchant/Influencer text
  ///
  /// In en, this message translates to:
  /// **'e.g. OFFRO20'**
  String get bizEGOFFRO20;

  /// Merchant/Influencer text
  ///
  /// In en, this message translates to:
  /// **'Apply'**
  String get bizApply;

  /// Merchant/Influencer text
  ///
  /// In en, this message translates to:
  /// **'Proceed to Checkout'**
  String get bizProceedToCheckout;

  /// Merchant/Influencer text
  ///
  /// In en, this message translates to:
  /// **'Live'**
  String get bizLive;

  /// Merchant/Influencer text
  ///
  /// In en, this message translates to:
  /// **'Filter Products'**
  String get bizFilterProducts;

  /// Merchant/Influencer text
  ///
  /// In en, this message translates to:
  /// **'Edit Product'**
  String get bizEditProduct;

  /// Merchant/Influencer text
  ///
  /// In en, this message translates to:
  /// **'Analytics'**
  String get bizAnalytics;

  /// Merchant/Influencer text
  ///
  /// In en, this message translates to:
  /// **'Delete Product'**
  String get bizDeleteProduct;

  /// Merchant/Influencer text
  ///
  /// In en, this message translates to:
  /// **'Catalogue'**
  String get bizCatalogue;

  /// Merchant/Influencer text
  ///
  /// In en, this message translates to:
  /// **'Filter'**
  String get bizFilter;

  /// Merchant/Influencer text
  ///
  /// In en, this message translates to:
  /// **'New Product'**
  String get bizNewProduct;

  /// Merchant/Influencer text
  ///
  /// In en, this message translates to:
  /// **'Search products…'**
  String get bizSearchProducts;

  /// Merchant/Influencer text
  ///
  /// In en, this message translates to:
  /// **'Pending'**
  String get bizPending;

  /// Merchant/Influencer text
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t load products'**
  String get bizCouldnTLoadProducts;

  /// Merchant/Influencer text
  ///
  /// In en, this message translates to:
  /// **'No products yet'**
  String get bizNoProductsYet;

  /// Merchant/Influencer text
  ///
  /// In en, this message translates to:
  /// **'No matching products'**
  String get bizNoMatchingProducts;

  /// Merchant/Influencer text
  ///
  /// In en, this message translates to:
  /// **'Tap + New Product to get started'**
  String get bizTapNewProductToGet;

  /// Merchant/Influencer text
  ///
  /// In en, this message translates to:
  /// **'Paused'**
  String get bizPaused;

  /// Merchant/Influencer text
  ///
  /// In en, this message translates to:
  /// **'Free'**
  String get bizFree;

  /// Merchant/Influencer text
  ///
  /// In en, this message translates to:
  /// **'Paid'**
  String get bizPaid;

  /// Merchant/Influencer text
  ///
  /// In en, this message translates to:
  /// **'Deactivated'**
  String get bizDeactivated;

  /// Merchant/Influencer text
  ///
  /// In en, this message translates to:
  /// **'On'**
  String get bizOn;

  /// Merchant/Influencer text
  ///
  /// In en, this message translates to:
  /// **'Off'**
  String get bizOff;

  /// Merchant/Influencer text
  ///
  /// In en, this message translates to:
  /// **'Offer Text'**
  String get bizOfferText;

  /// Merchant/Influencer text
  ///
  /// In en, this message translates to:
  /// **'Original Price'**
  String get bizOriginalPrice;

  /// Merchant/Influencer text
  ///
  /// In en, this message translates to:
  /// **'Offer Price'**
  String get bizOfferPrice;

  /// Merchant/Influencer text
  ///
  /// In en, this message translates to:
  /// **'Product updated!'**
  String get bizProductUpdated;

  /// Merchant/Influencer text
  ///
  /// In en, this message translates to:
  /// **'Delete this product?'**
  String get bizDeleteThisProduct;

  /// Merchant/Influencer text
  ///
  /// In en, this message translates to:
  /// **'Product deleted.'**
  String get bizProductDeleted;

  /// Merchant/Influencer text
  ///
  /// In en, this message translates to:
  /// **'Logo too large. Max 1MB.'**
  String get bizLogoTooLargeMax1MB;

  /// Merchant/Influencer text
  ///
  /// In en, this message translates to:
  /// **'Enter a code'**
  String get bizEnterACode;

  /// Merchant/Influencer text
  ///
  /// In en, this message translates to:
  /// **'Product title required'**
  String get bizProductTitleRequired;

  /// Merchant/Influencer text
  ///
  /// In en, this message translates to:
  /// **'Please select a store for this product'**
  String get bizPleaseSelectAStoreFor;

  /// Merchant/Influencer text
  ///
  /// In en, this message translates to:
  /// **'Please select a city for this product'**
  String get bizPleaseSelectACityFor;

  /// Merchant/Influencer text
  ///
  /// In en, this message translates to:
  /// **'Please upload a product image'**
  String get bizPleaseUploadAProductImage;

  /// Merchant/Influencer text
  ///
  /// In en, this message translates to:
  /// **'Enter the number of days (minimum 1)'**
  String get bizEnterTheNumberOfDays;

  /// Merchant/Influencer text
  ///
  /// In en, this message translates to:
  /// **'Product Order Summary'**
  String get bizProductOrderSummary;

  /// Merchant/Influencer text
  ///
  /// In en, this message translates to:
  /// **'Price'**
  String get bizPrice;

  /// Merchant/Influencer text
  ///
  /// In en, this message translates to:
  /// **'Product will go to admin review. No payment needed.'**
  String get bizProductWillGoToAdmin;

  /// Merchant/Influencer text
  ///
  /// In en, this message translates to:
  /// **'Razorpay opens. Product live after admin approval.'**
  String get bizRazorpayOpensProductLiveAfter;

  /// Merchant/Influencer text
  ///
  /// In en, this message translates to:
  /// **'Save Product'**
  String get bizSaveProduct;

  /// Merchant/Influencer text
  ///
  /// In en, this message translates to:
  /// **'Add Product'**
  String get bizAddProduct;

  /// Merchant/Influencer text
  ///
  /// In en, this message translates to:
  /// **'Product Title *'**
  String get bizProductTitle;

  /// Merchant/Influencer text
  ///
  /// In en, this message translates to:
  /// **'e.g. Raj Store ₹50 Off'**
  String get bizEGRajStore50;

  /// Merchant/Influencer text
  ///
  /// In en, this message translates to:
  /// **'e.g. Get ₹50 off on orders above ₹299'**
  String get bizEGGet50Off;

  /// Merchant/Influencer text
  ///
  /// In en, this message translates to:
  /// **'Discount is auto-calculated from prices'**
  String get bizDiscountIsAutoCalculatedFrom;

  /// Merchant/Influencer text
  ///
  /// In en, this message translates to:
  /// **'Upload Image'**
  String get bizUploadImage;

  /// Merchant/Influencer text
  ///
  /// In en, this message translates to:
  /// **'📐 400×400px'**
  String get biz400400px;

  /// Merchant/Influencer text
  ///
  /// In en, this message translates to:
  /// **'📦 Max 1MB'**
  String get bizMax1MB;

  /// Merchant/Influencer text
  ///
  /// In en, this message translates to:
  /// **'Validity (Days)'**
  String get bizValidityDays;

  /// Merchant/Influencer text
  ///
  /// In en, this message translates to:
  /// **'Start date'**
  String get bizStartDate;

  /// Merchant/Influencer text
  ///
  /// In en, this message translates to:
  /// **'End date'**
  String get bizEndDate;

  /// Merchant/Influencer text
  ///
  /// In en, this message translates to:
  /// **'Number of days'**
  String get bizNumberOfDays2;

  /// Merchant/Influencer text
  ///
  /// In en, this message translates to:
  /// **'Live period:'**
  String get bizLivePeriod;

  /// Merchant/Influencer text
  ///
  /// In en, this message translates to:
  /// **'Free ({amount})'**
  String bizFree0(String amount);

  /// Merchant/Influencer text
  ///
  /// In en, this message translates to:
  /// **'Free product'**
  String get bizFreeProduct;

  /// Merchant/Influencer text
  ///
  /// In en, this message translates to:
  /// **'Your business'**
  String get bizYourBusiness;

  /// Merchant/Influencer text
  ///
  /// In en, this message translates to:
  /// **'My Stores'**
  String get bizMyStores;

  /// Merchant/Influencer text
  ///
  /// In en, this message translates to:
  /// **'Tap + to add your first store'**
  String get bizTapToAddYourFirst;

  /// Merchant/Influencer text
  ///
  /// In en, this message translates to:
  /// **'Active'**
  String get bizActive;

  /// Merchant/Influencer text
  ///
  /// In en, this message translates to:
  /// **'Draft'**
  String get bizDraft;

  /// Merchant/Influencer text
  ///
  /// In en, this message translates to:
  /// **'Inactive'**
  String get bizInactive;

  /// Merchant/Influencer text
  ///
  /// In en, this message translates to:
  /// **'Deleted'**
  String get bizDeleted;

  /// Merchant/Influencer text
  ///
  /// In en, this message translates to:
  /// **'Removed'**
  String get bizRemoved;

  /// Merchant/Influencer text
  ///
  /// In en, this message translates to:
  /// **'Subscribe'**
  String get bizSubscribe;

  /// Merchant/Influencer text
  ///
  /// In en, this message translates to:
  /// **'Awaiting Admin Approval'**
  String get bizAwaitingAdminApproval2;

  /// Merchant/Influencer text
  ///
  /// In en, this message translates to:
  /// **'QR'**
  String get bizQR;

  /// Merchant/Influencer text
  ///
  /// In en, this message translates to:
  /// **'Gen QR'**
  String get bizGenQR;

  /// Merchant/Influencer text
  ///
  /// In en, this message translates to:
  /// **'Show this to customers to earn points'**
  String get bizShowThisToCustomersTo;

  /// Merchant/Influencer text
  ///
  /// In en, this message translates to:
  /// **'Device location is turned off. Turn it on and try again.'**
  String get bizDeviceLocationIsTurnedOff;

  /// Merchant/Influencer text
  ///
  /// In en, this message translates to:
  /// **'Unable to identify the exact location from this Google Maps link. Please open Google Maps, drop a pin on the exact location, tap Share → Copy link, and try again.'**
  String get bizUnableToIdentifyTheExact;

  /// Merchant/Influencer text
  ///
  /// In en, this message translates to:
  /// **'City'**
  String get bizCity;

  /// Merchant/Influencer text
  ///
  /// In en, this message translates to:
  /// **'State'**
  String get bizState;

  /// Merchant/Influencer text
  ///
  /// In en, this message translates to:
  /// **'Area'**
  String get bizArea;

  /// Merchant/Influencer text
  ///
  /// In en, this message translates to:
  /// **'Postal code'**
  String get bizPostalCode;

  /// Merchant/Influencer text
  ///
  /// In en, this message translates to:
  /// **'Location captured'**
  String get bizLocationCaptured;

  /// Merchant/Influencer text
  ///
  /// In en, this message translates to:
  /// **'Image too large. Max 2MB allowed.'**
  String get bizImageTooLargeMax2MB2;

  /// Merchant/Influencer text
  ///
  /// In en, this message translates to:
  /// **'Store name required'**
  String get bizStoreNameRequired;

  /// Merchant/Influencer text
  ///
  /// In en, this message translates to:
  /// **'Please set the store location using \"Use current location\" or a Google Maps link'**
  String get bizPleaseSetTheStoreLocation;

  /// Merchant/Influencer text
  ///
  /// In en, this message translates to:
  /// **'Mobile number is required'**
  String get bizMobileNumberIsRequired;

  /// Merchant/Influencer text
  ///
  /// In en, this message translates to:
  /// **'Enter a valid 10-digit mobile number (starts with 6–9)'**
  String get bizEnterAValid10Digit;

  /// Merchant/Influencer text
  ///
  /// In en, this message translates to:
  /// **'Edit Store'**
  String get bizEditStore;

  /// Merchant/Influencer text
  ///
  /// In en, this message translates to:
  /// **'Add Store'**
  String get bizAddStore;

  /// Merchant/Influencer text
  ///
  /// In en, this message translates to:
  /// **'Store Name *'**
  String get bizStoreName;

  /// Merchant/Influencer text
  ///
  /// In en, this message translates to:
  /// **'Category'**
  String get bizCategory;

  /// Merchant/Influencer text
  ///
  /// In en, this message translates to:
  /// **'Select category'**
  String get bizSelectCategory;

  /// Merchant/Influencer text
  ///
  /// In en, this message translates to:
  /// **'Store location'**
  String get bizStoreLocation;

  /// Merchant/Influencer text
  ///
  /// In en, this message translates to:
  /// **'Use GPS or paste a Maps link.'**
  String get bizUseGPSOrPasteA;

  /// Merchant/Influencer text
  ///
  /// In en, this message translates to:
  /// **'Use current location'**
  String get bizUseCurrentLocation;

  /// Merchant/Influencer text
  ///
  /// In en, this message translates to:
  /// **'or paste Google Maps link'**
  String get bizOrPasteGoogleMapsLink;

  /// Merchant/Influencer text
  ///
  /// In en, this message translates to:
  /// **'Paste Google Maps link here'**
  String get bizPasteGoogleMapsLinkHere;

  /// Merchant/Influencer text
  ///
  /// In en, this message translates to:
  /// **'Resolve Location'**
  String get bizResolveLocation;

  /// Merchant/Influencer text
  ///
  /// In en, this message translates to:
  /// **'Latitude'**
  String get bizLatitude;

  /// Merchant/Influencer text
  ///
  /// In en, this message translates to:
  /// **'Longitude'**
  String get bizLongitude;

  /// Merchant/Influencer text
  ///
  /// In en, this message translates to:
  /// **'Auto-filled by GPS or Google Maps — you can edit any value. Edited values are saved as entered.'**
  String get bizAutoFilledByGPSOr;

  /// Merchant/Influencer text
  ///
  /// In en, this message translates to:
  /// **'Phone'**
  String get bizPhone;

  /// Merchant/Influencer text
  ///
  /// In en, this message translates to:
  /// **'Tap to change image'**
  String get bizTapToChangeImage;

  /// Merchant/Influencer text
  ///
  /// In en, this message translates to:
  /// **'Main Store Image'**
  String get bizMainStoreImage;

  /// Merchant/Influencer text
  ///
  /// In en, this message translates to:
  /// **'📐 800×600px (4:3)'**
  String get biz800600px43;

  /// Merchant/Influencer text
  ///
  /// In en, this message translates to:
  /// **'Upload Logo [Optional]'**
  String get bizUploadLogoOptional;

  /// Merchant/Influencer text
  ///
  /// In en, this message translates to:
  /// **'Tap to change logo'**
  String get bizTapToChangeLogo;

  /// Merchant/Influencer text
  ///
  /// In en, this message translates to:
  /// **'Tap to upload logo'**
  String get bizTapToUploadLogo;

  /// Merchant/Influencer text
  ///
  /// In en, this message translates to:
  /// **'📐 200×200px (1:1)'**
  String get biz200200px11;

  /// Merchant/Influencer text
  ///
  /// In en, this message translates to:
  /// **'Store Timings [Optional]'**
  String get bizStoreTimingsOptional;

  /// Merchant/Influencer text
  ///
  /// In en, this message translates to:
  /// **'Opening Time'**
  String get bizOpeningTime;

  /// Merchant/Influencer text
  ///
  /// In en, this message translates to:
  /// **'Open at'**
  String get bizOpenAt;

  /// Merchant/Influencer text
  ///
  /// In en, this message translates to:
  /// **'Closing Time'**
  String get bizClosingTime;

  /// Merchant/Influencer text
  ///
  /// In en, this message translates to:
  /// **'Close at'**
  String get bizCloseAt;

  /// Merchant/Influencer text
  ///
  /// In en, this message translates to:
  /// **'About this store (description shown to customers)'**
  String get bizAboutThisStoreDescriptionShown;

  /// Merchant/Influencer text
  ///
  /// In en, this message translates to:
  /// **'Save Changes'**
  String get bizSaveChanges;

  /// Merchant/Influencer text
  ///
  /// In en, this message translates to:
  /// **'Create Store'**
  String get bizCreateStore;

  /// Merchant/Influencer text
  ///
  /// In en, this message translates to:
  /// **'Confirming payment...'**
  String get bizConfirmingPayment;

  /// Merchant/Influencer text
  ///
  /// In en, this message translates to:
  /// **'Please wait a moment'**
  String get bizPleaseWaitAMoment;

  /// Merchant/Influencer text
  ///
  /// In en, this message translates to:
  /// **'Subscription Request Sent'**
  String get bizSubscriptionRequestSent;

  /// Merchant/Influencer text
  ///
  /// In en, this message translates to:
  /// **'Plan'**
  String get bizPlan;

  /// Merchant/Influencer text
  ///
  /// In en, this message translates to:
  /// **'From'**
  String get bizFrom;

  /// Merchant/Influencer text
  ///
  /// In en, this message translates to:
  /// **'To'**
  String get bizTo;

  /// Merchant/Influencer text
  ///
  /// In en, this message translates to:
  /// **'Total Payable'**
  String get bizTotalPayable;

  /// Merchant/Influencer text
  ///
  /// In en, this message translates to:
  /// **'✅  Your subscription request has been submitted.'**
  String get bizYourSubscriptionRequestHasBeen;

  /// Merchant/Influencer text
  ///
  /// In en, this message translates to:
  /// **'Confirm Payment'**
  String get bizConfirmPayment;

  /// Merchant/Influencer text
  ///
  /// In en, this message translates to:
  /// **'Razorpay checkout will open. After payment, admin will approve your store.'**
  String get bizRazorpayCheckoutWillOpenAfter;

  /// Merchant/Influencer text
  ///
  /// In en, this message translates to:
  /// **'Pay Now'**
  String get bizPayNow;

  /// Merchant/Influencer text
  ///
  /// In en, this message translates to:
  /// **'Subscribe Store'**
  String get bizSubscribeStore;

  /// Merchant/Influencer text
  ///
  /// In en, this message translates to:
  /// **'Select Plan'**
  String get bizSelectPlan;

  /// Merchant/Influencer text
  ///
  /// In en, this message translates to:
  /// **'Start Date'**
  String get bizStartDate2;

  /// Merchant/Influencer text
  ///
  /// In en, this message translates to:
  /// **'Have a discount code?'**
  String get bizHaveADiscountCode;

  /// Merchant/Influencer text
  ///
  /// In en, this message translates to:
  /// **'Enter code'**
  String get bizEnterCode;

  /// Merchant/Influencer text
  ///
  /// In en, this message translates to:
  /// **'Discount:'**
  String get bizDiscount2;

  /// Merchant/Influencer text
  ///
  /// In en, this message translates to:
  /// **'Remove'**
  String get bizRemove;

  /// Merchant/Influencer text
  ///
  /// In en, this message translates to:
  /// **'Proceed to Pay'**
  String get bizProceedToPay;

  /// Merchant/Influencer text
  ///
  /// In en, this message translates to:
  /// **'Refresh'**
  String get bizRefresh;

  /// Merchant/Influencer text
  ///
  /// In en, this message translates to:
  /// **'No invoices yet'**
  String get bizNoInvoicesYet;

  /// Merchant/Influencer text
  ///
  /// In en, this message translates to:
  /// **'Pull down to refresh'**
  String get bizPullDownToRefresh;

  /// Merchant/Influencer text
  ///
  /// In en, this message translates to:
  /// **'Share'**
  String get bizShare;

  /// Merchant/Influencer text
  ///
  /// In en, this message translates to:
  /// **'Download PDF'**
  String get bizDownloadPDF;

  /// Merchant/Influencer text
  ///
  /// In en, this message translates to:
  /// **'Account registered'**
  String get bizAccountRegistered;

  /// Merchant/Influencer text
  ///
  /// In en, this message translates to:
  /// **'New store created'**
  String get bizNewStoreCreated;

  /// Merchant/Influencer text
  ///
  /// In en, this message translates to:
  /// **'Store profile updated'**
  String get bizStoreProfileUpdated;

  /// Merchant/Influencer text
  ///
  /// In en, this message translates to:
  /// **'Store approved'**
  String get bizStoreApproved;

  /// Merchant/Influencer text
  ///
  /// In en, this message translates to:
  /// **'Store rejected'**
  String get bizStoreRejected;

  /// Merchant/Influencer text
  ///
  /// In en, this message translates to:
  /// **'Store subscription activated'**
  String get bizStoreSubscriptionActivated;

  /// Merchant/Influencer text
  ///
  /// In en, this message translates to:
  /// **'Free subscription activated'**
  String get bizFreeSubscriptionActivated;

  /// Merchant/Influencer text
  ///
  /// In en, this message translates to:
  /// **'Subscription payment received'**
  String get bizSubscriptionPaymentReceived;

  /// Merchant/Influencer text
  ///
  /// In en, this message translates to:
  /// **'Banner submitted'**
  String get bizBannerSubmitted;

  /// Merchant/Influencer text
  ///
  /// In en, this message translates to:
  /// **'Banner approved'**
  String get bizBannerApproved;

  /// Merchant/Influencer text
  ///
  /// In en, this message translates to:
  /// **'Banner rejected'**
  String get bizBannerRejected;

  /// Merchant/Influencer text
  ///
  /// In en, this message translates to:
  /// **'Banner payment received'**
  String get bizBannerPaymentReceived;

  /// Merchant/Influencer text
  ///
  /// In en, this message translates to:
  /// **'Product submitted'**
  String get bizProductSubmitted;

  /// Merchant/Influencer text
  ///
  /// In en, this message translates to:
  /// **'Product approved'**
  String get bizProductApproved;

  /// Merchant/Influencer text
  ///
  /// In en, this message translates to:
  /// **'Product rejected'**
  String get bizProductRejected;

  /// Merchant/Influencer text
  ///
  /// In en, this message translates to:
  /// **'Product payment received'**
  String get bizProductPaymentReceived;

  /// Merchant/Influencer text
  ///
  /// In en, this message translates to:
  /// **'Payment received'**
  String get bizPaymentReceived;

  /// Merchant/Influencer text
  ///
  /// In en, this message translates to:
  /// **'Free plan activated'**
  String get bizFreePlanActivated;

  /// Merchant/Influencer text
  ///
  /// In en, this message translates to:
  /// **'Profile updated'**
  String get bizProfileUpdated;

  /// Merchant/Influencer text
  ///
  /// In en, this message translates to:
  /// **'QR code regenerated'**
  String get bizQRCodeRegenerated;

  /// Merchant/Influencer text
  ///
  /// In en, this message translates to:
  /// **'Payment'**
  String get bizPayment;

  /// Merchant/Influencer text
  ///
  /// In en, this message translates to:
  /// **'✅ Approved — Live'**
  String get bizApprovedLive2;

  /// Merchant/Influencer text
  ///
  /// In en, this message translates to:
  /// **'❌ Rejected'**
  String get bizRejected2;

  /// Merchant/Influencer text
  ///
  /// In en, this message translates to:
  /// **'⏳ Pending Approval'**
  String get bizPendingApproval2;

  /// Merchant/Influencer text
  ///
  /// In en, this message translates to:
  /// **'Business timeline'**
  String get bizBusinessTimeline;

  /// Merchant/Influencer text
  ///
  /// In en, this message translates to:
  /// **'No activity yet'**
  String get bizNoActivityYet;

  /// Merchant/Influencer text
  ///
  /// In en, this message translates to:
  /// **'Merchant account'**
  String get bizMerchantAccount;

  /// Merchant/Influencer text
  ///
  /// In en, this message translates to:
  /// **'Tap photo to change'**
  String get bizTapPhotoToChange;

  /// Merchant/Influencer text
  ///
  /// In en, this message translates to:
  /// **'Switch between User, Merchant & Influencer'**
  String get bizSwitchBetweenUserMerchantInfluencer;

  /// Merchant/Influencer text
  ///
  /// In en, this message translates to:
  /// **'KYC Policy'**
  String get bizKYCPolicy;

  /// Merchant/Influencer text
  ///
  /// In en, this message translates to:
  /// **'Merchant offers'**
  String get bizMerchantOffers;

  /// Merchant/Influencer text
  ///
  /// In en, this message translates to:
  /// **'My Deals'**
  String get bizMyDeals;

  /// Merchant/Influencer text
  ///
  /// In en, this message translates to:
  /// **'Add Deal'**
  String get bizAddDeal;

  /// Merchant/Influencer text
  ///
  /// In en, this message translates to:
  /// **'You need an active store to add deals.'**
  String get bizYouNeedAnActiveStore;

  /// Merchant/Influencer text
  ///
  /// In en, this message translates to:
  /// **'No deals yet'**
  String get bizNoDealsYet;

  /// Merchant/Influencer text
  ///
  /// In en, this message translates to:
  /// **'Add deals to attract more customers'**
  String get bizAddDealsToAttractMore;

  /// Merchant/Influencer text
  ///
  /// In en, this message translates to:
  /// **'Edit Deal'**
  String get bizEditDeal;

  /// Merchant/Influencer text
  ///
  /// In en, this message translates to:
  /// **'Delete Deal?'**
  String get bizDeleteDeal;

  /// Merchant/Influencer text
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get bizDelete;

  /// Merchant/Influencer text
  ///
  /// In en, this message translates to:
  /// **'Deal title is required'**
  String get bizDealTitleIsRequired;

  /// Merchant/Influencer text
  ///
  /// In en, this message translates to:
  /// **'End date is required'**
  String get bizEndDateIsRequired;

  /// Merchant/Influencer text
  ///
  /// In en, this message translates to:
  /// **'Please add an image before saving.'**
  String get bizPleaseAddAnImageBefore;

  /// Merchant/Influencer text
  ///
  /// In en, this message translates to:
  /// **'Deal updated!'**
  String get bizDealUpdated;

  /// Merchant/Influencer text
  ///
  /// In en, this message translates to:
  /// **'Deal added!'**
  String get bizDealAdded;

  /// Merchant/Influencer text
  ///
  /// In en, this message translates to:
  /// **'Deal Title (e.g. 20% off on all items)'**
  String get bizDealTitleEG20;

  /// Merchant/Influencer text
  ///
  /// In en, this message translates to:
  /// **'Description (optional)'**
  String get bizDescriptionOptional;

  /// Merchant/Influencer text
  ///
  /// In en, this message translates to:
  /// **'Deal Image'**
  String get bizDealImage;

  /// Merchant/Influencer text
  ///
  /// In en, this message translates to:
  /// **'Tap to replace image'**
  String get bizTapToReplaceImage;

  /// Merchant/Influencer text
  ///
  /// In en, this message translates to:
  /// **'📦 Max 2MB · Required'**
  String get bizMax2MBRequired;

  /// Merchant/Influencer text
  ///
  /// In en, this message translates to:
  /// **'Select End Date'**
  String get bizSelectEndDate;

  /// Merchant/Influencer text
  ///
  /// In en, this message translates to:
  /// **'All your stores, products & data will be permanently removed'**
  String get bizAllYourStoresProductsData;

  /// Merchant/Influencer text
  ///
  /// In en, this message translates to:
  /// **'I no longer run my business'**
  String get bizINoLongerRunMy;

  /// Merchant/Influencer text
  ///
  /// In en, this message translates to:
  /// **'The app is not working properly for me'**
  String get bizTheAppIsNotWorking;

  /// Merchant/Influencer text
  ///
  /// In en, this message translates to:
  /// **'Once your account is deleted, your stores, products, banners and data cannot be retrieved. Signing up again will create a new account.'**
  String get bizOnceYourAccountIsDeleted;

  /// Merchant/Influencer text
  ///
  /// In en, this message translates to:
  /// **'Your merchant account will be marked for deletion. You will be logged out immediately and cannot log in again.\n\nOnce deleted, your stores, products and data cannot be retrieved. Are you absolutely sure?'**
  String get bizYourMerchantAccountWillBe;

  /// Merchant/Influencer text
  ///
  /// In en, this message translates to:
  /// **'Checking…'**
  String get bizChecking;

  /// Merchant/Influencer text
  ///
  /// In en, this message translates to:
  /// **'Discount applied!'**
  String get bizDiscountApplied2;

  /// Merchant/Influencer text
  ///
  /// In en, this message translates to:
  /// **'Choose a later end date (add at least 1 day)'**
  String get bizChooseALaterEndDate;

  /// Merchant/Influencer text
  ///
  /// In en, this message translates to:
  /// **'✅ Renewed successfully!'**
  String get bizRenewedSuccessfully;

  /// Merchant/Influencer text
  ///
  /// In en, this message translates to:
  /// **'Renewal Summary'**
  String get bizRenewalSummary;

  /// Merchant/Influencer text
  ///
  /// In en, this message translates to:
  /// **'New end date'**
  String get bizNewEndDate;

  /// Merchant/Influencer text
  ///
  /// In en, this message translates to:
  /// **'Free renewal'**
  String get bizFreeRenewal;

  /// Merchant/Influencer text
  ///
  /// In en, this message translates to:
  /// **'Renew free'**
  String get bizRenewFree;

  /// Merchant/Influencer text
  ///
  /// In en, this message translates to:
  /// **'Renewed!'**
  String get bizRenewed;

  /// Merchant/Influencer text
  ///
  /// In en, this message translates to:
  /// **'Renew Product'**
  String get bizRenewProduct;

  /// Merchant/Influencer text
  ///
  /// In en, this message translates to:
  /// **'No end date'**
  String get bizNoEndDate;

  /// Merchant/Influencer text
  ///
  /// In en, this message translates to:
  /// **'Choose how long the product stays live.'**
  String get bizChooseHowLongTheProduct;

  /// Merchant/Influencer text
  ///
  /// In en, this message translates to:
  /// **'Days to add'**
  String get bizDaysToAdd;

  /// Merchant/Influencer text
  ///
  /// In en, this message translates to:
  /// **'Product Analytics'**
  String get bizProductAnalytics;

  /// Merchant/Influencer text
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t load analytics'**
  String get bizCouldnTLoadAnalytics;

  /// Merchant/Influencer text
  ///
  /// In en, this message translates to:
  /// **'Please check your connection and try again.'**
  String get bizPleaseCheckYourConnectionAnd;

  /// Merchant/Influencer text
  ///
  /// In en, this message translates to:
  /// **'Premium Listing Analytics'**
  String get bizPremiumListingAnalytics;

  /// Merchant/Influencer text
  ///
  /// In en, this message translates to:
  /// **'👁️ Views'**
  String get bizViews;

  /// Merchant/Influencer text
  ///
  /// In en, this message translates to:
  /// **'🔗 Shares'**
  String get bizShares;

  /// Merchant/Influencer text
  ///
  /// In en, this message translates to:
  /// **'🛒 Store Visits'**
  String get bizStoreVisits;

  /// Merchant/Influencer text
  ///
  /// In en, this message translates to:
  /// **'📅 Last Seen'**
  String get bizLastSeen;

  /// Merchant/Influencer text
  ///
  /// In en, this message translates to:
  /// **'Store Visits: customers who visited the store'**
  String get bizStoreVisitsCustomersWhoVisited;

  /// Merchant/Influencer text
  ///
  /// In en, this message translates to:
  /// **'Conversion Rate'**
  String get bizConversionRate;

  /// Merchant/Influencer text
  ///
  /// In en, this message translates to:
  /// **'Similar Products'**
  String get bizSimilarProducts;

  /// Merchant/Influencer text
  ///
  /// In en, this message translates to:
  /// **'Payment Successful!'**
  String get bizPaymentSuccessful;

  /// Merchant/Influencer text
  ///
  /// In en, this message translates to:
  /// **'Your purchase is now pending admin approval.'**
  String get bizYourPurchaseIsNowPending;

  /// Merchant/Influencer text
  ///
  /// In en, this message translates to:
  /// **'Admin will review and activate your purchase within 24 hours.'**
  String get bizAdminWillReviewAndActivate;

  /// Merchant/Influencer text
  ///
  /// In en, this message translates to:
  /// **'Influencers are coming soon ✨'**
  String get bizInfluencersAreComingSoon;

  /// Merchant/Influencer text
  ///
  /// In en, this message translates to:
  /// **'We\'re bringing local creators and their recommendations to OffrO. Stay tuned!'**
  String get bizWeReBringingLocalCreators;

  /// Merchant/Influencer text
  ///
  /// In en, this message translates to:
  /// **'People shaping the city'**
  String get bizPeopleShapingTheCity;

  /// Merchant/Influencer text
  ///
  /// In en, this message translates to:
  /// **'Local Voices'**
  String get bizLocalVoices;

  /// Merchant/Influencer text
  ///
  /// In en, this message translates to:
  /// **'Please select a star rating first'**
  String get bizPleaseSelectAStarRating;

  /// Merchant/Influencer text
  ///
  /// In en, this message translates to:
  /// **'Please log in to submit a review'**
  String get bizPleaseLogInToSubmit;

  /// Merchant/Influencer text
  ///
  /// In en, this message translates to:
  /// **'Please write at least a few words'**
  String get bizPleaseWriteAtLeastA;

  /// Merchant/Influencer text
  ///
  /// In en, this message translates to:
  /// **'VERIFIED LOCAL VOICE'**
  String get bizVERIFIEDLOCALVOICE;

  /// Merchant/Influencer text
  ///
  /// In en, this message translates to:
  /// **'Rating'**
  String get bizRating;

  /// Merchant/Influencer text
  ///
  /// In en, this message translates to:
  /// **'Rate this influencer'**
  String get bizRateThisInfluencer;

  /// Merchant/Influencer text
  ///
  /// In en, this message translates to:
  /// **'Share your experience (optional)'**
  String get bizShareYourExperienceOptional;

  /// Merchant/Influencer text
  ///
  /// In en, this message translates to:
  /// **'Update Review'**
  String get bizUpdateReview;

  /// Merchant/Influencer text
  ///
  /// In en, this message translates to:
  /// **'Creator account'**
  String get bizCreatorAccount;

  /// Merchant/Influencer text
  ///
  /// In en, this message translates to:
  /// **'CREATOR WORKSPACE'**
  String get bizCREATORWORKSPACE;

  /// Merchant/Influencer text
  ///
  /// In en, this message translates to:
  /// **'Profile views'**
  String get bizProfileViews;

  /// Merchant/Influencer text
  ///
  /// In en, this message translates to:
  /// **'Saved by'**
  String get bizSavedBy;

  /// Merchant/Influencer text
  ///
  /// In en, this message translates to:
  /// **'Your profile is live'**
  String get bizYourProfileIsLive;

  /// Merchant/Influencer text
  ///
  /// In en, this message translates to:
  /// **'Your profile isn\'t live yet'**
  String get bizYourProfileIsnTLive;

  /// Merchant/Influencer text
  ///
  /// In en, this message translates to:
  /// **'Merchants and customers can discover you.'**
  String get bizMerchantsAndCustomersCanDiscover;

  /// Merchant/Influencer text
  ///
  /// In en, this message translates to:
  /// **'Open your profile to review and publish it.'**
  String get bizOpenYourProfileToReview;

  /// Merchant/Influencer text
  ///
  /// In en, this message translates to:
  /// **'MATCHED FOR YOU'**
  String get bizMATCHEDFORYOU;

  /// Merchant/Influencer text
  ///
  /// In en, this message translates to:
  /// **'Campaign opportunities'**
  String get bizCampaignOpportunities;

  /// Merchant/Influencer text
  ///
  /// In en, this message translates to:
  /// **'INFLUENCER WORKSPACE'**
  String get bizINFLUENCERWORKSPACE;

  /// Merchant/Influencer text
  ///
  /// In en, this message translates to:
  /// **'Create your local profile.'**
  String get bizCreateYourLocalProfile;

  /// Merchant/Influencer text
  ///
  /// In en, this message translates to:
  /// **'You\'ll need an Influencer profile to use the Influencer module — it\'s how customers and merchants discover you on OffrO.'**
  String get bizYouLlNeedAnInfluencer;

  /// Merchant/Influencer text
  ///
  /// In en, this message translates to:
  /// **'+ Add influencer profile'**
  String get bizAddInfluencerProfile;

  /// Merchant/Influencer text
  ///
  /// In en, this message translates to:
  /// **'Not added'**
  String get bizNotAdded;

  /// Merchant/Influencer text
  ///
  /// In en, this message translates to:
  /// **'Continue Publishing / Pay Now'**
  String get bizContinuePublishingPayNow;

  /// Merchant/Influencer text
  ///
  /// In en, this message translates to:
  /// **'My profile'**
  String get bizMyProfile;

  /// Merchant/Influencer text
  ///
  /// In en, this message translates to:
  /// **'Business Details'**
  String get bizBusinessDetails;

  /// Merchant/Influencer text
  ///
  /// In en, this message translates to:
  /// **'Display Name'**
  String get bizDisplayName;

  /// Merchant/Influencer text
  ///
  /// In en, this message translates to:
  /// **'Bio'**
  String get bizBio;

  /// Merchant/Influencer text
  ///
  /// In en, this message translates to:
  /// **'Social Pages'**
  String get bizSocialPages;

  /// Merchant/Influencer text
  ///
  /// In en, this message translates to:
  /// **'Primary Specialty'**
  String get bizPrimarySpecialty;

  /// Merchant/Influencer text
  ///
  /// In en, this message translates to:
  /// **'No specialty selected'**
  String get bizNoSpecialtySelected;

  /// Merchant/Influencer text
  ///
  /// In en, this message translates to:
  /// **'Account Details'**
  String get bizAccountDetails;

  /// Merchant/Influencer text
  ///
  /// In en, this message translates to:
  /// **'Disable'**
  String get bizDisable;

  /// Merchant/Influencer text
  ///
  /// In en, this message translates to:
  /// **'Enable'**
  String get bizEnable;

  /// Merchant/Influencer text
  ///
  /// In en, this message translates to:
  /// **'Hide your profile from customers'**
  String get bizHideYourProfileFromCustomers;

  /// Merchant/Influencer text
  ///
  /// In en, this message translates to:
  /// **'Make your profile visible again'**
  String get bizMakeYourProfileVisibleAgain;

  /// Merchant/Influencer text
  ///
  /// In en, this message translates to:
  /// **'Switch to your Customer account'**
  String get bizSwitchToYourCustomerAccount;

  /// Merchant/Influencer text
  ///
  /// In en, this message translates to:
  /// **'Your profile is saved as a draft. Complete the one-time subscription payment from Edit Profile → Save & Publish to make it visible to customers.'**
  String get bizYourProfileIsSavedAs;

  /// Merchant/Influencer text
  ///
  /// In en, this message translates to:
  /// **'Payment is being processed. If you completed a payment and this doesn\'t update, try Save & Publish again.'**
  String get bizPaymentIsBeingProcessedIf;

  /// Merchant/Influencer text
  ///
  /// In en, this message translates to:
  /// **'Your last subscription payment attempt failed. Please try Save & Publish again to complete payment.'**
  String get bizYourLastSubscriptionPaymentAttempt;

  /// Merchant/Influencer text
  ///
  /// In en, this message translates to:
  /// **'Your profile is not yet published.'**
  String get bizYourProfileIsNotYet;

  /// Merchant/Influencer text
  ///
  /// In en, this message translates to:
  /// **'Delete Influencer Profile?'**
  String get bizDeleteInfluencerProfile;

  /// Merchant/Influencer text
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to delete your influencer profile? This action cannot be undone.'**
  String get bizAreYouSureYouWant;

  /// Merchant/Influencer text
  ///
  /// In en, this message translates to:
  /// **'If you create a new influencer profile in the future, a new subscription payment will be required.'**
  String get bizIfYouCreateANew;

  /// Merchant/Influencer text
  ///
  /// In en, this message translates to:
  /// **'Delete Profile'**
  String get bizDeleteProfile;

  /// Merchant/Influencer text
  ///
  /// In en, this message translates to:
  /// **'REVIEWS'**
  String get bizREVIEWS;

  /// Merchant/Influencer text
  ///
  /// In en, this message translates to:
  /// **'Creator reviews'**
  String get bizCreatorReviews;

  /// Merchant/Influencer text
  ///
  /// In en, this message translates to:
  /// **'Name is required'**
  String get bizNameIsRequired;

  /// Merchant/Influencer text
  ///
  /// In en, this message translates to:
  /// **'Please select a state'**
  String get bizPleaseSelectAState;

  /// Merchant/Influencer text
  ///
  /// In en, this message translates to:
  /// **'Please enter a valid 10-digit mobile number.'**
  String get bizPleaseEnterAValid10;

  /// Merchant/Influencer text
  ///
  /// In en, this message translates to:
  /// **'Profile image is required to publish your influencer profile.'**
  String get bizProfileImageIsRequiredTo;

  /// Merchant/Influencer text
  ///
  /// In en, this message translates to:
  /// **'We couldn\'t confirm your payment. If money was deducted, it will be verified shortly — please try Save & Publish again in a moment.'**
  String get bizWeCouldnTConfirmYour;

  /// Merchant/Influencer text
  ///
  /// In en, this message translates to:
  /// **'Creator identity'**
  String get bizCreatorIdentity;

  /// Merchant/Influencer text
  ///
  /// In en, this message translates to:
  /// **'Edit profile'**
  String get bizEditProfile;

  /// Merchant/Influencer text
  ///
  /// In en, this message translates to:
  /// **'Add profile'**
  String get bizAddProfile;

  /// Merchant/Influencer text
  ///
  /// In en, this message translates to:
  /// **'Required to publish'**
  String get bizRequiredToPublish;

  /// Merchant/Influencer text
  ///
  /// In en, this message translates to:
  /// **'Name *'**
  String get bizName;

  /// Merchant/Influencer text
  ///
  /// In en, this message translates to:
  /// **'e.g. Priya Sharma'**
  String get bizEGPriyaSharma;

  /// Merchant/Influencer text
  ///
  /// In en, this message translates to:
  /// **'Sharing the best local food, cafés, shops and great offers around your city.'**
  String get bizSharingTheBestLocalFood;

  /// Merchant/Influencer text
  ///
  /// In en, this message translates to:
  /// **'State *'**
  String get bizState2;

  /// Merchant/Influencer text
  ///
  /// In en, this message translates to:
  /// **'Select state'**
  String get bizSelectState;

  /// Merchant/Influencer text
  ///
  /// In en, this message translates to:
  /// **'City *'**
  String get bizCity2;

  /// Merchant/Influencer text
  ///
  /// In en, this message translates to:
  /// **'Select state first'**
  String get bizSelectStateFirst;

  /// Merchant/Influencer text
  ///
  /// In en, this message translates to:
  /// **'Select city'**
  String get bizSelectCity;

  /// Merchant/Influencer text
  ///
  /// In en, this message translates to:
  /// **'Primary Specialty (select one or more)'**
  String get bizPrimarySpecialtySelectOneOr;

  /// Merchant/Influencer text
  ///
  /// In en, this message translates to:
  /// **'No categories available'**
  String get bizNoCategoriesAvailable;

  /// Merchant/Influencer text
  ///
  /// In en, this message translates to:
  /// **'10-digit mobile number'**
  String get biz10DigitMobileNumber;

  /// Merchant/Influencer text
  ///
  /// In en, this message translates to:
  /// **'Social Links'**
  String get bizSocialLinks;

  /// Merchant/Influencer text
  ///
  /// In en, this message translates to:
  /// **'Instagram URL'**
  String get bizInstagramURL;

  /// Merchant/Influencer text
  ///
  /// In en, this message translates to:
  /// **'YouTube URL'**
  String get bizYouTubeURL;

  /// Merchant/Influencer text
  ///
  /// In en, this message translates to:
  /// **'Facebook URL'**
  String get bizFacebookURL;

  /// Merchant/Influencer text
  ///
  /// In en, this message translates to:
  /// **'Save (keep as draft)'**
  String get bizSaveKeepAsDraft;

  /// Merchant/Influencer text
  ///
  /// In en, this message translates to:
  /// **'Save & Publish'**
  String get bizSavePublish;

  /// Merchant/Influencer text
  ///
  /// In en, this message translates to:
  /// **'Save & Publish (Pay to Publish)'**
  String get bizSavePublishPayToPublish;

  /// Merchant/Influencer text
  ///
  /// In en, this message translates to:
  /// **'No subscription payment is currently required to publish your profile.'**
  String get bizNoSubscriptionPaymentIsCurrently;

  /// Merchant/Influencer text
  ///
  /// In en, this message translates to:
  /// **'Subscription Fee'**
  String get bizSubscriptionFee;

  /// Merchant/Influencer text
  ///
  /// In en, this message translates to:
  /// **'Discount code (optional)'**
  String get bizDiscountCodeOptional;

  /// Merchant/Influencer text
  ///
  /// In en, this message translates to:
  /// **'A one-time payment — you won\'t be charged again for editing or re-publishing this profile.'**
  String get bizAOneTimePaymentYou;

  /// Merchant/Influencer text
  ///
  /// In en, this message translates to:
  /// **'Enter a discount code first'**
  String get bizEnterADiscountCodeFirst;

  /// Merchant/Influencer text
  ///
  /// In en, this message translates to:
  /// **'Select specialties'**
  String get bizSelectSpecialties;

  /// Merchant/Influencer text
  ///
  /// In en, this message translates to:
  /// **'Create brief'**
  String get bizCreateBrief;

  /// Merchant/Influencer text
  ///
  /// In en, this message translates to:
  /// **'Share what you need and where.'**
  String get bizShareWhatYouNeedAnd;

  /// Merchant/Influencer text
  ///
  /// In en, this message translates to:
  /// **'Invite creators'**
  String get bizInviteCreators;

  /// Merchant/Influencer text
  ///
  /// In en, this message translates to:
  /// **'Local creators in your city see it.'**
  String get bizLocalCreatorsInYourCity;

  /// Merchant/Influencer text
  ///
  /// In en, this message translates to:
  /// **'Confirm match'**
  String get bizConfirmMatch;

  /// Merchant/Influencer text
  ///
  /// In en, this message translates to:
  /// **'Review who accepted and connect.'**
  String get bizReviewWhoAcceptedAndConnect;

  /// Merchant/Influencer text
  ///
  /// In en, this message translates to:
  /// **'Creator'**
  String get bizCreator;

  /// Merchant/Influencer text
  ///
  /// In en, this message translates to:
  /// **'Collaborations'**
  String get bizCollaborations;

  /// Merchant/Influencer text
  ///
  /// In en, this message translates to:
  /// **'Work with trusted local creators.'**
  String get bizWorkWithTrustedLocalCreators;

  /// Merchant/Influencer text
  ///
  /// In en, this message translates to:
  /// **'Create one clear campaign brief, review matched creators and confirm a collaboration without managing conversations across multiple apps.'**
  String get bizCreateOneClearCampaignBrief;

  /// Merchant/Influencer text
  ///
  /// In en, this message translates to:
  /// **'How it works'**
  String get bizHowItWorks;

  /// Merchant/Influencer text
  ///
  /// In en, this message translates to:
  /// **'Create campaign brief'**
  String get bizCreateCampaignBrief;

  /// Merchant/Influencer text
  ///
  /// In en, this message translates to:
  /// **'Your campaigns'**
  String get bizYourCampaigns;

  /// Merchant/Influencer text
  ///
  /// In en, this message translates to:
  /// **'Collaboration workspace'**
  String get bizCollaborationWorkspace;

  /// Merchant/Influencer text
  ///
  /// In en, this message translates to:
  /// **'No campaigns yet'**
  String get bizNoCampaignsYet;

  /// Merchant/Influencer text
  ///
  /// In en, this message translates to:
  /// **'Create your first campaign brief to invite local creators.'**
  String get bizCreateYourFirstCampaignBrief;

  /// Merchant/Influencer text
  ///
  /// In en, this message translates to:
  /// **'When should you use this?'**
  String get bizWhenShouldYouUseThis;

  /// Merchant/Influencer text
  ///
  /// In en, this message translates to:
  /// **'Use collaborations for launches, visits and creator content. Regular store updates and discounts belong in Banners or Deals instead.'**
  String get bizUseCollaborationsForLaunchesVisits;

  /// Merchant/Influencer text
  ///
  /// In en, this message translates to:
  /// **'Review proposals'**
  String get bizReviewProposals;

  /// Merchant/Influencer text
  ///
  /// In en, this message translates to:
  /// **'Close campaign?'**
  String get bizCloseCampaign;

  /// Merchant/Influencer text
  ///
  /// In en, this message translates to:
  /// **'Creators will no longer be able to accept this brief.'**
  String get bizCreatorsWillNoLongerBe;

  /// Merchant/Influencer text
  ///
  /// In en, this message translates to:
  /// **'Keep open'**
  String get bizKeepOpen;

  /// Merchant/Influencer text
  ///
  /// In en, this message translates to:
  /// **'Campaign'**
  String get bizCampaign;

  /// Merchant/Influencer text
  ///
  /// In en, this message translates to:
  /// **'Proposals'**
  String get bizProposals;

  /// Merchant/Influencer text
  ///
  /// In en, this message translates to:
  /// **'Creators who accepted'**
  String get bizCreatorsWhoAccepted;

  /// Merchant/Influencer text
  ///
  /// In en, this message translates to:
  /// **'No proposals yet'**
  String get bizNoProposalsYet;

  /// Merchant/Influencer text
  ///
  /// In en, this message translates to:
  /// **'Creators in your city will appear here once they accept your brief.'**
  String get bizCreatorsInYourCityWill;

  /// Merchant/Influencer text
  ///
  /// In en, this message translates to:
  /// **'Closing…'**
  String get bizClosing;

  /// Merchant/Influencer text
  ///
  /// In en, this message translates to:
  /// **'Close campaign'**
  String get bizCloseCampaign2;

  /// Merchant/Influencer text
  ///
  /// In en, this message translates to:
  /// **'Chat on WhatsApp'**
  String get bizChatOnWhatsApp;

  /// Merchant/Influencer text
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t open WhatsApp.'**
  String get bizCouldnTOpenWhatsApp;

  /// Merchant/Influencer text
  ///
  /// In en, this message translates to:
  /// **'Please select a store.'**
  String get bizPleaseSelectAStore2;

  /// Merchant/Influencer text
  ///
  /// In en, this message translates to:
  /// **'Enter a campaign title (at least 3 characters).'**
  String get bizEnterACampaignTitleAt;

  /// Merchant/Influencer text
  ///
  /// In en, this message translates to:
  /// **'Select a campaign objective.'**
  String get bizSelectACampaignObjective;

  /// Merchant/Influencer text
  ///
  /// In en, this message translates to:
  /// **'Describe what the creator should communicate (at least 10 characters).'**
  String get bizDescribeWhatTheCreatorShould;

  /// Merchant/Influencer text
  ///
  /// In en, this message translates to:
  /// **'Select the content you need.'**
  String get bizSelectTheContentYouNeed;

  /// Merchant/Influencer text
  ///
  /// In en, this message translates to:
  /// **'Choose a publish-by date.'**
  String get bizChooseAPublishByDate;

  /// Merchant/Influencer text
  ///
  /// In en, this message translates to:
  /// **'Choose a visit date for the store visit.'**
  String get bizChooseAVisitDateFor;

  /// Merchant/Influencer text
  ///
  /// In en, this message translates to:
  /// **'Visit date can\'t be after the publish-by date.'**
  String get bizVisitDateCanTBe;

  /// Merchant/Influencer text
  ///
  /// In en, this message translates to:
  /// **'Brief published. Matching creators can now see it.'**
  String get bizBriefPublishedMatchingCreatorsCan;

  /// Merchant/Influencer text
  ///
  /// In en, this message translates to:
  /// **'Campaign brief'**
  String get bizCampaignBrief;

  /// Merchant/Influencer text
  ///
  /// In en, this message translates to:
  /// **'Add and activate a store before creating a campaign brief.'**
  String get bizAddAndActivateAStore;

  /// Merchant/Influencer text
  ///
  /// In en, this message translates to:
  /// **'Select store'**
  String get bizSelectStore2;

  /// Merchant/Influencer text
  ///
  /// In en, this message translates to:
  /// **'Campaign title'**
  String get bizCampaignTitle;

  /// Merchant/Influencer text
  ///
  /// In en, this message translates to:
  /// **'Example: Seasonal menu launch'**
  String get bizExampleSeasonalMenuLaunch;

  /// Merchant/Influencer text
  ///
  /// In en, this message translates to:
  /// **'Campaign objective'**
  String get bizCampaignObjective;

  /// Merchant/Influencer text
  ///
  /// In en, this message translates to:
  /// **'Select objective'**
  String get bizSelectObjective;

  /// Merchant/Influencer text
  ///
  /// In en, this message translates to:
  /// **'What should the creator communicate?'**
  String get bizWhatShouldTheCreatorCommunicate;

  /// Merchant/Influencer text
  ///
  /// In en, this message translates to:
  /// **'Key message, experience and details they should know...'**
  String get bizKeyMessageExperienceAndDetails;

  /// Merchant/Influencer text
  ///
  /// In en, this message translates to:
  /// **'Requested content'**
  String get bizRequestedContent;

  /// Merchant/Influencer text
  ///
  /// In en, this message translates to:
  /// **'Visit date'**
  String get bizVisitDate;

  /// Merchant/Influencer text
  ///
  /// In en, this message translates to:
  /// **'Select date'**
  String get bizSelectDate;

  /// Merchant/Influencer text
  ///
  /// In en, this message translates to:
  /// **'Publish by'**
  String get bizPublishBy;

  /// Merchant/Influencer text
  ///
  /// In en, this message translates to:
  /// **'Preferred creator speciality'**
  String get bizPreferredCreatorSpeciality;

  /// Merchant/Influencer text
  ///
  /// In en, this message translates to:
  /// **'Select speciality'**
  String get bizSelectSpeciality;

  /// Merchant/Influencer text
  ///
  /// In en, this message translates to:
  /// **'No payment processing'**
  String get bizNoPaymentProcessing;

  /// Merchant/Influencer text
  ///
  /// In en, this message translates to:
  /// **'OffrO connects you with creators. Any compensation is agreed directly between you and the creator.'**
  String get bizOffrOConnectsYouWithCreators;

  /// Merchant/Influencer text
  ///
  /// In en, this message translates to:
  /// **'Publishing…'**
  String get bizPublishing;

  /// Merchant/Influencer text
  ///
  /// In en, this message translates to:
  /// **'Publish brief'**
  String get bizPublishBrief;

  /// Merchant/Influencer text
  ///
  /// In en, this message translates to:
  /// **'Matched locally'**
  String get bizMatchedLocally;

  /// Merchant/Influencer text
  ///
  /// In en, this message translates to:
  /// **'Review collaboration requests from relevant merchants in your city.'**
  String get bizReviewCollaborationRequestsFromReleva;

  /// Merchant/Influencer text
  ///
  /// In en, this message translates to:
  /// **'No collaboration requests yet'**
  String get bizNoCollaborationRequestsYet;

  /// Merchant/Influencer text
  ///
  /// In en, this message translates to:
  /// **'Requests from merchants in your city will appear here.'**
  String get bizRequestsFromMerchantsInYour;

  /// Merchant/Influencer text
  ///
  /// In en, this message translates to:
  /// **'Accepted'**
  String get bizAccepted;

  /// Merchant/Influencer text
  ///
  /// In en, this message translates to:
  /// **'Declined'**
  String get bizDeclined;

  /// Merchant/Influencer text
  ///
  /// In en, this message translates to:
  /// **'New collaboration request'**
  String get bizNewCollaborationRequest;

  /// Merchant/Influencer text
  ///
  /// In en, this message translates to:
  /// **'View brief'**
  String get bizViewBrief;

  /// Merchant/Influencer text
  ///
  /// In en, this message translates to:
  /// **'No campaign requests yet'**
  String get bizNoCampaignRequestsYet;

  /// Merchant/Influencer text
  ///
  /// In en, this message translates to:
  /// **'New briefs from merchants in your city will appear here.'**
  String get bizNewBriefsFromMerchantsIn;

  /// Merchant/Influencer text
  ///
  /// In en, this message translates to:
  /// **'Collaboration accepted.'**
  String get bizCollaborationAccepted;

  /// Merchant/Influencer text
  ///
  /// In en, this message translates to:
  /// **'Request declined.'**
  String get bizRequestDeclined;

  /// Merchant/Influencer text
  ///
  /// In en, this message translates to:
  /// **'Collaboration request'**
  String get bizCollaborationRequest;

  /// Merchant/Influencer text
  ///
  /// In en, this message translates to:
  /// **'Brief'**
  String get bizBrief;

  /// Merchant/Influencer text
  ///
  /// In en, this message translates to:
  /// **'Complete your profile subscription to accept collaborations.'**
  String get bizCompleteYourProfileSubscriptionTo;

  /// Merchant/Influencer text
  ///
  /// In en, this message translates to:
  /// **'Objective'**
  String get bizObjective;

  /// Merchant/Influencer text
  ///
  /// In en, this message translates to:
  /// **'Message'**
  String get bizMessage;

  /// Merchant/Influencer text
  ///
  /// In en, this message translates to:
  /// **'Preferred speciality'**
  String get bizPreferredSpeciality;

  /// Merchant/Influencer text
  ///
  /// In en, this message translates to:
  /// **'This collaboration is for promotion on your Instagram. There is no in-app chat.'**
  String get bizThisCollaborationIsForPromotion;

  /// Merchant/Influencer text
  ///
  /// In en, this message translates to:
  /// **'You accepted this collaboration'**
  String get bizYouAcceptedThisCollaboration;

  /// Merchant/Influencer text
  ///
  /// In en, this message translates to:
  /// **'The merchant\'s contact number is not available.'**
  String get bizTheMerchantSContactNumber;

  /// Merchant/Influencer text
  ///
  /// In en, this message translates to:
  /// **'Contact the merchant to plan your visit:'**
  String get bizContactTheMerchantToPlan;

  /// Merchant/Influencer text
  ///
  /// In en, this message translates to:
  /// **'This request is no longer open.'**
  String get bizThisRequestIsNoLonger;

  /// Merchant/Influencer text
  ///
  /// In en, this message translates to:
  /// **'Please wait…'**
  String get bizPleaseWait;

  /// Merchant/Influencer text
  ///
  /// In en, this message translates to:
  /// **'Accept collaboration'**
  String get bizAcceptCollaboration;

  /// Merchant/Influencer text
  ///
  /// In en, this message translates to:
  /// **'Decline'**
  String get bizDecline;

  /// Merchant/Influencer text
  ///
  /// In en, this message translates to:
  /// **'{used}/{limit} free slots used'**
  String bizFreeSlotsUsedOf(String used, String limit);

  /// Merchant/Influencer text
  ///
  /// In en, this message translates to:
  /// **'Welcome back, {name}'**
  String bizWelcomeBackName(String name);

  /// Merchant/Influencer text
  ///
  /// In en, this message translates to:
  /// **'✅ Banner submitted! {message}'**
  String bizBannerSubmittedMsg(String message);

  /// Merchant/Influencer text
  ///
  /// In en, this message translates to:
  /// **'If this deal is later removed, the banner opens the store instead.'**
  String get bizBannerFallbackDeal;

  /// Merchant/Influencer text
  ///
  /// In en, this message translates to:
  /// **'If this product is later removed, the banner opens the store instead.'**
  String get bizBannerFallbackProduct;

  /// Merchant/Influencer text
  ///
  /// In en, this message translates to:
  /// **'Payment failed: {error}'**
  String bizPaymentFailedMsg(String error);

  /// Merchant/Influencer text
  ///
  /// In en, this message translates to:
  /// **'Toggle failed: {error}'**
  String bizToggleFailed(String error);

  /// Merchant/Influencer text
  ///
  /// In en, this message translates to:
  /// **'{used} / {limit} free product slots used'**
  String bizFreeProductSlotsUsed(String used, String limit);

  /// Merchant/Influencer text
  ///
  /// In en, this message translates to:
  /// **'Additional products are charged at {price} per day of validity.'**
  String bizAdditionalProductsCharged(String price);

  /// Merchant/Influencer text
  ///
  /// In en, this message translates to:
  /// **'\"{title}\" will be permanently removed and cannot be reactivated. Any payment already made for this product will not be refunded.'**
  String bizDeleteProductBody(String title);

  /// Merchant/Influencer text
  ///
  /// In en, this message translates to:
  /// **'This product'**
  String get bizThisProduct;

  /// Merchant/Influencer text
  ///
  /// In en, this message translates to:
  /// **'Error deleting: {error}'**
  String bizDeleteError(String error);

  /// Merchant/Influencer text
  ///
  /// In en, this message translates to:
  /// **'✅ Code applied — {value}% off!'**
  String bizCodeAppliedPct(String value);

  /// Merchant/Influencer text
  ///
  /// In en, this message translates to:
  /// **'✅ Code applied — {value} off!'**
  String bizCodeAppliedAmt(String value);

  /// Merchant/Influencer text
  ///
  /// In en, this message translates to:
  /// **'Maximum validity is {days} days'**
  String bizMaxValidity(String days);

  /// Merchant/Influencer text
  ///
  /// In en, this message translates to:
  /// **'✅ Product submitted! {message}'**
  String bizProductSubmittedMsg(String message);

  /// Merchant/Influencer text
  ///
  /// In en, this message translates to:
  /// **'Payment error: {error}'**
  String bizPaymentErrorMsg(String error);

  /// Merchant/Influencer text
  ///
  /// In en, this message translates to:
  /// **'Could not open payment. Please try again.'**
  String get bizCouldNotOpenPayment;

  /// Merchant/Influencer text
  ///
  /// In en, this message translates to:
  /// **'Maximum {days} days'**
  String bizMaxDays(String days);

  /// Merchant/Influencer text
  ///
  /// In en, this message translates to:
  /// **'You have {remaining} of {limit} free product slots remaining.'**
  String bizFreeSlotsRemaining(String remaining, String limit);

  /// Merchant/Influencer text
  ///
  /// In en, this message translates to:
  /// **'You have used all {limit} free product slots.\nPrice is {price} per day + GST for the days you choose.'**
  String bizFreeSlotsAllUsed(String limit, String price);

  /// Merchant/Influencer text
  ///
  /// In en, this message translates to:
  /// **'Location updated to {city}'**
  String bizLocationUpdatedTo(String city);

  /// Merchant/Influencer text
  ///
  /// In en, this message translates to:
  /// **'Could not get location: {error}'**
  String bizCouldNotGetLocation(String error);

  /// Merchant/Influencer text
  ///
  /// In en, this message translates to:
  /// **'Location permission is required for current location. Allow it and try again.'**
  String get bizLocationPermissionNeeded;

  /// Merchant/Influencer text
  ///
  /// In en, this message translates to:
  /// **'Please set the store\'s location using \"Use Current Location\" or a Google Maps link before creating the store.'**
  String get bizSetStoreLocationFirst;

  /// Merchant/Influencer text
  ///
  /// In en, this message translates to:
  /// **'The store location looks incomplete. Use \"Use Current Location\" or a Google Maps link to set a valid location.'**
  String get bizStoreLocationIncomplete;

  /// Merchant/Influencer text
  ///
  /// In en, this message translates to:
  /// **'Payment cancelled or failed: {error}'**
  String bizPaymentCancelledOrFailed(String error);

  /// Merchant/Influencer text
  ///
  /// In en, this message translates to:
  /// **'External wallet: {name}'**
  String bizExternalWallet(String name);

  /// Merchant/Influencer text
  ///
  /// In en, this message translates to:
  /// **'✅ {value}% discount applied!'**
  String bizDiscountAppliedPct(String value);

  /// Merchant/Influencer text
  ///
  /// In en, this message translates to:
  /// **'✅ {value} discount applied!'**
  String bizDiscountAppliedAmt(String value);

  /// Merchant/Influencer text
  ///
  /// In en, this message translates to:
  /// **'✅  Your subscription request has been submitted.\n\nPlease pay the amount to your Offro representative.\nThe admin will activate your store once payment is confirmed.'**
  String get bizSubmittedPayRep;

  /// Merchant/Influencer text
  ///
  /// In en, this message translates to:
  /// **'End date cannot exceed store expiry ({date})'**
  String bizEndDateExceedsStore(String date);

  /// Merchant/Influencer text
  ///
  /// In en, this message translates to:
  /// **'Current end date: {date}'**
  String bizCurrentEndDate(String date);

  /// Merchant/Influencer text
  ///
  /// In en, this message translates to:
  /// **'A free product slot is available ({used} of {limit} in use), so this renewal is free.'**
  String bizFreeSlotAvailable(String used, String limit);

  /// Merchant/Influencer text
  ///
  /// In en, this message translates to:
  /// **'You are using all {limit} free product slots. Renewing costs {price} per day added + GST.'**
  String bizAllFreeSlotsUsedRenew(String limit, String price);

  /// Merchant/Influencer text
  ///
  /// In en, this message translates to:
  /// **'{pct}% of viewers visited the store (tapped Sold by)'**
  String bizViewersVisitedStore(String pct);

  /// Merchant/Influencer text
  ///
  /// In en, this message translates to:
  /// **'1 product expiring soon — tap to renew'**
  String get bizProductsExpiringOne;

  /// Merchant/Influencer text
  ///
  /// In en, this message translates to:
  /// **'{n} products expiring soon — tap to renew'**
  String bizProductsExpiringMany(String n);

  /// Merchant/Influencer text
  ///
  /// In en, this message translates to:
  /// **'More from {store}'**
  String bizMoreFromStore(String store);

  /// Merchant/Influencer text
  ///
  /// In en, this message translates to:
  /// **'this store'**
  String get bizThisStore;

  /// Merchant/Influencer text
  ///
  /// In en, this message translates to:
  /// **'Your \"{store}\" purchase is now pending admin approval.'**
  String bizPurchasePendingNamed(String store);

  /// Merchant/Influencer text
  ///
  /// In en, this message translates to:
  /// **'No influencers available in {city} yet'**
  String bizNoInfluencersInCity(String city);

  /// Merchant/Influencer text
  ///
  /// In en, this message translates to:
  /// **'See all ({count})'**
  String bizSeeAllCount(String count);

  /// Merchant/Influencer text
  ///
  /// In en, this message translates to:
  /// **'Reviews for {name}'**
  String bizReviewsFor(String name);

  /// Merchant/Influencer text
  ///
  /// In en, this message translates to:
  /// **'Publish by {date}'**
  String bizPublishByDate(String date);

  /// Merchant/Influencer text
  ///
  /// In en, this message translates to:
  /// **'See all {count} requests'**
  String bizSeeAllRequests(String count);

  /// Merchant/Influencer text
  ///
  /// In en, this message translates to:
  /// **'You declined this request. You can still accept it while it is open.'**
  String get bizDeclinedCanAccept;

  /// Merchant/Influencer text
  ///
  /// In en, this message translates to:
  /// **'You declined this request.'**
  String get bizDeclinedRequest;

  /// Merchant/Influencer text
  ///
  /// In en, this message translates to:
  /// **'Payment could not be completed. Please try again.'**
  String get errPayNoMessage;

  /// Merchant/Influencer text
  ///
  /// In en, this message translates to:
  /// **'We couldn\'t complete your payment. Please try again.'**
  String get errPayGeneric;

  /// Merchant/Influencer text
  ///
  /// In en, this message translates to:
  /// **'1 Store • {active} Active'**
  String bizStoresActiveOne(String active);

  /// Merchant/Influencer text
  ///
  /// In en, this message translates to:
  /// **'{count} Stores • {active} Active'**
  String bizStoresActiveMany(String count, String active);

  /// Merchant/Influencer text
  ///
  /// In en, this message translates to:
  /// **'{n} Live'**
  String bizNLive(String n);

  /// Merchant/Influencer text
  ///
  /// In en, this message translates to:
  /// **'{n} Pending'**
  String bizNPending(String n);

  /// Merchant/Influencer text
  ///
  /// In en, this message translates to:
  /// **'Submitted'**
  String get bizSubmittedWord;

  /// Merchant/Influencer text
  ///
  /// In en, this message translates to:
  /// **'1 Banner • {status}'**
  String bizBannersStatusOne(String status);

  /// Merchant/Influencer text
  ///
  /// In en, this message translates to:
  /// **'{count} Banners • {status}'**
  String bizBannersStatusMany(String count, String status);

  /// Merchant/Influencer text
  ///
  /// In en, this message translates to:
  /// **'{n} Days'**
  String bizNDays(String n);

  /// Merchant/Influencer text
  ///
  /// In en, this message translates to:
  /// **'Start: {from}   →   End: {end}'**
  String bizStartEndRange(String from, String end);

  /// Merchant/Influencer text
  ///
  /// In en, this message translates to:
  /// **'From: {date}'**
  String bizFromDateLabel(String date);

  /// Merchant/Influencer text
  ///
  /// In en, this message translates to:
  /// **'Until: {date}'**
  String bizUntilDateLabel(String date);

  /// Merchant/Influencer text
  ///
  /// In en, this message translates to:
  /// **'Invoice: {no}'**
  String bizInvoiceColon(String no);

  /// Merchant/Influencer text
  ///
  /// In en, this message translates to:
  /// **'{amount}/day'**
  String bizPerDayPrice(String amount);

  /// Merchant/Influencer text
  ///
  /// In en, this message translates to:
  /// **'GST ({pct}%)'**
  String bizGstPct(String pct);

  /// Merchant/Influencer text
  ///
  /// In en, this message translates to:
  /// **'Pay {amount}'**
  String bizPayAmount(String amount);

  /// Merchant/Influencer text
  ///
  /// In en, this message translates to:
  /// **'{price}/day × {days} days'**
  String bizPricePerDayTimesDays(String price, String days);

  /// Merchant/Influencer text
  ///
  /// In en, this message translates to:
  /// **'−{amount} ({pct}%) off  →  Total: {total}'**
  String bizDiscountTotalPct(String amount, String pct, String total);

  /// Merchant/Influencer text
  ///
  /// In en, this message translates to:
  /// **'−{amount} off  →  Total: {total}'**
  String bizDiscountTotalAmt(String amount, String total);

  /// Merchant/Influencer text
  ///
  /// In en, this message translates to:
  /// **'1 result'**
  String get bizResultOne;

  /// Merchant/Influencer text
  ///
  /// In en, this message translates to:
  /// **'{n} results'**
  String bizResultMany(String n);

  /// Merchant/Influencer text
  ///
  /// In en, this message translates to:
  /// **'Expired {date}'**
  String bizExpiredOn(String date);

  /// Merchant/Influencer text
  ///
  /// In en, this message translates to:
  /// **'Expires {date}'**
  String bizExpiresOn(String date);

  /// Merchant/Influencer text
  ///
  /// In en, this message translates to:
  /// **'Error: {error}'**
  String bizErrorColon(String error);

  /// Merchant/Influencer text
  ///
  /// In en, this message translates to:
  /// **'{days} day × {price}/day'**
  String bizDayTimesPriceOne(String days, String price);

  /// Merchant/Influencer text
  ///
  /// In en, this message translates to:
  /// **'{days} days × {price}/day'**
  String bizDayTimesPriceMany(String days, String price);

  /// Merchant/Influencer text
  ///
  /// In en, this message translates to:
  /// **'Failed: {error}'**
  String bizFailedColon(String error);

  /// Merchant/Influencer text
  ///
  /// In en, this message translates to:
  /// **'1 Deal'**
  String get bizDealCountOne;

  /// Merchant/Influencer text
  ///
  /// In en, this message translates to:
  /// **'{n} Deals'**
  String bizDealCountMany(String n);

  /// Merchant/Influencer text
  ///
  /// In en, this message translates to:
  /// **'{price} + {pct}% {tax}'**
  String bizPricePlusGst(String price, String pct, String tax);

  /// Merchant/Influencer text
  ///
  /// In en, this message translates to:
  /// **'Plan: {plan}  •  {from} – {end}'**
  String bizPlanPeriodLine(String plan, String from, String end);

  /// Merchant/Influencer text
  ///
  /// In en, this message translates to:
  /// **'Base: {base}  {tax}: {gst}'**
  String bizBaseGstLine(String base, String gst, String tax);

  /// Merchant/Influencer text
  ///
  /// In en, this message translates to:
  /// **'Discount ({code}): −{amount}'**
  String bizDiscountCodeLine(String code, String amount);

  /// Merchant/Influencer text
  ///
  /// In en, this message translates to:
  /// **'Banner: {title}'**
  String bizBannerTitleLine(String title);

  /// Merchant/Influencer text
  ///
  /// In en, this message translates to:
  /// **'Product: {title}'**
  String bizProductTitleLine(String title);

  /// Merchant/Influencer text
  ///
  /// In en, this message translates to:
  /// **'Untitled'**
  String get bizUntitledWord;

  /// Merchant/Influencer text
  ///
  /// In en, this message translates to:
  /// **'Ends {date}'**
  String bizEndsOn(String date);

  /// Merchant/Influencer text
  ///
  /// In en, this message translates to:
  /// **'Delete \"{title}\"?'**
  String bizDeleteDealNamed(String title);

  /// Merchant/Influencer text
  ///
  /// In en, this message translates to:
  /// **'Max: {date}'**
  String bizMaxDateLine(String date);

  /// Merchant/Influencer text
  ///
  /// In en, this message translates to:
  /// **'Renew · {amount}'**
  String bizRenewAmount(String amount);

  /// Merchant/Influencer text
  ///
  /// In en, this message translates to:
  /// **'Code \'{code}\' applied'**
  String bizCodeAppliedNamed(String code);

  /// Merchant/Influencer text
  ///
  /// In en, this message translates to:
  /// **'{n} active'**
  String bizNActive(String n);

  /// Merchant/Influencer text
  ///
  /// In en, this message translates to:
  /// **'Visit {date}'**
  String bizVisitOn(String date);

  /// Merchant/Influencer text
  ///
  /// In en, this message translates to:
  /// **'Call {phone}'**
  String bizCallPhone(String phone);

  /// Merchant/Influencer text
  ///
  /// In en, this message translates to:
  /// **'All Products'**
  String get bizAllProducts;

  /// Merchant/Influencer text
  ///
  /// In en, this message translates to:
  /// **'All Stores'**
  String get bizAllStores;

  /// Merchant/Influencer text
  ///
  /// In en, this message translates to:
  /// **'Banners'**
  String get bizBannersTab;

  /// Merchant/Influencer text
  ///
  /// In en, this message translates to:
  /// **'Payments'**
  String get bizPaymentsTab;

  /// Merchant/Influencer text
  ///
  /// In en, this message translates to:
  /// **'Additional product'**
  String get bizAdditionalProduct;

  /// Merchant/Influencer text
  ///
  /// In en, this message translates to:
  /// **'Billing & subscriptions'**
  String get bizBillingSubscriptions;

  /// Merchant/Influencer text
  ///
  /// In en, this message translates to:
  /// **'Till: {date}'**
  String bizTillDate(String date);

  /// Merchant/Influencer text
  ///
  /// In en, this message translates to:
  /// **'Exp: {date}'**
  String bizExpDate(String date);

  /// Merchant/Influencer text
  ///
  /// In en, this message translates to:
  /// **'1 day'**
  String get bizOneDayWord;

  /// Merchant/Influencer text
  ///
  /// In en, this message translates to:
  /// **'{n} days'**
  String bizDaysCountWord(String n);

  /// Merchant/Influencer text
  ///
  /// In en, this message translates to:
  /// **'1 proposal'**
  String get bizProposalOne;

  /// Merchant/Influencer text
  ///
  /// In en, this message translates to:
  /// **'{n} proposals'**
  String bizProposalMany(String n);

  /// Merchant/Influencer text
  ///
  /// In en, this message translates to:
  /// **'Influencer Subscription'**
  String get bizInfluencerSubscription;

  /// Merchant/Influencer text
  ///
  /// In en, this message translates to:
  /// **'OffrO Influencer'**
  String get bizOffrOInfluencer;

  /// OTP screen: shown when fewer than 4 digits were entered
  ///
  /// In en, this message translates to:
  /// **'Enter 4-digit OTP'**
  String get authEnterOtp4;

  /// OTP screen: wrong code (used when the server gives no message)
  ///
  /// In en, this message translates to:
  /// **'Incorrect OTP. Please try again.'**
  String get authOtpIncorrect;

  /// OTP screen: verification failed for a technical reason
  ///
  /// In en, this message translates to:
  /// **'Unable to verify OTP right now. Please try again.'**
  String get authOtpVerifyFailed;

  /// OTP screen: the code was sent by SMS instead
  ///
  /// In en, this message translates to:
  /// **'Code sent by SMS.'**
  String get authCodeSentSms;

  /// OTP screen: code sent again
  ///
  /// In en, this message translates to:
  /// **'OTP resent successfully.'**
  String get authOtpResent;

  /// OTP screen: resend failed (no server message)
  ///
  /// In en, this message translates to:
  /// **'Resend failed.'**
  String get authResendFailed;

  /// OTP screen: resend failed for a technical reason
  ///
  /// In en, this message translates to:
  /// **'Unable to resend OTP right now. Please try again.'**
  String get authOtpResendFailed;

  /// Shown while the account is prepared after login
  ///
  /// In en, this message translates to:
  /// **'Setting up your account...'**
  String get authSettingUpAccount;

  /// Merchant login splash; {dots} is an animated '...' that must stay at the end
  ///
  /// In en, this message translates to:
  /// **'Preparing your business dashboard{dots}'**
  String authPreparingDashboard(String dots);

  /// Merchant login splash, second line
  ///
  /// In en, this message translates to:
  /// **'Loading stores, products and activity...'**
  String get authLoadingBusinessData;

  /// Registration: name missing
  ///
  /// In en, this message translates to:
  /// **'Enter your name'**
  String get authEnterYourName;

  /// Registration: the consent checkbox is not ticked
  ///
  /// In en, this message translates to:
  /// **'Please tick the box to accept the Terms & Conditions and Privacy Policy and consent to WhatsApp updates from OffrO, to continue'**
  String get authAcceptTermsRequired;

  /// Registration: number already has an account
  ///
  /// In en, this message translates to:
  /// **'This number is already registered. Please login.'**
  String get authAlreadyRegistered;

  /// Login: number has no account
  ///
  /// In en, this message translates to:
  /// **'Number not registered. Please register first.'**
  String get authNotRegistered;

  /// Login: the code could not be sent
  ///
  /// In en, this message translates to:
  /// **'Unable to send OTP right now. Please try again.'**
  String get authOtpSendFailed;

  /// Login: generic failure
  ///
  /// In en, this message translates to:
  /// **'Login failed — please try again.'**
  String get authLoginFailed;

  /// Consent line, start: 'I agree to the [Terms & Conditions] and [Privacy Policy] and consent ...' (spaces are added in code)
  ///
  /// In en, this message translates to:
  /// **'I agree to the'**
  String get authAgreeTo;

  /// Consent line, joins the two links
  ///
  /// In en, this message translates to:
  /// **'and'**
  String get authAnd;

  /// Consent line, end
  ///
  /// In en, this message translates to:
  /// **'and consent to receive updates and promotional messages from OffrO via WhatsApp.'**
  String get authConsentWhatsApp;

  /// Merchant terms dialog title
  ///
  /// In en, this message translates to:
  /// **'Merchant Terms & Conditions'**
  String get authMerchantTermsTitle;

  /// Merchant terms dialog: shown while the server has no text
  ///
  /// In en, this message translates to:
  /// **'Merchant terms and conditions will be posted here.'**
  String get authMerchantTermsEmpty;

  /// Merchant terms dialog checkbox
  ///
  /// In en, this message translates to:
  /// **'I agree to the Merchant Terms'**
  String get authAgreeMerchantTerms;

  /// Merchant terms dialog button
  ///
  /// In en, this message translates to:
  /// **'Accept & Continue'**
  String get authAcceptContinue;

  /// Phone field validation
  ///
  /// In en, this message translates to:
  /// **'Enter your mobile number'**
  String get phoneEnterNumber;

  /// Phone field validation for India
  ///
  /// In en, this message translates to:
  /// **'Enter a valid 10-digit mobile number'**
  String get phoneInvalid10;

  /// Phone field validation; {country} is the country name
  ///
  /// In en, this message translates to:
  /// **'Enter a valid {country} mobile number'**
  String phoneInvalidCountry(String country);

  /// Country name in the country picker
  ///
  /// In en, this message translates to:
  /// **'India'**
  String get countryNameIN;

  /// Country name in the country picker
  ///
  /// In en, this message translates to:
  /// **'Jordan'**
  String get countryNameJO;

  /// Country name in the country picker
  ///
  /// In en, this message translates to:
  /// **'Nepal'**
  String get countryNameNP;

  /// Country name in the country picker
  ///
  /// In en, this message translates to:
  /// **'Philippines'**
  String get countryNamePH;

  /// Country name in the country picker
  ///
  /// In en, this message translates to:
  /// **'Saudi Arabia'**
  String get countryNameSA;

  /// Location gate title
  ///
  /// In en, this message translates to:
  /// **'Allow location access'**
  String get locGateTitle;

  /// Location gate explanation
  ///
  /// In en, this message translates to:
  /// **'OffrO needs your location to show nearby and relevant content.'**
  String get locGateBody;

  /// Location gate: permission blocked for good
  ///
  /// In en, this message translates to:
  /// **'Location permission is turned off for OffrO. You can allow it in app settings, or choose your city manually.'**
  String get locGateBlockedMsg;

  /// Location gate: device location is off
  ///
  /// In en, this message translates to:
  /// **'Your device\'s location services are off. Turn them on, or choose your city manually.'**
  String get locGateServiceOffMsg;

  /// Location gate: permission not allowed
  ///
  /// In en, this message translates to:
  /// **'Location permission wasn\'t allowed. You can still choose your city manually.'**
  String get locGateDeniedMsg;

  /// Location gate button
  ///
  /// In en, this message translates to:
  /// **'Open app settings'**
  String get locGateOpenSettings;

  /// Location gate main button
  ///
  /// In en, this message translates to:
  /// **'Allow location'**
  String get locGateAllow;

  /// Location gate secondary button
  ///
  /// In en, this message translates to:
  /// **'Choose city manually'**
  String get locGateChooseManually;

  /// Location card title while checking
  ///
  /// In en, this message translates to:
  /// **'Checking location…'**
  String get locCardChecking;

  /// Location card title
  ///
  /// In en, this message translates to:
  /// **'Location services are off'**
  String get locCardServicesOff;

  /// Location card subtitle
  ///
  /// In en, this message translates to:
  /// **'Turn on your device location to see places near you'**
  String get locCardServicesOffSub;

  /// Location card title
  ///
  /// In en, this message translates to:
  /// **'Enable location permissions'**
  String get locCardEnablePerm;

  /// Location card subtitle
  ///
  /// In en, this message translates to:
  /// **'for more relevant suggestions near you'**
  String get locCardEnablePermSub;

  /// Location card title
  ///
  /// In en, this message translates to:
  /// **'Location permission is blocked'**
  String get locCardBlocked;

  /// Location card subtitle
  ///
  /// In en, this message translates to:
  /// **'Allow location for OffrO in app settings'**
  String get locCardBlockedSub;

  /// Location card subtitle while detecting
  ///
  /// In en, this message translates to:
  /// **'Detecting your location…'**
  String get locCardDetecting;

  /// Location card: {error} is a message, then a retry hint
  ///
  /// In en, this message translates to:
  /// **'{error} Tap to retry.'**
  String locCardTapRetry(String error);

  /// Tagline under the logo
  ///
  /// In en, this message translates to:
  /// **'Discover · Save · Earn'**
  String get splashTagline;

  /// Accessible label of the back button
  ///
  /// In en, this message translates to:
  /// **'Back'**
  String get commonBack;

  /// Default title of the shared error state
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t load this'**
  String get stateErrorTitle;

  /// Default message of the shared error state
  ///
  /// In en, this message translates to:
  /// **'Check your connection and try again.'**
  String get stateErrorMessage;

  /// Developer notification diagnostics screens: app bar title
  ///
  /// In en, this message translates to:
  /// **'Notification Diagnostics'**
  String get notifDiagTitle;

  /// Developer notification log: heading of the FCM registration status panel
  ///
  /// In en, this message translates to:
  /// **'FCM Registration Status'**
  String get notifDiagRegStatusTitle;

  /// Developer notification diagnostics: copy button
  ///
  /// In en, this message translates to:
  /// **'Copy'**
  String get notifDiagCopy;

  /// Developer notification log: button that re-runs the registration check
  ///
  /// In en, this message translates to:
  /// **'Re-check'**
  String get notifDiagRecheck;

  /// Developer notification log: snackbar after copying the FCM token
  ///
  /// In en, this message translates to:
  /// **'FCM token copied'**
  String get notifDiagTokenCopied;

  /// Developer notification diagnostics: snackbar after copying the report
  ///
  /// In en, this message translates to:
  /// **'Diagnostics copied to clipboard'**
  String get notifDiagCopiedToClipboard;

  /// Developer notification log: clear button and dialog confirm action
  ///
  /// In en, this message translates to:
  /// **'Clear'**
  String get notifDiagClear;

  /// Developer notification log: clear confirmation dialog title
  ///
  /// In en, this message translates to:
  /// **'Clear Log?'**
  String get notifDiagClearLogTitle;

  /// Developer notification log: clear confirmation dialog body
  ///
  /// In en, this message translates to:
  /// **'This will remove all notification event entries.'**
  String get notifDiagClearLogBody;

  /// Developer notification log: empty state title
  ///
  /// In en, this message translates to:
  /// **'No events logged yet'**
  String get notifDiagEmptyTitle;

  /// Developer notification log: empty state hint (contains a line break)
  ///
  /// In en, this message translates to:
  /// **'Send a notification and check back\nto see which handlers fired'**
  String get notifDiagEmptyHint;

  /// Developer notification diagnostics: refresh button
  ///
  /// In en, this message translates to:
  /// **'Refresh'**
  String get notifDiagRefresh;

  /// Developer notification diagnostics: refresh button label while running
  ///
  /// In en, this message translates to:
  /// **'Checking...'**
  String get notifDiagChecking;

  /// Developer notification log: relative time under one minute; {n} is a whole number of seconds
  ///
  /// In en, this message translates to:
  /// **'{n}s ago'**
  String notifDiagSecondsAgo(String n);
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
