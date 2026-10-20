import 'package:flutter/material.dart';

import 'models/expense.dart';
import 'services/expense_storage.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const SpendWiseApp());
}

const Color navy = Color(0xFF111426);
const Color surface = Color(0xFF1C2035);
const Color violet = Color(0xFF7958FF);
const Color lavender = Color(0xFFC4B5FD);
const Color emerald = Color(0xFF52D6A0);
const Color gold = Color(0xFFF5C66B);
const Color muted = Color(0xFF9CA3B8);
const Color danger = Color(0xFFDC5265);
const double demoIncome = 18000;

const List<String> categories = [
  'Food & Dining',
  'Transportation',
  'Shopping',
  'Bills & Utilities',
  'Education',
  'Entertainment',
  'Health',
  'Other',
];

String peso(double amount) => '\u20B1${amount.toStringAsFixed(2)}';
String shortPeso(double amount) => '\u20B1${amount.toStringAsFixed(0)}';

String dateLabel(DateTime date) =>
    '${date.month.toString().padLeft(2, '0')}/'
    '${date.day.toString().padLeft(2, '0')}/${date.year}';

bool isSameMonth(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month;

IconData categoryIcon(String category) {
  switch (category) {
    case 'Food & Dining':
      return Icons.restaurant_rounded;
    case 'Transportation':
      return Icons.directions_bus_rounded;
    case 'Shopping':
      return Icons.shopping_bag_rounded;
    case 'Bills & Utilities':
      return Icons.receipt_long_rounded;
    case 'Education':
      return Icons.school_rounded;
    case 'Entertainment':
      return Icons.movie_rounded;
    case 'Health':
      return Icons.favorite_rounded;
    default:
      return Icons.category_rounded;
  }
}

Color categoryColor(String category) {
  switch (category) {
    case 'Food & Dining':
      return const Color(0xFFFFB86B);
    case 'Transportation':
      return lavender;
    case 'Shopping':
      return const Color(0xFFFF9AB5);
    case 'Bills & Utilities':
      return const Color(0xFF76C7FF);
    case 'Education':
      return gold;
    case 'Entertainment':
      return const Color(0xFFC4A1FF);
    case 'Health':
      return emerald;
    default:
      return muted;
  }
}

class SpendWiseApp extends StatelessWidget {
  const SpendWiseApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'SpendWise',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: navy,
        colorScheme: ColorScheme.fromSeed(
          seedColor: violet,
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: navy,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: Colors.white12),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: violet),
          ),
        ),
      ),
      home: const MainPage(),
    );
  }
}

class MainPage extends StatefulWidget {
  const MainPage({super.key});

  @override
  State<MainPage> createState() => _MainPageState();
}

class _MainPageState extends State<MainPage> {
  final ExpenseStorage _storage = ExpenseStorage();

  List<Expense> _expenses = [];
  Map<String, double> _budgets = {};

  double _monthlyBudget = 10000;

  int _questXp = 0;
  int _questCoins = 0;
  final Set<String> _completedQuests = {};

  bool _loading = true;
  bool _questStateLoaded = false;
  int _selectedTab = 0;

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  Future<void> _initialize() async {
    await Future.wait([
      _loadExpenses(),
      _loadBudgets(),
      _loadMonthlyBudget(),
      _loadQuestProgress(),
    ]);

    if (!mounted) return;

    setState(() => _loading = false);
    await _updateQuestProgress();
  }

  Future<void> _loadExpenses() async {
    try {
      final loaded = await _storage.loadExpenses();
      loaded.sort((a, b) => b.date.compareTo(a.date));

      if (!mounted) return;
      setState(() => _expenses = loaded);
    } catch (error, stackTrace) {
      debugPrint('Failed to load expenses: $error');
      debugPrintStack(stackTrace: stackTrace);
      if (mounted) _message('Could not load saved expenses.');
    }
  }

  Future<void> _loadBudgets() async {
    try {
      final loaded = await _storage.loadBudgets();
      if (mounted) setState(() => _budgets = loaded);
    } catch (error) {
      debugPrint('Failed to load category budgets: $error');
      if (mounted) _message('Could not load saved budgets.');
    }
  }

  Future<void> _loadMonthlyBudget() async {
    try {
      final amount = await _storage.loadMonthlyBudget();
      if (mounted) setState(() => _monthlyBudget = amount);
    } catch (error) {
      debugPrint('Failed to load monthly budget: $error');
      if (mounted) _message('Could not load the monthly budget.');
    }
  }

  Future<void> _loadQuestProgress() async {
    try {
      final saved = await _storage.loadQuestProgress();
      final quests = saved['completedQuests'];

      if (!mounted) return;

      setState(() {
        _questXp = (saved['xp'] as num?)?.toInt() ?? 0;
        _questCoins = (saved['coins'] as num?)?.toInt() ?? 0;
        _completedQuests
          ..clear()
          ..addAll(quests is List ? quests.whereType<String>() : <String>[]);
        _questStateLoaded = true;
      });
    } catch (error) {
      debugPrint('Failed to load quest progress: $error');
      if (mounted) setState(() => _questStateLoaded = true);
    }
  }

  Future<void> _updateQuestProgress() async {
    if (!_questStateLoaded) return;

    var changed = false;

    void completeQuest(String id, int xp, int coins) {
      if (_completedQuests.add(id)) {
        _questXp += xp;
        _questCoins += coins;
        changed = true;
      }
    }

    if (_expenses.isNotEmpty) {
      completeQuest('first_expense', 10, 5);
    }

    if (_expenses.length >= 5) {
      completeQuest('track_five_expenses', 20, 10);
    }

    if (!changed) return;

    try {
      final success = await _storage.saveQuestProgress({
        'xp': _questXp,
        'coins': _questCoins,
        'completedQuests': _completedQuests.toList(),
      });

      if (!mounted) return;

      if (!success) {
        _message('Quest rewards could not be saved.');
      } else {
        setState(() {});
      }
    } catch (error) {
      debugPrint('Failed to save quest progress: $error');
      if (mounted) _message('Quest rewards could not be saved.');
    }
  }

