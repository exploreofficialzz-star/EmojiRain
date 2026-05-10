import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';
import '../services/network_service.dart';

// ─────────────────────────────────────────────────────────────────────────────
// NetworkBanner
// Drop this into any Scaffold body using a Stack — it floats at the top.
// Usage:
//   Stack(
//     children: [
//       YourScreenContent(),
//       const NetworkBanner(),
//     ],
//   )
// ─────────────────────────────────────────────────────────────────────────────
class NetworkBanner extends StatelessWidget {
  const NetworkBanner({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<NetworkService>(
      builder: (context, net, _) {
        if (net.isOnline) return const SizedBox.shrink();
        return _OfflineBanner(status: net.status, net: net);
      },
    );
  }
}

class _OfflineBanner extends StatelessWidget {
  final NetworkStatus status;
  final NetworkService net;

  const _OfflineBanner({required this.status, required this.net});

  @override
  Widget build(BuildContext context) {
    final isNoInternet = status == NetworkStatus.noInternet;

    final Color bannerColor = isNoInternet
        ? const Color(0xFFB71C1C)
        : const Color(0xFFE65100);

    final Color borderColor = isNoInternet
        ? const Color(0xFFEF5350)
        : const Color(0xFFFF9800);

    final String icon  = isNoInternet ? '📡' : '📶';
    final String title = isNoInternet
        ? 'No internet connection'
        : 'Connected — no data';
    final String body = isNoInternet
        ? 'Connect to the internet to continue.'
        : 'Check your mobile data or WiFi.';

    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
          child: Material(
            color: Colors.transparent,
            child: Container(
              decoration: BoxDecoration(
                color: bannerColor.withOpacity(0.97),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: borderColor.withOpacity(0.6), width: 1.2),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.5),
                    blurRadius: 16,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              child: Row(
                children: [
                  Text(icon, style: const TextStyle(fontSize: 22)),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          title,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                            letterSpacing: 0.2,
                          ),
                        ),
                        const SizedBox(height: 1),
                        Text(
                          body,
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.white.withOpacity(0.80),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Retry button
                  GestureDetector(
                    onTap: () => net.refresh(),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                            color: Colors.white.withOpacity(0.30), width: 1),
                      ),
                      child: const Text(
                        'Retry',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            )
                .animate()
                .slideY(
                  begin: -1.0,
                  end: 0.0,
                  duration: 350.ms,
                  curve: Curves.easeOutCubic,
                )
                .fadeIn(duration: 250.ms),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// NetworkAwareAction
// Wrap any action that requires internet (e.g. IAP, ad load).
// Shows a SnackBar if offline and blocks the action.
// Usage:
//   NetworkAwareAction.run(
//     context: context,
//     action: () => purchaseSomething(),
//   );
// ─────────────────────────────────────────────────────────────────────────────
class NetworkAwareAction {
  static bool run({
    required BuildContext context,
    required VoidCallback action,
    String? offlineOverrideMessage,
  }) {
    final net = NetworkService.instance;
    if (net.isOnline) {
      action();
      return true;
    }

    final message = offlineOverrideMessage ?? net.shortMessage;
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Text(
              net.status == NetworkStatus.noInternet ? '📡 ' : '📶 ',
              style: const TextStyle(fontSize: 18),
            ),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
              ),
            ),
          ],
        ),
        backgroundColor: net.status == NetworkStatus.noInternet
            ? const Color(0xFFB71C1C)
            : const Color(0xFFE65100),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(12),
        duration: const Duration(seconds: 3),
        action: SnackBarAction(
          label: 'Retry',
          textColor: Colors.white,
          onPressed: () => net.refresh(),
        ),
      ),
    );
    return false;
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// FullScreenOfflineGate
// Use this when you MUST have internet before the user can proceed.
// Shows a full-screen offline message with retry.
// ─────────────────────────────────────────────────────────────────────────────
class FullScreenOfflineGate extends StatelessWidget {
  final Widget child;
  const FullScreenOfflineGate({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Consumer<NetworkService>(
      builder: (context, net, _) {
        if (net.isOnline) return child;
        return _OfflineFullScreen(status: net.status, net: net);
      },
    );
  }
}

class _OfflineFullScreen extends StatelessWidget {
  final NetworkStatus  status;
  final NetworkService net;
  const _OfflineFullScreen({required this.status, required this.net});

  @override
  Widget build(BuildContext context) {
    final isNoInternet = status == NetworkStatus.noInternet;
    final icon    = isNoInternet ? '📡' : '📶';
    final title   = isNoInternet ? 'No Internet' : 'No Data';
    final body    = isNoInternet
        ? 'Connect to the internet\nto continue playing.'
        : 'You\'re connected but there\'s\nno data. Check your mobile\ndata or WiFi connection.';

    return Container(
      color: const Color(0xFF08081A),
      child: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 40),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(icon, style: const TextStyle(fontSize: 64))
                  .animate(onPlay: (c) => c.repeat(reverse: true))
                  .scale(
                    begin: const Offset(1.0, 1.0),
                    end: const Offset(1.1, 1.1),
                    duration: 1200.ms,
                    curve: Curves.easeInOut,
                  ),
              const SizedBox(height: 24),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w900,
                  color: Colors.white,
                  letterSpacing: 1,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                body,
                style: const TextStyle(
                  fontSize: 15,
                  color: Color(0xFFB0BEC5),
                  height: 1.6,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 36),
              GestureDetector(
                onTap: () => net.refresh(),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 32, vertical: 16),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFFFFD700), Color(0xFFFF8C00)],
                    ),
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFFFFD700).withOpacity(0.3),
                        blurRadius: 20,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.refresh_rounded,
                          color: Colors.black, size: 22),
                      SizedBox(width: 8),
                      Text(
                        'Try Again',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                          color: Colors.black,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
