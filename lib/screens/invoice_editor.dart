import 'package:flutter/material.dart';

import '../data/app_store.dart';
import '../data/format.dart';
import '../data/models.dart';
import '../motion/motion.dart';
import '../theme/tokens.dart';
import '../theme/typography.dart';
import '../widgets/widgets.dart';
import 'client_form.dart';
import 'invoice_preview.dart';
import 'items.dart';

class InvoiceEditorScreen extends StatefulWidget {
  const InvoiceEditorScreen({super.key, this.client, this.initialItems, this.isEstimate = false});

  final Client? client;
  final List<LineItem>? initialItems;
  final bool isEstimate;

  @override
  State<InvoiceEditorScreen> createState() => _InvoiceEditorScreenState();
}

class _InvoiceEditorScreenState extends State<InvoiceEditorScreen> {
  late Client? _client = widget.client;
  late final List<LineItem> _items = List.of(widget.initialItems ?? const []);
  double _discount = 0;

  /// Starts at the business default; the × on the Tax line sets it to 0.
  late double _taxRate = AppScope.read(context).business.taxRate;
  bool _saving = false;

  Invoice _draft(AppStore store) {
    return store
        .newDraft(client: _client ?? _placeholderClient, items: List.unmodifiable(_items), estimate: widget.isEstimate)
        .copyWith(discount: _discount, taxRate: _taxRate);
  }

  static const _placeholderClient = Client(
    id: '', name: 'Choose a client', initials: '?', email: 'Tap to pick who to bill', phone: '', address: '', color: Palette.sand,
  );

  Future<void> _addItem() async {
    final item = await pushPage<CatalogItem>(context, const ItemsScreen(picker: true));
    if (!mounted || item == null) return;
    if (item.price == null) {
      toast(context, '${item.name} is a percentage — set it on the total');
      return;
    }
    setState(() => _items.add(LineItem(name: item.name, rate: item.price!)));
  }

  bool _validate(Invoice draft) {
    if (draft.client.id.isEmpty) {
      toast(context, 'Choose a client first');
      return false;
    }
    if (draft.items.isEmpty) {
      toast(context, 'Add at least one item');
      return false;
    }
    return true;
  }