  Future<bool> _saveExpenses() async {
    try {
      final success = await _storage.saveExpenses(_expenses);

      if (!success && mounted) {
        _message('Could not save expenses.');
      }

      return success;
    } catch (error) {
      debugPrint('Failed to save expenses: $error');
      if (mounted) _message('Could not save expenses.');
      return false;
    }
  }

  double get _monthlyExpenses {
    final now = DateTime.now();

    return _expenses
        .where((e) => isSameMonth(e.date, now))
        .fold<double>(0, (sum, e) => sum + e.amount);
  }

  double get _allExpenses =>
      _expenses.fold<double>(0, (sum, e) => sum + e.amount);

  double _categoryMonthlySpending(String category) {
    final now = DateTime.now();

    return _expenses
        .where((e) => e.category == category && isSameMonth(e.date, now))
        .fold<double>(0, (sum, e) => sum + e.amount);
  }

  double get _totalConfiguredBudget =>
      _budgets.values.fold<double>(0, (sum, amount) => sum + amount);

  double get _totalCategoryBudgetSpending {
    return _budgets.keys.fold<double>(
      0,
      (total, category) => total + _categoryMonthlySpending(category),
    );
  }

  void _message(String message) {
    if (!mounted) return;

    final messenger = ScaffoldMessenger.of(context);
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
      );
  }

  Future<void> _editMonthlyBudget() async {
    final amount = await showDialog<double>(
      context: context,
      builder: (_) => _MonthlyBudgetDialog(initialAmount: _monthlyBudget),
    );

    if (amount == null || !mounted) return;

    final previous = _monthlyBudget;
    setState(() => _monthlyBudget = amount);

    try {
      final success = await _storage.saveMonthlyBudget(amount);
      if (!mounted) return;

      if (!success) {
        setState(() => _monthlyBudget = previous);
        _message('Could not save the monthly budget.');
      } else {
        _message('Monthly budget saved.');
      }
    } catch (error) {
      debugPrint('Failed to save monthly budget: $error');
      if (!mounted) return;
      setState(() => _monthlyBudget = previous);
      _message('Could not save the monthly budget.');
    }
  }

  Future<void> _editCategoryBudget(String category) async {
    final amount = await showDialog<double>(
      context: context,
      builder: (_) => _CategoryBudgetDialog(
        category: category,
        initialAmount: _budgets[category],
      ),
    );

    if (amount == null || !mounted) return;

    final previous = Map<String, double>.from(_budgets);
    final updated = Map<String, double>.from(_budgets)..[category] = amount;

    setState(() => _budgets = updated);

    try {
      final success = await _storage.saveBudgets(updated);
      if (!mounted) return;

      if (!success) {
        setState(() => _budgets = previous);
        _message('Could not save category budget.');
      } else {
        _message('$category budget saved.');
      }
    } catch (error) {
      debugPrint('Failed to save category budget: $error');
      if (!mounted) return;
      setState(() => _budgets = previous);
      _message('Could not save category budget.');
    }
  }

  Future<void> _removeCategoryBudget(String category) async {
    if (!_budgets.containsKey(category)) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: surface,
        title: const Text('Remove budget?'),
        content: Text('Remove the monthly budget for $category?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: danger),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Remove'),
          ),
        ],
      ),
    );

    if (confirm != true || !mounted) return;

    final previous = Map<String, double>.from(_budgets);
    final updated = Map<String, double>.from(_budgets)..remove(category);

    setState(() => _budgets = updated);

    try {
      final success = await _storage.saveBudgets(updated);
      if (!mounted) return;

      if (!success) {
        setState(() => _budgets = previous);
        _message('Could not remove category budget.');
      } else {
        _message('$category budget removed.');
      }
    } catch (error) {
      debugPrint('Failed to remove category budget: $error');
      if (!mounted) return;
      setState(() => _budgets = previous);
      _message('Could not remove category budget.');
    }
  }

  // Calculates whether the expense will push spending further over a budget.
  // When editing, the original expense is excluded before the new one is added.
  List<String> _budgetWarnings(Expense candidate, Expense? original) {
    final now = DateTime.now();

    final originalInCurrentMonth =
        original != null && isSameMonth(original.date, now);
    final candidateInCurrentMonth = isSameMonth(candidate.date, now);

    final currentMonthlySpending = _monthlyExpenses;

    final projectedMonthlySpending =
        currentMonthlySpending -
        (originalInCurrentMonth ? original.amount : 0) +
        (candidateInCurrentMonth ? candidate.amount : 0);

    final warnings = <String>[];

    if (candidateInCurrentMonth &&
        projectedMonthlySpending > _monthlyBudget &&
        projectedMonthlySpending > currentMonthlySpending) {
      warnings.add(
        'Overall monthly budget\n'
        'Projected spending: ${peso(projectedMonthlySpending)}\n'
        'Monthly limit: ${peso(_monthlyBudget)}\n'
        'Over budget by: '
        '${peso(projectedMonthlySpending - _monthlyBudget)}',
      );
    }

    if (candidateInCurrentMonth) {
      final categoryLimit = _budgets[candidate.category];

      if (categoryLimit != null && categoryLimit > 0) {
        final currentCategorySpending = _categoryMonthlySpending(
          candidate.category,
        );

        var projectedCategorySpending = currentCategorySpending;

        if (originalInCurrentMonth && original.category == candidate.category) {
          projectedCategorySpending -= original.amount;
        }

        projectedCategorySpending += candidate.amount;

        if (projectedCategorySpending > categoryLimit &&
            projectedCategorySpending > currentCategorySpending) {
          warnings.add(
            '${candidate.category} budget\n'
            'Projected spending: ${peso(projectedCategorySpending)}\n'
            'Category limit: ${peso(categoryLimit)}\n'
            'Over budget by: '
            '${peso(projectedCategorySpending - categoryLimit)}',
          );
        }
      }
    }

    return warnings;
  }

  Future<void> _openExpenseForm({Expense? expense}) async {
    Expense? draft = expense;

    while (mounted) {
      final result = await showModalBottomSheet<Expense>(
        context: context,
        isScrollControlled: true,
        backgroundColor: surface,
        useSafeArea: true,
        builder: (_) => ExpenseForm(expense: draft),
      );

      if (result == null || !mounted) return;

      final warnings = _budgetWarnings(result, expense);

      if (warnings.isNotEmpty) {
        final saveAnyway = await showDialog<bool>(
          context: context,
          barrierDismissible: false,
          builder: (dialogContext) => AlertDialog(
            backgroundColor: surface,
            icon: const Icon(
              Icons.warning_amber_rounded,
              color: gold,
              size: 42,
            ),
            title: const Text('Budget Limit Warning'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'This expense will exceed the following budget limit(s):',
                    style: TextStyle(color: muted, height: 1.5),
                  ),
                  const SizedBox(height: 14),
                  ...warnings.map(
                    (warning) => Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: danger.withValues(alpha: 0.10),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: danger.withValues(alpha: 0.25),
                          ),
                        ),
                        child: Text(
                          warning,
                          style: const TextStyle(height: 1.5),
                        ),
                      ),
                    ),
                  ),
                  const Text(
                    'Would you like to save this expense anyway?',
                    style: TextStyle(height: 1.5),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: const Text('Go Back and Edit'),
              ),
              FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: violet,
                  foregroundColor: Colors.white,
                ),
                onPressed: () => Navigator.pop(dialogContext, true),
                child: const Text('Save Anyway'),
              ),
            ],
          ),
        );

        if (!mounted) return;

        if (saveAnyway != true) {
          // Reopen the form with the entered values preserved.
          draft = result;
          continue;
        }
      }

      final index = _expenses.indexWhere((e) => e.id == result.id);
      final previousExpenses = List<Expense>.from(_expenses);

      setState(() {
        if (index >= 0) {
          _expenses[index] = result;
        } else {
          _expenses.add(result);
        }

        _expenses.sort((a, b) => b.date.compareTo(a.date));
      });

      final saved = await _saveExpenses();

      if (!mounted) return;

      if (!saved) {
        // Restore the in-memory list if local storage could not save it.
        setState(() => _expenses = previousExpenses);
        return;
      }

      await _updateQuestProgress();

      if (!mounted) return;

      _message(
        expense == null ? 'Expense added successfully.' : 'Expense updated.',
      );

      return;
    }
  }

  Future<void> _deleteExpense(Expense expense) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: surface,
        title: const Text('Delete expense?'),
        content: Text('Remove "${expense.description}" from your records?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: danger),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm != true || !mounted) return;

    final previousExpenses = List<Expense>.from(_expenses);

    setState(() => _expenses.removeWhere((e) => e.id == expense.id));

    final saved = await _saveExpenses();

    if (!mounted) return;

    if (!saved) {
      setState(() => _expenses = previousExpenses);
      return;
    }

    await _updateQuestProgress();

    if (mounted) _message('Expense deleted.');
  }

  @override
  Widget build(BuildContext context) {
    const titles = [
      'SpendWise',
      'Expense history',
      'Insights',
      'Money Quest',
      'Monthly budgets',
    ];

    return Scaffold(
      appBar: _selectedTab == 0
          ? null
          : AppBar(title: Text(titles[_selectedTab]), backgroundColor: navy),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: violet))
          : IndexedStack(
              index: _selectedTab,
              children: [
                _buildDashboard(),
                _buildExpenseHistory(),
                _buildInsights(),
                _buildQuest(),
                _buildBudgets(),
              ],
            ),
      floatingActionButton: _selectedTab == 0 || _selectedTab == 1
          ? FloatingActionButton.extended(
              onPressed: () => _openExpenseForm(),
              backgroundColor: violet,
              foregroundColor: Colors.white,
              icon: const Icon(Icons.add_rounded),
              label: const Text('Add expense'),
            )
          : null,
      bottomNavigationBar: NavigationBar(
        backgroundColor: const Color(0xFF191C2E),
        indicatorColor: violet.withValues(alpha: 0.25),
        selectedIndex: _selectedTab,
        onDestinationSelected: (index) {
          setState(() => _selectedTab = index);
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home_rounded),
            label: 'Home',
          ),
          NavigationDestination(
            icon: Icon(Icons.receipt_long_outlined),
            selectedIcon: Icon(Icons.receipt_long_rounded),
            label: 'Expenses',
          ),
          NavigationDestination(
            icon: Icon(Icons.pie_chart_outline_rounded),
            selectedIcon: Icon(Icons.pie_chart_rounded),
            label: 'Insights',
          ),
          NavigationDestination(
            icon: Icon(Icons.emoji_events_outlined),
            selectedIcon: Icon(Icons.emoji_events_rounded),
            label: 'Quest',
          ),
          NavigationDestination(
            icon: Icon(Icons.account_balance_wallet_outlined),
            selectedIcon: Icon(Icons.account_balance_wallet_rounded),
            label: 'Budget',
          ),
        ],
      ),
    );
  }

  Widget _buildDashboard() {
    final now = DateTime.now();
    const monthNames = [
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December',
    ];

    final monthName = monthNames[now.month - 1];
    final monthExpenses = _expenses
        .where((e) => isSameMonth(e.date, now))
        .toList();

    final progress = _monthlyBudget <= 0
        ? 0.0
        : (_monthlyExpenses / _monthlyBudget).clamp(0.0, 1.0);
    final remainingIncome = demoIncome - _allExpenses;
    final budgetRemaining = _monthlyBudget - _monthlyExpenses;

    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 100),
        children: [
          Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [violet, Color(0xFFAB8BFF)],
                  ),
                  borderRadius: BorderRadius.circular(15),
                ),
                child: const Icon(
                  Icons.account_balance_wallet_rounded,
                  color: Colors.white,
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'SpendWise',
                      style: TextStyle(
                        fontSize: 23,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      'Your money, your quest.',
                      style: TextStyle(color: muted, fontSize: 12),
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: () => _message('Welcome to SpendWise!'),
                icon: const Icon(Icons.notifications_none_rounded),
                style: IconButton.styleFrom(backgroundColor: surface),
              ),
            ],
          ),
          const SizedBox(height: 28),
          const _Eyebrow('YOUR FINANCES'),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(22),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0xFF7858FF),
                  Color(0xFF5135B8),
                  Color(0xFF30245F),
                ],
              ),
              borderRadius: BorderRadius.circular(26),
              boxShadow: [
                BoxShadow(
                  color: violet.withValues(alpha: 0.18),
                  blurRadius: 24,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(
                      Icons.account_balance_wallet_outlined,
                      size: 18,
                      color: lavender,
                    ),
                    SizedBox(width: 8),
                    Text(
                      'Available balance',
                      style: TextStyle(color: lavender, fontSize: 13),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    peso(remainingIncome),
                    style: const TextStyle(
                      fontSize: 34,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Demo income minus all recorded expenses',
                  style: TextStyle(color: lavender, fontSize: 11),
                ),
                const SizedBox(height: 22),
                Row(
                  children: [
                    Expanded(
                      child: _BalanceStat(
                        icon: Icons.south_west_rounded,
                        label: 'Demo income',
                        amount: peso(demoIncome),
                        color: emerald,
                      ),
                    ),
                    Container(height: 38, width: 1, color: Colors.white24),
                    const SizedBox(width: 16),
                    Expanded(
                      child: _BalanceStat(
                        icon: Icons.north_east_rounded,
                        label: 'All expenses',
                        amount: peso(_allExpenses),
                        color: const Color(0xFFFFC1C8),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 26),
          Row(
            children: [
              const Expanded(
                child: Text(
                  'This month',
                  style: TextStyle(fontSize: 19, fontWeight: FontWeight.bold),
                ),
              ),
              Text(
                '$monthName ${now.year}',
                style: const TextStyle(color: muted, fontSize: 12),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _SummaryCard(
                  icon: Icons.payments_rounded,
                  title: 'Spent',
                  amount: peso(_monthlyExpenses),
                  subtitle: '${monthExpenses.length} recorded expenses',
                  color: lavender,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _SummaryCard(
                  icon: Icons.savings_rounded,
                  title: 'Unspent income',
                  amount: peso(remainingIncome),
                  subtitle: 'Demo income balance',
                  color: emerald,
                ),
              ),
            ],
          ),
          const SizedBox(height: 26),
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Monthly budget',
                  style: TextStyle(fontSize: 19, fontWeight: FontWeight.bold),
                ),
              ),
              TextButton(
                onPressed: () => setState(() => _selectedTab = 4),
                child: const Text('View all'),
              ),
            ],
          ),
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: surface,
              borderRadius: BorderRadius.circular(22),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    const CircleAvatar(
                      backgroundColor: Color(0xFF302650),
                      child: Icon(Icons.pie_chart_rounded, color: lavender),
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Overall spending',
                            style: TextStyle(fontWeight: FontWeight.w600),
                          ),
                          SizedBox(height: 4),
                          Text(
                            'Your spending limit for this month',
                            style: TextStyle(color: muted, fontSize: 11),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      tooltip: 'Edit monthly budget',
                      onPressed: _editMonthlyBudget,
                      icon: const Icon(Icons.edit_outlined, color: lavender),
                    ),
                    Text(
                      '${(_monthlyBudget <= 0 ? 0 : _monthlyExpenses / _monthlyBudget * 100).toStringAsFixed(1)}%',
                      style: TextStyle(
                        color: _monthlyExpenses > _monthlyBudget
                            ? Colors.redAccent
                            : emerald,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: LinearProgressIndicator(
                    value: progress,
                    minHeight: 9,
                    backgroundColor: const Color(0xFF363A50),
                    valueColor: AlwaysStoppedAnimation(
                      _monthlyExpenses > _monthlyBudget
                          ? Colors.redAccent
                          : violet,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        '${shortPeso(_monthlyExpenses)} spent',
                        style: const TextStyle(color: muted, fontSize: 12),
                      ),
                    ),
                    Text(
                      '${peso(_monthlyBudget)} limit',
                      style: const TextStyle(color: muted, fontSize: 12),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerRight,
                  child: Text(
                    budgetRemaining < 0
                        ? '${peso(budgetRemaining.abs())} over budget'
                        : '${peso(budgetRemaining)} remaining',
                    style: TextStyle(
                      color: budgetRemaining < 0 ? Colors.redAccent : emerald,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 26),
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Recent transactions',
                  style: TextStyle(fontSize: 19, fontWeight: FontWeight.bold),
                ),
              ),
              TextButton(
                onPressed: () => setState(() => _selectedTab = 1),
                child: const Text('See all'),
              ),
            ],
          ),
          if (_expenses.isEmpty)
            const _EmptyState(
              icon: Icons.receipt_long_rounded,
              title: 'No expenses yet',
              message: 'Tap Add expense to record your first transaction.',
            )
          else
            ..._expenses
                .take(4)
                .map(
                  (expense) => _TransactionTile(
                    expense: expense,
                    onTap: () => _openExpenseForm(expense: expense),
                    onDelete: () => _deleteExpense(expense),
                  ),
                ),
          const SizedBox(height: 26),
          const Text(
            'Money Quest',
            style: TextStyle(fontSize: 19, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 14),
          Material(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(22),
            child: InkWell(
              onTap: () => setState(() => _selectedTab = 3),
              borderRadius: BorderRadius.circular(22),
              child: Ink(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: surface,
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(color: gold.withValues(alpha: 0.18)),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.workspace_premium_rounded,
                      color: gold,
                      size: 38,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Your financial adventure',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 5),
                          Text(
                            'Level ${(_questXp ~/ 100) + 1} · $_questXp XP earned. Tap to view your quests.',
                            style: const TextStyle(color: muted, fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                    const Icon(
                      Icons.arrow_forward_ios_rounded,
                      color: gold,
                      size: 16,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBudgets() {
    final totalBudget = _totalConfiguredBudget;
    final totalSpent = _totalCategoryBudgetSpending;
    final hasBudgets = _budgets.isNotEmpty;
    final progress = totalBudget <= 0
        ? 0.0
        : (totalSpent / totalBudget).clamp(0.0, 1.0);
    final remaining = totalBudget - totalSpent;
    final overallProgress = _monthlyBudget <= 0
        ? 0.0
        : (_monthlyExpenses / _monthlyBudget).clamp(0.0, 1.0);
    final overallRemaining = _monthlyBudget - _monthlyExpenses;

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
      children: [
        const Text(
          'Plan your spending',
          style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        const Text(
          'Set an overall monthly limit and individual category budgets.',
          style: TextStyle(color: muted, height: 1.5),
        ),
        const SizedBox(height: 22),
        Container(
          padding: const EdgeInsets.all(18),
          margin: const EdgeInsets.only(bottom: 18),
          decoration: BoxDecoration(
            color: surface,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: violet.withValues(alpha: 0.35)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Overall monthly budget',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Edit overall budget',
                    onPressed: _editMonthlyBudget,
                    icon: const Icon(Icons.edit_outlined, color: lavender),
                  ),
                ],
              ),
              Text(
                '${peso(_monthlyExpenses)} of ${peso(_monthlyBudget)} spent',
                style: const TextStyle(color: muted, fontSize: 12),
              ),
              const SizedBox(height: 12),
              LinearProgressIndicator(
                value: overallProgress,
                minHeight: 8,
                borderRadius: BorderRadius.circular(8),
                backgroundColor: const Color(0xFF363A50),
                valueColor: AlwaysStoppedAnimation(
                  _monthlyExpenses > _monthlyBudget ? Colors.redAccent : violet,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                overallRemaining < 0
                    ? '${peso(overallRemaining.abs())} over budget'
                    : '${peso(overallRemaining)} remaining',
                style: TextStyle(
                  color: overallRemaining < 0 ? Colors.redAccent : emerald,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF5135B8), Color(0xFF30245F)],
            ),
            borderRadius: BorderRadius.circular(24),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  Icon(Icons.account_balance_wallet_rounded, color: lavender),
                  SizedBox(width: 8),
                  Text(
                    'Your category budgets',
                    style: TextStyle(color: lavender),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Text(
                peso(totalBudget),
                style: const TextStyle(
                  fontSize: 30,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                hasBudgets
                    ? 'Total of ${_budgets.length} configured ${_budgets.length == 1 ? 'category' : 'categories'}'
                    : 'No category budgets set yet',
                style: const TextStyle(color: lavender, fontSize: 12),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Spent this month',
                      style: TextStyle(color: lavender, fontSize: 12),
                    ),
                  ),
                  Text(
                    peso(totalSpent),
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              const SizedBox(height: 9),
              LinearProgressIndicator(
                value: progress,
                minHeight: 9,
                backgroundColor: Colors.white24,
                valueColor: AlwaysStoppedAnimation(
                  totalBudget > 0 && totalSpent > totalBudget
                      ? Colors.redAccent
                      : emerald,
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Remaining category budget',
                      style: TextStyle(color: lavender, fontSize: 12),
                    ),
                  ),
                  Text(
                    peso(remaining),
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: remaining < 0 ? Colors.redAccent : emerald,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 26),
        const Text(
          'Category budgets',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        ...categories.map((category) {
          final limit = _budgets[category];
          final spent = _categoryMonthlySpending(category);
          final hasLimit = limit != null && limit > 0;
          final fraction = hasLimit ? (spent / limit).clamp(0.0, 1.0) : 0.0;
          final ratio = hasLimit ? spent / limit : 0.0;

          final String status;
          final Color statusColor;

          if (!hasLimit) {
            status = 'Not set';
            statusColor = muted;
          } else if (ratio > 1) {
            status = 'Over budget';
            statusColor = Colors.redAccent;
          } else if (ratio >= 0.8) {
            status = 'Approaching limit';
            statusColor = gold;
          } else {
            status = 'On track';
            statusColor = emerald;
          }

          return Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: surface,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: hasLimit
                    ? categoryColor(category).withValues(alpha: 0.15)
                    : Colors.white10,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: categoryColor(category).withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Icon(
                        categoryIcon(category),
                        color: categoryColor(category),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            category,
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 5),
                          Text(
                            status,
                            style: TextStyle(
                              color: statusColor,
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      tooltip: 'Edit budget',
                      onPressed: () => _editCategoryBudget(category),
                      icon: const Icon(Icons.edit_outlined, color: lavender),
                    ),
                    if (hasLimit)
                      PopupMenuButton<String>(
                        color: surface,
                        onSelected: (value) {
                          if (value == 'remove') {
                            _removeCategoryBudget(category);
                          }
                        },
                        itemBuilder: (_) => const [
                          PopupMenuItem(
                            value: 'remove',
                            child: Text('Remove budget'),
                          ),
                        ],
                      ),
                  ],
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    const Text(
                      'Spent',
                      style: TextStyle(color: muted, fontSize: 12),
                    ),
                    const Spacer(),
                    Text(
                      peso(spent),
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    if (hasLimit) ...[
                      const Text(' / ', style: TextStyle(color: muted)),
                      Text(
                        peso(limit),
                        style: const TextStyle(color: muted, fontSize: 12),
                      ),
                    ],
                  ],
                ),
                if (hasLimit) ...[
                  const SizedBox(height: 10),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: LinearProgressIndicator(
                      value: fraction,
                      minHeight: 7,
                      backgroundColor: const Color(0xFF363A50),
                      valueColor: AlwaysStoppedAnimation(statusColor),
                    ),
                  ),
                  const SizedBox(height: 7),
                  Text(
                    ratio > 1
                        ? '${peso(spent - limit)} over your limit'
                        : '${peso(limit - spent)} remaining',
                    style: TextStyle(color: statusColor, fontSize: 11),
                  ),
                ] else
                  const Padding(
                    padding: EdgeInsets.only(top: 8),
                    child: Text(
                      'Set a limit to track spending in this category.',
                      style: TextStyle(color: muted, fontSize: 12),
                    ),
                  ),
              ],
            ),
          );
        }),
        const SizedBox(height: 8),
        const Text(
          'Spending is calculated from expenses dated in the current month. '
          'Your expenses and budgets remain saved on this device.',
          style: TextStyle(color: muted, fontSize: 12, height: 1.5),
        ),
      ],
    );
  }

  Widget _buildExpenseHistory() {
    if (_expenses.isEmpty) {
      return const _EmptyState(
        icon: Icons.receipt_long_rounded,
        title: 'Your expense history is empty',
        message: 'Tap Add expense to record your first expense.',
      );
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 110),
      children: [
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF5135B8), Color(0xFF30245F)],
            ),
            borderRadius: BorderRadius.circular(22),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Total recorded expenses',
                style: TextStyle(color: lavender),
              ),
              const SizedBox(height: 8),
              Text(
                peso(_allExpenses),
                style: const TextStyle(
                  fontSize: 29,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 5),
              Text(
                '${_expenses.length} ${_expenses.length == 1 ? 'transaction' : 'transactions'}',
                style: const TextStyle(color: lavender, fontSize: 12),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        const Text(
          'All transactions',
          style: TextStyle(fontSize: 19, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        ..._expenses.map(
          (expense) => _TransactionTile(
            expense: expense,
            onTap: () => _openExpenseForm(expense: expense),
            onDelete: () => _deleteExpense(expense),
          ),
        ),
      ],
    );
  }

  Widget _buildInsights() {
    if (_expenses.isEmpty) {
      return const _EmptyState(
        icon: Icons.insights_rounded,
        title: 'Insights will appear here',
        message: 'Record some expenses to see your spending by category.',
      );
    }

    final Map<String, double> totals = {};

    for (final expense in _expenses) {
      totals[expense.category] =
          (totals[expense.category] ?? 0) + expense.amount;
    }

    final total = _allExpenses;
    final ranked = totals.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        const Text(
          'Your spending',
          style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        const Text(
          'Based on all recorded expenses.',
          style: TextStyle(color: muted),
        ),
        const SizedBox(height: 20),
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: surface,
            borderRadius: BorderRadius.circular(22),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Total expenses', style: TextStyle(color: muted)),
              const SizedBox(height: 8),
              Text(
                peso(total),
                style: const TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 22),
              ...ranked.map((entry) {
                final fraction = total == 0 ? 0.0 : entry.value / total;

                return Padding(
                  padding: const EdgeInsets.only(bottom: 20),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Icon(
                            categoryIcon(entry.key),
                            color: categoryColor(entry.key),
                            size: 19,
                          ),
                          const SizedBox(width: 8),
                          Expanded(child: Text(entry.key)),
                          Text(
                            peso(entry.value),
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                      const SizedBox(height: 9),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: LinearProgressIndicator(
                          value: fraction,
                          minHeight: 7,
                          backgroundColor: const Color(0xFF363A50),
                          valueColor: AlwaysStoppedAnimation(
                            categoryColor(entry.key),
                          ),
                        ),
                      ),
                      const SizedBox(height: 5),
                      Align(
                        alignment: Alignment.centerRight,
                        child: Text(
                          '${(fraction * 100).toStringAsFixed(1)}%',
                          style: const TextStyle(color: muted, fontSize: 11),
                        ),
                      ),
                    ],
                  ),
                );
              }),
            ],
          ),
        ),
        if (ranked.isNotEmpty) ...[
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: surface,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              'Your highest spending category is ${ranked.first.key} '
              'at ${peso(ranked.first.value)}. Review this category to '
              'see whether you can save money.',
              style: const TextStyle(height: 1.5),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildQuest() {
    final level = (_questXp ~/ 100) + 1;
    final xpIntoLevel = _questXp % 100;
    final count = _expenses.length;

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        const Text(
          'Money Quest',
          style: TextStyle(fontSize: 25, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        const Text(
          'Build better money habits one step at a time.',
          style: TextStyle(color: muted),
        ),
        const SizedBox(height: 22),
        Container(
          padding: const EdgeInsets.all(22),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF5135B8), Color(0xFF30245F)],
            ),
            borderRadius: BorderRadius.circular(24),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(
                Icons.workspace_premium_rounded,
                color: gold,
                size: 42,
              ),
              const SizedBox(height: 12),
              Text(
                'Level $level · ${level == 1 ? 'Money Explorer' : 'Money Adventurer'}',
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '$_questXp XP earned · $_questCoins coins',
                style: const TextStyle(color: lavender),
              ),
              const SizedBox(height: 16),
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: LinearProgressIndicator(
                  value: xpIntoLevel / 100,
                  minHeight: 8,
                  backgroundColor: Colors.white24,
                  valueColor: const AlwaysStoppedAnimation(gold),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '$xpIntoLevel / 100 XP toward the next level',
                style: const TextStyle(color: lavender, fontSize: 12),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        const Text(
          'Available quests',
          style: TextStyle(fontSize: 19, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 14),
        _QuestTile(
          title: 'First Expense',
          description: 'Record your first transaction.',
          reward: '+10 XP · +5 coins',
          done: _completedQuests.contains('first_expense'),
        ),
        _QuestTile(
          title: 'Track Your Spending',
          description: 'Record five expenses.',
          reward: '+20 XP · +10 coins',
          done: _completedQuests.contains('track_five_expenses'),
          progress: count.clamp(0, 5) / 5,
          progressText: '${count.clamp(0, 5)} / 5 expenses',
        ),
        const SizedBox(height: 12),
        const Text(
          'Rewards are saved on this device. Each quest can award its reward once.',
          style: TextStyle(color: muted, fontSize: 12, height: 1.5),
        ),
      ],
    );
  }
}

class _MonthlyBudgetDialog extends StatefulWidget {
  final double initialAmount;

  const _MonthlyBudgetDialog({required this.initialAmount});

  @override
  State<_MonthlyBudgetDialog> createState() => _MonthlyBudgetDialogState();
}

class _MonthlyBudgetDialogState extends State<_MonthlyBudgetDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(
      text: widget.initialAmount.toStringAsFixed(2),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _save() {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final amount = double.tryParse(_controller.text.trim());
    if (amount == null || !amount.isFinite || amount <= 0) return;

    FocusScope.of(context).unfocus();
    Navigator.of(context).pop(amount);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: surface,
      title: const Text('Overall monthly budget'),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Set the maximum amount you plan to spend across all categories '
              'each calendar month.',
              style: TextStyle(color: muted, height: 1.5),
            ),
            const SizedBox(height: 18),
            TextFormField(
              controller: _controller,
              autofocus: true,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: const InputDecoration(
                labelText: 'Monthly spending limit',
                prefixText: '\u20B1 ',
                hintText: '10000.00',
              ),
              validator: (value) {
                final amount = double.tryParse(value?.trim() ?? '');

                if (amount == null ||
                    !amount.isFinite ||
                    amount <= 0 ||
                    amount > 1000000000) {
                  return 'Enter a valid amount greater than zero.';
                }

                return null;
              },
              onFieldSubmitted: (_) => _save(),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: violet),
          onPressed: _save,
          child: const Text('Save budget'),
        ),
      ],
    );
  }
}

