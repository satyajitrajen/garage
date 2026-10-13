/// Formats a quantity for display on bills and slips: whole quantities are
/// shown as integers ("2"), fractional ones keep their decimal without a
/// padded trailing zero ("2.5", not "2.50"; "2.05" keeps its hundredth).
String formatQuantity(double quantity) {
  if (quantity % 1 == 0) {
    return quantity.toInt().toString();
  }
  // Drop the trailing zero(s) of the 2-decimal rendering, plus the point
  // when nothing follows (e.g. 2.999 rounds to "3.00" → "3"). Integers never
  // reach this branch, so "20" stays "20".
  return quantity.toStringAsFixed(2).replaceFirst(RegExp(r'\.?0+$'), '');
}
