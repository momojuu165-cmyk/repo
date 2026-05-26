/// Application-wide configurable settings stored in Supabase.
class AppSettings {
  /// Monthly installment rate as a percentage (e.g. 3.0 = 3%)
  final double monthlyInstallmentRate;

  /// Rate override per number of months {months: rate%}
  /// e.g. {3: 5.0, 6: 10.0, 12: 20.0}
  final Map<int, double> installmentRatesByMonths;

  /// Default management fee for partner groups (%)
  final double defaultAdminFeeRate;

  /// Points earned per currency unit (e.g. 1 point per EGP)
  final int pointsPerCurrency;

  /// Redemption rate: value of 1 point in EGP
  final double pointsRedemptionRate;

  /// Maximum allowed installment months
  final int maxInstallmentMonths;

  /// Currency unit for displaying point value: 'piasters' or 'pounds'
  final String pointCurrencyType;

  const AppSettings({
    this.monthlyInstallmentRate = 3.0,
    this.installmentRatesByMonths = const {3: 5.0, 6: 10.0, 12: 20.0},
    this.defaultAdminFeeRate = 5.0,
    this.pointsPerCurrency = 1,
    this.pointsRedemptionRate = 0.01,
    this.maxInstallmentMonths = 24,
    this.pointCurrencyType = 'piasters',
  });

  /// Calculate installment rate for a given number of months.
  /// Uses exact-month override if defined, otherwise monthly rate × months.
  double rateForMonths(int months) {
    if (installmentRatesByMonths.containsKey(months)) {
      return installmentRatesByMonths[months]!;
    }
    return monthlyInstallmentRate * months;
  }

  /// Calculate total price with installment fee applied.
  double totalWithFee(double salePrice, int months) {
    final rate = rateForMonths(months) / 100.0;
    return salePrice * (1.0 + rate);
  }

  /// Value of 1 point in the chosen currency unit
  double get pointValueInUnit =>
      pointCurrencyType == 'piasters' ? pointsRedemptionRate * 100 : pointsRedemptionRate;

  String get pointCurrencyLabel =>
      pointCurrencyType == 'piasters' ? 'قرش' : 'جنيه';

  Map<String, dynamic> toMap() => {
        'monthly_installment_rate': monthlyInstallmentRate,
        'installment_rates_by_months':
            installmentRatesByMonths.map((k, v) => MapEntry(k.toString(), v)),
        'default_admin_fee_rate': defaultAdminFeeRate,
        'points_per_currency': pointsPerCurrency,
        'points_redemption_rate': pointsRedemptionRate,
        'max_installment_months': maxInstallmentMonths,
        'point_currency_type': pointCurrencyType,
      };

  factory AppSettings.fromMap(Map<String, dynamic> m) {
    Map<int, double> ratesMap = {3: 5.0, 6: 10.0, 12: 20.0};
    final raw = m['installment_rates_by_months'];
    if (raw is Map) {
      ratesMap = raw.map((k, v) =>
          MapEntry(int.tryParse(k.toString()) ?? 0, (v as num).toDouble()));
    }
    final rawPointsPerCurrency = (m['points_per_currency'] as int? ?? 1);
    final sanitizedPointsPerCurrency = rawPointsPerCurrency <= 0 ? 1 : rawPointsPerCurrency;

    return AppSettings(
      monthlyInstallmentRate:
          (m['monthly_installment_rate'] as num? ?? 3.0).toDouble(),
      installmentRatesByMonths: ratesMap,
      defaultAdminFeeRate:
          (m['default_admin_fee_rate'] as num? ?? 5.0).toDouble(),
      pointsPerCurrency: sanitizedPointsPerCurrency,
      pointsRedemptionRate:
          (m['points_redemption_rate'] as num? ?? 0.01).toDouble(),
      maxInstallmentMonths: (m['max_installment_months'] as int? ?? 24),
      pointCurrencyType: m['point_currency_type'] as String? ?? 'piasters',
    );
  }

  AppSettings copyWith({
    double? monthlyInstallmentRate,
    Map<int, double>? installmentRatesByMonths,
    double? defaultAdminFeeRate,
    int? pointsPerCurrency,
    double? pointsRedemptionRate,
    int? maxInstallmentMonths,
    String? pointCurrencyType,
  }) =>
      AppSettings(
        monthlyInstallmentRate:
            monthlyInstallmentRate ?? this.monthlyInstallmentRate,
        installmentRatesByMonths:
            installmentRatesByMonths ?? this.installmentRatesByMonths,
        defaultAdminFeeRate: defaultAdminFeeRate ?? this.defaultAdminFeeRate,
        pointsPerCurrency: pointsPerCurrency ?? this.pointsPerCurrency,
        pointsRedemptionRate:
            pointsRedemptionRate ?? this.pointsRedemptionRate,
        maxInstallmentMonths:
            maxInstallmentMonths ?? this.maxInstallmentMonths,
        pointCurrencyType: pointCurrencyType ?? this.pointCurrencyType,
      );
}
