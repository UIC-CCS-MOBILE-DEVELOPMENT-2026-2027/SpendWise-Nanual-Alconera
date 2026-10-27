import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../domain/money.dart';
import '../models/expense.dart';
import '../models/wallet.dart';

class StorageReadException implements Exception {
  final String message;
  const StorageReadException(this.message);
  @override
  String toString() => message;
}

/// Related updates use a single snapshot. Legacy keys are retained for recovery.
/// This avoids split-key updates; preferences still have platform durability limits.
class ExpenseStorage {
  static const snapshotKey = 'spendwise_snapshot_v1';
  static const _keys = {
    'wallet': 'spendwise_wallet',
    'expenses': 'spendwise_expenses',
    'budgets': 'spendwise_category_budgets',
    'quest': 'spendwise_quest_progress',
    'streak': 'spendwise_streak_data',
    'shop': 'spendwise_shop_data',
    'badges': 'spendwise_badges',
    'challenges': 'spendwise_challenge_progress',
  };
  static Future<void>? _writes;
  final Future<bool> Function(String key, String value)? writer;
  ExpenseStorage({this.writer});

  static Map<String, dynamic> _empty() => {
    'schemaVersion': 1,
    'wallet': Wallet().toJson(),
    'expenses': <dynamic>[],
    'budgets': <String, dynamic>{},
    'monthlyBudgetCentavos': 0,
    'quest': {'xp': 0, 'coins': 0, 'completedQuests': <String>[]},
    'streak': {'currentStreak': 0, 'bestStreak': 0},
    'shop': {
      'selectedTheme': 'default',
      'unlockedThemes': ['default'],
    },
    'badges': <String>[],
    'challenges': <String, dynamic>{},
  };

  static void _check(bool condition, String message) {
    if (!condition) throw FormatException(message);
  }

  static List<String> _strings(dynamic value) {
    _check(
      value is List && value.every((e) => e is String),
      'Invalid collection.',
    );
    return List<String>.from(value as List);
  }

