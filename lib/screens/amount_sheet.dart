import 'package:flutter/material.dart';

import '../data/format.dart';
import '../widgets/sheets.dart';
import '../widgets/widgets.dart';

/// Asks for a custom payment amount, capped at the open [balance].
Future<double?> showAmountSheet(BuildContext context, {required double balance}) =>
    showSheet<double>(context, (_) => _AmountSheet(balance: balance));

class _AmountSheet extends StatefulWidget {
  const _AmountSheet({required this.balance});

  final double balance;

  @override
  State<_AmountSheet> createState() => _AmountSheetState();
}

class _AmountSheetState extends State<_AmountSheet> {
  final _amount = TextEditingController();

  @override
  void dispose() {
    _amount.dispose();
    super.dispose();
  }

  void _use() {
    final v = parseAmount(_amount.text);
    if (v == null || v <= 0) {
      toast(context, 'Enter an amount');
      return;
    }
    if (v > widget.balance + 0.005) {
      toast(context, 'That is more than the ${money(widget.balance)} balance');
      return;
    }
    Navigator.of(context).pop(v);
  }

  @override
  Widget build(BuildContext context) {
    return SheetShell(
      title: 'Custom amount',
      subtitle: 'Balance ${money(widget.balance)}',
      saveLabel: 'Use this amount',
      onSave: _use,
      children: [
        SheetInput(
          label: 'Amount received',
          controller: _amount,
          hint: '0.00',
          mono: true,
          autofocus: true,
          keyboard: const TextInputType.numberWithOptions(decimal: true),
          onSubmit: _use,
        ),
      ],
    );
  }
}
