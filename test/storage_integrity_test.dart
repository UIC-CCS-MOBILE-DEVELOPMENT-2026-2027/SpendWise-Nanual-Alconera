import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:spendwise/domain/money.dart';
import 'package:spendwise/models/expense.dart';
import 'package:spendwise/models/wallet.dart';
import 'package:spendwise/services/expense_storage.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));
  Expense expense({String account = 'Bank'}) => Expense(
    id: 'e1',
    description: 'Lunch',
    amount: 12.34,
    category: 'Food & Dining',
    account: account,
    date: DateTime(2026, 10, 27),
  );

  test(
    'legacy financial and reward data migrate without deleting originals',
    () async {
      final legacy = jsonEncode([
        {
          'id': 'old',
          'description': 'Lunch',
          'amount': 12.345,
          'category': 'Food & Dining',
          'date': '2026-10-25T00:00:00.000',
        },
      ]);
      SharedPreferences.setMockInitialValues({
        'spendwise_expenses': legacy,
        'spendwise_overall_monthly_budget': 10000.0,
        'spendwise_quest_progress':
            '{"xp":50,"coins":25,"completedQuests":["first_expense"]}',
      });
      final storage = ExpenseStorage();
      expect((await storage.loadExpenses()).single.amountCentavos, 1235);
      expect(await storage.loadMonthlyBudget(), 10000);
      expect((await storage.loadQuestProgress())['coins'], 25);
      expect(await storage.saveBudgets({'Food & Dining': 100}), true);
      expect(
        (await SharedPreferences.getInstance()).getString('spendwise_expenses'),
        legacy,
      );
      expect((await storage.loadExpenses()).single.account, 'Cash on Hand');
    },
  );

  test(
    'one malformed record blocks loading and overwriting original history',
    () async {
      const bad = '[{"id":"broken"}]';
      SharedPreferences.setMockInitialValues({'spendwise_expenses': bad});
      final storage = ExpenseStorage();
      await expectLater(
        storage.loadExpenses(),
        throwsA(isA<StorageReadException>()),
      );
      await expectLater(
        storage.saveExpenses([expense()]),
        throwsA(isA<StorageReadException>()),
      );
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('spendwise_expenses'), bad);
      expect(prefs.getString(ExpenseStorage.snapshotKey), isNull);
    },
  );

  test(
    'corrupt current snapshot does not silently revert to stale legacy data',
    () async {
      SharedPreferences.setMockInitialValues({
        ExpenseStorage.snapshotKey: '{broken',
        'spendwise_expenses': '[]',
      });
      await expectLater(
        ExpenseStorage().loadSnapshot(),
        throwsA(isA<StorageReadException>()),
      );
      expect(
        jsonDecode(await ExpenseStorage().exportRecoveryData())['recoveryOnly'],
        true,
      );
    },
  );

  test(
    'account rename persists wallet and expense references in one write',
    () async {
      final prefs = await SharedPreferences.getInstance();
      var writes = 0;
      final storage = ExpenseStorage(
        writer: (key, value) async {
          writes++;
          return prefs.setString(key, value);
        },
      );
      await storage.saveFinancialData(
        wallet: Wallet(openingBalances: {'Savings': 100}),
        expenses: [expense(account: 'Savings')],
      );
      expect(writes, 1);
      expect(
        (await storage.loadWallet()).balance(
          'Savings',
          await storage.loadExpenses(),
        ),
        87.66,
      );
    },
  );

  test('failed grouped update leaves previous financial data intact', () async {
    final storage = ExpenseStorage();
    await storage.saveFinancialData(
      wallet: Wallet(openingBalances: {'Bank': 100}),
      expenses: [expense()],
    );
    final before = await storage.exportBackup();
    final failing = ExpenseStorage(writer: (_, _) async => false);
    expect(
      await failing.saveFinancialData(
        wallet: Wallet(openingBalances: {'Renamed': 100}),
        expenses: [expense(account: 'Renamed')],
      ),
      false,
    );
    expect(await storage.exportBackup(), before);
  });

  test(
    'concurrent updates to separate sections are serialized without data loss',
    () async {
      await Future.wait([
        ExpenseStorage().saveWallet(Wallet(openingBalances: {'Bank': 300})),
        ExpenseStorage().saveExpenses([expense()]),
        ExpenseStorage().saveMonthlyBudget(10000),
      ]);
      final storage = ExpenseStorage();
      expect((await storage.loadExpenses()).length, 1);
      expect((await storage.loadWallet()).openingBalances['Bank'], 300);
      expect(await storage.loadMonthlyBudget(), 10000);
    },
  );

  test('queue remains usable after a thrown write', () async {
    final failing = ExpenseStorage(
      writer: (_, _) async => throw StateError('Disk unavailable'),
    );
    await expectLater(failing.saveMonthlyBudget(50), throwsStateError);
    expect(await ExpenseStorage().saveMonthlyBudget(100), true);
    expect(await ExpenseStorage().loadMonthlyBudget(), 100);
  });

  test('reward markers and currency save together or not at all', () async {
    final storage = ExpenseStorage();
    await storage.saveQuestProgress({
      'xp': 5,
      'coins': 2,
      'completedQuests': <String>[],
    });
    final before = await storage.exportBackup();
    expect(
      await ExpenseStorage(writer: (_, _) async => false).saveRewards(
        quest: {
          'xp': 25,
          'coins': 12,
          'completedQuests': ['first_expense'],
        },
        challenges: {'daily_tracker_2026-10-27': true},
        badges: {'first_steps'},
        streak: {'currentStreak': 1, 'bestStreak': 1},
      ),
      false,
    );
    expect(await storage.exportBackup(), before);
    await storage.saveRewards(
      quest: {
        'xp': 25,
        'coins': 12,
        'completedQuests': ['first_expense'],
      },
      challenges: {'daily_tracker_2026-10-27': true},
      badges: {'first_steps'},
      streak: {'currentStreak': 1, 'bestStreak': 1},
    );
    expect((await storage.loadQuestProgress())['coins'], 12);
    expect(
      (await storage.loadChallengeProgress())['daily_tracker_2026-10-27'],
      true,
    );
    expect(await storage.loadEarnedBadges(), {'first_steps'});
  });

  test('invalid backup cannot replace saved data', () async {
    final storage = ExpenseStorage();
    await storage.saveMonthlyBudget(75);
    expect(
      () => storage.restoreBackup('{"schemaVersion":99}'),
      throwsFormatException,
    );
    expect(await storage.loadMonthlyBudget(), 75);
  });

  test(
    'backup round trip restores all sections and retains recovery copy',
    () async {
      final storage = ExpenseStorage();
      await storage.saveExpenses([expense()]);
      final backup = await storage.exportBackup();
      await storage.saveExpenses([]);
      expect(await storage.restoreBackup(backup), true);
      expect((await storage.loadExpenses()).single.description, 'Lunch');
      expect(
        (await SharedPreferences.getInstance()).getString(
          'spendwise_before_restore',
        ),
        isNotNull,
      );
    },
  );

  test('valid backup can recover an unreadable snapshot', () async {
    final backup = await ExpenseStorage().exportBackup();
    SharedPreferences.setMockInitialValues({
      ExpenseStorage.snapshotKey: 'corrupt',
    });
    expect(await ExpenseStorage().restoreBackup(backup), true);
    expect(await ExpenseStorage().loadExpenses(), isEmpty);
    expect(
      (await SharedPreferences.getInstance()).getString(
        'spendwise_before_restore',
      ),
      contains('corrupt'),
    );
  });

  test('money parsing rejects hidden fractions and scientific notation', () {
    expect(Money.parse('0.001'), isNull);
    expect(Money.parse('1e3'), isNull);
    expect(Money.parse('NaN'), isNull);
    expect(Money.parse('-1'), isNull);
    expect(Money.parse('0'), isNull);
    expect(Money.parse('0', allowZero: true), 0);
    expect(Money.parse('12.3'), 1230);
    expect(Money.parse(' 12.34 '), 1234);
    expect(Money.parse('1000000000.01'), isNull);
  });

  test(
    'centavo arithmetic stays exact at transfer and zero-balance boundaries',
    () {
      final wallet = Wallet(
        openingBalances: {'Bank': 0.3, 'Cash': 0},
        transfers: [
          Transfer(
            id: 't',
            from: 'Bank',
            to: 'Cash',
            amount: 0.1,
            date: DateTime(2026),
          ),
        ],
      );
      expect(wallet.balance('Bank', []), 0.2);
      expect(Money.sum([0.1, 0.2]), 0.3);
      expect(() => wallet.openingBalances['Bank'] = 0, throwsUnsupportedError);
      expect(() => wallet.transfers.clear(), throwsUnsupportedError);
    },
  );
}
