import 'package:flutter/material.dart';

import 'models/expense.dart';
import 'models/wallet.dart';

String _money(double value) => '₱${value.toStringAsFixed(2)}';

const _navy = Color(0xFF111426);
const _surface = Color(0xFF1C2035);
const _emerald = Color(0xFF38D9A9);

class WalletPanel extends StatefulWidget {
  final Wallet wallet;
  final List<Expense> expenses;
  final Future<bool> Function(Wallet) onSave;
  final Future<bool> Function({
    required Wallet wallet,
    required List<Expense> expenses,
  })
  onUpdateAccountData;
  final Color primaryColor;

  const WalletPanel({
    super.key,
    required this.wallet,
    required this.expenses,
    required this.onSave,
    required this.onUpdateAccountData,
    required this.primaryColor,
  });

  @override
  State<WalletPanel> createState() => _WalletPanelState();
}

class _WalletPanelState extends State<WalletPanel> {
  bool _saving = false;

  List<String> get _accounts {
    final names = <String>{
      ...widget.wallet.openingBalances.keys,
      ...widget.expenses.map((e) => e.account),
      for (final transfer in widget.wallet.transfers) ...[
        transfer.from,
        transfer.to,
      ],
    }.toList();

    names.sort((a, b) {
      if (a == 'Cash on Hand') return -1;
      if (b == 'Cash on Hand') return 1;
      return a.toLowerCase().compareTo(b.toLowerCase());
    });

    return names;
  }

  double get _totalBalance {
    return _accounts.fold<double>(
      0,
      (total, account) =>
          total + widget.wallet.balance(account, widget.expenses),
    );
  }

