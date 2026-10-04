import 'package:flutter/material.dart';

import '../models/maintenance_item.dart';

/// Lets the user change the price, quantity and discount of a line that is
/// already selected (e.g. a catalog part whose price differs for this job).
/// Returns the updated item, or null when cancelled.
Future<MaintenanceItem?> showEditItemDialog(
    BuildContext context, MaintenanceItem item) {
  String fmt(double v) =>
      v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toString();
  final priceController = TextEditingController(text: fmt(item.unitPrice));
  final qtyController = TextEditingController(text: fmt(item.quantity));
  final discountController =
      TextEditingController(text: fmt(item.discountPercent));
  final formKey = GlobalKey<FormState>();

  String? positive(String? v) {
    final n = double.tryParse(v?.trim() ?? '');
    if (n == null || n <= 0) return 'Must be greater than zero';
    return null;
  }

  return showDialog<MaintenanceItem>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(item.name, maxLines: 2, overflow: TextOverflow.ellipsis),
      content: Form(
        key: formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextFormField(
              controller: priceController,
              autofocus: true,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                  labelText: 'Unit price', prefixText: '₹ '),
              validator: positive,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: qtyController,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              decoration:
                  InputDecoration(labelText: 'Quantity (${item.unit})'),
              validator: positive,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: discountController,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(labelText: 'Discount %'),
              validator: (v) {
                final n = double.tryParse(v?.trim() ?? '');
                if (n == null || n < 0 || n > 100) {
                  return 'Between 0 and 100';
                }
                return null;
              },
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
        FilledButton(
          onPressed: () {
            if (!formKey.currentState!.validate()) return;
            Navigator.pop(
              ctx,
              item.copyWith(
                unitPrice: double.parse(priceController.text.trim()),
                quantity: double.parse(qtyController.text.trim()),
                discountPercent:
                    double.parse(discountController.text.trim()),
              ),
            );
          },
          child: const Text('Update'),
        ),
      ],
    ),
  );
}
