/// PHP amounts are calculated in integer centavos, never by adding doubles.
class Money {
  static const maxCentavos = 100000000000;

  static int centavos(num amount) {
    if (!amount.isFinite || amount.abs() > 90071992547409) {
      throw const FormatException('Invalid money amount.');
    }
    return (amount * 100).round();
  }

  static int? parse(String input, {bool allowZero = false}) {
    final text = input.trim();
    if (!RegExp(r'^\d+(\.\d{1,2})?$').hasMatch(text)) return null;
    final parts = text.split('.');
    final whole = int.tryParse(parts.first);
    if (whole == null || whole > maxCentavos ~/ 100) return null;
    final fraction = parts.length == 2
        ? int.parse(parts[1].padRight(2, '0'))
        : 0;
    final result = whole * 100 + fraction;
    if (result > maxCentavos || result < (allowZero ? 0 : 1)) return null;
    return result;
  }

  static double sum(Iterable<double> amounts) =>
      amounts.fold<int>(0, (sum, amount) => sum + centavos(amount)) / 100;

  static int read(Map<String, dynamic> json, {bool allowZero = false}) {
    final value = json['amountCentavos'];
    final int result;
    if (value != null) {
      if (value is! int) throw const FormatException('Invalid centavos.');
      result = value;
    } else {
      final legacy = json['amount'];
      if (legacy is! num) throw const FormatException('Missing amount.');
      result = centavos(legacy);
    }
    if (result < (allowZero ? 0 : 1) || result > maxCentavos) {
      throw const FormatException('Amount is outside the supported range.');
    }
    return result;
  }
}

DateTime calendarDate(DateTime value) =>
    DateTime(value.year, value.month, value.day);
String dayKey(DateTime value) =>
    '${value.year.toString().padLeft(4, '0')}-${value.month.toString().padLeft(2, '0')}-${value.day.toString().padLeft(2, '0')}';
String weekKey(DateTime value) =>
    dayKey(DateTime(value.year, value.month, value.day - value.weekday + 1));
