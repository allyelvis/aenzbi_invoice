class AppSettings {
  final String currencyCode;
  final String currencySymbol;
  final String currencyName;
  final String companyName;
  final String companyAddress;
  final String companyEmail;
  final String companyPhone;
  final String invoicePrefix;
  final String poPrefix;
  final double defaultTaxRate;

  const AppSettings({
    this.currencyCode = 'USD',
    this.currencySymbol = '\$',
    this.currencyName = 'US Dollar',
    this.companyName = '',
    this.companyAddress = '',
    this.companyEmail = '',
    this.companyPhone = '',
    this.invoicePrefix = 'INV',
    this.poPrefix = 'PO',
    this.defaultTaxRate = 0.0,
  });

  AppSettings copyWith({
    String? currencyCode,
    String? currencySymbol,
    String? currencyName,
    String? companyName,
    String? companyAddress,
    String? companyEmail,
    String? companyPhone,
    String? invoicePrefix,
    String? poPrefix,
    double? defaultTaxRate,
  }) =>
      AppSettings(
        currencyCode: currencyCode ?? this.currencyCode,
        currencySymbol: currencySymbol ?? this.currencySymbol,
        currencyName: currencyName ?? this.currencyName,
        companyName: companyName ?? this.companyName,
        companyAddress: companyAddress ?? this.companyAddress,
        companyEmail: companyEmail ?? this.companyEmail,
        companyPhone: companyPhone ?? this.companyPhone,
        invoicePrefix: invoicePrefix ?? this.invoicePrefix,
        poPrefix: poPrefix ?? this.poPrefix,
        defaultTaxRate: defaultTaxRate ?? this.defaultTaxRate,
      );

  Map<String, String> toSettingsMap() => {
        'currencyCode': currencyCode,
        'currencySymbol': currencySymbol,
        'currencyName': currencyName,
        'companyName': companyName,
        'companyAddress': companyAddress,
        'companyEmail': companyEmail,
        'companyPhone': companyPhone,
        'invoicePrefix': invoicePrefix,
        'poPrefix': poPrefix,
        'defaultTaxRate': defaultTaxRate.toString(),
      };

  static AppSettings fromSettingsMap(Map<String, String> m) => AppSettings(
        currencyCode: m['currencyCode'] ?? 'USD',
        currencySymbol: m['currencySymbol'] ?? '\$',
        currencyName: m['currencyName'] ?? 'US Dollar',
        companyName: m['companyName'] ?? '',
        companyAddress: m['companyAddress'] ?? '',
        companyEmail: m['companyEmail'] ?? '',
        companyPhone: m['companyPhone'] ?? '',
        invoicePrefix: m['invoicePrefix'] ?? 'INV',
        poPrefix: m['poPrefix'] ?? 'PO',
        defaultTaxRate: double.tryParse(m['defaultTaxRate'] ?? '0') ?? 0.0,
      );

  // Supported currencies
  static const List<Map<String, String>> currencies = [
    {'code': 'USD', 'symbol': '\$', 'name': 'US Dollar'},
    {'code': 'EUR', 'symbol': '€', 'name': 'Euro'},
    {'code': 'GBP', 'symbol': '£', 'name': 'British Pound'},
    {'code': 'JPY', 'symbol': '¥', 'name': 'Japanese Yen'},
    {'code': 'CAD', 'symbol': 'CA\$', 'name': 'Canadian Dollar'},
    {'code': 'AUD', 'symbol': 'A\$', 'name': 'Australian Dollar'},
    {'code': 'CHF', 'symbol': 'CHF', 'name': 'Swiss Franc'},
    {'code': 'CNY', 'symbol': '¥', 'name': 'Chinese Yuan'},
    {'code': 'BIF', 'symbol': 'Fr', 'name': 'Burundian Franc'},
    {'code': 'KES', 'symbol': 'KSh', 'name': 'Kenyan Shilling'},
    {'code': 'NGN', 'symbol': '₦', 'name': 'Nigerian Naira'},
    {'code': 'ZAR', 'symbol': 'R', 'name': 'South African Rand'},
    {'code': 'GHS', 'symbol': '₵', 'name': 'Ghanaian Cedi'},
    {'code': 'EGP', 'symbol': '£', 'name': 'Egyptian Pound'},
    {'code': 'MAD', 'symbol': 'MAD', 'name': 'Moroccan Dirham'},
    {'code': 'TZS', 'symbol': 'TSh', 'name': 'Tanzanian Shilling'},
    {'code': 'RWF', 'symbol': 'Fr', 'name': 'Rwandan Franc'},
    {'code': 'UGX', 'symbol': 'USh', 'name': 'Ugandan Shilling'},
    {'code': 'INR', 'symbol': '₹', 'name': 'Indian Rupee'},
    {'code': 'BRL', 'symbol': 'R\$', 'name': 'Brazilian Real'},
    {'code': 'MXN', 'symbol': 'MX\$', 'name': 'Mexican Peso'},
    {'code': 'AED', 'symbol': 'د.إ', 'name': 'UAE Dirham'},
    {'code': 'SAR', 'symbol': '﷼', 'name': 'Saudi Riyal'},
  ];
}
