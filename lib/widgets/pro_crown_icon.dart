import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:smart_printer/config/pro_theme.dart';
import 'package:smart_printer/screens/pro_screen.dart';
import 'package:smart_printer/services/billing_service.dart';

class ProCrownIcon extends StatelessWidget {
  final double size;
  final Color color;

  const ProCrownIcon({
    super.key,
    this.size = 26,
    this.color = AppTheme.accentColor,
  });

  @override
  Widget build(BuildContext context) {
    return ColorFiltered(
      colorFilter: ColorFilter.mode(color, BlendMode.srcIn),
      child: Image.asset(
        'assets/images/pro_crown_icon.png',
        width: size,
        height: size,
        errorBuilder: (_, _, _) => Icon(
          Icons.workspace_premium_rounded,
          color: color,
          size: size,
        ),
      ),
    );
  }
}

/// Home-style Pro crown. Hidden once Pro is active.
class ProAppBarButton extends StatelessWidget {
  const ProAppBarButton({super.key, this.size = 28});

  final double size;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: BillingService.instance,
      builder: (context, _) {
        if (BillingService.instance.isPro) {
          return const SizedBox.shrink();
        }
        return IconButton(
          tooltip: 'go_pro'.tr(),
          style: IconButton.styleFrom(
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            padding: const EdgeInsets.all(4),
            minimumSize: Size(size + 8, size + 8),
          ),
          onPressed: () {
            Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const ProScreen()),
            );
          },
          icon: ProCrownIcon(size: size),
        );
      },
    );
  }
}
