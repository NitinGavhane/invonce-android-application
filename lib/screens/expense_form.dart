import 'package:flutter/material.dart';

import '../data/app_store.dart';
import '../data/format.dart';
import '../data/models.dart';
import '../motion/motion.dart';
import '../widgets/sheets.dart';
import '../widgets/widgets.dart';

Future<Expense?> showExpenseSheet(BuildContext context) =>
    showSheet<Expense>(context, (_) => const _ExpenseSheet());

class _ExpenseSheet extends StatefulWidget {
  const _ExpenseSheet();

  @override
  State<_ExpenseSheet> createState() => _ExpenseSheetState();
}

class _ExpenseSheetState extends State<_ExpenseSheet> {
  static const _categories = ['Software', 'Travel', 'Meals', 'Office', 'Other'];

  final _name = TextEditingController();
  final _amount = TextEditingController();
  int _category = 0;
  bool _busy = false;

  @override
  void dispose() {
    _name.dispose();
    _amount.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final name = _name.text.trim();
    final amount = parseAmount(_amount.text);
    if (name.isEmpty) {
      toast(context, 'What was this expense for?');
      return;
    }
    if (amount == null || amount <= 0) {
      toast(context, 'Enter the amount');
      return;
    }
    setState(() => _busy = true);
    final store = AppScope.read(context);
    try {
      final e = await store.addExpense(name: name, category: _categories[_category], amount: amount, date: store.today);
      if (!mounted) return;
      Haptics.success();
      Navigator.of(context).pop(e);
    } catch (err) {
      if (mounted) {
        toast(context, "Couldn't save expense: $err");
        setState(() => _busy = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final store = AppScope.read(context);
    return SheetShell(
      title: 'New expense',
      subtitle: fmtDate(store.today, year: true),
      saveLabel: 'Save expense',
      busy: _busy,
      onSave: _save,
      children: [
        SheetInput(label: 'Description', controller: _name, hint: 'e.g. Client lunch', autofocus: true),
        SheetInput(
          label: 'Amount',
          controller: _amount,
          hint: '0.00',
          mono: true,
          keyboard: const TextInputType.numberWithOptions(decimal: true),
          onSubmit: _save,
        ),
        const SectionLabel('Category'),
        ChipBar(labels: _categories, selected: _category, onSelect: (i) => setState(() => _category = i)),
        DaylitButton('Attach receipt photo', variant: DaylitVariant.ghost, icon: Icons.photo_camera_outlined,
            onTap: () => toast(context, 'Camera & photo picker land with the iOS/Android builds')),
      ],
    );
  }
}
