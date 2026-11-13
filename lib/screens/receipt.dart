import 'package:flutter/material.dart';

import '../data/app_store.dart';
import '../data/format.dart';
import '../data/models.dart';
import '../data/pdf_service.dart';
import '../motion/motion.dart';
import '../theme/tokens.dart';
import '../theme/typography.dart';
import '../widgets/widgets.dart';
import 'send_sheet.dart';

class ReceiptScreen extends StatelessWidget {
  const ReceiptScreen({super.key, required this.invoice, required this.amount, required this.method, this.reference});

  final Invoice invoice;
  final double amount;
  final String method;
  final String? reference;

  Future<void> _savePdf(BuildContext context, AppStore store) async {
    try {
      final bytes = await DocumentPdf.receipt(
        invoice,
        store.business,
        amount: amount,
        method: method,
        date: store.today,
        reference: reference,
      );
      final name = DocumentPdf.fileName(invoice, receipt: true);
      await DocumentPdf.save(bytes, name);
      if (context.mounted) toast(context, '$name ready — choose where to save it');
    } catch (e) {
      if (context.mounted) toast(context, "Couldn't create the PDF: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    final dl = context.dl;
    final store = AppScope.watch(context);
    final inv = invoice;
    final balance = inv.balance;
    final number = inv.number.replaceFirst(RegExp(r'^[A-Z]+'), 'RCT');

    return ScreenScaffold(
      header: TopBar(
        title: 'Receipt · $number',
        onBack: () => Navigator.of(context).popUntil((r) => r.isFirst),
        trailing: [
          IconSquare(Icons.ios_share_rounded, label: 'Share', onTap: () => showSendSheet(context, inv)),
        ],
      ),
      bottom: [
        Expanded(
          flex: 10,
          child: DaylitButton('Save PDF', variant: DaylitVariant.ghost, onTap: () => _savePdf(context, store)),
        ),
        Expanded(
          flex: 13,
          child: DaylitButton('Send receipt', icon: Icons.send_rounded, onTap: () => showSendSheet(context, inv)),
        ),
      ],
      children: [
        FadeSlideIn(
          child: Container(
            padding: const EdgeInsets.fromLTRB(22, 26, 22, 22),
            decoration: BoxDecoration(
              color: dl.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: dl.border),
              boxShadow: [
                BoxShadow(color: Palette.wine.withValues(alpha: 0.10), blurRadius: 40, offset: const Offset(0, 18)),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Center(child: PaidCheck()),
                const SizedBox(height: 14),
                Center(
                  child: Text('PAYMENT RECEIVED',
                      style: Fonts.mono(size: 11, weight: FontWeight.w600, tracking: 0.12, color: Palette.paidText)),
                ),
                const SizedBox(height: 6),
                Center(child: Text(money(amount), style: Fonts.display(dl.ink))),
                const SizedBox(height: 4),
                Center(
                  child: Text('${fmtDate(store.today, year: true)} · $method${reference != null ? ' · $reference' : ''}',
                      style: Fonts.caption(dl.muted)),
                ),
                const SizedBox(height: 20),
                Divider(height: 1, color: dl.border),
                const SizedBox(height: 8),
                _Kv('Receipt no.', number, mono: true),
                _Kv('For invoice', inv.number, mono: true),
                _Kv('Billed to', inv.client.name),
                _Kv('From', store.business.name),
                const SizedBox(height: 8),
                Divider(height: 1, color: dl.border),
                const SizedBox(height: 12),
                Text('ITEMS', style: Fonts.mono(size: 9, tracking: 0.07, color: dl.muted)),
                const SizedBox(height: 4),
                for (final item in inv.items) _Kv(item.name, money(item.amount), mono: true, plain: true),
                Divider(height: 12, color: dl.border),
                Row(
                  children: [
                    Expanded(child: Text('Total paid', style: Fonts.sans(size: 13, weight: FontWeight.w700, color: dl.ink))),
                    Text(money(inv.paid), style: Fonts.mono(size: 14, weight: FontWeight.w600, tracking: -0.02, color: dl.ink)),
                  ],
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Pill(
                      'Balance ${money(balance < 0.005 ? 0 : balance)}',
                      bg: balance < 0.005 ? Palette.paidBg : Palette.lemon,
                      fg: balance < 0.005 ? Palette.paidText : Palette.wine,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Thank you for your business.',
                        textAlign: TextAlign.right,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: Fonts.sans(size: 11.5, color: dl.muted),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _Kv extends StatelessWidget {
  const _Kv(this.k, this.v, {this.mono = false, this.plain = false});

  final String k;
  final String v;
  final bool mono;
  final bool plain;

  @override
  Widget build(BuildContext context) {
    final dl = context.dl;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 6),
      decoration: BoxDecoration(border: Border(bottom: BorderSide(color: dl.border))),
      child: Row(
        children: [
          Expanded(child: Text(k, style: Fonts.sans(size: 12.5, color: plain ? dl.ink : dl.muted))),
          Text(
            v,
            style: mono
                ? Fonts.mono(size: 12, tracking: 0, color: dl.ink)
                : Fonts.sans(size: 12.5, weight: FontWeight.w600, color: dl.ink),
          ),
        ],
      ),
    );
  }
}
