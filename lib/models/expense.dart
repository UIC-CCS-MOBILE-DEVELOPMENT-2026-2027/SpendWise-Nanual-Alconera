class Expense {
  final String id;
  final String description;
  final double amount;
  final String category;
  final DateTime date;
  final String account;

  const Expense({
    required this.id,
    required this.description,
    required this.amount,
    required this.category,
    required this.date,
    this.account = 'Cash on Hand',
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'description': description,
      'amount': amount,
      'category': category,
      'account': account,
      'date': date.toIso8601String(),
    };
  }

  factory Expense.fromJson(Map<String, dynamic> json) {
    return Expense(
      id: json['id'] as String,
      description: json['description'] as String,
      amount: (json['amount'] as num).toDouble(),
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
