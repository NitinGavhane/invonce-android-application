import 'package:flutter/material.dart';

import '../data/format.dart';
import '../data/models.dart';
import '../theme/tokens.dart';
import '../theme/typography.dart';
import '../widgets/widgets.dart';

/// The document as the client will see it, drawn in [template]. Each layout
/// here has a matching one in `DocumentPdf`, so the preview is honest about
/// what the PDF will look like.
class InvoiceDocument extends StatelessWidget {
  const InvoiceDocument({
    super.key,
    required this.invoice,
    required this.business,
    required this.template,
  });

  final Invoice invoice;
  final Business business;
  final InvoiceTemplate template;

  @override
  Widget build(BuildContext context) {
    final look = _Look.of(template);
    final body = switch (template) {
      InvoiceTemplate.daylit => _Daylit(invoice, business, look),
      InvoiceTemplate.ledger => _Ledger(invoice, business, look),
      InvoiceTemplate.clean => _Clean(invoice, business, look),
      InvoiceTemplate.bold => _Bold(invoice, business, look),
      InvoiceTemplate.classic => _Classic(invoice, business, look),
      InvoiceTemplate.compact => _Compact(invoice, business, look),
    };
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: look.paper,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: look.frame),
        boxShadow: [
          BoxShadow(color: Palette.wine.withValues(alpha: 0.10), blurRadius: 40, offset: const Offset(0, 18)),
        ],
      ),
      child: body,
    );
  }
}

/// Colours for one template. The PDF side defines the same six sets.
class _Look {
  const _Look({
    required this.paper,
    required this.frame,
    required this.ink,
    required this.muted,
    required this.rule,
    required this.accent,
    required this.accentInk,
  });

  final Color paper;
  final Color frame;
  final Color ink;
  final Color muted;
  final Color rule;
  final Color accent;
  final Color accentInk;

  static _Look of(InvoiceTemplate t) => switch (t) {
        InvoiceTemplate.daylit => const _Look(
            paper: Palette.white, frame: Palette.linen, ink: Palette.wine, muted: Palette.mauve,
            rule: Palette.linen, accent: Palette.lemon, accentInk: Palette.wine),
        InvoiceTemplate.ledger => const _Look(
            paper: Palette.parchment, frame: Palette.sand, ink: Palette.wine, muted: Palette.mauve,
            rule: Palette.sand, accent: Palette.wine, accentInk: Palette.lemon),
        InvoiceTemplate.clean => const _Look(
            paper: Palette.white, frame: Color(0xFFEEEEEE), ink: Color(0xFF1A1A1A), muted: Color(0xFF8A8A8A),
            rule: Color(0xFFEEEEEE), accent: Color(0xFF1A1A1A), accentInk: Palette.white),
        InvoiceTemplate.bold => const _Look(
            paper: Palette.white, frame: Palette.linen, ink: Palette.midnight, muted: Palette.mauve,
            rule: Palette.linen, accent: Palette.wine, accentInk: Palette.lemon),
        InvoiceTemplate.classic => const _Look(
            paper: Palette.white, frame: Palette.linen, ink: Palette.wine, muted: Palette.mauve,
            rule: Palette.wine, accent: Palette.linen, accentInk: Palette.wine),
        InvoiceTemplate.compact => const _Look(
            paper: Palette.white, frame: Palette.linen, ink: Palette.wine, muted: Palette.mauve,
            rule: Palette.linen, accent: Palette.wine, accentInk: Palette.white),
      };
}

// ─── Shared pieces ──────────────────────────────────────────────────────────

String _kindOf(Invoice inv) => inv.isEstimate ? 'Estimate' : 'Invoice';

String _totalLabel(Invoice inv) => inv.isPaid ? 'Total paid' : (inv.paid > 0 ? 'Balance due' : 'Total due');

double _totalValue(Invoice inv) => inv.isPaid ? inv.total : inv.balance;

String _qty(LineItem i) => i.qty.toStringAsFixed(i.qty % 1 == 0 ? 0 : 2);

String _taxLabel(Invoice inv) {
  final pct = inv.taxRate * 100;
  return 'Tax (${pct.toStringAsFixed(pct % 1 == 0 ? 0 : 1)}%)';
}

