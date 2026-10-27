import 'expense.dart';
import '../domain/money.dart';

const defaultAccounts = ['Cash on Hand', 'Bank', 'E-Wallet'];

class Transfer {
  final String id;
  final String from;
  final String to;
  final int amountCentavos;
  double get amount => amountCentavos / 100;
  final DateTime date;

  Transfer({
    required this.id,
    required this.from,
    required this.to,
    required double amount,
    required this.date,
  }) : amountCentavos = Money.centavos(amount);

  Map<String, dynamic> toJson() => {
    'id': id,
    'from': from,
    'to': to,
    'amountCentavos': amountCentavos,
    'date': date.toIso8601String(),
  };

  factory Transfer.fromJson(Map<String, dynamic> json) => Transfer(
    id: json['id'] as String,
    from: json['from'] as String,
    to: json['to'] as String,
    amount: Money.read(json) / 100,
    date: DateTime.parse(json['date'] as String),
  );
}

class Wallet {
  final Map<String, double> openingBalances;
  final List<Transfer> transfers;

  Wallet({Map<String, double>? openingBalances, List<Transfer>? transfers})
    : openingBalances = Map.unmodifiable(
        openingBalances ?? {for (final name in defaultAccounts) name: 0.0},
      ),
      transfers = List.unmodifiable(transfers ?? []);

  double balance(String account, List<Expense> expenses) =>
      (Money.centavos(openingBalances[account] ?? 0) -
          expenses
              .where((e) => e.account == account)
              .fold<int>(0, (sum, e) => sum + e.amountCentavos) +
          transfers.fold<int>(
            0,
            (sum, t) =>
                sum +
                (t.to == account ? t.amountCentavos : 0) -
                (t.from == account ? t.amountCentavos : 0),
          )) /
      100;

  Map<String, dynamic> toJson() => {
    'openingBalanceCentavos': openingBalances.map(
      (name, amount) => MapEntry(name, Money.centavos(amount)),
    ),
    'transfers': transfers.map((t) => t.toJson()).toList(),
  };

  factory Wallet.fromJson(Map<String, dynamic> json) => Wallet(
    openingBalances: json.containsKey('openingBalanceCentavos')
        ? (json['openingBalanceCentavos'] as Map<String, dynamic>).map((
            name,
            amount,
          ) {
            if (amount is! int || amount < 0 || amount > Money.maxCentavos) {
              throw const FormatException('Invalid opening balance.');
            }
            return MapEntry(name, amount / 100);
          })
        : (json['openingBalances'] as Map<String, dynamic>).map(
            (name, amount) => MapEntry(name, (amount as num).toDouble()),
          ),
    transfers: (json['transfers'] as List)
        .map((t) => Transfer.fromJson(Map<String, dynamic>.from(t as Map)))
        .toList(),
  );
}
