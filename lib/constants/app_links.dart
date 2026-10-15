class AppLinks {
  static const String supportEmail = 'supportmateen@gmail.com';
  static const String androidPackage = 'com.smartprinter.android';
  static const String privacyPolicy =
      'https://sites.google.com/view/privacy-policy-mateen/home';
  static const String termsOfService =
      'https://sites.google.com/view/mateen-ahmad-terms-/home';

  static String get supportEmailUri => 'mailto:$supportEmail';

  static Uri get playStoreMarket =>
      Uri.parse('market://details?id=$androidPackage');

  static Uri get playStoreWeb => Uri.parse(
        'https://play.google.com/store/apps/details?id=$androidPackage',
      );
}
