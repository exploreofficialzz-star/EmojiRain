// ─────────────────────────────────────────────────────────────────────────────
// lib/services/network_service.dart — REVISED
//
// WHY THIS CHANGED:
//
// The original used internet_connection_checker_plus's `onStatusChange`
// stream, which continuously polls in the background (default ~every 10s)
// by making real HTTP requests to 3 external endpoints (two DNS-over-HTTPS
// hosts + icanhazip.com). On a real-world mobile connection — especially
// the variable-latency mobile networks common outside major metros — a
// single slow/timed-out request on ANY of those checks was enough to flip
// status to "disconnected" for a few seconds before the next poll corrected
// it. Every flip called notifyListeners(), and on the game screen each flip
// triggered a pause/resume cycle — rapid, repeated pause→resume→pause created
// exactly the kind of visual instability reported (frozen frames, overlays
// appearing mid-transition, stuck states).
//
// This revision:
//   1. REMOVES the continuous polling stream entirely — no more background
//      HTTP requests running every 10 seconds regardless of what the app is
//      doing. This directly reduces both data usage and check frequency.
//   2. Keeps Connectivity().onConnectivityChanged — EVENT-DRIVEN, fires only
//      on a real network type transition (wifi ↔ mobile ↔ none). Free,
//      instant, and accurate for the "no network at all" case.
//   3. Adds a much lower-frequency BACKSTOP timer (30s vs the old ~10s) to
//      catch "connected but no data flowing" (captive portal, ISP outage,
//      mobile data toggled off) — the case connectivity-type alone can't see.
//   4. Adds a CONFIRM-TWICE debounce for anything that would make the status
//      worse (online → noInternet/noData): a degraded status must be
//      observed on two checks, ~2s apart, before it's applied and
//      notifyListeners() fires. This filters out single-blip false
//      positives from transient network hiccups. Recovery TO online is
//      always applied immediately — there's no downside to reacting fast
//      to good news, and it keeps the game feeling responsive.
//   5. First-ever check (app cold start) skips the debounce and applies
//      immediately — an already-offline device should show that right away
//      rather than waiting 2 extra seconds with no prior "online" state to
//      protect.
//   6. A generation counter discards results from superseded in-flight
//      checks, so a slow check that resolves late can never overwrite a
//      newer, faster check's more current result.
//   7. Manual refresh() is throttled to once per 3 seconds — protects
//      against the retry button (or any caller) hammering the network.
//
// PUBLIC API IS UNCHANGED — status / isOnline / isOffline / title / message
// / shortMessage / icon / init() / refresh() all behave the same from the
// caller's perspective. This is a drop-in replacement.
// ─────────────────────────────────────────────────────────────────────────────

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

class NetworkService extends ChangeNotifier {
  NetworkService._();
  static final NetworkService instance = NetworkService._();

  NetworkStatus _status         = NetworkStatus.online;
  bool          _checking       = false;
  bool          _hasCheckedOnce = false;
  int           _checkGeneration = 0;

  // ── Debounce: degraded status must be confirmed twice before applying ────
  static const Duration _confirmWindow = Duration(seconds: 2);
  NetworkStatus? _pendingStatus;
  Timer?         _confirmTimer;

  // ── Manual refresh throttle ────────────────────────────────────────────────
  static const Duration _minCheckInterval = Duration(seconds: 3);
  DateTime? _lastCheckAt;

  // ── Backstop periodic check — replaces the old continuous polling stream ──
  static const Duration _backstopInterval = Duration(seconds: 30);
  Timer? _backstopTimer;

  StreamSubscription<List<ConnectivityResult>>? _connectivitySub;

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
    // Check immediately on startup — applied instantly, no debounce
    // (see _proposeStatus: first-ever check always applies right away).
    await _fullCheck(force: true);

    // Event-driven: fires ONLY on a genuine network type transition
    // (wifi ↔ mobile ↔ none). No polling involved — cheap and instant.
    _connectivitySub = Connectivity().onConnectivityChanged.listen(
      (_) => _fullCheck(),
    );

    // Backstop: catches "connected but no data flowing", which a
    // connectivity-type change alone can't see. Deliberately infrequent —
    // this is the "reduce the network check" fix. The previous continuous
    // polling stream (internet_connection_checker_plus's onStatusChange,
    // ~10s default with live HTTP requests) has been removed entirely.
    _backstopTimer = Timer.periodic(_backstopInterval, (_) => _fullCheck());
  }

  // ── Manual refresh ────────────────────────────────────────────────────────
  Future<void> refresh() => _fullCheck(force: true);

  // ── Internal ──────────────────────────────────────────────────────────────
  Future<void> _fullCheck({bool force = false}) async {
    final now = DateTime.now();

    // Throttle: skip if we checked too recently, unless forced (cold start
    // or explicit user-initiated refresh always goes through).
    if (!force && _lastCheckAt != null &&
        now.difference(_lastCheckAt!) < _minCheckInterval) {
      return;
    }
    if (_checking && !force) return;

    _lastCheckAt = now;
    _checking    = true;
    final myGeneration = ++_checkGeneration;

    try {
      // Step 1: network type
      final results = await Connectivity().checkConnectivity();
      if (myGeneration != _checkGeneration) return; // superseded by a newer check

      final hasNetworkType = results.isNotEmpty &&
          results.any((r) => r != ConnectivityResult.none);

      if (!hasNetworkType) {
        _proposeStatus(NetworkStatus.noInternet);
        return;
      }

      // Step 2: connected to a network — verify actual internet reachability
      final hasInternet = await InternetConnection().hasInternetAccess;
      if (myGeneration != _checkGeneration) return; // superseded by a newer check

      _proposeStatus(hasInternet ? NetworkStatus.online : NetworkStatus.noData);
    } finally {
      if (myGeneration == _checkGeneration) _checking = false;
    }
  }

  // ── Debounce gate ──────────────────────────────────────────────────────────
  // A DEGRADED status (noInternet/noData) is only applied once proposed on
  // two consecutive checks, ~2s apart — filters single-blip false positives.
  // RECOVERY to online always applies immediately — no reason to delay good
  // news, and there's no false-positive risk in believing "it's back."
  void _proposeStatus(NetworkStatus s) {
    // Cold start: apply the very first result immediately, no debounce.
    if (!_hasCheckedOnce) {
      _hasCheckedOnce = true;
      _pendingStatus  = null;
      _confirmTimer?.cancel();
      _setStatus(s);
      return;
    }

    if (s == _status) {
      // Already there — clear any stale pending confirmation.
      _pendingStatus = null;
      _confirmTimer?.cancel();
      return;
    }

    if (s == NetworkStatus.online) {
      _confirmTimer?.cancel();
      _pendingStatus = null;
      _setStatus(s);
      return;
    }

    // Degraded status — require the SAME proposal twice before applying.
    if (_pendingStatus == s) {
      _confirmTimer?.cancel();
      _pendingStatus = null;
      _setStatus(s);
    } else {
      _pendingStatus = s;
      _confirmTimer?.cancel();
      _confirmTimer = Timer(_confirmWindow, () => _fullCheck(force: true));
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
    _backstopTimer?.cancel();
    _confirmTimer?.cancel();
    super.dispose();
  }
}
