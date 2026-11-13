import 'package:flutter/material.dart';

import '../data/app_store.dart';
import '../data/format.dart';
import '../data/models.dart';
import '../motion/motion.dart';
import '../theme/tokens.dart';
import '../theme/typography.dart';
import '../widgets/widgets.dart';
import 'home.dart';

class InvoicesScreen extends StatefulWidget {
  const InvoicesScreen({super.key});

  @override
  State<InvoicesScreen> createState() => _InvoicesScreenState();
}

class _InvoicesScreenState extends State<InvoicesScreen> {
  static const _filters = ['All', 'Unpaid', 'Overdue', 'Paid'];
  int _filter = 0;
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final dl = context.dl;
    final store = AppScope.watch(context);
    final all = store.invoices;
    final q = _query.trim().toLowerCase();
    final visible = all.where((i) {
      final statusOk = switch (_filter) {
        1 => i.status == InvoiceStatus.unpaid,
        2 => i.status == InvoiceStatus.overdue,
        3 => i.isPaid,
        _ => true,
      };
      return statusOk &&
          (q.isEmpty || i.client.name.toLowerCase().contains(q) || i.number.toLowerCase().contains(q));
    }).toList();

    return ScreenScaffold(
      bottomPadding: 110,
      header: PageHeader(eyebrow: '${all.length} total', title: 'Invoices'),
      children: [
        ...stagger([
          SearchBox('Search by client or number', onChanged: (v) => setState(() => _query = v)),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: DaylitCard(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Eyebrow('Outstanding'),
                      const SizedBox(height: 4),
                      Text(money(store.totalOutstanding, cents: false),
                          style: Fonts.sans(size: 20, weight: FontWeight.w700, tracking: -0.02, color: dl.ink)),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: DaylitCard(
                  color: Palette.wine,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Eyebrow('Paid · 30d', color: Palette.lemon),
                      const SizedBox(height: 4),
                      Text(money(store.paidLast30, cents: false),
                          style: Fonts.sans(size: 20, weight: FontWeight.w700, tracking: -0.02, color: Palette.white)),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          ChipBar(labels: _filters, selected: _filter, onSelect: (i) => setState(() => _filter = i)),
          const SizedBox(height: 14),
        ]),
        AnimatedSwitcher(
          duration: Motion.standard,
          switchInCurve: Motion.emphasized,
          child: KeyedSubtree(
            key: ValueKey('$_filter-$q-${visible.length}'),
            child: visible.isEmpty
                ? EmptyState(
                    icon: Icons.receipt_long_outlined,
                    label: q.isNotEmpty ? 'No invoices match' : 'No ${_filters[_filter].toLowerCase()} invoices')
                : ListCard(children: [for (final inv in visible) InvoiceRow(inv)]),
          ),
        ),
      ],
    );
  }
}
