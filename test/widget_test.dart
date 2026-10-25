import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:spendwise/main.dart';
import 'package:spendwise/models/expense.dart';
import 'package:spendwise/models/wallet.dart';
import 'package:spendwise/services/expense_storage.dart';
import 'package:spendwise/wallet_panel.dart';

void main() {
  final date = DateTime(2026, 10, 25);

  Expense expense(String account) => Expense(
    id: '1',
    description: 'Lunch',
    amount: 100,
    category: 'Food & Dining',
    date: date,
    account: account,
  );

  test('Old expenses migrate to cash and preserve their category', () {
    final json = expense('Bank').toJson()..remove('account');
    final migrated = Expense.fromJson(json);

    expect(migrated.account, 'Cash on Hand');
    expect(migrated.category, 'Food & Dining');

    expect(
      Expense.fromJson(migrated.copyWith(account: 'GCash').toJson()).account,
      'GCash',
    );
  });

  test(
    'Withdrawal conserves total money; expenses deduct from the selected account',
    () {
      final wallet = Wallet(
        openingBalances: {'Bank': 1000, 'Cash on Hand': 0},
        transfers: [
          Transfer(
            id: 't',
            from: 'Bank',
            to: 'Cash on Hand',
            amount: 300,
            date: date,
          ),
        ],
      );

      expect(wallet.balance('Bank', []), 700);
      expect(wallet.balance('Cash on Hand', []), 300);

      final expenses = [expense('Cash on Hand')];

      expect(wallet.balance('Cash on Hand', expenses), 200);

      expect(
        wallet.balance('Bank', expenses) +
            wallet.balance('Cash on Hand', expenses),
        900,
      );

      expenses[0] = expenses[0].copyWith(account: 'Bank');

      expect(wallet.balance('Bank', expenses), 600);
      expect(wallet.balance('Cash on Hand', expenses), 300);

      expenses.clear();

      expect(wallet.balance('Bank', expenses), 700);
    },
  );

  test('Accounts, transfers and payment accounts survive reload', () async {
    SharedPreferences.setMockInitialValues({});

    final storage = ExpenseStorage();

    final wallet = Wallet(
      openingBalances: {'Bank': 500, 'Maya': 0},
      transfers: [
        Transfer(id: 't', from: 'Bank', to: 'Maya', amount: 200, date: date),
      ],
    );

    expect(await storage.saveWallet(wallet), isTrue);
    expect(await storage.saveExpenses([expense('Maya')]), isTrue);

    final loaded = await storage.loadWallet();

    expect(loaded.balance('Maya', await storage.loadExpenses()), 100);
    expect(loaded.transfers.single.date, date);
  });

  testWidgets('Expense form offers payment accounts separately from category', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: ExpenseForm(
            accounts: ['Cash on Hand', 'Bank', 'GCash', 'Maya'],
          ),
        ),
      ),
    );

    await tester.enterText(find.byType(TextFormField).at(0), 'Lunch');
    await tester.enterText(find.byType(TextFormField).at(1), '100');

    await tester.ensureVisible(find.text('Paid from'));
    await tester.tap(find.text('Cash on Hand'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Maya').last);
    await tester.pumpAndSettle();

    expect(find.text('Maya'), findsOneWidget);
    expect(find.text('Food & Dining'), findsOneWidget);

    final exception = tester.takeException();

    if (exception != null) {
      debugPrint(exception.toString());

      if (exception is FlutterError) {
        debugPrint(exception.diagnostics.map((d) => d.toString()).join('\n'));
      }
    }

    expect(exception, isNull);
  });

  testWidgets('Monthly budget saves on a small phone with the keyboard open', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});

    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1;

    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetViewInsets);

    await tester.pumpWidget(const SpendWiseApp());
    await tester.pumpAndSettle();

    await tester.tap(find.text('Budget'));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Edit overall budget'));
    await tester.pumpAndSettle();

    final budgetField = find.byType(TextFormField);

    expect(budgetField, findsOneWidget);

    await tester.tap(budgetField);
    await tester.enterText(budgetField, '15000');

    tester.view.viewInsets = const FakeViewPadding(bottom: 300);
    await tester.pumpAndSettle();

    final exception = tester.takeException();

    if (exception != null) {
      debugPrint('=== LAYOUT ERROR DETAILS ===');
      debugPrint(exception.toString());

      if (exception is FlutterError) {
        for (final diagnostic in exception.diagnostics) {
          debugPrint(diagnostic.toString());
        }
      }

      debugPrint('=== WIDGET TREE AROUND DIALOG ===');
      debugDumpApp();
      debugDumpRenderTree();
    }

    expect(exception, isNull);

    await tester.tap(find.text('Save budget'));
    await tester.pumpAndSettle();

    expect(await ExpenseStorage().loadMonthlyBudget(), 15000);

    await tester.ensureVisible(find.text('Awesome!'));
    await tester.tap(find.text('Awesome!'));
    await tester.pumpAndSettle();

    expect(find.text('Awesome!'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Expense can be saved and persisted from a phone form', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});

    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1;

    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetViewInsets);

    await tester.pumpWidget(const SpendWiseApp());
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(FloatingActionButton, 'Add expense'));
    await tester.pumpAndSettle();

    tester.view.viewInsets = const FakeViewPadding(bottom: 300);
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextFormField).at(0), 'Lunch');
    await tester.enterText(find.byType(TextFormField).at(1), '100');

    await tester.ensureVisible(find.text('Save expense'));
    await tester.tap(find.text('Save expense'));
    await tester.pumpAndSettle();

    expect((await ExpenseStorage().loadExpenses()).single.description, 'Lunch');

    await tester.ensureVisible(find.text('Awesome!'));
    await tester.tap(find.text('Awesome!'));
    await tester.pumpAndSettle();

    expect(find.text('Awesome!'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'Custom accounts and transfers can be saved from the dashboard panel',
    (tester) async {
      var wallet = Wallet(
        openingBalances: {'Cash on Hand': 0, 'Bank': 1000, 'GCash': 0},
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StatefulBuilder(
              builder: (context, setState) => SingleChildScrollView(
                child: WalletPanel(
                  wallet: wallet,
                  expenses: const [],
                  primaryColor: const Color(0xFF7958FF),
                  onSave: (updated) async {
                    setState(() => wallet = updated);
                    return true;
                  },
                ),
              ),
            ),
          ),
        ),
      );

      // Add a custom account.
      await tester.tap(find.text('Add account'));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextFormField).at(0), 'Maya');
      await tester.enterText(find.byType(TextFormField).at(1), '200');

      await tester.tap(find.text('Save account'));
      await tester.pumpAndSettle();

      expect(wallet.openingBalances['Maya'], 200);

      // Open the transfer dialog.
      await tester.ensureVisible(find.text('Transfer / withdraw'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Transfer / withdraw'));
      await tester.pumpAndSettle();

      // Select Bank as the source account.
      final dropdowns = find.byType(DropdownButtonFormField<String>);

      await tester.tap(dropdowns.at(0));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Bank').last);
      await tester.pumpAndSettle();

      // Select Maya as the destination account.
      await tester.tap(dropdowns.at(1));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Maya').last);
      await tester.pumpAndSettle();

      final amountField = find.byType(TextFormField);

      // An amount greater than Bank's balance must be rejected.
      await tester.enterText(amountField, '1100');
      await tester.tap(find.text('Confirm transfer'));
      await tester.pumpAndSettle();

      expect(find.text('Insufficient funds in this account.'), findsOneWidget);
      expect(wallet.transfers, isEmpty);

      // A valid transfer of 300 should succeed.
      await tester.enterText(amountField, '300');
      await tester.tap(find.text('Confirm transfer'));
      await tester.pumpAndSettle();

      expect(wallet.transfers, hasLength(1));
      expect(wallet.transfers.single.from, 'Bank');
      expect(wallet.transfers.single.to, 'Maya');
      expect(wallet.transfers.single.amount, 300);

      expect(wallet.balance('Bank', []), 700);
      expect(wallet.balance('Maya', []), 500);

      // Print detailed diagnostics if a layout exception occurred.
      final exception = tester.takeException();

      if (exception != null) {
        debugPrint('===== TRANSFER TEST LAYOUT ERROR =====');
        debugPrint(exception.toString());

        if (exception is FlutterError) {
          for (final diagnostic in exception.diagnostics) {
            debugPrint(diagnostic.toString());
          }
        }

        debugPrint('===== WIDGET TREE =====');
        debugDumpApp();
        debugDumpRenderTree();
      }

      expect(exception, isNull);
    },
  );
}
