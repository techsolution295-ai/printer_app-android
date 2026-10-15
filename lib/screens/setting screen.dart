import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:smart_printer/config/pro_theme.dart';
import 'package:smart_printer/constants/app_links.dart';
import 'package:smart_printer/services/app_language_config.dart';
import 'package:smart_printer/services/billing_service.dart';
import 'package:smart_printer/widgets/app_snack.dart';
import 'package:url_launcher/url_launcher.dart';

import 'language_selection_screen.dart';
import 'pro_screen.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    const overlayStyle = SystemUiOverlayStyle(
      statusBarColor: Colors.white,
      statusBarIconBrightness: Brightness.dark,
      statusBarBrightness: Brightness.light,
    );

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: overlayStyle,
      child: Scaffold(
        backgroundColor: AppTheme.pageBackground,
        appBar: AppBar(
          backgroundColor: Colors.white,
          surfaceTintColor: Colors.transparent,
          elevation: 0,
          scrolledUnderElevation: 0,
          centerTitle: true,
          systemOverlayStyle: overlayStyle,
          title: Text(
            'settings'.tr(),
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: AppTheme.textDark,
            ),
          ),
        ),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
          children: [
            _SimpleSection(
              title: 'general'.tr(),
              children: [
                ListenableBuilder(
                  listenable: BillingService.instance,
                  builder: (context, _) {
                    if (BillingService.instance.isPro) {
                      return const SizedBox.shrink();
                    }
                    return Column(
                      children: [
                        _SimpleTile(
                          icon: Icons.workspace_premium_rounded,
                          title: 'go_pro'.tr(),
                          subtitle: 'unlock_all_features'.tr(),
                          onTap: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => const ProScreen(),
                              ),
                            );
                          },
                        ),
                        const _SimpleDivider(),
                      ],
                    );
                  },
                ),
                const _LanguageTile(),
                const _SimpleDivider(),
                _SimpleTile(
                  icon: Icons.support_agent_rounded,
                  title: 'support'.tr(),
                  subtitle: 'support_sub'.tr(),
                  onTap: () => _launchUrl(context, AppLinks.supportEmailUri),
                ),
                const _SimpleDivider(),
                _SimpleTile(
                  icon: Icons.star_border_rounded,
                  title: 'rate_app'.tr(),
                  subtitle: 'rate_sub'.tr(),
                  onTap: () => _openPlayStore(context),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _SimpleSection(
              title: 'legal'.tr(),
              children: [
                _SimpleTile(
                  icon: Icons.privacy_tip_outlined,
                  title: 'privacy'.tr(),
                  subtitle: 'privacy_sub'.tr(),
                  onTap: () => _launchUrl(context, AppLinks.privacyPolicy),
                ),
                const _SimpleDivider(),
                _SimpleTile(
                  icon: Icons.description_outlined,
                  title: 'terms'.tr(),
                  subtitle: 'terms_sub'.tr(),
                  onTap: () => _launchUrl(context, AppLinks.termsOfService),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  static Future<void> _launchUrl(BuildContext context, String url) async {
    final uri = Uri.parse(url);
    final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!context.mounted) {
      return;
    }
    if (!launched) {
      AppSnack.show(
        context,
        'could_not_open_link'.tr(),
        icon: Icons.error_outline_rounded,
      );
    }
  }

  static Future<void> _openPlayStore(BuildContext context) async {
    final targets = <Uri>[
      AppLinks.playStoreMarket,
      AppLinks.playStoreWeb,
    ];
    for (final uri in targets) {
      try {
        final opened = await launchUrl(
          uri,
          mode: LaunchMode.externalNonBrowserApplication,
        );
        if (opened) return;
      } catch (_) {}
    }
    try {
      final opened = await launchUrl(
        AppLinks.playStoreWeb,
        mode: LaunchMode.externalApplication,
      );
      if (opened || !context.mounted) return;
    } catch (_) {}
    if (!context.mounted) return;
    AppSnack.show(
      context,
      'could_not_open_link'.tr(),
      icon: Icons.error_outline_rounded,
    );
  }
}

class _LanguageTile extends StatefulWidget {
  const _LanguageTile();

  @override
  State<_LanguageTile> createState() => _LanguageTileState();
}

class _LanguageTileState extends State<_LanguageTile> {
  String? _label;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _refresh();
  }

  Future<void> _refresh() async {
    final saved = await AppLanguageConfig.savedCountryId();
    if (!mounted) return;
    final label = saved != null
        ? AppLanguageConfig.optionById(saved).label
        : AppLanguageConfig.optionForLocale(context.locale).label;
    setState(() => _label = label);
  }

  @override
  Widget build(BuildContext context) {
    context.locale;
    return _SimpleTile(
      icon: Icons.language_rounded,
      title: 'language'.tr(),
      subtitle: _label ?? AppLanguageConfig.optionForLocale(context.locale).label,
      onTap: () async {
        await showLanguageSelectionSheet(context);
        if (mounted) await _refresh();
      },
    );
  }
}

class _SimpleSection extends StatelessWidget {
  const _SimpleSection({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 8),
          child: Text(
            title,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: AppTheme.secondaryColor,
            ),
          ),
        ),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppTheme.borderColor),
          ),
          child: Column(children: children),
        ),
      ],
    );
  }
}

class _SimpleTile extends StatelessWidget {
  const _SimpleTile({
    required this.icon,
    required this.title,
    this.subtitle,
    this.onTap,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
      leading: Container(
        height: 34,
        width: 34,
        decoration: BoxDecoration(
          color: AppTheme.tintColor,
          borderRadius: BorderRadius.circular(9),
        ),
        child: Icon(icon, size: 18, color: AppTheme.secondaryColor),
      ),
      title: Text(
        title,
        style: const TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w600,
          color: AppTheme.textDark,
        ),
      ),
      subtitle: subtitle == null
          ? null
          : Text(
              subtitle!,
              style: const TextStyle(
                fontSize: 12,
                color: AppTheme.textLight,
              ),
            ),
      trailing: const Icon(
        Icons.chevron_right_rounded,
        color: AppTheme.mutedColor,
      ),
    );
  }
}

class _SimpleDivider extends StatelessWidget {
  const _SimpleDivider();

  @override
  Widget build(BuildContext context) {
    return const Divider(
      height: 1,
      thickness: 1,
      indent: 62,
      endIndent: 14,
      color: AppTheme.borderColor,
    );
  }
}