  void _message(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
      );
  }

  Future<void> _persist(Wallet wallet) async {
    if (_saving) return;

    setState(() => _saving = true);

    var success = false;

    try {
      success = await widget.onSave(wallet);
    } catch (error, stackTrace) {
      debugPrint('Failed to save wallet: $error');
      debugPrintStack(stackTrace: stackTrace);
    }

    if (!mounted) return;

    setState(() => _saving = false);

    _message(
      success
          ? 'Changes saved successfully.'
          : 'Could not save changes. Please try again.',
    );
  }

  Future<void> _account([String? account]) async {
    if (_saving) return;

    final accountsBeforeDialog = _accounts;

    if (account != null && !accountsBeforeDialog.contains(account)) {
      _message('This account could not be found. Refresh and try again.');
      return;
    }

    final result = await showDialog<MapEntry<String, double>>(
      context: context,
      builder: (_) => _AccountDialog(
        account: account,
        wallet: widget.wallet,
        existingAccounts: accountsBeforeDialog,
        primaryColor: widget.primaryColor,
      ),
    );

    if (result == null || !mounted) return;

    final newName = result.key.trim();
    final enteredOpeningBalance = result.value;

    if (newName.isEmpty || newName.length > 40) {
      _message('Use an account name of 1–40 characters.');
      return;
    }

    final duplicate = accountsBeforeDialog.any(
      (name) => name.toLowerCase() == newName.toLowerCase() && name != account,
    );

    if (duplicate) {
      _message('An account with that name already exists.');
      return;
    }

    // Create a new account.
    if (account == null) {
      final updatedBalances = Map<String, double>.from(
        widget.wallet.openingBalances,
      );

      updatedBalances[newName] = enteredOpeningBalance;

      await _persist(
        Wallet(
          openingBalances: updatedBalances,
          transfers: widget.wallet.transfers,
        ),
      );

      return;
    }

    // Preserve the existing opening balance if the dialog's balance
    // was not changed. This is especially useful for accounts whose
    // opening balance was not previously stored explicitly.
    final previousOpeningBalance =
        widget.wallet.openingBalances[account] ?? 0.0;

    final updatedOpeningBalances = Map<String, double>.from(
      widget.wallet.openingBalances,
    );

    updatedOpeningBalances.remove(account);
    updatedOpeningBalances[newName] = enteredOpeningBalance;

    final updatedTransfers = widget.wallet.transfers.map((transfer) {
      return Transfer(
        id: transfer.id,
        from: transfer.from == account ? newName : transfer.from,
        to: transfer.to == account ? newName : transfer.to,
        amount: transfer.amount,
        date: transfer.date,
      );
    }).toList();

    final updatedExpenses = widget.expenses.map((expense) {
      return expense.account == account
          ? expense.copyWith(account: newName)
          : expense;
    }).toList();

    final updatedWallet = Wallet(
      openingBalances: updatedOpeningBalances,
      transfers: updatedTransfers,
    );

    setState(() => _saving = true);

    var success = false;

    try {
      success = await widget.onUpdateAccountData(
        wallet: updatedWallet,
        expenses: updatedExpenses,
      );
    } catch (error, stackTrace) {
      debugPrint('Failed to update account data: $error');
      debugPrintStack(stackTrace: stackTrace);
    }

    if (!mounted) return;

    setState(() => _saving = false);

    _message(
      success
          ? (newName == account
                ? 'Account updated successfully.'
                : 'Account renamed successfully.')
          : 'Could not save the account changes. Please try again.',
    );

    // Keep the local variable intentionally referenced for clarity:
    // accounts without an explicit opening balance default to zero.
    assert(previousOpeningBalance.isFinite);
  }

  Future<void> _deleteAccount(String account) async {
    if (_saving) return;

    final hasExpenses = widget.expenses.any(
      (expense) => expense.account == account,
    );

    final hasTransfers = widget.wallet.transfers.any(
      (transfer) => transfer.from == account || transfer.to == account,
    );

    final balance = widget.wallet.balance(account, widget.expenses);
    final hasNonzeroBalance = balance.abs() > 0.005;

    // Keep financial records safe. Rename the account instead if
    // it has recorded activity or money remaining.
    if (hasExpenses || hasTransfers || hasNonzeroBalance) {
      final reasons = <String>[
        if (hasExpenses) 'recorded expenses',
        if (hasTransfers) 'transfer history',
        if (hasNonzeroBalance) 'a nonzero balance',
      ];

      _message(
        'Cannot delete this account because it has '
        '${reasons.join(', ')}. Rename it if you want a different name.',
      );

      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete account?'),
        content: Text('Delete "$account"? This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: FilledButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Delete account'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    final updatedOpeningBalances = Map<String, double>.from(
      widget.wallet.openingBalances,
    )..remove(account);

    await _persist(
      Wallet(
        openingBalances: updatedOpeningBalances,
        transfers: widget.wallet.transfers,
      ),
    );
  }

  Future<void> _transfer() async {
    if (_saving) return;

    final availableAccounts = _accounts.isEmpty
        ? <String>['Cash on Hand']
        : _accounts;

    if (availableAccounts.length < 2) {
      _message('Add at least two accounts to make a transfer.');
      return;
    }

    final result = await showDialog<Transfer>(
      context: context,
      builder: (_) => _TransferDialog(
        wallet: widget.wallet,
        expenses: widget.expenses,
        accounts: availableAccounts,
        primaryColor: widget.primaryColor,
      ),
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
    if (_saving) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete transfer?'),
        content: const Text(
          'This removes the transfer and reverses its effect on '
          'the balances of the two accounts.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Keep transfer'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: FilledButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Delete transfer'),
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

  IconData _accountIcon(String name) {
    final value = name.toLowerCase();

    if (value.contains('cash')) return Icons.payments_rounded;
    if (value.contains('bank')) return Icons.account_balance_rounded;

    if (value.contains('gcash') ||
        value.contains('maya') ||
        value.contains('wallet')) {
      return Icons.account_balance_wallet_rounded;
    }

    if (value.contains('savings')) return Icons.savings_rounded;
    if (value.contains('credit')) return Icons.credit_card_rounded;

    return Icons.wallet_rounded;
  }

  Color _accountColor(int index) {
    final colors = [
      widget.primaryColor,
      _emerald,
      const Color(0xFFFFC857),
      const Color(0xFF54A6FF),
      const Color(0xFFFF8A65),
    ];

    return colors[index % colors.length];
  }

  String _dateLabel(DateTime date) {
    final local = date.toLocal();
    final day = local.day.toString().padLeft(2, '0');
    final month = local.month.toString().padLeft(2, '0');
    final hour = local.hour.toString().padLeft(2, '0');
    final minute = local.minute.toString().padLeft(2, '0');

    return '$month/$day/${local.year} · $hour:$minute';
  }

  @override
  Widget build(BuildContext context) {
    final accounts = _accounts;
    final transfers = widget.wallet.transfers.reversed.toList();
    final theme = Theme.of(context);
    final primary = widget.primaryColor;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: primary.withValues(alpha: 0.16),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(
                Icons.account_balance_wallet_rounded,
                color: primary,
                size: 23,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'My Accounts',
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  Text(
                    '${accounts.length} '
                    '${accounts.length == 1 ? 'account' : 'accounts'} connected',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            IconButton.filledTonal(
              tooltip: 'Add account',
              onPressed: _saving ? null : () => _account(),
              icon: const Icon(Icons.add_rounded),
            ),
          ],
        ),
        const SizedBox(height: 18),

        // Total balance.
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(22),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Color.lerp(primary, Colors.black, 0.15)!,
                Color.lerp(primary, _navy, 0.50)!,
                _navy,
              ],
            ),
            border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
            boxShadow: [
              BoxShadow(
                color: primary.withValues(alpha: 0.12),
                blurRadius: 22,
                offset: const Offset(0, 9),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.account_balance_rounded,
                    size: 18,
                    color: Colors.white.withValues(alpha: 0.78),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'TOTAL ACCOUNT BALANCE',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: Colors.white.withValues(alpha: 0.78),
                        letterSpacing: 1.1,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(
                  _money(_totalBalance),
                  style: theme.textTheme.headlineMedium?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.8,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Across all your tracked accounts',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: Colors.white.withValues(alpha: 0.72),
                ),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: _SummaryItem(
                      icon: Icons.wallet_outlined,
                      label: 'ACCOUNTS',
                      value: '${accounts.length}',
                    ),
                  ),
                  Container(
                    width: 1,
                    height: 36,
                    color: Colors.white.withValues(alpha: 0.20),
                  ),
                  const SizedBox(width: 18),
                  Expanded(
                    child: _SummaryItem(
                      icon: Icons.swap_horiz_rounded,
                      label: 'TRANSFERS',
                      value: '${widget.wallet.transfers.length}',
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),

        const SizedBox(height: 24),

        Row(
          children: [
            Expanded(
              child: Text(
                'Your accounts',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            TextButton.icon(
              onPressed: _saving ? null : () => _account(),
              icon: const Icon(Icons.add_rounded, size: 18),
              label: const Text('Add account'),
            ),
          ],
        ),
        const SizedBox(height: 8),

        if (accounts.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
            decoration: BoxDecoration(
              color: _surface,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.white.withValues(alpha: 0.07)),
            ),
            child: Column(
              children: [
                Icon(
                  Icons.account_balance_wallet_outlined,
                  size: 42,
                  color: primary,
                ),
                const SizedBox(height: 12),
                Text(
                  'Start with your first account',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 6),
                Text(
                  'Add your cash, bank, or e-wallet balance to '
                  'start tracking your money.',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 16),
                FilledButton.icon(
                  onPressed: _saving ? null : () => _account(),
                  icon: const Icon(Icons.add_rounded),
                  label: const Text('Create account'),
                  style: FilledButton.styleFrom(backgroundColor: primary),
                ),
              ],
            ),
          )
        else
          for (var i = 0; i < accounts.length; i++)
            _AccountCard(
              name: accounts[i],
              balance: widget.wallet.balance(accounts[i], widget.expenses),
              icon: _accountIcon(accounts[i]),
              color: _accountColor(i),
              openingBalanceSet: widget.wallet.openingBalances.containsKey(
                accounts[i],
              ),
              onTap: _saving ? null : () => _account(accounts[i]),
              onDelete: _saving ? null : () => _deleteAccount(accounts[i]),
            ),

        const SizedBox(height: 12),

        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _saving ? null : () => _account(),
                icon: const Icon(Icons.add_card_rounded),
                label: const Text('New account'),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 15),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: FilledButton.icon(
                onPressed: _saving ? null : _transfer,
                icon: const Icon(Icons.swap_horiz_rounded),
                label: const Text('Transfer / withdraw'),
                style: FilledButton.styleFrom(
                  backgroundColor: primary,
                  padding: const EdgeInsets.symmetric(vertical: 15),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              ),
            ),
          ],
        ),

        if (_saving) ...[
          const SizedBox(height: 12),
          LinearProgressIndicator(color: primary),
        ],

        const SizedBox(height: 24),

        // Transfer history.
        Container(
          decoration: BoxDecoration(
            color: _surface,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white.withValues(alpha: 0.07)),
          ),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 12, 14),
                child: Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: _emerald.withValues(alpha: 0.13),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.swap_horiz_rounded,
                        color: _emerald,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Transfer history',
                            style: theme.textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          Text(
                            'Money moved between accounts',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Text(
                      '${transfers.length}',
                      style: theme.textTheme.labelLarge?.copyWith(
                        color: _emerald,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
              Divider(height: 1, color: Colors.white.withValues(alpha: 0.07)),
              if (transfers.isEmpty)
                Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    children: [
                      Icon(
                        Icons.receipt_long_outlined,
                        size: 32,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'No transfers yet',
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Your account movements will appear here.',
                        textAlign: TextAlign.center,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                )
              else
                for (var i = 0; i < transfers.length; i++) ...[
                  ListTile(
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 5,
                    ),
                    leading: Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        color: _emerald.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(13),
                      ),
                      child: const Icon(
                        Icons.swap_horiz_rounded,
                        color: _emerald,
                      ),
                    ),
                    title: Text(
                      '${transfers[i].from} → ${transfers[i].to}',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    subtitle: Text(_dateLabel(transfers[i].date)),
                    trailing: SizedBox(
                      width: 108,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          Expanded(
                            child: FittedBox(
                              fit: BoxFit.scaleDown,
                              alignment: Alignment.centerRight,
                              child: Text(
                                _money(transfers[i].amount),
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  color: _emerald,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                          ),
                          IconButton(
                            visualDensity: VisualDensity.compact,
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(
                              minWidth: 32,
                              minHeight: 32,
                            ),
                            tooltip: 'Delete transfer',
                            onPressed: _saving
                                ? null
                                : () => _deleteTransfer(transfers[i]),
                            icon: const Icon(
                              Icons.delete_outline_rounded,
                              size: 19,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  if (i != transfers.length - 1)
                    Divider(
                      height: 1,
                      indent: 16,
                      endIndent: 16,
                      color: Colors.white.withValues(alpha: 0.05),
                    ),
                ],
            ],
          ),
        ),

        const SizedBox(height: 12),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              Icons.info_outline_rounded,
              size: 17,
              color: theme.colorScheme.onSurfaceVariant,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Opening balances represent the money you had before '
                'recording expenses and transfers in SpendWise. Transfers '
                'move money between accounts and are not expenses.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                  height: 1.5,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _SummaryItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _SummaryItem({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 20, color: Colors.white.withValues(alpha: 0.82)),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 10,
                  letterSpacing: 0.8,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                value,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _AccountCard extends StatelessWidget {
  final String name;
  final double balance;
  final IconData icon;
  final Color color;
  final bool openingBalanceSet;
  final VoidCallback? onTap;
  final VoidCallback? onDelete;

  const _AccountCard({
    required this.name,
    required this.balance,
    required this.icon,
    required this.color,
    required this.openingBalanceSet,
    required this.onTap,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      elevation: 0,
      color: _surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(19),
        side: BorderSide(color: Colors.white.withValues(alpha: 0.07)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(15),
              ),
              child: Icon(icon, color: color, size: 24),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    openingBalanceSet
                        ? 'Tracked account'
                        : 'Opening balance not set',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: openingBalanceSet
                          ? theme.colorScheme.onSurfaceVariant
                          : const Color(0xFFFFC857),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    _money(balance),
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w900,
                      letterSpacing: -0.3,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      OutlinedButton.icon(
                        onPressed: onTap,
                        icon: const Icon(Icons.edit_outlined, size: 16),
                        label: const Text('Edit'),
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size(0, 36),
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                        ),
                      ),
                      OutlinedButton.icon(
                        onPressed: onDelete,
                        icon: const Icon(
                          Icons.delete_outline_rounded,
                          size: 16,
                        ),
                        label: const Text('Delete'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.redAccent,
                          side: const BorderSide(color: Colors.redAccent),
                          minimumSize: const Size(0, 36),
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AccountDialog extends StatefulWidget {
  final String? account;
  final Wallet wallet;
  final List<String> existingAccounts;
  final Color primaryColor;

  const _AccountDialog({
    this.account,
    required this.wallet,
    required this.existingAccounts,
    required this.primaryColor,
  });

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
  Widget build(BuildContext context) {
    final primary = widget.primaryColor;

    return AlertDialog(
      scrollable: true,
      title: Text(widget.account == null ? 'Create account' : 'Edit account'),
      content: Form(
        key: _form,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.account == null
                  ? 'Give your account a name and set its starting balance.'
                  : 'Update the account name or its starting balance.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 18),
            TextFormField(
              controller: _name,
              textCapitalization: TextCapitalization.words,
              textInputAction: TextInputAction.next,
              maxLength: 40,
              decoration: const InputDecoration(
                labelText: 'Account name',
                hintText: 'e.g. Cash on Hand, E-Wallet, Savings',
                prefixIcon: Icon(Icons.account_balance_wallet_outlined),
                border: OutlineInputBorder(),
              ),
              validator: (value) {
                final name = value?.trim() ?? '';

                if (name.isEmpty) {
                  return 'Enter an account name.';
                }

                final duplicate = widget.existingAccounts.any(
                  (existing) =>
                      existing.toLowerCase() == name.toLowerCase() &&
                      existing != widget.account,
                );

                if (duplicate) {
                  return 'This account already exists.';
                }

                return null;
              },
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _amount,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              textInputAction: TextInputAction.done,
              decoration: const InputDecoration(
                labelText: 'Opening balance',
                prefixText: '₱ ',
                prefixIcon: Icon(Icons.payments_outlined),
                border: OutlineInputBorder(),
              ),
              validator: (value) {
                final amount = double.tryParse(value?.trim() ?? '');

                if (amount == null ||
                    !amount.isFinite ||
                    amount < 0 ||
                    amount > 1000000000) {
                  return 'Enter an amount from 0 to 1 billion.';
                }

                return null;
              },
            ),
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: primary.withValues(alpha: 0.09),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.info_outline_rounded, size: 18, color: primary),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      'Enter the balance before the expenses and '
                      'transfers recorded in SpendWise. This is not '
                      'income or an expense.',
                      style: TextStyle(height: 1.45),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton.icon(
          onPressed: () {
            if (!_form.currentState!.validate()) return;

            final name = _name.text.trim();
            final amount = double.parse(_amount.text.trim());

            Navigator.pop(context, MapEntry<String, double>(name, amount));
          },
          icon: const Icon(Icons.check_rounded),
          label: Text(
            widget.account == null ? 'Create account' : 'Save changes',
          ),
          style: FilledButton.styleFrom(backgroundColor: primary),
        ),
      ],
    );
  }
}

class _TransferDialog extends StatefulWidget {
  final Wallet wallet;
  final List<Expense> expenses;
  final List<String> accounts;
  final Color primaryColor;

  const _TransferDialog({
    required this.wallet,
    required this.expenses,
    required this.accounts,
    required this.primaryColor,
  });

  @override
  State<_TransferDialog> createState() => _TransferDialogState();
}

class _TransferDialogState extends State<_TransferDialog> {
  final _form = GlobalKey<FormState>();
  final _amount = TextEditingController();

  late String _from = widget.accounts.first;
  late String _to = widget.accounts.firstWhere(
    (account) => account != _from,
    orElse: () => _from,
  );

  double get _availableBalance => widget.wallet.balance(_from, widget.expenses);

  @override
  void dispose() {
    _amount.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primary = widget.primaryColor;

    return AlertDialog(
      scrollable: true,
      title: const Text('Transfer money'),
      content: Form(
        key: _form,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Move money between your accounts without recording '
              'an expense.',
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: 18),
            DropdownButtonFormField<String>(
              initialValue: _from,
              isExpanded: true,
              decoration: const InputDecoration(
                labelText: 'From account',
                prefixIcon: Icon(Icons.call_made_rounded),
                border: OutlineInputBorder(),
              ),
              items: widget.accounts
                  .map(
                    (account) => DropdownMenuItem(
                      value: account,
                      child: Text(account, overflow: TextOverflow.ellipsis),
                    ),
                  )
                  .toList(),
              onChanged: (value) {
                if (value == null) return;

                setState(() {
                  _from = value;

                  if (_from == _to) {
                    _to = widget.accounts.firstWhere(
                      (account) => account != _from,
                      orElse: () => _from,
                    );
                  }
                });
              },
            ),
            const SizedBox(height: 12),
            Center(
              child: Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: primary.withValues(alpha: 0.13),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.south_rounded, color: primary),
              ),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: _to,
              isExpanded: true,
              decoration: const InputDecoration(
                labelText: 'To account',
                prefixIcon: Icon(Icons.call_received_rounded),
                border: OutlineInputBorder(),
              ),
              items: widget.accounts
                  .map(
                    (account) => DropdownMenuItem(
                      value: account,
                      child: Text(account, overflow: TextOverflow.ellipsis),
                    ),
                  )
                  .toList(),
              onChanged: (value) {
                if (value != null) setState(() => _to = value);
              },
              validator: (_) {
                if (_from == _to) {
                  return 'Choose a different destination.';
                }

                return null;
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _amount,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: const InputDecoration(
                labelText: 'Transfer amount',
                prefixText: '₱ ',
                prefixIcon: Icon(Icons.payments_outlined),
                border: OutlineInputBorder(),
              ),
              validator: (value) {
                final amount = double.tryParse(value?.trim() ?? '');

                if (amount == null ||
                    !amount.isFinite ||
                    amount <= 0 ||
                    amount > 1000000000) {
                  return 'Enter a valid positive amount.';
                }

                if (amount > _availableBalance) {
                  return 'Insufficient funds in this account.';
                }

                return null;
              },
            ),
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: _emerald.withValues(alpha: 0.09),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.account_balance_wallet_outlined,
                    size: 19,
                    color: _emerald,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Available balance',
                          style: TextStyle(fontSize: 12),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          _money(_availableBalance),
                          style: const TextStyle(fontWeight: FontWeight.w800),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'For a cash withdrawal, transfer to Cash on Hand. '
              'Record any withdrawal fee separately as an expense.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                height: 1.45,
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton.icon(
          onPressed: () {
            if (!_form.currentState!.validate()) return;

            final now = DateTime.now();

            Navigator.pop(
              context,
              Transfer(
                id: now.microsecondsSinceEpoch.toString(),
                from: _from,
                to: _to,
                amount: double.parse(_amount.text.trim()),
                date: now,
              ),
            );
          },
          icon: const Icon(Icons.check_rounded),
          label: const Text('Confirm transfer'),
          style: FilledButton.styleFrom(backgroundColor: primary),
        ),
      ],
    );
  }
}
