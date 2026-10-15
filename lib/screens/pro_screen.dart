import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:smart_printer/config/pro_theme.dart';
import 'package:smart_printer/constants/app_links.dart';
import 'package:smart_printer/services/billing_service.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:smart_printer/l10n/labels.dart';
import 'package:smart_printer/widgets/app_snack.dart';

import 'main_screen.dart';

class ProScreen extends StatefulWidget {
  const ProScreen({super.key});

  @override
  State<ProScreen> createState() => _ProScreenState();
}

class _ProScreenState extends State<ProScreen> {
  final BillingService _billing = BillingService.instance;
  String _selectedProductId = BillingService.monthlyId;
  bool _leaving = false;

  List<_PlanMeta> get _planMeta => [
        _PlanMeta(
          productId: BillingService.weeklyId,
          name: 'pro_weekly',
          subtitle: 'pro_weekly_sub',
          badge: null,
        ),
        _PlanMeta(
          productId: BillingService.monthlyId,
          name: 'pro_monthly',
          subtitle: 'pro_monthly_sub',
          badge: 'pro_most_popular',
        ),
        _PlanMeta(
          productId: BillingService.yearlyId,
          name: 'pro_yearly',
          subtitle: 'pro_yearly_sub',
          badge: 'pro_best_value',
        ),
      ];

  @override
  void initState() {
    super.initState();
    _billing.addListener(_onBillingChanged);
    unawaited(_loadPrices());
  }

  Future<void> _loadPrices() async {
    await _billing.whenReady.timeout(
      const Duration(seconds: 8),
      onTimeout: () {},
    );
    if (!mounted || !_billing.storeAvailable) return;
    await _billing.loadProducts();
  }

  @override
  void dispose() {
    _billing.removeListener(_onBillingChanged);
    super.dispose();
  }

  void _onBillingChanged() {
    if (!mounted) return;

    if (_billing.isPro) {
      _openHome();
      return;
    }

    final error = _billing.lastError;
    if (error != null) {
      AppSnack.show(
        context,
        t(context, error),
        icon: Icons.error_rounded,
      );
      _billing.lastError = null;
    }
    final notice = _billing.statusMessage;
    if (notice != null) {
      AppSnack.show(
        context,
        t(context, notice),
        icon: notice == 'purchase_canceled'
            ? Icons.close_rounded
            : Icons.info_rounded,
      );
      _billing.statusMessage = null;
    }
    setState(() {});
  }

