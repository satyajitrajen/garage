import 'package:flutter/services.dart';

/// Indian digit grouping for whole numbers: 45000 → "45,000",
/// 123456 → "1,23,456" (matches how amounts and KM read elsewhere).
String groupDigits(int value) {
  final negative = value < 0;
  final digits = value.abs().toString();
  if (digits.length <= 3) return '${negative ? '-' : ''}$digits';
  final last3 = digits.substring(digits.length - 3);
  var rest = digits.substring(0, digits.length - 3);
  final parts = <String>[];
  while (rest.length > 2) {
    parts.insert(0, rest.substring(rest.length - 2));
    rest = rest.substring(0, rest.length - 2);
  }
  if (rest.isNotEmpty) parts.insert(0, rest);
  return '${negative ? '-' : ''}${parts.join(',')},$last3';
}

/// Parses a field that may contain grouping commas ("45,000" → 45000).
int? parseGroupedInt(String text) =>
    int.tryParse(text.replaceAll(',', '').trim());

/// Groups digits as the user types. Only pure-digit input is reformatted;
/// anything else (a minus sign, a decimal point, letters) is left exactly as
/// typed so the field's validator can reject it.
class GroupedDigitsInputFormatter extends TextInputFormatter {
  const GroupedDigitsInputFormatter();

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final raw = newValue.text.replaceAll(',', '');
    if (raw.isEmpty || !RegExp(r'^\d+$').hasMatch(raw)) return newValue;
    final value = int.tryParse(raw);
    if (value == null) return newValue;
    final formatted = groupDigits(value);
    // Keep the caret after the same number of digits it was after.
    final cursor = newValue.selection.end.clamp(0, newValue.text.length);
    final digitsBefore =
        newValue.text.substring(0, cursor).replaceAll(',', '').length;
    var offset = formatted.length;
    var seen = 0;
    for (var i = 0; i < formatted.length; i++) {
      if (seen == digitsBefore) {
        offset = i;
        break;
      }
      if (formatted[i] != ',') seen++;
    }
    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: offset),
    );
  }
}
