import 'package:flutter/material.dart';
import 'package:smart_printer/config/pro_theme.dart';
import '../l10n/labels.dart';

import 'files_screen.dart';
import 'web_page.dart';

class LearnMoreScreen extends StatelessWidget {
  const LearnMoreScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final width = media.size.width;
    final textScale = media.textScaler.scale(1);
    final compact = width < 360 || textScale > 1.12;
    final stackButtons = width < 390 || textScale > 1.2;
    final pad = width < 340 ? 12.0 : 16.0;
    final gap = compact ? 10.0 : 14.0;

    final webButton = ElevatedButton(
      onPressed: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const WebPageScreen()),
        );
      },
      style: ElevatedButton.styleFrom(
        backgroundColor: AppTheme.actionColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        padding: EdgeInsets.symmetric(vertical: compact ? 12 : 14, horizontal: 10),
      ),
      child: Text(
        t(context, 'open_web_print'),
        textAlign: TextAlign.center,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontSize: compact ? 13 : 14,
          fontWeight: FontWeight.w700,
          color: Colors.white,
          height: 1.2,
        ),
      ),
    );

    final filesButton = OutlinedButton(
      onPressed: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const FilesScreen()),
        );
      },
      style: OutlinedButton.styleFrom(
        foregroundColor: AppTheme.actionColor,
        side: const BorderSide(color: AppTheme.actionColor),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        padding: EdgeInsets.symmetric(vertical: compact ? 12 : 14, horizontal: 10),
      ),
      child: Text(
        t(context, 'view_files'),
        textAlign: TextAlign.center,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontSize: compact ? 13 : 14,
          fontWeight: FontWeight.w700,
          height: 1.2,
        ),
      ),
    );

    return Scaffold(
      backgroundColor: AppTheme.pageBackground,
      appBar: AppBar(
        title: Text(
          t(context, 'learn_more'),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        backgroundColor: Colors.white,
        foregroundColor: AppTheme.textDark,
        elevation: 0,
      ),
      body: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(pad, compact ? 10 : 16, pad, 24),
          child: Column(
            children: [
              _HeroCard(
                title: t(context, 'learn_title'),
                subtitle: t(context, 'learn_sub'),
                compact: compact,
              ),
              SizedBox(height: gap),
              _SectionCard(
                title: t(context, 'how_it_works'),
                compact: compact,
                child: Column(
                  children: [
                    _StepItem(
                      number: '1',
                      title: t(context, 'step_choose'),
                      subtitle: t(context, 'step_choose_sub'),
                      compact: compact,
                    ),
                    SizedBox(height: compact ? 8 : 10),
                    _StepItem(
                      number: '2',
                      title: t(context, 'step_review'),
                      subtitle: t(context, 'step_review_sub'),
                      compact: compact,
                    ),
                    SizedBox(height: compact ? 8 : 10),
                    _StepItem(
                      number: '3',
                      title: t(context, 'step_print'),
                      subtitle: t(context, 'step_print_sub'),
                      compact: compact,
                    ),
                  ],
                ),
              ),
              SizedBox(height: gap),
              _SectionCard(
                title: t(context, 'popular_features'),
                compact: compact,
                child: Wrap(
                  spacing: compact ? 8 : 10,
                  runSpacing: compact ? 8 : 10,
                  children: [
                    _FeaturePill(icon: Icons.text_fields_rounded, label: t(context, 'pill_smart')),
                    _FeaturePill(icon: Icons.photo_rounded, label: t(context, 'pill_photos')),
                    _FeaturePill(icon: Icons.picture_as_pdf_rounded, label: t(context, 'pill_pdf')),
                    _FeaturePill(icon: Icons.call_split_rounded, label: t(context, 'pill_split')),
                    _FeaturePill(icon: Icons.merge_type_rounded, label: t(context, 'pill_merge')),
                    _FeaturePill(icon: Icons.document_scanner_rounded, label: t(context, 'scan')),
                    _FeaturePill(icon: Icons.public_rounded, label: t(context, 'feat_web')),
                  ],
                ),
              ),
              SizedBox(height: gap),
              _SectionCard(
                title: t(context, 'quick_tips'),
                compact: compact,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _TipItem(text: t(context, 'tip_layout')),
                    const SizedBox(height: 8),
                    _TipItem(text: t(context, 'tip_pdf_images')),
                    const SizedBox(height: 8),
                    _TipItem(text: t(context, 'tip_save_files')),
                  ],
                ),
              ),
              SizedBox(height: compact ? 12 : 16),
              if (stackButtons)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    webButton,
                    const SizedBox(height: 10),
                    filesButton,
                  ],
                )
              else
                Row(
                  children: [
                    Expanded(child: webButton),
                    const SizedBox(width: 12),
                    Expanded(child: filesButton),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HeroCard extends StatelessWidget {
  const _HeroCard({
    required this.title,
    required this.subtitle,
    required this.compact,
  });

  final String title;
  final String subtitle;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final titleSize = (MediaQuery.sizeOf(context).width * 0.05).clamp(16.0, 20.0);
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(compact ? 14 : 16),
      decoration: BoxDecoration(
        gradient: AppTheme.gradientBackground,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: titleSize,
              fontWeight: FontWeight.w800,
              color: Colors.white,
              height: 1.2,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            subtitle,
            style: TextStyle(
              fontSize: compact ? 12 : 13,
              fontWeight: FontWeight.w500,
              color: Colors.white70,
              height: 1.35,
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({
    required this.title,
    required this.child,
    required this.compact,
  });

  final String title;
  final Widget child;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(compact ? 12 : 16, 14, compact ? 12 : 16, 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: compact ? 13 : 15,
              fontWeight: FontWeight.w700,
              color: AppTheme.textDark,
              height: 1.2,
            ),
          ),
          const SizedBox(height: 10),
          child,
        ],
      ),
    );
  }
}

class _StepItem extends StatelessWidget {
  const _StepItem({
    required this.number,
    required this.title,
    required this.subtitle,
    required this.compact,
  });

  final String number;
  final String title;
  final String subtitle;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          height: 28,
          width: 28,
          decoration: BoxDecoration(
            color: const Color(0xFFEAF2FF),
            borderRadius: BorderRadius.circular(8),
          ),
          alignment: Alignment.center,
          child: Text(
            number,
            style: const TextStyle(
              color: AppTheme.actionColor,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: compact ? 13 : 14,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.textDark,
                  height: 1.25,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                subtitle,
                style: TextStyle(
                  fontSize: compact ? 12 : 13,
                  fontWeight: FontWeight.w500,
                  color: AppTheme.textLight,
                  height: 1.35,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _FeaturePill extends StatelessWidget {
  const _FeaturePill({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final maxWidth = MediaQuery.sizeOf(context).width - 56;
    return ConstrainedBox(
      constraints: BoxConstraints(maxWidth: maxWidth),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: AppTheme.tintColor,
          borderRadius: BorderRadius.circular(18),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: AppTheme.actionColor),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                label,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.textDark,
                  height: 1.2,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TipItem extends StatelessWidget {
  const _TipItem({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          height: 6,
          width: 6,
          margin: const EdgeInsets.only(top: 6),
          decoration: const BoxDecoration(
            color: AppTheme.actionColor,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppTheme.textLight,
              height: 1.35,
            ),
          ),
        ),
      ],
    );
  }
}
