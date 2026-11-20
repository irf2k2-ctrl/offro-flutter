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
  String walletVoucherRate(String points) {
    return '$points نقطة = قسيمة ₹20';
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
  String get walletVoucherDesc => 'قسيمة هدية ترويجية · أمازون أو فليبكارت';

  @override
  String walletEarnMore(String points) {
    return 'اكسب $points نقطة إضافية';
  }

  @override
  String get walletHowTitle => 'كيف تعمل المكافآت';

  @override
  String get walletHowLine1 =>
      'استبدل 200 نقطة مكافآت بقسيمة هدية ترويجية بقيمة ₹20.';

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
}
