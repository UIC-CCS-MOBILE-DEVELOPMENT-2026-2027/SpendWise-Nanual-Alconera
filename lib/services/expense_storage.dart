import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/expense.dart';

class ExpenseStorage {
  static const String _storageKey = 'spendwise_expenses';
  static const String _budgetStorageKey = 'spendwise_category_budgets';
  static const String _monthlyBudgetStorageKey =
      'spendwise_overall_monthly_budget';
  static const String _questStorageKey = 'spendwise_quest_progress';

  Future<List<Expense>> loadExpenses() async {
    final prefs = await SharedPreferences.getInstance();
    final storedData = prefs.getString(_storageKey);

    if (storedData == null || storedData.isEmpty) {
      return [];
    }

    try {
      final List<dynamic> decoded = jsonDecode(storedData) as List<dynamic>;

      return decoded
          .map(
            (item) => Expense.fromJson(Map<String, dynamic>.from(item as Map)),
          )
          .toList();
    } catch (_) {
      return [];
    }
  }

  Future<bool> saveExpenses(List<Expense> expenses) async {
    final prefs = await SharedPreferences.getInstance();

    final encodedData = jsonEncode(
      expenses.map((expense) => expense.toJson()).toList(),
    );

    return prefs.setString(_storageKey, encodedData);
  }

  Future<Map<String, double>> loadBudgets() async {
    final prefs = await SharedPreferences.getInstance();
    final storedData = prefs.getString(_budgetStorageKey);

    if (storedData == null || storedData.isEmpty) {
      return {};
    }

    try {
      final Map<String, dynamic> decoded =
          jsonDecode(storedData) as Map<String, dynamic>;

      return decoded.map(
        (category, amount) => MapEntry(category, (amount as num).toDouble()),
      );
    } catch (_) {
      return {};
    }
  }

  Future<bool> saveBudgets(Map<String, double> budgets) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.setString(_budgetStorageKey, jsonEncode(budgets));
  }

  // The overall budget persists when the calendar month changes.
  // Only the spending total resets because it is calculated from dated expenses.
  Future<double> loadMonthlyBudget() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getDouble(_monthlyBudgetStorageKey) ?? 10000.0;
  }

  Future<bool> saveMonthlyBudget(double amount) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.setDouble(_monthlyBudgetStorageKey, amount);
  }

  Future<Map<String, dynamic>> loadQuestProgress() async {
    final prefs = await SharedPreferences.getInstance();
    final storedData = prefs.getString(_questStorageKey);

    if (storedData == null || storedData.isEmpty) {
      return {};
    }

    try {
      final decoded = jsonDecode(storedData);
      if (decoded is Map<String, dynamic>) {
        return decoded;
      }
    } catch (_) {
      // Invalid quest data starts with fresh progress.
    }

    return {};
  }

  Future<bool> saveQuestProgress(Map<String, dynamic> progress) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.setString(_questStorageKey, jsonEncode(progress));
  }
}