class _CategoryBudgetDialog extends StatefulWidget {
  final String category;
  final double? initialAmount;

  const _CategoryBudgetDialog({
    required this.category,
    required this.initialAmount,
  });

  @override
  State<_CategoryBudgetDialog> createState() => _CategoryBudgetDialogState();
}

class _CategoryBudgetDialogState extends State<_CategoryBudgetDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(
      text: widget.initialAmount?.toStringAsFixed(2) ?? '',
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _save() {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final amount = double.tryParse(_controller.text.trim());
    if (amount == null || !amount.isFinite || amount <= 0) return;

    FocusScope.of(context).unfocus();
    Navigator.of(context).pop(amount);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: surface,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      title: Text('${widget.category} budget'),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Set your spending limit for this category each month.',
                style: TextStyle(color: muted, height: 1.4),
              ),
              const SizedBox(height: 18),
              TextFormField(
                controller: _controller,
                autofocus: true,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: const InputDecoration(
                  labelText: 'Monthly limit',
                  prefixText: '\u20B1 ',
                  hintText: '2000.00',
                ),
                validator: (value) {
                  final amount = double.tryParse(value?.trim() ?? '');

                  if (amount == null ||
                      !amount.isFinite ||
                      amount <= 0 ||
                      amount > 1000000000) {
                    return 'Enter a valid amount greater than zero.';
                  }

                  return null;
                },
                onFieldSubmitted: (_) => _save(),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: violet),
          onPressed: _save,
          child: const Text('Save budget'),
        ),
      ],
    );
  }
}

