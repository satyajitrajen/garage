import 'package:flutter/material.dart';
import 'payment.dart';

enum ExpenseCategory {
  rent,
  electricityUtilities,
  internetPhone,
  toolsEquipment,
  consumables,
  partsStock,
  staffFood,
  fuelGenerator,
  miscellaneous,
}

extension ExpenseCategoryExtension on ExpenseCategory {
  String get displayName {
    switch (this) {
      case ExpenseCategory.rent:
        return 'Workshop Rent';
      case ExpenseCategory.electricityUtilities:
        return 'Electricity & Water';
      case ExpenseCategory.internetPhone:
        return 'Internet & Bills';
      case ExpenseCategory.toolsEquipment:
        return 'Tools & Equipment';
      case ExpenseCategory.consumables:
        return 'Consumables & Sprays';
      case ExpenseCategory.partsStock:
        return 'Parts Stock Purchase';
      case ExpenseCategory.staffFood:
        return 'Staff Tea & Lunch';
      case ExpenseCategory.fuelGenerator:
        return 'Diesel / Generator';
      case ExpenseCategory.miscellaneous:
        return 'Miscellaneous';
    }
  }

  IconData get icon {
    switch (this) {
      case ExpenseCategory.rent:
        return Icons.store_rounded;
      case ExpenseCategory.electricityUtilities:
        return Icons.bolt_rounded;
      case ExpenseCategory.internetPhone:
        return Icons.wifi_rounded;
      case ExpenseCategory.toolsEquipment:
        return Icons.home_repair_service_rounded;
      case ExpenseCategory.consumables:
        return Icons.cleaning_services_rounded;
      case ExpenseCategory.partsStock:
        return Icons.inventory_2_rounded;
      case ExpenseCategory.staffFood:
        return Icons.local_cafe_rounded;
      case ExpenseCategory.fuelGenerator:
        return Icons.local_gas_station_rounded;
      case ExpenseCategory.miscellaneous:
        return Icons.receipt_long_rounded;
    }
  }
}

class GarageExpense {
  final String id;
  final String title;
  final ExpenseCategory category;
  final double amount;
  final DateTime expenseDate;
  final PaymentMode paymentMode;
  final String? vendorName;
  final String? notes;
  final String? receiptPath;

  GarageExpense({
    required this.id,
    required this.title,
    required this.category,
    required this.amount,
    DateTime? expenseDate,
    this.paymentMode = PaymentMode.cash,
    this.vendorName,
    this.notes,
    this.receiptPath,
  }) : expenseDate = expenseDate ?? DateTime.now();

  GarageExpense copyWith({
    String? id,
    String? title,
    ExpenseCategory? category,
    double? amount,
    DateTime? expenseDate,
    PaymentMode? paymentMode,
    String? vendorName,
    String? notes,
    String? receiptPath,
  }) {
    return GarageExpense(
      id: id ?? this.id,
      title: title ?? this.title,
      category: category ?? this.category,
      amount: amount ?? this.amount,
      expenseDate: expenseDate ?? this.expenseDate,
      paymentMode: paymentMode ?? this.paymentMode,
      vendorName: vendorName ?? this.vendorName,
      notes: notes ?? this.notes,
      receiptPath: receiptPath ?? this.receiptPath,
    );
  }

  /// Copy with no receipt (copyWith can't null a field).
  GarageExpense clearReceipt() => GarageExpense(
        id: id,
        title: title,
        category: category,
        amount: amount,
        expenseDate: expenseDate,
        paymentMode: paymentMode,
        vendorName: vendorName,
        notes: notes,
      );
}