  void _openHome() {
    if (_leaving || !mounted) return;
    _leaving = true;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const MainScreen()),
      (_) => false,
    );
  }

  void _continueFree() {
    HapticFeedback.lightImpact();
    if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
      return;
    }
    _openHome();
  }

  ProductDetails? get _selectedProduct =>
      _billing.productFor(_selectedProductId);

  @override
  Widget build(BuildContext context) {
    if (_billing.isPro) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _openHome());
      return const Scaffold(
        backgroundColor: Colors.white,
        body: SizedBox.shrink(),
      );
    }

    final width = MediaQuery.sizeOf(context).width;
    final pad = width < 340 ? 12.0 : (width < 400 ? 16.0 : 22.0);
    final narrow = width < 360;

    return Scaffold(
      backgroundColor: const Color(0xFFF4F7FB),
      body: SafeArea(
        child: Padding(
          padding: EdgeInsets.fromLTRB(pad, 4, pad, 4),
          child: Column(
            children: [
              _FitSlot(
                flex: 24,
                child: _buildHero(narrow: narrow, width: width),
              ),
              _FitSlot(
                flex: 28,
                child: _FeatureComparison(narrow: narrow)
                    .animate()
                    .fadeIn(duration: 450.ms, delay: 180.ms)
                    .slideY(begin: 0.04, end: 0),
              ),
              _FitSlot(
                flex: 30,
                child: _buildPlans(narrow: narrow),
              ),
              _FitSlot(
                flex: 18,
                child: _buildFooter(narrow: narrow),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHero({required bool narrow, required double width}) {
    final titleSize = (width * 0.055).clamp(16.0, 22.0);
    final badge = (width * 0.15).clamp(48.0, 64.0);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _AwardBadge(size: narrow ? badge * 0.9 : badge)
            .animate()
            .fadeIn(duration: 400.ms)
            .scale(begin: const Offset(0.86, 0.86), curve: Curves.easeOutBack),
        const SizedBox(height: 6),
        Text(
          'pro_start'.tr(context: context),
          textAlign: TextAlign.center,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontFamily: AppTheme.fontFamily,
            fontSize: titleSize,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.3,
            color: AppTheme.textDark,
            height: 1.1,
          ),
        ).animate().fadeIn(duration: 400.ms, delay: 80.ms),
        const SizedBox(height: 2),
        Text(
          'pro_subtitle'.tr(context: context),
          textAlign: TextAlign.center,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontFamily: AppTheme.fontFamily,
            fontSize: narrow ? 12 : 14,
            fontWeight: FontWeight.w500,
            color: AppTheme.textLight,
            height: 1.2,
          ),
        ).animate().fadeIn(duration: 400.ms, delay: 140.ms),
      ],
    );
  }

  Widget _buildContinueFreeLink() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: _continueFree,
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            child: Text(
              'pro_continue_free'.tr(context: context),
              style: TextStyle(
                fontFamily: AppTheme.fontFamily,
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppTheme.textLight,
                decoration: TextDecoration.underline,
                decorationColor: AppTheme.textLight.withOpacity(0.8),
                letterSpacing: 0.2,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPlans({required bool narrow}) {
    if (!_billing.storeChecked || _billing.storeAvailable) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildContinueFreeLink(),
          for (int i = 0; i < _planMeta.length; i++)
            Padding(
              padding: EdgeInsets.only(
                bottom: i == _planMeta.length - 1 ? 0 : 8,
              ),
              child: _PlanCard(
                meta: _planMeta[i],
                priceText: _billing.priceLabel(
                  _billing.productFor(_planMeta[i].productId),
                ),
                isLoading: !_billing.storeChecked ||
                    (_billing.isLoadingProducts && _billing.products.isEmpty),
                isSelected: _selectedProductId == _planMeta[i].productId,
                savingsLabel: _savingsLabelFor(_planMeta[i].productId),
                narrow: narrow,
                onTap: () {
                  HapticFeedback.selectionClick();
                  setState(() => _selectedProductId = _planMeta[i].productId);
                },
              )
                  .animate()
                  .fadeIn(duration: 350.ms, delay: (220 + i * 80).ms)
                  .slideY(begin: 0.08, end: 0),
            ),
        ],
      );
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _buildContinueFreeLink(),
        _StoreUnavailable(onRetry: () => _billing.initialize()),
      ],
    );
  }

  String? _savingsLabelFor(String productId) {
    if (productId != BillingService.yearlyId) return null;
    final weekly = _billing.productFor(BillingService.weeklyId);
    final yearly = _billing.productFor(BillingService.yearlyId);
    if (weekly == null || yearly == null) return null;
    final weeklyAnnualCost = _billing.rawRecurringPrice(weekly) * 52;
    if (weeklyAnnualCost <= 0) return null;
    final savings =
        (1 - (_billing.rawRecurringPrice(yearly) / weeklyAnnualCost)) * 100;
    if (savings <= 0 || savings.isNaN) return null;
    return 'pro_save_vs_weekly'.tr(
      context: context,
      namedArgs: {'percent': '${savings.round()}'},
    );
  }

  Widget _buildFooter({required bool narrow}) {
    final product = _selectedProduct;
    final price = _billing.priceLabel(product);
    final canBuy = _billing.storeAvailable &&
        product != null &&
        !_billing.isPurchasePending;

    return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _AnimatedContinueButton(
            enabled: canBuy || _billing.isPurchasePending,
            isLoading: _billing.isPurchasePending,
            onTap: canBuy
                ? () {
                    HapticFeedback.mediumImpact();
                    _billing.buy(product);
                  }
                : null,
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 220),
              child: _billing.isPurchasePending
                  ? const SizedBox(
                      key: ValueKey('loading'),
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : FittedBox(
                      key: ValueKey(_selectedProductId),
                      fit: BoxFit.scaleDown,
                      child: Text(
                        price.isNotEmpty
                            ? 'pro_continue_price'.tr(
                                context: context,
                                namedArgs: {'price': price},
                              )
                            : 'continue_btn'.tr(context: context),
                        textAlign: TextAlign.center,
                        maxLines: 1,
                        style: TextStyle(
                          fontFamily: AppTheme.fontFamily,
                          fontSize: narrow ? 14 : 16,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.2,
                          color: Colors.white,
                        ),
                      ),
                    ),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'pro_renew_note'.tr(context: context),
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: AppTheme.fontFamily,
              fontSize: 10,
              height: 1.4,
              color: AppTheme.textLight,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 4),
          Wrap(
            alignment: WrapAlignment.center,
            runAlignment: WrapAlignment.center,
            spacing: 24,
            runSpacing: 8,
            children: [
              TextButton(
                onPressed: () => _launchUrl(AppLinks.privacyPolicy),
                style: TextButton.styleFrom(
                  foregroundColor: AppTheme.textLight,
                  padding: EdgeInsets.zero,
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: Text(
                  'privacy'.tr(context: context),
                  style: TextStyle(
                    fontFamily: AppTheme.fontFamily,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    decoration: TextDecoration.underline,
                  ),
                ),
              ),
              TextButton(
                onPressed: _billing.storeAvailable
                    ? () {
                        HapticFeedback.selectionClick();
                        _billing.restorePurchases();
                        AppSnack.show(
                          context,
                          'pro_checking'.tr(context: context),
                        );
                      }
                    : null,
                style: TextButton.styleFrom(
                  foregroundColor: AppTheme.textLight,
                  padding: EdgeInsets.zero,
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: Text(
                  'pro_restore'.tr(context: context),
                  style: TextStyle(
                    fontFamily: AppTheme.fontFamily,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    decoration: TextDecoration.underline,
                  ),
                ),
              ),
              TextButton(
                onPressed: () => _launchUrl(AppLinks.termsOfService),
                style: TextButton.styleFrom(
                  foregroundColor: AppTheme.textLight,
                  padding: EdgeInsets.zero,
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: Text(
                  'terms'.tr(context: context),
                  style: TextStyle(
                    fontFamily: AppTheme.fontFamily,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    decoration: TextDecoration.underline,
                  ),
                ),
              ),
            ],
          ),
        ],
    );
  }

  static Future<void> _launchUrl(String url) async {
    final uri = Uri.parse(url);
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }
}

