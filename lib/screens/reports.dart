import 'package:flutter/material.dart';

import '../data/app_store.dart';
import '../data/format.dart';
import '../data/models.dart';
import '../motion/motion.dart';
import '../theme/tokens.dart';
import '../theme/typography.dart';
import '../widgets/widgets.dart';

class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  @override
  void initState() {
    super.initState();
    // Online totals come from their own table; fetch once the page is up.
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      try {
        await AppScope.read(context).refreshOnline();
      } catch (_) {
        // Card simply stays hidden.
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final dl = context.dl;
    final store = AppScope.watch(context);
    final online = store.online;
    final months = store.monthlyRevenue;
    final maxRevenue = months.map((m) => m.$2).fold<double>(0, (a, b) => a > b ? a : b);
    final invoices = store.invoices;
    final unpaid = invoices.where((i) => i.status == InvoiceStatus.unpaid).toList();
    final overdue = invoices.where((i) => i.status == InvoiceStatus.overdue).toList();
    final paid = invoices.where((i) => i.isPaid).toList();
    final last = months.length - 1;

    return ScreenScaffold(
      bottomPadding: 40,
      header: TopBar(
        title: 'Reports',
        trailing: [
          DaylitChip('${store.today.year} ▾', active: true, onTap: () => toast(context, 'Custom date ranges are coming next')),
        ],
      ),
      children: stagger([
        Row(
          children: [
            Expanded(
              child: DaylitCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Eyebrow('Total paid', size: 10),
                    const SizedBox(height: 4),
                    Text(money(store.totalPaid, cents: false), style: Fonts.sans(size: 24, weight: FontWeight.w800, tracking: -0.03, color: dl.ink)),
                    const SizedBox(height: 4),
                    Text(plural(paid.length, 'invoice'), style: Fonts.sans(size: 12, weight: FontWeight.w600, color: Palette.paidText)),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: DaylitCard(
                color: Palette.wine,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Eyebrow('Outstanding', size: 10, color: Palette.lemon),
                    const SizedBox(height: 4),
                    Text(money(store.totalOutstanding, cents: false), style: Fonts.sans(size: 24, weight: FontWeight.w800, tracking: -0.03, color: Palette.white)),
                    const SizedBox(height: 4),
                    Text(plural(unpaid.length + overdue.length, 'open invoice'), style: Fonts.sans(size: 12, weight: FontWeight.w600, color: Palette.rose)),
                  ],
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        DaylitCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Expanded(child: Text('Revenue', style: Fonts.sans(size: 16, weight: FontWeight.w700, color: dl.ink))),
                  const Eyebrow('Last 6 months', size: 10),
                ],
              ),
              const SizedBox(height: 10),
              SizedBox(
                height: 150,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    for (var i = 0; i < months.length; i++) ...[
                      if (i > 0) const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            Expanded(
                              child: Align(
                                alignment: Alignment.bottomCenter,
                                child: FractionallySizedBox(
                                  heightFactor: maxRevenue == 0 ? 0.04 : (months[i].$2 / maxRevenue).clamp(0.04, 1.0),
                                  child: GrowIn(
                                    child: Container(
                                      width: double.infinity,
                                      decoration: BoxDecoration(
                                        color: i == last ? Palette.lemon : Palette.wine,
                                        borderRadius: const BorderRadius.vertical(top: Radius.circular(7), bottom: Radius.circular(3)),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 7),
                            Text(
                              months[i].$1,
                              style: Fonts.mono(
                                size: 10,
                                tracking: 0,
                                weight: i == last ? FontWeight.w600 : FontWeight.w500,
                                color: i == last ? dl.ink : dl.muted,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        ListCard(
          children: [
            _Breakdown(Palette.paidGreen, 'Paid', paid.length, store.totalPaid),
            _Breakdown(Palette.citrine, 'Unpaid', unpaid.length, unpaid.fold(0, (s, i) => s + i.balance)),
            _Breakdown(Palette.overdue, 'Overdue', overdue.length, store.totalOverdue),
          ],
        ),
        if (online != null && (online.payments > 0 || store.business.paymentsEnabled)) ...[
          const SizedBox(height: 12),
          DaylitCard(
            child: Row(
              children: [
                const IconTile(Icons.bolt_rounded, size: 40, color: Palette.lemon, fg: Palette.wine),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Eyebrow('Paid online', size: 10),
                      const SizedBox(height: 2),
                      Text(money(online.collected, cents: false),
                          style: Fonts.sans(size: 20, weight: FontWeight.w800, tracking: -0.03, color: dl.ink)),
                      Text(
                        '${plural(online.payments, 'payment')} · ${money(online.platformFees)} Invonce fees'
                        '${online.lastPaidAt == null ? '' : ' · last ${fmtDate(online.lastPaidAt!)}'}',
                        style: Fonts.caption(dl.muted),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
        const SizedBox(height: 14),
        DaylitButton(
          'Export report · CSV, Excel, PDF',
          icon: Icons.download_rounded,
          onTap: () => toast(context, 'Report export is coming next'),
        ),
      ]),
    );
  }
}

class _Breakdown extends StatelessWidget {
  const _Breakdown(this.color, this.label, this.count, this.amount);

  final Color color;
  final String label;
  final int count;
  final double amount;

  @override
  Widget build(BuildContext context) {
    final dl = context.dl;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 11),
      child: Row(
        children: [
          Container(width: 10, height: 10, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
          const SizedBox(width: 12),
          Expanded(child: Text(label, style: Fonts.sans(size: 14, weight: FontWeight.w600, color: dl.ink))),
          Text(plural(count, 'invoice'), style: Fonts.mono(size: 11, tracking: 0, color: dl.muted)),
          SizedBox(
            width: 90,
            child: Text(money(amount, cents: false), textAlign: TextAlign.right, style: Fonts.amount(dl.ink, size: 14)),
          ),
        ],
      ),
    );
  }
}