/// The client name carries the Hero from the list row, whatever the layout.
Widget _clientName(Invoice inv, TextStyle style) => Hero(
      tag: 'inv-${inv.id}',
      child: Material(type: MaterialType.transparency, child: Text(inv.client.name, style: style)),
    );

class _Th extends StatelessWidget {
  const _Th(this.text, {required this.color, this.align = TextAlign.left, this.size = 9});

  final String text;
  final Color color;
  final TextAlign align;
  final double size;

  @override
  Widget build(BuildContext context) =>
      Text(text.toUpperCase(), textAlign: align, style: Fonts.mono(size: size, tracking: 0.07, color: color));
}

class _Kv extends StatelessWidget {
  const _Kv(this.k, this.v, {required this.look});

  final String k;
  final String v;
  final _Look look;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(
          children: [
            Expanded(child: Text(k, style: Fonts.sans(size: 12, color: look.muted))),
            Text(v, style: Fonts.mono(size: 12, tracking: 0, color: look.ink)),
          ],
        ),
      );
}

/// Subtotal / discount / tax / paid lines — the same in every template.
List<Widget> _breakdown(Invoice inv, _Look look) => [
      _Kv('Subtotal', money(inv.subtotal), look: look),
      if (inv.discount > 0) _Kv('Discount', '−${money(inv.discount)}', look: look),
      if (inv.taxRate > 0) _Kv(_taxLabel(inv), money(inv.tax), look: look),
      if (inv.paid > 0 && !inv.isPaid) _Kv('Paid', '−${money(inv.paid)}', look: look),
    ];

/// Description · Qty · Amount rows with a configurable rule colour.
class _ItemRows extends StatelessWidget {
  const _ItemRows(this.inv, this.look, {this.rate = false, this.dense = false, this.zebra = false, this.rule});

  final Invoice inv;
  final _Look look;
  final bool rate;
  final bool dense;
  final bool zebra;

  /// Divider colour; defaults to the template's rule colour.
  final Color? rule;

  @override
  Widget build(BuildContext context) {
    final rule = this.rule ?? look.rule;
    final pad = dense ? 5.0 : 8.0;
    final size = dense ? 12.0 : 13.0;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < inv.items.length; i++) ...[
          if (!zebra) Divider(height: 1, color: rule),
          Container(
            color: zebra && i.isOdd ? look.rule.withValues(alpha: 0.5) : null,
            padding: EdgeInsets.symmetric(vertical: pad, horizontal: zebra ? 6 : 0),
            child: Row(
              children: [
                Expanded(child: Text(inv.items[i].name, style: Fonts.sans(size: size, color: look.ink))),
                SizedBox(
                  width: 34,
                  child: Text(_qty(inv.items[i]), textAlign: TextAlign.center,
                      style: Fonts.mono(size: 12, tracking: 0, color: look.muted)),
                ),
                if (rate)
                  SizedBox(
                    width: 64,
                    child: Text(money(inv.items[i].rate), textAlign: TextAlign.right,
                        style: Fonts.mono(size: 11.5, tracking: 0, color: look.muted)),
                  ),
                SizedBox(
                  width: 74,
                  child: Text(money(inv.items[i].amount), textAlign: TextAlign.right,
                      style: Fonts.mono(size: 12, tracking: 0, color: look.ink)),
                ),
              ],
            ),
          ),
        ],
        Divider(height: 1, color: rule),
      ],
    );
  }
}

class _TableHead extends StatelessWidget {
  const _TableHead(this.look, {this.rate = false, this.fill, this.color});

  final _Look look;
  final bool rate;
  final Color? fill;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final c = color ?? look.muted;
    return Container(
      color: fill,
      padding: EdgeInsets.symmetric(vertical: fill == null ? 8 : 7, horizontal: fill == null ? 0 : 6),
      child: Row(
        children: [
          Expanded(child: _Th('Description', color: c)),
          SizedBox(width: 34, child: _Th('Qty', color: c, align: TextAlign.center)),
          if (rate) SizedBox(width: 64, child: _Th('Rate', color: c, align: TextAlign.right)),
          SizedBox(width: 74, child: _Th('Amount', color: c, align: TextAlign.right)),
        ],
      ),
    );
  }
}

