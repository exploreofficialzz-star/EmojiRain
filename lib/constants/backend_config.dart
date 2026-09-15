/// Backend API configuration.
///
/// Change [apiBaseUrl] to point at your deployed FastAPI instance.
/// The Play Store link is embedded in multiplayer share messages.
class BackendConfig {
  const BackendConfig._();

  /// FastAPI base URL — no trailing slash.
  /// Example production: 'https://api.emojirain.chastech.com'
  static const String apiBaseUrl = 'https://api.emojirain.chastech.com';

  /// Google Play Store link (used in multiplayer invite copy-text).
  static const String playStoreUrl =
      'https://play.google.com/store/apps/details?id=com.chastech.emojirain';
}
