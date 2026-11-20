// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Arabic (`ar`).
class AppLocalizationsAr extends AppLocalizations {
  AppLocalizationsAr([String locale = 'ar']) : super(locale);

  @override
  String get otpEyebrow => 'التحقق';

  @override
  String get otpTitleLead => 'تحقق من';

  @override
  String get otpTitleAccent => 'رقمك';

  @override
  String otpSentTo(String phone) {
    return 'أرسلنا رمزًا من 4 أرقام إلى\n$phone';
  }

  @override
  String get otpVerifyButton => 'تحقق من الرمز';

  @override
  String get otpDidntReceive => 'لم يصلك الرمز؟';

  @override
  String otpResendIn(String seconds) {
    return 'إعادة الإرسال خلال $seconds ث';
  }

  @override
  String get otpResendAction => 'إعادة إرسال الرمز';

  @override
  String get otpSmsFallback => 'إرسال الرمز برسالة نصية بدلاً من ذلك';

  @override
  String get roleEyebrow => 'اجعل OffrO لك';

  @override
  String get roleTitleLead => 'كيف ستستخدم';

  @override
  String get roleTitleBrand => 'OffrO؟';

  @override
  String get roleSubtitle =>
      'اختر مساحة البداية. يمكنك إضافة دور آخر لاحقًا من ملفك الشخصي.';

  @override
  String get roleCustomer => 'عميل';

  @override
  String get roleCustomerDesc => 'اكتشف الأماكن والمنتجات والعروض المحلية';

  @override
  String get roleMerchant => 'تاجر';

  @override
  String get roleMerchantDesc => 'نمِّ عملك وأدر متجرك';

  @override
  String get roleInfluencer => 'مؤثر';

  @override
  String get roleInfluencerDesc =>
      'أنشئ قصصًا محلية وتعاون مع العلامات التجارية';

  @override
  String get roleRemember => 'تذكّر اختياري';

  @override
  String get roleRememberHint => 'يمكنك تغيير ذلك في أي وقت من الملف الشخصي';

  @override
  String get roleEnterCustomer => 'الدخول كعميل';

  @override
  String get roleEnterMerchant => 'الدخول كتاجر';

  @override
  String get roleEnterInfluencer => 'الدخول كمؤثر';

  @override
  String get roleSelectPrompt => 'اختر دورًا للمتابعة';

  @override
  String get switchTitleLead => 'بدّل';

  @override
  String get switchTitleAccent => 'الوضع';

  @override
  String switchCurrently(String mode) {
    return 'أنت حاليًا في وضع $mode';
  }

  @override
  String get switchCustomerSubtitle => 'تصفّح المتاجر والمنتجات والعروض';

  @override
  String get switchMerchantSubtitle => 'أدر المتجر والمنتجات واللافتات';

  @override
  String get switchInfluencerSubtitle => 'أدر ملفك كمؤثر';

  @override
  String get loginBadge => 'المحلي، بكل سهولة';

  @override
  String get loginWelcomeEyebrow => 'مرحبًا بك في حيّك';

  @override
  String get loginHeroLead => 'اكتشف المزيد مما';

  @override
  String get loginHeroAccent => 'تحب';

  @override
  String get loginHeroTail => '، بالقرب منك.';

  @override
  String get loginHeroBody =>
      'متاجر محلية وعروض مميزة وأشخاص يستحقون الاكتشاف، كل ذلك في مكان واحد.';

  @override
  String get loginTabLogin => 'تسجيل الدخول';

  @override
  String get loginTabRegister => 'إنشاء حساب';

  @override
  String get loginYourName => 'اسمك';

  @override
  String get loginNameHint => 'أدخل اسمك الكامل';

  @override
  String get loginMobile => 'رقم الجوال';

  @override
  String get loginGetCode => 'احصل على رمز التحقق';

  @override
  String get loginRegisterGetCode => 'سجّل واحصل على رمز التحقق';

  @override
  String get loginOr => 'أو';

  @override
  String get loginGuest => 'المتابعة كضيف';

  @override
  String get loginFollow => 'تابع قصتنا المحلية';

  @override
  String get onboardingSkip => 'تخطي';

  @override
  String get onboardingSlide1Title => 'اكتشف العروض المحلية';

  @override
  String get onboardingSlide1Subtitle =>
      'اعثر على أفضل العروض من المتاجر القريبة منك';

  @override
  String get onboardingSlide2Title => 'اكسب نقاط المكافآت';

  @override
  String get onboardingSlide2Subtitle =>
      'كل زيارة تمنحك نقاطًا يمكنك استبدالها';

  @override
  String get onboardingSlide3Title => 'احصل على قسائم الهدايا';

  @override
  String get onboardingSlide3Subtitle => 'استبدل نقاطك بقسائم Amazon وFlipkart';

  @override
  String get countryPickerTitle => 'اختر الدولة';

  @override
  String get profileGroupActivity => 'نشاطي';

  @override
  String get profileGroupAccount => 'الحساب';

  @override
  String get profileGroupLanguage => 'اللغة';

  @override
  String get profileGroupLegal => 'حول التطبيق والقانونية';

  @override
  String get profileGroupSession => 'الجلسة';

  @override
  String get profileGuestBadge => 'تتصفح كضيف';

  @override
  String get profileMemberBadge => 'عضو في OffrO';

  @override
  String get languageRowLabel => 'لغة التطبيق';

  @override
  String get languageSheetTitle => 'اختر اللغة';

  @override
  String get languageSheetNote =>
      'يبقى التطبيق بالإنجليزية حتى تختار لغة أخرى.';

  @override
  String get languageNameEn => 'English';

  @override
  String get languageNameAr => 'العربية';

  @override
  String get languageButtonSemantics => 'تغيير اللغة';

  @override
  String get profileEyebrow => 'OffrO الخاص بك';

  @override
  String get profileTitle => 'الملف الشخصي';

  @override
  String get profileStatSaved => 'المحفوظات';

  @override
  String get profileStatPoints => 'النقاط';
}
