import 'package:flutter/material.dart';

import '../data/app_store.dart';
import '../data/format.dart';
import '../motion/motion.dart';
import '../theme/tokens.dart';
import '../theme/typography.dart';
import '../widgets/widgets.dart';
import 'expense_form.dart';
import 'home.dart';

class ExpensesScreen extends StatefulWidget {
  const ExpensesScreen({super.key});

  @override
  State<ExpensesScreen> createState() => _ExpensesScreenState();
}

class _ExpensesScreenState extends State<ExpensesScreen> {
  static const _filters = ['All', 'Software', 'Travel', 'Meals', 'Office'];
  int _filter = 0;

  @override
  Widget build(BuildContext context) {
    final dl = context.dl;
    final store = AppScope.watch(context);
    final expenses = store.expenses;
    final visible = _filter == 0 ? expenses : expenses.where((e) => e.category == _filters[_filter]).toList();
    final withReceipts = expenses.where((e) => e.hasReceipt).length;

    return ScreenScaffold(
      bottomPadding: 40,
      header: TopBar(
        title: 'Expenses',
        trailing: [
          IconSquare(Icons.add_rounded, filled: true, label: 'Add expense', onTap: () => showExpenseSheet(context)),
        ],
      ),
      children: [
        ...stagger([
          DaylitCard(
            color: Palette.wine,
            radius: 20,
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Eyebrow('Spent', color: Palette.lemon),
                      const SizedBox(height: 6),
                      Text(money(store.totalExpenses, cents: false),
                          style: Fonts.sans(size: 34, weight: FontWeight.w800, tracking: -0.03, color: Palette.white, height: 1)),
                      const SizedBox(height: 4),
                      Text('${plural(expenses.length, 'expense')} · $withReceipts with receipts',
                          style: Fonts.caption(Palette.rose)),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    const Eyebrow('Net', size: 9.5, color: Palette.rose),
                    const SizedBox(height: 2),
                    Text(money(store.totalPaid - store.totalExpenses, cents: false),
                        style: Fonts.sans(size: 17, weight: FontWeight.w700, color: Palette.lemon)),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          ChipBar(labels: _filters, selected: _filter, onSelect: (i) => setState(() => _filter = i)),
          const SizedBox(height: 14),
        ]),
        AnimatedSwitcher(
          duration: Motion.standard,
          switchInCurve: Motion.emphasized,
          child: KeyedSubtree(
            key: ValueKey('$_filter-${visible.length}'),
            child: visible.isEmpty
                ? const EmptyState(icon: Icons.receipt_long_outlined, label: 'No expenses here')
                : ListCard(
                    children: [
                      for (final e in visible)
                        RowTile(
                          leading: IconTile(e.icon, size: 38),
                          title: e.name,
                          subtitle: '${e.category} · ${fmtDate(e.date)}${e.hasReceipt ? '' : ' · no receipt'}',
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (e.hasReceipt) const Icon(Icons.receipt_outlined, size: 16, color: Palette.paidGreen),
                              SizedBox(
                                width: 64,
                                child: Text(money(e.amount, cents: false), textAlign: TextAlign.right, style: Fonts.amount(dl.ink)),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
          ),
        ),
      ],
    );
  }
}
