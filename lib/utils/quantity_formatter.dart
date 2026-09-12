/// Formats a quantity for display on bills and slips: whole quantities are
/// shown as integers ("2"), fractional ones keep their decimal ("2.5").
String formatQuantity(double quantity) {
  if (quantity % 1 == 0) {
    return quantity.toInt().toString();
  }
  return quantity.toStringAsFixed(2);
}
