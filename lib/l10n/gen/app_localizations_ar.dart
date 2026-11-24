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
  String get onboardingSlide3Subtitle => 'استبدل نقاطك بقسائم هدايا';

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

  @override
  String get profileFavourites => 'مفضلاتي';

  @override
  String get profileFavouritesNote => 'المتاجر التي حفظتها';

  @override
  String get profileRewardsNote => 'نقاط المكافآت والقسائم';

  @override
  String get profileScanHistory => 'سجل المسح';

  @override
  String get profileScanHistoryNote => 'النقاط المكتسبة في المتاجر';

  @override
  String get profileNotifications => 'الإشعارات';

  @override
  String get profileNotificationsNote => 'العروض والمكافآت وتحديثات الحساب';

  @override
  String get profileSwitchMode => 'تبديل الوضع';

  @override
  String get profileSwitchModeNote => 'التبديل بين المستخدم والتاجر';

  @override
  String get profileContact => 'تواصل مع Offro';

  @override
  String get profileContactNote => 'تحدث معنا عبر واتساب';

  @override
  String get profileAboutUs => 'من نحن';

  @override
  String get profileAboutFallback =>
      'تربط Offro المتاجر المحلية بالعملاء من خلال العروض ونقاط الولاء.';

  @override
  String get profileTerms => 'الشروط والأحكام';

  @override
  String get profilePrivacy => 'سياسة الخصوصية';

  @override
  String get profilePrivacyNote => 'تتضمن حذف الحساب';

  @override
  String get profileRefund => 'سياسة الاسترداد';

  @override
  String get profileLogout => 'تسجيل الخروج';

  @override
  String get commonCancel => 'إلغاء';

  @override
  String get commonClose => 'إغلاق';

  @override
  String get commonAll => 'الكل';

  @override
  String get notifClearTitle => 'مسح كل الإشعارات؟';

  @override
  String get notifClearBody => 'سيؤدي هذا إلى حذف جميع إشعاراتك نهائيًا.';

  @override
  String get notifClearAll => 'مسح الكل';

  @override
  String get notifEmptyTitle => 'لا توجد إشعارات بعد';

  @override
  String get notifEmptyBody => 'ستظهر العروض والتنبيهات هنا';

  @override
  String get timeAgoJustNow => 'الآن';

  @override
  String timeAgoMinutes(String n) {
    return 'منذ $n د';
  }

  @override
  String timeAgoHours(String n) {
    return 'منذ $n س';
  }

  @override
  String timeAgoDays(String n) {
    return 'منذ $n ي';
  }

  @override
  String timeAgoWeeks(String n) {
    return 'منذ $n أسبوع';
  }

  @override
  String searchStoresIn(String city) {
    return 'ابحث عن متاجر في $city...';
  }

  @override
  String searchNoResults(String q) {
    return 'لا توجد نتائج لـ «$q»';
  }

  @override
  String searchNoResultsDq(String q) {
    return 'لا توجد نتائج لـ «$q»';
  }

  @override
  String get searchNoStores => 'لا توجد متاجر بعد';

  @override
  String get searchStoreAreaOffer => 'ابحث عن متجر أو منطقة أو عرض...';

  @override
  String catSearchStores(String category) {
    return 'ابحث في متاجر $category...';
  }

  @override
  String catNoStoresFound(String category) {
    return 'لم يتم العثور على متاجر $category';
  }

  @override
  String catFoundButNone(String count, String category) {
    return 'تم العثور على $count متجر في هذه المدينة، لكن لا يوجد ما يطابق «$category».';
  }

  @override
  String catCategoriesFound(String list) {
    return 'الفئات الموجودة: $list';
  }

  @override
  String get catCategoriesTitle => 'الفئات';

  @override
  String get catSearchCategories => 'ابحث في الفئات...';

  @override
  String get catNoCategories => 'لم يتم العثور على فئات';

  @override
  String get catAllCategories => 'كل الفئات';

  @override
  String get dealsEndingSoon => 'تنتهي قريبًا';

  @override
  String get dealExpired => 'منتهي';

  @override
  String get dealEndsInOneDay => 'ينتهي خلال يوم';

  @override
  String dealEndsInDays(String days) {
    return 'ينتهي خلال $days أيام';
  }

  @override
  String get dealLocalBadge => 'عرض محلي';

  @override
  String get dealAvailableInStore => 'متاح في المتجر';

  @override
  String get dealsEyebrow => 'جديد حولك';

  @override
  String get dealsTitle => 'العروض المحلية';

  @override
  String dealsSubtitleCity(String city) {
    return 'أسعار حصرية للأعضاء وعروض محدودة من أنشطة موثّقة في $city.';
  }

  @override
  String get dealsSubtitleNearby =>
      'أسعار حصرية للأعضاء وعروض محدودة من أنشطة موثّقة بالقرب منك.';

  @override
  String get dealsSearch => 'ابحث عن عروض أو متاجر أو مناطق';

  @override
  String get dealsThisWeek => 'هذا الأسبوع';

  @override
  String get dealsNoneActive => 'لا توجد عروض نشطة حاليًا';

  @override
  String get dealsNoMatch => 'لا توجد عروض تطابق بحثك';

  @override
  String get areasTitle => 'كل المناطق';

  @override
  String get areasSearch => 'ابحث في المناطق...';

  @override
  String get areasNone => 'لا توجد مناطق متاحة';

  @override
  String areaSearchIn(String area) {
    return 'ابحث في $area...';
  }

  @override
  String areaStoresOne(String area) {
    return 'متجر واحد في $area';
  }

  @override
  String areaStoresMany(String count, String area) {
    return '$count متاجر في $area';
  }

  @override
  String get areaNoStores => 'لم يتم العثور على متاجر';

  @override
  String get storeSeeAllStores => 'عرض كل\nالمتاجر';

  @override
  String get unitMeter => 'م';

  @override
  String get unitKm => 'كم';

  @override
  String ptsOnVisit(String points) {
    return '$points نقطة عند الزيارة';
  }

  @override
  String get storeOpenNowCaps => 'مفتوح الآن';

  @override
  String get badgeNewStore => 'متجر جديد';

  @override
  String offSuffix(String amount) {
    return 'خصم $amount';
  }

  @override
  String get prodTitleFallback => 'منتج';

  @override
  String get prodListedBy => 'عرض من';

  @override
  String get prodViewStore => 'عرض المتجر';

  @override
  String get prodStoreInactive => 'المتجر غير نشط حاليًا';

  @override
  String get prodDetails => 'تفاصيل المنتج';

  @override
  String get prodRateReview => 'قيّم وأضف مراجعة';

  @override
  String get prodTapToRate => 'اضغط للتقييم';

  @override
  String get ratingPoor => 'ضعيف';

  @override
  String get ratingFair => 'مقبول';

  @override
  String get ratingGood => 'جيد';

  @override
  String get ratingGreat => 'رائع';

  @override
  String get ratingExcellent => 'ممتاز';

  @override
  String get prodShareExperience => 'شاركنا تجربتك مع هذا المنتج...';

  @override
  String get prodSubmitReview => 'إرسال المراجعة';

  @override
  String get prodThanksReview => 'شكرًا على مراجعتك!';

  @override
  String get reviewLoginRequired => 'يرجى تسجيل الدخول لإرسال مراجعة.';

  @override
  String get reviewSubmitted => 'تم إرسال المراجعة! شكرًا لك.';

  @override
  String get reviewSessionExpired =>
      'انتهت جلستك. يرجى تسجيل الدخول مرة أخرى لإرسال المراجعة.';

  @override
  String get prodAllProducts => 'كل المنتجات';

  @override
  String get prodNoProducts => 'لم يتم العثور على منتجات';

  @override
  String get prodSearch => 'ابحث عن منتجات...';

  @override
  String prodSeller(String name) {
    return 'البائع: $name';
  }

  @override
  String get prodBestSeller => 'الأكثر مبيعًا';

  @override
  String get monthJan => 'يناير';

  @override
  String get monthFeb => 'فبراير';

  @override
  String get monthMar => 'مارس';

  @override
  String get monthApr => 'أبريل';

  @override
  String get monthMay => 'مايو';

  @override
  String get monthJun => 'يونيو';

  @override
  String get monthJul => 'يوليو';

  @override
  String get monthAug => 'أغسطس';

  @override
  String get monthSep => 'سبتمبر';

  @override
  String get monthOct => 'أكتوبر';

  @override
  String get monthNov => 'نوفمبر';

  @override
  String get monthDec => 'ديسمبر';

  @override
  String get errGeneric => 'حدث خطأ ما. يرجى المحاولة مرة أخرى.';

  @override
  String get errConnect =>
      'تعذّر الاتصال بـ OffrO الآن. يرجى التحقق من اتصالك بالإنترنت والمحاولة مرة أخرى.';

  @override
  String get errTimeout =>
      'يستغرق OffrO وقتًا طويلًا للرد. يرجى المحاولة مرة أخرى بعد قليل.';

  @override
  String get errUnavailable =>
      'OffrO غير متاح مؤقتًا. يرجى المحاولة مرة أخرى بعد قليل.';

  @override
  String get errSession => 'انتهت جلستك. يرجى تسجيل الدخول مرة أخرى.';

  @override
  String get errApiNetwork =>
      'خطأ في الشبكة. يرجى التحقق من اتصالك والمحاولة مرة أخرى.';

  @override
  String get errApiUnexpected => 'استجابة غير متوقعة من الخادم.';

  @override
  String get profileGuestName => 'ضيف';

  @override
  String get profileSupportNote =>
      'هل تريد تحديث ملفك الشخصي؟ تواصل مع الدعم وسنساعدك فورًا.';

  @override
  String get favEyebrow => 'محفوظ لوقت لاحق';

  @override
  String get favPlacesOne => 'مكان واحد تحبه في مكان واحد.';

  @override
  String favPlacesMany(String count) {
    return '$count أماكن تحبها في مكان واحد.';
  }

  @override
  String get favEmptyTitle => 'لا توجد مفضلات بعد';

  @override
  String get favEmptyBody => 'اضغط على القلب في أي متجر لحفظه هنا';

  @override
  String get qrTitle => 'مسح رمز QR للمتجر';

  @override
  String get qrInvalid => '❌ رمز QR غير صالح';

  @override
  String get qrPointsAdded => 'تمت إضافة النقاط!';

  @override
  String get qrDone => 'تم!';

  @override
  String get qrRefreshedNote => '🔐 تم تحديث رمز QR للمتجر لأسباب أمنية.';

  @override
  String get qrGreat => 'رائع!';

  @override
  String get qrPointAt => 'وجّه الكاميرا نحو رمز QR للمتجر';

  @override
  String get exploreYourCity => 'مدينتك';

  @override
  String exploreDiscover(String city) {
    return 'اكتشف $city';
  }

  @override
  String get exploreTitle => 'استكشف القريب منك';

  @override
  String get exploreDesc =>
      'اعثر على الأعمال المستقلة والخدمات المفيدة والأماكن المحلية المفضلة حولك.';

  @override
  String get exploreSearchHint => 'ابحث عن متاجر أو فئات أو مناطق';

  @override
  String get exploreSearchNote =>
      'يبحث في أسماء الأعمال وفئات المتاجر والأحياء.';

  @override
  String get exploreByArea => 'استكشف حسب المنطقة';

  @override
  String exploreNeighbourhoodsIn(String city) {
    return 'الأحياء في $city';
  }

  @override
  String get exploreAroundYou => 'حولك';

  @override
  String get exploreNeighbourhood => 'الحي';

  @override
  String get explorePlacesOne => 'مكان واحد قريب';

  @override
  String explorePlacesMany(String count) {
    return '$count أماكن قريبة';
  }

  @override
  String exploreStoresInArea(String area) {
    return 'المتاجر في $area';
  }

  @override
  String get exploreNoMatchTitle => 'لا توجد متاجر مطابقة بعد';

  @override
  String get exploreNoMatchBody => 'جرّب اسم عمل أو فئة أو حيًا آخر.';

  @override
  String exploreOffer(String offer) {
    return 'عرض · $offer';
  }

  @override
  String get exploreStoreOne => 'متجر واحد';

  @override
  String exploreStoreMany(String count) {
    return '$count متاجر';
  }

  @override
  String get walletDone => 'تم';

  @override
  String get walletBadge => 'نقاط المكافآت';

  @override
  String get walletBalance => 'الرصيد المتاح';

  @override
  String get walletPointsWord => 'نقطة';

  @override
  String get walletRedeem => 'استبدال';

  @override
  String walletVoucherRate(String points, String amount) {
    return '$points نقطة = قسيمة $amount';
  }

  @override
  String get walletReadyToRedeem => 'جاهز للاستبدال';

  @override
  String walletToGo(String points) {
    return 'متبقٍ $points نقطة';
  }

  @override
  String walletPtsOnly(String points) {
    return '$points نقطة';
  }

  @override
  String get walletVoucherDesc => 'قسيمة هدية ترويجية';

  @override
  String walletVoucherDescPartners(String partners) {
    return 'قسيمة هدية ترويجية · $partners';
  }

  @override
  String get walletRewardsUnavailable =>
      'استبدال قسائم الهدايا غير متاح لبلدك بعد.';

  @override
  String walletEarnMore(String points) {
    return 'اكسب $points نقطة إضافية';
  }

  @override
  String get walletHowTitle => 'كيف تعمل المكافآت';

  @override
  String walletHowLine1(String points, String amount) {
    return 'استبدل $points نقطة مكافآت بقسيمة هدية ترويجية بقيمة $amount.';
  }

  @override
  String get walletHowLine2 => 'تسليم قسيمة الهدية: من 3 إلى 5 أيام عمل.';

  @override
  String get walletHowLine3 => 'نقاط المكافآت لا تنتهي صلاحيتها.';

  @override
  String get walletHowDisclaimer =>
      'نقاط المكافآت هي نقاط ولاء ترويجية. لا يمكن شراؤها أو تحويلها أو استبدالها بنقد.';

  @override
  String get walletRecent => 'النشاط الأخير';

  @override
  String get walletNoScansHint =>
      'لا توجد عمليات مسح بعد — ستظهر هنا النقاط التي تكسبها من المتاجر.';

  @override
  String walletEarnedOn(String date) {
    return 'مكتسبة · $date';
  }

  @override
  String get walletEyebrow => 'ولاؤك المحلي';

  @override
  String get walletTitle => 'المكافآت';

  @override
  String get walletDesc => 'كل عملية شراء محلية تقرّبك من شيء جميل.';

  @override
  String get walletVouchersEyebrow => 'جاهزة للاستخدام';

  @override
  String get walletVouchersTitle => 'قسائمك';

  @override
  String get walletViewHistory => 'عرض السجل';

  @override
  String get scanHistoryTitle => 'سجل المسح';

  @override
  String get scanHistoryEmpty => 'لا توجد عمليات مسح بعد';

  @override
  String walletPtsPlus(String points) {
    return '+$points نقطة';
  }

  @override
  String get storeTabAbout => 'نبذة';

  @override
  String get storeTabProducts => 'المنتجات';

  @override
  String get storeTabReviews => 'المراجعات';

  @override
  String get storeTabRewards => 'المكافآت';

  @override
  String storeScanEarn(String points) {
    return 'امسح واكسب $points نقطة';
  }

  @override
  String get storeScanCardTitle => 'امسح رمز QR للمتجر';

  @override
  String storeScanCardBody(String points) {
    return 'أكّد زيارتك أو عملية الشراء واكسب $points نقطة مكافآت.';
  }

  @override
  String get storeScanQr => 'مسح QR';

  @override
  String get storeRewardsSoon => 'المكافآت قريبًا';

  @override
  String get storeEarnPointsTitle => 'اكسب نقاط المكافآت';

  @override
  String storeEarnPointsBody(String points) {
    return 'امسح رمز QR بعد الشراء لتكسب $points نقطة';
  }

  @override
  String storeYourPoints(String points) {
    return 'نقاطك: $points';
  }

  @override
  String get storeShowLess => 'عرض أقل';

  @override
  String get storeReadMore => 'اقرأ المزيد ←';

  @override
  String get storeOpenWord => 'مفتوح';

  @override
  String get storeClosedWord => 'مغلق';

  @override
  String storeCostForTwo(String amount) {
    return '₹$amount لشخصين';
  }

  @override
  String get storeDineIn => 'الجلوس في المكان متاح';

  @override
  String get storeChipTrending => 'رائج';

  @override
  String get storeChipJustOpened => 'افتُتح حديثًا';

  @override
  String get storeChipPopular => 'شائع';

  @override
  String storeOfferPct(String pct) {
    return 'عرض · خصم $pct%';
  }

  @override
  String get storeCall => 'اتصال';

  @override
  String get storeWhatsApp => 'واتساب';

  @override
  String get storeDirections => 'الاتجاهات';

  @override
  String get storeExclusiveOne => 'حصري على OffrO · عرض واحد';

  @override
  String storeExclusiveMany(String count) {
    return 'حصري على OffrO · $count عروض';
  }

  @override
  String get storeExclusive => 'حصري على OffrO';

  @override
  String get storeDealsFromStore => 'عروض هذا المتجر';

  @override
  String get storeOffersSoon => 'العروض قريبًا';

  @override
  String storeDiscOff(String pct) {
    return 'خصم $pct%';
  }

  @override
  String get storeOffWord => 'خصم';

  @override
  String get prodsAvailableEyebrow => 'المنتجات المتوفرة في هذا المتجر';

  @override
  String get prodsFeatured => 'منتجات مميزة';

  @override
  String get prodsTip =>
      'نصيحة: اضغط مطولًا على صورة المنتج لعرض التفاصيل وكتابة مراجعة.';

  @override
  String prodRatingSubmitFailed(String error) {
    return 'تعذر إرسال التقييم: $error';
  }

  @override
  String prodValidTill(String date) {
    return 'صالح حتى $date';
  }

  @override
  String get prodYourRating => 'تقييمك';

  @override
  String get prodRateThis => 'قيّم هذا المنتج';

  @override
  String get prodReviewHint => 'اكتب مراجعة قصيرة (اختياري)';

  @override
  String get prodSubmitRating => 'إرسال التقييم';

  @override
  String get prodThanksRating => 'شكرًا على تقييمك! ⭐';

  @override
  String get prodGotIt => 'حسنًا';

  @override
  String get revStoreNotFound =>
      'لم يتم العثور على المتجر. تعذر إرسال المراجعة.';

  @override
  String get revSelectStar => 'يرجى اختيار تقييم بالنجوم';

  @override
  String get revMin5 => 'اكتب 5 أحرف على الأقل';

  @override
  String get revSubmittedStar => '⭐ تم إرسال المراجعة! شكرًا لك.';

  @override
  String get revUnavailable => 'معلومات المتجر غير متاحة.';

  @override
  String get revEyebrow => 'ماذا يقول العملاء';

  @override
  String get revTitle => 'المراجعات';

  @override
  String get revCountOne => '(مراجعة واحدة)';

  @override
  String revCountMany(String count) {
    return '($count مراجعات)';
  }

  @override
  String get revNoneTitle => 'لا توجد مراجعات بعد';

  @override
  String get revYourReview => 'مراجعتك';

  @override
  String get revEdit => 'تعديل';

  @override
  String get revWrite => 'اكتب مراجعة…';

  @override
  String get revShareExp => 'شاركنا تجربتك…';

  @override
  String get revSubmit => 'إرسال';

  @override
  String get revNoneDot => 'لا توجد مراجعات بعد.';

  @override
  String get revBeFirst => 'كن أول من يكتب مراجعة.';

  @override
  String get revViewAll => 'عرض كل المراجعات ←';

  @override
  String get revAllTitle => 'كل المراجعات';

  @override
  String get revAnonymous => 'مجهول';

  @override
  String get storeDealWord => 'عرض';

  @override
  String get storeNewStoreTitle => 'متجر جديد';

  @override
  String storeDistAwayM(String n) {
    return 'يبعد $n م';
  }

  @override
  String storeDistAwayKm(String n) {
    return 'يبعد $n كم';
  }

  @override
  String get locGpsFailed =>
      'تعذر الحصول على موقع GPS دقيق. انتقل إلى مكان مفتوح أو تحقق من الإشارة.';

  @override
  String get locCityUnknown => 'حصلنا على موقعك لكن تعذر تحديد المدينة.';

  @override
  String get locServicesOff =>
      'خدمات الموقع في جهازك متوقفة. يرجى تشغيلها من الإعدادات.';

  @override
  String get locPermissionOff =>
      'إذن الموقع متوقف لتطبيق OffrO. يرجى السماح به من إعدادات التطبيق.';

  @override
  String get locPermissionDenied =>
      'لم يتم السماح بإذن الموقع. اضغط على البطاقة للمحاولة مرة أخرى، أو اختر مدينة من القائمة أدناه.';

  @override
  String get locNotDetected => 'لم يتم تحديد الموقع';

  @override
  String get locGoToSettings => 'الانتقال إلى الإعدادات';

  @override
  String get locCityUnsupportedTitle => 'المدينة غير مدعومة بعد';

  @override
  String locCityUnsupportedBody(String city) {
    return 'OffrO غير متاح في $city بعد. يرجى اختيار مدينة أخرى من القائمة.';
  }

  @override
  String get commonOk => 'حسنًا';

  @override
  String get locTitle => 'الموقع';

  @override
  String get locSearchHint => 'ابحث عن مدينة أو منطقة أو حي';

  @override
  String get locCitiesLoadFailed =>
      'تعذر تحميل المدن. تحقق من اتصالك وحاول مرة أخرى.';

  @override
  String get locNoCitiesYet => 'لا توجد مدن متاحة لبلدك بعد.';

  @override
  String get locTryAgain => 'حاول مرة أخرى';

  @override
  String get locPopularCities => 'المدن الشائعة';

  @override
  String get locAllCities => 'كل المدن';

  @override
  String get locCities => 'المدن';

  @override
  String get locAreas => 'المناطق';

  @override
  String get locNoMatch => 'لم يتم العثور على أماكن مطابقة.';

  @override
  String get legalEyebrow => 'قانوني';

  @override
  String get legalPrivacyTitle => 'سياسة الخصوصية';

  @override
  String get legalPrivacyUpdating =>
      'يجري تحديث محتوى سياسة الخصوصية. يرجى المراجعة لاحقًا.';

  @override
  String get legalReadLess => 'عرض أقل';

  @override
  String get legalReadMore => 'اقرأ المزيد';

  @override
  String get legalAccountCaps => 'الحساب';

  @override
  String get legalDeleteRequest => 'طلب حذف حسابي';

  @override
  String get legalDeleteRequestNote => 'ستتم إزالة جميع بياناتك نهائيًا';

  @override
  String get delReasonUnused => 'لم أعد أستخدم التطبيق';

  @override
  String get delReasonPrivacy => 'لدي مخاوف تتعلق بالخصوصية';

  @override
  String get delReasonDuplicate => 'لدي حساب مكرر';

  @override
  String get delReasonNoisy => 'إشعارات كثيرة أو محتوى غير ذي صلة';

  @override
  String get delReasonOther => 'أخرى';

  @override
  String get delEyebrow => 'الحساب';

  @override
  String get delTitle => 'حذف الحساب';

  @override
  String get delWarning =>
      'بعد حذف حسابك لا يمكن استرجاع بياناتك. سيؤدي التسجيل مجددًا إلى إنشاء حساب جديد.';

  @override
  String get delSelectReason => 'اختر سببًا لحذف حسابك';

  @override
  String get delSubmit => 'إرسال طلب الحذف';

  @override
  String get delConfirmTitle => 'حذف الحساب؟';

  @override
  String get delConfirmBody =>
      'سيتم تحديد حسابك للحذف. سيتم تسجيل خروجك فورًا ولن تتمكن من تسجيل الدخول مجددًا.\n\nبعد الحذف لا يمكن استرجاع بياناتك. هل أنت متأكد تمامًا؟';

  @override
  String get delConfirmYes => 'نعم، احذف';

  @override
  String get delRequestedTitle => 'تم طلب الحذف';

  @override
  String get delRequestedBody => 'تم إرسال طلب حذف حسابك. تم تسجيل خروجك.';

  @override
  String delSubmitFailed(String error) {
    return 'تعذر الإرسال: $error';
  }

  @override
  String get loadStep1 => 'جارٍ تحديد موقعك...';

  @override
  String get loadStep2 => 'جارٍ البحث عن العروض القريبة...';

  @override
  String get loadStep3 => 'جارٍ فحص المتاجر المحلية...';

  @override
  String get loadStep4 => 'جارٍ تحميل عروض اليوم...';

  @override
  String get catBrowseTitle => 'تصفح حسب الفئات';

  @override
  String get catView => 'عرض';

  @override
  String get catPharmacy => 'صيدلية';

  @override
  String get catFashion => 'أزياء';

  @override
  String get catBeauty => 'تجميل';

  @override
  String get catElectronics => 'إلكترونيات';

  @override
  String get catEducation => 'تعليم';

  @override
  String get catHospital => 'مستشفى';

  @override
  String get catCafe => 'مقهى';

  @override
  String get catFitness => 'لياقة بدنية';

  @override
  String get catJewelry => 'مجوهرات';

  @override
  String get catSubRestaurant => 'أكثر من 500 مكان';

  @override
  String get catSubPharmacy => 'مستلزمات صحية';

  @override
  String get catSubFashion => 'وصل حديثًا';

  @override
  String get catSubBeauty => 'العناية بالبشرة والمزيد';

  @override
  String get catSubElectronics => 'أجهزة رائجة';

  @override
  String get catSubEducation => 'تعلّم وانمُ';

  @override
  String get catSubHospital => 'رعاية صحية بالقرب منك';

  @override
  String get catSubCafe => 'قهوة والمزيد';

  @override
  String get catSubGrocery => 'طازج ويومي';

  @override
  String get catSubFitness => 'ابقَ قويًا';

  @override
  String get catSubJewelry => 'قطع ثمينة';

  @override
  String get catSubBakery => 'مخبوزات طازجة يوميًا';

  @override
  String get dealsActiveOne => 'عرض واحد نشط لك';

  @override
  String dealsActiveMany(String count) {
    return '$count عروض نشطة لك';
  }

  @override
  String get areaCardStoreOne => 'متجر واحد';

  @override
  String areaCardStoreMany(String count) {
    return '$count متاجر';
  }

  @override
  String storeDistAwaySpM(String n) {
    return 'يبعد $n م';
  }

  @override
  String storeDistAwaySpKm(String n) {
    return 'يبعد $n كم';
  }

  @override
  String get prodSpecialOffer => 'عرض خاص';

  @override
  String get prodDownload => 'تنزيل';

  @override
  String get bizAdd => 'إضافة';

  @override
  String get bizNoStoresYetTapTo =>
      'لا توجد متاجر بعد — اضغط لإضافة متجرك الأول';

  @override
  String get bizSubscribeYourStoreToCreate => 'اشترك بمتجرك لإنشاء البانرات.';

  @override
  String get bizNoBannersYetPromoteYour => 'لا توجد بانرات بعد — روّج لمتجرك';

  @override
  String get bizSubscribeYourStoreToAdd => 'اشترك بمتجرك لإضافة المنتجات.';

  @override
  String get bizNoProductsYetAddYour => 'لا توجد منتجات بعد — أضف منتجك الأول';

  @override
  String get bizMERCHANTWORKSPACE => 'مساحة التاجر';

  @override
  String get bizWelcomeBack => 'مرحبًا بعودتك';

  @override
  String get bizCouldnTLoadYourDashboard => 'تعذر تحميل لوحة التحكم';

  @override
  String get bizLiveStores => 'المتاجر النشطة';

  @override
  String get bizLiveBanners => 'البانرات النشطة';

  @override
  String get bizLiveProducts => 'المنتجات النشطة';

  @override
  String get bizMANAGEYOURBUSINESS => 'أدر نشاطك التجاري';

  @override
  String get bizMyStore => 'متجري';

  @override
  String get bizMyBanner => 'بانري';

  @override
  String get bizMyProducts => 'منتجاتي';

  @override
  String get bizCreatorCollaborations => 'التعاون مع صنّاع المحتوى';

  @override
  String get bizBriefMatchAndManageLocal =>
      'اكتب الطلب وطابق وأدر صنّاع المحتوى المحليين';

  @override
  String get bizSubscribeYourStoreToWork =>
      'اشترك بمتجرك للتعاون مع صنّاع المحتوى.';

  @override
  String get bizLocked => 'مقفل';

  @override
  String get bizManage => 'إدارة';

  @override
  String get bizPromotions => 'الترويج';

  @override
  String get bizMyBanners => 'بانراتي';

  @override
  String get bizNewBanner => 'بانر جديد';

  @override
  String get bizCouldnTLoadBanners => 'تعذر تحميل البانرات';

  @override
  String get bizNoBannersYet => 'لا توجد بانرات بعد';

  @override
  String get bizTapToCreateYourFirst => 'اضغط + لإنشاء بانرك الأول';

  @override
  String get bizApprovedLive => 'تمت الموافقة — نشط';

  @override
  String get bizRejected => 'مرفوض';

  @override
  String get bizRemovedByAdmin => 'تمت الإزالة بواسطة الإدارة';

  @override
  String get bizTurnedOff => 'متوقف';

  @override
  String get bizPendingApproval => 'بانتظار الموافقة';

  @override
  String get bizSubmitted => 'تم الإرسال';

  @override
  String get bizEditBannerTitle => 'تعديل عنوان البانر';

  @override
  String get bizBannerTitle => 'عنوان البانر';

  @override
  String get bizSave => 'حفظ';

  @override
  String get bizEditTitle => 'تعديل العنوان';

  @override
  String get bizTurnOffBanner => 'إيقاف البانر؟';

  @override
  String get bizTurnOnBanner => 'تشغيل البانر؟';

  @override
  String get bizThisBannerWillBeHidden =>
      'سيتم إخفاء هذا البانر عن المتاجر حتى تعيد تشغيله.';

  @override
  String get bizThisBannerWillGoLive => 'سيظهر هذا البانر مجددًا في المتاجر.';

  @override
  String get bizTurnOff => 'إيقاف';

  @override
  String get bizTurnOn => 'تشغيل';

  @override
  String get bizExpiredChooseANewStart => 'منتهي · اختر تاريخ بدء جديدًا';

  @override
  String get bizRenew => 'تجديد';

  @override
  String get bizRejectedCreateANewBanner =>
      'مرفوض · أنشئ بانرًا جديدًا لإعادة الإرسال';

  @override
  String get bizCreateNew => 'إنشاء جديد';

  @override
  String get bizRemovedByAdmin2 => 'تمت الإزالة بواسطة الإدارة';

  @override
  String get bizAwaitingAdminApproval => 'بانتظار موافقة الإدارة';

  @override
  String get bizImageTooLargeMax2MB =>
      'الصورة كبيرة جدًا. الحد الأقصى 2 ميجابايت.';

  @override
  String get bizVideoIsTooLargePlease =>
      'الفيديو كبير جدًا. يرجى اختيار فيديو لا يتجاوز 10 ميجابايت.';

  @override
  String get bizVideoIsTooLongPlease =>
      'الفيديو طويل جدًا. يرجى اختيار فيديو لا يتجاوز 15 ثانية.';

  @override
  String get bizCouldNotReadThisVideo =>
      'تعذرت قراءة هذا الفيديو. يرجى اختيار فيديو آخر.';

  @override
  String get bizCouldNotUploadTheVideo =>
      'تعذر رفع الفيديو. يرجى المحاولة مرة أخرى.';

  @override
  String get bizExistingBannerVideoWillBe =>
      'سيُعاد استخدام فيديو البانر الحالي';

  @override
  String get bizTapToReplace => 'اضغط للاستبدال';

  @override
  String get bizTapToSelectBannerVideo => 'اضغط لاختيار فيديو البانر';

  @override
  String get biz10801080px11 => '📐 1080×1080 بكسل (1:1)';

  @override
  String get bizMax15Sec10MB => 'الحد الأقصى 15 ثانية · 10 ميجابايت';

  @override
  String get bizBannerTitleRequired => 'عنوان البانر مطلوب';

  @override
  String get bizPleaseSelectAStore => 'يرجى اختيار متجر';

  @override
  String get bizPleaseSelectACity => 'يرجى اختيار مدينة';

  @override
  String get bizPleaseSelectABannerVideo => 'يرجى اختيار فيديو للبانر';

  @override
  String get bizPleaseUploadABannerImage => 'يرجى رفع صورة للبانر';

  @override
  String get bizEnterNumberOfDaysMinimum => 'أدخل عدد الأيام (الحد الأدنى 1)';

  @override
  String get bizUntitledDeal => 'عرض بلا عنوان';

  @override
  String get bizUntitledProduct => 'منتج بلا عنوان';

  @override
  String get bizCTADestination => 'وجهة زر الإجراء';

  @override
  String get bizChooseWhereThisBannerShould =>
      'اختر الوجهة التي سينقل إليها هذا البانر العميل.';

  @override
  String get bizSelectDeal => 'اختر عرضًا';

  @override
  String get bizSelectProduct => 'اختر منتجًا';

  @override
  String get bizCustomersWillOpenTheSelected => 'سيفتح العملاء المتجر المحدد.';

  @override
  String get bizNothingSelectedYetTheBanner =>
      'لم يتم اختيار شيء بعد — سيفتح البانر المتجر.';

  @override
  String get bizDiscountApplied => '✅ تم تطبيق الخصم!';

  @override
  String get bizPaymentGatewayNotConfiguredContact =>
      'بوابة الدفع غير مهيأة. تواصل مع الدعم.';

  @override
  String get bizCouldNotOpenPaymentPlease =>
      'تعذر فتح الدفع. يرجى المحاولة مرة أخرى.';

  @override
  String get bizBannerOrderSummary => 'ملخص طلب البانر';

  @override
  String get bizTitle => 'العنوان';

  @override
  String get bizDuration => 'المدة';

  @override
  String get bizPeriod => 'الفترة';

  @override
  String get bizRate => 'السعر';

  @override
  String get bizBasePrice => 'السعر الأساسي';

  @override
  String get bizDiscount => 'الخصم';

  @override
  String get bizTotal => 'الإجمالي';

  @override
  String get bizYourBannerWillBeSubmitted =>
      'سيتم إرسال بانرك إلى الإدارة للمراجعة بعد التأكيد.';

  @override
  String get bizRazorpayCheckoutWillOpenBanner =>
      'سيتم فتح صفحة الدفع Razorpay. يصبح البانر نشطًا بعد موافقة الإدارة.';

  @override
  String get bizConfirmSubmit => 'تأكيد الإرسال';

  @override
  String get bizRenewBanner => 'تجديد البانر';

  @override
  String get bizCreateBanner => 'إنشاء بانر';

  @override
  String get bizBannerTitle2 => 'عنوان البانر *';

  @override
  String get bizEG50OFFAt => 'مثال: خصم 50% في متجر راج';

  @override
  String get bizSelectStore => 'اختر المتجر *';

  @override
  String get bizUnnamedStore => 'متجر بلا اسم';

  @override
  String get bizCityAutoFilledFromStore =>
      'تتم تعبئة المدينة تلقائيًا من المتجر';

  @override
  String get bizImage => 'صورة';

  @override
  String get bizVideo => 'فيديو';

  @override
  String get bizTapToUploadBannerImage => 'اضغط لرفع صورة البانر';

  @override
  String get bizMax2MB => '📦 الحد الأقصى 2 ميجابايت';

  @override
  String get bizDurationStartDate => 'المدة وتاريخ البدء';

  @override
  String get bizNumberOfDays => 'عدد الأيام';

  @override
  String get bizFromDate => 'من تاريخ';

  @override
  String get bizActivePeriod => 'فترة النشاط:';

  @override
  String get bizDiscountCode => 'رمز الخصم';

  @override
  String get bizHaveAPromoCodeEnter => 'لديك رمز ترويجي؟ أدخله أدناه.';

  @override
  String get bizEGOFFRO20 => 'مثال: OFFRO20';

  @override
  String get bizApply => 'تطبيق';

  @override
  String get bizProceedToCheckout => 'المتابعة إلى الدفع';

  @override
  String get bizLive => 'نشط';

  @override
  String get bizFilterProducts => 'تصفية المنتجات';

  @override
  String get bizEditProduct => 'تعديل المنتج';

  @override
  String get bizAnalytics => 'التحليلات';

  @override
  String get bizDeleteProduct => 'حذف المنتج';

  @override
  String get bizCatalogue => 'الكتالوج';

  @override
  String get bizFilter => 'تصفية';

  @override
  String get bizNewProduct => 'منتج جديد';

  @override
  String get bizSearchProducts => 'ابحث في المنتجات…';

  @override
  String get bizPending => 'قيد الانتظار';

  @override
  String get bizCouldnTLoadProducts => 'تعذر تحميل المنتجات';

  @override
  String get bizNoProductsYet => 'لا توجد منتجات بعد';

  @override
  String get bizNoMatchingProducts => 'لا توجد منتجات مطابقة';

  @override
  String get bizTapNewProductToGet => 'اضغط + منتج جديد للبدء';

  @override
  String get bizPaused => 'متوقف مؤقتًا';

  @override
  String get bizFree => 'مجاني';

  @override
  String get bizPaid => 'مدفوع';

  @override
  String get bizDeactivated => 'معطّل';

  @override
  String get bizOn => 'مفعّل';

  @override
  String get bizOff => 'متوقف';

  @override
  String get bizOfferText => 'نص العرض';

  @override
  String get bizOriginalPrice => 'السعر الأصلي';

  @override
  String get bizOfferPrice => 'سعر العرض';

  @override
  String get bizProductUpdated => 'تم تحديث المنتج!';

  @override
  String get bizDeleteThisProduct => 'حذف هذا المنتج؟';

  @override
  String get bizProductDeleted => 'تم حذف المنتج.';

  @override
  String get bizLogoTooLargeMax1MB =>
      'الشعار كبير جدًا. الحد الأقصى 1 ميجابايت.';

  @override
  String get bizEnterACode => 'أدخل رمزًا';

  @override
  String get bizProductTitleRequired => 'عنوان المنتج مطلوب';

  @override
  String get bizPleaseSelectAStoreFor => 'يرجى اختيار متجر لهذا المنتج';

  @override
  String get bizPleaseSelectACityFor => 'يرجى اختيار مدينة لهذا المنتج';

  @override
  String get bizPleaseUploadAProductImage => 'يرجى رفع صورة للمنتج';

  @override
  String get bizEnterTheNumberOfDays => 'أدخل عدد الأيام (الحد الأدنى 1)';

  @override
  String get bizProductOrderSummary => 'ملخص طلب المنتج';

  @override
  String get bizPrice => 'السعر';

  @override
  String get bizProductWillGoToAdmin =>
      'سيُرسل المنتج إلى الإدارة للمراجعة. لا حاجة للدفع.';

  @override
  String get bizRazorpayOpensProductLiveAfter =>
      'سيتم فتح Razorpay. يصبح المنتج نشطًا بعد موافقة الإدارة.';

  @override
  String get bizSaveProduct => 'حفظ المنتج';

  @override
  String get bizAddProduct => 'إضافة منتج';

  @override
  String get bizProductTitle => 'عنوان المنتج *';

  @override
  String get bizEGRajStore50 => 'مثال: خصم ₹50 من متجر راج';

  @override
  String get bizEGGet50Off => 'مثال: احصل على خصم ₹50 على الطلبات فوق ₹299';

  @override
  String get bizDiscountIsAutoCalculatedFrom =>
      'يُحسب الخصم تلقائيًا من الأسعار';

  @override
  String get bizUploadImage => 'رفع صورة';

  @override
  String get biz400400px => '📐 400×400 بكسل';

  @override
  String get bizMax1MB => '📦 الحد الأقصى 1 ميجابايت';

  @override
  String get bizValidityDays => 'مدة الصلاحية (بالأيام)';

  @override
  String get bizStartDate => 'تاريخ البدء';

  @override
  String get bizEndDate => 'تاريخ الانتهاء';

  @override
  String get bizNumberOfDays2 => 'عدد الأيام';

  @override
  String get bizLivePeriod => 'فترة النشاط:';

  @override
  String bizFree0(String amount) {
    return 'مجاني ($amount)';
  }

  @override
  String get bizFreeProduct => 'منتج مجاني';

  @override
  String get bizYourBusiness => 'نشاطك التجاري';

  @override
  String get bizMyStores => 'متاجري';

  @override
  String get bizTapToAddYourFirst => 'اضغط + لإضافة متجرك الأول';

  @override
  String get bizActive => 'نشط';

  @override
  String get bizDraft => 'مسودة';

  @override
  String get bizInactive => 'غير نشط';

  @override
  String get bizDeleted => 'محذوف';

  @override
  String get bizRemoved => 'تمت الإزالة';

  @override
  String get bizSubscribe => 'اشتراك';

  @override
  String get bizAwaitingAdminApproval2 => 'بانتظار موافقة الإدارة';

  @override
  String get bizQR => 'رمز QR';

  @override
  String get bizGenQR => 'إنشاء QR';

  @override
  String get bizShowThisToCustomersTo =>
      'اعرض هذا الرمز على العملاء ليكسبوا النقاط';

  @override
  String get bizDeviceLocationIsTurnedOff =>
      'خدمة الموقع في الجهاز متوقفة. شغّلها وحاول مرة أخرى.';

  @override
  String get bizUnableToIdentifyTheExact =>
      'تعذر تحديد الموقع الدقيق من رابط خرائط Google هذا. يرجى فتح خرائط Google، وتحديد الموقع الدقيق بدبوس، ثم اضغط مشاركة ← نسخ الرابط، وحاول مرة أخرى.';

  @override
  String get bizCity => 'المدينة';

  @override
  String get bizState => 'الولاية';

  @override
  String get bizArea => 'المنطقة';

  @override
  String get bizPostalCode => 'الرمز البريدي';

  @override
  String get bizLocationCaptured => 'تم تحديد الموقع';

  @override
  String get bizImageTooLargeMax2MB2 =>
      'الصورة كبيرة جدًا. الحد الأقصى المسموح 2 ميجابايت.';

  @override
  String get bizStoreNameRequired => 'اسم المتجر مطلوب';

  @override
  String get bizPleaseSetTheStoreLocation =>
      'يرجى تحديد موقع المتجر باستخدام \"استخدام الموقع الحالي\" أو رابط خرائط Google';

  @override
  String get bizMobileNumberIsRequired => 'رقم الجوال مطلوب';

  @override
  String get bizEnterAValid10Digit =>
      'أدخل رقم جوال صحيحًا من 10 أرقام (يبدأ بـ 6–9)';

  @override
  String get bizEditStore => 'تعديل المتجر';

  @override
  String get bizAddStore => 'إضافة متجر';

  @override
  String get bizStoreName => 'اسم المتجر *';

  @override
  String get bizCategory => 'الفئة';

  @override
  String get bizSelectCategory => 'اختر الفئة';

  @override
  String get bizStoreLocation => 'موقع المتجر';

  @override
  String get bizUseGPSOrPasteA => 'استخدم GPS أو الصق رابط الخرائط.';

  @override
  String get bizUseCurrentLocation => 'استخدام الموقع الحالي';

  @override
  String get bizOrPasteGoogleMapsLink => 'أو الصق رابط خرائط Google';

  @override
  String get bizPasteGoogleMapsLinkHere => 'الصق رابط خرائط Google هنا';

  @override
  String get bizResolveLocation => 'تحديد الموقع';

  @override
  String get bizLatitude => 'خط العرض';

  @override
  String get bizLongitude => 'خط الطول';

  @override
  String get bizAutoFilledByGPSOr =>
      'تمت التعبئة تلقائيًا بواسطة GPS أو خرائط Google — يمكنك تعديل أي قيمة. تُحفظ القيم المعدّلة كما أدخلتها.';

  @override
  String get bizPhone => 'الهاتف';

  @override
  String get bizTapToChangeImage => 'اضغط لتغيير الصورة';

  @override
  String get bizMainStoreImage => 'الصورة الرئيسية للمتجر';

  @override
  String get biz800600px43 => '📐 800×600 بكسل (4:3)';

  @override
  String get bizUploadLogoOptional => 'رفع الشعار [اختياري]';

  @override
  String get bizTapToChangeLogo => 'اضغط لتغيير الشعار';

  @override
  String get bizTapToUploadLogo => 'اضغط لرفع الشعار';

  @override
  String get biz200200px11 => '📐 200×200 بكسل (1:1)';

  @override
  String get bizStoreTimingsOptional => 'ساعات عمل المتجر [اختياري]';

  @override
  String get bizOpeningTime => 'وقت الفتح';

  @override
  String get bizOpenAt => 'يفتح في';

  @override
  String get bizClosingTime => 'وقت الإغلاق';

  @override
  String get bizCloseAt => 'يغلق في';

  @override
  String get bizAboutThisStoreDescriptionShown =>
      'نبذة عن هذا المتجر (وصف يظهر للعملاء)';

  @override
  String get bizSaveChanges => 'حفظ التغييرات';

  @override
  String get bizCreateStore => 'إنشاء المتجر';

  @override
  String get bizConfirmingPayment => 'جارٍ تأكيد الدفع...';

  @override
  String get bizPleaseWaitAMoment => 'يرجى الانتظار قليلًا';

  @override
  String get bizSubscriptionRequestSent => 'تم إرسال طلب الاشتراك';

  @override
  String get bizPlan => 'الخطة';

  @override
  String get bizFrom => 'من';

  @override
  String get bizTo => 'إلى';

  @override
  String get bizTotalPayable => 'إجمالي المبلغ المستحق';

  @override
  String get bizYourSubscriptionRequestHasBeen => '✅  تم إرسال طلب اشتراكك.';

  @override
  String get bizConfirmPayment => 'تأكيد الدفع';

  @override
  String get bizRazorpayCheckoutWillOpenAfter =>
      'سيتم فتح صفحة الدفع Razorpay. بعد الدفع ستوافق الإدارة على متجرك.';

  @override
  String get bizPayNow => 'ادفع الآن';

  @override
  String get bizSubscribeStore => 'الاشتراك بالمتجر';

  @override
  String get bizSelectPlan => 'اختر الخطة';

  @override
  String get bizStartDate2 => 'تاريخ البدء';

  @override
  String get bizHaveADiscountCode => 'لديك رمز خصم؟';

  @override
  String get bizEnterCode => 'أدخل الرمز';

  @override
  String get bizDiscount2 => 'الخصم:';

  @override
  String get bizRemove => 'إزالة';

  @override
  String get bizProceedToPay => 'المتابعة إلى الدفع';

  @override
  String get bizRefresh => 'تحديث';

  @override
  String get bizNoInvoicesYet => 'لا توجد فواتير بعد';

  @override
  String get bizPullDownToRefresh => 'اسحب للأسفل للتحديث';

  @override
  String get bizShare => 'مشاركة';

  @override
  String get bizDownloadPDF => 'تنزيل PDF';

  @override
  String get bizAccountRegistered => 'تم تسجيل الحساب';

  @override
  String get bizNewStoreCreated => 'تم إنشاء متجر جديد';

  @override
  String get bizStoreProfileUpdated => 'تم تحديث ملف المتجر';

  @override
  String get bizStoreApproved => 'تمت الموافقة على المتجر';

  @override
  String get bizStoreRejected => 'تم رفض المتجر';

  @override
  String get bizStoreSubscriptionActivated => 'تم تفعيل اشتراك المتجر';

  @override
  String get bizFreeSubscriptionActivated => 'تم تفعيل الاشتراك المجاني';

  @override
  String get bizSubscriptionPaymentReceived => 'تم استلام دفعة الاشتراك';

  @override
  String get bizBannerSubmitted => 'تم إرسال البانر';

  @override
  String get bizBannerApproved => 'تمت الموافقة على البانر';

  @override
  String get bizBannerRejected => 'تم رفض البانر';

  @override
  String get bizBannerPaymentReceived => 'تم استلام دفعة البانر';

  @override
  String get bizProductSubmitted => 'تم إرسال المنتج';

  @override
  String get bizProductApproved => 'تمت الموافقة على المنتج';

  @override
  String get bizProductRejected => 'تم رفض المنتج';

  @override
  String get bizProductPaymentReceived => 'تم استلام دفعة المنتج';

  @override
  String get bizPaymentReceived => 'تم استلام الدفعة';

  @override
  String get bizFreePlanActivated => 'تم تفعيل الخطة المجانية';

  @override
  String get bizProfileUpdated => 'تم تحديث الملف الشخصي';

  @override
  String get bizQRCodeRegenerated => 'تم إنشاء رمز QR من جديد';

  @override
  String get bizPayment => 'الدفع';

  @override
  String get bizApprovedLive2 => '✅ تمت الموافقة — نشط';

  @override
  String get bizRejected2 => '❌ مرفوض';

  @override
  String get bizPendingApproval2 => '⏳ بانتظار الموافقة';

  @override
  String get bizBusinessTimeline => 'السجل الزمني للنشاط';

  @override
  String get bizNoActivityYet => 'لا يوجد نشاط بعد';

  @override
  String get bizMerchantAccount => 'حساب التاجر';

  @override
  String get bizTapPhotoToChange => 'اضغط على الصورة لتغييرها';

  @override
  String get bizSwitchBetweenUserMerchantInfluencer =>
      'التبديل بين المستخدم والتاجر والمؤثر';

  @override
  String get bizKYCPolicy => 'سياسة اعرف عميلك (KYC)';

  @override
  String get bizMerchantOffers => 'عروض التاجر';

  @override
  String get bizMyDeals => 'عروضي';

  @override
  String get bizAddDeal => 'إضافة عرض';

  @override
  String get bizYouNeedAnActiveStore => 'تحتاج إلى متجر نشط لإضافة العروض.';

  @override
  String get bizNoDealsYet => 'لا توجد عروض بعد';

  @override
  String get bizAddDealsToAttractMore => 'أضف عروضًا لجذب المزيد من العملاء';

  @override
  String get bizEditDeal => 'تعديل العرض';

  @override
  String get bizDeleteDeal => 'حذف العرض؟';

  @override
  String get bizDelete => 'حذف';

  @override
  String get bizDealTitleIsRequired => 'عنوان العرض مطلوب';

  @override
  String get bizEndDateIsRequired => 'تاريخ الانتهاء مطلوب';

  @override
  String get bizPleaseAddAnImageBefore => 'يرجى إضافة صورة قبل الحفظ.';

  @override
  String get bizDealUpdated => 'تم تحديث العرض!';

  @override
  String get bizDealAdded => 'تمت إضافة العرض!';

  @override
  String get bizDealTitleEG20 =>
      'عنوان العرض (مثال: خصم 20% على جميع المنتجات)';

  @override
  String get bizDescriptionOptional => 'الوصف (اختياري)';

  @override
  String get bizDealImage => 'صورة العرض';

  @override
  String get bizTapToReplaceImage => 'اضغط لاستبدال الصورة';

  @override
  String get bizMax2MBRequired => '📦 الحد الأقصى 2 ميجابايت · مطلوبة';

  @override
  String get bizSelectEndDate => 'اختر تاريخ الانتهاء';

  @override
  String get bizAllYourStoresProductsData =>
      'ستتم إزالة جميع متاجرك ومنتجاتك وبياناتك نهائيًا';

  @override
  String get bizINoLongerRunMy => 'لم أعد أدير نشاطي التجاري';

  @override
  String get bizTheAppIsNotWorking => 'التطبيق لا يعمل بشكل صحيح معي';

  @override
  String get bizOnceYourAccountIsDeleted =>
      'بعد حذف حسابك لا يمكن استرجاع متاجرك ومنتجاتك وبانراتك وبياناتك. سيؤدي التسجيل مجددًا إلى إنشاء حساب جديد.';

  @override
  String get bizYourMerchantAccountWillBe =>
      'سيتم تحديد حساب التاجر الخاص بك للحذف. سيتم تسجيل خروجك فورًا ولن تتمكن من تسجيل الدخول مجددًا.\n\nبعد الحذف لا يمكن استرجاع متاجرك ومنتجاتك وبياناتك. هل أنت متأكد تمامًا؟';

  @override
  String get bizChecking => 'جارٍ التحقق…';

  @override
  String get bizDiscountApplied2 => 'تم تطبيق الخصم!';

  @override
  String get bizChooseALaterEndDate =>
      'اختر تاريخ انتهاء لاحقًا (أضف يومًا واحدًا على الأقل)';

  @override
  String get bizRenewedSuccessfully => '✅ تم التجديد بنجاح!';

  @override
  String get bizRenewalSummary => 'ملخص التجديد';

  @override
  String get bizNewEndDate => 'تاريخ الانتهاء الجديد';

  @override
  String get bizFreeRenewal => 'تجديد مجاني';

  @override
  String get bizRenewFree => 'تجديد مجاني';

  @override
  String get bizRenewed => 'تم التجديد!';

  @override
  String get bizRenewProduct => 'تجديد المنتج';

  @override
  String get bizNoEndDate => 'لا يوجد تاريخ انتهاء';

  @override
  String get bizChooseHowLongTheProduct =>
      'اختر المدة التي يبقى فيها المنتج نشطًا.';

  @override
  String get bizDaysToAdd => 'الأيام المراد إضافتها';

  @override
  String get bizProductAnalytics => 'تحليلات المنتج';

  @override
  String get bizCouldnTLoadAnalytics => 'تعذر تحميل التحليلات';

  @override
  String get bizPleaseCheckYourConnectionAnd =>
      'يرجى التحقق من اتصالك والمحاولة مرة أخرى.';

  @override
  String get bizPremiumListingAnalytics => 'تحليلات الإدراج المميز';

  @override
  String get bizViews => '👁️ المشاهدات';

  @override
  String get bizShares => '🔗 المشاركات';

  @override
  String get bizStoreVisits => '🛒 زيارات المتجر';

  @override
  String get bizLastSeen => '📅 آخر ظهور';

  @override
  String get bizStoreVisitsCustomersWhoVisited =>
      'زيارات المتجر: العملاء الذين زاروا المتجر';

  @override
  String get bizConversionRate => 'معدل التحويل';

  @override
  String get bizSimilarProducts => 'منتجات مشابهة';

  @override
  String get bizPaymentSuccessful => 'تمت عملية الدفع بنجاح!';

  @override
  String get bizYourPurchaseIsNowPending =>
      'عملية الشراء بانتظار موافقة الإدارة.';

  @override
  String get bizAdminWillReviewAndActivate =>
      'ستراجع الإدارة عملية الشراء وتفعّلها خلال 24 ساعة.';

  @override
  String get bizInfluencersAreComingSoon => 'المؤثرون قريبًا ✨';

  @override
  String get bizWeReBringingLocalCreators =>
      'نحضر لكم صنّاع المحتوى المحليين وتوصياتهم إلى OffrO. ترقبوا!';

  @override
  String get bizPeopleShapingTheCity => 'أشخاص يصنعون المدينة';

  @override
  String get bizLocalVoices => 'أصوات محلية';

  @override
  String get bizPleaseSelectAStarRating => 'يرجى اختيار تقييم بالنجوم أولًا';

  @override
  String get bizPleaseLogInToSubmit => 'يرجى تسجيل الدخول لإرسال مراجعة';

  @override
  String get bizPleaseWriteAtLeastA => 'يرجى كتابة بضع كلمات على الأقل';

  @override
  String get bizVERIFIEDLOCALVOICE => 'صوت محلي موثّق';

  @override
  String get bizRating => 'التقييم';

  @override
  String get bizRateThisInfluencer => 'قيّم هذا المؤثر';

  @override
  String get bizShareYourExperienceOptional => 'شارك تجربتك (اختياري)';

  @override
  String get bizUpdateReview => 'تحديث المراجعة';

  @override
  String get bizCreatorAccount => 'حساب صانع المحتوى';

  @override
  String get bizCREATORWORKSPACE => 'مساحة صانع المحتوى';

  @override
  String get bizProfileViews => 'مشاهدات الملف الشخصي';

  @override
  String get bizSavedBy => 'تم الحفظ بواسطة';

  @override
  String get bizYourProfileIsLive => 'ملفك الشخصي نشط';

  @override
  String get bizYourProfileIsnTLive => 'ملفك الشخصي غير نشط بعد';

  @override
  String get bizMerchantsAndCustomersCanDiscover =>
      'يمكن للتجار والعملاء اكتشافك.';

  @override
  String get bizOpenYourProfileToReview => 'افتح ملفك الشخصي لمراجعته ونشره.';

  @override
  String get bizMATCHEDFORYOU => 'مطابقة لك';

  @override
  String get bizCampaignOpportunities => 'فرص الحملات';

  @override
  String get bizINFLUENCERWORKSPACE => 'مساحة المؤثر';

  @override
  String get bizCreateYourLocalProfile => 'أنشئ ملفك المحلي.';

  @override
  String get bizYouLlNeedAnInfluencer =>
      'ستحتاج إلى ملف مؤثر لاستخدام قسم المؤثرين — فهو الطريقة التي يكتشفك بها العملاء والتجار على OffrO.';

  @override
  String get bizAddInfluencerProfile => '+ إضافة ملف مؤثر';

  @override
  String get bizNotAdded => 'غير مضاف';

  @override
  String get bizContinuePublishingPayNow => 'متابعة النشر / ادفع الآن';

  @override
  String get bizMyProfile => 'ملفي الشخصي';

  @override
  String get bizBusinessDetails => 'تفاصيل النشاط';

  @override
  String get bizDisplayName => 'الاسم المعروض';

  @override
  String get bizBio => 'النبذة';

  @override
  String get bizSocialPages => 'صفحات التواصل الاجتماعي';

  @override
  String get bizPrimarySpecialty => 'التخصص الرئيسي';

  @override
  String get bizNoSpecialtySelected => 'لم يتم اختيار تخصص';

  @override
  String get bizAccountDetails => 'تفاصيل الحساب';

  @override
  String get bizDisable => 'تعطيل';

  @override
  String get bizEnable => 'تفعيل';

  @override
  String get bizHideYourProfileFromCustomers => 'إخفاء ملفك الشخصي عن العملاء';

  @override
  String get bizMakeYourProfileVisibleAgain => 'إظهار ملفك الشخصي مرة أخرى';

  @override
  String get bizSwitchToYourCustomerAccount => 'التبديل إلى حساب العميل';

  @override
  String get bizYourProfileIsSavedAs =>
      'تم حفظ ملفك الشخصي كمسودة. أكمل دفعة الاشتراك لمرة واحدة من تعديل الملف ← حفظ ونشر ليصبح ظاهرًا للعملاء.';

  @override
  String get bizPaymentIsBeingProcessedIf =>
      'جارٍ معالجة الدفع. إذا أتممت الدفع ولم يتحدث الوضع، حاول الحفظ والنشر مرة أخرى.';

  @override
  String get bizYourLastSubscriptionPaymentAttempt =>
      'فشلت آخر محاولة لدفع الاشتراك. يرجى المحاولة مرة أخرى عبر حفظ ونشر لإتمام الدفع.';

  @override
  String get bizYourProfileIsNotYet => 'لم يتم نشر ملفك الشخصي بعد.';

  @override
  String get bizDeleteInfluencerProfile => 'حذف ملف المؤثر؟';

  @override
  String get bizAreYouSureYouWant =>
      'هل أنت متأكد أنك تريد حذف ملف المؤثر؟ لا يمكن التراجع عن هذا الإجراء.';

  @override
  String get bizIfYouCreateANew =>
      'إذا أنشأت ملف مؤثر جديدًا في المستقبل، فستكون هناك حاجة إلى دفعة اشتراك جديدة.';

  @override
  String get bizDeleteProfile => 'حذف الملف الشخصي';

  @override
  String get bizREVIEWS => 'المراجعات';

  @override
  String get bizCreatorReviews => 'مراجعات صانع المحتوى';

  @override
  String get bizNameIsRequired => 'الاسم مطلوب';

  @override
  String get bizPleaseSelectAState => 'يرجى اختيار الولاية';

  @override
  String get bizPleaseEnterAValid10 => 'يرجى إدخال رقم جوال صحيح من 10 أرقام.';

  @override
  String get bizProfileImageIsRequiredTo =>
      'صورة الملف الشخصي مطلوبة لنشر ملف المؤثر.';

  @override
  String get bizWeCouldnTConfirmYour =>
      'تعذر تأكيد الدفع. إذا تم خصم المبلغ فسيتم التحقق منه قريبًا — يرجى المحاولة مرة أخرى عبر حفظ ونشر بعد قليل.';

  @override
  String get bizCreatorIdentity => 'هوية صانع المحتوى';

  @override
  String get bizEditProfile => 'تعديل الملف الشخصي';

  @override
  String get bizAddProfile => 'إضافة ملف شخصي';

  @override
  String get bizRequiredToPublish => 'مطلوب للنشر';

  @override
  String get bizName => 'الاسم *';

  @override
  String get bizEGPriyaSharma => 'مثال: أحمد العلي';

  @override
  String get bizSharingTheBestLocalFood =>
      'أشارك أفضل المأكولات والمقاهي والمتاجر والعروض الرائعة في مدينتك.';

  @override
  String get bizState2 => 'الولاية *';

  @override
  String get bizSelectState => 'اختر الولاية';

  @override
  String get bizCity2 => 'المدينة *';

  @override
  String get bizSelectStateFirst => 'اختر الولاية أولًا';

  @override
  String get bizSelectCity => 'اختر المدينة';

  @override
  String get bizPrimarySpecialtySelectOneOr =>
      'التخصص الرئيسي (اختر واحدًا أو أكثر)';

  @override
  String get bizNoCategoriesAvailable => 'لا توجد فئات متاحة';

  @override
  String get biz10DigitMobileNumber => 'رقم جوال من 10 أرقام';

  @override
  String get bizSocialLinks => 'روابط التواصل الاجتماعي';

  @override
  String get bizInstagramURL => 'رابط Instagram';

  @override
  String get bizYouTubeURL => 'رابط YouTube';

  @override
  String get bizFacebookURL => 'رابط Facebook';

  @override
  String get bizSaveKeepAsDraft => 'حفظ (إبقاؤه كمسودة)';

  @override
  String get bizSavePublish => 'حفظ ونشر';

  @override
  String get bizSavePublishPayToPublish => 'حفظ ونشر (ادفع للنشر)';

  @override
  String get bizNoSubscriptionPaymentIsCurrently =>
      'لا يلزم حاليًا دفع اشتراك لنشر ملفك الشخصي.';

  @override
  String get bizSubscriptionFee => 'رسوم الاشتراك';

  @override
  String get bizDiscountCodeOptional => 'رمز الخصم (اختياري)';

  @override
  String get bizAOneTimePaymentYou =>
      'دفعة لمرة واحدة — لن يتم تحصيل رسوم مرة أخرى عند تعديل هذا الملف أو إعادة نشره.';

  @override
  String get bizEnterADiscountCodeFirst => 'أدخل رمز الخصم أولًا';

  @override
  String get bizSelectSpecialties => 'اختر التخصصات';

  @override
  String get bizCreateBrief => 'إنشاء ملخص';

  @override
  String get bizShareWhatYouNeedAnd => 'شارك ما تحتاجه وأين.';

  @override
  String get bizInviteCreators => 'دعوة صنّاع المحتوى';

  @override
  String get bizLocalCreatorsInYourCity =>
      'يراه صنّاع المحتوى المحليون في مدينتك.';

  @override
  String get bizConfirmMatch => 'تأكيد المطابقة';

  @override
  String get bizReviewWhoAcceptedAndConnect => 'راجع من وافق وتواصل معهم.';

  @override
  String get bizCreator => 'صانع المحتوى';

  @override
  String get bizCollaborations => 'التعاونات';

  @override
  String get bizWorkWithTrustedLocalCreators =>
      'تعاون مع صنّاع محتوى محليين موثوقين.';

  @override
  String get bizCreateOneClearCampaignBrief =>
      'أنشئ ملخص حملة واحدًا واضحًا، وراجع صنّاع المحتوى المطابقين وأكّد التعاون دون إدارة المحادثات عبر تطبيقات متعددة.';

  @override
  String get bizHowItWorks => 'كيف يعمل';

  @override
  String get bizCreateCampaignBrief => 'إنشاء ملخص الحملة';

  @override
  String get bizYourCampaigns => 'حملاتك';

  @override
  String get bizCollaborationWorkspace => 'مساحة التعاون';

  @override
  String get bizNoCampaignsYet => 'لا توجد حملات بعد';

  @override
  String get bizCreateYourFirstCampaignBrief =>
      'أنشئ أول ملخص حملة لدعوة صنّاع المحتوى المحليين.';

  @override
  String get bizWhenShouldYouUseThis => 'متى تستخدم هذا؟';

  @override
  String get bizUseCollaborationsForLaunchesVisits =>
      'استخدم التعاونات لإطلاق المنتجات والزيارات ومحتوى صنّاع المحتوى. أما تحديثات المتجر العادية والخصومات فمكانها البانرات أو العروض.';

  @override
  String get bizReviewProposals => 'مراجعة العروض المقدمة';

  @override
  String get bizCloseCampaign => 'إغلاق الحملة؟';

  @override
  String get bizCreatorsWillNoLongerBe =>
      'لن يتمكن صنّاع المحتوى من قبول هذا الملخص بعد الآن.';

  @override
  String get bizKeepOpen => 'إبقاؤها مفتوحة';

  @override
  String get bizCampaign => 'الحملة';

  @override
  String get bizProposals => 'العروض المقدمة';

  @override
  String get bizCreatorsWhoAccepted => 'صنّاع المحتوى الذين وافقوا';

  @override
  String get bizNoProposalsYet => 'لا توجد عروض بعد';

  @override
  String get bizCreatorsInYourCityWill =>
      'سيظهر صنّاع المحتوى في مدينتك هنا بمجرد قبولهم ملخصك.';

  @override
  String get bizClosing => 'جارٍ الإغلاق…';

  @override
  String get bizCloseCampaign2 => 'إغلاق الحملة';

  @override
  String get bizChatOnWhatsApp => 'مراسلة عبر WhatsApp';

  @override
  String get bizCouldnTOpenWhatsApp => 'تعذر فتح WhatsApp.';

  @override
  String get bizPleaseSelectAStore2 => 'يرجى اختيار متجر.';

  @override
  String get bizEnterACampaignTitleAt =>
      'أدخل عنوان الحملة (3 أحرف على الأقل).';

  @override
  String get bizSelectACampaignObjective => 'اختر هدف الحملة.';

  @override
  String get bizDescribeWhatTheCreatorShould =>
      'صف ما يجب أن يوصله صانع المحتوى (10 أحرف على الأقل).';

  @override
  String get bizSelectTheContentYouNeed => 'اختر المحتوى الذي تحتاجه.';

  @override
  String get bizChooseAPublishByDate => 'اختر تاريخ النشر النهائي.';

  @override
  String get bizChooseAVisitDateFor => 'اختر تاريخ الزيارة للمتجر.';

  @override
  String get bizVisitDateCanTBe =>
      'لا يمكن أن يكون تاريخ الزيارة بعد تاريخ النشر النهائي.';

  @override
  String get bizBriefPublishedMatchingCreatorsCan =>
      'تم نشر الملخص. يمكن لصنّاع المحتوى المطابقين رؤيته الآن.';

  @override
  String get bizCampaignBrief => 'ملخص الحملة';

  @override
  String get bizAddAndActivateAStore =>
      'أضف متجرًا وفعّله قبل إنشاء ملخص الحملة.';

  @override
  String get bizSelectStore2 => 'اختر المتجر';

  @override
  String get bizCampaignTitle => 'عنوان الحملة';

  @override
  String get bizExampleSeasonalMenuLaunch => 'مثال: إطلاق قائمة الموسم';

  @override
  String get bizCampaignObjective => 'هدف الحملة';

  @override
  String get bizSelectObjective => 'اختر الهدف';

  @override
  String get bizWhatShouldTheCreatorCommunicate =>
      'ماذا يجب أن يوصل صانع المحتوى؟';

  @override
  String get bizKeyMessageExperienceAndDetails =>
      'الرسالة الرئيسية والتجربة والتفاصيل التي ينبغي أن يعرفوها...';

  @override
  String get bizRequestedContent => 'المحتوى المطلوب';

  @override
  String get bizVisitDate => 'تاريخ الزيارة';

  @override
  String get bizSelectDate => 'اختر التاريخ';

  @override
  String get bizPublishBy => 'النشر قبل';

  @override
  String get bizPreferredCreatorSpeciality => 'تخصص صانع المحتوى المفضل';

  @override
  String get bizSelectSpeciality => 'اختر التخصص';

  @override
  String get bizNoPaymentProcessing => 'بدون معالجة مدفوعات';

  @override
  String get bizOffrOConnectsYouWithCreators =>
      'يربطك OffrO بصنّاع المحتوى. أي مقابل يُتفق عليه مباشرة بينك وبين صانع المحتوى.';

  @override
  String get bizPublishing => 'جارٍ النشر…';

  @override
  String get bizPublishBrief => 'نشر الملخص';

  @override
  String get bizMatchedLocally => 'مطابقة محليًا';

  @override
  String get bizReviewCollaborationRequestsFromReleva =>
      'راجع طلبات التعاون من التجار المعنيين في مدينتك.';

  @override
  String get bizNoCollaborationRequestsYet => 'لا توجد طلبات تعاون بعد';

  @override
  String get bizRequestsFromMerchantsInYour =>
      'ستظهر هنا الطلبات الواردة من التجار في مدينتك.';

  @override
  String get bizAccepted => 'مقبول';

  @override
  String get bizDeclined => 'مرفوض';

  @override
  String get bizNewCollaborationRequest => 'طلب تعاون جديد';

  @override
  String get bizViewBrief => 'عرض الملخص';

  @override
  String get bizNoCampaignRequestsYet => 'لا توجد طلبات حملات بعد';

  @override
  String get bizNewBriefsFromMerchantsIn =>
      'ستظهر هنا الملخصات الجديدة من التجار في مدينتك.';

  @override
  String get bizCollaborationAccepted => 'تم قبول التعاون.';

  @override
  String get bizRequestDeclined => 'تم رفض الطلب.';

  @override
  String get bizCollaborationRequest => 'طلب تعاون';

  @override
  String get bizBrief => 'الملخص';

  @override
  String get bizCompleteYourProfileSubscriptionTo =>
      'أكمل اشتراك ملفك الشخصي لقبول التعاونات.';

  @override
  String get bizObjective => 'الهدف';

  @override
  String get bizMessage => 'الرسالة';

  @override
  String get bizPreferredSpeciality => 'التخصص المفضل';

  @override
  String get bizThisCollaborationIsForPromotion =>
      'هذا التعاون للترويج على حسابك في Instagram. لا توجد محادثة داخل التطبيق.';

  @override
  String get bizYouAcceptedThisCollaboration => 'لقد قبلت هذا التعاون';

  @override
  String get bizTheMerchantSContactNumber =>
      'رقم التواصل الخاص بالتاجر غير متاح.';

  @override
  String get bizContactTheMerchantToPlan => 'تواصل مع التاجر لتخطيط زيارتك:';

  @override
  String get bizThisRequestIsNoLonger => 'هذا الطلب لم يعد مفتوحًا.';

  @override
  String get bizPleaseWait => 'يرجى الانتظار…';

  @override
  String get bizAcceptCollaboration => 'قبول التعاون';

  @override
  String get bizDecline => 'رفض';

  @override
  String bizFreeSlotsUsedOf(String used, String limit) {
    return 'تم استخدام $used/$limit من الفتحات المجانية';
  }

  @override
  String bizWelcomeBackName(String name) {
    return 'مرحبًا بعودتك، $name';
  }

  @override
  String bizBannerSubmittedMsg(String message) {
    return '✅ تم إرسال البانر! $message';
  }

  @override
  String get bizBannerFallbackDeal =>
      'إذا تمت إزالة هذا العرض لاحقًا، سيفتح البانر المتجر بدلًا منه.';

  @override
  String get bizBannerFallbackProduct =>
      'إذا تمت إزالة هذا المنتج لاحقًا، سيفتح البانر المتجر بدلًا منه.';

  @override
  String bizPaymentFailedMsg(String error) {
    return 'فشلت عملية الدفع: $error';
  }

  @override
  String bizToggleFailed(String error) {
    return 'تعذر التبديل: $error';
  }

  @override
  String bizFreeProductSlotsUsed(String used, String limit) {
    return 'تم استخدام $used / $limit من فتحات المنتجات المجانية';
  }

  @override
  String bizAdditionalProductsCharged(String price) {
    return 'تُحتسب المنتجات الإضافية بسعر $price عن كل يوم صلاحية.';
  }

  @override
  String bizDeleteProductBody(String title) {
    return 'سيتم حذف \"$title\" نهائيًا ولا يمكن إعادة تفعيله. لن يتم استرداد أي مبلغ تم دفعه لهذا المنتج.';
  }

  @override
  String get bizThisProduct => 'هذا المنتج';

  @override
  String bizDeleteError(String error) {
    return 'خطأ أثناء الحذف: $error';
  }

  @override
  String bizCodeAppliedPct(String value) {
    return '✅ تم تطبيق الرمز — خصم $value%!';
  }

  @override
  String bizCodeAppliedAmt(String value) {
    return '✅ تم تطبيق الرمز — خصم $value!';
  }

  @override
  String bizMaxValidity(String days) {
    return 'الحد الأقصى للصلاحية $days يومًا';
  }

  @override
  String bizProductSubmittedMsg(String message) {
    return '✅ تم إرسال المنتج! $message';
  }

  @override
  String bizPaymentErrorMsg(String error) {
    return 'خطأ في الدفع: $error';
  }

  @override
  String get bizCouldNotOpenPayment =>
      'تعذر فتح صفحة الدفع. يرجى المحاولة مرة أخرى.';

  @override
  String bizMaxDays(String days) {
    return 'الحد الأقصى $days يومًا';
  }

  @override
  String bizFreeSlotsRemaining(String remaining, String limit) {
    return 'لديك $remaining من أصل $limit فتحات منتجات مجانية متبقية.';
  }

  @override
  String bizFreeSlotsAllUsed(String limit, String price) {
    return 'لقد استخدمت جميع فتحات المنتجات المجانية البالغ عددها $limit.\nالسعر $price لليوم + ضريبة GST عن الأيام التي تختارها.';
  }

  @override
  String bizLocationUpdatedTo(String city) {
    return 'تم تحديث الموقع إلى $city';
  }

  @override
  String bizCouldNotGetLocation(String error) {
    return 'تعذر الحصول على الموقع: $error';
  }

  @override
  String get bizLocationPermissionNeeded =>
      'إذن الموقع مطلوب لتحديد الموقع الحالي. اسمح به وحاول مرة أخرى.';

  @override
  String get bizSetStoreLocationFirst =>
      'يرجى تحديد موقع المتجر باستخدام \"استخدام الموقع الحالي\" أو رابط خرائط Google قبل إنشاء المتجر.';

  @override
  String get bizStoreLocationIncomplete =>
      'يبدو موقع المتجر غير مكتمل. استخدم \"استخدام الموقع الحالي\" أو رابط خرائط Google لتحديد موقع صحيح.';

  @override
  String bizPaymentCancelledOrFailed(String error) {
    return 'تم إلغاء الدفع أو فشل: $error';
  }

  @override
  String bizExternalWallet(String name) {
    return 'محفظة خارجية: $name';
  }

  @override
  String bizDiscountAppliedPct(String value) {
    return '✅ تم تطبيق خصم $value%!';
  }

  @override
  String bizDiscountAppliedAmt(String value) {
    return '✅ تم تطبيق خصم $value!';
  }

  @override
  String get bizSubmittedPayRep =>
      '✅  تم إرسال طلب اشتراكك.\n\nيرجى دفع المبلغ إلى ممثل Offro الخاص بك.\nستفعّل الإدارة متجرك بمجرد تأكيد الدفع.';

  @override
  String bizEndDateExceedsStore(String date) {
    return 'لا يمكن أن يتجاوز تاريخ الانتهاء تاريخ انتهاء المتجر ($date)';
  }

  @override
  String bizCurrentEndDate(String date) {
    return 'تاريخ الانتهاء الحالي: $date';
  }

  @override
  String bizFreeSlotAvailable(String used, String limit) {
    return 'تتوفر فتحة منتج مجانية ($used من $limit قيد الاستخدام)، لذا فهذا التجديد مجاني.';
  }

  @override
  String bizAllFreeSlotsUsedRenew(String limit, String price) {
    return 'أنت تستخدم جميع فتحات المنتجات المجانية البالغ عددها $limit. يكلّف التجديد $price عن كل يوم يضاف + ضريبة GST.';
  }

  @override
  String bizViewersVisitedStore(String pct) {
    return 'زار $pct% من المشاهدين المتجر (ضغطوا على \"البائع\")';
  }

  @override
  String get bizProductsExpiringOne => 'منتج واحد ينتهي قريبًا — اضغط للتجديد';

  @override
  String bizProductsExpiringMany(String n) {
    return '$n منتجات تنتهي قريبًا — اضغط للتجديد';
  }

  @override
  String bizMoreFromStore(String store) {
    return 'المزيد من $store';
  }

  @override
  String get bizThisStore => 'هذا المتجر';

  @override
  String bizPurchasePendingNamed(String store) {
    return 'عملية شرائك لـ \"$store\" بانتظار موافقة الإدارة.';
  }

  @override
  String bizNoInfluencersInCity(String city) {
    return 'لا يوجد مؤثرون متاحون في $city حتى الآن';
  }

  @override
  String bizSeeAllCount(String count) {
    return 'عرض الكل ($count)';
  }

  @override
  String bizReviewsFor(String name) {
    return 'مراجعات $name';
  }

  @override
  String bizPublishByDate(String date) {
    return 'النشر قبل $date';
  }

  @override
  String bizSeeAllRequests(String count) {
    return 'عرض جميع الطلبات ($count)';
  }

  @override
  String get bizDeclinedCanAccept =>
      'لقد رفضت هذا الطلب. ما زال بإمكانك قبوله ما دام مفتوحًا.';

  @override
  String get bizDeclinedRequest => 'لقد رفضت هذا الطلب.';

  @override
  String get errPayNoMessage =>
      'تعذر إكمال عملية الدفع. يرجى المحاولة مرة أخرى.';

  @override
  String get errPayGeneric =>
      'لم نتمكن من إكمال عملية الدفع. يرجى المحاولة مرة أخرى.';

  @override
  String get errPayCancelled =>
      'تم إلغاء عملية الدفع. لم يتم خصم أي مبلغ منك. يمكنك المحاولة مرة أخرى متى شئت.';

  @override
  String get errPayPending =>
      'لم نتلقَّ تأكيد الدفع بعد. يرجى التحقق مرة أخرى بعد قليل قبل إعادة الدفع.';

  @override
  String get errPayNetwork =>
      'تعذر إكمال الدفع بسبب مشكلة في الاتصال. يرجى التحقق من الإنترنت والمحاولة مرة أخرى.';

  @override
  String bizStoresActiveOne(String active) {
    return 'متجر واحد • $active نشط';
  }

  @override
  String bizStoresActiveMany(String count, String active) {
    return '$count متاجر • $active نشط';
  }

  @override
  String bizNLive(String n) {
    return '$n نشط';
  }

  @override
  String bizNPending(String n) {
    return '$n قيد الانتظار';
  }

  @override
  String get bizSubmittedWord => 'تم الإرسال';

  @override
  String bizBannersStatusOne(String status) {
    return 'بانر واحد • $status';
  }

  @override
  String bizBannersStatusMany(String count, String status) {
    return '$count بانرات • $status';
  }

  @override
  String bizNDays(String n) {
    return '$n يوم';
  }

  @override
  String bizStartEndRange(String from, String end) {
    return 'البداية: $from   ←   النهاية: $end';
  }

  @override
  String bizFromDateLabel(String date) {
    return 'من: $date';
  }

  @override
  String bizUntilDateLabel(String date) {
    return 'حتى: $date';
  }

  @override
  String bizInvoiceColon(String no) {
    return 'الفاتورة: $no';
  }

  @override
  String bizPerDayPrice(String amount) {
    return '$amount/يوم';
  }

  @override
  String bizGstPct(String pct) {
    return 'ضريبة GST ($pct%)';
  }

  @override
  String bizPayAmount(String amount) {
    return 'ادفع $amount';
  }

  @override
  String bizPricePerDayTimesDays(String price, String days) {
    return '$price/يوم × $days يوم';
  }

  @override
  String bizDiscountTotalPct(String amount, String pct, String total) {
    return 'خصم −$amount ($pct%)  ←  الإجمالي: $total';
  }

  @override
  String bizDiscountTotalAmt(String amount, String total) {
    return 'خصم −$amount  ←  الإجمالي: $total';
  }

  @override
  String get bizResultOne => 'نتيجة واحدة';

  @override
  String bizResultMany(String n) {
    return '$n نتائج';
  }

  @override
  String bizExpiredOn(String date) {
    return 'انتهى في $date';
  }

  @override
  String bizExpiresOn(String date) {
    return 'ينتهي في $date';
  }

  @override
  String bizErrorColon(String error) {
    return 'خطأ: $error';
  }

  @override
  String bizDayTimesPriceOne(String days, String price) {
    return '$days يوم × $price/يوم';
  }

  @override
  String bizDayTimesPriceMany(String days, String price) {
    return '$days يوم × $price/يوم';
  }

  @override
  String bizFailedColon(String error) {
    return 'فشل: $error';
  }

  @override
  String get bizDealCountOne => 'عرض واحد';

  @override
  String bizDealCountMany(String n) {
    return '$n عروض';
  }

  @override
  String bizPricePlusGst(String price, String pct, String tax) {
    return '$price + $pct% ضريبة $tax';
  }

  @override
  String bizPlanPeriodLine(String plan, String from, String end) {
    return 'الخطة: $plan  •  $from – $end';
  }

  @override
  String bizBaseGstLine(String base, String gst, String tax) {
    return 'الأساس: $base  $tax: $gst';
  }

  @override
  String bizDiscountCodeLine(String code, String amount) {
    return 'الخصم ($code): −$amount';
  }

  @override
  String bizBannerTitleLine(String title) {
    return 'البانر: $title';
  }

  @override
  String bizProductTitleLine(String title) {
    return 'المنتج: $title';
  }

  @override
  String get bizUntitledWord => 'بدون عنوان';

  @override
  String bizEndsOn(String date) {
    return 'ينتهي في $date';
  }

  @override
  String bizDeleteDealNamed(String title) {
    return 'حذف \"$title\"؟';
  }

  @override
  String bizMaxDateLine(String date) {
    return 'الحد الأقصى: $date';
  }

  @override
  String bizRenewAmount(String amount) {
    return 'تجديد · $amount';
  }

  @override
  String bizCodeAppliedNamed(String code) {
    return 'تم تطبيق الرمز \'$code\'';
  }

  @override
  String bizNActive(String n) {
    return '$n نشط';
  }

  @override
  String bizVisitOn(String date) {
    return 'زيارة $date';
  }

  @override
  String bizCallPhone(String phone) {
    return 'اتصل بـ $phone';
  }

  @override
  String get bizAllProducts => 'كل المنتجات';

  @override
  String get bizAllStores => 'كل المتاجر';

  @override
  String get bizBannersTab => 'البانرات';

  @override
  String get bizPaymentsTab => 'المدفوعات';

  @override
  String get bizAdditionalProduct => 'منتج إضافي';

  @override
  String get bizBillingSubscriptions => 'الفواتير والاشتراكات';

  @override
  String bizTillDate(String date) {
    return 'حتى: $date';
  }

  @override
  String bizExpDate(String date) {
    return 'ينتهي: $date';
  }

  @override
  String get bizOneDayWord => 'يوم واحد';

  @override
  String bizDaysCountWord(String n) {
    return '$n يوم';
  }

  @override
  String get bizProposalOne => 'عرض واحد';

  @override
  String bizProposalMany(String n) {
    return '$n عروض';
  }

  @override
  String get bizInfluencerSubscription => 'اشتراك المؤثر';

  @override
  String get bizOffrOInfluencer => 'مؤثر OffrO';

  @override
  String get authEnterOtp4 => 'أدخل رمز التحقق المكوّن من 4 أرقام';

  @override
  String get authOtpIncorrect => 'رمز التحقق غير صحيح. يرجى المحاولة مرة أخرى.';

  @override
  String get authOtpVerifyFailed =>
      'تعذر التحقق من الرمز حاليًا. يرجى المحاولة مرة أخرى.';

  @override
  String get authCodeSentSms => 'تم إرسال الرمز عبر رسالة نصية.';

  @override
  String get authOtpResent => 'تمت إعادة إرسال الرمز بنجاح.';

  @override
  String get authResendFailed => 'فشلت إعادة الإرسال.';

  @override
  String get authOtpResendFailed =>
      'تعذرت إعادة إرسال الرمز حاليًا. يرجى المحاولة مرة أخرى.';

  @override
  String get authSettingUpAccount => 'جارٍ إعداد حسابك...';

  @override
  String authPreparingDashboard(String dots) {
    return 'جارٍ تجهيز لوحة نشاطك التجاري$dots';
  }

  @override
  String get authLoadingBusinessData =>
      'جارٍ تحميل المتاجر والمنتجات والنشاط...';

  @override
  String get authEnterYourName => 'أدخل اسمك';

  @override
  String get authAcceptTermsRequired =>
      'يرجى تحديد المربع لقبول الشروط والأحكام وسياسة الخصوصية والموافقة على تحديثات WhatsApp من OffrO للمتابعة';

  @override
  String get authAlreadyRegistered =>
      'هذا الرقم مسجّل بالفعل. يرجى تسجيل الدخول.';

  @override
  String get authNotRegistered => 'هذا الرقم غير مسجّل. يرجى التسجيل أولًا.';

  @override
  String get authOtpSendFailed =>
      'تعذر إرسال الرمز حاليًا. يرجى المحاولة مرة أخرى.';

  @override
  String get authLoginFailed => 'فشل تسجيل الدخول — يرجى المحاولة مرة أخرى.';

  @override
  String get authAgreeTo => 'أوافق على';

  @override
  String get authAnd => 'و';

  @override
  String get authConsentWhatsApp =>
      'وأوافق على تلقي التحديثات والرسائل الترويجية من OffrO عبر WhatsApp.';

  @override
  String get authMerchantTermsTitle => 'شروط وأحكام التاجر';

  @override
  String get authMerchantTermsEmpty => 'ستُنشر شروط وأحكام التاجر هنا.';

  @override
  String get authAgreeMerchantTerms => 'أوافق على شروط التاجر';

  @override
  String get authAcceptContinue => 'قبول ومتابعة';

  @override
  String get phoneEnterNumber => 'أدخل رقم جوالك';

  @override
  String get phoneInvalid10 => 'أدخل رقم جوال صحيحًا من 10 أرقام';

  @override
  String phoneInvalidCountry(String country) {
    return 'أدخل رقم جوال صحيحًا في $country';
  }

  @override
  String get countryNameIN => 'الهند';

  @override
  String get countryNameJO => 'الأردن';

  @override
  String get countryNameNP => 'نيبال';

  @override
  String get countryNamePH => 'الفلبين';

  @override
  String get countryNameSA => 'المملكة العربية السعودية';

  @override
  String get locGateTitle => 'السماح بالوصول إلى الموقع';

  @override
  String get locGateBody =>
      'يحتاج OffrO إلى موقعك لعرض المحتوى القريب والمناسب لك.';

  @override
  String get locGateBlockedMsg =>
      'إذن الموقع متوقف لتطبيق OffrO. يمكنك السماح به من إعدادات التطبيق، أو اختيار مدينتك يدويًا.';

  @override
  String get locGateServiceOffMsg =>
      'خدمات الموقع في جهازك متوقفة. شغّلها، أو اختر مدينتك يدويًا.';

  @override
  String get locGateDeniedMsg =>
      'لم يتم السماح بإذن الموقع. ما زال بإمكانك اختيار مدينتك يدويًا.';

  @override
  String get locGateOpenSettings => 'فتح إعدادات التطبيق';

  @override
  String get locGateAllow => 'السماح بالموقع';

  @override
  String get locGateChooseManually => 'اختيار المدينة يدويًا';

  @override
  String get locCardChecking => 'جارٍ التحقق من الموقع…';

  @override
  String get locCardServicesOff => 'خدمات الموقع متوقفة';

  @override
  String get locCardServicesOffSub =>
      'شغّل موقع جهازك لعرض الأماكن القريبة منك';

  @override
  String get locCardEnablePerm => 'فعّل أذونات الموقع';

  @override
  String get locCardEnablePermSub => 'للحصول على اقتراحات أنسب بالقرب منك';

  @override
  String get locCardBlocked => 'إذن الموقع محظور';

  @override
  String get locCardBlockedSub =>
      'اسمح بالموقع لتطبيق OffrO من إعدادات التطبيق';

  @override
  String get locCardDetecting => 'جارٍ تحديد موقعك…';

  @override
  String locCardTapRetry(String error) {
    return '$error اضغط لإعادة المحاولة.';
  }

  @override
  String get splashTagline => 'اكتشف · وفّر · اكسب';

  @override
  String get commonBack => 'رجوع';

  @override
  String get stateErrorTitle => 'تعذر تحميل هذا المحتوى';

  @override
  String get stateErrorMessage => 'تحقق من اتصالك وحاول مرة أخرى.';

  @override
  String get notifDiagTitle => 'تشخيص الإشعارات';

  @override
  String get notifDiagRegStatusTitle => 'حالة تسجيل FCM';

  @override
  String get notifDiagCopy => 'نسخ';

  @override
  String get notifDiagRecheck => 'إعادة الفحص';

  @override
  String get notifDiagTokenCopied => 'تم نسخ رمز FCM';

  @override
  String get notifDiagCopiedToClipboard => 'تم نسخ التشخيص إلى الحافظة';

  @override
  String get notifDiagClear => 'مسح';

  @override
  String get notifDiagClearLogTitle => 'مسح السجل؟';

  @override
  String get notifDiagClearLogBody =>
      'سيؤدي هذا إلى إزالة جميع سجلات أحداث الإشعارات.';

  @override
  String get notifDiagEmptyTitle => 'لا توجد أحداث مسجّلة بعد';

  @override
  String get notifDiagEmptyHint =>
      'أرسل إشعارًا ثم عد لاحقًا\nلمعرفة المعالجات التي عملت';

  @override
  String get notifDiagRefresh => 'تحديث';

  @override
  String get notifDiagChecking => 'جارٍ الفحص...';

  @override
  String notifDiagSecondsAgo(String n) {
    return 'منذ $n ث';
  }
}
