import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../data/api/api_config.dart';
import '../providers/auth_provider.dart';
import '../screens/billing/billing_screen.dart';
import '../theme/app_text.dart';

/// SaaS subscription banner for the dashboard. Hidden in mock mode, when the
/// subscription is active, or when billing can't be reached. Trialing shows
/// an amber countdown; expired / past-due / suspended / cancelled show red.
/// Tapping opens the Billing screen.
class SubscriptionBanner extends StatefulWidget {
  const SubscriptionBanner({super.key});

  @override
  State<SubscriptionBanner> createState() => _SubscriptionBannerState();
}

class _SubscriptionBannerState extends State<SubscriptionBanner> {
  Map<String, dynamic>? _billing;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (ApiConfig.useMock) return;
    try {
      final b = await context.read<AuthProvider>().fetchBilling();
      if (mounted) setState(() => _billing = b);
    } catch (_) {
      // Silent: banner is advisory, errors surface on the Billing screen.
    }
  }

  @override
  Widget build(BuildContext context) {
    final b = _billing;
    if (b == null) return const SizedBox.shrink();
    final status = (b['status'] as String?) ?? 'unknown';
    if (status == 'active') return const SizedBox.shrink();

    final bool urgent = status != 'trialing';
    int? daysLeft;
    if (status == 'trialing') {
      final end =
          DateTime.tryParse((b['trial_ends_at'] as String?) ?? '')?.toLocal();
      if (end != null) daysLeft = end.difference(DateTime.now()).inDays;
    }
    final text = urgent
        ? 'Subscription $status — renew to keep adding records.'
        : daysLeft == null
            ? 'Trial period — subscribe to keep full access.'
            : daysLeft < 0
                ? 'Trial expired — subscribe to keep adding records.'
                : 'Trial: $daysLeft day${daysLeft == 1 ? '' : 's'} left.';
    final bg = urgent ? Colors.red.shade700 : Colors.orange.shade800;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: bg,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const BillingScreen()),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            child: Row(
              children: [
                const Icon(Icons.card_membership_rounded,
                    color: Colors.white, size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    text,
                    style: GoogleFonts.poppins(
                      color: Colors.white,
                      fontSize: AppText.label,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const Icon(Icons.chevron_right_rounded,
                    color: Colors.white, size: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
