import 'dart:typed_data';

import 'package:flutter/services.dart' show rootBundle;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import 'format.dart';
import 'models.dart';

/// Builds the invoice / estimate / receipt PDFs in the business's chosen
/// template and hands them to the device (save, print, share).
///
/// Every `InvoiceTemplate` has a layout here and a matching one in
/// `InvoiceDocument` (the on-screen preview); keep the two in step.
class DocumentPdf {
  DocumentPdf._(this._sans, this._sansBold, this._mono, this._monoBold);

  final pw.Font _sans;
  final pw.Font _sansBold;
  final pw.Font _mono;
  final pw.Font _monoBold;

  static DocumentPdf? _cached;

  static Future<DocumentPdf> _instance() async {
    if (_cached != null) return _cached!;
    Future<pw.Font> load(String file) async =>
        pw.Font.ttf(await rootBundle.load('assets/google_fonts/$file.ttf'));
    return _cached = DocumentPdf._(
      await load('HankenGrotesk-Regular'),
      await load('HankenGrotesk-Bold'),
      await load('JetBrainsMono-Regular'),
      await load('JetBrainsMono-SemiBold'),
    );
  }

  // Daylit palette in PDF space.
  static const _wine = PdfColor.fromInt(0xFF4D1520);
  static const _midnight = PdfColor.fromInt(0xFF360912);
  static const _parchment = PdfColor.fromInt(0xFFFBF9F6);
  static const _white = PdfColor.fromInt(0xFFFFFFFF);
  static const _lemon = PdfColor.fromInt(0xFFFAFFA7);
  static const _mauve = PdfColor.fromInt(0xFF825B63);
  static const _rose = PdfColor.fromInt(0xFFE9CDD2);
  static const _linen = PdfColor.fromInt(0xFFF2EEE7);
  static const _sand = PdfColor.fromInt(0xFFD3CAC3);
  static const _paidBg = PdfColor.fromInt(0xFFDCEBDC);
  static const _paidText = PdfColor.fromInt(0xFF2F5D34);
  static const _overdueBg = PdfColor.fromInt(0xFFF6DEDE);
  static const _overdueText = PdfColor.fromInt(0xFF8F2525);
  static const _sentBg = PdfColor.fromInt(0xFFE0E8F1);
  static const _sentText = PdfColor.fromInt(0xFF33506B);

  // ─── Public API ───────────────────────────────────────────────────────────

  static String fileName(Invoice inv, {bool receipt = false}) =>
      '${receipt ? receiptNumber(inv) : inv.number}.pdf';

  static String receiptNumber(Invoice inv) => inv.number.replaceFirst(RegExp(r'^[A-Z]+'), 'RCT');

  /// Renders [inv] in `business.template` (or [template] when given).
  /// [payLink], when given, is printed in the payment footer so the client
  /// can pay online straight from the PDF.
  static Future<Uint8List> invoice(Invoice inv, Business business, {String? payLink, InvoiceTemplate? template}) async =>
      (await _instance())._invoice(inv, business, template ?? business.template, payLink: payLink);

  static Future<Uint8List> receipt(
    Invoice inv,
    Business business, {
    required double amount,
    required String method,
    required DateTime date,
    String? reference,
  }) async =>
      (await _instance())._receipt(inv, business, amount: amount, method: method, date: date, reference: reference);

  /// Opens the system save/share sheet (Android: Files, Drive, …; web: download).
  static Future<void> save(Uint8List bytes, String name) => Printing.sharePdf(bytes: bytes, filename: name);

  /// Opens the system print dialog.
  static Future<void> print(Uint8List bytes, String name) =>
      Printing.layoutPdf(onLayout: (_) async => bytes, name: name);

  /// Share sheet with the PDF attached and an email subject/body prefilled.
  static Future<void> send(Uint8List bytes, String name, {required String subject, required String body}) =>
      Printing.sharePdf(bytes: bytes, filename: name, subject: subject, body: body);

  // ─── Text styles ──────────────────────────────────────────────────────────

  pw.TextStyle _s(double size, {bool bold = false, PdfColor color = _wine, double? spacing, double? height}) =>
      pw.TextStyle(font: bold ? _sansBold : _sans, fontSize: size, color: color, letterSpacing: spacing, lineSpacing: height);

  pw.TextStyle _m(double size, {bool bold = false, PdfColor color = _wine, double spacing = 0}) =>
      pw.TextStyle(font: bold ? _monoBold : _mono, fontSize: size, color: color, letterSpacing: spacing);

  pw.Widget _th(String text, {pw.TextAlign align = pw.TextAlign.left, PdfColor color = _mauve, double size = 7}) =>
      pw.Text(text.toUpperCase(), textAlign: align, style: _m(size, color: color, spacing: 0.6));

