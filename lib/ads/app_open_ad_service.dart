import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import 'package:smart_printer/services/billing_service.dart';

import 'ad_service.dart';

class AppOpenAdManager {
  AppOpenAdManager._();
  static final AppOpenAdManager instance = AppOpenAdManager._();

  static const _maxAttempts = 3;

  AppOpenAd? _appOpenAd;
  bool _showing = false;
  bool _loading = false;
  int _ticket = 0;
  Completer<bool>? _loadCompleter;

  bool get _isProUser => BillingService.instance.isPro;

  void _dropLoadedAd() {
    _appOpenAd?.dispose();
    _appOpenAd = null;
  }

  Future<bool> loadAd() {
    if (_isProUser) {
      _dropLoadedAd();
      return Future.value(false);
    }
    if (_appOpenAd != null) {
      return Future.value(true);
    }
    if (_loading) {
      return _loadCompleter?.future ?? Future.value(false);
    }

    _loadCompleter = Completer<bool>();
    _loading = true;
    _startLoad(1);
    return _loadCompleter!.future;
  }

  void _startLoad(int attempt) {
    final ticket = ++_ticket;
    Timer(const Duration(seconds: 5), () {
      _failAttempt(attempt, ticket, 'timed out');
    });

    try {
      AppOpenAd.load(
        adUnitId: AdService.instance.appOpenAdUnitId,
        request: const AdRequest(),
        adLoadCallback: AppOpenAdLoadCallback(
          onAdLoaded: (ad) {
            if (ticket != _ticket || _isProUser) {
              ad.dispose();
              if (_isProUser) _finish(false);
              return;
            }
            _ticket++;
            _appOpenAd = ad;
            debugPrint('App open ad loaded on attempt $attempt');
            _finish(true);
          },
          onAdFailedToLoad: (error) {
            _failAttempt(attempt, ticket, error);
          },
        ),
      );
    } on PlatformException catch (error) {
      _failAttempt(attempt, ticket, error);
    }
  }

  void _failAttempt(int attempt, int ticket, Object error) {
    if (ticket != _ticket) return;
    _ticket++;
    debugPrint('App open ad attempt $attempt failed: $error');
    if (_isProUser || attempt >= _maxAttempts) {
      _dropLoadedAd();
      _finish(false);
      return;
    }
    Future<void>.delayed(Duration(milliseconds: 700 * attempt), () {
      if (_isProUser) {
        _finish(false);
        return;
      }
      if (_loadCompleter == null || _loadCompleter!.isCompleted) return;
      _startLoad(attempt + 1);
    });
  }

  void _finish(bool success) {
    _loading = false;
    final completer = _loadCompleter;
    _loadCompleter = null;
    if (completer != null && !completer.isCompleted) {
      completer.complete(success);
    }
  }

  Future<bool> showAdIfAvailable({Duration? loadTimeout}) async {
    if (_isProUser) {
      _dropLoadedAd();
      return false;
    }
    if (_showing) {
      return false;
    }

    final loadFuture = loadAd();
    final loaded = loadTimeout == null
        ? await loadFuture
        : await loadFuture.timeout(
            loadTimeout,
            onTimeout: () => _appOpenAd != null,
          );
    if (_isProUser || !loaded || _appOpenAd == null) {
      return false;
    }

    final completer = Completer<void>();
    var didShow = false;
    _showing = true;
    final ad = _appOpenAd!;

    ad.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (shown) {
        shown.dispose();
        _appOpenAd = null;
        _showing = false;
        if (!completer.isCompleted) {
          completer.complete();
        }
        loadAd();
      },
      onAdFailedToShowFullScreenContent: (shown, error) {
        shown.dispose();
        _appOpenAd = null;
        _showing = false;
        if (!completer.isCompleted) {
          completer.complete();
        }
        loadAd();
      },
      onAdShowedFullScreenContent: (_) {
        didShow = true;
      },
    );

    try {
      await ad.show();
      await completer.future;
    } catch (error) {
      if (kDebugMode) {
        debugPrint('App open show error: $error');
      }
      _showing = false;
      _appOpenAd = null;
      try {
        ad.dispose();
      } catch (_) {}
      if (!completer.isCompleted) {
        completer.complete();
      }
      loadAd();
      return false;
    }
    return didShow;
  }
}
