import '../models/app_settings.dart';

class CurrencyService {
  static CurrencyService? _instance;
  static CurrencyService get instance {
    _instance ??= CurrencyService._();
    return _instance!;
  }
  CurrencyService._();

  AppSettings _settings = const AppSettings();

  AppSettings get settings => _settings;
  String get symbol => _settings.currencySymbol;
  String get code => _settings.currencyCode;

  void update(AppSettings settings) {
    _settings = settings;
  }

  String format(double amount) {
    final sym = _settings.currencySymbol;
    if (amount.abs() >= 1000000) {
      return '$sym${(amount / 1000000).toStringAsFixed(2)}M';
    }
    final str = amount.toStringAsFixed(2);
    final parts = str.split('.');
    final intPart = parts[0];
    final decPart = parts.length > 1 ? '.${parts[1]}' : '';
    final buf = StringBuffer();
    int count = 0;
    for (int i = intPart.length - 1; i >= 0; i--) {
      if (count > 0 && count % 3 == 0 && intPart[i] != '-') buf.write(',');
      buf.write(intPart[i]);
      count++;
    }
    final formatted = buf.toString().split('').reversed.join('');
    return '$sym$formatted$decPart';
  }

  String compact(double amount) {
    final sym = _settings.currencySymbol;
    if (amount >= 1000000) return '$sym${(amount / 1000000).toStringAsFixed(1)}M';
    if (amount >= 1000) return '$sym${(amount / 1000).toStringAsFixed(1)}k';
    return '$sym${amount.toStringAsFixed(2)}';
  }
}
