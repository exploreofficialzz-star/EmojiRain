import 'package:flutter/services.dart';

class InstallSourceService {
  InstallSourceService._();

  static const MethodChannel _channel =
      MethodChannel('com.chastech.emojirain/install_source');

  /// Google Play Store's package name — the only source where Google IAP works.
  static const String _playStorePackage = 'com.android.vending';

  /// Returns true ONLY when the app was installed via Google Play Store.
  static Future<bool> isFromPlayStore() async {
    try {
      final installer =
          await _channel.invokeMethod<String>('getInstallerPackage');
      return installer == _playStorePackage;
    } catch (_) {
      // Channel error → default to Paystack (never block a non-Play purchase)
      return false;
    }
  }
}
