import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../data/app_store.dart';
import '../data/format.dart';
import '../data/models.dart';
import '../data/pricing.dart';
import '../motion/motion.dart';
import '../theme/tokens.dart';
import '../theme/typography.dart';
import '../widgets/widgets.dart';
import 'paywall.dart';
import 'razorpay_onboarding.dart';

/// Payout account (Stripe Connect outside India, Razorpay Route in India),
/// fee explainer, and which manual methods the PDF mentions.
class PaymentMethodsScreen extends StatefulWidget {
  const PaymentMethodsScreen({super.key});

  @override
  State<PaymentMethodsScreen> createState() => _PaymentMethodsScreenState();
}

class _PaymentMethodsScreenState extends State<PaymentMethodsScreen> {
  final _on = <String, bool>{'bank': true, 'check': true, 'cash': true, 'other': false};
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadEarnings());
  }

  Future<void> _loadEarnings() async {
    if (!mounted) return;
    final store = AppScope.read(context);
    if (!store.business.paymentsEnabled) return;
    try {
      await store.refreshOnline();
    } catch (_) {
      // Earnings are decorative here; Reports shows the error state.
    }
  }

  Future<void> _connect() async {
    final store = AppScope.read(context);
    if (store.business.usesRazorpay) {
      final submitted = await showRazorpayOnboarding(context);
      if (submitted == true && mounted) {
        toast(context, 'Sent to Razorpay — KYC review takes 1–2 business days');
      }
      return;
    }
    setState(() => _busy = true);
    PaymentsStatus? s;
    try {
      s = await store.connectPayments();
    } catch (e) {
      if (mounted) toast(context, "Couldn't start Stripe setup: $e");
    } finally {
      if (mounted) setState(() => _busy = false);
    }
    // The browser hand-off happens outside the busy state: the user finishes
    // Stripe's form there and comes back to tap "Check status".
    if (s?.onboardingUrl != null) await _open(s!.onboardingUrl!);
  }

  Future<void> _open(String url) async {
    var ok = false;
    try {
      ok = await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    } catch (_) {
      ok = false;
    }
    if (!ok && mounted) toast(context, 'Finish setup in your browser: $url');
  }

  Future<void> _check() async {
    final store = AppScope.read(context);
    setState(() => _busy = true);
    try {
      final s = await store.refreshPaymentsStatus();
      if (!mounted) return;
      if (s.enabled) {
        Haptics.success();
        toast(context, 'Payments are live — clients can pay your invoices online');
        await _loadEarnings();
      } else {
        toast(context, switch (s.status) {
          'onboarding' => 'Stripe still needs a few details — tap Continue setup',
          'under_review' => 'Razorpay is still reviewing your documents',
          'needs_clarification' => 'Razorpay needs more information — check your email',
          'not_connected' => 'No payout account yet',
          _ => 'Status: ${s.status}',
        });
      }
    } catch (e) {
      if (mounted) toast(context, "Couldn't check status: $e");
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final dl = context.dl;
    final store = AppScope.watch(context);
    final b = store.business;
    final provider = providerLabel(b.provider);
    final (String pillText, Color pillBg, Color pillFg) = b.paymentsEnabled
        ? ('Active', Palette.paidBg, Palette.paidText)
        : b.hasPaymentAccount
            ? ('Pending', Palette.lemon, Palette.wine)
            : ('Not connected', Palette.rose, Palette.wine);

    Widget row(String key, IconData icon, String title, [String? sub]) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 11),
          child: Row(
            children: [
              IconTile(icon, size: 36),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: Fonts.sans(size: 14.5, weight: FontWeight.w600, color: dl.ink)),
                    if (sub != null) Text(sub, style: Fonts.caption(dl.muted)),
                  ],
                ),
              ),
              DaylitToggle(value: _on[key]!, onChanged: (v) => setState(() => _on[key] = v)),
            ],
          ),
        );

    final online = store.online;

    return ScreenScaffold(
      header: const TopBar(title: 'Payment methods'),
      bottom: [
        Expanded(
          child: DaylitButton('Save', onTap: () {
            Navigator.of(context).pop();
            toast(context, 'Payment methods saved');
          }),
        ),
      ],
      children: stagger([
        // ── Payout account ──────────────────────────────────────────────────
        DaylitCard(
          color: Palette.wine,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const IconTile(Icons.bolt_rounded, size: 44, color: Palette.lemon, fg: Palette.wine),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Get paid online', style: Fonts.body(Palette.white)),
                        const SizedBox(height: 2),
                        Text('$provider · ${countryName(b.country)}', style: Fonts.caption(Palette.rose)),
                      ],
                    ),
                  ),
                  Pill(pillText, bg: pillBg, fg: pillFg),
                ],
              ),
              const SizedBox(height: 14),
              Text(
                b.paymentsEnabled
                    ? 'Every invoice now carries a pay link. ${providerRails(b.provider)} — money settles to your bank by $provider.'
                    : b.hasPaymentAccount
                        ? (b.usesRazorpay
                            ? 'Razorpay is verifying your KYC and bank details. You can keep sending invoices meanwhile.'
                            : 'Stripe still needs a few details before payouts can start.')
                        : 'Clients pay straight from the invoice with ${providerRails(b.provider).toLowerCase()}. '
                            '${b.isPro ? 'No Invonce fee on Pro.' : 'Invonce keeps ${feePct(b.platformFeeBps)} — 0% on Pro.'}',
                style: Fonts.sans(size: 13.5, color: const Color(0xFFF3E3E7), height: 1.45),
              ),
              if (b.paymentsEnabled && online != null) ...[
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Eyebrow('Collected online', size: 10, color: Palette.lemon),
                          const SizedBox(height: 2),
                          Text(money(online.collected, cents: false),
                              style: Fonts.sans(size: 22, weight: FontWeight.w800, tracking: -0.03, color: Palette.white)),
                        ],
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        const Eyebrow('Payments', size: 10, color: Palette.lemon),
                        const SizedBox(height: 2),
                        Text('${online.payments}', style: Fonts.mono(size: 16, weight: FontWeight.w600, tracking: 0, color: Palette.white)),
                      ],
                    ),
                  ],
                ),
              ],
              const SizedBox(height: 14),
              if (!b.hasPaymentAccount)
                DaylitButton(
                  _busy ? 'Starting…' : (b.usesRazorpay ? 'Set up Razorpay' : 'Connect Stripe'),
                  variant: DaylitVariant.lemon,
                  icon: Icons.arrow_forward_rounded,
                  onTap: _busy ? null : _connect,
                )
              else
                Row(
                  children: [
                    Expanded(
                      child: DaylitButton(
                        _busy ? 'Checking…' : (b.paymentsEnabled ? 'Refresh' : 'Check status'),
                        variant: DaylitVariant.lemon,
                        icon: Icons.refresh_rounded,
                        onTap: _busy ? null : _check,
                      ),
                    ),
                    if (!b.paymentsEnabled && !b.usesRazorpay) ...[
                      const SizedBox(width: 10),
                      Pressable(
                        onTap: _busy ? null : _connect,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
                          child: Text('Continue setup', style: Fonts.sans(size: 14, weight: FontWeight.w700, color: Palette.lemon)),
                        ),
                      ),
                    ],
                  ],
                ),
            ],
          ),
        ),

        // ── Fees ────────────────────────────────────────────────────────────
        const SectionLabel('Fees on online payments'),
        ListCard(
          children: [
            _FeeRow(
              'Invonce platform fee',
              b.isPro ? '0%' : feePct(b.platformFeeBps),
              b.isPro ? 'Included with Pro' : 'Free plan · drops to 0% on Pro',
            ),
            _FeeRow('$provider processing', processorFee(b.provider), 'Charged by $provider, deducted before payout'),
          ],
        ),
        if (!b.isPro) ...[
          const SizedBox(height: 10),
          Pressable(
            onTap: () => pushPage(context, const PaywallScreen()),
            scale: 0.985,
            child: Container(
              padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
              decoration: BoxDecoration(color: Palette.lemon, borderRadius: BorderRadius.circular(16)),
              child: Row(
                children: [
                  const Icon(Icons.workspace_premium_outlined, size: 18, color: Palette.wine),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text('Keep 100% of every online payment with Pro',
                        style: Fonts.sans(size: 13.5, weight: FontWeight.w700, color: Palette.wine)),
                  ),
                  const Chevron(color: Palette.wine),
                ],
              ),
            ),
          ),
        ],

        // ── Manual ──────────────────────────────────────────────────────────
        const SectionLabel('Also accept'),
        ListCard(
          children: [
            row('bank', Icons.account_balance_outlined, 'Bank transfer', 'Bank details are printed on the PDF'),
            row('check', Icons.receipt_outlined, 'Check'),
            row('cash', Icons.payments_outlined, 'Cash'),
            row('other', Icons.more_horiz_rounded, 'Other'),
          ],
        ),
        const SectionLabel('Shown on invoices'),
        FieldTile(
          label: 'Payment instructions',
          value: b.paymentsEnabled
              ? 'Pay online with the link on this invoice, or make checks payable to ${b.name}.'
              : 'Make checks payable to ${b.name}. Bank details are included on the PDF.',
          minHeight: 76,
        ),
      ]),
    );
  }
}

class _FeeRow extends StatelessWidget {
  const _FeeRow(this.label, this.value, this.sub);

  final String label;
  final String value;
  final String sub;

  @override
  Widget build(BuildContext context) {
    final dl = context.dl;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: Fonts.sans(size: 14.5, weight: FontWeight.w600, color: dl.ink)),
                Text(sub, style: Fonts.caption(dl.muted)),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Text(value, style: Fonts.mono(size: 13, weight: FontWeight.w600, tracking: 0, color: dl.ink)),
        ],
      ),
    );
  }
}