  Future<void> _save(AppStore store, {required bool preview}) async {
    final draft = _draft(store);
    if (!_validate(draft)) return;
    setState(() => _saving = true);
    try {
      final saved = await store.saveInvoice(draft);
      if (!mounted) return;
      Haptics.success();
      if (preview) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute<void>(builder: (_) => InvoicePreviewScreen(invoice: saved)),
        );
      } else {
        Navigator.of(context).pop();
        toast(context, '${saved.number} saved');
      }
    } catch (e) {
      if (mounted) toast(context, "Couldn't save: $e");
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final dl = context.dl;
    final store = AppScope.watch(context);
    final draft = _draft(store);
    final client = draft.client;

    return ScreenScaffold(
      header: TopBar(
        title: widget.isEstimate ? 'New estimate' : 'New invoice',
        trailing: [
          Pressable(
            onTap: () {
              if (_validate(draft)) pushPage(context, InvoicePreviewScreen(invoice: draft));
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
              child: Text('Preview', style: Fonts.sans(size: 14, weight: FontWeight.w700, color: dl.rust)),
            ),
          ),
        ],
      ),
      bottom: [
        Expanded(
          flex: 10,
          child: DaylitButton(
            'Save draft',
            variant: DaylitVariant.ghost,
            onTap: _saving ? null : () => _save(store, preview: false),
          ),
        ),
        Expanded(
          flex: 14,
          child: DaylitButton(
            _saving ? 'Saving…' : 'Save & preview',
            onTap: _saving ? null : () => _save(store, preview: true),
          ),
        ),
      ],
      children: stagger([
        Row(
          children: [
            Expanded(child: FieldTile(label: 'No.', value: draft.number, mono: true)),
            const SizedBox(width: 10),
            Expanded(child: FieldTile(label: 'Issued', value: fmtDate(draft.issued))),
            const SizedBox(width: 10),
            Expanded(child: FieldTile(label: 'Due', value: fmtDate(draft.due))),
          ],
        ),
        const SectionLabel('Bill to'),
        Pressable(
          onTap: () => _pickClient(context, store),
          scale: 0.985,
          child: DaylitCard(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                AvatarTile(client.initials, size: 40, color: client.color),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(client.name, style: Fonts.body(client.id.isEmpty ? dl.muted : dl.ink)),
                      const SizedBox(height: 2),
                      Text(client.email, style: Fonts.caption(dl.muted)),
                    ],
                  ),
                ),
                Chevron(color: dl.muted),
              ],
            ),
          ),
        ),
        const SectionLabel('Items'),
        DaylitCard(
          padding: const EdgeInsets.fromLTRB(16, 2, 16, 2),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (var i = 0; i < _items.length; i++) ...[
                if (i > 0) Divider(height: 1, color: dl.border),
                _ItemRow(
                  item: _items[i],
                  onRemove: () => setState(() => _items.removeAt(i)),
                ),
              ],
              if (_items.isNotEmpty) Divider(height: 1, color: dl.border),
              Pressable(
                onTap: _addItem,
                scale: 0.985,
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 13),
                  child: Row(
                    children: [
                      Icon(Icons.add_rounded, size: 20, color: dl.rust),
                      const SizedBox(width: 8),
                      Text(_items.isEmpty ? 'Add your first item' : 'Add item',
                          style: Fonts.sans(size: 14, weight: FontWeight.w700, color: dl.rust)),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        DaylitCard(
          child: Column(
            children: [
              _TotalLine('Subtotal', money(draft.subtotal)),
              _TotalLine(
                'Discount',
                draft.discount > 0 ? '−${money(draft.discount)}' : 'Add',
                link: draft.discount == 0,
                onTap: () => _pickDiscount(context, draft),
                onRemove: draft.discount > 0 ? () => setState(() => _discount = 0) : null,
                removeKey: const Key('remove-discount'),
              ),
              _TotalLine(
                draft.taxRate > 0 ? 'Tax (${_pct(draft.taxRate)})' : 'Tax',
                draft.taxRate > 0 ? money(draft.tax) : 'Add',
                link: draft.taxRate == 0,
                onTap: () => _pickTax(context, store),
                onRemove: draft.taxRate > 0 ? () => setState(() => _taxRate = 0) : null,
                removeKey: const Key('remove-tax'),
              ),
              Divider(height: 18, color: dl.border),
              Row(
                children: [
                  Expanded(child: Text('Total', style: Fonts.sans(size: 16, weight: FontWeight.w700, color: dl.ink))),
                  AnimatedSwitcher(
                    duration: Motion.standard,
                    switchInCurve: Motion.spring,
                    transitionBuilder: (c, a) => ScaleTransition(scale: a, child: FadeTransition(opacity: a, child: c)),
                    child: Text(
                      money(draft.total),
                      key: ValueKey(draft.total),
                      style: Fonts.amount(dl.ink, size: 20).copyWith(fontWeight: FontWeight.w800),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ]),
    );
  }

  static String _pct(double rate) {
    final p = rate * 100;
    return '${p == p.roundToDouble() ? p.round() : p.toStringAsFixed(1)}%';
  }

  Future<void> _pickTax(BuildContext context, AppStore store) async {
    final base = store.business.taxRate;
    final options = <double>{0, base, 0.05, 0.10, 0.15, 0.18, 0.20}.toList()..sort();
    final picked = await showModalBottomSheet<double>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _Sheet(
        title: 'Tax rate',
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final r in options)
                DaylitChip(
                  r == 0 ? 'None' : '${_pct(r)}${r == base ? ' · default' : ''}',
                  active: (r - _taxRate).abs() < 0.0001,
                  onTap: () => Navigator.of(ctx).pop(r),
                ),
            ],
          ),
          const SizedBox(height: 6),
          Text('Applied to the subtotal after any discount. Change the default under More → Tax & currency.',
              style: Fonts.caption(ctx.dl.muted)),
        ],
      ),
    );
    if (picked != null && mounted) setState(() => _taxRate = picked);
  }

  Future<void> _pickDiscount(BuildContext context, Invoice draft) async {
    final options = <double>[0, 50, 100, draft.subtotal * 0.10, draft.subtotal * 0.15];
    final labels = ['None', r'$50', r'$100', '10%', '15%'];
    final dl = context.dl;
    final picked = await showModalBottomSheet<double>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _Sheet(
        title: 'Discount',
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (var i = 0; i < options.length; i++)
                DaylitChip(labels[i], active: (options[i] - _discount).abs() < 0.01, onTap: () => Navigator.of(ctx).pop(options[i])),
            ],
          ),
          const SizedBox(height: 6),
          Text('Applied before tax.', style: Fonts.caption(dl.muted)),
        ],
      ),
    );
    if (picked != null && mounted) setState(() => _discount = picked);
  }

  Future<void> _pickClient(BuildContext context, AppStore store) async {
    final picked = await showModalBottomSheet<Client>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _Sheet(
        title: 'Bill to',
        children: [
          RowTile(
            leading: const IconTile(Icons.person_add_alt_1_outlined, size: 38, color: Palette.lemon),
            title: 'New client',
            subtitle: 'Add someone you haven\'t billed before',
            subtitleMono: false,
            verticalPadding: 8,
            onTap: () => Navigator.of(ctx).pop(const Client(
              id: '__new__', name: '', initials: '', email: '', phone: '', address: '', color: Palette.wine,
            )),
          ),
          Divider(height: 8, color: ctx.dl.border),
          for (final c in store.clients)
            RowTile(
              leading: AvatarTile(c.initials, size: 38, color: c.color),
              title: c.name,
              subtitle: c.email,
              subtitleMono: false,
              verticalPadding: 8,
              trailing: c.id == _client?.id ? const Icon(Icons.check_rounded, color: Palette.wine) : null,
              onTap: () => Navigator.of(ctx).pop(c),
            ),
        ],
      ),
    );
    if (!mounted || picked == null) return;
    if (picked.id == '__new__') {
      final created = await showClientSheet(this.context);
      if (created != null && mounted) setState(() => _client = created);
      return;
    }
    setState(() => _client = picked);
  }
}