  // Note: the pdf engine misdraws radii larger than half the box, so pills use
  // an explicit radius of half their height rather than "999".
  pw.Widget _pill(String text, PdfColor bg, PdfColor fg) => pw.Container(
        height: 16,
        padding: const pw.EdgeInsets.symmetric(horizontal: 8),
        alignment: pw.Alignment.center,
        decoration: pw.BoxDecoration(color: bg, borderRadius: pw.BorderRadius.circular(8)),
        child: pw.Text(text.toUpperCase(), style: _m(7, bold: true, color: fg, spacing: 0.3)),
      );

  /// A green circle with a stroked check mark (no font glyph needed).
  pw.Widget _checkBadge() => pw.Container(
        width: 44,
        height: 44,
        decoration: const pw.BoxDecoration(color: _paidBg, shape: pw.BoxShape.circle),
        child: pw.CustomPaint(
          size: const PdfPoint(44, 44),
          painter: (canvas, size) {
            final w = size.x;
            canvas
              ..setStrokeColor(_paidText)
              ..setLineWidth(3.2)
              ..setLineCap(PdfLineCap.round)
              ..setLineJoin(PdfLineJoin.round)
              ..moveTo(w * 0.30, w * 0.50)
              ..lineTo(w * 0.44, w * 0.36)
              ..lineTo(w * 0.72, w * 0.66)
              ..strokePath();
          },
        ),
      );

  (PdfColor, PdfColor, String) _status(InvoiceStatus s) => switch (s) {
        InvoiceStatus.paid => (_paidBg, _paidText, 'Paid'),
        InvoiceStatus.unpaid => (_lemon, _wine, 'Unpaid'),
        InvoiceStatus.overdue => (_overdueBg, _overdueText, 'Overdue'),
        InvoiceStatus.sent => (_sentBg, _sentText, 'Sent'),
        InvoiceStatus.accepted => (_paidBg, _paidText, 'Accepted'),
        InvoiceStatus.draft => (_linen, _mauve, 'Draft'),
        InvoiceStatus.voided => (_linen, _mauve, 'Voided'),
      };

  // ─── Shared pieces ────────────────────────────────────────────────────────

  static String _qty(LineItem i) => i.qty.toStringAsFixed(i.qty % 1 == 0 ? 0 : 2);

  static String _taxLabel(Invoice inv) {
    final pct = inv.taxRate * 100;
    return 'Tax (${pct.toStringAsFixed(pct % 1 == 0 ? 0 : 1)}%)';
  }

  static String _totalLabel(Invoice inv) => inv.isPaid ? 'Total paid' : (inv.paid > 0 ? 'Balance due' : 'Total due');

  static double _totalValue(Invoice inv) => inv.isPaid ? inv.total : inv.balance;

  static String _paymentNote(Business b) =>
      'Card, bank transfer, check or cash accepted. Payment is due within ${b.dueInDays} days of the issue date.';

