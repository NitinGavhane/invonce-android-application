import 'package:flutter/material.dart';

import '../data/app_store.dart';
import '../data/format.dart';
import '../data/models.dart';
import '../motion/motion.dart';
import '../theme/tokens.dart';
import '../theme/typography.dart';
import '../widgets/widgets.dart';
import 'home.dart';
import 'invoice_editor.dart';
import 'item_form.dart';

/// Saved products & services. In [picker] mode a tap returns the item.
class ItemsScreen extends StatefulWidget {
  const ItemsScreen({super.key, this.picker = false});

  final bool picker;

  @override
  State<ItemsScreen> createState() => _ItemsScreenState();
}

class _ItemsScreenState extends State<ItemsScreen> {
  static const _filters = ['All', 'Services', 'Products'];
  int _filter = 0;
  String _query = '';

  Future<void> _newItem() async {
    final item = await showItemSheet(context);
    if (item == null || !mounted) return;
    if (widget.picker) Navigator.of(context).pop(item);
  }

  @override
  Widget build(BuildContext context) {
    final dl = context.dl;
    final store = AppScope.watch(context);
    final q = _query.trim().toLowerCase();
    final visible = store.catalog.where((c) {
      final kindOk = switch (_filter) { 1 => c.isService, 2 => !c.isService, _ => true };
      return kindOk && (q.isEmpty || c.name.toLowerCase().contains(q));
    }).toList();

    return ScreenScaffold(
      bottomPadding: 40,
      header: TopBar(
        title: widget.picker ? 'Add item' : 'Items & services',
        trailing: [IconSquare(Icons.add_rounded, filled: true, label: 'New item', onTap: _newItem)],
      ),
      children: [
        ...stagger([
          SearchBox('Search items', onChanged: (v) => setState(() => _query = v)),
          const SizedBox(height: 12),
          ChipBar(labels: _filters, selected: _filter, onSelect: (i) => setState(() => _filter = i)),
          const SizedBox(height: 14),
        ]),
        AnimatedSwitcher(
          duration: Motion.standard,
          switchInCurve: Motion.emphasized,
          child: KeyedSubtree(
            key: ValueKey('$_filter-$q-${visible.length}'),
            child: visible.isEmpty
                ? EmptyState(
                    icon: Icons.inventory_2_outlined,
                    label: store.catalog.isEmpty ? 'No saved items yet — tap + to add one' : 'No items match',
                  )
                : ListCard(
                    children: [
                      for (final item in visible)
                        RowTile(
                          leading: IconTile(item.icon, size: 38),
                          title: item.name,
                          subtitle: '${item.kind} · ${item.unit}',
                          trailing: item.price == null
                              ? Text(item.priceLabel ?? '', style: Fonts.amount(dl.ink))
                              : RichText(
                                  text: TextSpan(
                                    text: money(item.price!, cents: false),
                                    style: Fonts.amount(dl.ink),
                                    children: [
                                      if (item.priceLabel != null)
                                        TextSpan(text: item.priceLabel, style: Fonts.mono(size: 11, tracking: 0, color: dl.muted)),
                                    ],
                                  ),
                                ),
                          onTap: () {
                            if (widget.picker) {
                              Navigator.of(context).pop(item);
                            } else {
                              pushPage(
                                context,
                                InvoiceEditorScreen(
                                  initialItems: [if (item.price != null) LineItem(name: item.name, rate: item.price!)],
                                ),
                              );
                            }
                          },
                        ),
                    ],
                  ),
          ),
        ),
      ],
    );
  }
}
