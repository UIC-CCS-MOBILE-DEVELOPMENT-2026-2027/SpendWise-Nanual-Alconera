import 'package:flutter/material.dart';
import 'models/expense.dart';
import 'models/wallet.dart';

String _money(double value) => '₱${value.toStringAsFixed(2)}';

class WalletPanel extends StatefulWidget {
  final Wallet wallet;
  final List<Expense> expenses;
  final Future<bool> Function(Wallet) onSave;
  const WalletPanel({
    super.key,
    required this.wallet,
    required this.expenses,
    required this.onSave,
  });

  @override
  State<WalletPanel> createState() => _WalletPanelState();
}

class _WalletPanelState extends State<WalletPanel> {
  bool _saving = false;

  Future<void> _persist(Wallet wallet) async {
    setState(() => _saving = true);
    await widget.onSave(wallet);
    if (mounted) setState(() => _saving = false);
  }

  Future<void> _account([String? account]) async {
    final result = await showDialog<MapEntry<String, double>>(
      context: context,
      builder: (_) => _AccountDialog(account: account, wallet: widget.wallet),
    );
    if (result == null || !mounted) return;
    await _persist(
      Wallet(
        openingBalances: {
          ...widget.wallet.openingBalances,
          result.key: result.value,
        },
        transfers: widget.wallet.transfers,
      ),
    );
  }

  Future<void> _transfer() async {
    final result = await showDialog<Transfer>(
      context: context,
      builder: (_) =>
          _TransferDialog(wallet: widget.wallet, expenses: widget.expenses),
    );
    if (result == null || !mounted) return;
    await _persist(
      Wallet(
        openingBalances: widget.wallet.openingBalances,
        transfers: [...widget.wallet.transfers, result],
      ),
    );
  }

  Future<void> _deleteTransfer(Transfer transfer) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete transfer?'),
        content: const Text(
          'This reverses the movement between these accounts.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    await _persist(
      Wallet(
        openingBalances: widget.wallet.openingBalances,
        transfers: widget.wallet.transfers
            .where((t) => t.id != transfer.id)
            .toList(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final accounts = {
      ...widget.wallet.openingBalances.keys,
      ...widget.expenses.map((e) => e.account),
    };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Accounts',
          style: TextStyle(fontSize: 19, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        const Text(
          'Set opening balances before your recorded expenses. Older expenses use Cash on Hand; edit them to change the account.',
        ),
        const SizedBox(height: 8),
        for (final account in accounts)
          Card(
            child: ListTile(
              title: Text(account),
              subtitle: Text(
                _money(widget.wallet.balance(account, widget.expenses)),
              ),
              trailing: const Icon(Icons.edit_outlined),
              onTap: _saving ? null : () => _account(account),
            ),
          ),
        Wrap(
          spacing: 8,
          children: [
            TextButton.icon(
              onPressed: _saving ? null : () => _account(),
              icon: const Icon(Icons.add),
              label: const Text('Add account'),
            ),
            TextButton.icon(
              onPressed: _saving ? null : _transfer,
              icon: const Icon(Icons.swap_horiz),
              label: const Text('Transfer / withdraw'),
            ),
          ],
        ),
        if (_saving) const LinearProgressIndicator(),
        if (widget.wallet.transfers.isNotEmpty)
          ExpansionTile(
            title: const Text('Transfer history'),
            subtitle: const Text('Transfers do not count as expenses.'),
            children: [
              for (final transfer in widget.wallet.transfers.reversed)
                ListTile(
                  title: Text('${transfer.from} → ${transfer.to}'),
                  subtitle: Text(
                    '${_money(transfer.amount)} · ${transfer.date.toLocal().toString().split('.').first}',
                  ),
                  trailing: IconButton(
                    tooltip: 'Delete transfer',
                    onPressed: _saving ? null : () => _deleteTransfer(transfer),
                    icon: const Icon(Icons.delete_outline),
                  ),
                ),
            ],
          ),
      ],
    );
  }
}

class _AccountDialog extends StatefulWidget {
  final String? account;
  final Wallet wallet;
  const _AccountDialog({this.account, required this.wallet});
  @override
  State<_AccountDialog> createState() => _AccountDialogState();
}

class _AccountDialogState extends State<_AccountDialog> {
  final _form = GlobalKey<FormState>();
  late final _name = TextEditingController(text: widget.account ?? '');
  late final _amount = TextEditingController(
    text: (widget.wallet.openingBalances[widget.account] ?? 0).toStringAsFixed(
      2,
    ),
  );
  @override
  void dispose() {
    _name.dispose();
    _amount.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(widget.account == null ? 'Add account' : 'Opening balance'),
    content: SingleChildScrollView(
      child: Form(
        key: _form,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextFormField(
              controller: _name,
              enabled: widget.account == null,
              decoration: const InputDecoration(labelText: 'Account name'),
              validator: (value) {
                final name = value?.trim() ?? '';
                if (name.isEmpty || name.length > 40) {
                  return 'Use a name of 1–40 characters.';
                }
                if (widget.account == null &&
                    widget.wallet.openingBalances.keys.any(
                      (key) => key.toLowerCase() == name.toLowerCase(),
                    )) {
                  return 'This account already exists.';
                }
                return null;
              },
            ),
            TextFormField(
              controller: _amount,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: const InputDecoration(
                labelText: 'Opening balance (PHP)',
              ),
              validator: (value) {
                final amount = double.tryParse(value ?? '');
                return amount == null ||
                        !amount.isFinite ||
                        amount < 0 ||
                        amount > 1000000000
                    ? 'Enter an amount from 0 to 1 billion.'
                    : null;
              },
            ),
            const SizedBox(height: 12),
            const Text(
              'Enter the balance before all expenses and transfers recorded in this app. This is not income or an expense.',
            ),
          ],
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Cancel'),
      ),
      FilledButton(
        onPressed: () {
          if (_form.currentState!.validate()) {
            Navigator.pop(
              context,
              MapEntry(_name.text.trim(), double.parse(_amount.text)),
            );
          }
        },
        child: const Text('Save account'),
      ),
    ],
  );
}