  /// Wine tile with the business initial + name block — the Daylit header.
  pw.Widget _header(Business b, String kind, {pw.Widget? badge}) {
    final initial = b.initials.isEmpty ? '·' : b.initials[0];
    return pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Container(
          width: 36,
          height: 36,
          alignment: pw.Alignment.center,
          decoration: pw.BoxDecoration(color: _wine, borderRadius: pw.BorderRadius.circular(9)),
          child: pw.Text(initial, style: _s(16, bold: true, color: _lemon)),
        ),
        pw.SizedBox(width: 10),
        pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(b.name, style: _s(13, bold: true)),
            ..._businessLines(b),
          ],
        ),
        pw.Spacer(),
        pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.end,
          children: [
            pw.Text(kind.toUpperCase(), style: _m(20, bold: true, spacing: 0.5)),
            if (badge != null) ...[pw.SizedBox(height: 6), badge],
          ],
        ),
      ],
    );
  }

  List<pw.Widget> _businessLines(Business b, {PdfColor color = _mauve, double size = 8.5, pw.TextAlign align = pw.TextAlign.left}) => [
        for (final line in [b.email, b.phone, b.address.replaceAll('\n', ', ')])
          if (line.isNotEmpty) pw.Text(line, textAlign: align, style: _s(size, color: color)),
      ];

  pw.Widget _footer(Business b, String note, {String? link, PdfColor ink = _wine, PdfColor muted = _mauve, PdfColor rule = _linen, bool mono = true}) =>
      pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Divider(color: rule, thickness: 1),
          pw.SizedBox(height: 8),
          if (mono) _th('Payment', color: muted) else pw.Text('Payment', style: _s(8, color: muted)),
          pw.SizedBox(height: 3),
          pw.Text(note, style: _s(8.5, color: muted)),
          if (link != null && link.isNotEmpty) ...[
            pw.SizedBox(height: 6),
            pw.UrlLink(
              destination: link,
              child: pw.Row(
                children: [
                  pw.Text('Pay online  ', style: _s(8.5, bold: true, color: ink)),
                  pw.Text(link, style: _m(7, color: muted, spacing: 0)),
                ],
              ),
            ),
          ],
          pw.SizedBox(height: 14),
          pw.Row(
            children: [
              pw.Text('Thank you for your business.', style: _s(8.5, color: muted)),
              pw.Spacer(),
              pw.Text('Made with Invonce', style: _m(6.5, color: muted, spacing: 0.4)),
            ],
          ),
        ],
      );

  pw.Widget _kv(String k, String v, {bool mono = true, bool bold = false, PdfColor ink = _wine, PdfColor muted = _mauve}) => pw.Padding(
        padding: const pw.EdgeInsets.symmetric(vertical: 2.5),
        child: pw.Row(
          children: [
            pw.Expanded(child: pw.Text(k, style: _s(9, color: muted))),
            pw.Text(v, style: mono ? _m(9, bold: bold, color: ink) : _s(9, bold: bold, color: ink)),
          ],
        ),
      );

  /// Subtotal / discount / tax / paid — identical in every template.
  List<pw.Widget> _breakdown(Invoice inv, {bool mono = true, PdfColor ink = _wine, PdfColor muted = _mauve}) => [
        _kv('Subtotal', money(inv.subtotal), mono: mono, ink: ink, muted: muted),
        if (inv.discount > 0) _kv('Discount', '-${money(inv.discount)}', mono: mono, ink: ink, muted: muted),
        if (inv.taxRate > 0) _kv(_taxLabel(inv), money(inv.tax), mono: mono, ink: ink, muted: muted),
        if (inv.paid > 0 && !inv.isPaid) _kv('Paid', '-${money(inv.paid)}', mono: mono, ink: ink, muted: muted),
      ];

  pw.Widget _tableHead({bool rate = true, PdfColor color = _mauve, PdfColor? fill, bool mono = true}) {
    pw.Widget cell(String t, pw.TextAlign a) =>
        mono ? _th(t, align: a, color: color) : pw.Text(t, textAlign: a, style: _s(8, color: color));
    return pw.Container(
      color: fill,
      padding: pw.EdgeInsets.symmetric(vertical: 6, horizontal: fill == null ? 0 : 6),
      child: pw.Row(
        children: [
          pw.Expanded(child: cell('Description', pw.TextAlign.left)),
          pw.SizedBox(width: 50, child: cell('Qty', pw.TextAlign.center)),
          if (rate) pw.SizedBox(width: 80, child: cell('Rate', pw.TextAlign.right)),
          pw.SizedBox(width: 90, child: cell('Amount', pw.TextAlign.right)),
        ],
      ),
    );
  }

  List<pw.Widget> _rows(
    Invoice inv, {
    bool rate = true,
    PdfColor rule = _linen,
    PdfColor ink = _wine,
    PdfColor muted = _mauve,
    bool mono = true,
    bool zebra = false,
    double pad = 7,
    double size = 10,
  }) {
    pw.TextStyle numStyle(PdfColor c, {bool bold = false}) => mono ? _m(size - 1, color: c, bold: bold) : _s(size - 0.5, color: c, bold: bold);
    return [
      for (var i = 0; i < inv.items.length; i++) ...[
        if (!zebra) pw.Divider(color: rule, thickness: 0.8),
        pw.Container(
          color: zebra && i.isOdd ? rule : null,
          padding: pw.EdgeInsets.symmetric(vertical: pad, horizontal: zebra ? 6 : 0),
          child: pw.Row(
            children: [
              pw.Expanded(child: pw.Text(inv.items[i].name, style: _s(size, color: ink))),
              pw.SizedBox(width: 50, child: pw.Text(_qty(inv.items[i]), textAlign: pw.TextAlign.center, style: numStyle(muted))),
              if (rate) pw.SizedBox(width: 80, child: pw.Text(money(inv.items[i].rate), textAlign: pw.TextAlign.right, style: numStyle(muted))),
              pw.SizedBox(width: 90, child: pw.Text(money(inv.items[i].amount), textAlign: pw.TextAlign.right, style: numStyle(ink))),
            ],
          ),
        ),
      ],
      pw.Divider(color: rule, thickness: 1),
    ];
  }

  pw.Widget _billedTo(Invoice inv, {PdfColor ink = _wine, PdfColor muted = _mauve, String title = 'Billed to', bool mono = true}) => pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          if (mono) _th(title, color: muted) else pw.Text(title, style: _s(8, color: muted)),
          pw.SizedBox(height: 3),
          pw.Text(inv.client.name, style: _s(11, bold: true, color: ink)),
          if (inv.client.address.isNotEmpty) pw.Text(inv.client.address, style: _s(8.5, color: muted)),
          if (inv.client.email.isNotEmpty) pw.Text(inv.client.email, style: _s(8.5, color: muted)),
        ],
      );

  pw.Page _page(pw.Widget Function(pw.Context) build, {PdfColor? paper, pw.Widget Function(pw.Context)? background}) => pw.Page(
        pageTheme: pw.PageTheme(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(44),
          buildBackground: background ??
              (paper == null ? null : (_) => pw.FullPage(ignoreMargins: true, child: pw.Container(color: paper))),
        ),
        build: build,
      );

  // ─── Invoice / estimate ───────────────────────────────────────────────────

  Future<Uint8List> _invoice(Invoice inv, Business b, InvoiceTemplate template, {String? payLink}) async {
    final doc = pw.Document(title: '${inv.number} · ${b.name}', author: b.name, creator: 'Invonce');
    doc.addPage(switch (template) {
      InvoiceTemplate.daylit => _daylit(inv, b, payLink),
      InvoiceTemplate.ledger => _ledger(inv, b, payLink),
      InvoiceTemplate.clean => _clean(inv, b, payLink),
      InvoiceTemplate.bold => _bold(inv, b, payLink),
      InvoiceTemplate.classic => _classic(inv, b, payLink),
      InvoiceTemplate.compact => _compact(inv, b, payLink),
    });
    return doc.save();
  }

  // 1. Daylit — the house look.
  pw.Page _daylit(Invoice inv, Business b, String? payLink) {
    final kind = inv.isEstimate ? 'Estimate' : 'Invoice';
    final (bg, fg, label) = _status(inv.status);
    return _page(
      (ctx) => pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          _header(b, kind, badge: _pill(label, bg, fg)),
          pw.SizedBox(height: 26),
          pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              _billedTo(inv),
              pw.Spacer(),
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.end,
                children: [
                  _th('$kind no.', align: pw.TextAlign.right),
                  pw.SizedBox(height: 3),
                  pw.Text(inv.number, style: _m(10)),
                  pw.SizedBox(height: 8),
                  _th('Issued · Due', align: pw.TextAlign.right),
                  pw.SizedBox(height: 3),
                  pw.Text('${fmtDate(inv.issued, year: true)} · ${fmtDate(inv.due, year: true)}', style: _m(10)),
                ],
              ),
            ],
          ),
          pw.SizedBox(height: 24),
          pw.Divider(color: _linen, thickness: 1),
          _tableHead(),
          ..._rows(inv),
          pw.SizedBox(height: 14),
          pw.Align(
            alignment: pw.Alignment.centerRight,
            child: pw.SizedBox(
              width: 230,
              child: pw.Column(
                children: [
                  ..._breakdown(inv),
                  pw.SizedBox(height: 6),
                  pw.Container(
                    padding: const pw.EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: pw.BoxDecoration(color: _lemon, borderRadius: pw.BorderRadius.circular(8)),
                    child: pw.Row(
                      children: [
                        pw.Expanded(child: pw.Text(_totalLabel(inv), style: _s(11, bold: true))),
                        pw.Text(money(_totalValue(inv)), style: _m(13, bold: true)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          pw.Spacer(),
          _footer(b, _paymentNote(b), link: payLink),
        ],
      ),
    );
  }

  // 2. Ledger — mono type, wine rules, parchment paper.
  pw.Page _ledger(Invoice inv, Business b, String? payLink) {
    final kind = inv.isEstimate ? 'Estimate' : 'Invoice';
    final (_, _, label) = _status(inv.status);
    pw.Widget rule([double w = 1]) => pw.Container(height: w, color: _wine);
    return _page(
      paper: _parchment,
      (ctx) => pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Row(
            children: [
              pw.Text('${kind.toUpperCase()} NO. ${inv.number.replaceFirst(RegExp(r'^[A-Z]+-'), '')}', style: _m(11, bold: true, spacing: 1.2)),
              pw.Spacer(),
              pw.Text(label.toUpperCase(), style: _m(8, bold: true, color: _mauve, spacing: 1)),
            ],
          ),
          pw.SizedBox(height: 8),
          rule(1.5),
          pw.SizedBox(height: 16),
          pw.Text(b.name, style: _s(16, bold: true)),
          pw.SizedBox(height: 2),
          ..._businessLines(b),
          pw.SizedBox(height: 20),
          pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Expanded(child: _billedTo(inv, title: 'Bill to')),
              pw.SizedBox(
                width: 150,
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    _th('Issued'),
                    pw.SizedBox(height: 3),
                    pw.Text(fmtDate(inv.issued, year: true), style: _m(10)),
                    pw.SizedBox(height: 8),
                    _th('Due'),
                    pw.SizedBox(height: 3),
                    pw.Text(fmtDate(inv.due, year: true), style: _m(10)),
                  ],
                ),
              ),
            ],
          ),
          pw.SizedBox(height: 22),
          rule(),
          _tableHead(color: _wine),
          ..._rows(inv, rule: _sand),
          pw.SizedBox(height: 12),
          pw.Align(
            alignment: pw.Alignment.centerRight,
            child: pw.SizedBox(
              width: 240,
              child: pw.Column(
                children: [
                  ..._breakdown(inv),
                  pw.SizedBox(height: 6),
                  rule(),
                  pw.SizedBox(height: 1.5),
                  rule(),
                  pw.Padding(
                    padding: const pw.EdgeInsets.symmetric(vertical: 7),
                    child: pw.Row(
                      children: [
                        pw.Expanded(child: pw.Text(_totalLabel(inv).toUpperCase(), style: _m(8.5, bold: true, spacing: 0.8))),
                        pw.Text(money(_totalValue(inv)), style: _m(14, bold: true)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          pw.Spacer(),
          pw.Text(_paymentNote(b), style: _s(8.5, color: _mauve)),
          if (payLink != null && payLink.isNotEmpty) ...[
            pw.SizedBox(height: 5),
            pw.UrlLink(destination: payLink, child: pw.Text('Pay online: $payLink', style: _m(7.5, color: _wine))),
          ],
          pw.SizedBox(height: 14),
          rule(1.5),
          pw.SizedBox(height: 6),
          pw.Row(
            children: [
              pw.Text(b.website, style: _m(7.5, color: _mauve)),
              pw.Spacer(),
              pw.Text('PAGE 1 / 1  ·  MADE WITH INVONCE', style: _m(6.5, color: _mauve, spacing: 0.5)),
            ],
          ),
        ],
      ),
    );
  }

  // 3. Clean — grey on white, sans only, plenty of air.
  pw.Page _clean(Invoice inv, Business b, String? payLink) {
    const ink = PdfColor.fromInt(0xFF1A1A1A);
    const grey = PdfColor.fromInt(0xFF8A8A8A);
    const hair = PdfColor.fromInt(0xFFEAEAEA);
    final kind = inv.isEstimate ? 'Estimate' : 'Invoice';
    final (_, _, label) = _status(inv.status);
    pw.Widget meta(String k, String v) => pw.Padding(
          padding: const pw.EdgeInsets.only(bottom: 3),
          child: pw.Row(
            children: [
              pw.SizedBox(width: 56, child: pw.Text(k, style: _s(8.5, color: grey))),
              pw.Text(v, style: _s(9, color: ink)),
            ],
          ),
        );
    return _page(
      (ctx) => pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(kind, style: _s(11, color: grey)),
          pw.SizedBox(height: 2),
          pw.Text(b.name, style: _s(22, bold: true, color: ink, spacing: -0.4)),
          pw.SizedBox(height: 36),
          pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Expanded(child: _billedTo(inv, ink: ink, muted: grey, mono: false)),
              pw.Expanded(
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    meta('Number', inv.number),
                    meta('Issued', fmtDate(inv.issued, year: true)),
                    meta('Due', fmtDate(inv.due, year: true)),
                    meta('Status', label),
                  ],
                ),
              ),
            ],
          ),
          pw.SizedBox(height: 36),
          _tableHead(rate: false, color: grey, mono: false),
          ..._rows(inv, rate: false, rule: hair, ink: ink, muted: grey, mono: false, pad: 9),
          pw.SizedBox(height: 18),
          pw.Align(
            alignment: pw.Alignment.centerRight,
            child: pw.SizedBox(
              width: 220,
              child: pw.Column(
                children: [
                  ..._breakdown(inv, mono: false, ink: ink, muted: grey),
                  pw.SizedBox(height: 10),
                  pw.Row(
                    children: [
                      pw.Expanded(child: pw.Text(_totalLabel(inv), style: _s(10, bold: true, color: ink))),
                      pw.Text(money(_totalValue(inv)), style: _s(20, bold: true, color: ink, spacing: -0.4)),
                    ],
                  ),
                ],
              ),
            ),
          ),
          pw.Spacer(),
          pw.Text(_paymentNote(b), style: _s(8.5, color: grey)),
          if (payLink != null && payLink.isNotEmpty) ...[
            pw.SizedBox(height: 5),
            pw.UrlLink(destination: payLink, child: pw.Text('Pay online: $payLink', style: _s(8.5, color: ink))),
          ],
          pw.SizedBox(height: 8),
          pw.Text([b.email, b.phone, b.website].where((s) => s.isNotEmpty).join('   ·   '), style: _s(8.5, color: grey)),
        ],
      ),
    );
  }

  // 4. Bold — full-bleed midnight band, wine total bar.
  pw.Page _bold(Invoice inv, Business b, String? payLink) {
    final kind = inv.isEstimate ? 'Estimate' : 'Invoice';
    final (bg, fg, label) = _status(inv.status);
    const bandHeight = 168.0;
    return _page(
      background: (_) => pw.FullPage(
        ignoreMargins: true,
        child: pw.Column(children: [pw.Container(height: bandHeight, color: _midnight), pw.Spacer()]),
      ),
      (ctx) => pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          // Everything in the band is white/lemon on midnight.
          pw.SizedBox(
            height: bandHeight - 44,
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Row(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Expanded(child: pw.Text(b.name, style: _s(18, bold: true, color: _lemon, spacing: -0.3))),
                    _pill(label, bg, fg),
                  ],
                ),
                pw.SizedBox(height: 2),
                pw.Text([b.email, b.phone].where((s) => s.isNotEmpty).join('   ·   '), style: _s(8.5, color: _rose)),
                pw.Spacer(),
                pw.Text(kind.toUpperCase(), style: _s(32, bold: true, color: _white, spacing: -1)),
                pw.SizedBox(height: 4),
                pw.Text('${inv.number}     ·     Issued ${fmtDate(inv.issued, year: true)}     ·     Due ${fmtDate(inv.due, year: true)}',
                    style: _m(8.5, color: _rose, spacing: 0.3)),
                pw.SizedBox(height: 14),
              ],
            ),
          ),
          pw.SizedBox(height: 26),
          _th('Billed to'),
          pw.SizedBox(height: 3),
          pw.Text(inv.client.name, style: _s(14, bold: true, color: _midnight)),
          if (inv.client.address.isNotEmpty) pw.Text(inv.client.address, style: _s(8.5, color: _mauve)),
          if (inv.client.email.isNotEmpty) pw.Text(inv.client.email, style: _s(8.5, color: _mauve)),
          pw.SizedBox(height: 22),
          _tableHead(fill: _linen, color: _midnight),
          ..._rows(inv, ink: _midnight, zebra: true, pad: 8),
          pw.SizedBox(height: 14),
          pw.Align(
            alignment: pw.Alignment.centerRight,
            child: pw.SizedBox(width: 230, child: pw.Column(children: _breakdown(inv, ink: _midnight))),
          ),
          pw.SizedBox(height: 10),
          pw.Container(
            padding: const pw.EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: pw.BoxDecoration(color: _wine, borderRadius: pw.BorderRadius.circular(10)),
            child: pw.Row(
              children: [
                pw.Expanded(child: pw.Text(_totalLabel(inv).toUpperCase(), style: _m(9, bold: true, color: _lemon, spacing: 1))),
                pw.Text(money(_totalValue(inv)), style: _s(22, bold: true, color: _lemon, spacing: -0.5)),
              ],
            ),
          ),
          pw.Spacer(),
          _footer(b, _paymentNote(b), link: payLink, ink: _midnight),
        ],
      ),
    );
  }

  // 5. Classic — centred title between double rules, boxed table.
  pw.Page _classic(Invoice inv, Business b, String? payLink) {
    final kind = inv.isEstimate ? 'Estimate' : 'Invoice';
    final (_, _, label) = _status(inv.status);
    pw.Widget doubleRule() => pw.Column(children: [
          pw.Container(height: 1.6, color: _wine),
          pw.SizedBox(height: 1.6),
          pw.Container(height: 0.6, color: _wine),
        ]);
    pw.Widget block(String title, List<pw.Widget> lines, {pw.CrossAxisAlignment align = pw.CrossAxisAlignment.start}) => pw.Column(
          crossAxisAlignment: align,
          children: [
            pw.Text(title.toUpperCase(), style: _s(7, bold: true, color: _mauve, spacing: 1)),
            pw.SizedBox(height: 4),
            ...lines,
          ],
        );
    return _page(
      (ctx) => pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.stretch,
        children: [
          doubleRule(),
          pw.Padding(
            padding: const pw.EdgeInsets.symmetric(vertical: 10),
            child: pw.Column(
              children: [
                pw.Text(kind.toUpperCase(), style: _s(18, bold: true, spacing: 4)),
                pw.SizedBox(height: 3),
                pw.Text('${inv.number}   ·   $label', style: _m(8.5, color: _mauve, spacing: 0.4)),
              ],
            ),
          ),
          doubleRule(),
          pw.SizedBox(height: 22),
          pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Expanded(child: block('From', [pw.Text(b.name, style: _s(11, bold: true)), ..._businessLines(b)])),
              pw.SizedBox(width: 20),
              pw.Expanded(
                child: block('Bill to', [
                  pw.Text(inv.client.name, style: _s(11, bold: true)),
                  if (inv.client.address.isNotEmpty) pw.Text(inv.client.address, style: _s(8.5, color: _mauve)),
                  if (inv.client.email.isNotEmpty) pw.Text(inv.client.email, style: _s(8.5, color: _mauve)),
                ]),
              ),
            ],
          ),
          pw.SizedBox(height: 20),
          pw.Row(
            children: [
              pw.Expanded(child: block('Date issued', [pw.Text(fmtDate(inv.issued, year: true), style: _s(10))])),
              pw.Expanded(child: block('Date due', [pw.Text(fmtDate(inv.due, year: true), style: _s(10))])),
              pw.Expanded(child: block('Amount due', [pw.Text(money(_totalValue(inv)), style: _s(10, bold: true))], align: pw.CrossAxisAlignment.end)),
            ],
          ),
          pw.SizedBox(height: 22),
          pw.Container(
            decoration: pw.BoxDecoration(border: pw.Border.all(color: _wine, width: 0.6)),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.stretch,
              children: [
                _tableHead(fill: _linen, color: _wine),
                pw.Padding(
                  padding: const pw.EdgeInsets.symmetric(horizontal: 6),
                  child: pw.Column(children: _rows(inv, rule: _sand)),
                ),
              ],
            ),
          ),
          pw.SizedBox(height: 14),
          pw.Align(
            alignment: pw.Alignment.centerRight,
            child: pw.SizedBox(
              width: 240,
              child: pw.Column(
                children: [
                  ..._breakdown(inv, mono: false),
                  pw.SizedBox(height: 6),
                  pw.Container(
                    padding: const pw.EdgeInsets.symmetric(vertical: 7),
                    decoration: const pw.BoxDecoration(
                      border: pw.Border(top: pw.BorderSide(color: _wine, width: 1.2), bottom: pw.BorderSide(color: _wine, width: 1.2)),
                    ),
                    child: pw.Row(
                      children: [
                        pw.Expanded(child: pw.Text(_totalLabel(inv), style: _s(11, bold: true))),
                        pw.Text(money(_totalValue(inv)), style: _s(14, bold: true)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          pw.Spacer(),
          pw.Text('TERMS', style: _s(7, bold: true, color: _mauve, spacing: 1)),
          pw.SizedBox(height: 3),
          pw.Text(_paymentNote(b), style: _s(8.5, color: _mauve)),
          if (payLink != null && payLink.isNotEmpty) ...[
            pw.SizedBox(height: 5),
            pw.UrlLink(destination: payLink, child: pw.Text('Pay online: $payLink', style: _s(8.5, bold: true))),
          ],
          pw.SizedBox(height: 16),
          doubleRule(),
          pw.SizedBox(height: 7),
          pw.Text(
            [b.name, b.website, b.email].where((s) => s.isNotEmpty).join('     ·     '),
            textAlign: pw.TextAlign.center,
            style: _s(8, color: _mauve),
          ),
        ],
      ),
    );
  }

  // 6. Compact — tight rows, meta strip, totals beside the note.
  pw.Page _compact(Invoice inv, Business b, String? payLink) {
    final kind = inv.isEstimate ? 'Estimate' : 'Invoice';
    final (_, _, label) = _status(inv.status);
    final initial = b.initials.isEmpty ? '·' : b.initials[0];
    return _page(
      (ctx) => pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Row(
            children: [
              pw.Container(
                width: 24,
                height: 24,
                alignment: pw.Alignment.center,
                decoration: pw.BoxDecoration(color: _wine, borderRadius: pw.BorderRadius.circular(6)),
                child: pw.Text(initial, style: _s(11, bold: true, color: _lemon)),
              ),
              pw.SizedBox(width: 8),
              pw.Expanded(
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(b.name, style: _s(12, bold: true)),
                    pw.Text([b.email, b.phone, b.address.replaceAll('\n', ', ')].where((s) => s.isNotEmpty).join('  ·  '), style: _s(7.5, color: _mauve)),
                  ],
                ),
              ),
              pw.Text('$kind ${inv.number}'.toUpperCase(), style: _m(10, bold: true, spacing: 0.6)),
            ],
          ),
          pw.SizedBox(height: 12),
          pw.Container(
            padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: pw.BoxDecoration(color: _linen, borderRadius: pw.BorderRadius.circular(6)),
            child: pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Expanded(child: _billedTo(inv, title: 'Bill to')),
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.end,
                  children: [
                    _th('Issued · Due', align: pw.TextAlign.right),
                    pw.SizedBox(height: 3),
                    pw.Text('${fmtDate(inv.issued, year: true)} · ${fmtDate(inv.due, year: true)}', style: _m(9)),
                    pw.SizedBox(height: 4),
                    pw.Text(label.toUpperCase(), style: _m(7, bold: true, color: _mauve, spacing: 0.8)),
                  ],
                ),
              ],
            ),
          ),
          pw.SizedBox(height: 10),
          _tableHead(),
          ..._rows(inv, pad: 4.5, size: 9),
          pw.SizedBox(height: 12),
          pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Expanded(
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    _th('Payment'),
                    pw.SizedBox(height: 3),
                    pw.Text(_paymentNote(b), style: _s(8, color: _mauve)),
                    if (payLink != null && payLink.isNotEmpty) ...[
                      pw.SizedBox(height: 4),
                      pw.UrlLink(destination: payLink, child: pw.Text('Pay online: $payLink', style: _m(7, color: _wine))),
                    ],
                  ],
                ),
              ),
              pw.SizedBox(width: 24),
              pw.SizedBox(
                width: 200,
                child: pw.Column(
                  children: [
                    ..._breakdown(inv),
                    pw.SizedBox(height: 4),
                    pw.Container(
                      padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                      decoration: pw.BoxDecoration(color: _wine, borderRadius: pw.BorderRadius.circular(6)),
                      child: pw.Row(
                        children: [
                          pw.Expanded(child: pw.Text(_totalLabel(inv), style: _s(9.5, bold: true, color: _white))),
                          pw.Text(money(_totalValue(inv)), style: _m(12, bold: true, color: _white)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          pw.Spacer(),
          pw.Row(
            children: [
              pw.Text('Thank you for your business.', style: _s(8, color: _mauve)),
              pw.Spacer(),
              pw.Text('Made with Invonce', style: _m(6.5, color: _mauve, spacing: 0.4)),
            ],
          ),
        ],
      ),
    );
  }

  // ─── Receipt ──────────────────────────────────────────────────────────────

  Future<Uint8List> _receipt(
    Invoice inv,
    Business b, {
    required double amount,
    required String method,
    required DateTime date,
    String? reference,
  }) async {
    final number = receiptNumber(inv);
    final balance = inv.balance < 0.005 ? 0.0 : inv.balance;
    final doc = pw.Document(title: '$number · ${b.name}', author: b.name, creator: 'Invonce');

    doc.addPage(
      _page(
        (ctx) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            _header(b, 'Receipt', badge: _pill(balance == 0 ? 'Paid in full' : 'Partial payment', _paidBg, _paidText)),
            pw.SizedBox(height: 34),
            pw.Center(
              child: pw.Column(
                children: [
                  _checkBadge(),
                  pw.SizedBox(height: 10),
                  pw.Text('PAYMENT RECEIVED', style: _m(8, bold: true, color: _paidText, spacing: 1.2)),
                  pw.SizedBox(height: 4),
                  pw.Text(money(amount), style: _s(30, bold: true)),
                  pw.SizedBox(height: 3),
                  pw.Text('${fmtDate(date, year: true)} · $method${reference != null ? ' · $reference' : ''}', style: _s(9, color: _mauve)),
                ],
              ),
            ),
            pw.SizedBox(height: 28),
            pw.Divider(color: _linen, thickness: 1),
            pw.SizedBox(height: 4),
            _kv('Receipt no.', number),
            _kv('For invoice', inv.number),
            _kv('Billed to', inv.client.name, mono: false),
            _kv('From', b.name, mono: false),
            pw.SizedBox(height: 4),
            pw.Divider(color: _linen, thickness: 1),
            pw.SizedBox(height: 8),
            _th('Items'),
            pw.SizedBox(height: 2),
            for (final item in inv.items)
              pw.Padding(
                padding: const pw.EdgeInsets.symmetric(vertical: 2.5),
                child: pw.Row(
                  children: [
                    pw.Expanded(child: pw.Text(item.name, style: _s(9))),
                    pw.Text(money(item.amount), style: _m(9)),
                  ],
                ),
              ),
            pw.SizedBox(height: 6),
            pw.Divider(color: _linen, thickness: 1),
            _kv('Invoice total', money(inv.total)),
            _kv('Paid to date', money(inv.paid), bold: true),
            pw.SizedBox(height: 8),
            pw.Row(
              children: [
                _pill('Balance ${money(balance)}', balance == 0 ? _paidBg : _lemon, balance == 0 ? _paidText : _wine),
              ],
            ),
            pw.Spacer(),
            _footer(b, 'This receipt confirms payment received for ${inv.number}. Keep it for your records.'),
          ],
        ),
      ),
    );
    return doc.save();
  }
}
