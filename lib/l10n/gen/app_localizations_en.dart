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
}