class ExpenseForm extends StatefulWidget {
  final Expense? expense;

  const ExpenseForm({super.key, this.expense});

  @override
  State<ExpenseForm> createState() => _ExpenseFormState();
}

class _ExpenseFormState extends State<ExpenseForm> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _descriptionController;
  late final TextEditingController _amountController;
  late String _category;
  late DateTime _date;

  bool get _editing => widget.expense != null;

  @override
  void initState() {
    super.initState();

    final expense = widget.expense;

    _descriptionController = TextEditingController(
      text: expense?.description ?? '',
    );

    _amountController = TextEditingController(
      text: expense?.amount.toStringAsFixed(2) ?? '',
    );

    _category = expense?.category ?? categories.first;
    _date = expense?.date ?? DateTime.now();
  }

  @override
  void dispose() {
    _descriptionController.dispose();
    _amountController.dispose();
    super.dispose();
  }

  Future<void> _chooseDate() async {
    final selected = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2000),
      lastDate: DateTime.now().add(const Duration(days: 3650)),
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: const ColorScheme.dark(
            primary: violet,
            surface: surface,
          ),
        ),
        child: child!,
      ),
    );

    if (selected != null && mounted) {
      setState(() => _date = selected);
    }
  }

  void _submit() {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final amount = double.parse(_amountController.text.trim());
    final description = _descriptionController.text.trim();
    final oldExpense = widget.expense;

    Navigator.of(context).pop(
      Expense(
        id: oldExpense?.id ?? DateTime.now().microsecondsSinceEpoch.toString(),
        description: description,
        amount: amount,
        category: _category,
        date: _date,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 22,
        bottom: MediaQuery.of(context).viewInsets.bottom + 22,
      ),
      child: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      _editing ? 'Edit expense' : 'Add expense',
                      style: const TextStyle(
                        fontSize: 23,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              const Text(
                'Enter the details of your transaction.',
                style: TextStyle(color: muted),
              ),
              const SizedBox(height: 22),
              const Text('Description'),
              const SizedBox(height: 8),
              TextFormField(
                controller: _descriptionController,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                  hintText: 'e.g. Lunch, bus fare, groceries',
                  prefixIcon: Icon(Icons.edit_note_rounded),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter a description.';
                  }

                  if (value.trim().length > 80) {
                    return 'Use 80 characters or fewer.';
                  }

                  return null;
                },
              ),
              const SizedBox(height: 18),
              const Text('Amount (PHP)'),
              const SizedBox(height: 8),
              TextFormField(
                controller: _amountController,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: const InputDecoration(
                  hintText: '0.00',
                  prefixText: '\u20B1 ',
                  prefixIcon: Icon(Icons.payments_outlined),
                ),
                validator: (value) {
                  final amount = double.tryParse(value?.trim() ?? '');

                  if (amount == null || !amount.isFinite || amount <= 0) {
                    return 'Enter an amount greater than zero.';
                  }

                  if (amount > 1000000000) {
                    return 'Please enter a smaller amount.';
                  }

                  return null;
                },
              ),
              const SizedBox(height: 18),
              const Text('Category'),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                initialValue: _category,
                isExpanded: true,
                decoration: const InputDecoration(
                  prefixIcon: Icon(Icons.category_outlined),
                ),
                items: categories
                    .map(
                      (category) => DropdownMenuItem(
                        value: category,
                        child: Text(category),
                      ),
                    )
                    .toList(),
                onChanged: (value) {
                  if (value != null) setState(() => _category = value);
                },
              ),
              const SizedBox(height: 18),
              const Text('Date'),
              const SizedBox(height: 8),
              InkWell(
                onTap: _chooseDate,
                borderRadius: BorderRadius.circular(14),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: navy,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: Colors.white12),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.calendar_month_rounded, color: lavender),
                      const SizedBox(width: 12),
                      Expanded(child: Text(dateLabel(_date))),
                      const Icon(Icons.keyboard_arrow_down_rounded),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 26),
              SizedBox(
                width: double.infinity,
                height: 54,
                child: FilledButton.icon(
                  onPressed: _submit,
                  style: FilledButton.styleFrom(
                    backgroundColor: violet,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  icon: Icon(_editing ? Icons.save_rounded : Icons.add_rounded),
                  label: Text(
                    _editing ? 'Save changes' : 'Save expense',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Eyebrow extends StatelessWidget {
  final String text;

  const _Eyebrow(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        color: muted,
        fontSize: 11,
        fontWeight: FontWeight.bold,
        letterSpacing: 2,
      ),
    );
  }
}

class _BalanceStat extends StatelessWidget {
  final IconData icon;
  final String label;
  final String amount;
  final Color color;

  const _BalanceStat({
    required this.icon,
    required this.label,
    required this.amount,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, color: color, size: 16),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                label,
                style: const TextStyle(color: lavender, fontSize: 11),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        const SizedBox(height: 7),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(
            amount,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
        ),
      ],
    );
  }
}

