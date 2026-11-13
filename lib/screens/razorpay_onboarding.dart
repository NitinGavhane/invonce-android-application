import 'package:flutter/material.dart';

import '../data/app_store.dart';
import '../data/models.dart';
import '../motion/motion.dart';
import '../theme/tokens.dart';
import '../theme/typography.dart';
import '../widgets/sheets.dart';
import '../widgets/widgets.dart';

/// Razorpay Route needs KYC + settlement details up front (there is no hosted
/// onboarding page like Stripe's). The form posts straight to the connect
/// function; nothing here is kept in Invonce's database. Resolves `true` once
/// the linked account has been created.
Future<bool?> showRazorpayOnboarding(BuildContext context) =>
    showSheet<bool>(context, (_) => const _RazorpaySheet());

class _RazorpaySheet extends StatefulWidget {
  const _RazorpaySheet();

  @override
  State<_RazorpaySheet> createState() => _RazorpaySheetState();
}

class _RazorpaySheetState extends State<_RazorpaySheet> {
  static const _types = ['Individual', 'Proprietorship', 'Partnership', 'Pvt Ltd', 'LLP'];
  static const _typeCodes = ['individual', 'proprietorship', 'partnership', 'private_limited', 'llp'];

  late final Business _b = AppScope.read(context).business;
  late final _legal = TextEditingController(text: _b.name);
  late final _display = TextEditingController(text: _b.name);
  late final _email = TextEditingController(text: _b.email);
  late final _phone = TextEditingController(text: _b.phone);
  final _pan = TextEditingController();
  final _street = TextEditingController();
  final _city = TextEditingController();
  final _state = TextEditingController();
  final _pin = TextEditingController();
  final _account = TextEditingController();
  final _ifsc = TextEditingController();
  late final _beneficiary = TextEditingController(text: _b.name);
  int _type = 0;
  bool _busy = false;

  @override
  void dispose() {
    for (final c in [_legal, _display, _email, _phone, _pan, _street, _city, _state, _pin, _account, _ifsc, _beneficiary]) {
      c.dispose();
    }
    super.dispose();
  }

  String? _validate() {
    if (_legal.text.trim().isEmpty) return 'Enter the legal business name';
    if (!_email.text.contains('@')) return 'Enter a valid email';
    if (_phone.text.replaceAll(RegExp(r'\D'), '').length < 10) return 'Enter a 10-digit mobile number';
    if (!RegExp(r'^[A-Z]{5}[0-9]{4}[A-Z]$').hasMatch(_pan.text.trim().toUpperCase())) return 'PAN looks wrong (e.g. ABCDE1234F)';
    if (_street.text.trim().isEmpty || _city.text.trim().isEmpty || _state.text.trim().isEmpty) return 'Enter the registered address';
    if (!RegExp(r'^\d{6}$').hasMatch(_pin.text.trim())) return 'PIN code must be 6 digits';
    if (_account.text.replaceAll(' ', '').length < 9) return 'Enter the bank account number';
    if (!RegExp(r'^[A-Z]{4}0[A-Z0-9]{6}$').hasMatch(_ifsc.text.trim().toUpperCase())) return 'IFSC looks wrong (e.g. HDFC0001234)';
    if (_beneficiary.text.trim().isEmpty) return 'Enter the account holder name';
    return null;
  }

  Future<void> _submit() async {
    final problem = _validate();
    if (problem != null) {
      toast(context, problem);
      return;
    }
    final digits = _phone.text.replaceAll(RegExp(r'\D'), '');
    final phone = _phone.text.trim().startsWith('+') ? '+$digits' : '+91${digits.substring(digits.length - 10)}';
    setState(() => _busy = true);
    try {
      await AppScope.read(context).connectPayments(
        razorpay: RazorpayOnboarding(
          legalName: _legal.text.trim(),
          displayName: _display.text.trim().isEmpty ? _legal.text.trim() : _display.text.trim(),
          email: _email.text.trim(),
          phone: phone,
          businessType: _typeCodes[_type],
          pan: _pan.text.trim().toUpperCase(),
          street: _street.text.trim(),
          city: _city.text.trim(),
          state: _state.text.trim(),
          postalCode: _pin.text.trim(),
          accountNumber: _account.text.replaceAll(' ', ''),
          ifsc: _ifsc.text.trim().toUpperCase(),
          beneficiaryName: _beneficiary.text.trim(),
        ),
      );
      if (!mounted) return;
      Haptics.success();
      Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) {
        toast(context, "Razorpay didn't accept the details: $e");
        setState(() => _busy = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final dl = context.dl;
    return SheetShell(
      title: 'Set up Razorpay',
      subtitle: 'UPI, cards & netbanking for Indian clients. These details go straight to Razorpay — Invonce never stores them.',
      saveLabel: 'Submit to Razorpay',
      busy: _busy,
      onSave: _submit,
      children: [
        const SectionLabel('Business'),
        SheetInput(label: 'Legal business name', controller: _legal, hint: 'As on PAN'),
        SheetInput(label: 'Display name', controller: _display, hint: 'Shown to clients at checkout'),
        Row(
          children: [
            Expanded(child: SheetInput(label: 'Email', controller: _email, keyboard: TextInputType.emailAddress)),
            const SizedBox(width: 10),
            Expanded(child: SheetInput(label: 'Mobile', controller: _phone, hint: '+91 98765 43210', keyboard: TextInputType.phone)),
          ],
        ),
        ChipBar(labels: _types, selected: _type, onSelect: (i) => setState(() => _type = i)),
        SheetInput(label: 'PAN', controller: _pan, hint: 'ABCDE1234F', mono: true),
        const SectionLabel('Registered address'),
        SheetInput(label: 'Street', controller: _street, hint: 'Flat / building / street'),
        Row(
          children: [
            Expanded(child: SheetInput(label: 'City', controller: _city)),
            const SizedBox(width: 10),
            Expanded(child: SheetInput(label: 'State', controller: _state)),
            const SizedBox(width: 10),
            SizedBox(width: 96, child: SheetInput(label: 'PIN', controller: _pin, keyboard: TextInputType.number, mono: true)),
          ],
        ),
        const SectionLabel('Settlement bank account'),
        SheetInput(label: 'Account number', controller: _account, keyboard: TextInputType.number, mono: true),
        Row(
          children: [
            Expanded(child: SheetInput(label: 'IFSC', controller: _ifsc, hint: 'HDFC0001234', mono: true)),
            const SizedBox(width: 10),
            Expanded(child: SheetInput(label: 'Account holder', controller: _beneficiary)),
          ],
        ),
        Text(
          'Razorpay verifies the documents in 1–2 business days. Payments land in this account, minus the fees shown on the previous screen.',
          style: Fonts.caption(dl.muted),
        ),
      ],
    );
  }
}
