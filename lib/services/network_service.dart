import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:internet_connection_checker_plus/internet_connection_checker_plus.dart';

// ── Network Status ────────────────────────────────────────────────────────────
enum NetworkStatus {
  online,      // connected AND real internet is reachable
  noInternet,  // no network type at all (airplane mode / no signal)
  noData,      // connected to wifi or mobile but NO data flowing
               // e.g. WiFi portal, mobile data disabled, ISP issue
}

/// Dual-layer network check:
/// Layer 1 — ConnectivityResult (wifi/mobile/none)
/// Layer 2 — internet_connection_checker_plus (actual data reachability)
///
/// This correctly handles:
///   • Airplane mode           → noInternet
///   • WiFi connected, no data  → noData
///   • Mobile signal, data off  → noData
///   • WiFi portal/captive      → noData
///   • Normal connection        → online
class NetworkService extends ChangeNotifier {
  NetworkService._();
  static final NetworkService instance = NetworkService._();

  NetworkStatus _status   = NetworkStatus.online;
  bool          _checking = false;

  StreamSubscription<List<ConnectivityResult>>? _connectivitySub;
  StreamSubscription<InternetStatus>?           _internetSub;

  NetworkStatus get status   => _status;
  bool          get isOnline  => _status == NetworkStatus.online;
  bool          get isOffline => _status != NetworkStatus.online;

  // ── Human-readable messages ────────────────────────────────────────────────
  String get title {
    switch (_status) {
      case NetworkStatus.online:      return '';
      case NetworkStatus.noInternet:  return 'No Internet Connection';
      case NetworkStatus.noData:      return 'No Data Available';
    }
  }

  String get message {
    switch (_status) {
      case NetworkStatus.online:     return '';
      case NetworkStatus.noInternet: return 'You\'re not connected.\nConnect to Wi-Fi or enable mobile data to continue.';
      case NetworkStatus.noData:     return 'Connected but no data flowing.\nCheck your mobile data or Wi-Fi connection.';
    }
  }

  String get shortMessage {
    switch (_status) {
      case NetworkStatus.online:     return '';
      case NetworkStatus.noInternet: return 'No internet connection';
      case NetworkStatus.noData:     return 'Check your mobile data or Wi-Fi';
    }
  }

  String get icon {
    switch (_status) {
      case NetworkStatus.online:     return '';
      case NetworkStatus.noInternet: return '📡';
      case NetworkStatus.noData:     return '📶';
    }
  }

  // ── Init ──────────────────────────────────────────────────────────────────
  Future<void> init() async {
    // Check immediately on startup
    await _fullCheck();

    // React to network type changes (wifi ↔ mobile ↔ none)
    _connectivitySub = Connectivity().onConnectivityChanged.listen(
      (_) => _fullCheck(),
    );

    // React to real internet status changes from the checker package
    // This fires when actual reachability changes (e.g. data runs out)
    _internetSub = InternetConnection().onStatusChange.listen(
      (status) => _applyInternetStatus(status),
    );
  }

  // ── Manual refresh ────────────────────────────────────────────────────────
  Future<void> refresh() => _fullCheck();

  // ── Internal ──────────────────────────────────────────────────────────────
  Future<void> _fullCheck() async {
    if (_checking) return;
    _checking = true;

    try {
      // Step 1: Check network type
      final results = await Connectivity().checkConnectivity();
      final hasNetworkType = results.isNotEmpty &&
          results.any((r) => r != ConnectivityResult.none);

      if (!hasNetworkType) {
        // No network type at all — definitely no internet
        _setStatus(NetworkStatus.noInternet);
        return;
      }

      // Step 2: Connected to a network — verify actual internet reachability
      // internet_connection_checker_plus tries multiple endpoints:
      // Default: dns1.p01.nsone.net, dns2.p01.nsone.net, icanhazip.com
      final hasInternet = await InternetConnection().hasInternetAccess;

      if (hasInternet) {
        _setStatus(NetworkStatus.online);
      } else {
        // Connected to wifi/mobile but no actual data flowing
        _setStatus(NetworkStatus.noData);
      }
    } finally {
      _checking = false;
    }
  }

  void _applyInternetStatus(InternetStatus status) {
    if (status == InternetStatus.connected) {
      _setStatus(NetworkStatus.online);
    } else {
      // Don't blindly set noData — check what type of connection we have
      // to give the right message
      _fullCheck();
    }
  }

  void _setStatus(NetworkStatus s) {
    if (_status == s) return;
    _status = s;
    notifyListeners();
  }

  @override
  void dispose() {
    _connectivitySub?.cancel();
    _internetSub?.cancel();
    super.dispose();
  }
}
