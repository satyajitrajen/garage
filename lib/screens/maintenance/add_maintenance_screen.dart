import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import '../../models/maintenance_item.dart';
import '../../providers/garage_provider.dart';
import '../../theme/app_colors.dart';
import '../../utils/currency_formatter.dart';
import '../../utils/quantity_formatter.dart';
import '../../widgets/search_bar_widget.dart';

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

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Added "${item.name}"'),
        duration: const Duration(milliseconds: 1000),
        backgroundColor: AppColors.paid,
      ),
    );
  }

  void _addCustomItem() {
    if (_customNameController.text.trim().isEmpty || _customPriceController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter item name and price')),
      );
      return;
    }

    final price = double.tryParse(_customPriceController.text.trim()) ?? 0.0;
    final qty = double.tryParse(_customQtyController.text.trim()) ?? 1.0;
    final discount = double.tryParse(_customDiscountController.text.trim()) ?? 0.0;

    // Validate inputs so bad line items can't corrupt invoice totals.
    if (price <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Price must be greater than zero')),
      );
      return;
    }
    if (qty <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Quantity must be greater than zero')),
      );
      return;
    }
    if (discount < 0 || discount > 100) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Discount must be between 0 and 100 percent')),
      );
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
      taxPercent: 18.0,
      isLabour: _customIsLabour || _customCategory == ItemCategory.labour,
    );

    setState(() {
      _currentItems.add(newItem);
    });

    _customNameController.clear();
    _customPriceController.clear();
    _customQtyController.text = '1';
    _customDiscountController.text = '0';

    Navigator.pop(context); // Close bottom sheet
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Custom item added!'), backgroundColor: AppColors.paid),
    );
  }

  void _showAddCustomItemSheet() {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
      builder: (ctx) => SafeArea(
        top: false,
        child: StatefulBuilder(
          builder: (context, setSheetState) {
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
                        Text(
                          'Add Custom Item / Service',
                          style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.w700),
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
                      style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 8,
                      children: ItemCategory.values.map((cat) {
                        final isSelected = _customCategory == cat;
                        return ChoiceChip(
                          label: Text(cat.displayName),
                          selected: isSelected,
                          selectedColor: AppColors.primary.withValues(alpha: 0.15),
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
                      activeColor: AppColors.primary,
                      title: Text(
                        'Count as Labour / Service Charge',
                        style: GoogleFonts.poppins(fontSize: 14),
                      ),
                      onChanged: (val) {
                        setSheetState(() => _customIsLabour = val ?? false);
                      },
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
    final isDark = Theme.of(context).brightness == Brightness.dark;

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
            icon: const Icon(Icons.add_circle_outline_rounded, color: AppColors.primary),
            label: Text(
              'Custom Item',
              style: GoogleFonts.poppins(
                color: AppColors.primary,
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
            color: isDark ? const Color(0xFF1E293B) : Colors.white,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Selected Work Items (${_currentItems.length})',
                      style: GoogleFonts.poppins(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: isDark ? Colors.white : AppColors.textPrimary,
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
                            fontSize: 12.5,
                            color: AppColors.pending,
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
                        return Container(
                          width: 200,
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: item.isLabour
                                  ? AppColors.inProgress.withOpacity(0.4)
                                  : AppColors.primary.withOpacity(0.4),
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
                                        fontSize: 12.5,
                                        fontWeight: FontWeight.w700,
                                      ),
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  GestureDetector(
                                    onTap: () => setState(() => _currentItems.removeAt(index)),
                                    child: const Icon(Icons.close_rounded, size: 16, color: AppColors.textMuted),
                                  ),
                                ],
                              ),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    CurrencyFormatter.format(item.totalAmount),
                                    style: GoogleFonts.poppins(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w800,
                                      color: AppColors.primary,
                                    ),
                                  ),
                                  Row(
                                    children: [
                                      GestureDetector(
                                        onTap: () => _updateItemQuantity(index, -1),
                                        child: Container(
                                          padding: const EdgeInsets.all(3),
                                          decoration: BoxDecoration(
                                            color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                                            borderRadius: BorderRadius.circular(6),
                                          ),
                                          child: const Icon(Icons.remove, size: 12),
                                        ),
                                      ),
                                      Padding(
                                        padding: const EdgeInsets.symmetric(horizontal: 6),
                                        child: Text(
                                          formatQuantity(item.quantity),
                                          style: GoogleFonts.poppins(fontWeight: FontWeight.w700, fontSize: 13),
                                        ),
                                      ),
                                      GestureDetector(
                                        onTap: () => _updateItemQuantity(index, 1),
                                        child: Container(
                                          padding: const EdgeInsets.all(3),
                                          decoration: BoxDecoration(
                                            color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
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
                        );
                      },
                    ),
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
            labelColor: AppColors.primary,
            unselectedLabelColor: isDark ? const Color(0xFF94A3B8) : AppColors.textMuted,
            indicatorColor: AppColors.primary,
            tabAlignment: TabAlignment.start,
            labelStyle: GoogleFonts.poppins(fontWeight: FontWeight.w700, fontSize: 13.5),
            tabs: const [
              Tab(text: 'All Items'),
              Tab(text: 'Spare Parts'),
              Tab(text: 'Labour & Services'),
              Tab(text: 'Oils & Fluids'),
              Tab(text: 'Tyres & Battery'),
              Tab(text: 'Transport / Misc'),
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
              color: isDark ? const Color(0xFF1E293B) : Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.08),
                  blurRadius: 10,
                  offset: const Offset(0, -4),
                ),
              ],
            ),
            child: SafeArea(
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              'Parts: ${CurrencyFormatter.format(partsSubtotal)}',
                              style: GoogleFonts.poppins(
                                fontSize: 11.5,
                                color: isDark ? const Color(0xFF94A3B8) : AppColors.textSecondary,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Labour: ${CurrencyFormatter.format(labourSubtotal)}',
                              style: GoogleFonts.poppins(
                                fontSize: 11.5,
                                color: isDark ? const Color(0xFF94A3B8) : AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          CurrencyFormatter.format(totalAmount),
                          style: GoogleFonts.poppins(
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                            color: AppColors.primary,
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
        child: Text(
          'No items found in this category',
          style: GoogleFonts.poppins(color: AppColors.textMuted),
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: filtered.length,
      separatorBuilder: (_, _) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        final item = filtered[index];
        final isSelected = _currentItems.any((i) => i.name == item.name);

        return Card(
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            leading: CircleAvatar(
              backgroundColor: item.isLabour
                  ? AppColors.inProgress.withOpacity(0.12)
                  : AppColors.primary.withOpacity(0.12),
              child: Icon(
                item.isLabour ? Icons.build_rounded : Icons.precision_manufacturing_rounded,
                color: item.isLabour ? AppColors.inProgress : AppColors.primary,
                size: 20,
              ),
            ),
            title: Text(
              item.name,
              style: GoogleFonts.poppins(fontSize: 14.5, fontWeight: FontWeight.w700),
            ),
            subtitle: Row(
              children: [
                Text(
                  item.category.displayName,
                  style: GoogleFonts.poppins(fontSize: 12, color: AppColors.textMuted),
                ),
                if (item.partNumber != null) ...[
                  const SizedBox(width: 8),
                  Text(
                    '• ${item.partNumber}',
                    style: GoogleFonts.poppins(fontSize: 12, color: AppColors.textMuted),
                  ),
                ],
              ],
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      CurrencyFormatter.format(item.unitPrice),
                      style: GoogleFonts.poppins(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: AppColors.primary,
                      ),
                    ),
                    Text(
                      'per ${item.unit}',
                      style: GoogleFonts.poppins(fontSize: 11, color: AppColors.textMuted),
                    ),
                  ],
                ),
                const SizedBox(width: 10),
                IconButton.filledTonal(
                  onPressed: () => _addCatalogueItem(item),
                  icon: Icon(
                    isSelected ? Icons.add_rounded : Icons.add_rounded,
                    size: 20,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
