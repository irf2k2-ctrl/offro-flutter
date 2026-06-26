// lib/screens/splash/splash_screen.dart
// OFFRO — Splash / boot screen

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/constants/app_constants.dart';
import '../../core/services/api_service.dart';
import '../../core/services/prefs_service.dart';
import '../../core/widgets/brand_logo.dart';

// SplashScreen uses callbacks to navigate — avoids circular imports with main.dart.
// main.dart is responsible for passing the correct navigation callbacks.

class SplashScreen extends StatefulWidget {
  final void Function(String token, String name, String phone, String city, String userId)? onUser;
  final void Function(String token, Map merchant)? onMerchant;
  final void Function()? onOnboarding;
  final void Function()? onLogin;

  const SplashScreen({
    super.key,
    this.onUser,
    this.onMerchant,
    this.onOnboarding,
    this.onLogin,
  });

  @override State<SplashScreen> createState() => _SplashState();
}

class _SplashState extends State<SplashScreen> with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _fade;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 900));
    _fade = CurvedAnimation(parent: _ctrl, curve: Curves.easeIn);
    _ctrl.forward();
    _checkLogin();
  }

  @override void dispose() { _ctrl.dispose(); super.dispose(); }

  Future<void> _checkLogin() async {
    await Future.delayed(const Duration(milliseconds: 2200));
    if (!mounted) return;
    final u = await Prefs.get();
    final token = u["token"];
    final role  = u["role"] ?? "user";

    if (token != null && token.isNotEmpty) {
      try {
        if (role == "merchant") {
          final me = await Api.getMerchantMe(token);
          if (me != null && mounted) { widget.onMerchant?.call(token, me); return; }
          // getMerchantMe returned null → 401/403 → invalid token
          await Prefs.clear();
        } else {
          final me = await Api.getMe(token);
          if (me != null && mounted) {
            final savedCity = u["city"] ?? "";
            widget.onUser?.call(
              token,
              me["name"]?.toString() ?? "",
              me["phone"]?.toString() ?? me["_id"]?.toString() ?? "",
              savedCity,
              me["_id"]?.toString() ?? me["user_id"]?.toString() ?? "",
            );
            return;
          }
          // getMe returned null → 401/403 → invalid token
          await Prefs.clear();
        }
      } catch (e) {
        // Network/timeout error — DO NOT clear token or go to login.
        // Use saved session data so the user stays logged in when offline/cold start.
        debugPrint('[OFFRO] splash: network error during session check — using saved session. $e');
        final savedCity = u["city"] ?? "";
        final savedName = u["name"] ?? "";
        final savedPhone = u["phone"] ?? "";
        final savedId    = u["user_id"] ?? "";
        if (mounted) {
          if (role == "merchant") {
            // Build minimal merchant map from saved prefs
            final merchantMap = {
              "_id": savedId, "name": savedName, "phone": savedPhone,
              "city": savedCity, "token": token,
            };
            widget.onMerchant?.call(token, merchantMap);
          } else {
            widget.onUser?.call(token, savedName, savedPhone, savedCity, savedId);
          }
          return;
        }
      }
    }
    if (!mounted) return;
    final prefs2 = await SharedPreferences.getInstance();
    final onboardingDone = prefs2.getBool('onboarding_done') ?? false;
    if (!mounted) return;
    if (onboardingDone) {
      widget.onLogin?.call();
    } else {
      widget.onOnboarding?.call();
    }
  }

  @override
  Widget build(BuildContext context) {
    // White status bar icons (on white bg use dark icons)
    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
    ));
    return Scaffold(
      // ── Original OFFRO splash: white background + centered green logo ──
      backgroundColor: Colors.white,
      body: FadeTransition(
        opacity: _fade,
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // ── OFFRO Logo — white background, green logo ──
              buildImageLogo(height: 110, white: false),
              const SizedBox(height: 14),
              const Text(
                "Discover · Save · Earn",
                style: TextStyle(
                  color: kMuted,
                  fontSize: 12,
                  letterSpacing: 1.8,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 48),
              const SizedBox(
                width: 22, height: 22,
                child: CircularProgressIndicator(
                  color: kPrimary,
                  strokeWidth: 2.0,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
