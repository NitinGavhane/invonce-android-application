import 'package:flutter/material.dart';

import '../data/app_store.dart';
import '../data/models.dart';
import '../data/pricing.dart';
import '../data/repository.dart';
import '../motion/motion.dart';
import '../shell.dart';
import '../theme/tokens.dart';
import '../theme/typography.dart';
import '../widgets/sheets.dart';
import '../widgets/widgets.dart';

class BusinessProfileScreen extends StatefulWidget {
  const BusinessProfileScreen({super.key, this.onboarding = false});

  final bool onboarding;

  @override
  State<BusinessProfileScreen> createState() => _BusinessProfileScreenState();
}

class _BusinessProfileScreenState extends State<BusinessProfileScreen> {
  late final Business _initial = AppScope.read(context).business;
  late final _name = TextEditingController(text: _initial.name);
  late final _email = TextEditingController(text: _initial.email);
  late final _phone = TextEditingController(text: _initial.phone);
  late final _address = TextEditingController(text: _initial.address);
  late final _website = TextEditingController(text: _initial.website);
  late final _taxId = TextEditingController(text: _initial.taxId);
  late String _country = _initial.country;
  bool _saving = false;

  Future<void> _pickCountry() async {
    final picked = await showSheet<String>(context, (_) => _CountrySheet(selected: _country));
    if (picked != null && mounted) setState(() => _country = picked);
  }

