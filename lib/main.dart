import 'dart:async';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:smart_printer/ads/ad_service.dart';
import 'package:smart_printer/config/pro_theme.dart';
import 'package:smart_printer/ads/app_open_ad_service.dart';
import 'package:smart_printer/screens/splash_screen.dart';
import 'package:smart_printer/services/app_language_config.dart';
import 'package:smart_printer/services/billing_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  SystemChrome.setSystemUIOverlayStyle(AppTheme.lightScreenOverlay);
  await EasyLocalization.ensureInitialized();
  await AdService.instance.initialize();
  AppOpenAdManager.instance.loadAd();
  unawaited(BillingService.instance.initialize());

  final savedId = await AppLanguageConfig.savedCountryId();
  final startLocale = savedId == null
      ? const Locale('en')
      : AppLanguageConfig.optionById(savedId).locale;

  runApp(
    EasyLocalization(
      supportedLocales: AppLanguageConfig.supportedLocales,
      path: 'assets/translations',
      fallbackLocale: const Locale('en'),
      startLocale: startLocale,
      useFallbackTranslations: true,
      useFallbackTranslationsForEmptyResources: true,
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Smart Printer',
      locale: context.locale,
      supportedLocales: context.supportedLocales,
      localizationsDelegates: context.localizationDelegates,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: AppTheme.actionColor,
          primary: AppTheme.actionColor,
        ),
        useMaterial3: true,
        scaffoldBackgroundColor: AppTheme.pageBackground,
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.white,
          foregroundColor: AppTheme.textDark,
          elevation: 0,
          scrolledUnderElevation: 0,
          surfaceTintColor: Colors.transparent,
          systemOverlayStyle: AppTheme.lightScreenOverlay,
        ),
      ),
      builder: (context, child) {
        return AnnotatedRegion<SystemUiOverlayStyle>(
          value: AppTheme.lightScreenOverlay,
          child: child ?? const SizedBox.shrink(),
        );
      },
      home: const SplashScreen(),
    );
  }
}
