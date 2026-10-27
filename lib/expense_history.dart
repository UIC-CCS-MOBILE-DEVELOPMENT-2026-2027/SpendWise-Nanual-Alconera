import 'package:flutter/material.dart';
import 'domain/money.dart';
import 'models/expense.dart';

class ExpenseHistory extends StatefulWidget {
  final List<Expense> expenses;
  final Color primaryColor;
  final ValueChanged<Expense> onEdit, onDelete;
  const ExpenseHistory({
    super.key,
    required this.expenses,
    required this.primaryColor,
    required this.onEdit,
    required this.onDelete,
  });
  @override
  State<ExpenseHistory> createState() => _ExpenseHistoryState();
}

class _ExpenseHistoryState extends State<ExpenseHistory> {
  final _search = TextEditingController();
  String? _account;
  bool _thisMonth = false;
  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final accounts = widget.expenses.map((e) => e.account).toSet().toList()
      ..sort();
    final account = accounts.contains(_account) ? _account : null;
    final query = _search.text.trim().toLowerCase();
    final now = DateTime.now();
    final filtered = widget.expenses
        .where(
          (e) =>
              (account == null || e.account == account) &&
              (!_thisMonth ||
                  (e.date.year == now.year && e.date.month == now.month)) &&
              ('${e.description} ${e.category} ${e.account}'
                  .toLowerCase()
                  .contains(query)),
        )
        .toList();
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 110),
      itemCount: filtered.length + 1,
      itemBuilder: (context, index) {
        if (index == 0) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Expense history',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 8),
              Text(
                '₱${Money.sum(filtered.map((e) => e.amount)).toStringAsFixed(2)}',
                style: TextStyle(
                  color: widget.primaryColor,
                  fontSize: 30,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text('${filtered.length} of ${widget.expenses.length} expenses'),
              const SizedBox(height: 18),
              TextField(
                controller: _search,
                decoration: InputDecoration(
                  labelText: 'Search expenses',
                  hintText: 'Description, category or account',
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: query.isEmpty
                      ? null
                      : IconButton(
                          tooltip: 'Clear search',
                          onPressed: () => setState(_search.clear),
                          icon: const Icon(Icons.close),
                        ),
                ),
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                key: ValueKey(account),
                initialValue: account ?? '',
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'Payment account'),
                items: [
                  const DropdownMenuItem(
                    value: '',
                    child: Text('All accounts'),
                  ),
                  ...accounts.map(
                    (a) => DropdownMenuItem(
                      value: a,
                      child: Text(a, overflow: TextOverflow.ellipsis),
                    ),
                  ),
                ],
                onChanged: (value) =>
                    setState(() => _account = value == '' ? null : value),
              ),
              Wrap(
                spacing: 12,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  FilterChip(
                    label: const Text('This month'),
                    selected: _thisMonth,
                    onSelected: (value) => setState(() => _thisMonth = value),
                  ),
                  TextButton(
                    onPressed: () => setState(() {
                      _search.clear();
                      _account = null;
                      _thisMonth = false;
                    }),
                    child: const Text('Reset filters'),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              if (filtered.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 24),
                  child: Text(
                    'No matching expenses. Clear the filters or add an expense.',
                  ),
                ),
            ],
          );
        }
        final expense = filtered[index - 1];
        return Card(
          child: ListTile(
            onTap: () => widget.onEdit(expense),
            title: Text(expense.description),
            subtitle: Text(
              '${expense.category}\n${expense.account} · ${dayKey(expense.date)}',
            ),
            isThreeLine: true,
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '₱${expense.amount.toStringAsFixed(2)}',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                PopupMenuButton<String>(
                  tooltip: 'Actions for ${expense.description}',
                  onSelected: (action) => action == 'edit'
                      ? widget.onEdit(expense)
                      : widget.onDelete(expense),
                  itemBuilder: (_) => const [
                    PopupMenuItem(value: 'edit', child: Text('Edit')),
                    PopupMenuItem(value: 'delete', child: Text('Delete')),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
