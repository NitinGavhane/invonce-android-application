import 'package:flutter/material.dart';

import '../data/app_store.dart';
import '../data/format.dart';
import '../data/models.dart';
import '../motion/motion.dart';
import '../theme/tokens.dart';
import '../theme/typography.dart';
import '../widgets/widgets.dart';
import 'amount_sheet.dart';
import 'receipt.dart';

class RecordPaymentScreen extends StatefulWidget {
  const RecordPaymentScreen({super.key, required this.invoice});

  final Invoice invoice;

  @override
  State<RecordPaymentScreen> createState() => _RecordPaymentScreenState();
}

class _RecordPaymentScreenState extends State<RecordPaymentScreen> {
  static const _portions = [0.25, 0.5, 1.0];
  static const _methods = ['Card', 'Cash', 'Check', 'Bank transfer', 'Other'];

  bool _full = true;
  int _portion = 2;
  int _method = 0;
  double? _custom;
  bool _saving = false;

  double get _amount => _custom ?? widget.invoice.balance * (_full ? 1 : _portions[_portion]);

  Future<void> _pickCustom() async {
    final v = await showAmountSheet(context, balance: widget.invoice.balance);
    if (v == null || !mounted) return;
    setState(() {
      _custom = v;
      _full = false;
    });
  }

  Future<void> _record(AppStore store) async {
    final amount = _amount;
    final reference = '#${4400 + store.invoices.length}';
    setState(() => _saving = true);
    try {
      final updated = await store.recordPayment(widget.invoice, amount: amount, method: _methods[_method], reference: reference);
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute<void>(
          builder: (_) => ReceiptScreen(invoice: updated, amount: amount, method: _methods[_method], reference: reference),
        ),
      );
    } catch (e) {
      if (mounted) toast(context, "Couldn't record payment: $e");
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final dl = context.dl;
    final store = AppScope.watch(context);
    final inv = widget.invoice;
    final amount = _amount;
    final settles = amount >= inv.balance - 0.005;

    return ScreenScaffold(
      header: const TopBar(title: 'Record payment'),
      bottom: [
        Expanded(
          child: DaylitButton(
            _saving ? 'Recording…' : 'Record ${money(amount)}${settles ? ' & mark paid' : ''}',
            icon: Icons.check_rounded,
            onTap: _saving ? null : () => _record(store),
          ),
        ),
      ],
      children: stagger([
        DaylitCard(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              AvatarTile(inv.client.initials, color: inv.client.color),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('${inv.number} · ${inv.client.name}', style: Fonts.body(dl.ink)),
                    const SizedBox(height: 2),
                    Text('Total ${money(inv.total, cents: false)} · Paid ${money(inv.paid, cents: false)}',
                        style: Fonts.mono(size: 11, tracking: 0, color: dl.muted)),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  const Eyebrow('Balance', size: 9.5),
                  const SizedBox(height: 2),
                  Text(money(inv.balance, cents: false), style: Fonts.amount(dl.ink)),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        DaylitCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Eyebrow('Amount received', size: 10),
              const SizedBox(height: 4),
              AnimatedSwitcher(
                duration: Motion.standard,
                switchInCurve: Motion.spring,
                transitionBuilder: (c, a) => FadeTransition(opacity: a, child: ScaleTransition(scale: a, alignment: Alignment.centerLeft, child: c)),
                child: RichText(
                  key: ValueKey(amount),
                  text: TextSpan(
                    text: money(amount, cents: false),
                    style: Fonts.mono(size: 36, weight: FontWeight.w600, tracking: -0.03, color: dl.ink),
                    children: [
                      TextSpan(
                        text: '.${((amount - amount.floor()) * 100).round().toString().padLeft(2, '0')}',
                        style: Fonts.mono(size: 20, weight: FontWeight.w500, color: dl.muted),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              _Segmented(
                labels: const ['Full payment', 'Partial / deposit'],
                selected: _full ? 0 : 1,
                onSelect: (i) => setState(() {
                  _full = i == 0;
                  _custom = null;
                  if (_full) _portion = 2;
                }),
              ),
              const SizedBox(height: 10),
              ChipBar(
                labels: const ['25%', '50%', '100%', 'Custom'],
                selected: _custom != null ? 3 : (_full ? 2 : _portion),
                onSelect: (i) {
                  if (i == 3) {
                    _pickCustom();
                    return;
                  }
                  setState(() {
                    _custom = null;
                    _portion = i;
                    _full = i == 2;
                  });
                },
              ),
            ],
          ),
        ),
        const SectionLabel('Payment method'),
        ChipBar(labels: _methods, selected: _method, onSelect: (i) => setState(() => _method = i)),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(child: FieldTile(label: 'Date', value: fmtDate(store.today, year: true))),
            const SizedBox(width: 10),
            Expanded(child: FieldTile(label: 'Reference', value: '#${4400 + store.invoices.length}', mono: true)),
          ],
        ),
        const SizedBox(height: 10),
        const FieldTile(label: 'Note (optional)', value: 'Add a note for your records', muted: true, minHeight: 72),
      ]),
    );
  }
}

class _Segmented extends StatelessWidget {
  const _Segmented({required this.labels, required this.selected, required this.onSelect});

  final List<String> labels;
  final int selected;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    final dl = context.dl;
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: dl.bg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: dl.border),
      ),
      child: Row(
        children: [
          for (var i = 0; i < labels.length; i++)
            Expanded(
              child: Pressable(
                onTap: () => onSelect(i),
                scale: 0.97,
                child: AnimatedContainer(
                  duration: Motion.standard,
                  curve: Motion.emphasized,
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  decoration: BoxDecoration(
                    color: i == selected ? Palette.wine : Colors.transparent,
                    borderRadius: BorderRadius.circular(9),
                  ),
                  child: Center(
                    child: Text(
                      labels[i],
                      style: Fonts.sans(size: 13, weight: FontWeight.w600, color: i == selected ? Palette.lemon : dl.muted),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