class _SummaryCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String amount;
  final String subtitle;
  final Color color;

  const _SummaryCard({
    required this.icon,
    required this.title,
    required this.amount,
    required this.subtitle,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(21),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(height: 14),
          Text(title, style: const TextStyle(color: muted, fontSize: 12)),
          const SizedBox(height: 5),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              amount,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ),
          const SizedBox(height: 5),
          Text(
            subtitle,
            style: const TextStyle(color: muted, fontSize: 10),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

class _TransactionTile extends StatelessWidget {
  final Expense expense;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  const _TransactionTile({
    required this.expense,
    required this.onTap,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final color = categoryColor(expense.category);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(18),
        clipBehavior: Clip.antiAlias,
        child: ListTile(
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 14,
            vertical: 5,
          ),
          leading: Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(categoryIcon(expense.category), color: color),
          ),
          title: Text(
            expense.description,
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          subtitle: Text(
            '${expense.category} · ${dateLabel(expense.date)}',
            style: const TextStyle(color: muted, fontSize: 11),
          ),
          trailing: PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert_rounded, color: muted),
            onSelected: (value) {
              if (value == 'edit') onTap();
              if (value == 'delete') onDelete();
            },
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'edit', child: Text('Edit expense')),
              PopupMenuItem(value: 'delete', child: Text('Delete expense')),
            ],
          ),
          onTap: onTap,
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;

  const _EmptyState({
    required this.icon,
    required this.title,
    required this.message,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: lavender, size: 52),
            const SizedBox(height: 16),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(color: muted, height: 1.5),
            ),
          ],
        ),
      ),
    );
  }
}

class _QuestTile extends StatelessWidget {
  final String title;
  final String description;
  final String reward;
  final bool done;
  final double? progress;
  final String? progressText;

  const _QuestTile({
    required this.title,
    required this.description,
    required this.reward,
    required this.done,
    this.progress,
    this.progressText,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                done ? Icons.check_circle_rounded : Icons.flag_rounded,
                color: done ? emerald : gold,
                size: 25,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      description,
                      style: const TextStyle(color: muted, fontSize: 12),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Text(
                done ? 'Complete' : reward,
                style: TextStyle(
                  color: done ? emerald : gold,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          if (progress != null) ...[
            const SizedBox(height: 14),
            LinearProgressIndicator(
              value: progress,
              backgroundColor: const Color(0xFF363A50),
              color: gold,
              minHeight: 6,
              borderRadius: BorderRadius.circular(8),
            ),
            const SizedBox(height: 6),
            Text(
              progressText ?? '',
              style: const TextStyle(color: muted, fontSize: 11),
            ),
          ],
        ],
      ),
    );
  }
}