Widget _paymentNote(Business b, _Look look, {double size = 11}) => Text(
      'Card, bank transfer, check or cash accepted. Thank you for your business — payment is due within ${b.dueInDays} days.',
      style: Fonts.sans(size: size, color: look.muted, height: 1.5),
    );

Widget _businessLines(Business b, _Look look, {TextAlign align = TextAlign.left, double size = 11}) => Column(
      crossAxisAlignment: align == TextAlign.right ? CrossAxisAlignment.end : CrossAxisAlignment.start,
      children: [
        for (final line in [b.email, b.phone, b.address.replaceAll('\n', ', ')])
          if (line.isNotEmpty) Text(line, textAlign: align, style: Fonts.sans(size: size, color: look.muted, height: 1.45)),
      ],
    );

// ─── 1. Daylit — the house look ─────────────────────────────────────────────

class _Daylit extends StatelessWidget {
  const _Daylit(this.inv, this.b, this.look);

  final Invoice inv;
  final Business b;
  final _Look look;

  @override
  Widget build(BuildContext context) {
    final kind = _kindOf(inv);
    return Padding(
      padding: const EdgeInsets.all(22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Row(
                  children: [
                    Container(
                      width: 42,
                      height: 42,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(color: Palette.wine, borderRadius: BorderRadius.circular(12)),
                      child: Text(b.initials.isEmpty ? '·' : b.initials[0],
                          style: Fonts.sans(size: 18, weight: FontWeight.w800, tracking: 0, color: Palette.lemon)),
                    ),
                    const SizedBox(width: 11),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(b.name, style: Fonts.body(look.ink)),
                          Text(b.email, style: Fonts.sans(size: 11, color: look.muted)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(kind.toUpperCase(), style: Fonts.mono(size: 20, weight: FontWeight.w600, tracking: 0.02, color: look.ink)),
                  const SizedBox(height: 6),
                  StatusPill(inv.status),
                ],
              ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _Th('Billed to', color: look.muted),
                    const SizedBox(height: 4),
                    _clientName(inv, Fonts.sans(size: 13, weight: FontWeight.w600, color: look.ink)),
                    const SizedBox(height: 2),
                    Text(inv.client.address.replaceFirst(', ', '\n'), style: Fonts.sans(size: 11, color: look.muted, height: 1.5)),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  _Th('$kind no.', color: look.muted),
                  const SizedBox(height: 4),
                  Text(inv.number, style: Fonts.mono(size: 12, tracking: 0, color: look.ink)),
                  const SizedBox(height: 10),
                  _Th('Issued · Due', color: look.muted),
                  const SizedBox(height: 4),
                  Text('${fmtDate(inv.issued)} · ${fmtDate(inv.due)}', style: Fonts.mono(size: 12, tracking: 0, color: look.ink)),
                ],
              ),
            ],
          ),
          const SizedBox(height: 18),
          Divider(height: 1, color: look.rule),
          _TableHead(look),
          _ItemRows(inv, look),
          const SizedBox(height: 14),
          Align(
            alignment: Alignment.centerRight,
            child: SizedBox(
              width: 184,
              child: Column(
                children: [
                  ..._breakdown(inv, look),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                    decoration: BoxDecoration(color: look.accent, borderRadius: BorderRadius.circular(10)),
                    child: Row(
                      children: [
                        Expanded(child: Text(_totalLabel(inv), style: Fonts.sans(size: 13, weight: FontWeight.w700, color: look.accentInk))),
                        Text(money(_totalValue(inv)), style: Fonts.mono(size: 16, weight: FontWeight.w600, tracking: -0.02, color: look.accentInk)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 18),
          Divider(height: 1, color: look.rule),
          const SizedBox(height: 12),
          _Th('Payment', color: look.muted),
          const SizedBox(height: 4),
          _paymentNote(b, look),
        ],
      ),
    );
  }
}

// ─── 2. Ledger — mono, ruled, bookkeeper ────────────────────────────────────

class _Ledger extends StatelessWidget {
  const _Ledger(this.inv, this.b, this.look);

  final Invoice inv;
  final Business b;
  final _Look look;

  @override
  Widget build(BuildContext context) {
    final kind = _kindOf(inv);
    final (_, _, statusLabel) = StatusPill.styleOf(inv.status);
    Widget rule([double w = 1]) => Container(height: w, color: Palette.wine);
    return Padding(
      padding: const EdgeInsets.all(22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text('${kind.toUpperCase()} NO. ${inv.number.replaceFirst(RegExp(r'^[A-Z]+-'), '')}',
                    style: Fonts.mono(size: 12, weight: FontWeight.w600, tracking: 0.1, color: look.ink)),
              ),
              Text(statusLabel.toUpperCase(), style: Fonts.mono(size: 10, weight: FontWeight.w600, tracking: 0.1, color: look.muted)),
            ],
          ),
          const SizedBox(height: 8),
          rule(1.5),
          const SizedBox(height: 14),
          Text(b.name, style: Fonts.sans(size: 17, weight: FontWeight.w700, tracking: -0.02, color: look.ink)),
          const SizedBox(height: 2),
          _businessLines(b, look),
          const SizedBox(height: 16),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _Th('Bill to', color: look.muted),
                    const SizedBox(height: 4),
                    _clientName(inv, Fonts.mono(size: 12.5, weight: FontWeight.w600, tracking: 0, color: look.ink)),
                    const SizedBox(height: 2),
                    Text(inv.client.address.replaceFirst(', ', '\n'), style: Fonts.sans(size: 11, color: look.muted, height: 1.5)),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _Th('Issued', color: look.muted),
                  const SizedBox(height: 4),
                  Text(fmtDate(inv.issued, year: true), style: Fonts.mono(size: 11.5, tracking: 0, color: look.ink)),
                  const SizedBox(height: 8),
                  _Th('Due', color: look.muted),
                  const SizedBox(height: 4),
                  Text(fmtDate(inv.due, year: true), style: Fonts.mono(size: 11.5, tracking: 0, color: look.ink)),
                ],
              ),
            ],
          ),
          const SizedBox(height: 18),
          rule(),
          _TableHead(look, rate: true, color: look.ink),
          _ItemRows(inv, look, rate: true, rule: Palette.sand),
          const SizedBox(height: 10),
          Align(
            alignment: Alignment.centerRight,
            child: SizedBox(
              width: 200,
              child: Column(
                children: [
                  ..._breakdown(inv, look),
                  const SizedBox(height: 6),
                  rule(),
                  const SizedBox(height: 2),
                  rule(),
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Row(
                      children: [
                        Expanded(child: Text(_totalLabel(inv).toUpperCase(), style: Fonts.mono(size: 10, weight: FontWeight.w600, tracking: 0.08, color: look.ink))),
                        Text(money(_totalValue(inv)), style: Fonts.mono(size: 16, weight: FontWeight.w600, tracking: 0, color: look.ink)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),
          _paymentNote(b, look, size: 10.5),
          const SizedBox(height: 14),
          rule(1.5),
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(child: Text(b.website, style: Fonts.mono(size: 9.5, tracking: 0, color: look.muted))),
              Text('PAGE 1 / 1', style: Fonts.mono(size: 9.5, tracking: 0.06, color: look.muted)),
            ],
          ),
        ],
      ),
    );
  }
}

