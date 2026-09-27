import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../data/api/api_exception.dart';
import '../../providers/auth_provider.dart';
import '../../theme/app_text.dart';
import '../../utils/app_snack_bar.dart';

/// SaaS subscription screen: trial countdown, plan status, Razorpay checkout
/// entry, and cancel. The server creates the Razorpay subscription and hands
/// back its hosted payment page; the app opens it in the browser and
/// re-reads status when the user comes back (activation arrives by webhook).
class BillingScreen extends StatefulWidget {
  const BillingScreen({super.key});

  @override
  State<BillingScreen> createState() => _BillingScreenState();
}

class _BillingScreenState extends State<BillingScreen>
    with WidgetsBindingObserver {
  Map<String, dynamic>? _billing;
  bool _loading = true;
  String? _error;
  bool _awaitingPayment = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _load();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Back from the payment page: the webhook may already have activated
    // the subscription.
    if (state == AppLifecycleState.resumed && _awaitingPayment) {
      _awaitingPayment = false;
      _load();
    }
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final b = await context.read<AuthProvider>().fetchBilling();
      if (!mounted) return;
      setState(() {
        _billing = b;
        _loading = false;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.userMessage;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'Could not load billing status.';
        _loading = false;
      });
    }
  }

  Future<void> _checkout(String plan) async {
    try {
      final res =
          await context.read<AuthProvider>().startCheckout(plan: plan);
      if (!mounted) return;
      if (res['configured'] == false) {
        showAppSnackBar(
            context, (res['message'] as String?) ?? 'Payment not configured.');
        return;
      }
      final url = Uri.tryParse((res['short_url'] as String?) ?? '');
      if (url == null || !url.hasScheme) {
        showAppSnackBar(context, 'Checkout link missing. Please try again.',
            type: SnackBarType.error);
        return;
      }
      _awaitingPayment = true;
      final opened =
          await launchUrl(url, mode: LaunchMode.externalApplication);
      if (!mounted) return;
      if (!opened) {
        _awaitingPayment = false;
        showAppSnackBar(context, 'Could not open the payment page.',
            type: SnackBarType.error);
        return;
      }
      showAppSnackBar(context,
          'Complete payment in the browser. Your plan activates automatically.');
    } on ApiException catch (e) {
      if (!mounted) return;
      showAppSnackBar(context, e.userMessage, type: SnackBarType.error);
    } catch (_) {
      if (!mounted) return;
      showAppSnackBar(context, 'Checkout failed. Please try again.',
          type: SnackBarType.error);
    }
  }

  Future<void> _cancel() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Cancel subscription?'),
        content: const Text(
            'Writes will be blocked when the subscription lapses. You can resubscribe anytime.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Keep')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Cancel')),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    try {
      await context.read<AuthProvider>().cancelBilling();
      if (!mounted) return;
      showAppSnackBar(context, 'Subscription cancelled.');
      await _load();
    } on ApiException catch (e) {
      if (!mounted) return;
      showAppSnackBar(context, e.userMessage, type: SnackBarType.error);
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final isOwner = auth.isOwner;
    return Scaffold(
      appBar: AppBar(title: const Text('Subscription')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(_error!),
                      const SizedBox(height: 12),
                      FilledButton(
                          onPressed: _load, child: const Text('Retry')),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      _statusCard(),
                      const SizedBox(height: 16),
                      if (isOwner) ...[
                        Text('Plans',
                            style: GoogleFonts.poppins(
                                fontSize: AppText.subtitle,
                                fontWeight: FontWeight.w700)),
                        const SizedBox(height: 8),
                        _planTile('Pro Monthly', 'Billed every month',
                            'monthly', Icons.calendar_month_rounded),
                        const SizedBox(height: 8),
                        _planTile('Pro Yearly', 'Two months free vs monthly',
                            'yearly', Icons.calendar_today_rounded),
                        const SizedBox(height: 16),
                        OutlinedButton(
                          onPressed: _cancel,
                          child: const Text('Cancel subscription'),
                        ),
                      ] else
                        Text(
                          'Only the workshop owner can change the subscription.',
                          style: GoogleFonts.poppins(
                              color: Theme.of(context).hintColor),
                        ),
                    ],
                  ),
                ),
    );
  }

  Widget _statusCard() {
    final b = _billing ?? {};
    final status = (b['status'] as String?) ?? 'unknown';
    final plan = (b['plan_tier'] as String?) ?? 'trial';
    final trialEnds = b['trial_ends_at'] as String?;
    String subtitle = 'Plan: $plan';
    if (trialEnds != null && status == 'trialing') {
      final end = DateTime.tryParse(trialEnds)?.toLocal();
      if (end != null) {
        final left = end.difference(DateTime.now()).inDays;
        subtitle = 'Trial ends ${end.day}/${end.month}/${end.year}'
            '${left < 0 ? ' (expired)' : ' ($left days left)'}';
      }
    }
    Color dot = Colors.green;
    if (status == 'trialing') dot = Colors.orange;
    if (status == 'past_due' ||
        status == 'cancelled' ||
        status == 'suspended') {
      dot = Colors.red;
    }
    return Card(
      child: ListTile(
        leading: Icon(Icons.circle, color: dot, size: 14),
        title: Text('Status: $status',
            style: GoogleFonts.poppins(fontWeight: FontWeight.w700)),
        subtitle: Text(subtitle),
      ),
    );
  }

  Widget _planTile(String title, String subtitle, String plan, IconData icon) {
    return Card(
      child: ListTile(
        leading: Icon(icon),
        title: Text(title,
            style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
        subtitle: Text(subtitle),
        trailing: FilledButton(
          onPressed: () => _checkout(plan),
          child: const Text('Subscribe'),
        ),
      ),
    );
  }
}
