import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../data/app_config.dart';
import '../../data/garage_profile.dart';
import '../../providers/garage_provider.dart';
import '../../theme/app_dimens.dart';
import '../../theme/app_palette.dart';
import '../../theme/app_text.dart';
import '../../utils/app_snack_bar.dart';
import '../../utils/error_message.dart';
import '../../l10n/app_language.dart';
import '../../utils/form_errors.dart';

/// Edits the garage profile printed on every invoice / estimate (name,
/// GSTIN, address, UPI) and the business defaults in [AppConfig].
class GarageSettingsScreen extends StatefulWidget {
  const GarageSettingsScreen({super.key});

  @override
  State<GarageSettingsScreen> createState() => _GarageSettingsScreenState();
}

class _GarageSettingsScreenState extends State<GarageSettingsScreen> {
  final _formKey = GlobalKey<FormState>();
  late final Map<String, TextEditingController> _c;
  late double _defaultTax;
  late List<double> _taxOptions;
  bool _isSaving = false;

  static final _gstinPattern =
      RegExp(r'^[0-9]{2}[A-Z]{5}[0-9]{4}[A-Z][1-9A-Z]Z[0-9A-Z]$');

  @override
  void initState() {
    super.initState();
    final provider = context.read<GarageProvider>();
    final p = provider.profile;
    final c = provider.config;
    _c = {
      'name': TextEditingController(text: p.name),
      'tagline': TextEditingController(text: p.tagline),
      'address': TextEditingController(text: p.addressLine),
      'city': TextEditingController(text: p.city),
      'phone': TextEditingController(text: p.phone),
      'email': TextEditingController(text: p.email),
      'gstin': TextEditingController(text: p.gstin),
      'upi': TextEditingController(text: p.upiId),
      'dueDays': TextEditingController(text: '${c.invoiceDueDays}'),
      'workingDays': TextEditingController(text: '${c.workingDaysPerMonth}'),
      'deliveryHours': TextEditingController(text: '${c.promisedDeliveryHours}'),
      'receivedBy': TextEditingController(text: c.defaultReceivedBy),
      'notes': TextEditingController(text: c.invoiceNotes),
      'terms': TextEditingController(text: c.invoiceTerms),
    };
    _defaultTax = c.defaultTaxPercent;
    _taxOptions = List.of(c.taxPercentOptions);
  }

  @override
  void dispose() {
    for (final controller in _c.values) {
      controller.dispose();
    }
    super.dispose();
  }

  String _t(String key) => _c[key]!.text.trim();

  String? _intInRange(String? v, int min, int max) {
    final n = int.tryParse(v?.trim() ?? '');
    if (n == null || n < min || n > max) return 'Enter $min–$max';
    return null;
  }

