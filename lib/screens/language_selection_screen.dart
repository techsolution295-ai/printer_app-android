import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:smart_printer/config/pro_theme.dart';

import '../services/app_language_config.dart';
import '../services/billing_service.dart';
import 'main_screen.dart';
import 'pro_screen.dart';

Future<void> showLanguageSelectionSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    builder: (sheetContext) => const LanguageSelectionSheet(),
  );
}

class LanguageSelectionScreen extends StatelessWidget {
  const LanguageSelectionScreen({super.key});

  Future<void> _finish(BuildContext context) async {
    if (!context.mounted) return;
    final next = BillingService.instance.isPro
        ? const MainScreen()
        : const ProScreen();
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => next),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: LanguageSelectionPanel(
          showCloseButton: false,
          onFinished: _finish,
        ),
      ),
    );
  }
}

class LanguageSelectionSheet extends StatelessWidget {
  const LanguageSelectionSheet({super.key});

  @override
  Widget build(BuildContext context) {
    final maxHeight = MediaQuery.sizeOf(context).height * 0.88;

    return Container(
      constraints: BoxConstraints(maxHeight: maxHeight),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 10),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: const Color(0xFFD1D5DB),
              borderRadius: BorderRadius.circular(99),
            ),
          ),
          Flexible(
            child: LanguageSelectionPanel(
              showCloseButton: true,
              onFinished: (context) async {
                if (context.mounted) Navigator.of(context).pop();
              },
            ),
          ),
        ],
      ),
    );
  }
}

class LanguageSelectionPanel extends StatefulWidget {
  const LanguageSelectionPanel({
    super.key,
    required this.showCloseButton,
    required this.onFinished,
  });

  final bool showCloseButton;
  final Future<void> Function(BuildContext context) onFinished;

  @override
  State<LanguageSelectionPanel> createState() => _LanguageSelectionPanelState();
}

class _LanguageSelectionPanelState extends State<LanguageSelectionPanel> {
  String _selectedCountryId = AppLanguageConfig.defaultCountryId;
  bool _loadedSaved = false;
  String _searchQuery = '';
  late final TextEditingController _searchController;
  late final FocusNode _searchFocusNode;

  static const Color _accent = AppTheme.actionColor;
  static const Color _textPrimary = Color(0xFF111111);
  static const Color _textMuted = Color(0xFF6B7280);
  static const Color _divider = Color(0xFFE6E7F1);

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController();
    _searchFocusNode = FocusNode();
    _searchController.addListener(() {
      setState(() => _searchQuery = _searchController.text);
    });
    _searchFocusNode.addListener(() {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_loadedSaved) {
      _loadSelection();
    }
  }

  Future<void> _loadSelection() async {
    final saved = await AppLanguageConfig.savedCountryId();
    if (!mounted) return;
    setState(() {
      _loadedSaved = true;
      _selectedCountryId = saved ?? AppLanguageConfig.defaultCountryId;
    });
  }

  List<LanguageOption> get _filteredOptions {
    final query = _searchQuery.trim().toLowerCase();
    if (query.isEmpty) return AppLanguageConfig.languageOptions;
    return AppLanguageConfig.languageOptions.where((option) {
      return option.label.toLowerCase().contains(query) ||
          option.localeCode.toLowerCase().contains(query) ||
          option.id.toLowerCase().contains(query);
    }).toList();
  }

  Future<void> _continue() async {
    final option = AppLanguageConfig.optionById(_selectedCountryId);
    await AppLanguageConfig.saveCountryId(option.id);
    if (!mounted) return;

    final current = context.locale;
    final next = option.locale;
    final sameLanguage = current.languageCode == next.languageCode;
    final sameCountry = (current.countryCode ?? '') == (next.countryCode ?? '');
    if (!sameLanguage || !sameCountry) {
      await context.setLocale(next);
    }

    if (!mounted) return;
    await widget.onFinished(context);
  }

  @override
  Widget build(BuildContext context) {
    final options = _filteredOptions;

    return Padding(
      padding: EdgeInsets.fromLTRB(
        20,
        18,
        20,
        16 + MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'choose_language'.tr(),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                        color: _textPrimary,
                        height: 1.15,
                        letterSpacing: -0.6,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'choose_language_sub'.tr(),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: _textMuted,
                      ),
                    ),
                  ],
                ),
              ),
              if (widget.showCloseButton)
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(
                    CupertinoIcons.xmark_circle_fill,
                    size: 28,
                    color: Color(0xFFD1D5DB),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),
          _LanguageSearchBar(
            controller: _searchController,
            focusNode: _searchFocusNode,
            onClear: () {
              _searchController.clear();
              _searchFocusNode.unfocus();
            },
          ),
          const SizedBox(height: 14),
          Expanded(
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: const Color(0xFFF9FAFB),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: _divider),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: options.isEmpty
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Text(
                            'no_language_results'.tr(),
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: _textMuted,
                            ),
                          ),
                        ),
                      )
                    : ListView.separated(
                        padding: EdgeInsets.zero,
                        keyboardDismissBehavior:
                            ScrollViewKeyboardDismissBehavior.onDrag,
                        itemCount: options.length,
                        separatorBuilder: (context, index) => const Divider(
                          height: 1,
                          thickness: 1,
                          color: _divider,
                        ),
                        itemBuilder: (context, index) {
                          final option = options[index];
                          final selected = _selectedCountryId == option.id;
                          return ListTile(
                            onTap: () =>
                                setState(() => _selectedCountryId = option.id),
                            leading: Text(
                              option.flag,
                              style: const TextStyle(fontSize: 26),
                            ),
                            title: Text(
                              option.label,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: _textPrimary,
                              ),
                            ),
                            trailing: Icon(
                              selected
                                  ? Icons.check_circle_rounded
                                  : Icons.circle_outlined,
                              color: selected ? _accent : const Color(0xFFD1D5DB),
                            ),
                          );
                        },
                      ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            height: 54,
            child: ElevatedButton(
              onPressed: _continue,
              style: ElevatedButton.styleFrom(
                backgroundColor: _accent,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: Text(
                'continue_btn'.tr(),
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _LanguageSearchBar extends StatelessWidget {
  const _LanguageSearchBar({
    required this.controller,
    required this.focusNode,
    required this.onClear,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final VoidCallback onClear;

  static const Color _accent = AppTheme.actionColor;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<TextEditingValue>(
      valueListenable: controller,
      builder: (context, value, _) {
        final hasText = value.text.isNotEmpty;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          height: 48,
          decoration: BoxDecoration(
            color: const Color(0xFFF3F4F6),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: focusNode.hasFocus ? _accent : const Color(0xFFE5E7EB),
              width: focusNode.hasFocus ? 1.4 : 1,
            ),
          ),
          child: Row(
            children: [
              const SizedBox(width: 14),
              Icon(
                CupertinoIcons.search,
                size: 18,
                color: focusNode.hasFocus ? _accent : const Color(0xFF9CA3AF),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: TextField(
                  controller: controller,
                  focusNode: focusNode,
                  textInputAction: TextInputAction.search,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                    color: Color(0xFF111111),
                  ),
                  decoration: InputDecoration(
                    hintText: 'search_language'.tr(),
                    hintStyle: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                      color: Color(0xFF9CA3AF),
                    ),
                    border: InputBorder.none,
                    isDense: true,
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
              ),
              if (hasText)
                GestureDetector(
                  onTap: onClear,
                  child: const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 12),
                    child: Icon(
                      CupertinoIcons.xmark_circle_fill,
                      size: 18,
                      color: Color(0xFF9CA3AF),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}
