class AppConstants {
  AppConstants._();

  static const String appName = 'Utang Tracker';
  static const String logoAsset = 'assets/images/new-logo.png';

  static const List<String> paymentMethods = [
    'Cash',
    'GCash',
    'Bank Transfer',
    'Other',
  ];

  static const int recentItemsLimit = 5;

  static const String githubOwner = 'awenmirasol234';
  static const String githubRepo = 'utang-tracker';
  static const String githubApiBaseUrl = 'https://api.github.com';

  static const String githubLatestReleaseUrl =
      'https://github.com/awenmirasol234/utang-tracker/releases/latest';

  static const String rawReleaseNotesUrl =
      'https://raw.githubusercontent.com/awenmirasol234/utang-tracker/main/assets/release_notes/current.json';
  static const String githubReleasesBaseUrl =
      'https://github.com/awenmirasol234/utang-tracker/releases/download';

  static const String apkAssetPrefix = 'utang-tracker';

  static const String universalAbiName = 'universal';

  static const String updaterChannel = 'com.example.utang_tracker/updater';
}
