import 'dart:async';
import 'dart:io';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';

// ── Network Status ────────────────────────────────────────────────────────────
enum NetworkStatus {
  online,      // connected and internet is reachable
  noInternet,  // no connection type at all (airplane mode / no signal)
  noData,      // connected to wifi or mobile but no actual internet access
}

class NetworkService extends ChangeNotifier {
  NetworkService._();
  static final NetworkService instance = NetworkService._();

  static const String _pingHost      = 'google.com';
  static const Duration _pingTimeout = Duration(seconds: 5);
  static const Duration _retryDelay  = Duration(seconds: 8);

  NetworkStatus _status = NetworkStatus.online;
  bool          _checking = false;
  StreamSubscription<List<ConnectivityResult>>? _sub;
  Timer? _retryTimer;

  NetworkStatus get status    => _status;
  bool          get isOnline  => _status == NetworkStatus.online;
  bool          get isOffline => _status != NetworkStatus.online;

  // ── Human-readable messages per state ──────────────────────────────────────
  String get message {
    switch (_status) {
      case NetworkStatus.online:
        return '';
      case NetworkStatus.noInternet:
        return 'No internet connection.\nConnect to the internet to continue.';
      case NetworkStatus.noData:
        return 'Connected but no data.\nCheck your mobile data or WiFi.';
    }
  }

  // Short single-line label for banners / snackbars
  String get shortMessage {
    switch (_status) {
      case NetworkStatus.online:
        return '';
      case NetworkStatus.noInternet:
        return 'No internet connection';
      case NetworkStatus.noData:
        return 'Check your mobile data or WiFi';
    }
  }

  // ── Init ──────────────────────────────────────────────────────────────────
  Future<void> init() async {
    // Check immediately on startup
    await _check();

    // Re-check every time connectivity type changes
    _sub = Connectivity().onConnectivityChanged.listen(
      (List<ConnectivityResult> results) => _checkFromResults(results),
    );
  }

  // ── Manual refresh (e.g. from "Retry" button) ─────────────────────────────
  Future<void> refresh() async {
    _retryTimer?.cancel();
    await _check();
  }

  // ── Internal ──────────────────────────────────────────────────────────────
  Future<void> _check() async {
    if (_checking) return;
    _checking = true;

    try {
      final results = await Connectivity().checkConnectivity();
      await _checkFromResults(results);
    } finally {
      _checking = false;
    }
  }

  Future<void> _checkFromResults(List<ConnectivityResult> results) async {
    // If no connection type at all
    if (results.isEmpty || results.every((r) => r == ConnectivityResult.none)) {
      _setStatus(NetworkStatus.noInternet);
      _scheduleRetry();
      return;
    }

    // Connected to a network — verify actual internet reachability
    final reachable = await _pingInternet();
    if (reachable) {
      _setStatus(NetworkStatus.online);
      _retryTimer?.cancel();
    } else {
      // Has a network type but cannot reach internet
      _setStatus(NetworkStatus.noData);
      _scheduleRetry();
    }
  }

  Future<bool> _pingInternet() async {
    try {
      final result = await InternetAddress.lookup(_pingHost)
          .timeout(_pingTimeout);
      return result.isNotEmpty && result.first.rawAddress.isNotEmpty;
    } on SocketException {
      return false;
    } on TimeoutException {
      return false;
    } catch (_) {
      return false;
    }
  }

  void _setStatus(NetworkStatus s) {
    if (_status == s) return;
    _status = s;
    notifyListeners();
  }

  // Auto-retry when offline — re-checks every 8 seconds
  void _scheduleRetry() {
    _retryTimer?.cancel();
    _retryTimer = Timer(_retryDelay, () async {
      await _check();
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    _retryTimer?.cancel();
    super.dispose();
  }
}
