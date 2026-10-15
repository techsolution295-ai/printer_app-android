import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import 'package:smart_printer/services/billing_service.dart';

import 'ad_service.dart';

/// Same visual style as Smart-printer-appsrepublic:
/// white strip, grey top/bottom borders, shimmer skeleton while loading.
class BannerAdWidget extends StatefulWidget {
  const BannerAdWidget({
    super.key,
    this.margin = const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
  });

  final EdgeInsets margin;

  @override
  State<BannerAdWidget> createState() => _BannerAdWidgetState();
}

class _BannerAdWidgetState extends State<BannerAdWidget> {
  BannerAd? _bannerAd;
  bool _isLoaded = false;
  int _loadAttempts = 0;
  static const int _maxLoadAttempts = 3;

  @override
  void initState() {
    super.initState();
    BillingService.instance.addListener(_onProChanged);
    if (!BillingService.instance.isPro) {
      _loadBanner();
    }
  }

  @override
  void dispose() {
    BillingService.instance.removeListener(_onProChanged);
    _bannerAd?.dispose();
    super.dispose();
  }

  void _onProChanged() {
    if (!mounted) return;
    if (BillingService.instance.isPro) {
      _bannerAd?.dispose();
      setState(() {
        _bannerAd = null;
        _isLoaded = false;
      });
      return;
    }
    if (_bannerAd == null) {
      _loadAttempts = 0;
      _loadBanner();
    }
  }

  void _loadBanner() {
    if (BillingService.instance.isPro) return;
    _bannerAd?.dispose();
    _bannerAd = null;
    _isLoaded = false;
    _loadAttempts += 1;

    final banner = BannerAd(
      adUnitId: AdService.instance.bannerAdUnitId,
      request: const AdRequest(),
      size: AdSize.banner,
      listener: BannerAdListener(
        onAdLoaded: (ad) {
          if (kDebugMode) {
            debugPrint('[BannerAdWidget] banner loaded');
          }
          if (!mounted || BillingService.instance.isPro) {
            ad.dispose();
            return;
          }
          setState(() {
            _bannerAd = ad as BannerAd;
            _isLoaded = true;
          });
        },
        onAdFailedToLoad: (ad, error) {
          if (kDebugMode) {
            debugPrint('[BannerAdWidget] banner failed: ${error.message}');
          }
          ad.dispose();
          if (!mounted) {
            return;
          }
          setState(() {
            _bannerAd = null;
            _isLoaded = false;
          });
          if (_loadAttempts < _maxLoadAttempts) {
            Future<void>.delayed(const Duration(seconds: 2), () {
              if (mounted) {
                _loadBanner();
              }
            });
          }
        },
      ),
    );

    _bannerAd = banner;
    banner.load();
  }

  @override
  Widget build(BuildContext context) {
    if (BillingService.instance.isPro) {
      return const SizedBox.shrink();
    }
    final bannerAd = _bannerAd;

    return Container(
      margin: widget.margin,
      width: double.infinity,
      height: 54,
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(
          top: BorderSide(color: Colors.grey.shade500, width: 1.6),
          bottom: BorderSide(color: Colors.grey.shade500, width: 1.6),
        ),
      ),
      child: Center(
        child: !_isLoaded || bannerAd == null
            ? const _BannerSkeleton()
            : SizedBox(
                width: bannerAd.size.width.toDouble(),
                height: bannerAd.size.height.toDouble(),
                child: AdWidget(ad: bannerAd),
              ),
      ),
    );
  }
}

class _BannerSkeleton extends StatefulWidget {
  const _BannerSkeleton();

  @override
  State<_BannerSkeleton> createState() => _BannerSkeletonState();
}

class _BannerSkeletonState extends State<_BannerSkeleton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final base = Color.lerp(
          Colors.grey.shade200,
          Colors.grey.shade300,
          _controller.value,
        )!;

        return SizedBox(
          width: 320,
          height: 50,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              children: [
                Container(
                  width: 34,
                  height: 24,
                  decoration: BoxDecoration(
                    color: base,
                    borderRadius: BorderRadius.circular(6),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Container(
                    height: 12,
                    decoration: BoxDecoration(
                      color: base,
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Container(
                  width: 58,
                  height: 28,
                  decoration: BoxDecoration(
                    color: base,
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
