import 'package:flutter/material.dart';

/// Direct actions shared by expense history, dashboard and calendar rows.
class ExpenseActions extends StatelessWidget {
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const ExpenseActions({
    super.key,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      IconButton(
        tooltip: 'Edit expense',
        onPressed: onEdit,
        icon: const Icon(Icons.edit_outlined),
        color: Theme.of(context).colorScheme.primary,
      ),
      IconButton(
        tooltip: 'Delete expense',
        onPressed: onDelete,
        icon: const Icon(Icons.delete_outline_rounded),
        color: const Color(0xFFDC5265),
      ),
    ],
  );
}
