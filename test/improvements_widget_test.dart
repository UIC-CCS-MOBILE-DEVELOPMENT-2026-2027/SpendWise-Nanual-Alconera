import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:spendwise/main.dart';
import 'package:spendwise/expense_history.dart';
import 'package:spendwise/models/expense.dart';
import 'package:spendwise/models/wallet.dart';
import 'package:spendwise/services/expense_storage.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('corrupt saved data opens recovery and disables expense entry', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({'spendwise_expenses': '[broken'});
    await tester.pumpWidget(const SpendWiseApp());
    await tester.pumpAndSettle();
    expect(
      find.textContaining('Your records have been preserved'),
      findsOneWidget,
    );
    expect(find.text('Add expense'), findsNothing);
    expect(find.text('Retry loading'), findsOneWidget);
    await tester.tap(find.text('Backup and recovery'));
    await tester.pumpAndSettle();
    expect(find.text('Copy recovery data'), findsOneWidget);
    expect(
      (await SharedPreferences.getInstance()).getString('spendwise_expenses'),
      '[broken',
    );
  });

  testWidgets(
    'empty wallet redirects expense entry to account setup without throwing',
    (tester) async {
      await ExpenseStorage().saveWallet(Wallet(openingBalances: {}));
      await tester.pumpWidget(const SpendWiseApp());
      await tester.pumpAndSettle();
      await tester.tap(
        find.widgetWithText(FloatingActionButton, 'Add expense'),
      );
      await tester.pumpAndSettle();
      expect(
        find.text('Create an account in My Accounts before adding an expense.'),
        findsOneWidget,
      );
      expect(find.byType(ExpenseForm), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('history search filters both displayed records and total', (
    tester,
  ) async {
    final now = DateTime.now();
    final expenses = [
      Expense(
        id: '1',
        description: 'Lunch',
        amount: 100,
        category: 'Food & Dining',
        account: 'Cash',
        date: now,
      ),
      Expense(
        id: '2',
        description: 'Bus fare',
        amount: 20,
        category: 'Transportation',
        account: 'Bank',
        date: now,
      ),
    ];
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ExpenseHistory(
            expenses: expenses,
            primaryColor: Colors.purple,
            onEdit: (_) {},
            onDelete: (_) {},
          ),
        ),
      ),
    );
    expect(find.text('₱120.00'), findsOneWidget);
    expect(find.text('Lunch'), findsOneWidget);
    await tester.enterText(find.byType(TextField), 'Bus');
    await tester.pumpAndSettle();
    expect(find.text('Lunch'), findsNothing);
    expect(find.text('Bus fare'), findsOneWidget);
    expect(find.text('1 of 2 expenses'), findsOneWidget);
    expect(find.text('₱20.00'), findsNWidgets(2));
    await tester.tap(find.text('Reset filters'));
    await tester.pumpAndSettle();
    expect(find.text('Lunch'), findsOneWidget);
  });

  testWidgets('failed expense save rolls back without a reward celebration', (
    tester,
  ) async {
    await tester.pumpWidget(
      SpendWiseApp(storage: ExpenseStorage(writer: (_, _) async => false)),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FloatingActionButton, 'Add expense'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField).at(0), 'Lunch');
    await tester.enterText(find.byType(TextFormField).at(1), '12.34');
    await tester.ensureVisible(find.text('Save expense'));
    await tester.tap(find.text('Save expense'));
    await tester.pumpAndSettle();
    expect(await ExpenseStorage().loadExpenses(), isEmpty);
    expect(find.text('Awesome!'), findsNothing);
    expect(find.text('Could not save expenses.'), findsOneWidget);
  });

  testWidgets('calendar shows recorded expenses for a selected day', (
    tester,
  ) async {
    final now = DateTime.now();
    await ExpenseStorage().saveExpenses([
      Expense(
        id: '1',
        description: 'Calendar lunch',
        amount: 45.67,
        category: 'Food & Dining',
        date: now,
      ),
    ]);
    await tester.pumpWidget(const SpendWiseApp());
    await tester.pumpAndSettle();
    await tester.tap(find.text('Calendar'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('Total: ₱45.67'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Total: ₱45.67'), findsOneWidget);
    expect(find.textContaining('Calendar lunch'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('backup restore rejects bad text without changing data', (
    tester,
  ) async {
    await tester.pumpWidget(const SpendWiseApp());
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Backup and restore').first);
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byType(TextField),
      jsonEncode({'schemaVersion': 99}),
    );
    await tester.tap(find.text('Review restore'));
    await tester.pumpAndSettle();
    expect(
      find.text(
        'This is not a valid SpendWise backup. No records were changed.',
      ),
      findsOneWidget,
    );
    expect(await ExpenseStorage().loadExpenses(), isEmpty);
  });
  testWidgets(
    'editing a monthly budget uses a placeholder and keeps an unchanged limit',
    (tester) async {
      final storage = ExpenseStorage();
      await storage.saveMonthlyBudget(5000);
      await tester.pumpWidget(const SpendWiseApp());
      await tester.pumpAndSettle();
      await tester.tap(find.text('Budget'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Edit overall budget'));
      await tester.pumpAndSettle();
      final field = tester.widget<TextFormField>(find.byType(TextFormField));
      expect(field.controller!.text, isEmpty);
      expect(find.text('5000.00'), findsOneWidget);
      await tester.tap(find.text('Save budget'));
      await tester.pumpAndSettle();
      expect(await storage.loadMonthlyBudget(), 5000);
      expect(find.text('Overall monthly budget').hitTestable(), findsOneWidget);
    },
  );

  testWidgets(
    'account rename with a blank balance preserves the opening funds',
    (tester) async {
      final storage = ExpenseStorage();
      await storage.saveWallet(Wallet(openingBalances: {'Bank': 1234.56}));
      await tester.pumpWidget(const SpendWiseApp());
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.widgetWithText(OutlinedButton, 'Edit'),
        250,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.ensureVisible(find.widgetWithText(OutlinedButton, 'Edit'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(OutlinedButton, 'Edit'));
      await tester.pumpAndSettle();
      final fields = find.byType(TextFormField);
      final balance = tester.widget<TextFormField>(fields.at(1));
      expect(balance.controller!.text, isEmpty);
      expect(find.text('1234.56'), findsOneWidget);
      await tester.enterText(fields.at(0), 'Savings');
      await tester.tap(find.text('Save changes'));
      await tester.pumpAndSettle();
      final wallet = await storage.loadWallet();
      expect(wallet.openingBalances['Savings'], 1234.56);
      expect(wallet.openingBalances.containsKey('Bank'), false);
    },
  );

  testWidgets('history and calendar expose direct edit and delete actions', (
    tester,
  ) async {
    await ExpenseStorage().saveExpenses([
      Expense(
        id: 'icons',
        description: 'Icon test',
        amount: 42,
        category: 'Food & Dining',
        date: DateTime.now(),
      ),
    ]);
    await tester.pumpWidget(const SpendWiseApp());
    await tester.pumpAndSettle();
    await tester.tap(find.text('Expenses'));
    await tester.pumpAndSettle();
    expect(find.byTooltip('Edit expense'), findsOneWidget);
    expect(find.byTooltip('Delete expense'), findsOneWidget);
    await tester.ensureVisible(
      find.widgetWithIcon(IconButton, Icons.edit_outlined),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithIcon(IconButton, Icons.edit_outlined));
    await tester.pumpAndSettle();
    expect(find.byType(ExpenseForm), findsOneWidget);
    await tester.tap(find.byTooltip('Close expense form'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Calendar'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.byTooltip('Delete expense'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.ensureVisible(
      find.widgetWithIcon(IconButton, Icons.delete_outline_rounded),
    );
    await tester.pumpAndSettle();
    await tester.tap(
      find.widgetWithIcon(IconButton, Icons.delete_outline_rounded),
    );
    await tester.pumpAndSettle();
    expect(find.text('Delete expense?'), findsOneWidget);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect((await ExpenseStorage().loadExpenses()).length, 1);
  });
}
