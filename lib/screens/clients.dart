import 'package:flutter/material.dart';

import '../data/app_store.dart';
import '../data/format.dart';
import '../data/models.dart';
import '../motion/motion.dart';
import '../theme/tokens.dart';
import '../theme/typography.dart';
import '../widgets/widgets.dart';
import 'client_detail.dart';
import 'client_form.dart';
import 'home.dart';

class ClientsScreen extends StatefulWidget {
  const ClientsScreen({super.key});

  @override
  State<ClientsScreen> createState() => _ClientsScreenState();
}

class _ClientsScreenState extends State<ClientsScreen> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final store = AppScope.watch(context);
    final q = _query.trim().toLowerCase();
    final visible = q.isEmpty
        ? store.clients
        : store.clients.where((c) => c.name.toLowerCase().contains(q) || c.email.toLowerCase().contains(q)).toList();

    final groups = <String, List<Client>>{};
    for (final c in visible) {
      final ch = c.name.isEmpty ? 'Z' : c.name[0].toUpperCase();
      final key = ch.compareTo('I') < 0 ? 'A — H' : (ch.compareTo('Q') < 0 ? 'I — P' : 'Q — Z');
      groups.putIfAbsent(key, () => []).add(c);
    }

    return ScreenScaffold(
      bottomPadding: 110,
      header: PageHeader(
        eyebrow: plural(store.clients.length, 'client'),
        title: 'Clients',
        trailing: IconSquare(
          Icons.add_rounded,
          filled: true,
          size: 44,
          label: 'Add client',
          onTap: () => showClientSheet(context),
        ),
      ),
      children: [
        ...stagger([
          SearchBox('Search clients', onChanged: (v) => setState(() => _query = v)),
          const SizedBox(height: 4),
        ]),
        if (store.clients.isEmpty)
          const Padding(
            padding: EdgeInsets.only(top: 8),
            child: EmptyState(icon: Icons.people_outline_rounded, label: 'No clients yet — tap + to add your first'),
          )
        else if (visible.isEmpty)
          const Padding(
            padding: EdgeInsets.only(top: 8),
            child: EmptyState(icon: Icons.search_off_rounded, label: 'No clients match'),
          ),
        for (final entry in groups.entries) ...[
          SectionLabel(entry.key),
          ListCard(children: [for (final c in entry.value) ClientRow(c)]),
          const SizedBox(height: 4),
        ],
      ],
    );
  }
}

class ClientRow extends StatelessWidget {
  const ClientRow(this.client, {super.key});

  final Client client;

  @override
  Widget build(BuildContext context) {
    final dl = context.dl;
    final store = AppScope.read(context);
    final count = store.invoicesFor(client).length;
    final due = store.outstandingFor(client);
    return RowTile(
      verticalPadding: 12,
      leading: Hero(tag: 'client-${client.id}', child: AvatarTile(client.initials, color: client.color)),
      title: client.name,
      subtitleWidget: RichText(
        text: TextSpan(
          style: Fonts.caption(dl.muted),
          children: [
            TextSpan(text: '${plural(count, 'invoice')} · '),
            TextSpan(
              text: '${money(due, cents: false)} due',
              style: due > 0 ? Fonts.sans(size: 12.5, weight: FontWeight.w600, color: dl.rust) : null,
            ),
          ],
        ),
      ),
      trailing: Chevron(color: dl.muted),
      onTap: () => pushPage(context, ClientDetailScreen(client: client)),
    );
  }
}
