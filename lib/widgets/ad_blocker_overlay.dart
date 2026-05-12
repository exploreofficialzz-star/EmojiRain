import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';
import '../constants/app_constants.dart';
import '../services/ad_service.dart';
import '../services/purchase_service.dart';
import 'remove_ads_sheet.dart';

/// App-level overlay — placed in MaterialApp.builder so it covers every screen.
/// Shown when AdService detects ads are being blocked AND user hasn't purchased
/// Remove Ads.
class AdBlockerOverlay extends StatelessWidget {
  const AdBlockerOverlay({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer2<AdService, PurchaseService>(
      builder: (context, adService, purchase, _) {
        // Only show when ads are blocked and user hasn't purchased remove-ads
        if (!adService.adsBlocked || purchase.adsRemoved) {
          return const SizedBox.shrink();
        }
        return const _BlockerScreen();
      },
    );
  }
}

class _BlockerScreen extends StatefulWidget {
  const _BlockerScreen();

  @override
  State<_BlockerScreen> createState() => _BlockerScreenState();
}

class _BlockerScreenState extends State<_BlockerScreen> {
  bool _retrying = false;

  Future<void> _retry() async {
    setState(() => _retrying = true);
    AdService.instance.retryAds();
    // Give it 4 seconds to attempt loading
    await Future.delayed(const Duration(seconds: 4));
    if (mounted) setState(() => _retrying = false);
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: Container(
        color: const Color(0xFF06060F).withOpacity(0.97),
        child: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 36),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // ── Icon ─────────────────────────────────────────────
                  Container(
                    width: 110, height: 110,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppColors.error.withOpacity(0.12),
                      border: Border.all(
                          color: AppColors.error.withOpacity(0.4), width: 2),
                    ),
                    child: const Center(
                      child: Text('🚫', style: TextStyle(fontSize: 52)),
                    ),
                  )
                      .animate(onPlay: (c) => c.repeat(reverse: true))
                      .scale(
                        begin: const Offset(1.0, 1.0),
                        end:   const Offset(1.05, 1.05),
                        duration: 1400.ms,
                        curve: Curves.easeInOut,
                      ),

                  const SizedBox(height: 28),

                  // ── Title ─────────────────────────────────────────────
                  ShaderMask(
                    shaderCallback: (b) =>
                        AppColors.goldGradient.createShader(b),
                    child: const Text(
                      'Ads Are Disabled',
                      style: TextStyle(
                        fontSize:   28,
                        fontWeight: FontWeight.w900,
                        color:      Colors.white,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),

                  // ── Body ──────────────────────────────────────────────
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color:        AppColors.surfaceCard,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: Colors.white.withOpacity(0.08)),
                    ),
                    child: const Text(
                      'EmojiRain is free because of ads.\n\n'
                      'It looks like ads are being blocked on your device. '
                      'Please disable your ad blocker or enable ads '
                      'to keep playing for free.',
                      style: TextStyle(
                        fontSize:   14,
                        color:      AppColors.textSecondary,
                        height:     1.6,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),

                  const SizedBox(height: 32),

                  // ── Enable Ads & Retry ────────────────────────────────
                  GestureDetector(
                    onTap: _retrying ? null : _retry,
                    child: Container(
                      width:  double.infinity,
                      height: 58,
                      decoration: BoxDecoration(
                        gradient:     AppColors.primaryBtnGradient,
                        borderRadius: BorderRadius.circular(18),
                        boxShadow: [
                          BoxShadow(
                            color:      AppColors.primary.withOpacity(0.35),
                            blurRadius: 20,
                            offset:     const Offset(0, 6),
                          ),
                        ],
                      ),
                      child: _retrying
                          ? const Center(
                              child: SizedBox(
                                width:  24,
                                height: 24,
                                child:  CircularProgressIndicator(
                                  color:       Colors.black,
                                  strokeWidth: 3,
                                ),
                              ),
                            )
                          : const Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text('✅', style: TextStyle(fontSize: 22)),
                                SizedBox(width: 10),
                                Column(
                                  mainAxisSize: MainAxisSize.min,
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Enable Ads & Retry',
                                      style: TextStyle(
                                        fontSize:   15,
                                        fontWeight: FontWeight.w900,
                                        color:      Colors.black,
                                        letterSpacing: 0.5,
                                      ),
                                    ),
                                    Text(
                                      'Disable ad blocker then tap here',
                                      style: TextStyle(
                                        fontSize: 11,
                                        color:    Colors.black54,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                    ),
                  ),

                  const SizedBox(height: 14),

                  // ── Or divider ────────────────────────────────────────
                  Row(
                    children: [
                      Expanded(child: Divider(color: Colors.white12)),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        child: Text(
                          'OR',
                          style: TextStyle(
                            fontSize:   11,
                            fontWeight: FontWeight.w700,
                            color:      Colors.white38,
                            letterSpacing: 2,
                          ),
                        ),
                      ),
                      Expanded(child: Divider(color: Colors.white12)),
                    ],
                  ),

                  const SizedBox(height: 14),

                  // ── Remove Ads IAP ────────────────────────────────────
                  GestureDetector(
                    onTap: () => showRemoveAdsSheet(context),
                    child: Container(
                      width:  double.infinity,
                      height: 58,
                      decoration: BoxDecoration(
                        color:        AppColors.surfaceCard,
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(
                          color: AppColors.primary.withOpacity(0.45),
                          width: 1.5,
                        ),
                      ),
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text('👑', style: TextStyle(fontSize: 22)),
                          SizedBox(width: 10),
                          Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Go Ad-Free',
                                style: TextStyle(
                                  fontSize:   15,
                                  fontWeight: FontWeight.w900,
                                  color:      AppColors.primary,
                                  letterSpacing: 0.5,
                                ),
                              ),
                              Text(
                                'From \$0.99/day — no ads ever',
                                style: TextStyle(
                                  fontSize: 11,
                                  color:    AppColors.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  )
                      .animate()
                      .shimmer(
                        delay:    1500.ms,
                        duration: 2000.ms,
                        color:    AppColors.primary.withOpacity(0.2),
                      ),
                ],
              ),
            ),
          ),
        ),
      ),
    ).animate().fadeIn(duration: 300.ms);
  }
}
