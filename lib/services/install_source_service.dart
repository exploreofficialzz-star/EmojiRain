// ─────────────────────────────────────────────────────────────────────────────
// lib/services/install_source_service.dart
//
// WHY THIS EXISTS:
//   InAppPurchase.instance.isAvailable() returns TRUE on any Android device
//   that has Google Play Services — including sideloaded APKs. That means
//   sideloaded builds hit the IAP flow, Play Store rejects the purchase, and
//   the user sees "item could not be found".
//
//   The correct check is the actual installer package name:
//     com.android.vending         → installed from Google Play  → IAP flow
//     anything else / null        → sideloaded, Samsung, Huawei → Paystack flow
// ─────────────────────────────────────────────────────────────────────────────

import 'package:flutter/services.dart';

class InstallSourceService {
  InstallSourceService._();

  static const MethodChannel _channel =
      MethodChannel('com.chastech.emojirain/install_source');

  /// Google Play Store's package name — the only source where Google IAP works.
  static const String _playStorePackage = 'com.android.vending';

  /// Returns true ONLY when the app was installed via Google Play Store.
  ///
  /// Returns false for:
  ///   • Sideloaded APK           (installer = null / packageinstaller)
  ///   • Samsung Galaxy Store     (installer = com.sec.android.app.samsungapps)
  ///   • Huawei AppGallery        (installer = com.huawei.appmarket)
  ///   • Amazon Appstore          (installer = com.amazon.venezia)
  ///   • Debug / flutter run      (installer = null)
  ///
  /// In all false cases, [PurchaseService] activates the Paystack flow.
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