  /// Also used to validate a backup before a replacement can be confirmed.
  static Map<String, dynamic> validateBackup(String text) {
    final decoded = jsonDecode(text);
    _check(decoded is Map<String, dynamic>, 'Expected a SpendWise backup.');
    final data = Map<String, dynamic>.from(decoded as Map);
    _check(data['schemaVersion'] == 1, 'Unsupported backup version.');
    final wallet = Wallet.fromJson(
      Map<String, dynamic>.from(data['wallet'] as Map),
    );
    final names = <String>{};
    for (final entry in wallet.openingBalances.entries) {
      _check(
        entry.key.trim().isNotEmpty &&
            entry.key.length <= 40 &&
            names.add(entry.key.toLowerCase()),
        'Invalid or duplicate account name.',
      );
      _check(entry.value >= 0, 'Invalid opening balance.');
      Money.centavos(entry.value);
    }
    final ids = <String>{};
    final expenses = (data['expenses'] as List)
        .map((e) => Expense.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
    for (final expense in expenses) {
      _check(ids.add(expense.id), 'Duplicate expense ID.');
      _check(
        expense.description.length <= 80 && expense.account.length <= 40,
        'Invalid expense text.',
      );
    }
    ids.clear();
    for (final transfer in wallet.transfers) {
      _check(
        transfer.id.isNotEmpty &&
            ids.add(transfer.id) &&
            transfer.from.trim().isNotEmpty &&
            transfer.to.trim().isNotEmpty &&
            transfer.from != transfer.to,
        'Invalid transfer.',
      );
    }
    final budgets = Map<String, dynamic>.from(data['budgets'] as Map);
    for (final value in budgets.values) {
      _check(value is num && value > 0, 'Invalid category budget.');
      Money.centavos(value as num);
    }
    final monthly = data['monthlyBudgetCentavos'];
    _check(
      monthly is int && monthly >= 0 && monthly <= Money.maxCentavos,
      'Invalid monthly budget.',
    );
    final quest = data['quest'] as Map;
    for (final field in ['xp', 'coins']) {
      _check(quest[field] is int && quest[field] >= 0, 'Invalid rewards.');
    }
    _strings(quest['completedQuests']);
    _strings(data['badges']);
    final shop = data['shop'] as Map;
    _check(shop['selectedTheme'] is String, 'Invalid theme.');
    final themes = _strings(shop['unlockedThemes']);
    _check(
      themes.contains(shop['selectedTheme']),
      'Selected theme is not unlocked.',
    );
    for (final value in (data['challenges'] as Map).values) {
      _check(value is bool, 'Invalid challenge record.');
    }
    for (final field in ['currentStreak', 'bestStreak']) {
      final value = (data['streak'] as Map)[field];
      _check(value is int && value >= 0, 'Invalid streak.');
    }
    data['wallet'] = Wallet(
      openingBalances: wallet.openingBalances.map(
        (k, v) => MapEntry(k, Money.centavos(v) / 100),
      ),
      transfers: wallet.transfers,
    ).toJson();
    data['expenses'] = expenses.map((e) => e.toJson()).toList();
    data['budgets'] = budgets.map(
      (k, v) => MapEntry(k, Money.centavos(v as num) / 100),
    );
    return data;
  }

  Future<Map<String, dynamic>> loadSnapshot() async {
    final prefs = await SharedPreferences.getInstance();
    try {
      final saved = prefs.getString(snapshotKey);
      if (saved != null) return validateBackup(saved);
      final data = _empty();
      for (final entry in _keys.entries) {
        final raw = prefs.getString(entry.value);
        if (raw == null) continue;
        final decoded = jsonDecode(raw);
        // Older versions omitted optional reward fields.
        if (['quest', 'streak', 'shop'].contains(entry.key)) {
          data[entry.key] = {...data[entry.key] as Map, ...decoded as Map};
        } else {
          data[entry.key] = decoded;
        }
      }
      data['monthlyBudgetCentavos'] = Money.centavos(
        prefs.getDouble('spendwise_overall_monthly_budget') ?? 0,
      );
      return validateBackup(jsonEncode(data));
    } catch (_) {
      throw const StorageReadException(
        'Saved data could not be read. It has been preserved. Retry or restore a valid backup.',
      );
    }
  }

  Future<bool> _commit(
    Map<String, dynamic> Function(Map<String, dynamic>) change, {
    bool replacement = false,
  }) {
    Future<bool> apply() async {
      final current = replacement ? _empty() : await loadSnapshot();
      final next = validateBackup(jsonEncode(change(current)));
      final prefs = await SharedPreferences.getInstance();
      try {
        if (replacement) {
          final previous = await exportRecoveryData();
          if (!await prefs.setString('spendwise_before_restore', previous)) {
            return false;
          }
        }
        final saved =
            await (writer?.call(snapshotKey, jsonEncode(next)) ??
                prefs.setString(snapshotKey, jsonEncode(next)));
        if (!saved && writer == null) await prefs.reload();
        return saved;
      } catch (_) {
        if (writer == null) await prefs.reload();
        rethrow;
      }
    }

    final previous = _writes;
    final operation = previous == null
        ? apply()
        : previous.then((_) => apply());
    final settled = operation.then<void>(
      (_) {},
      onError: (Object _, StackTrace _) {},
    );
    _writes = settled;
    return () async {
      try {
        return await operation;
      } finally {
        await settled;
        if (identical(_writes, settled)) _writes = null;
      }
    }();
  }

  Future<bool> _patch(Map<String, dynamic> patch) =>
      _commit((current) => {...current, ...patch});
  Future<String> exportBackup() async =>
      const JsonEncoder.withIndent('  ').convert(await loadSnapshot());
  Future<bool> restoreBackup(String text) {
    final validated = validateBackup(text);
    return _commit((_) => validated, replacement: true);
  }

  Future<String> exportRecoveryData() async {
    final prefs = await SharedPreferences.getInstance();
    return const JsonEncoder.withIndent('  ').convert({
      'recoveryOnly': true,
      for (final key in [
        snapshotKey,
        ..._keys.values,
        'spendwise_overall_monthly_budget',
      ])
        key: prefs.get(key),
    });
  }

  Future<Wallet> loadWallet() async => Wallet.fromJson(
    Map<String, dynamic>.from((await loadSnapshot())['wallet'] as Map),
  );
  Future<List<Expense>> loadExpenses() async =>
      ((await loadSnapshot())['expenses'] as List)
          .map((e) => Expense.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList();
  Future<Map<String, double>> loadBudgets() async => Map<String, dynamic>.from(
    (await loadSnapshot())['budgets'] as Map,
  ).map((k, v) => MapEntry(k, (v as num).toDouble()));
  Future<double> loadMonthlyBudget() async =>
      ((await loadSnapshot())['monthlyBudgetCentavos'] as int) / 100;
  Future<Map<String, dynamic>> _map(String key) async =>
      Map<String, dynamic>.from((await loadSnapshot())[key] as Map);
  Future<Map<String, dynamic>> loadQuestProgress() => _map('quest');
  Future<Map<String, dynamic>> loadStreakData() => _map('streak');
  Future<Map<String, dynamic>> loadShopData() => _map('shop');
  Future<Map<String, dynamic>> loadChallengeProgress() => _map('challenges');
  Future<Set<String>> loadEarnedBadges() async =>
      _strings((await loadSnapshot())['badges']).toSet();

  Future<bool> saveWallet(Wallet wallet) => _patch({'wallet': wallet.toJson()});
  Future<bool> saveExpenses(List<Expense> expenses) =>
      _patch({'expenses': expenses.map((e) => e.toJson()).toList()});
  Future<bool> saveFinancialData({
    required Wallet wallet,
    required List<Expense> expenses,
  }) => _patch({
    'wallet': wallet.toJson(),
    'expenses': expenses.map((e) => e.toJson()).toList(),
  });
  Future<bool> saveBudgets(Map<String, double> budgets) =>
      _patch({'budgets': budgets});
  Future<bool> saveMonthlyBudget(double amount) =>
      _patch({'monthlyBudgetCentavos': Money.centavos(amount)});
  Future<bool> saveQuestProgress(Map<String, dynamic> progress) =>
      _patch({'quest': progress});
  Future<bool> saveStreakData(Map<String, dynamic> progress) =>
      _patch({'streak': progress});
  Future<bool> saveShopData(Map<String, dynamic> progress) =>
      _patch({'shop': progress});
  Future<bool> saveChallengeProgress(Map<String, dynamic> progress) =>
      _patch({'challenges': progress});
  Future<bool> saveEarnedBadges(Set<String> badges) =>
      _patch({'badges': badges.toList()});
  Future<bool> saveRewards({
    required Map<String, dynamic> quest,
    required Map<String, dynamic> challenges,
    required Set<String> badges,
    required Map<String, dynamic> streak,
  }) => _patch({
    'quest': quest,
    'challenges': challenges,
    'badges': badges.toList(),
    'streak': streak,
  });
  Future<bool> savePurchase({
    required Map<String, dynamic> quest,
    required Map<String, dynamic> shop,
  }) => _patch({'quest': quest, 'shop': shop});
}