/// Gives one block a share of the screen and shrinks it only if it does not fit.
class _FitSlot extends StatelessWidget {
  final int flex;
  final Widget child;

  const _FitSlot({required this.flex, required this.child});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      flex: flex,
      child: LayoutBuilder(
        builder: (context, constraints) {
          return FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.center,
            child: SizedBox(
              width: constraints.maxWidth,
              child: child,
            ),
          );
        },
      ),
    );
  }
}

class _AnimatedContinueButton extends StatefulWidget {
  final bool enabled;
  final bool isLoading;
  final VoidCallback? onTap;
  final Widget child;

  const _AnimatedContinueButton({
    required this.enabled,
    required this.isLoading,
    required this.onTap,
    required this.child,
  });

  @override
  State<_AnimatedContinueButton> createState() =>
      _AnimatedContinueButtonState();
}

class _AnimatedContinueButtonState extends State<_AnimatedContinueButton>
    with TickerProviderStateMixin {
  late final AnimationController _shimmer;
  late final AnimationController _pulse;
  late final Animation<double> _scale;
  bool _pressed = false;

  bool get _isActive => widget.enabled && !widget.isLoading;

  @override
  void initState() {
    super.initState();
    _shimmer = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    );
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _scale = Tween<double>(begin: 1.0, end: 1.05).animate(
      CurvedAnimation(parent: _pulse, curve: Curves.easeInOut),
    );
    _syncShimmer();
  }

  @override
  void didUpdateWidget(covariant _AnimatedContinueButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.enabled != widget.enabled ||
        oldWidget.isLoading != widget.isLoading) {
      _syncShimmer();
    }
  }

  void _syncShimmer() {
    if (_isActive) {
      if (!_shimmer.isAnimating) {
        _shimmer.repeat();
      }
      if (!_pulse.isAnimating) {
        _pulse.repeat(reverse: true);
      }
    } else {
      _shimmer
        ..stop()
        ..value = 0;
      _pulse
        ..stop()
        ..value = 0;
    }
  }

  @override
  void dispose() {
    _shimmer.dispose();
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([_shimmer, _pulse]),
      builder: (context, child) {
        final t = _isActive ? _shimmer.value : 0.0;
        final scale = _pressed
            ? 0.97
            : (_isActive ? _scale.value : 1.0);
        return Transform.scale(
          scale: scale,
          child: SizedBox(
          width: double.infinity,
          height: 52,
          child: DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              gradient: _isActive
                  ? AppTheme.gradientBackground
                  : LinearGradient(
                      colors: [
                        AppTheme.primaryColor.withOpacity(0.45),
                        AppTheme.secondaryColor.withOpacity(0.45),
                      ],
                    ),
              boxShadow: _isActive
                  ? [
                      BoxShadow(
                        color: AppTheme.primaryColor.withOpacity(0.22),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ]
                  : null,
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: _isActive ? widget.onTap : null,
                  onTapDown:
                      _isActive ? (_) => setState(() => _pressed = true) : null,
                  onTapUp: _isActive
                      ? (_) => setState(() => _pressed = false)
                      : null,
                  onTapCancel:
                      _isActive ? () => setState(() => _pressed = false) : null,
                  splashColor: Colors.white.withOpacity(0.16),
                  highlightColor: Colors.white.withOpacity(0.08),
                  child: Opacity(
                    opacity: _pressed ? 0.88 : 1,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        if (_isActive)
                          Positioned.fill(
                            child: IgnorePointer(
                              child: FractionallySizedBox(
                                widthFactor: 0.45,
                                alignment: Alignment(-1.4 + (t * 2.8), 0),
                                child: DecoratedBox(
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      colors: [
                                        Colors.white.withOpacity(0),
                                        Colors.white.withOpacity(0.22),
                                        Colors.white.withOpacity(0),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: child!,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
        );
      },
      child: widget.child,
    );
  }
}

class _AwardBadge extends StatelessWidget {
  final double size;

  const _AwardBadge({this.size = 72});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size(size, size * 1.15),
      painter: _AwardBadgePainter(),
    );
  }
}

class _AwardBadgePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final shader = AppTheme.gradientBackground.createShader(
      Offset.zero & size,
    );
    final stroke = Paint()
      ..shader = shader
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.6
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final center = Offset(size.width / 2, size.height * 0.38);
    final radius = size.width * 0.34;

    canvas.drawCircle(center, radius, stroke);

    final inner = Paint()
      ..shader = shader
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    canvas.drawCircle(center, radius * 0.78, inner);

    canvas.drawPath(_star(center, radius * 0.42), stroke);

    final unit = size.width / 72;
    final leftRibbon = Path()
      ..moveTo(center.dx - 4 * unit, center.dy + radius * 0.72)
      ..lineTo(center.dx - 22 * unit, size.height - 2)
      ..lineTo(center.dx - 7 * unit, size.height - 10 * unit)
      ..lineTo(center.dx + 3 * unit, center.dy + radius * 0.78)
      ..close();

    final rightRibbon = Path()
      ..moveTo(center.dx + 4 * unit, center.dy + radius * 0.72)
      ..lineTo(center.dx + 22 * unit, size.height - 2)
      ..lineTo(center.dx + 7 * unit, size.height - 10 * unit)
      ..lineTo(center.dx - 3 * unit, center.dy + radius * 0.78)
      ..close();

    canvas.drawPath(leftRibbon, stroke);
    canvas.drawPath(rightRibbon, stroke);
  }

  Path _star(Offset center, double radius) {
    const points = 5;
    final path = Path();
    for (var i = 0; i < points * 2; i++) {
      final r = i.isEven ? radius : radius * 0.42;
      final angle = -math.pi / 2 + (i * math.pi / points);
      final point = Offset(
        center.dx + math.cos(angle) * r,
        center.dy + math.sin(angle) * r,
      );
      if (i == 0) {
        path.moveTo(point.dx, point.dy);
      } else {
        path.lineTo(point.dx, point.dy);
      }
    }
    path.close();
    return path;
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _FeatureComparison extends StatelessWidget {
  final bool narrow;

  const _FeatureComparison({required this.narrow});

  List<_FeatureRowData> get _features => [
    _FeatureRowData(
      icon: Icons.print_rounded,
      title: 'pro_feat_print',
      premium: true,
      basic: false,
    ),
    _FeatureRowData(
      icon: Icons.document_scanner_outlined,
      title: 'pro_feat_scan',
      premium: true,
      basic: false,
    ),
    _FeatureRowData(
      icon: Icons.picture_as_pdf_outlined,
      title: 'pro_feat_pdf',
      premium: true,
      basic: true,
    ),
    _FeatureRowData(
      icon: Icons.grid_view_rounded,
      title: 'pro_feat_printables',
      premium: true,
      basic: true,
    ),
    _FeatureRowData(
      icon: Icons.block_rounded,
      title: 'pro_feat_ads',
      premium: true,
      basic: false,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final premiumWidth = narrow ? 56.0 : 70.0;
    final basicWidth = narrow ? 44.0 : 54.0;
    final titleSize = narrow ? 12.0 : 13.5;
    final labelSize = narrow ? 10.0 : 11.0;

    Widget columnLabel(String text, double columnWidth) {
      return SizedBox(
        width: columnWidth,
        child: Text(
          text,
          textAlign: TextAlign.center,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontFamily: AppTheme.fontFamily,
            fontSize: labelSize,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.3,
            color: AppTheme.textDark,
            height: 1.15,
          ),
        ),
      );
    }

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 4),
          child: Row(
            children: [
              const Expanded(child: SizedBox()),
              columnLabel('pro_premium'.tr(context: context), premiumWidth),
              columnLabel('pro_basic'.tr(context: context), basicWidth),
            ],
          ),
        ),
        for (final feature in _features)
          Padding(
            padding: const EdgeInsets.only(bottom: 2),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                SizedBox(
                  width: narrow ? 18 : 22,
                  child: Center(
                    child: _GradientIcon(
                      icon: feature.icon,
                      size: narrow ? 16 : 18,
                    ),
                  ),
                ),
                SizedBox(width: narrow ? 6 : 8),
                Expanded(
                  child: Text(
                    t(context, feature.title),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontFamily: AppTheme.fontFamily,
                      fontSize: titleSize,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textDark,
                      height: 1.2,
                    ),
                  ),
                ),
                SizedBox(
                  width: premiumWidth,
                  child: Center(child: _StatusMark(enabled: feature.premium)),
                ),
                SizedBox(
                  width: basicWidth,
                  child: Center(child: _StatusMark(enabled: feature.basic)),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _GradientIcon extends StatelessWidget {
  final IconData icon;
  final double size;

  const _GradientIcon({required this.icon, required this.size});

  @override
  Widget build(BuildContext context) {
    return ShaderMask(
      blendMode: BlendMode.srcIn,
      shaderCallback: (bounds) => AppTheme.gradientBackground.createShader(
        Rect.fromLTWH(0, 0, bounds.width, bounds.height),
      ),
      child: Icon(icon, size: size, color: Colors.white),
    );
  }
}

class _StatusMark extends StatelessWidget {
  final bool enabled;

  const _StatusMark({required this.enabled});

  @override
  Widget build(BuildContext context) {
    if (enabled) {
      return const _GradientIcon(icon: Icons.check_rounded, size: 26);
    }
    return ShaderMask(
      blendMode: BlendMode.srcIn,
      shaderCallback: (bounds) => AppTheme.gradientBackground.createShader(
        Rect.fromLTWH(0, 0, bounds.width, bounds.height),
      ),
      child: Container(
        width: 16,
        height: 3.2,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(4),
        ),
      ),
    );
  }
}

class _StoreUnavailable extends StatelessWidget {
  final VoidCallback onRetry;

  const _StoreUnavailable({required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          'pro_store_down'.tr(context: context),
          textAlign: TextAlign.center,
          style: TextStyle(
            fontFamily: AppTheme.fontFamily,
            color: AppTheme.textLight,
            fontSize: 13,
            height: 1.4,
          ),
        ),
        TextButton(
          onPressed: onRetry,
          child: Text(
            'retry'.tr(context: context),
            style: TextStyle(
              fontFamily: AppTheme.fontFamily,
              fontWeight: FontWeight.w700,
              color: AppTheme.primaryColor,
            ),
          ),
        ),
      ],
    );
  }
}

class _PlanCard extends StatelessWidget {
  final _PlanMeta meta;
  final String priceText;
  final bool isLoading;
  final bool isSelected;
  final String? savingsLabel;
  final bool narrow;
  final VoidCallback onTap;

  const _PlanCard({
    required this.meta,
    required this.priceText,
    required this.isLoading,
    required this.isSelected,
    required this.savingsLabel,
    required this.narrow,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          padding: const EdgeInsets.symmetric(
            horizontal: 12,
            vertical: 8,
          ),
          decoration: BoxDecoration(
            color: isSelected
                ? AppTheme.primaryColor.withOpacity(0.06)
                : Colors.white,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isSelected ? AppTheme.primaryColor : AppTheme.borderColor,
              width: isSelected ? 1.6 : 1,
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                width: 20,
                height: 20,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: isSelected ? AppTheme.gradientBackground : null,
                  border: isSelected
                      ? null
                      : Border.all(color: AppTheme.borderColor, width: 1.6),
                ),
                child: isSelected
                    ? const Icon(Icons.check_rounded,
                        size: 13, color: Colors.white)
                    : null,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            t(context, meta.name),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontFamily: AppTheme.fontFamily,
                              color: AppTheme.textDark,
                              fontWeight: FontWeight.w700,
                              fontSize: narrow ? 13 : 14,
                            ),
                          ),
                        ),
                        if (meta.badge != null) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 7,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              gradient: AppTheme.gradientBackground,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              t(context, meta.badge!),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 9,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.2,
                                height: 1.2,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      savingsLabel ?? t(context, meta.subtitle),
                      maxLines: 1,
                      style: TextStyle(
                        fontFamily: AppTheme.fontFamily,
                        color: savingsLabel != null
                            ? AppTheme.secondaryColor
                            : AppTheme.textLight,
                        fontSize: 11.5,
                        height: 1.25,
                        fontWeight: savingsLabel != null
                            ? FontWeight.w700
                            : FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              isLoading
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppTheme.primaryColor,
                      ),
                    )
                  : ConstrainedBox(
                      constraints: BoxConstraints(
                        maxWidth: MediaQuery.sizeOf(context).width < 360
                            ? 78
                            : 108,
                      ),
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerRight,
                        child: Text(
                          priceText.isEmpty ? '--' : priceText,
                          textAlign: TextAlign.end,
                          maxLines: 1,
                          style: TextStyle(
                            fontFamily: AppTheme.fontFamily,
                            color: AppTheme.textDark,
                            fontWeight: FontWeight.w800,
                            fontSize: narrow ? 13 : 15,
                            height: 1.15,
                          ),
                        ),
                      ),
                    ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PlanMeta {
  final String productId;
  final String name;
  final String subtitle;
  final String? badge;

  const _PlanMeta({
    required this.productId,
    required this.name,
    required this.subtitle,
    required this.badge,
  });
}

class _FeatureRowData {
  final IconData icon;
  final String title;
  final bool premium;
  final bool basic;

  const _FeatureRowData({
    required this.icon,
    required this.title,
    required this.premium,
    required this.basic,
  });
}