/// Picker sheet: header stays put, the list scrolls, never taller than 85%.
class _Sheet extends StatelessWidget {
  const _Sheet({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final dl = context.dl;
    return ConstrainedBox(
      constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.85),
      child: Container(
        decoration: BoxDecoration(color: dl.surface, borderRadius: const BorderRadius.vertical(top: Radius.circular(28))),
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(width: 40, height: 5, decoration: BoxDecoration(color: Palette.sand, borderRadius: BorderRadius.circular(99))),
            ),
            const SizedBox(height: 14),
            Text(title, style: Fonts.screen(dl.ink)),
            const SizedBox(height: 8),
            Flexible(
              child: SingleChildScrollView(
                child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: children),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ItemRow extends StatelessWidget {
  const _ItemRow({required this.item, required this.onRemove});

  final LineItem item;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final dl = context.dl;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(item.name, style: Fonts.body(dl.ink)),
                const SizedBox(height: 3),
                Text('${item.qty.toStringAsFixed(0)} × ${money(item.rate)}',
                    style: Fonts.mono(size: 11, tracking: 0, color: dl.muted)),
              ],
            ),
          ),
          Text(money(item.amount, cents: false), style: Fonts.amount(dl.ink)),
          const SizedBox(width: 10),
          Pressable(
            onTap: onRemove,
            scale: 0.85,
            semanticLabel: 'Remove ${item.name}',
            child: const Icon(Icons.close_rounded, size: 18, color: Palette.sand),
          ),
        ],
      ),
    );
  }
}

/// Subtotal / Discount / Tax line. [onTap] opens a picker; [onRemove] shows a × that clears it.
class _TotalLine extends StatelessWidget {
  const _TotalLine(this.label, this.value, {this.link = false, this.onTap, this.onRemove, this.removeKey});

  final String label;
  final String value;
  final bool link;
  final VoidCallback? onTap;
  final VoidCallback? onRemove;
  final Key? removeKey;

  @override
  Widget build(BuildContext context) {
    final dl = context.dl;
    final row = Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          Expanded(child: Text(label, style: Fonts.sans(size: 14, color: dl.muted))),
          Text(
            value,
            style: link
                ? Fonts.sans(size: 13, weight: FontWeight.w700, color: dl.rust)
                : Fonts.mono(size: 14, weight: FontWeight.w500, tracking: -0.01, color: dl.ink),
          ),
          if (onRemove != null) ...[
            const SizedBox(width: 8),
            Pressable(
              key: removeKey,
              onTap: onRemove,
              scale: 0.85,
              semanticLabel: 'Remove $label',
              child: Container(
                width: 22,
                height: 22,
                decoration: BoxDecoration(color: dl.tile, shape: BoxShape.circle),
                child: Icon(Icons.close_rounded, size: 14, color: dl.rust),
              ),
            ),
          ],
        ],
      ),
    );
    return onTap == null ? row : Pressable(onTap: onTap, scale: 0.99, child: row);
  }
}
