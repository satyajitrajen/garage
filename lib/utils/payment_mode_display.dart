import 'package:flutter/material.dart';

import '../models/payment.dart';

/// Display labels and icons for [PaymentMode], shared by screens so payment
/// modes render consistently everywhere. Distinct from the existing
/// `PaymentModeExtension` (`displayName` verbose form / `shortName` compact
/// form) in lib/models/payment.dart.
extension PaymentModeDisplay on PaymentMode {
  String get label {
    switch (this) {
      case PaymentMode.cash:
        return 'Cash';
      case PaymentMode.upi:
        return 'UPI';
      case PaymentMode.card:
        return 'Card';
      case PaymentMode.bankTransfer:
        return 'Bank Transfer';
      case PaymentMode.cheque:
        return 'Cheque';
      case PaymentMode.other:
        return 'Other';
    }
  }

  IconData get icon {
    switch (this) {
      case PaymentMode.cash:
        return Icons.payments_rounded;
      case PaymentMode.upi:
        return Icons.smartphone_rounded;
      case PaymentMode.card:
        return Icons.credit_card_rounded;
      case PaymentMode.bankTransfer:
        return Icons.account_balance_rounded;
      case PaymentMode.cheque:
        return Icons.receipt_long_rounded;
      case PaymentMode.other:
        return Icons.more_horiz_rounded;
    }
  }
}
