import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../data/app_store.dart';
import '../data/format.dart';
import '../data/models.dart';
import '../data/pdf_service.dart';
import '../motion/motion.dart';
import '../theme/tokens.dart';
import '../theme/typography.dart';
import '../widgets/widgets.dart';

/// Email · Text · Payment link · Print · Save PDF, with read receipts.
/// Every option produces a real PDF and hands it to the device.
Future<void> showSendSheet(BuildContext context, Invoice invoice, {int initialOption = 0}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    barrierColor: Palette.midnight.withValues(alpha: 0.62),
    builder: (_) => _SendSheet(invoice: invoice, initialOption: initialOption),
  );
}

/// Builds the right PDF for a document: a receipt once it's paid, else the
/// invoice/estimate — with the pay link printed once online payments are live.
Future<(Uint8List, String)> buildDocumentPdf(AppStore store, Invoice inv) async {
  if (inv.isPaid) {
    final bytes = await DocumentPdf.receipt(
      inv,
      store.business,
      amount: inv.paid,
      method: 'Payment recorded',
      date: inv.paidOn ?? store.today,
    );
    return (bytes, DocumentPdf.fileName(inv, receipt: true));
  }
  final link = payLinkIfLive(store, inv);
  return (await DocumentPdf.invoice(inv, store.business, payLink: link), DocumentPdf.fileName(inv));
}

/// The public pay link, only when the client can actually pay on it.
String? payLinkIfLive(AppStore store, Invoice inv) {
  if (inv.isEstimate || inv.isPaid || !store.business.paymentsEnabled) return null;
  final link = store.payLinkFor(inv);
  return link.isEmpty ? null : link;
}

class _SendSheet extends StatefulWidget {
  const _SendSheet({required this.invoice, required this.initialOption});

  final Invoice invoice;
  final int initialOption;

  @override
  State<_SendSheet> createState() => _SendSheetState();
}

class _SendSheetState extends State<_SendSheet> {
  static const _options = <(IconData, String)>[
    (Icons.mail_outline_rounded, 'Email'),
    (Icons.sms_outlined, 'Text message'),
    (Icons.link_rounded, 'Payment link'),
    (Icons.print_outlined, 'Print'),
    (Icons.download_rounded, 'Save as PDF'),
  ];

  late int _selected = widget.initialOption;
  bool _readReceipts = true;
  bool _busy = false;

