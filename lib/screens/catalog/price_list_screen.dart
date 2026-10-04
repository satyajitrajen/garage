import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';

import '../../data/api/api_exception.dart';
import '../../models/maintenance_item.dart';
import '../../providers/garage_provider.dart';
import '../../theme/app_palette.dart';
import '../../theme/app_text.dart';
import '../../utils/app_snack_bar.dart';
import '../../utils/currency_formatter.dart';
import '../../widgets/empty_state_widget.dart';
import '../../widgets/search_bar_widget.dart';

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
    final result = await showModalBottomSheet<MaintenanceItem>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => _ItemForm(existing: existing),
    );
    if (result == null || !mounted) return;
    final provider = context.read<GarageProvider>();
    try {
      // The catalog API has no update: an edit saves the new version first,
      // then removes the old one, so a failure never loses the item.
      await provider.addCatalogItem(result);
      if (existing != null) await provider.deleteCatalogItem(existing.id);
      if (!mounted) return;
      showAppSnackBar(context, existing == null ? 'Item added' : 'Item updated',
          type: SnackBarType.success);
    } catch (e) {
      if (!mounted) return;
      showAppSnackBar(context,
          e is ApiException ? e.userMessage : 'Could not save item',
          type: SnackBarType.error);
    }
  }

  Future<void> _delete(MaintenanceItem item) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Remove from price list?'),
        content: Text('"${item.name}" will no longer appear when adding items. '
            'Existing job cards and bills are not affected.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Keep')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Remove')),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    try {
      await context.read<GarageProvider>().deleteCatalogItem(item.id);
    } catch (e) {
      if (!mounted) return;
      showAppSnackBar(context,
          e is ApiException ? e.userMessage : 'Could not remove item',
          type: SnackBarType.error);
    }
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
      appBar: AppBar(title: const Text('Spare parts & price list')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openForm(),
        icon: const Icon(Icons.add_rounded),
        label: const Text('Add item'),
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
              hintText: 'Search parts, labour…',
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
                      label: Text(cat?.displayName ?? 'All'),
                      selected: _filter == cat,
                      onSelected: (_) => setState(() => _filter = cat),
                    ),
                  ),
              ],
            ),
          ),
          Expanded(
            child: items.isEmpty
                ? EmptyStateWidget(
                    icon: Icons.inventory_2_outlined,
                    title: catalog.isEmpty ? 'No items yet' : 'No matches',
                    description: catalog.isEmpty
                        ? 'Add spare parts and labour with their prices to pick them quickly on job cards.'
                        : 'Try a different search or category.',
                  )
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
                                    color: palette.primary),
                              ),
                              IconButton(
                                tooltip: 'Remove',
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
        id: const Uuid().v4(),
        name: _name.text.trim(),
        category: _category,
        unitPrice: double.parse(_price.text.trim()),
        unit: _unit.text.trim().isEmpty ? 'Pcs' : _unit.text.trim(),
        isLabour: _category == ItemCategory.labour,
        partNumber: partNo.isEmpty ? null : partNo,
        taxPercent: widget.existing?.taxPercent ??
            context.read<GarageProvider>().config.defaultTaxPercent,
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
              Text(widget.existing == null ? 'Add item' : 'Edit item',
                  style: GoogleFonts.poppins(
                      fontSize: AppText.title, fontWeight: FontWeight.w700)),
              const SizedBox(height: 16),
              TextFormField(
                controller: _name,
                autofocus: widget.existing == null,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(
                    labelText: 'Name', hintText: 'e.g. Brake pad set'),
                validator: (v) =>
                    (v ?? '').trim().isEmpty ? 'Enter a name' : null,
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<ItemCategory>(
                value: _category,
                decoration: const InputDecoration(labelText: 'Category'),
                items: [
                  for (final c in ItemCategory.values)
                    DropdownMenuItem(value: c, child: Text(c.displayName)),
                ],
                onChanged: (c) => setState(() => _category = c ?? _category),
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
                      decoration: const InputDecoration(
                          labelText: 'Price', prefixText: '₹ '),
                      validator: (v) {
                        final n = double.tryParse(v?.trim() ?? '');
                        return n == null || n <= 0
                            ? 'Enter a price above 0'
                            : null;
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _unit,
                      decoration: const InputDecoration(labelText: 'Unit'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _partNo,
                decoration: const InputDecoration(
                    labelText: 'Part number (optional)'),
              ),
              const SizedBox(height: 20),
              FilledButton(
                onPressed: _submit,
                style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14)),
                child: Text(widget.existing == null ? 'Add to price list' : 'Save'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
