import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';
import '../constants/app_constants.dart';
import '../services/network_service.dart';
import '../services/purchase_service.dart';

// ── Show helper ───────────────────────────────────────────────────────────────
void showRemoveAdsSheet(BuildContext context) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => ChangeNotifierProvider.value(
      value: PurchaseService.instance,
      child: const RemoveAdsSheet(),
    ),
  );
}

// ── Sheet ─────────────────────────────────────────────────────────────────────
class RemoveAdsSheet extends StatelessWidget {
  const RemoveAdsSheet({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer2<PurchaseService, NetworkService>(
      builder: (context, purchase, net, _) {
        return Container(
          decoration: const BoxDecoration(
            color: Color(0xFF12122A),
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
            border: Border(
              top: BorderSide(color: Color(0xFF2A2A50), width: 1),
            ),
          ),
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom + 24,
          ),
          child: SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // ── Drag handle ───────────────────────────────────────
                  Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.white24,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // ── Header ────────────────────────────────────────────
                  _buildHeader(purchase),
                  const SizedBox(height: 24),

                  // ── Offline warning ───────────────────────────────────
                  if (net.isOffline) ...[
                    _buildOfflineBanner(net),
                    const SizedBox(height: 20),
                  ],

                  // ── Error ─────────────────────────────────────────────
                  if (purchase.error != null) ...[
                    _buildErrorBanner(context, purchase),
                    const SizedBox(height: 16),
                  ],

                  // ── Already active status ──────────────────────────────
                  if (purchase.adsRemoved) ...[
                    _buildActiveStatus(purchase),
                    const SizedBox(height: 20),
                  ],

                  // ── Tier cards ────────────────────────────────────────
                  _TierCard(
                    productId:   IAPIds.noAdsDay,
                    label:       '1 Day',
                    price:       '\$0.99',
                    description: 'Perfect for a quick session',
                    icon:        '☀️',
                    isBest:      false,
                    isLoading:   purchase.loading,
                    isDisabled:  net.isOffline,
                  ),
                  const SizedBox(height: 10),
                  _TierCard(
                    productId:   IAPIds.noAdsWeek,
                    label:       '1 Week',
                    price:       '\$2.99',
                    description: 'Most popular — great value',
                    icon:        '🌟',
                    isBest:      true,
                    isLoading:   purchase.loading,
                    isDisabled:  net.isOffline,
                  ),
                  const SizedBox(height: 10),
                  _TierCard(
                    productId:   IAPIds.noAdsMonth,
                    label:       '1 Month',
                    price:       '\$8.99',
                    description: 'Best deal for dedicated players',
                    icon:        '👑',
                    isBest:      false,
                    isLoading:   purchase.loading,
                    isDisabled:  net.isOffline,
                  ),
                  const SizedBox(height: 20),

                  // ── Fine print ────────────────────────────────────────
                  const Text(
                    'Purchases are consumable and time-limited.\nTime stacks if you buy while already active.\nManaged via Google Play / App Store.',
                    style: TextStyle(
                      fontSize: 11,
                      color: Color(0xFF546E7A),
                      height: 1.5,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildHeader(PurchaseService purchase) {
    return Column(
      children: [
        ShaderMask(
          shaderCallback: (b) => AppColors.goldGradient.createShader(b),
          child: const Text(
            '🚫📺  Remove Ads',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w900,
              color: Colors.white,
              letterSpacing: 0.5,
            ),
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          'Play without interruptions.\nRewarded ads (continues & slow-mo) still available.',
          style: TextStyle(
            fontSize: 13,
            color: Color(0xFF78909C),
            height: 1.5,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildOfflineBanner(NetworkService net) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFE65100).withOpacity(0.15),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
            color: const Color(0xFFFF9800).withOpacity(0.4), width: 1),
      ),
      child: Row(
        children: [
          const Text('📶', style: TextStyle(fontSize: 20)),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'No internet connection',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFFFF9800),
                  ),
                ),
                Text(
                  net.shortMessage,
                  style: const TextStyle(
                    fontSize: 11,
                    color: Color(0xFF78909C),
                  ),
                ),
              ],
            ),
          ),
          GestureDetector(
            onTap: () => net.refresh(),
            child: const Text(
              'Retry',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: Color(0xFFFF9800),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorBanner(BuildContext context, PurchaseService purchase) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFB71C1C).withOpacity(0.15),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
            color: const Color(0xFFEF5350).withOpacity(0.4), width: 1),
      ),
      child: Row(
        children: [
          const Text('⚠️', style: TextStyle(fontSize: 18)),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              purchase.error!,
              style: const TextStyle(
                fontSize: 12,
                color: Color(0xFFEF9A9A),
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          GestureDetector(
            onTap: () => purchase.clearError(),
            child: const Icon(Icons.close, color: Color(0xFF78909C), size: 18),
          ),
        ],
      ),
    );
  }

  Widget _buildActiveStatus(PurchaseService purchase) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.success.withOpacity(0.12),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
            color: AppColors.success.withOpacity(0.35), width: 1.2),
      ),
      child: Row(
        children: [
          const Text('✅', style: TextStyle(fontSize: 22)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Remove Ads Active',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: AppColors.success,
                  ),
                ),
                Text(
                  purchase.statusLabel,
                  style: const TextStyle(
                    fontSize: 11,
                    color: Color(0xFF78909C),
                  ),
                ),
              ],
            ),
          ),
          const Text('🎉', style: TextStyle(fontSize: 20)),
        ],
      ),
    );
  }
}

