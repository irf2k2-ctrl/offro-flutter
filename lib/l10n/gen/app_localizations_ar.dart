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

  @override
  String get navHome => 'الرئيسية';

  @override
  String get navExplore => 'استكشف';

  @override
  String get navDeals => 'العروض';

  @override
  String get navRewards => 'المكافآت';

  @override
  String get navProfile => 'الملف الشخصي';

  @override
  String get navInvoices => 'الفواتير';

  @override
  String get navActivity => 'النشاط';

  @override
  String get navOpportunities => 'الفرص';

  @override
  String get homeExploring => 'تستكشف';

  @override
  String get homeSelectLocation => 'اختر الموقع';

  @override
  String get homeSearchHint => 'ابحث عن متاجر أو منتجات أو خدمات';

  @override
  String get homeViewArrow => 'عرض ←';

  @override
  String get homeHeroBadge => 'عروض ومتاجر محلية';

  @override
  String get homeExploreLead => 'استكشف';

  @override
  String get homeHeroSubtitle =>
      'اكتشف المتاجر والعروض والأماكن المحلية المفضلة';

  @override
  String get homeDiscoverStores => 'اكتشف المتاجر';

  @override
  String get homeYourCity => 'مدينتك';

  @override
  String get homeDealEndsToday => 'ينتهي اليوم';

  @override
  String get homeDealOneDayLeft => 'يتبقى يوم واحد';

  @override
  String homeDealDaysLeft(String days) {
    return 'يتبقى $days أيام';
  }

  @override
  String get homeExclusiveEyebrow => 'مخصص لأعضاء OffrO';

  @override
  String get homeExclusiveTitle => 'عروض حصرية';

  @override
  String get homeViewAll => 'عرض الكل';

  @override
  String get homeDealOffer => 'عرض';

  @override
  String homePercentOff(String percent) {
    return 'خصم $percent%';
  }

  @override
  String get homeRewardsBadge => 'مكافآت OffrO';

  @override
  String get homePointsSuffix => 'نقطة';

  @override
  String get homeRewardsTapToView => 'اضغط لعرض مكافآتك واستبدالها';

  @override
  String get homeRewardsEarnHint => 'زر المتاجر لتبدأ بكسب النقاط';

  @override
  String get homeCategoriesEyebrow => 'اعثر على ما تحتاجه';

  @override
  String get homeCategoriesTitle => 'استكشف الفئات';

  @override
  String get homeSeeAll => 'عرض الكل';

  @override
  String get homeSeeAllLower => 'عرض الكل';

  @override
  String get catBakery => 'المخابز';

  @override
  String get catAutomobile => 'السيارات';

  @override
  String get catRestaurant => 'المطاعم';

  @override
  String get catGrocery => 'البقالة';

  @override
  String get homeProductsEyebrow => 'من المتاجر المحلية';

  @override
  String get homeProductsTitle => 'منتجات بالقرب منك';

  @override
  String get homeBrowseAll => 'تصفّح الكل';

  @override
  String homeFavoriteSaveFailed(String error) {
    return 'تعذّر حفظ المفضلة: $error';
  }

  @override
  String get homeNearbyEyebrow => 'حول حيّك';

  @override
  String get homeStoresNearTitle => 'متاجر بالقرب منك';

  @override
  String get homeNearbyStoresTitle => 'المتاجر القريبة';

  @override
  String get homeBadgeNew => 'جديد';

  @override
  String homeOfferInline(String offer) {
    return 'عرض · $offer';
  }

  @override
  String get homeOpenNow => 'مفتوح الآن';

  @override
  String get homeClosed => 'مغلق';

  @override
  String get homeDistanceAny => 'أي مسافة';

  @override
  String homeDistanceUnder(String km) {
    return 'أقل من $km كم';
  }

  @override
  String homeNoStoresWithin(String km) {
    return 'لا توجد متاجر ضمن $km كم';
  }

  @override
  String get homeTryLargerRadius => 'جرّب نطاقًا أوسع أو اضغط على «أي مسافة»';

  @override
  String get homeExploreAreasTitle => 'استكشف المناطق';

  @override
  String get homeExploreAreasSubtitle => 'اكتشف أماكن رائعة بالقرب منك';

  @override
  String get homeViewAllArrow => 'عرض الكل ←';

  @override
  String get homeStoreWord => 'متجر';

  @override
  String get homeFeatureRewards => 'مكافآتي';

  @override
  String get homeBackToHome => 'العودة إلى الرئيسية';

  @override
  String get homeContactSupport => 'التواصل مع الدعم';

  @override
  String get homeNoInternet => 'لا يوجد اتصال بالإنترنت';

  @override
  String get homeCheckConnection => 'تحقق من اتصالك وحاول مرة أخرى';

  @override
  String get homeServerSlow => 'الخادم يستغرق وقتًا طويلًا';

  @override
  String get homeColdStart =>
      'بدء التشغيل بطيء — يرجى الانتظار لحظة ثم إعادة المحاولة';

  @override
  String get homeCouldntLoadStores => 'تعذّر تحميل المتاجر';

  @override
  String get homePleaseTryAgain => 'يرجى المحاولة مرة أخرى';

  @override
  String get homeCouldntLoadPage => 'تعذّر تحميل هذه الصفحة';

  @override
  String get commonRetry => 'إعادة المحاولة';

  @override
  String get commonTryAgain => 'حاول مرة أخرى';

  @override
  String get homePromoTitle => 'لافتات مميزة';

  @override
  String get homePromoSubtitle => 'أحدث العروض من متاجرنا';

  @override
  String get timeAm => 'ص';

  @override
  String get timePm => 'م';

  @override
  String storeClosesAt(String time) {
    return 'يغلق $time';
  }

  @override
  String storeOpensAt(String time) {
    return 'يفتح $time';
  }

  @override
  String get badgeJustOpened => 'افتُتح للتو';

  @override
  String get badgeNewlyAdded => 'أُضيف حديثًا';

  @override
  String get badgeNewlyOpened => 'افتُتح حديثًا';

  @override
  String get badgeTrending => 'رائج';

  @override
  String get badgePopular => 'شائع';

  @override
  String get badgeTopRated => 'الأعلى تقييمًا';

  @override
  String get badgeMustVisit => 'يجب زيارته';

  @override
  String get badgeLimitedOffer => 'عرض محدود';

  @override
  String get homeLoginRequiredTitle => 'تسجيل الدخول مطلوب';

  @override
  String homeLoginRequiredBody(String feature) {
    return 'يرجى تسجيل الدخول أو إنشاء حساب لاستخدام $feature.';
  }

  @override
  String get homeLoginRegister => 'تسجيل الدخول / إنشاء حساب';

  @override
  String get homeMaybeLater => 'ربما لاحقًا';

  @override
  String get homeUnableToConnect =>
      'تعذّر الاتصال. يرجى التحقق من اتصالك بالإنترنت والمحاولة مرة أخرى.';

  @override
  String get homeRefreshFailed =>
      'تعذّر تحديث المتاجر. يرجى المحاولة مرة أخرى.';
}
