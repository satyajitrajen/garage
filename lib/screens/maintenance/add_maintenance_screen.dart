import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import '../../data/api/api_exception.dart';
import '../../models/maintenance_item.dart';
import '../../providers/garage_provider.dart';
import '../../theme/app_dimens.dart';
import '../../theme/app_palette.dart';
import '../../utils/app_snack_bar.dart';
import '../../utils/currency_formatter.dart';
import '../../utils/permissions.dart';
import '../../utils/quantity_formatter.dart';
import '../../widgets/permission_gate.dart';
import '../../widgets/edit_item_dialog.dart';
import '../../widgets/search_bar_widget.dart';
import '../../theme/app_text.dart';

class AddMaintenanceScreen extends StatefulWidget {
  final List<MaintenanceItem> initialItems;
  final String title;

  const AddMaintenanceScreen({
    super.key,
    this.initialItems = const [],
    this.title = 'Add Maintenance Items',
  });

  @override
  State<AddMaintenanceScreen> createState() => _AddMaintenanceScreenState();
}

class _AddMaintenanceScreenState extends State<AddMaintenanceScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  late List<MaintenanceItem> _currentItems;
  final _searchController = TextEditingController();
  String _searchQuery = '';

  // Custom item form controllers
  final _customNameController = TextEditingController();
  final _customPriceController = TextEditingController();
  final _customQtyController = TextEditingController(text: '1');
  final _customUnitController = TextEditingController(text: 'Pcs');
  final _customDiscountController = TextEditingController(text: '0');
  ItemCategory _customCategory = ItemCategory.sparePart;
  bool _customIsLabour = false;
  bool _customSaveToCatalog = false;

  @override
  void initState() {
    super.initState();
    _currentItems = List<MaintenanceItem>.from(widget.initialItems);
    _tabController = TabController(length: 6, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    _customNameController.dispose();
    _customPriceController.dispose();
    _customQtyController.dispose();
    _customUnitController.dispose();
    _customDiscountController.dispose();
    super.dispose();
  }

  void _addCatalogueItem(MaintenanceItem item) {
    final existingIndex = _currentItems.indexWhere((i) => i.name == item.name);
    if (existingIndex != -1) {
      // Increment quantity
      final existing = _currentItems[existingIndex];
      setState(() {
        _currentItems[existingIndex] = existing.copyWith(quantity: existing.quantity + 1);
      });
    } else {
      setState(() {
        _currentItems.add(
          item.copyWith(id: const Uuid().v4(), quantity: 1),
        );
      });
    }
    // No snackbar: the selected-items header and the Done button count already
    // confirm the add, and a floating snackbar covered the Done button.
  }

  void _addCustomItem() {
    if (_customNameController.text.trim().isEmpty || _customPriceController.text.trim().isEmpty) {
      showAppSnackBar(context, 'Please enter item name and price', type: SnackBarType.info);
      return;
    }

    final price = double.tryParse(_customPriceController.text.trim()) ?? 0.0;
    final qty = double.tryParse(_customQtyController.text.trim()) ?? 1.0;
    final discount = double.tryParse(_customDiscountController.text.trim()) ?? 0.0;

    // Validate inputs so bad line items can't corrupt invoice totals.
    if (price <= 0) {
      showAppSnackBar(context, 'Price must be greater than zero', type: SnackBarType.info);
      return;
    }
    if (qty <= 0) {
      showAppSnackBar(context, 'Quantity must be greater than zero', type: SnackBarType.info);
      return;
    }
    if (discount < 0 || discount > 100) {
      showAppSnackBar(context, 'Discount must be between 0 and 100 percent', type: SnackBarType.error);
      return;
    }

    final newItem = MaintenanceItem(
      id: const Uuid().v4(),
      name: _customNameController.text.trim(),
      category: _customCategory,
      unitPrice: price,
      quantity: qty,
      unit: _customUnitController.text.trim().isEmpty ? 'Pcs' : _customUnitController.text.trim(),
      discountPercent: discount,
      taxPercent: context.read<GarageProvider>().config.defaultTaxPercent,
      isLabour: _customIsLabour || _customCategory == ItemCategory.labour,
    );

    setState(() {
      _currentItems.add(newItem);
    });
    if (_customSaveToCatalog) _saveToCatalog(newItem);

    _customNameController.clear();
    _customPriceController.clear();
    _customQtyController.text = '1';
    _customDiscountController.text = '0';

    Navigator.pop(context); // Close bottom sheet
    showAppSnackBar(context, 'Custom item added!', type: SnackBarType.success);
  }

  /// Stores a custom line in the garage price list so it can be picked next
  /// time. Runs in the background: the bill line is already added.
  Future<void> _saveToCatalog(MaintenanceItem item) async {
    final provider = context.read<GarageProvider>();
    final messenger = ScaffoldMessenger.of(context);
    try {
      await provider.addCatalogItem(MaintenanceItem(
        id: const Uuid().v4(),
        name: item.name,
        category: item.category,
        unitPrice: item.unitPrice,
        unit: item.unit,
        isLabour: item.isLabour,
      ));
    } catch (e) {
      messenger.showSnackBar(SnackBar(
        content: Text(e is ApiException
            ? 'Not saved to price list: ${e.userMessage}'
            : 'Could not save item to price list'),
        behavior: SnackBarBehavior.floating,
      ));
    }
  }

  Future<void> _confirmDeleteCatalogItem(MaintenanceItem item) async {
    if (!ensurePermission(context, Permissions.jobcardsManage)) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Remove from price list?'),
        content: Text('"${item.name}" will no longer appear in the catalog. '
            'Existing bills are not affected.'),
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
      showAppSnackBar(
        context,
        e is ApiException ? e.userMessage : 'Could not remove item',
        type: SnackBarType.error,
      );
    }
  }

  void _showAddCustomItemSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppDimens.radiusSheet)),
      ),
      backgroundColor: context.palette.surface,
      builder: (ctx) => SafeArea(
        top: false,
        child: StatefulBuilder(
          builder: (context, setSheetState) {
            // Palette is captured inside the builder so a theme flip while
            // the sheet is open re-reads it (stale-capture guard).
            final palette = context.palette;
            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom + 24,
                top: 24,
                left: 20,
                right: 20,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            'Add Custom Item / Service',
                            style: GoogleFonts.poppins(fontSize: AppText.title, fontWeight: FontWeight.w700),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close_rounded),
                          onPressed: () => Navigator.pop(context),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _customNameController,
                      decoration: const InputDecoration(
                        labelText: 'Item / Job Description *',
                        hintText: 'e.g. Steering Rack Bushing / Lathe Job',
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _customPriceController,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              labelText: 'Unit Rate (₹) *',
                              hintText: 'e.g. 1500',
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextField(
                            controller: _customQtyController,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              labelText: 'Quantity',
                              hintText: 'e.g. 1',
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _customUnitController,
                            decoration: const InputDecoration(
                              labelText: 'Unit',
                              hintText: 'Pcs / Ltr / Job / Set',
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextField(
                            controller: _customDiscountController,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              labelText: 'Discount %',
                              hintText: '0',
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Text(
                      'Category',
                      style: GoogleFonts.poppins(fontSize: AppText.caption, fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 8,
                      children: ItemCategory.values.map((cat) {
                        final isSelected = _customCategory == cat;
                        return ChoiceChip(
                          label: Text(cat.displayName),
                          selected: isSelected,
                          selectedColor: palette.primary.withValues(alpha: 0.15),
                          onSelected: (selected) {
                            if (selected) {
                              setSheetState(() {
                                _customCategory = cat;
                                _customIsLabour = cat == ItemCategory.labour;
                              });
                            }
                          },
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 12),
                    CheckboxListTile(
                      value: _customIsLabour,
                      contentPadding: EdgeInsets.zero,
                      activeColor: palette.primary,
                      title: Text(
                        'Count as Labour / Service Charge',
                        style: GoogleFonts.poppins(fontSize: AppText.body),
                      ),
                      onChanged: (val) {
                        setSheetState(() => _customIsLabour = val ?? false);
                      },
                    ),
                    PermissionGate(
                      permission: Permissions.jobcardsManage,
                      child: CheckboxListTile(
                        value: _customSaveToCatalog,
                        contentPadding: EdgeInsets.zero,
                        activeColor: palette.primary,
                        title: Text(
                          'Save to price list for next time',
                          style: GoogleFonts.poppins(fontSize: AppText.body),
                        ),
                        onChanged: (val) {
                          setSheetState(
                              () => _customSaveToCatalog = val ?? false);
                        },
                      ),
                    ),
                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _addCustomItem,
                        style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16)),
                        child: const Text('Add to Bill Items'),
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Future<void> _editItem(int index) async {
    final updated = await showEditItemDialog(context, _currentItems[index]);
    if (updated == null || !mounted) return;
    setState(() => _currentItems[index] = updated);
  }

  void _updateItemQuantity(int index, double delta) {
    final item = _currentItems[index];
    final newQty = item.quantity + delta;
    if (newQty <= 0) {
      setState(() => _currentItems.removeAt(index));
    } else {
      setState(() {
        _currentItems[index] = item.copyWith(quantity: newQty);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<GarageProvider>(context);
    final palette = context.palette;

    final partsSubtotal = _currentItems
        .where((i) => !i.isLabour)
        .fold(0.0, (sum, i) => sum + i.totalAmount);
    final labourSubtotal = _currentItems
        .where((i) => i.isLabour)
        .fold(0.0, (sum, i) => sum + i.totalAmount);
    final totalAmount = _currentItems.fold(0.0, (sum, i) => sum + i.totalAmount);

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title, style: GoogleFonts.poppins(fontWeight: FontWeight.w700)),
        actions: [
          TextButton.icon(
            onPressed: _showAddCustomItemSheet,
            icon: Icon(Icons.add_circle_outline_rounded, color: palette.primary),
            label: Text(
              'Custom Item',
              style: GoogleFonts.poppins(
                color: palette.primary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          // ---------------------------------------------------------
          // SELECTED ITEMS DRAWER / ACCORDION PREVIEW
          // ---------------------------------------------------------
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            color: palette.card,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        'Selected Work Items (${_currentItems.length})',
                        style: GoogleFonts.poppins(
                          fontSize: AppText.subtitle,
                          fontWeight: FontWeight.w700,
                          color: palette.textPrimary,
                        ),
                      ),
                    ),
                    if (_currentItems.isNotEmpty)
                      TextButton(
                        onPressed: () => setState(() => _currentItems.clear()),
                        style: TextButton.styleFrom(
                          padding: EdgeInsets.zero,
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        child: Text(
                          'Clear All',
                          style: GoogleFonts.poppins(
                            fontSize: AppText.caption,
                            color: palette.pending,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                  ],
                ),
                if (_currentItems.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  SizedBox(
                    height: 110,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: _currentItems.length,
                      separatorBuilder: (_, _) => const SizedBox(width: 10),
                      itemBuilder: (context, index) {
                        final item = _currentItems[index];
                        // Tap a selected line to change its price / qty.
                        return GestureDetector(
                          onTap: () => _editItem(index),
                          child: Container(
                          width: 200,
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: palette.background,
                            borderRadius: BorderRadius.circular(AppDimens.radiusBadge),
                            border: Border.all(
                              color: item.isLabour
                                  ? palette.inProgress.withOpacity(0.4)
                                  : palette.primary.withOpacity(0.4),
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(
                                    child: Text(
                                      item.name,
                                      style: GoogleFonts.poppins(
                                        fontSize: AppText.caption,
                                        fontWeight: FontWeight.w700,
                                      ),
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  GestureDetector(
                                    onTap: () => setState(() => _currentItems.removeAt(index)),
                                    child: Icon(Icons.close_rounded, size: 16, color: palette.textMuted),
                                  ),
                                ],
                              ),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                  Text(
                                    '@ ${CurrencyFormatter.format(item.unitPrice)}',
                                    style: GoogleFonts.poppins(fontSize: AppText.label, color: palette.textMuted),
                                  ),
                                  Text(
                                    CurrencyFormatter.format(item.totalAmount),
                                    style: GoogleFonts.poppins(
                                      fontSize: AppText.body,
                                      fontWeight: FontWeight.w700,
                                      color: palette.primary,
                                    ),
                                  ),
                                    ],
                                  ),
                                  Row(
                                    children: [
                                      GestureDetector(
                                        onTap: () => _updateItemQuantity(index, -1),
                                        child: Container(
                                          padding: const EdgeInsets.all(3),
                                          decoration: BoxDecoration(
                                            color: palette.cardAlt,
                                            borderRadius: BorderRadius.circular(6),
                                          ),
                                          child: const Icon(Icons.remove, size: 12),
                                        ),
                                      ),
                                      Padding(
                                        padding: const EdgeInsets.symmetric(horizontal: 6),
                                        child: Text(
                                          formatQuantity(item.quantity),
                                          style: GoogleFonts.poppins(fontWeight: FontWeight.w700, fontSize: AppText.caption),
                                        ),
                                      ),
                                      GestureDetector(
                                        onTap: () => _updateItemQuantity(index, 1),
                                        child: Container(
                                          padding: const EdgeInsets.all(3),
                                          decoration: BoxDecoration(
                                            color: palette.cardAlt,
                                            borderRadius: BorderRadius.circular(6),
                                          ),
                                          child: const Icon(Icons.add, size: 12),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Tap an item to edit its price',
                    style: GoogleFonts.poppins(fontSize: AppText.label, color: palette.textMuted),
                  ),
                ],
              ],
            ),
          ),
          const Divider(height: 1),

          // Search in Catalogue
          Padding(
            padding: const EdgeInsets.all(12),
            child: CustomSearchBar(
              controller: _searchController,
              hintText: 'Search parts, oils, labour...',
              onChanged: (val) => setState(() => _searchQuery = val),
            ),
          ),

          // Categories Tabs
          TabBar(
            controller: _tabController,
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            labelStyle: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: AppText.body),
            tabs: [
              const Tab(text: 'All Items'),
              Tab(text: ItemCategory.sparePart.displayName),
              Tab(text: ItemCategory.labour.displayName),
              Tab(text: ItemCategory.fluids.displayName),
              Tab(text: ItemCategory.tyresBattery.displayName),
              Tab(text: ItemCategory.transportMisc.displayName),
            ],
          ),

          // Catalogue List
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildCatalogueList(provider.catalog, null),
                _buildCatalogueList(provider.catalog, ItemCategory.sparePart),
                _buildCatalogueList(provider.catalog, ItemCategory.labour),
                _buildCatalogueList(provider.catalog, ItemCategory.fluids),
                _buildCatalogueList(provider.catalog, ItemCategory.tyresBattery),
                _buildCatalogueList(provider.catalog, ItemCategory.transportMisc),
              ],
            ),
          ),

          // Bottom Totals & Confirmation Bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            decoration: BoxDecoration(
              color: palette.card,
              boxShadow: AppDimens.cardShadow(palette.textPrimary),
            ),
            child: SafeArea(
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Wrap(
                          spacing: 8,
                          children: [
                            Text(
                              'Parts: ${CurrencyFormatter.format(partsSubtotal)}',
                              style: GoogleFonts.poppins(
                                fontSize: AppText.label,
                                color: palette.textSecondary,
                              ),
                            ),
                            Text(
                              'Labour: ${CurrencyFormatter.format(labourSubtotal)}',
                              style: GoogleFonts.poppins(
                                fontSize: AppText.label,
                                color: palette.textSecondary,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          CurrencyFormatter.format(totalAmount),
                          style: GoogleFonts.poppins(
                            fontSize: AppText.headline,
                            fontWeight: FontWeight.w700,
                            color: palette.primary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  ElevatedButton.icon(
                    onPressed: () {
                      Navigator.pop(context, _currentItems);
                    },
                    icon: const Icon(Icons.check_rounded, size: 18),
                    label: Text('Done (${_currentItems.length} items)'),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCatalogueList(List<MaintenanceItem> allCatalog, ItemCategory? filterCat) {
    final palette = context.palette;
    final filtered = allCatalog.where((item) {
      if (filterCat != null && item.category != filterCat) return false;
      if (_searchQuery.isNotEmpty) {
        final q = _searchQuery.toLowerCase();
        final nameMatches = item.name.toLowerCase().contains(q);
        final partNoMatches = item.partNumber?.toLowerCase().contains(q) ?? false;
        return nameMatches || partNoMatches;
      }
      return true;
    }).toList();

    if (filtered.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            allCatalog.isEmpty
                ? 'Your price list is empty.\nAdd a custom item and tick '
                    '"Save to price list" to reuse it.'
                : 'No items found in this category',
            textAlign: TextAlign.center,
            style: GoogleFonts.poppins(color: context.palette.textMuted),
          ),
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: filtered.length,
      separatorBuilder: (_, _) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        final item = filtered[index];
        final meta = [
          item.category.displayName,
          if (item.partNumber != null) item.partNumber!,
        ].join(' • ');

        // Custom row instead of ListTile: at narrow widths / large text the
        // ListTile trailing price block squeezed the title to nothing.
        return Card(
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: () => _addCatalogueItem(item),
            onLongPress: () => _confirmDeleteCatalogItem(item),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
              child: Row(
                children: [
                  CircleAvatar(
                    backgroundColor: item.isLabour
                        ? palette.inProgress.withOpacity(0.12)
                        : palette.primary.withOpacity(0.12),
                    child: Icon(
                      item.isLabour ? Icons.build_rounded : Icons.precision_manufacturing_rounded,
                      color: item.isLabour ? palette.inProgress : palette.primary,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.name,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.poppins(fontSize: AppText.subtitle, fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          meta,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.poppins(fontSize: AppText.label, color: palette.textMuted),
                        ),
                        const SizedBox(height: 4),
                        Text.rich(
                          TextSpan(children: [
                            TextSpan(
                              text: CurrencyFormatter.format(item.unitPrice),
                              style: GoogleFonts.poppins(
                                fontSize: AppText.subtitle,
                                fontWeight: FontWeight.w700,
                                color: palette.primary,
                              ),
                            ),
                            TextSpan(
                              text: ' / ${item.unit}',
                              style: GoogleFonts.poppins(fontSize: AppText.label, color: palette.textMuted),
                            ),
                          ]),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  IconButton.filledTonal(
                    tooltip: 'Add',
                    onPressed: () => _addCatalogueItem(item),
                    icon: const Icon(Icons.add_rounded, size: 20),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
