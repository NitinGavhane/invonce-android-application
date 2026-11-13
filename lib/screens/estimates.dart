import 'package:flutter/material.dart';

import '../data/app_store.dart';
import '../data/format.dart';
import '../data/models.dart';
import '../motion/motion.dart';
import '../theme/tokens.dart';
import '../theme/typography.dart';
import '../widgets/widgets.dart';
import 'home.dart';
import 'invoice_editor.dart';
import 'invoice_preview.dart';

class EstimatesScreen extends StatefulWidget {
  const EstimatesScreen({super.key});

  @override
  State<EstimatesScreen> createState() => _EstimatesScreenState();
}

class _EstimatesScreenState extends State<EstimatesScreen> {
  static const _filters = ['All', 'Draft', 'Sent', 'Accepted'];
  int _filter = 0;

  @override
  Widget build(BuildContext context) {
    final dl = context.dl;
    final store = AppScope.watch(context);
    final all = store.estimates;
    final visible = switch (_filter) {
      1 => all.where((e) => e.status == InvoiceStatus.draft).toList(),
      2 => all.where((e) => e.status == InvoiceStatus.sent).toList(),
      3 => all.where((e) => e.status == InvoiceStatus.accepted).toList(),
      _ => all,
    };
    final accepted = visible.where((e) => e.status == InvoiceStatus.accepted).toList();
    final rest = visible.where((e) => e.status != InvoiceStatus.accepted).toList();

    return ScreenScaffold(
      bottomPadding: 40,
      header: TopBar(
        title: 'Estimates',
        trailing: [
          IconSquare(
            Icons.add_rounded,
            filled: true,
            label: 'New estimate',
            onTap: () => pushPage(context, const InvoiceEditorScreen(isEstimate: true)),
          ),
        ],
      ),
      children: [
        ...stagger([
          const Padding(
            padding: EdgeInsets.only(bottom: 12),
            child: Eyebrow('Win the work, then convert to an invoice in one tap'),
          ),
          ChipBar(labels: _filters, selected: _filter, onSelect: (i) => setState(() => _filter = i)),
          const SizedBox(height: 14),
        ]),
        AnimatedSwitcher(
          duration: Motion.standard,
          switchInCurve: Motion.emphasized,
          child: Column(
            key: ValueKey('$_filter-${visible.length}'),
            children: [
              if (visible.isEmpty)
                EmptyState(icon: Icons.request_quote_outlined, label: 'No ${_filters[_filter].toLowerCase()} estimates'),
              for (final est in accepted) ...[
                DaylitCard(
                  child: Column(
                    children: [
                      _EstimateRow(est),
                      Divider(height: 24, color: dl.border),
                      Align(
                        alignment: Alignment.centerRight,
                        child: Pressable(
                          onTap: () => _convert(context, store, est),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                            decoration: BoxDecoration(
                              color: Palette.lemon,
                              borderRadius: BorderRadius.circular(Radii.pill),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text('Convert to invoice',
                                    style: Fonts.sans(size: 12, weight: FontWeight.w700, color: Palette.wine)),
                                const SizedBox(width: 6),
                                const Icon(Icons.arrow_forward_rounded, size: 14, color: Palette.wine),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
              ],
              if (rest.isNotEmpty) ListCard(children: [for (final e in rest) _EstimateRow(e)]),
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _convert(BuildContext context, AppStore store, Invoice est) async {
    final draft = store.newDraft(client: est.client, items: est.items);
    final saved = await store.saveInvoice(draft);
    if (!context.mounted) return;
    Haptics.success();
    toast(context, '${est.number} converted to ${saved.number}');
    pushPage(context, InvoicePreviewScreen(invoice: saved));
  }
}

class _EstimateRow extends StatelessWidget {
  const _EstimateRow(this.est);

  final Invoice est;

  @override
  Widget build(BuildContext context) {
    final dl = context.dl;
    final sub = est.status == InvoiceStatus.draft ? 'Draft' : fmtDate(est.issued);
    return RowTile(
      verticalPadding: est.status == InvoiceStatus.accepted ? 0 : 11,
      leading: AvatarTile(est.client.initials, color: est.client.color),
      title: est.client.name,
      subtitle: '${est.number} · $sub',
      trailing: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(money(est.total, cents: false),
              style: Fonts.sans(size: 15, weight: FontWeight.w700, tracking: -0.02, color: dl.ink)),
          const SizedBox(height: 5),
          StatusPill(est.status),
        ],
      ),
      onTap: () => pushPage(context, InvoicePreviewScreen(invoice: est)),
    );
  }
}