// ─── 3. Clean — grey on white, lots of air ──────────────────────────────────

class _Clean extends StatelessWidget {
  const _Clean(this.inv, this.b, this.look);

  final Invoice inv;
  final Business b;
  final _Look look;

  @override
  Widget build(BuildContext context) {
    final kind = _kindOf(inv);
    final (_, _, statusLabel) = StatusPill.styleOf(inv.status);
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(kind, style: Fonts.sans(size: 13, weight: FontWeight.w500, tracking: 0, color: look.muted)),
          const SizedBox(height: 4),
          Text(b.name, style: Fonts.sans(size: 22, weight: FontWeight.w700, tracking: -0.03, color: look.ink)),
          const SizedBox(height: 30),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Billed to', style: Fonts.sans(size: 11, color: look.muted)),
                    const SizedBox(height: 4),
                    _clientName(inv, Fonts.sans(size: 13, weight: FontWeight.w600, color: look.ink)),
                    Text(inv.client.address.replaceFirst(', ', '\n'), style: Fonts.sans(size: 11, color: look.muted, height: 1.5)),
                  ],
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (final (k, v) in [
                      ('Number', inv.number),
                      ('Issued', fmtDate(inv.issued, year: true)),
                      ('Due', fmtDate(inv.due, year: true)),
                      ('Status', statusLabel),
                    ])
                      Padding(
                        padding: const EdgeInsets.only(bottom: 3),
                        child: Row(
                          children: [
                            SizedBox(width: 52, child: Text(k, style: Fonts.sans(size: 11, color: look.muted))),
                            Expanded(child: Text(v, style: Fonts.sans(size: 11.5, weight: FontWeight.w500, color: look.ink))),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 30),
          Row(
            children: [
              Expanded(child: Text('Description', style: Fonts.sans(size: 11, color: look.muted))),
              SizedBox(width: 34, child: Text('Qty', textAlign: TextAlign.center, style: Fonts.sans(size: 11, color: look.muted))),
              SizedBox(width: 74, child: Text('Amount', textAlign: TextAlign.right, style: Fonts.sans(size: 11, color: look.muted))),
            ],
          ),
          const SizedBox(height: 8),
          for (final item in inv.items) ...[
            Divider(height: 1, color: look.rule),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 10),
              child: Row(
                children: [
                  Expanded(child: Text(item.name, style: Fonts.sans(size: 13, color: look.ink))),
                  SizedBox(width: 34, child: Text(_qty(item), textAlign: TextAlign.center, style: Fonts.sans(size: 12, color: look.muted))),
                  SizedBox(width: 74, child: Text(money(item.amount), textAlign: TextAlign.right, style: Fonts.sans(size: 13, color: look.ink))),
                ],
              ),
            ),
          ],
          Divider(height: 1, color: look.rule),
          const SizedBox(height: 16),
          Align(
            alignment: Alignment.centerRight,
            child: SizedBox(
              width: 190,
              child: Column(
                children: [
                  for (final (k, v) in [
                    ('Subtotal', money(inv.subtotal)),
                    if (inv.discount > 0) ('Discount', '−${money(inv.discount)}'),
                    if (inv.taxRate > 0) (_taxLabel(inv), money(inv.tax)),
                    if (inv.paid > 0 && !inv.isPaid) ('Paid', '−${money(inv.paid)}'),
                  ])
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 3),
                      child: Row(
                        children: [
                          Expanded(child: Text(k, style: Fonts.sans(size: 12, color: look.muted))),
                          Text(v, style: Fonts.sans(size: 12, color: look.ink)),
                        ],
                      ),
                    ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(child: Text(_totalLabel(inv), style: Fonts.sans(size: 13, weight: FontWeight.w600, color: look.ink))),
                      Text(money(_totalValue(inv)), style: Fonts.sans(size: 22, weight: FontWeight.w700, tracking: -0.03, color: look.ink)),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 34),
          _paymentNote(b, look),
          const SizedBox(height: 6),
          Text([b.email, b.phone].where((s) => s.isNotEmpty).join('  ·  '), style: Fonts.sans(size: 11, color: look.muted)),
        ],
      ),
    );
  }
}

