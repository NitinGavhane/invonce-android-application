import 'package:flutter/material.dart';

import '../data/app_store.dart';
import '../data/format.dart';
import '../data/models.dart';
import '../motion/motion.dart';
import '../shell.dart';
import '../theme/tokens.dart';
import '../theme/typography.dart';
import '../widgets/widgets.dart';
import 'estimates.dart';
import 'invoice_editor.dart';
import 'invoice_preview.dart';
import 'profile_menu.dart';
import 'reports.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final store = AppScope.watch(context);
    final invoices = store.invoices;
    final open = invoices.where((i) => i.isOpen).toList();
    final overdueCount = invoices.where((i) => i.status == InvoiceStatus.overdue).length;
    final name = store.business.name.isEmpty ? 'Your business' : store.business.name;

    return ScreenScaffold(
      bottomPadding: 110,
      header: PageHeader(
        eyebrow: fmtWeekday(store.today),
        title: name,
        trailing: Pressable(
          onTap: () => showProfileMenu(context),
          scale: 0.9,
          semanticLabel: 'Profile menu',
          child: AvatarTile(store.business.initials.isEmpty ? '·' : store.business.initials, size: 44, radius: 16),
        ),
      ),
      children: stagger([
        _HeroCard(
          outstanding: store.totalOutstanding,
          sub: 'Across ${plural(open.length, 'open invoice')} · $overdueCount overdue',
          paid: store.paidLast30,
          overdue: store.totalOverdue,
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: DaylitButton(
                'New invoice',
                height: 48,
                fontSize: 14,
                onTap: () => pushPage(context, const InvoiceEditorScreen()),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: DaylitButton(
                'Estimate',
                variant: DaylitVariant.ghost,
                height: 48,
                fontSize: 14,
                onTap: () => pushPage(context, const EstimatesScreen()),
              ),
            ),
            const SizedBox(width: 10),
            IconSquare(
              Icons.bar_chart_rounded,
              size: 48,
              label: 'Reports',
              onTap: () => pushPage(context, const ReportsScreen()),
            ),
          ],
        ),
        const SizedBox(height: 14),
        SectionHead(
          'Recent invoices',
          action: 'See all',
          onAction: () => ShellScope.of(context)?.goTo(1),
        ),
        if (invoices.isEmpty)
          const EmptyState(icon: Icons.receipt_long_outlined, label: 'No invoices yet — create your first in 60 seconds')
        else
          ListCard(children: [for (final inv in invoices.take(3)) InvoiceRow(inv)]),
      ]),
    );
  }
}

class _HeroCard extends StatelessWidget {
  const _HeroCard({required this.outstanding, required this.sub, required this.paid, required this.overdue});

  final double outstanding;
  final String sub;
  final double paid;
  final double overdue;

  @override
  Widget build(BuildContext context) {
    return DaylitCard(
      color: Palette.wine,
      radius: 24,
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Eyebrow('Outstanding balance', color: Palette.lemon),
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(money(outstanding, cents: false), style: Fonts.display(Palette.white)),
              Text(
                '.${((outstanding - outstanding.floor()) * 100).round().toString().padLeft(2, '0')}',
                style: Fonts.sans(size: 22, weight: FontWeight.w700, color: Palette.white.withValues(alpha: 0.65)),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(sub, style: Fonts.sans(size: 13, color: Palette.rose)),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _MiniStat(
                  label: 'Paid · 30d',
                  value: money(paid, cents: false),
                  bg: Palette.white.withValues(alpha: 0.09),
                  labelColor: Palette.rose,
                  valueColor: Palette.white,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _MiniStat(
                  label: 'Overdue',
                  value: money(overdue, cents: false),
                  bg: Palette.lemon,
                  labelColor: Palette.rust,
                  valueColor: Palette.wine,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MiniStat extends StatelessWidget {
  const _MiniStat({
    required this.label,
    required this.value,
    required this.bg,
    required this.labelColor,
    required this.valueColor,
  });

  final String label;
  final String value;
  final Color bg;
  final Color labelColor;
  final Color valueColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 11),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(14)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Eyebrow(label, color: labelColor),
          const SizedBox(height: 3),
          Text(value, style: Fonts.sans(size: 17, weight: FontWeight.w700, tracking: -0.02, color: valueColor)),
        ],
      ),
    );
  }
}

/// Shared invoice list row (Home, Invoices, Client detail).
class InvoiceRow extends StatelessWidget {
  const InvoiceRow(this.invoice, {super.key, this.showClient = true});

  final Invoice invoice;
  final bool showClient;

  @override
  Widget build(BuildContext context) {
    final dl = context.dl;
    final inv = invoice;
    final when = inv.isPaid && inv.paidOn != null
        ? 'Paid ${fmtDate(inv.paidOn!)}'
        : 'Due ${fmtDate(inv.due)}${inv.viewed ? ' · Viewed' : ''}';
    return RowTile(
      leading: showClient
          ? Hero(
              tag: 'inv-${inv.id}',
              child: AvatarTile(inv.client.initials, color: inv.client.color),
            )
          : null,
      title: showClient ? inv.client.name : inv.number,
      subtitle: showClient ? '${inv.number} · $when' : when,
      trailing: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(money(inv.total, cents: false),
              style: Fonts.sans(size: 15, weight: FontWeight.w700, tracking: -0.02, color: dl.ink)),
          const SizedBox(height: 5),
          StatusPill(inv.status),
        ],
      ),
      onTap: () => pushPage(context, InvoicePreviewScreen(invoice: inv)),
    );
  }
}

class EmptyState extends StatelessWidget {
  const EmptyState({super.key, required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final dl = context.dl;
    return DaylitCard(
      padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 24),
      child: Column(
        children: [
          Icon(icon, size: 32, color: dl.muted),
          const SizedBox(height: 10),
          Text(label, textAlign: TextAlign.center, style: Fonts.body(dl.muted)),
        ],
      ),
    );
  }
}