class _TransferDialog extends StatefulWidget {
  final Wallet wallet;
  final List<Expense> expenses;
  const _TransferDialog({required this.wallet, required this.expenses});
  @override
  State<_TransferDialog> createState() => _TransferDialogState();
}

class _TransferDialogState extends State<_TransferDialog> {
  final _form = GlobalKey<FormState>();
  final _amount = TextEditingController();
  late String _from = widget.wallet.openingBalances.keys.first;
  late String _to = widget.wallet.openingBalances.keys.last;
  @override
  void dispose() {
    _amount.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Transfer / withdraw'),
    content: SingleChildScrollView(
      child: Form(
        key: _form,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            DropdownButtonFormField<String>(
              initialValue: _from,
              isExpanded: true,
              decoration: const InputDecoration(labelText: 'From'),
              items: widget.wallet.openingBalances.keys
                  .map((a) => DropdownMenuItem(value: a, child: Text(a)))
                  .toList(),
              onChanged: (value) => setState(() => _from = value!),
            ),
            DropdownButtonFormField<String>(
              initialValue: _to,
              isExpanded: true,
              decoration: const InputDecoration(labelText: 'To'),
              items: widget.wallet.openingBalances.keys
                  .map((a) => DropdownMenuItem(value: a, child: Text(a)))
                  .toList(),
              onChanged: (value) => setState(() => _to = value!),
              validator: (_) =>
                  _from == _to ? 'Choose a different account.' : null,
            ),
            TextFormField(
              controller: _amount,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: const InputDecoration(labelText: 'Amount (PHP)'),
              validator: (value) {
                final amount = double.tryParse(value ?? '');
                if (amount == null ||
                    !amount.isFinite ||
                    amount <= 0 ||
                    amount > 1000000000) {
                  return 'Enter a valid positive amount.';
                }
                if (amount > widget.wallet.balance(_from, widget.expenses)) {
                  return 'Insufficient funds in this account.';
                }
                return null;
              },
            ),
            const SizedBox(height: 12),
            const Text(
              'For withdrawals, transfer to Cash on Hand. Record any withdrawal fee separately as an expense paid from the account charged.',
            ),
          ],
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Cancel'),
      ),
      FilledButton(
        onPressed: () {
          if (!_form.currentState!.validate()) return;
          final now = DateTime.now();
          Navigator.pop(
            context,
            Transfer(
              id: now.microsecondsSinceEpoch.toString(),
              from: _from,
              to: _to,
              amount: double.parse(_amount.text),
              date: now,
            ),
          );
        },
        child: const Text('Save transfer'),
      ),
    ],
  );
}
