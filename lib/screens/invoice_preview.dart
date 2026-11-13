import 'package:flutter/material.dart';

import '../data/app_store.dart';
import '../data/models.dart';
import '../data/pdf_service.dart';
import '../motion/motion.dart';
import '../widgets/widgets.dart';
import 'invoice_document.dart';
import 'record_payment.dart';
import 'send_sheet.dart';

/// The document itself — what the client receives, in the business's template.
/// [template] overrides it for a one-off look (Templates → "Preview").
class InvoicePreviewScreen extends StatelessWidget {
  const InvoicePreviewScreen({super.key, required this.invoice, this.template});

  final Invoice invoice;
  final InvoiceTemplate? template;

  @override
  Widget build(BuildContext context) {
    final store = AppScope.watch(context);
    // Prefer the live copy so status/payments reflect what was just recorded.
    final inv = store.documents.firstWhere((d) => d.id == invoice.id, orElse: () => invoice);
    final business = store.business;
    final kind = inv.isEstimate ? 'Estimate' : 'Invoice';

    return ScreenScaffold(
      header: TopBar(
        title: '$kind · ${inv.number}',
        trailing: [
          IconSquare(Icons.download_rounded, label: 'Download PDF', onTap: () => _savePdf(context, store, inv)),
          IconSquare(Icons.ios_share_rounded, label: 'Share',
              onTap: () => showSendSheet(context, inv)),
        ],
      ),
      bottom: inv.isPaid
          ? [
              Expanded(
                child: DaylitButton('Send receipt', icon: Icons.send_rounded,
                    onTap: () => showSendSheet(context, inv)),
              ),
            ]
          : inv.isEstimate
              ? [
                  Expanded(
                    flex: 10,
                    child: DaylitButton(
                      inv.status == InvoiceStatus.accepted ? 'Convert to invoice' : 'Mark accepted',
                      variant: DaylitVariant.lemon,
                      icon: inv.status == InvoiceStatus.accepted ? Icons.arrow_forward_rounded : Icons.check_rounded,
                      onTap: () => _estimateAction(context, store, inv),
                    ),
                  ),
                  Expanded(
                    flex: 13,
                    child: DaylitButton('Send estimate', icon: Icons.send_rounded, onTap: () => showSendSheet(context, inv)),
                  ),
                ]
              : [
                  Expanded(
                    flex: 10,
                    child: DaylitButton(
                      'Mark paid',
                      variant: DaylitVariant.lemon,
                      icon: Icons.check_rounded,
                      onTap: () => pushPage(context, RecordPaymentScreen(invoice: inv)),
                    ),
                  ),
                  Expanded(
                    flex: 13,
                    child: DaylitButton('Send invoice', icon: Icons.send_rounded, onTap: () => showSendSheet(context, inv)),
                  ),
                ],
      children: [
        FadeSlideIn(
          child: InvoiceDocument(invoice: inv, business: business, template: template ?? business.template),
        ),
      ],
    );
  }
}

Future<void> _savePdf(BuildContext context, AppStore store, Invoice inv) async {
  try {
    final (bytes, name) = await buildDocumentPdf(store, inv);
    await DocumentPdf.save(bytes, name);
    if (context.mounted) toast(context, '$name ready — choose where to save it');
  } catch (e) {
    if (context.mounted) toast(context, "Couldn't create the PDF: $e");
  }
}

Future<void> _estimateAction(BuildContext context, AppStore store, Invoice est) async {
  try {
    if (est.status == InvoiceStatus.accepted) {
      final saved = await store.saveInvoice(store.newDraft(client: est.client, items: est.items));
      if (!context.mounted) return;
      Haptics.success();
      toast(context, '${est.number} converted to ${saved.number}');
      Navigator.of(context).pushReplacement(
        MaterialPageRoute<void>(builder: (_) => InvoicePreviewScreen(invoice: saved)),
      );
    } else {
      await store.setStatus(est, InvoiceStatus.accepted);
      if (!context.mounted) return;
      Haptics.success();
      toast(context, '${est.number} marked accepted');
    }
  } catch (e) {
    if (context.mounted) toast(context, "Couldn't update: $e");
  }
}
