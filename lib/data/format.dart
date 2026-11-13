const _months = [
  'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
  'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
];
const _weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

/// ISO code of the business's currency. The store sets it when the business loads;
/// every amount in the app is formatted with it.
String currencyCode = 'USD';

const _symbols = {
  'USD': '\$', 'INR': '₹', 'GBP': '£', 'EUR': '€', 'CAD': 'C\$', 'AUD': 'A\$', 'SGD': 'S\$',
  'NZD': 'NZ\$', 'JPY': '¥', 'AED': 'AED ', 'CHF': 'CHF ', 'ZAR': 'R',
};
const _zeroDecimal = {'JPY', 'KRW', 'VND', 'CLP'};

String symbolFor(String code) => _symbols[code.toUpperCase()] ?? '${code.toUpperCase()} ';

/// `$1,240.00` — or `$1,240` with [cents] false — in the business's currency
/// (`₹1,240.00` for INR). Negatives use a true minus.
String money(double value, {bool cents = true, String? currency}) {
  final code = (currency ?? currencyCode).toUpperCase();
  final symbol = symbolFor(code);
  final showCents = cents && !_zeroDecimal.contains(code);
  final negative = value < 0;
  final v = value.abs();
  final whole = showCents ? v.floor() : v.round();
  final frac = ((v - v.floor()) * 100).round();
  final digits = whole.toString();
  final buf = StringBuffer();
  for (var i = 0; i < digits.length; i++) {
    final remaining = digits.length - i;
    buf.write(digits[i]);
    if (remaining > 1 && remaining % 3 == 1) buf.write(',');
  }
  final out = showCents ? '$symbol$buf.${frac.toString().padLeft(2, '0')}' : '$symbol$buf';
  return negative ? '−$out' : out;
}

String fmtDate(DateTime d, {bool year = false}) =>
    '${_months[d.month - 1]} ${d.day}${year ? ', ${d.year}' : ''}';

String fmtWeekday(DateTime d) => '${_weekdays[d.weekday - 1]} · ${fmtDate(d)}';

String fmtMonth(DateTime d) => _months[d.month - 1];

String fmtTime(DateTime d) {
  final h = d.hour % 12 == 0 ? 12 : d.hour % 12;
  final m = d.minute.toString().padLeft(2, '0');
  return '$h:$m ${d.hour < 12 ? 'AM' : 'PM'}';
}

String plural(int n, String one, [String? many]) =>
    '$n ${n == 1 ? one : (many ?? '${one}s')}';
