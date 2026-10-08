/// Summary lines for a GST breakdown (rate → tax amount), in rate order.
///
/// With [split] each rate becomes a CGST and an SGST line at half the rate
/// (intra-state GST), e.g. 18% → "CGST (9%)" and "SGST (9%)". Without it each
/// rate is a single "GST (18%)" line.
List<MapEntry<String, double>> gstLines(
  Map<double, double> breakdown, {
  bool split = true,
}) {
  String pct(double rate) => rate == rate.roundToDouble()
      ? rate.toStringAsFixed(0)
      : rate.toStringAsFixed(1);
  final lines = <MapEntry<String, double>>[];
  for (final entry in breakdown.entries) {
    if (split) {
      final half = pct(entry.key / 2);
      lines.add(MapEntry('CGST ($half%)', entry.value / 2));
      lines.add(MapEntry('SGST ($half%)', entry.value / 2));
    } else {
      lines.add(MapEntry('GST (${pct(entry.key)}%)', entry.value));
    }
  }
  return lines;
}
