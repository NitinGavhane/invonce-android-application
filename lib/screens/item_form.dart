import 'package:flutter/material.dart';

import '../data/app_store.dart';
import '../data/models.dart';
import '../motion/motion.dart';
import '../widgets/sheets.dart';
import '../widgets/widgets.dart';

/// Creates a saved product/service. Returns it so a picker can use it at once.
Future<CatalogItem?> showItemSheet(BuildContext context) =>
    showSheet<CatalogItem>(context, (_) => const _ItemSheet());

class _ItemSheet extends StatefulWidget {
  const _ItemSheet();

  @override
  State<_ItemSheet> createState() => _ItemSheetState();
}

class _ItemSheetState extends State<_ItemSheet> {
  static const _kinds = ['Service', 'Product'];
  static const _units = ['flat', 'per hour', 'per day', 'per unit', 'per month', 'per year'];

  final _name = TextEditingController();
  final _price = TextEditingController();
  int _kind = 0;
  int _unit = 0;
  bool _busy = false;

  @override
  void dispose() {
    _name.dispose();
    _price.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final name = _name.text.trim();
    if (name.isEmpty) {
      toast(context, 'Give the item a name');
      return;
    }
    final price = parseAmount(_price.text);
    if (price == null) {
      toast(context, 'Enter a price');
      return;
    }
    setState(() => _busy = true);
    try {
      final item = await AppScope.read(context).addItem(
        name: name,
        kind: _kinds[_kind],
        unit: _units[_unit],
        price: price,
        priceLabel: _unit == 1 ? '/hr' : (_unit == 2 ? '/day' : null),
      );
      if (!mounted) return;
      Haptics.success();
      Navigator.of(context).pop(item);
    } catch (e) {
      if (mounted) {
        toast(context, "Couldn't save item: $e");
        setState(() => _busy = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return SheetShell(
      title: 'New item',
      subtitle: 'Saved items are one tap away when you build an invoice.',
      saveLabel: 'Save item',
      busy: _busy,
      onSave: _save,
      children: [
        SheetInput(label: 'Name', controller: _name, hint: 'e.g. Website design', autofocus: true),
        SheetInput(
          label: 'Price',
          controller: _price,
          hint: '0.00',
          mono: true,
          keyboard: const TextInputType.numberWithOptions(decimal: true),
          onSubmit: _save,
        ),
        const SectionLabel('Type'),
        ChipBar(labels: _kinds, selected: _kind, onSelect: (i) => setState(() => _kind = i)),
        const SectionLabel('Billed'),
        ChipBar(labels: _units, selected: _unit, onSelect: (i) => setState(() => _unit = i)),
      ],
    );
  }
}
