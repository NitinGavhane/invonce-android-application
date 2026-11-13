import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../data/app_store.dart';
import '../data/format.dart';
import '../data/models.dart';
import '../motion/motion.dart';
import '../theme/tokens.dart';
import '../theme/typography.dart';
import '../widgets/widgets.dart';
import 'client_form.dart';
import 'home.dart';
import 'invoice_editor.dart';

class ClientDetailScreen extends StatelessWidget {
  const ClientDetailScreen({super.key, required this.client});

  final Client client;

  Future<void> _open(BuildContext context, String uri, String fallback) async {
    try {
      final ok = await launchUrl(Uri.parse(uri));
      if (!ok && context.mounted) toast(context, fallback);
    } catch (_) {
      if (context.mounted) toast(context, fallback);
    }
  }

  @override
  Widget build(BuildContext context) {
    final dl = context.dl;
    final store = AppScope.watch(context);
    // Live copy, so edits made in the sheet show immediately.
    final c = store.clients.firstWhere((x) => x.id == client.id, orElse: () => client);
    final mine = store.invoicesFor(c);
    final billed = mine.fold<double>(0, (s, i) => s + i.total);
    final due = store.outstandingFor(c);
    final activity = store.eventsFor(c);

    return ScreenScaffold(
      bottomPadding: 40,
      header: TopBar(
        title: 'Client',
        trailing: [
          IconSquare(Icons.edit_outlined, label: 'Edit client', onTap: () => showClientSheet(context, existing: c)),
        ],
      ),
      children: stagger([
        DaylitCard(
          child: Column(
            children: [
              Row(
                children: [
                  Hero(tag: 'client-${c.id}', child: AvatarTile(c.initials, size: 54, radius: 16, color: c.color)),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(c.name, style: Fonts.sans(size: 19, weight: FontWeight.w700, tracking: -0.02, color: dl.ink)),
                        const SizedBox(height: 3),
                        Text('${c.email} · ${c.phone}', style: Fonts.caption(dl.muted)),
                        Text(c.address, style: Fonts.caption(dl.muted)),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  _Action(Icons.phone_outlined, 'Call', onTap: () => _open(context, 'tel:${c.phone.replaceAll(RegExp(r'[^0-9+]'), '')}', 'Calling isn\'t available on this device')),
                  const SizedBox(width: 8),
                  _Action(Icons.mail_outline_rounded, 'Email', onTap: () => _open(context, 'mailto:${c.email}', 'No mail app available')),
                  const SizedBox(width: 8),
                  _Action(Icons.add_rounded, 'Invoice', filled: true, onTap: () => pushPage(context, InvoiceEditorScreen(client: c))),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            _Stat('Billed', money(billed, cents: false)),
            const SizedBox(width: 8),
            _Stat('Outstanding', money(due, cents: false), lemon: true),
            const SizedBox(width: 8),
            _Stat('Invoices', '${mine.length}'),
          ],
        ),
        const SectionLabel('Invoices'),
        if (mine.isEmpty)
          const EmptyState(icon: Icons.receipt_long_outlined, label: 'Nothing billed yet')
        else
          ListCard(children: [for (final inv in mine) InvoiceRow(inv, showClient: false)]),
        if (activity.isNotEmpty) ...[
          const SectionLabel('Activity'),
          ListCard(
            children: [
              for (final a in activity)
                RowTile(
                  leading: IconTile(a.icon, size: 30),
                  title: a.title,
                  subtitle: '${fmtDate(a.when)} · ${fmtTime(a.when)}',
                  verticalPadding: 10,
                ),
            ],
          ),
        ],
      ]),
    );
  }
}

class _Action extends StatelessWidget {
  const _Action(this.icon, this.label, {required this.onTap, this.filled = false});

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool filled;

  @override
  Widget build(BuildContext context) {
    final dl = context.dl;
    final fg = filled ? Palette.lemon : dl.ink;
    return Expanded(
      child: Pressable(
        onTap: onTap,
        semanticLabel: label,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 9),
          decoration: BoxDecoration(
            color: filled ? Palette.wine : dl.bg,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: filled ? Palette.wine : dl.border),
          ),
          child: Column(
            children: [
              Icon(icon, size: 18, color: fg),
              const SizedBox(height: 4),
              Text(label, style: Fonts.sans(size: 12, weight: FontWeight.w600, color: fg)),
            ],
          ),
        ),
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat(this.label, this.value, {this.lemon = false});

  final String label;
  final String value;
  final bool lemon;

  @override
  Widget build(BuildContext context) {
    final dl = context.dl;
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: lemon ? Palette.lemon : dl.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: lemon ? Palette.lemon : dl.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Eyebrow(label, size: 9.5, color: lemon ? Palette.rust : null),
            const SizedBox(height: 2),
            Text(value, style: Fonts.sans(size: 17, weight: FontWeight.w700, tracking: -0.02, color: lemon ? Palette.wine : dl.ink)),
          ],
        ),
      ),
    );
  }
}