// ─── 4. Bold — midnight band, wine total bar ────────────────────────────────

class _Bold extends StatelessWidget {
  const _Bold(this.inv, this.b, this.look);

  final Invoice inv;
  final Business b;
  final _Look look;

  @override
  Widget build(BuildContext context) {
    final kind = _kindOf(inv);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          color: Palette.midnight,
          padding: const EdgeInsets.fromLTRB(22, 22, 22, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(b.name, style: Fonts.sans(size: 20, weight: FontWeight.w800, tracking: -0.03, color: Palette.lemon)),
                  ),
                  const SizedBox(width: 12),
                  StatusPill(inv.status),
                ],
              ),
              const SizedBox(height: 3),
              Text([b.email, b.phone].where((s) => s.isNotEmpty).join('  ·  '), style: Fonts.sans(size: 11, color: Palette.rose)),
              const SizedBox(height: 18),
              Text(kind.toUpperCase(), style: Fonts.sans(size: 34, weight: FontWeight.w800, tracking: -0.04, color: Palette.white, height: 1)),
              const SizedBox(height: 6),
              Text('${inv.number}   ·   Issued ${fmtDate(inv.issued)}   ·   Due ${fmtDate(inv.due)}',
                  style: Fonts.mono(size: 10.5, tracking: 0.02, color: Palette.rose)),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(22, 20, 22, 22),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _Th('Billed to', color: look.muted),
              const SizedBox(height: 4),
              _clientName(inv, Fonts.sans(size: 15, weight: FontWeight.w700, tracking: -0.01, color: look.ink)),
              Text(inv.client.address, style: Fonts.sans(size: 11, color: look.muted, height: 1.5)),
              const SizedBox(height: 18),
              _TableHead(look, fill: look.rule, color: look.ink),
              _ItemRows(inv, look, zebra: true),
              const SizedBox(height: 14),
              Align(
                alignment: Alignment.centerRight,
                child: SizedBox(width: 200, child: Column(children: _breakdown(inv, look))),
              ),
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                decoration: BoxDecoration(color: look.accent, borderRadius: BorderRadius.circular(12)),
                child: Row(
                  children: [
                    Expanded(child: Text(_totalLabel(inv).toUpperCase(), style: Fonts.mono(size: 11, weight: FontWeight.w600, tracking: 0.08, color: look.accentInk))),
                    Text(money(_totalValue(inv)), style: Fonts.sans(size: 24, weight: FontWeight.w800, tracking: -0.03, color: look.accentInk)),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              _paymentNote(b, look),
            ],
          ),
        ),
      ],
    );
  }
}

