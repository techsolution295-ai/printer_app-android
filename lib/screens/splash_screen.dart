import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../ads/app_open_ad_service.dart';
import '../services/app_language_config.dart';
import '../services/billing_service.dart';
import 'language_selection_screen.dart';
import 'main_screen.dart';
import 'pro_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  static const _brandBlue = Color(0xFF4D6FA6);
  static const _openedKey = 'has_opened_before';
  static const _firstLaunchAdWait = Duration(seconds: 12);
  static const _laterLaunchAdWait = Duration(seconds: 7);

  late final AnimationController _controller;
  late final Animation<double> _fadeAnimation;
  late final Animation<double> _scaleAnimation;
  bool _hasNavigated = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _fadeAnimation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOut,
    );
    _scaleAnimation = Tween<double>(begin: 0.88, end: 1).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutBack),
    );
    _controller.forward();
    _startSplashSequence();
  }

  Future<void> _startSplashSequence() async {
    final prefs = await SharedPreferences.getInstance();
    final firstLaunch = prefs.getBool(_openedKey) != true;

    await BillingService.instance.whenCached.timeout(
      const Duration(seconds: 2),
      onTimeout: () {},
    );
    if (BillingService.instance.isPro) {
      await BillingService.instance.whenReady.timeout(
        const Duration(seconds: 3),
        onTimeout: () {},
      );
    }
    if (!mounted) return;
    if (BillingService.instance.isPro) {
      await _rememberLaunch(prefs);
      await _routeNext();
      return;
    }

    // First install gives the SDK time to fetch an app-open ad. Later opens
    // still wait, but not as long.
    await AppOpenAdManager.instance.showAdIfAvailable(
      loadTimeout: firstLaunch ? _firstLaunchAdWait : _laterLaunchAdWait,
    );
    if (!mounted) return;

    await _rememberLaunch(prefs);
    await _routeNext();
  }

  Future<void> _rememberLaunch(SharedPreferences prefs) async {
    if (prefs.getBool(_openedKey) == true) return;
    await prefs.setBool(_openedKey, true);
  }

  Future<void> _routeNext() async {
    if (_hasNavigated || !mounted) return;
    _hasNavigated = true;
    final savedLanguage = await AppLanguageConfig.savedCountryId();
    if (!mounted) return;
    final Widget next;
    if (savedLanguage == null) {
      next = const LanguageSelectionScreen();
    } else if (!BillingService.instance.isPro) {
      next = const ProScreen();
    } else {
      next = const MainScreen();
    }
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => next),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFFF8FBFF), Color(0xFFEAF2FA), Color(0xFFDCEAF7)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              const Spacer(flex: 3),
              FadeTransition(
                opacity: _fadeAnimation,
                child: ScaleTransition(
                  scale: _scaleAnimation,
                  child: Image.asset(
                    'assets/images/splash_logo.png',
                    width: 168,
                    height: 168,
                    fit: BoxFit.contain,
                  ),
                ),
              ),
              const SizedBox(height: 18),
              FadeTransition(
                opacity: _fadeAnimation,
                child: Text(
                  'splash_tagline'.tr(),
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: Color(0xFF6B7A96),
                  ),
                ),
              ),
              const Spacer(flex: 2),
              FadeTransition(
                opacity: _fadeAnimation,
                child: const SpinKitWave(
                  color: _brandBlue,
                  size: 36,
                  itemCount: 5,
                ),
              ),
              const SizedBox(height: 14),
              FadeTransition(
                opacity: _fadeAnimation,
                child: Text(
                  'loading'.tr(),
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF8A9BB5),
                    letterSpacing: 0.4,
                  ),
                ),
              ),
              const Spacer(flex: 1),
            ],
          ),
        ),
      ),
    );
  }
}