// ── Tier Card ─────────────────────────────────────────────────────────────────
class _TierCard extends StatelessWidget {
  final String productId;
  final String label;
  final String price;
  final String description;
  final String icon;
  final bool   isBest;
  final bool   isLoading;
  final bool   isDisabled;

  const _TierCard({
    required this.productId,
    required this.label,
    required this.price,
    required this.description,
    required this.icon,
    required this.isBest,
    required this.isLoading,
    required this.isDisabled,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: isLoading || isDisabled
          ? null
          : () => context.read<PurchaseService>().buy(productId),
      child: AnimatedOpacity(
        opacity: isDisabled ? 0.45 : 1.0,
        duration: const Duration(milliseconds: 200),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
              decoration: BoxDecoration(
                color: isBest
                    ? AppColors.primary.withOpacity(0.08)
                    : const Color(0xFF1A1A35),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isBest
                      ? AppColors.primary.withOpacity(0.5)
                      : Colors.white.withOpacity(0.08),
                  width: isBest ? 1.5 : 1,
                ),
              ),
              child: Row(
                children: [
                  // Icon
                  Text(icon, style: const TextStyle(fontSize: 28)),
                  const SizedBox(width: 14),

                  // Label + description
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          label,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                          ),
                        ),
                        Text(
                          description,
                          style: const TextStyle(
                            fontSize: 11,
                            color: Color(0xFF78909C),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Price / loading
                  isLoading
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            color: AppColors.primary,
                          ),
                        )
                      : Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 7),
                          decoration: BoxDecoration(
                            gradient: isBest
                                ? AppColors.goldGradient
                                : const LinearGradient(colors: [
                                    Color(0xFF2A2A50),
                                    Color(0xFF1A1A35),
                                  ]),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            price,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w900,
                              color: isBest ? Colors.black : Colors.white,
                            ),
                          ),
                        ),
                ],
              ),
            ),

            // "Best Value" badge
            if (isBest)
              Positioned(
                top: -10,
                right: 16,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    gradient: AppColors.goldGradient,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text(
                    'BEST VALUE',
                    style: TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.w900,
                      color: Colors.black,
                      letterSpacing: 1,
                    ),
                  ),
                ).animate().shimmer(
                    duration: 2000.ms,
                    color: Colors.white.withOpacity(0.4)),
              ),
          ],
        ),
      ),
    );
  }
}