  Future<void> _save() async {
    if (_isSaving) return;
    if (!_formKey.currentState!.validate()) {
      scrollToFirstFormError(_formKey);
      return;
    }
    final provider = context.read<GarageProvider>();
    final old = provider.config;
    final profile = GarageProfile(
      name: _t('name'),
      tagline: _t('tagline'),
      addressLine: _t('address'),
      city: _t('city'),
      phone: _t('phone'),
      email: _t('email'),
      gstin: _t('gstin').toUpperCase(),
      upiId: _t('upi'),
    );
    final config = AppConfig(
      defaultTaxPercent: _defaultTax,
      taxPercentOptions: _taxOptions,
      invoiceDueDays: int.parse(_t('dueDays')),
      quotationValidityOptions: old.quotationValidityOptions,
      workingDaysPerMonth: int.parse(_t('workingDays')),
      promisedDeliveryHours: int.parse(_t('deliveryHours')),
      invoiceNotes: _t('notes'),
      invoiceTerms: _t('terms'),
      defaultReceivedBy:
          _t('receivedBy').isEmpty ? old.defaultReceivedBy : _t('receivedBy'),
    );
    setState(() => _isSaving = true);
    try {
      await provider.updateSettings(profile, config);
      if (!mounted) return;
      showAppSnackBar(context, tr('Garage settings saved'),
          type: SnackBarType.success);
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      showAppSnackBar(
        context,
        errorMessage(e),
        type: SnackBarType.error,
      );
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Widget _field(
    String key,
    String label, {
    IconData? icon,
    TextInputType? keyboard,
    int maxLines = 1,
    String? Function(String?)? validator,
    TextCapitalization caps = TextCapitalization.none,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: TextFormField(
        controller: _c[key],
        keyboardType: keyboard,
        maxLines: maxLines,
        textCapitalization: caps,
        validator: validator,
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: icon == null ? null : Icon(icon),
        ),
      ),
    );
  }

  Widget _section(String title) => Padding(
        padding: const EdgeInsets.only(top: 8, bottom: 12),
        child: Text(
          title,
          style: GoogleFonts.poppins(
            fontSize: AppText.title,
            fontWeight: FontWeight.w700,
            color: context.palette.textPrimary,
          ),
        ),
      );

  Future<void> _addTaxOption() async {
    final controller = TextEditingController();
    // Inline validation: out-of-range or duplicate rates show an error under
    // the field instead of silently doing nothing on Add.
    final value = await showDialog<double>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          String? error;
          void validate() {
            final v = double.tryParse(controller.text.trim());
            if (v == null || v < 0 || v > 100) {
              setDialogState(() => error = tr('Enter a rate between 0 and 100'));
              return;
            }
            if (_taxOptions.contains(v)) {
              setDialogState(() => error = tr('This rate is already in the list'));
              return;
            }
            Navigator.pop(ctx, v);
          }

          return AlertDialog(
            title: Text(tr('Add GST rate')),
            content: TextField(
              controller: controller,
              autofocus: true,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(suffixText: '%', errorText: error),
              onSubmitted: (_) => validate(),
            ),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(ctx), child: Text(tr('Cancel'))),
              FilledButton(
                onPressed: validate,
                child: Text(tr('Add')),
              ),
            ],
          );
        },
      ),
    );
    controller.dispose();
    if (value != null) {
      setState(() => _taxOptions = [..._taxOptions, value]..sort());
    }
  }

  String _pct(double v) =>
      v == v.roundToDouble() ? '${v.toStringAsFixed(0)}%' : '$v%';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(tr('Garage Settings'),
            style: GoogleFonts.poppins(fontWeight: FontWeight.w700)),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(AppDimens.paddingScreen),
          children: [
            _section(tr('Bill header')),
            _field('name', tr('Garage name *'),
                icon: Icons.store_rounded,
                caps: TextCapitalization.words,
                validator: (v) => (v ?? '').trim().isEmpty
                    ? tr('Garage name is required')
                    : null),
            _field('tagline', tr('Tagline'), icon: Icons.short_text_rounded),
            _field('address', tr('Address'), icon: Icons.location_on_outlined),
            _field('city', tr('City / State'), icon: Icons.location_city_rounded),
            _field('phone', tr('Phone'),
                icon: Icons.phone_rounded, keyboard: TextInputType.phone),
            _field('email', tr('Email'),
                icon: Icons.email_outlined,
                keyboard: TextInputType.emailAddress),
            _field('gstin', 'GSTIN',
                icon: Icons.receipt_long_rounded,
                caps: TextCapitalization.characters, validator: (v) {
              final s = (v ?? '').trim().toUpperCase();
              if (s.isEmpty || _gstinPattern.hasMatch(s)) return null;
              return tr('Enter a valid 15-character GSTIN');
            }),
            _field('upi', tr('UPI ID (for payment QR)'),
                icon: Icons.qr_code_rounded, validator: (v) {
              final s = (v ?? '').trim();
              if (s.isEmpty || s.contains('@')) return null;
              return tr('UPI ID looks like name@bank');
            }),
            _section(tr('GST rates')),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final rate in _taxOptions)
                  ChoiceChip(
                    label: Text(_pct(rate)),
                    selected: rate == _defaultTax,
                    onSelected: (_) => setState(() => _defaultTax = rate),
                  ),
                ActionChip(
                  avatar: const Icon(Icons.add, size: 16),
                  label: Text(tr('Rate')),
                  onPressed: _addTaxOption,
                ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.only(top: 6, bottom: 14),
              child: Text(tr('Selected rate is the default on new bills.'),
                  style: GoogleFonts.poppins(
                      fontSize: AppText.label,
                      color: context.palette.textMuted)),
            ),
            _section(tr('Defaults')),
            _field('dueDays', tr('Bill due in (days)'),
                keyboard: TextInputType.number,
                validator: (v) => _intInRange(v, 0, 1000)),
            _field('deliveryHours', tr('Promised delivery (hours)'),
                keyboard: TextInputType.number,
                validator: (v) => _intInRange(v, 0, 1000)),
            _field('workingDays', tr('Working days per month (payroll)'),
                keyboard: TextInputType.number,
                validator: (v) => _intInRange(v, 1, 31)),
            _field('receivedBy', tr('Payments received by')),
            _field('notes', tr('Bill notes'), maxLines: 2),
            _field('terms', tr('Terms & conditions'), maxLines: 3),
            const SizedBox(height: 12),
            ElevatedButton.icon(
              onPressed: _isSaving ? null : _save,
              icon: const Icon(Icons.check_rounded),
              label: Text(tr('Save Settings')),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }
}
