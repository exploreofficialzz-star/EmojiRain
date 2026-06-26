import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class CoinService extends ChangeNotifier {
  CoinService._();
  static final CoinService instance = CoinService._();

  static const String _balanceKey = 'coin_balance';

  int _balance = 0;

  int get balance => _balance;

  String get formattedBalance {
    if (_balance >= 1000000) return '${(_balance / 1000000).toStringAsFixed(1)}M';
    if (_balance >= 1000)    return '${(_balance / 1000).toStringAsFixed(1)}K';
    return '$_balance';
  }

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    _balance = prefs.getInt(_balanceKey) ?? 0;
    notifyListeners();
  }

  Future<void> addCoins(int amount) async {
    if (amount <= 0) return;
    _balance += amount;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_balanceKey, _balance);
    notifyListeners();
  }

  Future<bool> spendCoins(int amount) async {
    if (_balance < amount) return false;
    _balance -= amount;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_balanceKey, _balance);
    notifyListeners();
    return true;
  }
}
