class AppConfig {
  const AppConfig({
    this.defaultTaxPercent = 18.0,
    this.taxPercentOptions = const [0.0, 12.0, 18.0, 28.0],
    this.invoiceDueDays = 7,
    this.quotationValidityOptions = const [7, 15, 30],
    this.workingDaysPerMonth = 26,
    this.promisedDeliveryHours = 6,
    this.invoiceNotes = 'Thank you for choosing us! Standard warranty applies.',
    this.invoiceTerms =
        'All parts replaced carry manufacturer warranty. Labour warranty 30 days.',
    this.defaultReceivedBy = 'Cashier',
  });

  final double defaultTaxPercent;
  final List<double> taxPercentOptions;
  final int invoiceDueDays;
  final List<int> quotationValidityOptions;
  final int workingDaysPerMonth;
  final int promisedDeliveryHours;
  final String invoiceNotes;
  final String invoiceTerms;
  final String defaultReceivedBy;
}

/// Heals a raw config fetched from the repository so form screens can trust
/// the invariants (option lists non-empty, default tax a member of the tax
/// options) without re-validating in every dropdown.
///
/// [AppConfig.defaultTaxPercent] is a billed money value, so when the stored
/// option list has drifted out of sync with it, the stored rate is preserved
/// by appending it to the options rather than silently rewriting the tax rate
/// the garage actually bills at. Pure and side-effect free so tests can call
/// it directly.
AppConfig normalizeConfig(AppConfig raw) {
  final defaults = const AppConfig();
  final taxOptions = raw.taxPercentOptions.isNotEmpty
      ? raw.taxPercentOptions
      : defaults.taxPercentOptions;
  final healedTaxOptions = taxOptions.contains(raw.defaultTaxPercent)
      ? taxOptions
      : [...taxOptions, raw.defaultTaxPercent];
  final validityOptions = raw.quotationValidityOptions.isNotEmpty
      ? raw.quotationValidityOptions
      : defaults.quotationValidityOptions;
  return AppConfig(
    defaultTaxPercent: raw.defaultTaxPercent,
    taxPercentOptions: healedTaxOptions,
    invoiceDueDays: raw.invoiceDueDays,
    quotationValidityOptions: validityOptions,
    workingDaysPerMonth: raw.workingDaysPerMonth,
    promisedDeliveryHours: raw.promisedDeliveryHours,
    invoiceNotes: raw.invoiceNotes,
    invoiceTerms: raw.invoiceTerms,
    defaultReceivedBy: raw.defaultReceivedBy,
  );
}
