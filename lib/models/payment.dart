import '../l10n/app_language.dart';

enum PaymentMode {
  cash,
  upi,
  card,
  bankTransfer,
  cheque,
  other,
}

extension PaymentModeExtension on PaymentMode {
  String get displayName {
    switch (this) {
      case PaymentMode.cash:
        return tr('Cash');
      case PaymentMode.upi:
        return tr('UPI / QR / GPay');
      case PaymentMode.card:
        return tr('Credit / Debit Card');
      case PaymentMode.bankTransfer:
        return tr('Bank Transfer / NEFT');
      case PaymentMode.cheque:
        return tr('Cheque');
      case PaymentMode.other:
        return tr('Other');
    }
  }

  String get shortName {
    switch (this) {
      case PaymentMode.cash:
        return tr('Cash');
      case PaymentMode.upi:
        return tr('UPI');
      case PaymentMode.card:
        return tr('Card');
      case PaymentMode.bankTransfer:
        return tr('Bank');
      case PaymentMode.cheque:
        return tr('Cheque');
      case PaymentMode.other:
        return tr('Other');
    }
  }
}

class Payment {
  final String id;
  final String invoiceId;
  final String? customerId;
  final double amount;
  final PaymentMode mode;
  final String? transactionRef; // UPI Ref / UTR / Cheque No
  final DateTime paymentDate;
  final String? notes;
  final String? receivedBy; // Staff/Cashier name

  Payment({
    required this.id,
    required this.invoiceId,
    this.customerId,
    required this.amount,
    required this.mode,
    this.transactionRef,
    DateTime? paymentDate,
    this.notes,
    this.receivedBy,
  }) : paymentDate = paymentDate ?? DateTime.now();

  Payment copyWith({
    String? id,
    String? invoiceId,
    String? customerId,
    double? amount,
    PaymentMode? mode,
    String? transactionRef,
    DateTime? paymentDate,
    String? notes,
    String? receivedBy,
  }) {
    return Payment(
      id: id ?? this.id,
      invoiceId: invoiceId ?? this.invoiceId,
      customerId: customerId ?? this.customerId,
      amount: amount ?? this.amount,
      mode: mode ?? this.mode,
      transactionRef: transactionRef ?? this.transactionRef,
      paymentDate: paymentDate ?? this.paymentDate,
      notes: notes ?? this.notes,
      receivedBy: receivedBy ?? this.receivedBy,
    );
  }
}
