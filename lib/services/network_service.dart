import 'dart:async';
import 'dart:io';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';

enum NetworkStatus {
  online,      // connected + internet reachable
  noInternet,  // no connection type (airplane mode / no signal)
  noData,      // connected to wifi/mobile but no actual data flowing
}

class NetworkService extends ChangeNotifier {
  NetworkService._();
  static final NetworkService instance = NetworkService._();

  // Ping these hosts in order — first success = online
  static const List<String> _pingHosts = [
    'google.com',
    'cloudflare.com',
    '1.1.1.1',
  ];
  static const Duration _pingTimeout  = Duration(seconds: 4);
  static const Duration _retryDelay   = Duration(seconds: 7);

  NetworkStatus _status   = NetworkStatus.online;
  bool          _checking = false;

  StreamSubscription<List<ConnectivityResult>>? _sub;
  Timer? _retryTimer;

  NetworkStatus get status   => _status;
  bool          get isOnline => _status == NetworkStatus.online;
  bool          get isOffline => _status != NetworkStatus.online;

  // ── Messages ──────────────────────────────────────────────────────────────
  String get title {
    switch (_status) {
      case NetworkStatus.online:      return '';
      case NetworkStatus.noInternet:  return 'No Internet Connection';
      case NetworkStatus.noData:      return 'No Data Available';
    }
  }

  String get message {
    switch (_status) {
      case NetworkStatus.online:
        return '';
      case NetworkStatus.noInternet:
        return 'You\'re not connected to the internet.\nConnect to Wi-Fi or enable mobile data.';
      case NetworkStatus.noData:
        return 'You\'re connected but data isn\'t flowing.\nCheck your mobile data or Wi-Fi connection.';
    }
  }

  String get shortMessage {
    switch (_status) {
      case NetworkStatus.online:      return '';
      case NetworkStatus.noInternet:  return 'No internet connection';
      case NetworkStatus.noData:      return 'Check your mobile data or Wi-Fi';
    }
  }

  String get icon {
    switch (_status) {
      case NetworkStatus.online:      return '';
      case NetworkStatus.noInternet:  return '📡';
      case NetworkStatus.noData:      return '📶';
    }
  }

  // ── Init ──────────────────────────────────────────────────────────────────
  Future<void> init() async {
    await _check();
    _sub = Connectivity().onConnectivityChanged.listen(_onConnectivityChanged);
  }

  Future<void> refresh() async {
    _retryTimer?.cancel();
    await _check();
  }

  // ── Internal ──────────────────────────────────────────────────────────────
  void _onConnectivityChanged(List<ConnectivityResult> results) => _check();

  Future<void> _check() async {
    if (_checking) return;
    _checking = true;

    try {
      final results = await Connectivity().checkConnectivity();

      // Step 1 — No network type at all
      if (results.isEmpty || results.every((r) => r == ConnectivityResult.none)) {
        _setStatus(NetworkStatus.noInternet);
        _scheduleRetry();
        return;
      }

      // Step 2 — Connected to a network type (wifi/mobile/ethernet)
      // Now verify real data flows by pinging known hosts
      final hasData = await _pingAny();

      if (hasData) {
        _setStatus(NetworkStatus.online);
        _retryTimer?.cancel();
      } else {
        // Connected to network but no data flowing
        _setStatus(NetworkStatus.noData);
        _scheduleRetry();
      }
    } finally {
      _checking = false;
    }
  }

  /// Tries each host in order. Returns true as soon as one resolves.
  Future<bool> _pingAny() async {
    for (final host in _pingHosts) {
      try {
        final result = await InternetAddress.lookup(host)
            .timeout(_pingTimeout);
        if (result.isNotEmpty && result.first.rawAddress.isNotEmpty) {
          return true;
        }
      } on SocketException {
        continue;
      } on TimeoutException {
        continue;
      } catch (_) {
        continue;
      }
    }
    return false;
  }

  void _setStatus(NetworkStatus s) {
    if (_status == s) return;
    _status = s;
    notifyListeners();
  }

  void _scheduleRetry() {
    _retryTimer?.cancel();
    _retryTimer = Timer(_retryDelay, _check);
  }

  @override
  void dispose() {
    _sub?.cancel();
    _retryTimer?.cancel();
    super.dispose();
  }
}
