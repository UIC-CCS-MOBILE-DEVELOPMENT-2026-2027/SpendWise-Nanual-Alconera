import 'expense.dart';

const defaultAccounts = ['Cash on Hand', 'Bank', 'GCash'];

class Transfer {
  final String id;
  final String from;
  final String to;
  final double amount;
  final DateTime date;

  const Transfer({
    required this.id,
    required this.from,
    required this.to,
    required this.amount,
    required this.date,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'from': from,
    'to': to,
    'amount': amount,
    'date': date.toIso8601String(),
  };

  factory Transfer.fromJson(Map<String, dynamic> json) => Transfer(
    id: json['id'] as String,
    from: json['from'] as String,
    to: json['to'] as String,
    amount: (json['amount'] as num).toDouble(),
    date: DateTime.parse(json['date'] as String),
  );
}

class Wallet {
  final Map<String, double> openingBalances;
  final List<Transfer> transfers;

  Wallet({Map<String, double>? openingBalances, List<Transfer>? transfers})
    : openingBalances =
          openingBalances ?? {for (final name in defaultAccounts) name: 0},
      transfers = transfers ?? [];

  double balance(String account, List<Expense> expenses) =>
      (openingBalances[account] ?? 0) -
      expenses
          .where((e) => e.account == account)
          .fold<double>(0, (sum, e) => sum + e.amount) +
      transfers.fold<double>(
        0,
        (sum, t) =>
            sum +
            (t.to == account ? t.amount : 0) -
            (t.from == account ? t.amount : 0),
      );

  Map<String, dynamic> toJson() => {
    'openingBalances': openingBalances,
    'transfers': transfers.map((t) => t.toJson()).toList(),
  };

  factory Wallet.fromJson(Map<String, dynamic> json) => Wallet(
    openingBalances: (json['openingBalances'] as Map<String, dynamic>).map(
      (name, amount) => MapEntry(name, (amount as num).toDouble()),
    ),
    transfers: (json['transfers'] as List)
        .map((t) => Transfer.fromJson(Map<String, dynamic>.from(t as Map)))
        .toList(),
  );
}
