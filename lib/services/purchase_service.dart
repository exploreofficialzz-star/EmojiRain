import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../constants/app_constants.dart';

class PurchaseService extends ChangeNotifier {
  PurchaseService._();
  static final PurchaseService instance = PurchaseService._();

  static const String _expiryKey = 'remove_ads_expiry_ms';

  StreamSubscription<List<PurchaseDetails>>? _sub;
  List<ProductDetails> _products       = [];
  bool                 _adsRemoved     = false;
  DateTime?            _expiry;
  bool                 _loading        = false;
  String?              _error;
  bool                 _storeAvailable = false;
  bool                 _billingChecked = false;

  List<ProductDetails> get products       => List.unmodifiable(_products);
  bool                 get adsRemoved     => _adsRemoved;
  DateTime?            get expiry         => _expiry;
  bool                 get loading        => _loading;
  String?              get error          => _error;
  bool                 get storeAvailable => _storeAvailable;
  bool                 get billingChecked => _billingChecked;

  Future<void> init() async {
    await _checkSavedExpiry();

    _storeAvailable = await InAppPurchase.instance.isAvailable();
    _billingChecked = true;

    if (!_storeAvailable) {
      notifyListeners();
      return;
    }

    _sub = InAppPurchase.instance.purchaseStream.listen(
      _handlePurchaseUpdate,
      onError: (dynamic e) {
        _error   = 'Purchase stream error: $e';
        _loading = false;
        notifyListeners();
      },
    );

    await _loadProducts();
    await InAppPurchase.instance.restorePurchases();
  }

  Future<void> _checkSavedExpiry() async {
    final prefs = await SharedPreferences.getInstance();
    final ms    = prefs.getInt(_expiryKey);
    if (ms == null) return;

    _expiry     = DateTime.fromMillisecondsSinceEpoch(ms);
    _adsRemoved = _expiry!.isAfter(DateTime.now());

    if (!_adsRemoved) {
      await prefs.remove(_expiryKey);
      _expiry = null;
    }
    notifyListeners();
  }

  Future<void> _loadProducts() async {
    final response =
        await InAppPurchase.instance.queryProductDetails(IAPIds.all);

    if (response.error != null) {
      _error = response.error!.message;
      notifyListeners();
      return;
    }

    final order = [IAPIds.noAdsDay, IAPIds.noAdsWeek, IAPIds.noAdsMonth];
    _products = response.productDetails
      ..sort((a, b) => order.indexOf(a.id).compareTo(order.indexOf(b.id)));

    notifyListeners();
  }

  // ── Google Play / App Store IAP ───────────────────────────────────────────
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

    final param = PurchaseParam(productDetails: matches.first);
    try {
      await InAppPurchase.instance.buyConsumable(purchaseParam: param);
    } catch (e) {
      _error   = 'Could not start purchase: $e';
      _loading = false;
      notifyListeners();
    }
  }

  void _handlePurchaseUpdate(List<PurchaseDetails> purchases) async {
    for (final p in purchases) {
      switch (p.status) {
        case PurchaseStatus.purchased:
        case PurchaseStatus.restored:
          final dur = IAPIds.durations[p.productID];
          if (dur != null) await _applyDuration(dur);
          await InAppPurchase.instance.completePurchase(p);

        case PurchaseStatus.error:
          _error = p.error?.message ?? 'Purchase failed. Please try again.';

        case PurchaseStatus.canceled:
          break;

        case PurchaseStatus.pending:
          break;
      }
    }
    _loading = false;
    notifyListeners();
  }

  // ── Paystack payment activation ───────────────────────────────────────────
  Future<void> activatePaystackPurchase(String productId) async {
    final duration = IAPIds.durations[productId];
    if (duration == null) return;
    await _applyDuration(duration);
  }

  // ── Core: apply duration to the remove-ads timer ──────────────────────────
  Future<void> _applyDuration(Duration duration) async {
    final now  = DateTime.now();
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

  Future<void> refresh()  async => _checkSavedExpiry();
  void         clearError()     { _error = null; notifyListeners(); }

  String get statusLabel {
    if (!_adsRemoved || _expiry == null) return '';
    final diff = _expiry!.difference(DateTime.now());
    if (diff.isNegative)   return '';
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
