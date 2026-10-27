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
}
