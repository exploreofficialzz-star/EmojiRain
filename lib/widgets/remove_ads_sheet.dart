import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';
import '../constants/app_constants.dart';
import '../services/network_service.dart';
import '../services/purchase_service.dart';
import '../services/paystack_service.dart';
import 'paystack_checkout.dart';  // FIX: was '../services/paystack_checkout.dart' (wrong path — file lives in widgets/)
import 'unlock_code_dialog.dart';

// ── Show helper ───────────────────────────────────────────────────────────────
void showRemoveAdsSheet(BuildContext context) {
  showModalBottomSheet(
    context:            context,
    isScrollControlled: true,
    backgroundColor:    Colors.transparent,
    builder: (_) => ChangeNotifierProvider.value(
      value: PurchaseService.instance,
      child: const RemoveAdsSheet(),
    ),
  );
}

// ─── Sheet ────────────────────────────────────────────────────────────────────
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
            border: Border(top: BorderSide(color: Color(0xFF2A2A50), width: 1)),
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
                  // Drag handle
                  Container(
                    width: 40, height: 4,
                    decoration: BoxDecoration(
                      color:        Colors.white24,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(height: 22),

                  _buildHeader(),
                  const SizedBox(height: 18),

                  // Active status
                  if (purchase.adsRemoved) ...[
                    _buildActiveStatus(purchase),
                    const SizedBox(height: 16),
                  ],

                  // ── Smart routing ─────────────────────────────────────
                  // Google Play installed  →  IAP flow (existing)
                  // Sideloaded / other store → Paystack popup
                  if (purchase.storeAvailable)
                    _buildPlayStoreFlow(context, purchase, net)
                  else
                    _buildPaystackFlow(context, purchase),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  // ── Header ────────────────────────────────────────────────────────────────
  Widget _buildHeader() {
    return Column(
      children: [
        ShaderMask(
          shaderCallback: (b) => AppColors.goldGradient.createShader(b),
          child: const Text(
            '🚫📺  Remove Ads',
            style: TextStyle(
              fontSize: 24, fontWeight: FontWeight.w900,
              color: Colors.white, letterSpacing: 0.5,
            ),
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          'Play without interruptions.\n'
          'Rewarded ads (continues & power-ups) still available.',
          style: TextStyle(
            fontSize: 13, color: Color(0xFF78909C), height: 1.5,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  // ── FLOW A: Google Play / App Store ──────────────────────────────────────
  Widget _buildPlayStoreFlow(
    BuildContext context,
    PurchaseService purchase,
    NetworkService net,
  ) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (net.isOffline) ...[
          _buildOfflineBanner(net),
          const SizedBox(height: 14),
        ],
        if (purchase.error != null) ...[
          _buildErrorBanner(context, purchase),
          const SizedBox(height: 12),
        ],
        _PlayTierCard(
          productId:   IAPIds.noAdsDay,
          label:       '1 Day',   price: r'$0.99',
          description: 'Perfect for a quick session',
          icon: '☀️',  isBest:   false,
          isLoading:   purchase.loading,
          isDisabled:  net.isOffline,
        ),
        const SizedBox(height: 10),
        _PlayTierCard(
          productId:   IAPIds.noAdsWeek,
          label:       '1 Week',  price: r'$2.99',
          description: 'Most popular — great value',
          icon: '🌟',  isBest:   true,
          isLoading:   purchase.loading,
          isDisabled:  net.isOffline,
        ),
        const SizedBox(height: 10),
        _PlayTierCard(
          productId:   IAPIds.noAdsMonth,
          label:       '1 Month', price: r'$8.99',
          description: 'Best deal for dedicated players',
          icon: '👑',  isBest:   false,
          isLoading:   purchase.loading,
          isDisabled:  net.isOffline,
        ),
        const SizedBox(height: 18),
        const Text(
          'Purchases are consumable and time-limited.\n'
          'Time stacks if you buy while already active.\n'
          'Managed via Google Play / App Store.',
          style: TextStyle(
            fontSize: 11, color: Color(0xFF546E7A), height: 1.5,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 4),
      ],
    );
  }

  // ── FLOW B: Paystack (sideloaded APK / other stores) ─────────────────────
  Widget _buildPaystackFlow(BuildContext context, PurchaseService purchase) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Payment methods badge
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: AppColors.accent.withOpacity(0.07),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.accent.withOpacity(0.25)),
          ),
          child: const Row(
            children: [
              Text('💳', style: TextStyle(fontSize: 20)),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Card · Bank Transfer · USSD · Mobile Money\n'
                  'Secure payment opens right here in the app.',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                    height: 1.5,
                  ),
                ),
              ),
            ],
          ),
        ).animate().fadeIn(duration: 350.ms),

        const SizedBox(height: 14),

        // Paystack tier cards
        ...PaystackService.tiers.entries.map((entry) => Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: _PaystackTierCard(
            productId: entry.key,
            onTap:     () => _handlePaystackTap(context, entry.key),
          ),
        )),

        const SizedBox(height: 8),

        // Powered by Paystack badge
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.lock_rounded,
                size: 12, color: AppColors.textSecondary.withOpacity(0.5)),
            const SizedBox(width: 4),
            Text(
              'Secured by Paystack',
              style: TextStyle(
                fontSize: 10, color: AppColors.textSecondary.withOpacity(0.5),
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),

        const SizedBox(height: 14),

        // Divider
        Row(children: [
          const Expanded(child: Divider(color: Colors.white10)),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Text(
              'Already bought?',
              style: TextStyle(
                fontSize: 10,
                color: AppColors.textSecondary.withOpacity(0.55),
              ),
            ),
          ),
          const Expanded(child: Divider(color: Colors.white10)),
        ]),

        const SizedBox(height: 12),

        // Unlock code button
        GestureDetector(
          onTap: () async {
            Navigator.of(context).pop();
            await showUnlockCodeDialog(context);
          },
          child: Container(
            width: double.infinity, height: 48,
            decoration: BoxDecoration(
              color: AppColors.surfaceCard,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: AppColors.primary.withOpacity(0.35), width: 1.5,
              ),
            ),
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text('🔑', style: TextStyle(fontSize: 17)),
                SizedBox(width: 8),
                Text(
                  'Enter Unlock Code',
                  style: TextStyle(
                    fontSize: 14, fontWeight: FontWeight.w800,
                    color: AppColors.primary,
                  ),
                ),
              ],
            ),
          ),
        ).animate().fadeIn(delay: 300.ms),

        const SizedBox(height: 14),

        Text(
          'Support: ${AppSupport.email}',
          style: const TextStyle(fontSize: 10, color: Color(0xFF546E7A)),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 4),
      ],
    );
  }

  // ── Launch Paystack and handle result ─────────────────────────────────────
  Future<void> _handlePaystackTap(
    BuildContext context,
    String productId,
  ) async {
    Navigator.of(context).pop();

    final result = await PaystackCheckout.pay(
      context,
      productId: productId,
    );

    if (!result.isSuccess || !context.mounted) return;

    await PurchaseService.instance.activatePaystackPurchase(productId);

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Row(children: [
          const Text('🎉', style: TextStyle(fontSize: 18)),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Ads removed! ${PurchaseService.instance.statusLabel}',
              style: const TextStyle(
                color: Colors.white, fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ]),
        backgroundColor: AppColors.surfaceCard,
        behavior:        SnackBarBehavior.floating,
        margin:  const EdgeInsets.fromLTRB(20, 0, 20, 24),
        shape:   RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        duration: const Duration(seconds: 3),
      ));
    }
  }

  // ── Shared helpers ────────────────────────────────────────────────────────
  Widget _buildActiveStatus(PurchaseService purchase) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.success.withOpacity(0.12),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: AppColors.success.withOpacity(0.35), width: 1.2,
        ),
      ),
      child: Row(children: [
        const Text('✅', style: TextStyle(fontSize: 22)),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Remove Ads Active', style: TextStyle(
                fontSize: 13, fontWeight: FontWeight.w800,
                color: AppColors.success,
              )),
              Text(purchase.statusLabel, style: const TextStyle(
                fontSize: 11, color: Color(0xFF78909C),
              )),
            ],
          ),
        ),
        const Text('🎉', style: TextStyle(fontSize: 20)),
      ]),
    );
  }

  Widget _buildOfflineBanner(NetworkService net) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFE65100).withOpacity(0.15),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: const Color(0xFFFF9800).withOpacity(0.4),
        ),
      ),
      child: Row(children: [
        const Text('📶', style: TextStyle(fontSize: 20)),
        const SizedBox(width: 10),
        Expanded(
          child: Text(net.shortMessage, style: const TextStyle(
            fontSize: 12, color: Color(0xFF78909C),
          )),
        ),
        GestureDetector(
          onTap: () => net.refresh(),
          child: const Text('Retry', style: TextStyle(
            fontSize: 12, fontWeight: FontWeight.w700,
            color: Color(0xFFFF9800),
          )),
        ),
      ]),
    );
  }

  Widget _buildErrorBanner(BuildContext context, PurchaseService purchase) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFB71C1C).withOpacity(0.15),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: const Color(0xFFEF5350).withOpacity(0.4),
        ),
      ),
      child: Row(children: [
        const Text('⚠️', style: TextStyle(fontSize: 18)),
        const SizedBox(width: 10),
        Expanded(
          child: Text(purchase.error!, style: const TextStyle(
            fontSize: 12, color: Color(0xFFEF9A9A),
            fontWeight: FontWeight.w500,
          )),
        ),
        GestureDetector(
          onTap: () => purchase.clearError(),
          child: const Icon(Icons.close, color: Color(0xFF78909C), size: 18),
        ),
      ]),
    );
  }
}

