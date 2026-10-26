import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../data/api/api_exception.dart';
import '../../providers/auth_provider.dart';
import '../../services/apple_iap_service.dart';
import '../../theme/app_text.dart';
import '../../utils/app_snack_bar.dart';
import '../../utils/currency_formatter.dart';
import '../../utils/date_formatter.dart';
import '../../utils/error_message.dart';

/// Display label for a backend subscription status ("past_due" → "Past due").
String subscriptionStatusLabel(String status) => switch (status) {
      'trialing' => 'Trial',
      'active' => 'Active',
      'past_due' => 'Past due',
      'cancelled' => 'Cancelled',
      'suspended' => 'Suspended',
      _ => status.isEmpty
          ? 'Unknown'
          : status[0].toUpperCase() + status.substring(1).replaceAll('_', ' '),
    };

/// SaaS subscription screen: trial countdown, plan status, checkout, and
/// cancel. On iOS plans are bought through Apple in-app purchase (App Store
/// rule 3.1.1) and verified by the server. Elsewhere the server creates a
/// Razorpay subscription and hands back its hosted payment page; the app
/// opens it in the browser and re-reads status when the user comes back
/// (activation arrives by webhook).
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

  // iOS in-app purchase state.
  final _iap = AppleIapService.instance;
  List<ProductDetails> _products = const [];
  String? _productsError;
  bool _purchasing = false;

  static const _termsUrl = 'https://garage.nexorytechnologies.com/terms';
  static const _privacyUrl = 'https://garage.nexorytechnologies.com/privacy';
  static const _manageUrl = 'https://apps.apple.com/account/subscriptions';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    if (AppleIapService.isSupported) {
      _iap.onVerify = context.read<AuthProvider>().verifyApplePurchase;
      _iap.events.addListener(_onIapEvent);
      _iap.start();
    }
    _load();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _iap.events.removeListener(_onIapEvent);
    super.dispose();
  }

  bool get _isApple => (_billing?['provider'] as String?) == 'apple';

  Future<void> _loadProducts() async {
    final b = _billing ?? {};
    final ids = {
      (b['apple_product_monthly'] as String?) ??
          'com.nexory.garage.pro.monthly',
      (b['apple_product_yearly'] as String?) ?? 'com.nexory.garage.pro.yearly',
    };
    try {
      final products = await _iap.loadProducts(ids);
      products.sort((a, b) => a.rawPrice.compareTo(b.rawPrice));
      if (!mounted) return;
      setState(() {
        _products = products;
        _productsError =
            products.isEmpty ? 'Plans are not available right now.' : null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _productsError = 'Could not load plans from the App Store.');
    }
  }

  Future<void> _buyApple(ProductDetails product) async {
    final gid = context.read<AuthProvider>().garageId;
    if (gid == null) return;
    setState(() => _purchasing = true);
    try {
      await _iap.buy(product, garageId: gid);
    } catch (_) {
      if (!mounted) return;
      setState(() => _purchasing = false);
      showAppSnackBar(context, 'Could not start the purchase.',
          type: SnackBarType.error);
    }
  }

  Future<void> _restoreApple() async {
    setState(() => _purchasing = true);
    try {
      await _iap.restore();
    } catch (_) {
      if (!mounted) return;
      showAppSnackBar(context, 'Could not restore purchases.',
          type: SnackBarType.error);
    } finally {
      // Restore with nothing to restore sends no event.
      Future.delayed(const Duration(seconds: 4), () {
        if (mounted) setState(() => _purchasing = false);
      });
    }
  }

  void _onIapEvent() {
    final e = _iap.events.value;
    if (e == null || !mounted) return;
    if (e.kind != IapEventKind.pending) setState(() => _purchasing = false);
    switch (e.kind) {
      case IapEventKind.pending:
        break;
      case IapEventKind.purchased:
        showAppSnackBar(context, 'Subscription active. Thank you!');
        _load();
      case IapEventKind.restored:
        showAppSnackBar(context, 'Purchases restored.');
        _load();
      case IapEventKind.cancelled:
        break;
      case IapEventKind.error:
        showAppSnackBar(context, e.message ?? 'Purchase failed.',
            type: SnackBarType.error);
    }
  }

  Future<void> _open(String url) =>
      launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);

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
      if (AppleIapService.isSupported && _products.isEmpty) _loadProducts();
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
      showAppSnackBar(context, errorMessage(e), type: SnackBarType.error);
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
      showAppSnackBar(context, errorMessage(e), type: SnackBarType.error);
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
                      if (isOwner && AppleIapService.isSupported)
                        ..._applePlans()
                      else if (isOwner && _isApple)
                        Text(
                          'This subscription is billed through the App Store. Manage it on the iPhone or iPad that bought it.',
                          style: GoogleFonts.poppins(
                              color: Theme.of(context).hintColor),
                        )
                      else if (isOwner) ...[
                        Text('Plans',
                            style: GoogleFonts.poppins(
                                fontSize: AppText.subtitle,
                                fontWeight: FontWeight.w700)),
                        const SizedBox(height: 8),
                        _planTile('Pro Monthly', 'Billed every month',
                            'monthly', Icons.calendar_month_rounded,
                            price: _price('price_monthly'), per: 'month'),
                        const SizedBox(height: 8),
                        _planTile('Pro Yearly', 'Two months free vs monthly',
                            'yearly', Icons.calendar_today_rounded,
                            price: _price('price_yearly'), per: 'year'),
                        // Only a live paid plan can be cancelled; during the
                        // trial there is nothing to cancel.
                        if (_canCancel) ...[
                          const SizedBox(height: 16),
                          OutlinedButton(
                            onPressed: _cancel,
                            child: const Text('Cancel subscription'),
                          ),
                        ],
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

  List<Widget> _applePlans() {
    final hint = GoogleFonts.poppins(
        fontSize: AppText.caption, color: Theme.of(context).hintColor);
    final active = (_billing?['status'] as String?) == 'active';
    return [
      Text('Plans',
          style: GoogleFonts.poppins(
              fontSize: AppText.subtitle, fontWeight: FontWeight.w700)),
      const SizedBox(height: 8),
      if (_products.isEmpty && _productsError == null)
        const Padding(
          padding: EdgeInsets.all(24),
          child: Center(child: CircularProgressIndicator()),
        )
      else if (_productsError != null)
        Card(
          child: ListTile(
            title: Text(_productsError!),
            trailing: TextButton(
                onPressed: () {
                  setState(() => _productsError = null);
                  _loadProducts();
                },
                child: const Text('Retry')),
          ),
        )
      else
        for (final p in _products) ...[
          Card(
            child: ListTile(
              leading: Icon(p.id.endsWith('yearly')
                  ? Icons.calendar_today_rounded
                  : Icons.calendar_month_rounded),
              title: Text(p.title.isEmpty ? p.id : p.title,
                  style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
              subtitle: Text(
                  '${p.price} / ${p.id.endsWith('yearly') ? 'year' : 'month'}'),
              trailing: FilledButton(
                onPressed: _purchasing ? null : () => _buyApple(p),
                child: const Text('Subscribe'),
              ),
            ),
          ),
          const SizedBox(height: 8),
        ],
      const SizedBox(height: 8),
      Row(
        children: [
          Expanded(
            child: OutlinedButton(
              onPressed: _purchasing ? null : _restoreApple,
              child: const Text('Restore purchases'),
            ),
          ),
          if (_isApple && active) ...[
            const SizedBox(width: 12),
            Expanded(
              child: OutlinedButton(
                onPressed: () => _open(_manageUrl),
                child: const Text('Manage'),
              ),
            ),
          ],
        ],
      ),
      if (_purchasing)
        const Padding(
          padding: EdgeInsets.only(top: 12),
          child: LinearProgressIndicator(),
        ),
      const SizedBox(height: 16),
      Text(
        'Payment is charged to your Apple ID at confirmation. The subscription '
        'renews automatically unless cancelled at least 24 hours before the '
        'end of the current period. Manage or cancel it anytime in your '
        'Apple ID settings.',
        style: hint,
      ),
      const SizedBox(height: 4),
      Wrap(
        children: [
          TextButton(
              onPressed: () => _open(_termsUrl),
              child: const Text('Terms of Use')),
          TextButton(
              onPressed: () => _open(_privacyUrl),
              child: const Text('Privacy Policy')),
        ],
      ),
    ];
  }

  bool get _canCancel {
    if (_isApple) return false;
    final status = (_billing?['status'] as String?) ?? '';
    return status == 'active' || status == 'past_due';
  }

  /// Plan price in rupees from the billing response, or null when the
  /// server has none configured.
  num? _price(String key) {
    final value = _billing?[key];
    return value is num && value > 0 ? value : null;
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
        final left = AppDateFormatter.daysUntil(end);
        subtitle = 'Trial ends ${AppDateFormatter.formatDate(end)}'
            '${left < 0 ? ' (expired)' : left == 0 ? ' (today)' : ' ($left day${left == 1 ? '' : 's'} left)'}';
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
        title: Text('Status: ${subscriptionStatusLabel(status)}',
            style: GoogleFonts.poppins(fontWeight: FontWeight.w700)),
        subtitle: Text(subtitle),
      ),
    );
  }

  Widget _planTile(String title, String subtitle, String plan, IconData icon,
      {num? price, required String per}) {
    return Card(
      child: ListTile(
        leading: Icon(icon),
        title: Text(title,
            style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
        subtitle: Text(price == null
            ? subtitle
            : '${CurrencyFormatter.format(price.toDouble())} / $per · $subtitle'),
        trailing: FilledButton(
          onPressed: () => _checkout(plan),
          child: const Text('Subscribe'),
        ),
      ),
    );
  }
}
