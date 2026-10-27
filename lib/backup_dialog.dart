import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'services/expense_storage.dart';

class BackupDialog extends StatefulWidget {
  final ExpenseStorage storage;
  final bool recovery;
  const BackupDialog({super.key, required this.storage, this.recovery = false});
  @override
  State<BackupDialog> createState() => _BackupDialogState();
}

class _BackupDialogState extends State<BackupDialog> {
  final _input = TextEditingController();
  bool _busy = false;
  String? _message;
  @override
  void dispose() {
    _input.dispose();
    super.dispose();
  }

  Future<void> _copy() async {
    setState(() => _busy = true);
    try {
      final text = widget.recovery
          ? await widget.storage.exportRecoveryData()
          : await widget.storage.exportBackup();
      await Clipboard.setData(ClipboardData(text: text));
      if (mounted) {
        setState(
          () => _message = widget.recovery
              ? 'Recovery data copied. Save it securely for troubleshooting; this is not a restorable backup.'
              : 'Backup copied. Paste it into a text file and save it somewhere private.',
        );
      }
    } catch (_) {
      if (mounted) {
        setState(() => _message = 'Could not copy the data. Please try again.');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _restore() async {
    Map<String, dynamic> data;
    try {
      data = ExpenseStorage.validateBackup(_input.text);
    } catch (_) {
      setState(
        () => _message =
            'This is not a valid SpendWise backup. No records were changed.',
      );
      return;
    }
    final count = (data['expenses'] as List).length;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Replace saved data?'),
        content: Text(
          'Restore $count expenses and the accounts, budgets and rewards in this backup? This replaces your current records. A recovery copy of the current data will be kept on this device.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Restore backup'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _busy = true);
    try {
      final saved = await widget.storage.restoreBackup(_input.text);
      if (!mounted) return;
      if (saved) {
        Navigator.pop(context, true);
        return;
      }
      setState(
        () => _message =
            'Restore failed. Your current records were not replaced.',
      );
    } catch (_) {
      if (mounted) {
        setState(() => _message = 'Restore failed. Please try again.');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    scrollable: true,
    title: const Text('Backup and restore'),
    content: SizedBox(
      width: 480,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Backups contain your financial information. Keep copied text private. They are not encrypted.',
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: _busy ? null : _copy,
            icon: const Icon(Icons.copy),
            label: Text(widget.recovery ? 'Copy recovery data' : 'Copy backup'),
          ),
          const SizedBox(height: 20),
          TextField(
            controller: _input,
            enabled: !_busy,
            maxLines: 4,
            maxLength: 2000000,
            decoration: const InputDecoration(
              labelText: 'Paste a SpendWise backup to restore',
            ),
          ),
          if (_message != null)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Text(_message!, semanticsLabel: _message),
            ),
          if (_busy) const LinearProgressIndicator(),
        ],
      ),
    ),
    actions: [
      TextButton(
        onPressed: _busy ? null : () => Navigator.pop(context),
        child: const Text('Close'),
      ),
      TextButton(
        onPressed: _busy ? null : _restore,
        child: const Text('Review restore'),
      ),
    ],
  );
}
