/// Regional pricing and country metadata. Mirrors `pro_prices` in the database;
/// the app stores are the source of truth for what is actually charged once
/// in-app purchase is live, this table is what the paywall displays.
class ProPrice {
  const ProPrice(this.country, this.currency, this.symbol, this.monthly, this.yearly);

  final String country;
  final String currency;
  final String symbol;
  final double monthly;
  final double yearly;

  String get monthlyLabel => '$symbol${_price(monthly)}';
  String get yearlyLabel => '$symbol${_price(yearly)}';

  /// Months of the monthly price the yearly plan saves, e.g. "Save 42%".
  int get yearlySavingPct => (100 - yearly / (monthly * 12) * 100).round();

  static String _price(double v) => v == v.roundToDouble() ? v.toInt().toString() : v.toStringAsFixed(2);
}

const proPrices = <String, ProPrice>{
  'US': ProPrice('US', 'USD', '\$', 9.99, 69.99),
  'IN': ProPrice('IN', 'INR', '₹', 499, 2999),
  'GB': ProPrice('GB', 'GBP', '£', 7.99, 59.99),
  'EU': ProPrice('EU', 'EUR', '€', 8.99, 64.99),
  'CA': ProPrice('CA', 'CAD', 'C\$', 12.99, 89.99),
  'AU': ProPrice('AU', 'AUD', 'A\$', 14.99, 99.99),
  'SG': ProPrice('SG', 'SGD', 'S\$', 12.99, 89.99),
  'AE': ProPrice('AE', 'AED', 'AED ', 36, 259),
};

const _euro = {'DE', 'FR', 'ES', 'IT', 'NL', 'BE', 'AT', 'PT', 'IE', 'FI', 'GR', 'LU'};

ProPrice proPriceFor(String country) {
  final c = country.toUpperCase();
  return proPrices[c] ?? (_euro.contains(c) ? proPrices['EU']! : proPrices['US']!);
}

/// Countries offered in the business profile. (code, name, currency)
const countries = <(String, String, String)>[
  ('US', 'United States', 'USD'),
  ('IN', 'India', 'INR'),
  ('GB', 'United Kingdom', 'GBP'),
  ('CA', 'Canada', 'CAD'),
  ('AU', 'Australia', 'AUD'),
  ('DE', 'Germany', 'EUR'),
  ('FR', 'France', 'EUR'),
  ('ES', 'Spain', 'EUR'),
  ('IT', 'Italy', 'EUR'),
  ('NL', 'Netherlands', 'EUR'),
  ('IE', 'Ireland', 'EUR'),
  ('SG', 'Singapore', 'SGD'),
  ('AE', 'United Arab Emirates', 'AED'),
  ('NZ', 'New Zealand', 'NZD'),
  ('JP', 'Japan', 'JPY'),
];

String countryName(String code) =>
    countries.where((c) => c.$1 == code.toUpperCase()).map((c) => c.$2).firstOrNull ?? code.toUpperCase();

String currencyForCountry(String code) =>
    countries.where((c) => c.$1 == code.toUpperCase()).map((c) => c.$3).firstOrNull ?? 'USD';

/// India → Razorpay (Stripe Connect is not offered there); everyone else → Stripe.
String providerFor(String country) => country.toUpperCase() == 'IN' ? 'razorpay' : 'stripe';

String providerLabel(String provider) => provider == 'razorpay' ? 'Razorpay' : 'Stripe';

/// Rails the client sees on the pay page.
String providerRails(String provider) =>
    provider == 'razorpay' ? 'UPI, cards, netbanking & wallets' : 'Cards, Apple Pay & Google Pay';

/// 100 bps → "1%", 150 → "1.5%".
String feePct(int bps) {
  final pct = bps / 100;
  return '${pct == pct.roundToDouble() ? pct.toInt() : pct}%';
}

/// Approximate processor fee, for the fee explainer only.
String processorFee(String provider) => provider == 'razorpay' ? '≈2% per transaction' : '≈2.9% + 30¢ per transaction';