  @override
  void dispose() {
    for (final c in [_name, _email, _phone, _address, _website, _taxId]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    final store = AppScope.read(context);
    final name = _name.text.trim();
    if (name.isEmpty) {
      toast(context, 'Enter your business name');
      return;
    }
    setState(() => _saving = true);
    try {
      await store.updateBusiness(_initial.copyWith(
        name: name,
        initials: initialsOf(name),
        email: _email.text.trim(),
        phone: _phone.text.trim(),
        address: _address.text.trim(),
        website: _website.text.trim(),
        taxId: _taxId.text.trim(),
        country: _country,
        // A new country brings its currency along; Tax & currency can still override it.
        currency: _country == _initial.country ? _initial.currency : currencyForCountry(_country),
      ));
      if (!mounted) return;
      Haptics.success();
      if (widget.onboarding) {
        if (store.demo) {
          Navigator.of(context).pushAndRemoveUntil(MaterialPageRoute<void>(builder: (_) => const AppShell()), (_) => false);
        } else {
          Navigator.of(context).popUntil((r) => r.isFirst);
        }
      } else {
        Navigator.of(context).pop();
        toast(context, 'Profile saved');
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
    final b = AppScope.watch(context).business;

    Widget input(String label, TextEditingController c, String hint, {bool mono = false, int lines = 1, bool autofocus = false}) =>
        FieldTile(
          label: label,
          child: TextField(
            controller: c,
            maxLines: lines,
            autofocus: autofocus,
            style: mono ? Fonts.mono(size: 14, weight: FontWeight.w600, tracking: 0, color: dl.ink) : Fonts.body(dl.ink),
            cursorColor: Palette.wine,
            decoration: InputDecoration.collapsed(hintText: hint, hintStyle: Fonts.sans(size: 15, color: dl.muted)),
          ),
        );

    return ScreenScaffold(
      header: TopBar(title: widget.onboarding ? 'Set up your business' : 'Business profile'),
      bottom: [
        Expanded(
          child: DaylitButton(
            _saving ? 'Saving…' : (widget.onboarding ? "Save & let's go" : 'Save profile'),
            onTap: _saving ? null : _save,
          ),
        ),
      ],
      children: stagger([
        DaylitCard(
          child: Row(
            children: [
              Container(
                width: 66,
                height: 66,
                alignment: Alignment.center,
                decoration: BoxDecoration(color: Palette.wine, borderRadius: BorderRadius.circular(18)),
                child: Text(b.initials.isEmpty ? '·' : b.initials[0],
                    style: Fonts.sans(size: 26, weight: FontWeight.w800, tracking: 0, color: Palette.lemon)),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Your logo', style: Fonts.body(dl.ink)),
                    const SizedBox(height: 2),
                    Text('Shows on every invoice, estimate & receipt', style: Fonts.caption(dl.muted)),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        DaylitChip('Upload', onTap: () => toast(context, 'Image picker is coming next')),
                        const SizedBox(width: 8),
                        DaylitChip('Remove', onTap: () => toast(context, 'Logo removed')),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SectionLabel('Business details'),
        input('Business name', _name, 'Northwind Studio', autofocus: widget.onboarding && b.name.isEmpty),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(child: input('Email', _email, 'hello@company.com')),
            const SizedBox(width: 10),
            Expanded(child: input('Phone', _phone, '(000) 000-0000')),
          ],
        ),
        const SizedBox(height: 10),
        input('Address', _address, 'Street, city, postcode', lines: 2),
        const SizedBox(height: 10),
        Pressable(
          onTap: _pickCountry,
          scale: 0.99,
          child: FieldTile(
            label: 'Country',
            child: Row(
              children: [
                Expanded(child: Text(countryName(_country), style: Fonts.sans(size: 15, weight: FontWeight.w600, color: dl.ink))),
                Text(_country, style: Fonts.mono(size: 11, tracking: 0.04, color: dl.muted)),
                const SizedBox(width: 6),
                const Chevron(),
              ],
            ),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Sets your currency and how you get paid online — ${providerLabel(providerFor(_country))} for ${countryName(_country)}.',
          style: Fonts.caption(dl.muted),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(child: input('Website', _website, 'company.com')),
            const SizedBox(width: 10),
            Expanded(child: input('Tax ID / VAT', _taxId, '[TAX ID]', mono: true)),
          ],
        ),
        const SectionLabel('Invoice defaults'),
        Row(
          children: [
            Expanded(child: FieldTile(label: 'Currency', value: _country == _initial.country ? b.currency : currencyForCountry(_country))),
            const SizedBox(width: 10),
            Expanded(child: FieldTile(label: 'Default tax', value: '${(b.taxRate * 100).round()}%')),
            const SizedBox(width: 10),
            Expanded(child: FieldTile(label: 'Due in', value: '${b.dueInDays} days')),
          ],
        ),
        const SizedBox(height: 6),
        Text('Change these under More → Tax & currency.', style: Fonts.caption(dl.muted)),
      ]),
    );
  }
}

class _CountrySheet extends StatelessWidget {
  const _CountrySheet({required this.selected});

  final String selected;

  @override
  Widget build(BuildContext context) {
    final dl = context.dl;
    return Container(
      decoration: BoxDecoration(color: dl.surface, borderRadius: const BorderRadius.vertical(top: Radius.circular(28))),
      padding: EdgeInsets.fromLTRB(20, 12, 20, 12 + MediaQuery.paddingOf(context).bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Container(width: 40, height: 5, decoration: BoxDecoration(color: Palette.sand, borderRadius: BorderRadius.circular(99))),
          ),
          const SizedBox(height: 14),
          Text('Country', style: Fonts.screen(dl.ink)),
          const SizedBox(height: 3),
          Text('Where your business is registered', style: Fonts.caption(dl.muted)),
          const SizedBox(height: 8),
          Flexible(
            child: ListView(
              shrinkWrap: true,
              children: [
                for (final (code, name, currency) in countries)
                  Pressable(
                    onTap: () => Navigator.of(context).pop(code),
                    scale: 0.985,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 11),
                      child: Row(
                        children: [
                          Expanded(child: Text(name, style: Fonts.sans(size: 15, weight: FontWeight.w600, color: dl.ink))),
                          Text('$currency · ${providerLabel(providerFor(code))}',
                              style: Fonts.mono(size: 10.5, tracking: 0.02, color: dl.muted)),
                          const SizedBox(width: 10),
                          Icon(
                            code == selected ? Icons.check_circle_rounded : Icons.circle_outlined,
                            size: 20,
                            color: code == selected ? Palette.wine : Palette.sand,
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
