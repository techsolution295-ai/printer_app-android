import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LanguageOption {
  const LanguageOption({
    required this.id,
    required this.label,
    required this.flag,
    required this.localeCode,
    this.countryCode,
  });

  final String id;
  final String label;
  final String flag;
  final String localeCode;
  final String? countryCode;

  Locale get locale =>
      countryCode == null ? Locale(localeCode) : Locale(localeCode, countryCode);

  /// Filename stem used by easy_localization (`zh` or `zh-TW`).
  String get translationFileCode =>
      countryCode == null ? localeCode : '$localeCode-$countryCode';
}

class AppLanguageConfig {
  AppLanguageConfig._();

  static const String _prefsKey = 'selected_language_country_id';
  static const String defaultCountryId = 'us';

  /// All countries / languages in display order.
  static const List<LanguageOption> languageOptions = <LanguageOption>[
    // Priority sequence
    LanguageOption(id: 'us', label: 'United States', flag: '🇺🇸', localeCode: 'en'),
    LanguageOption(id: 'in', label: 'India', flag: '🇮🇳', localeCode: 'hi'),
    LanguageOption(id: 'za', label: 'South Africa', flag: '🇿🇦', localeCode: 'en'),
    LanguageOption(id: 'ph', label: 'Philippines', flag: '🇵🇭', localeCode: 'fil'),
    LanguageOption(id: 'my', label: 'Malaysia', flag: '🇲🇾', localeCode: 'ms'),
    LanguageOption(id: 'sa', label: 'Saudi Arabia', flag: '🇸🇦', localeCode: 'ar'),
    LanguageOption(id: 'de', label: 'Germany', flag: '🇩🇪', localeCode: 'de'),
    LanguageOption(id: 'fr', label: 'France', flag: '🇫🇷', localeCode: 'fr'),
    LanguageOption(id: 'jp', label: 'Japan', flag: '🇯🇵', localeCode: 'ja'),
    // Remaining
    LanguageOption(id: 'sg', label: 'Singapore', flag: '🇸🇬', localeCode: 'en'),
    LanguageOption(id: 'ng', label: 'Nigeria', flag: '🇳🇬', localeCode: 'en'),
    LanguageOption(id: 'nz', label: 'New Zealand', flag: '🇳🇿', localeCode: 'en'),
    LanguageOption(id: 'cd', label: 'Congo (DRC)', flag: '🇨🇩', localeCode: 'fr'),
    LanguageOption(id: 'hu', label: 'Hungary', flag: '🇭🇺', localeCode: 'hu'),
    LanguageOption(id: 'mv', label: 'Maldives', flag: '🇲🇻', localeCode: 'en'),
    LanguageOption(id: 'id', label: 'Indonesia', flag: '🇮🇩', localeCode: 'id'),
    LanguageOption(id: 'zm', label: 'Zambia', flag: '🇿🇲', localeCode: 'en'),
    LanguageOption(id: 'co', label: 'Colombia', flag: '🇨🇴', localeCode: 'es'),
    LanguageOption(id: 'zw', label: 'Zimbabwe', flag: '🇿🇼', localeCode: 'en'),
    LanguageOption(id: 'vn', label: 'Vietnam', flag: '🇻🇳', localeCode: 'vi'),
    LanguageOption(id: 'gt', label: 'Guatemala', flag: '🇬🇹', localeCode: 'es'),
    LanguageOption(id: 'hn', label: 'Honduras', flag: '🇭🇳', localeCode: 'es'),
    LanguageOption(id: 'bg', label: 'Bulgaria', flag: '🇧🇬', localeCode: 'bg'),
    LanguageOption(id: 'ec', label: 'Ecuador', flag: '🇪🇨', localeCode: 'es'),
    LanguageOption(id: 'kr', label: 'South Korea', flag: '🇰🇷', localeCode: 'ko'),
    LanguageOption(id: 'lt', label: 'Lithuania', flag: '🇱🇹', localeCode: 'lt'),
    LanguageOption(id: 'lk', label: 'Sri Lanka', flag: '🇱🇰', localeCode: 'si'),
    LanguageOption(id: 'iq', label: 'Iraq', flag: '🇮🇶', localeCode: 'ar'),
    LanguageOption(id: 'eg', label: 'Egypt', flag: '🇪🇬', localeCode: 'ar'),
    LanguageOption(id: 'arg', label: 'Argentina', flag: '🇦🇷', localeCode: 'es'),
    LanguageOption(id: 'at', label: 'Austria', flag: '🇦🇹', localeCode: 'de'),
    LanguageOption(id: 'be', label: 'Belgium', flag: '🇧🇪', localeCode: 'nl'),
    LanguageOption(id: 'ma', label: 'Morocco', flag: '🇲🇦', localeCode: 'ar'),
    LanguageOption(id: 'rs', label: 'Serbia', flag: '🇷🇸', localeCode: 'sr'),
    LanguageOption(id: 'ae', label: 'United Arab Emirates', flag: '🇦🇪', localeCode: 'ar'),
    LanguageOption(id: 've', label: 'Venezuela', flag: '🇻🇪', localeCode: 'es'),
    LanguageOption(id: 'cn', label: 'China', flag: '🇨🇳', localeCode: 'zh'),
    LanguageOption(id: 'th', label: 'Thailand', flag: '🇹🇭', localeCode: 'th'),
    LanguageOption(id: 'it', label: 'Italy', flag: '🇮🇹', localeCode: 'it'),
    LanguageOption(id: 'pl', label: 'Poland', flag: '🇵🇱', localeCode: 'pl'),
    LanguageOption(id: 'br', label: 'Brazil', flag: '🇧🇷', localeCode: 'pt'),
    LanguageOption(id: 'tr', label: 'Turkey', flag: '🇹🇷', localeCode: 'tr'),
    LanguageOption(id: 'ru', label: 'Russia', flag: '🇷🇺', localeCode: 'ru'),
    LanguageOption(id: 'es', label: 'Spain', flag: '🇪🇸', localeCode: 'es'),
    LanguageOption(id: 'nl', label: 'Netherlands', flag: '🇳🇱', localeCode: 'nl'),
    LanguageOption(id: 'pt', label: 'Portugal', flag: '🇵🇹', localeCode: 'pt'),
    LanguageOption(id: 'cz', label: 'Czech Republic', flag: '🇨🇿', localeCode: 'cs'),
    LanguageOption(id: 'dk', label: 'Denmark', flag: '🇩🇰', localeCode: 'da'),
    LanguageOption(id: 'ro', label: 'Romania', flag: '🇷🇴', localeCode: 'ro'),
    LanguageOption(id: 'se', label: 'Sweden', flag: '🇸🇪', localeCode: 'sv'),
    LanguageOption(id: 'na', label: 'Namibia', flag: '🇳🇦', localeCode: 'af'),
    LanguageOption(id: 'al', label: 'Albania', flag: '🇦🇱', localeCode: 'sq'),
    LanguageOption(id: 'et', label: 'Ethiopia', flag: '🇪🇹', localeCode: 'am'),
    LanguageOption(id: 'am', label: 'Armenia', flag: '🇦🇲', localeCode: 'hy'),
    LanguageOption(id: 'az', label: 'Azerbaijan', flag: '🇦🇿', localeCode: 'az'),
    LanguageOption(id: 'eu', label: 'Basque Country', flag: '🇪🇸', localeCode: 'eu'),
    LanguageOption(id: 'by', label: 'Belarus', flag: '🇧🇾', localeCode: 'be'),
    LanguageOption(id: 'bd', label: 'Bangladesh', flag: '🇧🇩', localeCode: 'bn'),
    LanguageOption(id: 'mm', label: 'Myanmar', flag: '🇲🇲', localeCode: 'my'),
    LanguageOption(id: 'kh', label: 'Cambodia', flag: '🇰🇭', localeCode: 'km'),
    LanguageOption(id: 'ad', label: 'Andorra', flag: '🇦🇩', localeCode: 'ca'),
    LanguageOption(id: 'hr', label: 'Croatia', flag: '🇭🇷', localeCode: 'hr'),
    LanguageOption(id: 'ee', label: 'Estonia', flag: '🇪🇪', localeCode: 'et'),
    LanguageOption(id: 'fi', label: 'Finland', flag: '🇫🇮', localeCode: 'fi'),
    LanguageOption(id: 'gl', label: 'Galicia', flag: '🇪🇸', localeCode: 'gl'),
    LanguageOption(id: 'ge', label: 'Georgia', flag: '🇬🇪', localeCode: 'ka'),
    LanguageOption(id: 'gr', label: 'Greece', flag: '🇬🇷', localeCode: 'el'),
    LanguageOption(id: 'gu', label: 'Gujarati', flag: '🇮🇳', localeCode: 'gu'),
    LanguageOption(id: 'il', label: 'Israel', flag: '🇮🇱', localeCode: 'he'),
    LanguageOption(id: 'is', label: 'Iceland', flag: '🇮🇸', localeCode: 'is'),
    LanguageOption(id: 'kn', label: 'Kannada', flag: '🇮🇳', localeCode: 'kn'),
    LanguageOption(id: 'kz', label: 'Kazakhstan', flag: '🇰🇿', localeCode: 'kk'),
    LanguageOption(id: 'kg', label: 'Kyrgyzstan', flag: '🇰🇬', localeCode: 'ky'),
    LanguageOption(id: 'la', label: 'Laos', flag: '🇱🇦', localeCode: 'lo'),
    LanguageOption(id: 'lv', label: 'Latvia', flag: '🇱🇻', localeCode: 'lv'),
    LanguageOption(id: 'mk', label: 'North Macedonia', flag: '🇲🇰', localeCode: 'mk'),
    LanguageOption(id: 'ml', label: 'Malayalam', flag: '🇮🇳', localeCode: 'ml'),
    LanguageOption(id: 'mr', label: 'Marathi', flag: '🇮🇳', localeCode: 'mr'),
    LanguageOption(id: 'mn', label: 'Mongolia', flag: '🇲🇳', localeCode: 'mn'),
    LanguageOption(id: 'np', label: 'Nepal', flag: '🇳🇵', localeCode: 'ne'),
    LanguageOption(id: 'no', label: 'Norway', flag: '🇳🇴', localeCode: 'nb'),
    LanguageOption(id: 'ir', label: 'Iran', flag: '🇮🇷', localeCode: 'fa'),
    LanguageOption(id: 'pa', label: 'Punjabi', flag: '🇮🇳', localeCode: 'pa'),
    LanguageOption(id: 'ch', label: 'Switzerland', flag: '🇨🇭', localeCode: 'rm'),
    LanguageOption(id: 'sk', label: 'Slovakia', flag: '🇸🇰', localeCode: 'sk'),
    LanguageOption(id: 'si_sl', label: 'Slovenia', flag: '🇸🇮', localeCode: 'sl'),
    LanguageOption(id: 'ke', label: 'Kenya', flag: '🇰🇪', localeCode: 'sw'),
    LanguageOption(id: 'ta', label: 'Tamil', flag: '🇮🇳', localeCode: 'ta'),
    LanguageOption(id: 'te', label: 'Telugu', flag: '🇮🇳', localeCode: 'te'),
    LanguageOption(
      id: 'tw',
      label: 'Taiwan',
      flag: '🇹🇼',
      localeCode: 'zh',
      countryCode: 'TW',
    ),
    LanguageOption(id: 'ua', label: 'Ukraine', flag: '🇺🇦', localeCode: 'uk'),
    LanguageOption(id: 'pk', label: 'Pakistan', flag: '🇵🇰', localeCode: 'ur'),
    LanguageOption(id: 'zu', label: 'Zulu', flag: '🇿🇦', localeCode: 'zu'),
  ];

