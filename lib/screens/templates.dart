import 'package:flutter/material.dart';

import '../data/app_store.dart';
import '../data/models.dart';
import '../motion/motion.dart';
import '../theme/tokens.dart';
import '../theme/typography.dart';
import '../widgets/widgets.dart';
import 'invoice_preview.dart';

/// Pick the document design. The choice is saved on the business and applies
/// to every invoice, estimate and receipt — on screen and in the PDF.
class TemplatesScreen extends StatefulWidget {
  const TemplatesScreen({super.key});

  @override
  State<TemplatesScreen> createState() => _TemplatesScreenState();
}

class _TemplatesScreenState extends State<TemplatesScreen> {
  static const _filters = ['All', 'Modern', 'Classic', 'Minimal'];

  int _filter = 0;
  InvoiceTemplate? _saving;

  Future<void> _use(InvoiceTemplate t) async {
    final store = AppScope.read(context);
    if (t == store.business.template || _saving != null) return;
    setState(() => _saving = t);
    try {
      await store.setTemplate(t);
      if (!mounted) return;
      Haptics.tap();
      toast(context, '${t.label} is now your template');
    } catch (e) {
      if (mounted) toast(context, "Couldn't save: $e");
    } finally {
      if (mounted) setState(() => _saving = null);
    }
  }

  void _preview(InvoiceTemplate t) {
    final sample = AppScope.read(context).documents.firstOrNull;
    if (sample == null) {
      toast(context, 'Create an invoice first to preview a template');
      return;
    }
    pushPage(context, InvoicePreviewScreen(invoice: sample, template: t));
  }

