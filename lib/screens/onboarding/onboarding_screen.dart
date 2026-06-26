// lib/screens/onboarding/onboarding_screen.dart
// OFFRO — Onboarding (3-slide flow)

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/constants/app_constants.dart';
import '../../core/widgets/brand_logo.dart';
import '../auth/login_screen.dart';

PageRoute _onbRoute(Widget w) => MaterialPageRoute(builder: (_) => w);

class OnboardingScreen extends StatefulWidget {
  final VoidCallback? onComplete;
  const OnboardingScreen({super.key, this.onComplete});
  @override State<OnboardingScreen> createState() => _OnboardingState();
}

class _OnboardingState extends State<OnboardingScreen> {
  final PageController _pc = PageController();
  int _idx = 0;

  @override void initState() {
    super.initState();
    // Force transparent status bar so images fill edge-to-edge
    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
    ));
  }

  static const List<Map<String, String>> _slides = [
    {
      "webp": "assets/onboarding/screen1.webp",
      "png":  "assets/onboarding/screen1.png",
      "title": "Discover Local Deals",
      "subtitle": "Find the best offers from stores near you",
    },
    {
      "webp": "assets/onboarding/screen2.webp",
      "png":  "assets/onboarding/screen2.png",
      "title": "Earn Reward Points",
      "subtitle": "Every visit earns you points you can redeem",
    },
    {
      "webp": "assets/onboarding/screen3.webp",
      "png":  "assets/onboarding/screen3.png",
      "title": "Get Gift Vouchers",
      "subtitle": "Redeem your points for Amazon & Flipkart vouchers",
    },
  ];

  @override void dispose() {
    _pc.dispose();
    // Restore default overlay style when leaving onboarding
    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
    ));
    super.dispose();
  }

  Future<void> _goToLogin() async {
    if (!mounted) return;
    // Always save onboarding_done so Skip and Get Started both work correctly
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('onboarding_done', true);
    if (!mounted) return;
    if (widget.onComplete != null) {
      widget.onComplete!();
    } else {
      Navigator.pushReplacement(context, _onbRoute(const LoginScreen()));
    }
  }

  @override Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);

    return PopScope(
      canPop: _idx == 0,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && _idx > 0) {
          _pc.previousPage(
              duration: const Duration(milliseconds: 320), curve: Curves.easeInOut);
        }
      },
      child: Scaffold(
        backgroundColor: Colors.white,
        extendBodyBehindAppBar: true,
        body: Stack(children: [

          // ── Full-screen PageView (no SafeArea — fills edge to edge) ──
          Positioned.fill(
            child: PageView.builder(
              controller: _pc,
              itemCount: _slides.length,
              onPageChanged: (i) => setState(() => _idx = i),
              itemBuilder: (_, i) {
                final slide = _slides[i];
                return _OnboardingSlide(
                  webp: slide["webp"]!,
                  png:  slide["png"]!,
                  title: slide["title"]!,
                  subtitle: slide["subtitle"]!,
                  isLast: i == _slides.length - 1,
                  onGetStarted: _goToLogin,
                );
              },
            ),
          ),

          // ── Skip button — top-right with safe area offset ──
          if (_idx < _slides.length - 1)
            Positioned(
              top: mq.padding.top + 12,
              right: 16,
              child: GestureDetector(
                onTap: _goToLogin,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
                  decoration: BoxDecoration(
                    color: kPrimary.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: kPrimary.withOpacity(0.25)),
                  ),
                  child: const Text(
                    "Skip",
                    style: TextStyle(
                      color: kPrimary,
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                    ),
                  ),
                ),
              ),
            ),
        ]),
      ),
    );
  }
}

// ── Get Started button — debounced, saves onboarding flag ──
class _GetStartedButton extends StatefulWidget {
  final VoidCallback onTap;
  const _GetStartedButton({required this.onTap});
  @override State<_GetStartedButton> createState() => _GetStartedButtonState();
}
class _GetStartedButtonState extends State<_GetStartedButton> {
  bool _tapped = false;
  Future<void> _handle() async {
    if (_tapped) return;
    setState(() => _tapped = true);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('onboarding_done', true);
    widget.onTap();
  }
  @override Widget build(BuildContext context) => GestureDetector(
    onTap: _tapped ? null : _handle,
    behavior: HitTestBehavior.translucent,   // captures taps even over transparent area
    child: AnimatedOpacity(
      opacity: _tapped ? 0.0 : 1.0,
      duration: const Duration(milliseconds: 200),
      child: const SizedBox.expand(),        // fills the tap zone, invisible over the image
    ),
  );
}

// ── Single onboarding slide: image fills available space, fallback chain webp→png→branded ──
class _OnboardingSlide extends StatefulWidget {
  final String webp, png, title, subtitle;
  final bool isLast;
  final VoidCallback? onGetStarted;
  const _OnboardingSlide({
    required this.webp, required this.png,
    required this.title, required this.subtitle,
    this.isLast = false, this.onGetStarted,
  });
  @override State<_OnboardingSlide> createState() => _OnboardingSlideSt();
}

class _OnboardingSlideSt extends State<_OnboardingSlide> {
  bool _webpFailed = false;
  bool _pngFailed  = false;

  @override Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);

    Widget imageWidget;
    // Image fills the full slide; ConstrainedBox keeps max width on tablets
    final imgFit = BoxFit.contain;

    if (!_webpFailed) {
      imageWidget = SizedBox.expand(
        child: Image.asset(
          widget.webp,
          fit: imgFit,
          alignment: Alignment.center,
          errorBuilder: (_, __, ___) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) setState(() => _webpFailed = true);
            });
            return const SizedBox.shrink();
          },
        ),
      );
    } else if (!_pngFailed) {
      imageWidget = SizedBox.expand(
        child: Image.asset(
          widget.png,
          fit: imgFit,
          alignment: Alignment.center,
          errorBuilder: (_, __, ___) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) setState(() => _pngFailed = true);
            });
            return const SizedBox.shrink();
          },
        ),
      );
    } else {
      // Both images failed — branded fallback, no fixed heights
      imageWidget = Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF3E5F55), Color(0xFF2a4039)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: mq.size.width * 0.25,
              height: mq.size.width * 0.25,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.15),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.local_offer_rounded, color: Colors.white, size: 48),
            ),
            SizedBox(height: mq.size.height * 0.04),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: mq.size.width * 0.1),
              child: Text(
                widget.title,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: mq.size.width * 0.065,
                  fontWeight: FontWeight.w900,
                  height: 1.2,
                ),
              ),
            ),
            SizedBox(height: mq.size.height * 0.02),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: mq.size.width * 0.12),
              child: Text(
                widget.subtitle,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: mq.size.width * 0.038,
                  height: 1.5,
                ),
              ),
            ),
          ],
        ),
      );
    }

    // For the last slide: wrap with tap zone at the bottom so "Let's Get Started"
    // button baked into the image is tappable → navigates to login.
    if (widget.isLast && widget.onGetStarted != null) {
      return Stack(children: [
        Positioned.fill(child: imageWidget),
        // Transparent tap zone covers the bottom ~25% of screen (button area)
        Positioned(
          left: 0, right: 0, bottom: 0,
          height: mq.size.height * 0.20,
          child: _GetStartedButton(onTap: widget.onGetStarted!),
        ),
      ]);
    }
    return imageWidget;
  }
}


// ─────────────────────── LOGIN SCREEN ───────────────────────
