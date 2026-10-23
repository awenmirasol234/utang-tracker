class AppConstants {
  AppConstants._();

  static const String appName = 'Utang Tracker';
  static const String logoAsset = 'assets/images/new-logo.png';

  static const String defaultPaymentMethod = 'Cash';

  static const int recentItemsLimit = 5;

  static const String githubOwner = 'awenmirasol234';
  static const String githubRepo = 'utang-tracker';

  static const String githubLatestReleaseUrl =
      'https://github.com/awenmirasol234/utang-tracker/releases/latest';

  static const String rawReleaseNotesUrl =
      'https://raw.githubusercontent.com/awenmirasol234/utang-tracker/main/assets/release_notes/current.json';
  static const String githubReleasesBaseUrl =
      'https://github.com/awenmirasol234/utang-tracker/releases/download';

  static const String apkAssetPrefix = 'utang-tracker';

  static const String universalAbiName = 'universal';

  static const String updaterChannel = 'com.example.utang_tracker/updater';

  static const String googleDriveServerClientId = String.fromEnvironment(
    'GOOGLE_DRIVE_SERVER_CLIENT_ID',
  );

  /// How often the app polls for updates while it is in the foreground.
  static const Duration updateCheckInterval = Duration(hours: 6);

  /// Grace period before the first automatic check, so that the update
  /// repository is never read while the app is still starting up.
  static const Duration updateCheckStartupGrace = Duration(minutes: 1);
}