  static List<Locale> get supportedLocales {
    final seen = <String>{};
    final locales = <Locale>[];
    for (final option in languageOptions) {
      final key = option.translationFileCode;
      if (seen.add(key)) {
        locales.add(option.locale);
      }
    }
    return locales;
  }

  static LanguageOption optionById(String id) {
    return languageOptions.firstWhere(
      (o) => o.id == id,
      orElse: () => languageOptions.first,
    );
  }

  static LanguageOption optionForLocale(Locale locale) {
    final withCountry = languageOptions.where(
      (o) =>
          o.localeCode == locale.languageCode &&
          (o.countryCode == null ||
              o.countryCode == locale.countryCode),
    );
    if (locale.countryCode != null && locale.countryCode!.isNotEmpty) {
      final exact = withCountry.where((o) => o.countryCode == locale.countryCode);
      if (exact.isNotEmpty) return exact.first;
    }
    return withCountry.isNotEmpty
        ? withCountry.first
        : languageOptions.first;
  }

  static String labelForCode(String code) {
    return optionForLocale(Locale(code)).label;
  }

  static String flagForCode(String code) {
    return optionForLocale(Locale(code)).flag;
  }

  static Future<String?> savedCountryId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_prefsKey);
  }

  static Future<void> saveCountryId(String id) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefsKey, id);
  }

  static Future<String> currentCountryLabel(Locale locale) async {
    final saved = await savedCountryId();
    if (saved != null) {
      return optionById(saved).label;
    }
    return optionById(defaultCountryId).label;
  }
}