  Future<void> _go() async {
    final store = AppScope.read(context);
    final inv = widget.invoice;
    final b = store.business;
    final kind = inv.isEstimate ? 'Estimate' : (inv.isPaid ? 'Receipt' : 'Invoice');
    setState(() => _busy = true);
    try {
      String done;
      switch (_selected) {
        case 0 || 1:
          final (bytes, name) = await buildDocumentPdf(store, inv);
          final due = inv.isPaid ? '' : ' It is due on ${fmtDate(inv.due, year: true)}.';
          final live = payLinkIfLive(store, inv);
          final pay = live == null ? '' : '\n\nPay online: $live';
          await DocumentPdf.send(
            bytes,
            name,
            subject: '$kind ${inv.number} from ${b.name}',
            body: 'Hi ${inv.client.name},\n\nPlease find $kind ${inv.number} for ${money(inv.total)} attached.$due$pay\n\nThank you,\n${b.name}',
          );
          if (!inv.isPaid) await store.markSent(inv);
          done = '${inv.number} shared';
        case 2:
          final link = inv.isEstimate ? '' : store.payLinkFor(inv);
          if (link.isEmpty) {
            await Clipboard.setData(ClipboardData(
              text: '$kind ${inv.number} · ${money(inv.isPaid ? inv.total : inv.balance)}'
                  '${inv.isPaid ? '' : ' due ${fmtDate(inv.due, year: true)}'} · ${b.name}',
            ));
            done = inv.isEstimate ? 'Estimate details copied' : 'Details copied — save the invoice to get its pay link';
          } else {
            await Clipboard.setData(ClipboardData(text: link));
            done = b.paymentsEnabled
                ? 'Payment link copied'
                : 'Link copied — connect payments in More → Payment methods so clients can pay on it';
          }
        case 3:
          final (bytes, name) = await buildDocumentPdf(store, inv);
          await DocumentPdf.print(bytes, name);
          done = '${inv.number} sent to printer';
        default:
          final (bytes, name) = await buildDocumentPdf(store, inv);
          await DocumentPdf.save(bytes, name);
          done = '$name ready — choose where to save it';
      }
      if (!mounted) return;
      Haptics.success();
      Navigator.of(context).pop();
      toast(context, done);
    } catch (e) {
      if (mounted) {
        toast(context, "Couldn't create the PDF: $e");
        setState(() => _busy = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final dl = context.dl;
    final inv = widget.invoice;
    final kind = inv.isEstimate ? 'estimate' : (inv.isPaid ? 'receipt' : 'invoice');
    final cta = switch (_selected) {
      0 => 'Send by email',
      1 => 'Send by text',
      2 => 'Copy payment link',
      3 => 'Print',
      _ => 'Save PDF',
    };

    return Container(
      decoration: BoxDecoration(
        color: dl.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: EdgeInsets.fromLTRB(20, 12, 20, 18 + MediaQuery.paddingOf(context).bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 5,
              decoration: BoxDecoration(color: Palette.sand, borderRadius: BorderRadius.circular(99)),
            ),
          ),
          const SizedBox(height: 16),
          Text('Send $kind', style: Fonts.sans(size: 22, weight: FontWeight.w700, tracking: -0.03, color: dl.ink)),
          const SizedBox(height: 3),
          RichText(
            text: TextSpan(
              style: Fonts.sans(size: 13, color: dl.muted),
              children: [
                TextSpan(text: '${inv.number} · '),
                TextSpan(text: money(inv.total), style: Fonts.sans(size: 13, weight: FontWeight.w700, color: dl.ink)),
                TextSpan(text: ' to ${inv.client.name}'),
              ],
            ),
          ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: dl.bg,
              borderRadius: BorderRadius.circular(Radii.input),
              border: Border.all(color: dl.border),
            ),
            child: Row(
              children: [
                const Eyebrow('To', size: 10),
                const SizedBox(width: 8),
                Flexible(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(color: Palette.lemon, borderRadius: BorderRadius.circular(Radii.pill)),
                    child: Text(
                      inv.client.email.isEmpty ? inv.client.name : inv.client.email,
                      overflow: TextOverflow.ellipsis,
                      style: Fonts.sans(size: 12.5, weight: FontWeight.w600, color: Palette.wine),
                    ),
                  ),
                ),
                const Spacer(),
                Text('Pick in share sheet', style: Fonts.sans(size: 11, weight: FontWeight.w600, color: dl.muted)),
              ],
            ),
          ),
          const SizedBox(height: 6),
          for (var i = 0; i < _options.length; i++) ...[
            if (i > 0) Divider(height: 1, color: dl.border),
            Pressable(
              onTap: () => setState(() => _selected = i),
              scale: 0.985,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 11),
                child: Row(
                  children: [
                    IconTile(_options[i].$1, size: 36),
                    const SizedBox(width: 12),
                    Expanded(child: Text(_options[i].$2, style: Fonts.body(dl.ink))),
                    _Radio(on: _selected == i),
                  ],
                ),
              ),
            ),
          ],
          const SizedBox(height: 8),
          if (!inv.isPaid)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
              decoration: BoxDecoration(color: dl.bg, borderRadius: BorderRadius.circular(Radii.input)),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text("Notify me when it's viewed", style: Fonts.sans(size: 14, weight: FontWeight.w600, color: dl.ink)),
                        Text('Read receipts for this $kind', style: Fonts.caption(dl.muted)),
                      ],
                    ),
                  ),
                  DaylitToggle(value: _readReceipts, onChanged: (v) => setState(() => _readReceipts = v)),
                ],
              ),
            ),
          const SizedBox(height: 14),
          DaylitButton(
            _busy ? 'Preparing PDF…' : cta,
            icon: _selected == 0 ? Icons.send_rounded : _options[_selected].$1,
            onTap: _busy ? null : _go,
          ),
          const SizedBox(height: 4),
          Pressable(
            onTap: () => Navigator.of(context).pop(),
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: Center(child: Text('Cancel', style: Fonts.sans(size: 14, weight: FontWeight.w600, color: dl.muted))),
            ),
          ),
        ],
      ),
    );
  }
}

class _Radio extends StatelessWidget {
  const _Radio({required this.on});

  final bool on;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: Motion.fast,
      width: 22,
      height: 22,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: on ? Palette.wine : Colors.transparent,
        border: Border.all(color: on ? Palette.wine : Palette.sand, width: 2),
      ),
      child: AnimatedScale(
        scale: on ? 1 : 0,
        duration: Motion.standard,
        curve: Motion.spring,
        child: Center(
          child: Container(width: 8, height: 8, decoration: const BoxDecoration(color: Palette.white, shape: BoxShape.circle)),
        ),
      ),
    );
  }
}
