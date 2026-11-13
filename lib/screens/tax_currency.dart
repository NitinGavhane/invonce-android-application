import 'package:flutter/material.dart';

import '../data/app_store.dart';
import '../motion/motion.dart';
import '../theme/tokens.dart';
import '../theme/typography.dart';
import '../widgets/widgets.dart';

class TaxCurrencyScreen extends StatefulWidget {
  const TaxCurrencyScreen({super.key});

  @override
  State<TaxCurrencyScreen> createState() => _TaxCurrencyScreenState();
}

class _TaxCurrencyScreenState extends State<TaxCurrencyScreen> {
  static const _currencies = ['USD \$', 'EUR €', 'GBP £', 'CAD \$', 'AUD \$', 'INR ₹'];
  static const _taxModes = ['On total', 'Per item', 'Inclusive'];
  int _currency = 0;
  int _taxMode = 0;
  bool _showTaxId = true;

  @override
  Widget build(BuildContext context) {
    final dl = context.dl;
    final business = AppScope.watch(context).business;

    return ScreenScaffold(
      header: const TopBar(title: 'Tax & currency'),
      bottom: [
        Expanded(
          child: DaylitButton('Save', onTap: () {
            Navigator.of(context).pop();
            toast(context, 'Tax & currency saved');
          }),
        ),
      ],
      children: stagger([
        const SectionLabel('Currency'),
        ChipBar(labels: _currencies, selected: _currency, onSelect: (i) => setState(() => _currency = i)),
        const SectionLabel('Default tax'),
        Row(
          children: [
            Expanded(child: FieldTile(label: 'Tax name', value: 'Sales tax')),
            const SizedBox(width: 10),
            Expanded(child: FieldTile(label: 'Rate', value: '${(business.taxRate * 100).round()}%', mono: true)),
          ],
        ),
        const SizedBox(height: 10),
        ChipBar(labels: _taxModes, selected: _taxMode, onSelect: (i) => setState(() => _taxMode = i)),
        const SizedBox(height: 8),
        Text(
          switch (_taxMode) {
            1 => 'Tax is set on each line item — handy when some items are exempt.',
            2 => 'Prices already include tax; the invoice shows the tax portion.',
            _ => 'One tax rate applied to the invoice subtotal after discounts.',
          },
          style: Fonts.caption(dl.muted),
        ),
        const SectionLabel('On documents'),
        ListCard(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 11),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Show tax ID on invoices', style: Fonts.sans(size: 14.5, weight: FontWeight.w600, color: dl.ink)),
                        Text('Uses the Tax ID from your business profile', style: Fonts.caption(dl.muted)),
                      ],
                    ),
                  ),
                  DaylitToggle(value: _showTaxId, onChanged: (v) => setState(() => _showTaxId = v)),
                ],
              ),
            ),
          ],
        ),
      ]),
    );
  }
}
