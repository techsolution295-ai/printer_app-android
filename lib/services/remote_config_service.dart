import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_remote_config/firebase_remote_config.dart';
import 'package:flutter/foundation.dart';

/// Firebase Remote Config switches for ads.
///
/// Keys match the console: all_ads, banner_ad, interstitial_ad, open_ad.
/// all_ads turns every format off. Each format also has its own switch.
class RemoteConfigService {
  RemoteConfigService._();
  static final RemoteConfigService instance = RemoteConfigService._();

  bool _initialized = false;
  Future<void>? _initFuture;

  bool allAds = true;
  bool bannerAd = true;
  bool interstitialAd = true;
  bool openAd = true;

  bool get showBannerAd => allAds && bannerAd;

  bool get showInterstitialAd => allAds && interstitialAd;

  bool get showOpenAd => allAds && openAd;

  Future<void> init() {
    _initFuture ??= _init();
    return _initFuture!;
  }

  Future<void> _init() async {
    if (_initialized) return;

    try {
      if (Firebase.apps.isEmpty) {
        await Firebase.initializeApp();
      }

      final remoteConfig = FirebaseRemoteConfig.instance;
      await remoteConfig.setConfigSettings(
        RemoteConfigSettings(
          fetchTimeout: const Duration(seconds: 10),
          minimumFetchInterval:
              kDebugMode ? Duration.zero : const Duration(hours: 1),
        ),
      );
      await remoteConfig.setDefaults(const <String, dynamic>{
        'all_ads': true,
        'banner_ad': true,
        'interstitial_ad': true,
        'open_ad': true,
      });

      final activated = await remoteConfig.fetchAndActivate();
      allAds = remoteConfig.getBool('all_ads');
      bannerAd = remoteConfig.getBool('banner_ad');
      interstitialAd = remoteConfig.getBool('interstitial_ad');
      openAd = remoteConfig.getBool('open_ad');
      _initialized = true;
      debugPrint(
        'Remote Config [${activated ? 'activated' : 'cached'}] '
        'all_ads=$allAds, banner_ad=$bannerAd, '
        'interstitial_ad=$interstitialAd, open_ad=$openAd',
      );
    } catch (error, stackTrace) {
      _initialized = true;
      debugPrint('Remote Config failed, ads stay on by default: $error');
      if (kDebugMode) {
        debugPrintStack(stackTrace: stackTrace);
      }
    }
  }
}
