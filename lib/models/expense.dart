import '../domain/money.dart';

class Expense {
  final String id;
  final String description;
  final int amountCentavos;
  double get amount => amountCentavos / 100;
  final String category;
  final DateTime date;
  final String account;

  Expense({
    required this.id,
    required this.description,
    required double amount,
    required this.category,
    required this.date,
    this.account = 'Cash on Hand',
  }) : amountCentavos = Money.centavos(amount);

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'description': description,
      'amountCentavos': amountCentavos,
      'category': category,
      'account': account,
      'date': date.toIso8601String(),
    };
  }

  factory Expense.fromJson(Map<String, dynamic> json) {
    for (final key in ['id', 'description', 'category']) {
      if (json[key] is! String || (json[key] as String).trim().isEmpty) {
        throw FormatException('Invalid expense $key.');
      }
    }
    if (json['account'] != null &&
        (json['account'] is! String ||
            (json['account'] as String).trim().isEmpty)) {
      throw const FormatException('Invalid expense account.');
    }
    return Expense(
      id: json['id'] as String,
      description: json['description'] as String,
      amount: Money.read(json) / 100,
      category: json['category'] as String,
      account: json['account'] as String? ?? 'Cash on Hand',
      date: DateTime.parse(json['date'] as String),
    );
  }

  Expense copyWith({
    String? description,
    double? amount,
    String? category,
    DateTime? date,
    String? account,
  }) {
    return Expense(
      id: id,
      description: description ?? this.description,
      amount: amount ?? this.amount,
      category: category ?? this.category,
      date: date ?? this.date,
      account: account ?? this.account,
    );
  }
}