// ── Google Play Tier Card ─────────────────────────────────────────────────────
class _PlayTierCard extends StatelessWidget {
  final String productId, label, price, description, icon;
  final bool   isBest, isLoading, isDisabled;

  const _PlayTierCard({
    required this.productId,  required this.label,
    required this.price,      required this.description,
    required this.icon,       required this.isBest,
    required this.isLoading,  required this.isDisabled,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: isLoading || isDisabled
          ? null
          : () => context.read<PurchaseService>().buy(productId),
      child: AnimatedOpacity(
        opacity:  isDisabled ? 0.45 : 1.0,
        duration: const Duration(milliseconds: 200),
        child: Stack(clipBehavior: Clip.none, children: [
          _cardBody(
            icon:    icon,
            label:   label,
            desc:    description,
            isBest:  isBest,
            trailing: isLoading
                ? const SizedBox(
                    width: 22, height: 22,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5, color: AppColors.primary,
                    ),
                  )
                : _priceChip(price, isBest),
          ),
          if (isBest) _bestBadge(),
        ]),
      ),
    );
  }
}

// ── Paystack Tier Card ────────────────────────────────────────────────────────
class _PaystackTierCard extends StatelessWidget {
  final String       productId;
  final VoidCallback onTap;

  const _PaystackTierCard({required this.productId, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final tier = PaystackService.tiers[productId]!;
    return GestureDetector(
      onTap: onTap,
      child: Stack(clipBehavior: Clip.none, children: [
        _cardBody(
          icon:     tier.icon,
          label:    tier.label,
          desc:     tier.description,
          isBest:   tier.isBest,
          trailing: _priceChip(tier.displayPrice, tier.isBest),
        ),
        if (tier.isBest) _bestBadge(),
      ]),
    ).animate().fadeIn(delay: 150.ms);
  }
}

// ── Shared card building helpers ──────────────────────────────────────────────
Widget _cardBody({
  required String  icon,
  required String  label,
  required String  desc,
  required bool    isBest,
  required Widget  trailing,
}) {
  return Container(
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
    child: Row(children: [
      Text(icon, style: const TextStyle(fontSize: 28)),
      const SizedBox(width: 14),
      Expanded(child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(
            fontSize: 15, fontWeight: FontWeight.w800, color: Colors.white,
          )),
          Text(desc, style: const TextStyle(
            fontSize: 11, color: Color(0xFF78909C),
          )),
        ],
      )),
      trailing,
    ]),
  );
}

Widget _priceChip(String price, bool isBest) {
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
    decoration: BoxDecoration(
      gradient: isBest
          ? AppColors.goldGradient
          : const LinearGradient(
              colors: [Color(0xFF2A2A50), Color(0xFF1A1A35)],
            ),
      borderRadius: BorderRadius.circular(10),
    ),
    child: Text(price, style: TextStyle(
      fontSize: 14, fontWeight: FontWeight.w900,
      color: isBest ? Colors.black : Colors.white,
    )),
  );
}

Widget _bestBadge() {
  return Positioned(
    top: -10, right: 16,
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        gradient:     AppColors.goldGradient,
        borderRadius: BorderRadius.circular(8),
      ),
      child: const Text('BEST VALUE', style: TextStyle(
        fontSize: 9, fontWeight: FontWeight.w900,
        color: Colors.black, letterSpacing: 1,
      )),
    ).animate().shimmer(
        duration: 2000.ms, color: Colors.white.withOpacity(0.4)),
  );
}
