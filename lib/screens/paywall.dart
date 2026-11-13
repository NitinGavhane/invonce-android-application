import 'package:flutter/material.dart';

import '../data/app_store.dart';
import '../data/pricing.dart';
import '../legal/legal_texts.dart';
import '../motion/motion.dart';
import '../theme/tokens.dart';
import '../theme/typography.dart';
import '../widgets/widgets.dart';
import 'legal.dart';

class PaywallScreen extends StatefulWidget {
  const PaywallScreen({super.key});

  @override
  State<PaywallScreen> createState() => _PaywallScreenState();
}

class _PaywallScreenState extends State<PaywallScreen> {
  int _plan = 1;

  @override
  Widget build(BuildContext context) {
    final store = AppScope.watch(context);
    final price = store.proPrice;
    const features = [
      'Unlimited invoices, estimates & clients',
      '0% Invonce fee on online payments',
      'Remove the Invonce watermark',
      'Read receipts & automatic payment reminders',
      'Recurring invoices',
      'All 150+ templates & priority support',
    ];

    return Scaffold(
      backgroundColor: Palette.midnight,
      body: SafeArea(
        child: FillOrScroll(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Align(
                alignment: Alignment.centerRight,
                child: Pressable(
                  onTap: () => Navigator.of(context).pop(),
                  scale: 0.9,
                  semanticLabel: 'Close',
                  child: Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.1), shape: BoxShape.circle),
                    child: const Icon(Icons.close_rounded, size: 18, color: Palette.white),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              ...stagger([
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                  decoration: BoxDecoration(color: Palette.lemon, borderRadius: BorderRadius.circular(Radii.pill)),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.workspace_premium_outlined, size: 14, color: Palette.wine),
                      const SizedBox(width: 6),
                      Text('INVONCE PRO', style: Fonts.mono(size: 11, weight: FontWeight.w600, tracking: 0.08, color: Palette.wine)),
                    ],
                  ),
                ),
                const SizedBox(height: 18),
                Text(
                  'Unlimited invoices.\nZero limits.',
                  style: Fonts.sans(size: 40, weight: FontWeight.w700, tracking: -0.04, color: Palette.white, height: 1.03),
                ),
                const SizedBox(height: 12),
                Text('Everything in free, plus the tools that get you paid faster.',
                    style: Fonts.sans(size: 15, color: const Color(0xFFD9B9C0), height: 1.5)),
                const SizedBox(height: 26),
                for (final f in features)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Row(
                      children: [
                        Container(
                          width: 22,
                          height: 22,
                          decoration: const BoxDecoration(color: Palette.lemon, shape: BoxShape.circle),
                          child: const Icon(Icons.check_rounded, size: 13, color: Palette.wine),
                        ),
                        const SizedBox(width: 12),
                        Expanded(child: Text(f, style: Fonts.sans(size: 14.5, color: const Color(0xFFF3E3E7)))),
                      ],
                    ),
                  ),
              ]),
              const Spacer(),
              Row(
                children: [
                  _Plan('Monthly', price.monthlyLabel, '/mo', selected: _plan == 0, onTap: () => setState(() => _plan = 0)),
                  const SizedBox(width: 12),
                  _Plan('Yearly', price.yearlyLabel, '/yr',
                      selected: _plan == 1, badge: 'Save ${price.yearlySavingPct}%', onTap: () => setState(() => _plan = 1)),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                'Prices in ${price.currency} for ${countryName(store.business.country)} · billed through the App Store / Google Play',
                style: Fonts.sans(size: 12, color: const Color(0xFFB48D97)),
              ),
              const SizedBox(height: 12),
              DaylitButton(
                'Start 7-day free trial',
                variant: DaylitVariant.lemon,
                height: 54,
                fontSize: 16,
                onTap: () {
                  Haptics.success();
                  Navigator.of(context).pop();
                  toast(context, 'Trial started — welcome to Pro');
                },
              ),
              const SizedBox(height: 12),
              Center(
                child: Wrap(
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text('CANCEL ANYTIME · ', style: Fonts.mono(size: 10.5, tracking: 0.02, color: const Color(0xFFB48D97))),
                    Pressable(
                      onTap: () => toast(context, 'Restore runs through the App Store / Play once in-app purchase is live'),
                      child: Text('RESTORE', style: Fonts.mono(size: 10.5, tracking: 0.02, color: Palette.lemon)),
                    ),
                    Text(' · ', style: Fonts.mono(size: 10.5, tracking: 0.02, color: const Color(0xFFB48D97))),
                    Pressable(
                      onTap: () => pushPage(context, const LegalDocScreen(doc: subscriptionPolicy)),
                      child: Text('TERMS', style: Fonts.mono(size: 10.5, tracking: 0.02, color: Palette.lemon)),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Plan extends StatelessWidget {
  const _Plan(this.label, this.price, this.per, {required this.selected, required this.onTap, this.badge});

  final String label;
  final String price;
  final String per;
  final bool selected;
  final VoidCallback onTap;
  final String? badge;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Pressable(
        onTap: onTap,
        scale: 0.97,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            AnimatedContainer(
              duration: Motion.standard,
              curve: Motion.emphasized,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: selected ? Palette.lemon.withValues(alpha: 0.08) : Colors.white.withValues(alpha: 0.04),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: selected ? Palette.lemon : Colors.white.withValues(alpha: 0.14), width: 1.5),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label.toUpperCase(),
                      style: Fonts.mono(size: 10, tracking: 0.08, color: selected ? Palette.lemon : const Color(0xFFD9B9C0))),
                  const SizedBox(height: 6),
                  RichText(
                    text: TextSpan(
                      text: price,
                      style: Fonts.sans(size: 24, weight: FontWeight.w800, tracking: -0.03, color: Palette.white),
                      children: [TextSpan(text: per, style: Fonts.sans(size: 13, color: const Color(0xFFD9B9C0)))],
                    ),
                  ),
                ],
              ),
            ),
            if (badge != null)
              Positioned(
                top: -11,
                right: 12,
                child: Pill(badge!, bg: Palette.lemon, fg: Palette.wine),
              ),
          ],
        ),
      ),
    );
  }
}
