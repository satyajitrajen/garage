import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';

import '../../models/maintenance_item.dart';
import '../../providers/garage_provider.dart';
import '../../theme/app_palette.dart';
import '../../theme/app_text.dart';
import '../../utils/app_snack_bar.dart';
import '../../utils/currency_formatter.dart';
import '../../utils/error_message.dart';
import '../../utils/permissions.dart';
import '../../widgets/empty_state_widget.dart';
import '../../widgets/permission_gate.dart';
import '../../widgets/search_bar_widget.dart';
import '../../l10n/app_language.dart';

/// Spare parts & labour price list: the catalog the job card item picker
/// offers. Add, edit or remove items here ahead of time.
class PriceListScreen extends StatefulWidget {
  const PriceListScreen({super.key});

  @override
  State<PriceListScreen> createState() => _PriceListScreenState();
}

class _PriceListScreenState extends State<PriceListScreen> {
  final _searchController = TextEditingController();
  String _query = '';
  ItemCategory? _filter;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _openForm([MaintenanceItem? existing]) async {
    // Catalog writes ride on jobcards.manage (backend POST/PUT/DELETE
    // /api/catalog); the More menu gates the screen itself with the same key.
    if (!ensurePermission(context, Permissions.jobcardsManage)) return;
    final result = await showModalBottomSheet<MaintenanceItem>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => _ItemForm(existing: existing),
    );
    if (result == null || !mounted) return;
    final provider = context.read<GarageProvider>();
    try {
      if (existing == null) {
        await provider.addCatalogItem(result);
      } else {
        await provider.updateCatalogItem(result);
      }
      if (!mounted) return;
      showAppSnackBar(context, existing == null ? tr('Item added') : tr('Item updated'),
          type: SnackBarType.success);
    } catch (e) {
      if (!mounted) return;
      showAppSnackBar(context, errorMessage(e), type: SnackBarType.error);
    }
  }

  Future<void> _delete(MaintenanceItem item) async {
    if (!ensurePermission(context, Permissions.jobcardsManage)) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        final palette = ctx.palette;
        return AlertDialog(
          title: Text(tr('Remove from price list?')),
          content: Text('"${item.name}" will no longer appear when adding items. '
              'Existing job cards and bills are not affected.'),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: Text(tr('Keep'), style: TextStyle(color: palette.textSecondary))),
            FilledButton(
                onPressed: () => Navigator.pop(ctx, true),
                style: FilledButton.styleFrom(
                  backgroundColor: palette.absent,
                  foregroundColor: palette.onPrimary,
                ),
                child: Text(tr('Remove'))),
          ],
        );
      },
    );
    if (ok != true || !mounted) return;
    try {
      await context.read<GarageProvider>().deleteCatalogItem(item.id);
      if (!mounted) return;
      showAppSnackBar(context, '"${item.name}" removed from price list',
          type: SnackBarType.success);
    } catch (e) {
      if (!mounted) return;
      showAppSnackBar(context, errorMessage(e), type: SnackBarType.error);
    }
  }

  /// Truly-empty catalog state; the Add CTA is shown only when permitted.
  Widget _catalogEmptyState({required bool withCta}) {
    return EmptyStateWidget(
      icon: Icons.inventory_2_outlined,
      title: tr('No items yet'),
      description:
          tr('Add spare parts and labour with their prices to pick them quickly on job cards.'),
      buttonText: withCta ? tr('Add item') : null,
      onButtonPressed: withCta ? () => _openForm() : null,
    );
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final catalog = context.watch<GarageProvider>().catalog;
    final q = _query.toLowerCase();
    final items = catalog
        .where((i) => _filter == null || i.category == _filter)
        .where((i) =>
            q.isEmpty ||
            i.name.toLowerCase().contains(q) ||
            (i.partNumber?.toLowerCase().contains(q) ?? false))
        .toList()
      ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));

    return Scaffold(
      backgroundColor: palette.background,
      appBar: AppBar(title: Text(tr('Spare parts & price list'))),
      // Gated: staff without jobcards.manage never see the add affordance.
      floatingActionButton: PermissionGate(
        permission: Permissions.jobcardsManage,
        child: FloatingActionButton.extended(
          onPressed: () => _openForm(),
          icon: const Icon(Icons.add_rounded),
          label: Text(tr('Add item')),
        ),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
            child: CustomSearchBar(
              controller: _searchController,
              onClear: () => setState(() {
                _searchController.clear();
                _query = '';
              }),
              hintText: tr('Search parts, labour…'),
              onChanged: (v) => setState(() => _query = v),
            ),
          ),
          SizedBox(
            height: 48,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              children: [
                for (final cat in <ItemCategory?>[null, ...ItemCategory.values])
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: ChoiceChip(
                      label: Text(cat?.displayName ?? tr('All')),
                      selected: _filter == cat,
                      onSelected: (_) => setState(() => _filter = cat),
                    ),
                  ),
              ],
            ),
          ),
          Expanded(
            child: items.isEmpty
                ? (catalog.isEmpty
                    // Truly empty: offer the add action, permission-gated.
                    ? PermissionGate(
                        permission: Permissions.jobcardsManage,
                        fallback: _catalogEmptyState(withCta: false),
                        child: _catalogEmptyState(withCta: true),
                      )
                    : EmptyStateWidget(
                        icon: Icons.inventory_2_outlined,
                        title: tr('No matches'),
                        description: _query.trim().isNotEmpty
                            ? 'No results found for "${_query.trim()}".'
                            : tr('Try a different search or category.'),
                      ))
                : ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 96),
                    itemCount: items.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 6),
                    itemBuilder: (_, i) {
                      final item = items[i];
                      return Card(
                        margin: EdgeInsets.zero,
                        child: ListTile(
                          onTap: () => _openForm(item),
                          title: Text(item.name,
                              style: GoogleFonts.poppins(
                                  fontWeight: FontWeight.w600)),
                          subtitle: Text(
                            [
                              item.category.displayName,
                              if (item.partNumber?.isNotEmpty ?? false)
                                'Part# ${item.partNumber}',
                            ].join(' · '),
                            style: GoogleFonts.poppins(
                                fontSize: AppText.caption,
                                color: palette.textMuted),
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                '${CurrencyFormatter.format(item.unitPrice)}/${item.unit}',
                                style: GoogleFonts.poppins(
                                    fontWeight: FontWeight.w700,
                                    color: palette.textPrimary),
                              ),
                              IconButton(
                                tooltip: tr('Remove'),
                                icon: Icon(Icons.delete_outline_rounded,
                                    color: palette.textMuted),
                                onPressed: () => _delete(item),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class _ItemForm extends StatefulWidget {
  const _ItemForm({this.existing});
  final MaintenanceItem? existing;

  @override
  State<_ItemForm> createState() => _ItemFormState();
}

class _ItemFormState extends State<_ItemForm> {
  final _formKey = GlobalKey<FormState>();
  late final _name = TextEditingController(text: widget.existing?.name);
  late final _price = TextEditingController(
      text: widget.existing == null ? '' : _fmt(widget.existing!.unitPrice));
  late final _unit =
      TextEditingController(text: widget.existing?.unit ?? 'Pcs');
  late final _partNo =
      TextEditingController(text: widget.existing?.partNumber);
  late ItemCategory _category =
      widget.existing?.category ?? ItemCategory.sparePart;
  late double _tax = widget.existing?.taxPercent ??
      context.read<GarageProvider>().config.defaultTaxPercent;

  static String _fmt(double v) =>
      v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toString();

  @override
  void dispose() {
    _name.dispose();
    _price.dispose();
    _unit.dispose();
    _partNo.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    final partNo = _partNo.text.trim();
    Navigator.pop(
      context,
      MaintenanceItem(
        id: widget.existing?.id ?? const Uuid().v4(),
        name: _name.text.trim(),
        category: _category,
        unitPrice: double.parse(_price.text.trim()),
        unit: _unit.text.trim().isEmpty ? 'Pcs' : _unit.text.trim(),
        isLabour: _category == ItemCategory.labour,
        partNumber: partNo.isEmpty ? null : partNo,
        taxPercent: _tax,
        notes: widget.existing?.notes,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
          20, 20, 20, MediaQuery.of(context).viewInsets.bottom + 20),
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(widget.existing == null ? tr('Add item') : tr('Edit item'),
                  style: GoogleFonts.poppins(
                      fontSize: AppText.title, fontWeight: FontWeight.w700)),
              const SizedBox(height: 16),
              TextFormField(
                controller: _name,
                autofocus: widget.existing == null,
                textCapitalization: TextCapitalization.words,
                decoration: InputDecoration(
                    labelText: tr('Name'), hintText: 'e.g. Brake pad set'),
                validator: (v) =>
                    (v ?? '').trim().isEmpty ? 'Enter a name' : null,
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<ItemCategory>(
                value: _category,
                decoration: InputDecoration(labelText: tr('Category')),
                items: [
                  for (final c in ItemCategory.values)
                    DropdownMenuItem(value: c, child: Text(c.displayName)),
                ],
                onChanged: (c) => setState(() {
                  _category = c ?? _category;
                  // Labour is sold per job; keep the unit in step unless
                  // the user typed their own.
                  final unit = _unit.text.trim();
                  if (unit.isEmpty || unit == 'Pcs' || unit == 'Job') {
                    _unit.text = _category == ItemCategory.labour ? 'Job' : 'Pcs';
                  }
                }),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    flex: 2,
                    child: TextFormField(
                      controller: _price,
                      keyboardType: const TextInputType.numberWithOptions(
                          decimal: true),
                      decoration: InputDecoration(
                          labelText: tr('Price'), prefixText: '₹ '),
                      validator: (v) {
                        final n = double.tryParse(v?.trim() ?? '');
                        return n == null || n <= 0
                            ? tr('Enter a price above 0')
                            : null;
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _unit,
                      decoration: InputDecoration(labelText: tr('Unit')),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<double>(
                value: _tax,
                decoration: InputDecoration(labelText: tr('GST %')),
                items: [
                  for (final t in {
                    ...context.read<GarageProvider>().config.taxPercentOptions,
                    _tax,
                  })
                    DropdownMenuItem(value: t, child: Text('${_fmt(t)}%')),
                ],
                onChanged: (t) => setState(() => _tax = t ?? _tax),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _partNo,
                decoration: InputDecoration(
                    labelText: tr('Part number (optional)')),
              ),
              const SizedBox(height: 20),
              FilledButton(
                onPressed: _submit,
                style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14)),
                child: Text(widget.existing == null ? tr('Add to price list') : tr('Save')),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