  @override
  Widget build(BuildContext context) {
    final dl = context.dl;
    final store = AppScope.watch(context);
    final inUse = _saving ?? store.business.template;
    final visible = [
      for (final t in InvoiceTemplate.values)
        if (_filter == 0 || t.category == _filters[_filter]) t,
    ];

    return ScreenScaffold(
      header: TopBar(
        title: 'Templates',
        trailing: [Text('${InvoiceTemplate.values.length} DESIGNS', style: Fonts.mono(size: 11, color: dl.muted))],
      ),
      bottom: [
        Expanded(
          child: DaylitButton('Preview ${inUse.label} with my invoice', onTap: () => _preview(inUse)),
        ),
      ],
      children: [
        ...stagger([
          ChipBar(labels: _filters, selected: _filter, onSelect: (i) => setState(() => _filter = i)),
          const SizedBox(height: 10),
          Text(inUse.blurb, style: Fonts.caption(dl.muted)),
          const SizedBox(height: 14),
        ]),
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          childAspectRatio: 0.92,
          children: [
            for (final t in visible)
              Pressable(
                onTap: () => _use(t),
                onLongPress: () => _preview(t),
                scale: 0.97,
                child: AnimatedContainer(
                  duration: Motion.standard,
                  curve: Motion.emphasized,
                  padding: const EdgeInsets.fromLTRB(8, 8, 8, 10),
                  decoration: BoxDecoration(
                    color: dl.surface,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: inUse == t ? Palette.wine : dl.border, width: 1.5),
                    boxShadow: inUse == t
                        ? [BoxShadow(color: Palette.wine.withValues(alpha: 0.08), spreadRadius: 3)]
                        : null,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Expanded(child: TemplateThumb(t)),
                      const SizedBox(height: 8),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: Row(
                          children: [
                            Expanded(child: Text(t.label, style: Fonts.sans(size: 13.5, weight: FontWeight.w700, color: dl.ink))),
                            if (inUse == t)
                              const Pill('In use', bg: Palette.lemon, fg: Palette.wine)
                            else
                              Text(t.category.toUpperCase(), style: Fonts.mono(size: 9, color: dl.muted)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 12),
        Text('Tap to use a template · hold to preview it', textAlign: TextAlign.center, style: Fonts.caption(dl.muted)),
      ],
    );
  }
}

/// Tiny schematic of each template's layout — mirrors `InvoiceDocument`.
class TemplateThumb extends StatelessWidget {
  const TemplateThumb(this.template, {super.key});

  final InvoiceTemplate template;

  @override
  Widget build(BuildContext context) {
    final dl = context.dl;
    Widget line(double w, {Color? color, double h = 4}) => Align(
          alignment: Alignment.centerLeft,
          child: FractionallySizedBox(
            widthFactor: w,
            child: Container(height: h, decoration: BoxDecoration(color: color ?? dl.border, borderRadius: BorderRadius.circular(2))),
          ),
        );
    Widget gap([double h = 5]) => SizedBox(height: h);
    Widget total(double w, Color color, {double h = 6}) => Align(
          alignment: Alignment.centerRight,
          child: FractionallySizedBox(
            widthFactor: w,
            child: Container(height: h, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(h / 3))),
          ),
        );

    final body = switch (template) {
      InvoiceTemplate.daylit => Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(width: 14, height: 14, decoration: BoxDecoration(color: Palette.wine, borderRadius: BorderRadius.circular(4))),
                Text('INVOICE', style: Fonts.mono(size: 6, weight: FontWeight.w600, color: dl.ink)),
              ],
            ),
            gap(8),
            line(0.5, color: Palette.sand), gap(), line(0.35),
            gap(8),
            line(1), gap(), line(1), gap(), line(1),
            const Spacer(),
            total(0.52, Palette.lemon, h: 14),
          ],
        ),
      InvoiceTemplate.ledger => Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('LEDGER NO. 0006', style: Fonts.mono(size: 6, weight: FontWeight.w600, tracking: 0.1, color: dl.ink)),
            gap(4), Container(height: 1, color: Palette.wine), gap(),
            line(0.45), gap(), line(0.3), gap(),
            Container(height: 1, color: Palette.sand), gap(),
            line(1, color: Palette.sand), gap(), line(1, color: Palette.sand), gap(), line(1, color: Palette.sand),
            const Spacer(),
            Container(height: 1, color: Palette.wine),
          ],
        ),
      InvoiceTemplate.clean => Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            line(0.3, color: const Color(0xFFDDDDDD)),
            const Spacer(),
            line(1, color: const Color(0xFFEEEEEE)), gap(), line(1, color: const Color(0xFFEEEEEE)), gap(), line(1, color: const Color(0xFFEEEEEE)),
            gap(),
            total(0.4, const Color(0xFFBBBBBB)),
          ],
        ),
      InvoiceTemplate.bold => Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              height: 40,
              padding: const EdgeInsets.all(10),
              decoration: const BoxDecoration(color: Palette.midnight, borderRadius: BorderRadius.vertical(top: Radius.circular(9))),
              child: line(0.5, color: Palette.lemon, h: 6),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 8, 10, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  line(1, color: Palette.sand), gap(), line(1, color: Palette.sand), gap(), line(1, color: Palette.sand), gap(8),
                  total(0.45, Palette.wine, h: 8),
                ],
              ),
            ),
          ],
        ),
      InvoiceTemplate.classic => Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(vertical: 5),
              decoration: const BoxDecoration(
                border: Border(top: BorderSide(color: Palette.wine, width: 2), bottom: BorderSide(color: Palette.wine, width: 2)),
              ),
              child: Text('INVOICE', textAlign: TextAlign.center, style: Fonts.sans(size: 7, weight: FontWeight.w700, tracking: 0.14, color: dl.ink)),
            ),
            gap(8), line(0.55), gap(), line(0.35), gap(8),
            line(1, color: Palette.sand), gap(), line(1, color: Palette.sand),
            const Spacer(),
            total(0.45, Palette.wine),
          ],
        ),
      InvoiceTemplate.compact => Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Container(width: 10, height: 10, decoration: BoxDecoration(color: Palette.wine, borderRadius: BorderRadius.circular(3))),
                const SizedBox(width: 4),
                Expanded(child: line(0.4, color: Palette.sand)),
              ],
            ),
            gap(4),
            for (var i = 0; i < 6; i++) ...[line(1), gap(3)],
            const Spacer(),
            Row(
              children: [
                Expanded(child: line(0.4, color: Palette.sand)),
                Expanded(child: total(0.6, Palette.wine)),
              ],
            ),
          ],
        ),
    };

    final padded = template == InvoiceTemplate.bold;
    final white = template == InvoiceTemplate.daylit || template == InvoiceTemplate.clean;
    return Container(
      padding: padded ? EdgeInsets.zero : const EdgeInsets.all(10),
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: white ? dl.surface : dl.bg,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: template == InvoiceTemplate.clean ? const Color(0xFFEEEEEE) : dl.border),
      ),
      child: body,
    );
  }
}
