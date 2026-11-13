import 'package:flutter/material.dart';

import '../data/app_store.dart';
import '../data/models.dart';
import '../data/repository.dart';
import '../motion/motion.dart';
import '../widgets/sheets.dart';
import '../widgets/widgets.dart';

/// New client (no [existing]) or edit. Returns the saved client.
Future<Client?> showClientSheet(BuildContext context, {Client? existing}) =>
    showSheet<Client>(context, (_) => _ClientSheet(existing: existing));

class _ClientSheet extends StatefulWidget {
  const _ClientSheet({this.existing});

  final Client? existing;

  @override
  State<_ClientSheet> createState() => _ClientSheetState();
}

class _ClientSheetState extends State<_ClientSheet> {
  late final _name = TextEditingController(text: widget.existing?.name ?? '');
  late final _email = TextEditingController(text: widget.existing?.email ?? '');
  late final _phone = TextEditingController(text: widget.existing?.phone ?? '');
  late final _address = TextEditingController(text: widget.existing?.address ?? '');
  bool _busy = false;

  @override
  void dispose() {
    for (final c in [_name, _email, _phone, _address]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    final name = _name.text.trim();
    if (name.isEmpty) {
      toast(context, 'Give the client a name');
      return;
    }
    setState(() => _busy = true);
    final store = AppScope.read(context);
    try {
      final existing = widget.existing;
      final Client saved;
      if (existing == null) {
        saved = await store.addClient(
          name: name,
          email: _email.text.trim(),
          phone: _phone.text.trim(),
          address: _address.text.trim(),
        );
      } else {
        saved = await store.updateClient(Client(
          id: existing.id,
          name: name,
          initials: initialsOf(name),
          email: _email.text.trim(),
          phone: _phone.text.trim(),
          address: _address.text.trim(),
          color: existing.color,
        ));
      }
      if (!mounted) return;
      Haptics.success();
      Navigator.of(context).pop(saved);
    } catch (e) {
      if (mounted) {
        toast(context, "Couldn't save client: $e");
        setState(() => _busy = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final editing = widget.existing != null;
    return SheetShell(
      title: editing ? 'Edit client' : 'New client',
      saveLabel: editing ? 'Save changes' : 'Save client',
      busy: _busy,
      onSave: _save,
      children: [
        SheetInput(label: 'Name', controller: _name, hint: 'Client or company name', autofocus: !editing),
        SheetInput(label: 'Email', controller: _email, hint: 'name@company.com', keyboard: TextInputType.emailAddress),
        SheetInput(label: 'Phone', controller: _phone, hint: '(000) 000-0000', keyboard: TextInputType.phone),
        SheetInput(label: 'Address', controller: _address, hint: 'Street, city, postcode', lines: 2),
        if (!editing)
          DaylitButton('Import from Contacts', variant: DaylitVariant.ghost, icon: Icons.contacts_outlined,
              onTap: () => toast(context, 'Contacts import needs device permissions — coming with the iOS/Android builds')),
      ],
    );
  }
}