// ─── 5. Classic — centred title, double rules ───────────────────────────────

class _Classic extends StatelessWidget {
  const _Classic(this.inv, this.b, this.look);

  final Invoice inv;
  final Business b;
  final _Look look;

  @override
  Widget build(BuildContext context) {
    final kind = _kindOf(inv);
    final (_, _, statusLabel) = StatusPill.styleOf(inv.status);
    Widget doubleRule() => Column(children: [
          Container(height: 2, color: look.rule),
          const SizedBox(height: 2),
          Container(height: 0.8, color: look.rule),
        ]);
    Widget block(String title, List<Widget> lines, {CrossAxisAlignment align = CrossAxisAlignment.start}) => Column(
          crossAxisAlignment: align,
          children: [
            Text(title.toUpperCase(), style: Fonts.sans(size: 9.5, weight: FontWeight.w700, tracking: 0.12, color: look.muted)),
            const SizedBox(height: 5),
            ...lines,
          ],
        );
    return Padding(
      padding: const EdgeInsets.all(22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          doubleRule(),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: Column(
              children: [
                Text(kind.toUpperCase(), style: Fonts.sans(size: 18, weight: FontWeight.w700, tracking: 0.22, color: look.ink)),
                const SizedBox(height: 2),
                Text('${inv.number}  ·  $statusLabel', style: Fonts.mono(size: 10.5, tracking: 0.04, color: look.muted)),
              ],
            ),
          ),
          doubleRule(),
          const SizedBox(height: 18),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: block('From', [
                  Text(b.name, style: Fonts.sans(size: 13, weight: FontWeight.w700, color: look.ink)),
                  _businessLines(b, look),
                ]),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: block('Bill to', [
                  _clientName(inv, Fonts.sans(size: 13, weight: FontWeight.w700, color: look.ink)),
                  Text(inv.client.address.replaceFirst(', ', '\n'), style: Fonts.sans(size: 11, color: look.muted, height: 1.45)),
                ]),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(child: block('Date issued', [Text(fmtDate(inv.issued, year: true), style: Fonts.sans(size: 12, weight: FontWeight.w500, color: look.ink))])),
              Expanded(child: block('Date due', [Text(fmtDate(inv.due, year: true), style: Fonts.sans(size: 12, weight: FontWeight.w500, color: look.ink))])),
              Expanded(
                child: block('Amount due', [Text(money(_totalValue(inv)), style: Fonts.sans(size: 12, weight: FontWeight.w700, color: look.ink))],
                    align: CrossAxisAlignment.end),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Container(
            decoration: BoxDecoration(border: Border.all(color: look.rule, width: 0.8)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _TableHead(look, rate: true, fill: look.accent, color: look.ink),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  child: _ItemRows(inv, look, rate: true, rule: look.rule.withValues(alpha: 0.25)),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          Align(
            alignment: Alignment.centerRight,
            child: SizedBox(
              width: 200,
              child: Column(
                children: [
                  ..._breakdown(inv, look),
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    decoration: BoxDecoration(border: Border(top: BorderSide(color: look.rule, width: 1.5), bottom: BorderSide(color: look.rule, width: 1.5))),
                    child: Row(
                      children: [
                        Expanded(child: Text(_totalLabel(inv), style: Fonts.sans(size: 13, weight: FontWeight.w700, color: look.ink))),
                        Text(money(_totalValue(inv)), style: Fonts.sans(size: 16, weight: FontWeight.w700, tracking: -0.02, color: look.ink)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
          Text('Terms', style: Fonts.sans(size: 9.5, weight: FontWeight.w700, tracking: 0.12, color: look.muted)),
          const SizedBox(height: 4),
          _paymentNote(b, look),
          const SizedBox(height: 16),
          doubleRule(),
          const SizedBox(height: 8),
          Text(
            [b.name, b.website, b.email].where((s) => s.isNotEmpty).join('   ·   '),
            textAlign: TextAlign.center,
            style: Fonts.sans(size: 10, color: look.muted),
          ),
        ],
      ),
    );
  }
}

// ─── 6. Compact — everything on one page ────────────────────────────────────

class _Compact extends StatelessWidget {
  const _Compact(this.inv, this.b, this.look);

  final Invoice inv;
  final Business b;
  final _Look look;

  @override
  Widget build(BuildContext context) {
    final kind = _kindOf(inv);
    final (_, _, statusLabel) = StatusPill.styleOf(inv.status);
    return Padding(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: 26,
                height: 26,
                alignment: Alignment.center,
                decoration: BoxDecoration(color: Palette.wine, borderRadius: BorderRadius.circular(7)),
                child: Text(b.initials.isEmpty ? '·' : b.initials[0],
                    style: Fonts.sans(size: 12, weight: FontWeight.w800, tracking: 0, color: Palette.lemon)),
              ),
              const SizedBox(width: 8),
              Expanded(child: Text(b.name, style: Fonts.sans(size: 13.5, weight: FontWeight.w700, color: look.ink))),
              Text('$kind ${inv.number}'.toUpperCase(), style: Fonts.mono(size: 10.5, weight: FontWeight.w600, tracking: 0.04, color: look.ink)),
            ],
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(color: look.rule, borderRadius: BorderRadius.circular(8)),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _Th('Bill to', color: look.muted, size: 8.5),
                      const SizedBox(height: 2),
                      _clientName(inv, Fonts.sans(size: 12.5, weight: FontWeight.w600, color: look.ink)),
                      Text(inv.client.address, maxLines: 1, overflow: TextOverflow.ellipsis, style: Fonts.sans(size: 10, color: look.muted)),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text('${fmtDate(inv.issued)} → ${fmtDate(inv.due)}', style: Fonts.mono(size: 10, tracking: 0, color: look.ink)),
                    const SizedBox(height: 3),
                    Text(statusLabel.toUpperCase(), style: Fonts.mono(size: 9, weight: FontWeight.w600, tracking: 0.08, color: look.muted)),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          _TableHead(look, rate: true),
          _ItemRows(inv, look, rate: true, dense: true),
          const SizedBox(height: 10),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: _paymentNote(b, look, size: 9.5)),
              const SizedBox(width: 12),
              SizedBox(
                width: 150,
                child: Column(
                  children: [
                    ..._breakdown(inv, look),
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 7),
                      decoration: BoxDecoration(color: look.accent, borderRadius: BorderRadius.circular(7)),
                      child: Row(
                        children: [
                          Expanded(child: Text(_totalLabel(inv), style: Fonts.sans(size: 11, weight: FontWeight.w700, color: look.accentInk))),
                          Text(money(_totalValue(inv)), style: Fonts.mono(size: 13, weight: FontWeight.w600, tracking: -0.01, color: look.accentInk)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
