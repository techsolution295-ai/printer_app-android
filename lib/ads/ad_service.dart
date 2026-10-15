import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:smart_printer/services/billing_service.dart';

class AdService {
  AdService._();
  static final AdService instance = AdService._();

  // Google sample / debug unit IDs.
  static const _testBannerId = 'ca-app-pub-3940256099942544/6300978111';
  static const _testInterstitialId = 'ca-app-pub-3940256099942544/1033173712';
  static const _testAppOpenId = 'ca-app-pub-3940256099942544/9257395921';

  // Production units. Release builds request these; debug stays on Google test ads.
  static const _productionBannerId = 'ca-app-pub-6952052496235990/3880219967';
  static const _productionInterstitialId = 'ca-app-pub-6952052496235990/4660703183';
  static const _productionAppOpenId = 'ca-app-pub-6952052496235990/3389265370';

  // Only a release build uses real units. Debug and profile stay on Google test ads.
  bool get _useRealAds => kReleaseMode;

  String get bannerAdUnitId => _useRealAds ? _productionBannerId : _testBannerId;

  String get interstitialAdUnitId =>
      _useRealAds ? _productionInterstitialId : _testInterstitialId;

  String get appOpenAdUnitId => _useRealAds ? _productionAppOpenId : _testAppOpenId;

  bool _initialized = false;
  bool _watchingPro = false;
  InterstitialAd? _interstitialAd;
  bool _loadingInterstitial = false;
  bool _showingInterstitial = false;

  bool get isProUser => BillingService.instance.isPro;

  Future<void> initialize() async {
    if (_initialized) {
      return;
    }
    _initialized = true;
    if (!_watchingPro) {
      _watchingPro = true;
      BillingService.instance.addListener(_onProChanged);
    }
    await MobileAds.instance.initialize();
    debugPrint(
      _useRealAds
          ? 'AdService: RELEASE — real ads'
          : 'AdService: DEBUG — Google test ads',
    );
    if (isProUser) return;
    _loadInterstitial();
  }

  void _onProChanged() {
    if (isProUser) {
      _interstitialAd?.dispose();
      _interstitialAd = null;
      _loadingInterstitial = false;
      return;
    }
    _loadInterstitial();
  }

  void _loadInterstitial() {
    if (isProUser) {
      _interstitialAd?.dispose();
      _interstitialAd = null;
      return;
    }
    if (_interstitialAd != null || _loadingInterstitial) {
      return;
    }
    _loadingInterstitial = true;
    InterstitialAd.load(
      adUnitId: interstitialAdUnitId,
      request: const AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (ad) {
          _interstitialAd = ad;
          _loadingInterstitial = false;
        },
        onAdFailedToLoad: (error) {
          _loadingInterstitial = false;
          if (kDebugMode) {
            debugPrint('Interstitial failed to load: $error');
          }
        },
      ),
    );
  }

  /// Feature / tool / printable select.
  Future<void> showSelectInterstitialThen(FutureOr<void> Function() action) {
    return _showInterstitialOrContinue(action);
  }

  /// Print / Save / Download / Convert.
  Future<void> showInterstitialThen(FutureOr<void> Function() action) {
    return _showInterstitialOrContinue(action);
  }

  Future<void> _showInterstitialOrContinue(FutureOr<void> Function() action) async {
    if (isProUser) {
      await action();
      return;
    }
    if (_showingInterstitial) {
      await action();
      return;
    }

    if (_interstitialAd == null) {
      _loadInterstitial();
      final deadline = DateTime.now().add(const Duration(seconds: 4));
      while (_interstitialAd == null && DateTime.now().isBefore(deadline)) {
        if (!_loadingInterstitial) {
          _loadInterstitial();
        }
        await Future<void>.delayed(const Duration(milliseconds: 250));
      }
    }

    final ad = _interstitialAd;
    if (ad == null) {
      if (kDebugMode) {
        debugPrint('Interstitial unavailable — continuing action');
      }
      await action();
      _loadInterstitial();
      return;
    }

    final completer = Completer<void>();
    ad.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (shown) {
        shown.dispose();
        _interstitialAd = null;
        _showingInterstitial = false;
        if (!completer.isCompleted) {
          completer.complete();
        }
        _loadInterstitial();
      },
      onAdFailedToShowFullScreenContent: (shown, error) {
        shown.dispose();
        _interstitialAd = null;
        _showingInterstitial = false;
        if (!completer.isCompleted) {
          completer.complete();
        }
        _loadInterstitial();
      },
    );

    _interstitialAd = null;
    _showingInterstitial = true;
    try {
      await ad.show();
      await completer.future;
    } catch (error) {
      if (kDebugMode) {
        debugPrint('Interstitial show error: $error');
      }
      _showingInterstitial = false;
      try {
        ad.dispose();
      } catch (_) {}
      if (!completer.isCompleted) {
        completer.complete();
      }
      _loadInterstitial();
    }

    try {
      await action();
    } finally {
      if (!_loadingInterstitial && _interstitialAd == null) {
        _loadInterstitial();
      }
    }
  }
}

/// Shows a full-screen ad, then runs print or save.
void Function() afterInterstitial(FutureOr<void> Function() action) {
  return () {
    AdService.instance.showInterstitialThen(action);
  };
}
