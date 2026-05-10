import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../constants/app_constants.dart';

class PurchaseService extends ChangeNotifier {
  PurchaseService._();
  static final PurchaseService instance = PurchaseService._();

  static const String _expiryKey = 'remove_ads_expiry_ms';

  // ── State ─────────────────────────────────────────────────────────────────
  StreamSubscription<List<PurchaseDetails>>? _sub;
  List<ProductDetails> _products   = [];
  bool                 _adsRemoved = false;
  DateTime?            _expiry;
  bool                 _loading    = false;
  String?              _error;
  bool                 _storeAvailable = false;

  List<ProductDetails> get products        => List.unmodifiable(_products);
  bool                 get adsRemoved      => _adsRemoved;
  DateTime?            get expiry          => _expiry;
  bool                 get loading         => _loading;
  String?              get error           => _error;
  bool                 get storeAvailable  => _storeAvailable;

  // ── Init ──────────────────────────────────────────────────────────────────
  Future<void> init() async {
    await _checkSavedExpiry();

    _storeAvailable = await InAppPurchase.instance.isAvailable();
    if (!_storeAvailable) return;

    // Listen to purchase stream
    _sub = InAppPurchase.instance.purchaseStream.listen(
      _handlePurchaseUpdate,
      onError: (dynamic e) {
        _error = 'Purchase stream error: $e';
        _loading = false;
        notifyListeners();
      },
    );

    await _loadProducts();

    // Restore any existing purchases (important on iOS)
    await InAppPurchase.instance.restorePurchases();
  }

  // ── Check saved expiry on launch ──────────────────────────────────────────
  Future<void> _checkSavedExpiry() async {
    final prefs = await SharedPreferences.getInstance();
    final ms    = prefs.getInt(_expiryKey);
    if (ms == null) return;

    _expiry     = DateTime.fromMillisecondsSinceEpoch(ms);
    _adsRemoved = _expiry!.isAfter(DateTime.now());

    if (!_adsRemoved) {
      // Expired — clean up stored value
      await prefs.remove(_expiryKey);
      _expiry = null;
    }
    notifyListeners();
  }

  // ── Load products from store ──────────────────────────────────────────────
  Future<void> _loadProducts() async {
    final response = await InAppPurchase.instance
        .queryProductDetails(IAPIds.all);

    if (response.error != null) {
      _error = response.error!.message;
      notifyListeners();
      return;
    }

    // Sort by duration: day → week → month
    final order = [IAPIds.noAdsDay, IAPIds.noAdsWeek, IAPIds.noAdsMonth];
    _products = response.productDetails
      ..sort((a, b) => order.indexOf(a.id).compareTo(order.indexOf(b.id)));

    notifyListeners();
  }

  // ── Trigger a purchase ────────────────────────────────────────────────────
  Future<void> buy(String productId) async {
    _error = null;

    final matches = _products.where((p) => p.id == productId).toList();
    if (matches.isEmpty) {
      _error = 'Product not available. Please try again.';
      notifyListeners();
      return;
    }

    _loading = true;
    notifyListeners();

    // Treat as consumable — user can re-buy (time stacks)
    final param = PurchaseParam(productDetails: matches.first);
    try {
      await InAppPurchase.instance.buyConsumable(purchaseParam: param);
    } catch (e) {
      _error   = 'Could not start purchase: $e';
      _loading = false;
      notifyListeners();
    }
  }

  // ── Handle purchase stream events ─────────────────────────────────────────
  void _handlePurchaseUpdate(List<PurchaseDetails> purchases) async {
    for (final p in purchases) {
      switch (p.status) {
        case PurchaseStatus.purchased:
        case PurchaseStatus.restored:
          await _applyPurchase(p.productID);
          // Must call completePurchase on both platforms
          await InAppPurchase.instance.completePurchase(p);

        case PurchaseStatus.error:
          _error = p.error?.message ?? 'Purchase failed. Please try again.';

        case PurchaseStatus.canceled:
          // User cancelled — no action, no error shown
          break;

        case PurchaseStatus.pending:
          // Payment pending (e.g. cash payment in some regions)
          break;
      }
    }
    _loading = false;
    notifyListeners();
  }

  // ── Apply a valid purchase ────────────────────────────────────────────────
  Future<void> _applyPurchase(String productId) async {
    final duration = IAPIds.durations[productId];
    if (duration == null) return;

    final now = DateTime.now();

    // Stack on top of existing active period, or start fresh
    final base = (_adsRemoved && _expiry != null && _expiry!.isAfter(now))
        ? _expiry!
        : now;

    _expiry     = base.add(duration);
    _adsRemoved = true;
    _error      = null;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_expiryKey, _expiry!.millisecondsSinceEpoch);

    notifyListeners();
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  /// Refreshes the active status — call periodically or on app resume.
  Future<void> refresh() async => _checkSavedExpiry();

  /// Dismisses the current error message.
  void clearError() {
    _error = null;
    notifyListeners();
  }

  /// Human-readable status label shown in UI.
  /// Returns empty string if ads are not removed.
  String get statusLabel {
    if (!_adsRemoved || _expiry == null) return '';
    final diff = _expiry!.difference(DateTime.now());
    if (diff.isNegative) return '';
    if (diff.inDays >= 1)  return 'Ad-free · ${diff.inDays}d ${diff.inHours % 24}h left';
    if (diff.inHours >= 1) return 'Ad-free · ${diff.inHours}h ${diff.inMinutes % 60}m left';
    return 'Ad-free · ${diff.inMinutes}m left';
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }
}
