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
