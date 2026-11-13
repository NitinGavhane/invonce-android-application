import 'package:flutter/material.dart';

import '../data/app_store.dart';
import '../motion/motion.dart';
import '../shell.dart';
import '../theme/tokens.dart';
import '../theme/typography.dart';
import '../widgets/widgets.dart';
import '../legal/legal_texts.dart';
import 'business_profile.dart';
import 'legal.dart';
import 'sign_in.dart';

class _LegalLink extends StatelessWidget {
  const _LegalLink(this.label, this.doc);

  final String label;
  final LegalDoc doc;

  @override
  Widget build(BuildContext context) {
    return Pressable(
      onTap: () => pushPage(context, LegalDocScreen(doc: doc)),
      child: Text(
        label,
        style: Fonts.sans(size: 11.5, weight: FontWeight.w700, color: Palette.lemon).copyWith(decoration: TextDecoration.underline, decorationColor: Palette.lemon),
      ),
    );
  }
}

class OnboardingScreen extends StatelessWidget {
  const OnboardingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final store = AppScope.read(context);
    const features = [
      'Invoices, estimates & receipts',
      'Send by email, text, link or PDF',
      "Know the moment it's viewed & paid",
      '150+ templates, your logo, your brand',
    ];

    return Scaffold(
      backgroundColor: Palette.wine,
      body: SafeArea(
        child: FillOrScroll(
          padding: const EdgeInsets.fromLTRB(28, 44, 28, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ...stagger([
                Container(
                  width: 84,
                  height: 84,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: Palette.lemon,
                    borderRadius: BorderRadius.circular(22),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.25),
                        blurRadius: 40,
                        offset: const Offset(0, 18),
                      ),
                    ],
                  ),
                  child: const ReceiptMark(size: 52, paper: Palette.wine, ink: Palette.lemon),
                ),
                const SizedBox(height: 36),
                const Eyebrow('Invonce', color: Palette.lemon),
                const SizedBox(height: 10),
                Text(
                  'Invoices that get you paid.',
                  style: Fonts.sans(size: 44, weight: FontWeight.w700, tracking: -0.04, color: Palette.white, height: 1.02),
                ),
                const SizedBox(height: 16),
                Text(
                  'Make a professional invoice in under a minute, send it from your phone, and track every payment.',
                  style: Fonts.sans(size: 16, color: Palette.rose, height: 1.5),
                ),
                const SizedBox(height: 32),
                for (final f in features)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 14),
                    child: Row(
                      children: [
                        Container(
                          width: 26,
                          height: 26,
                          decoration: const BoxDecoration(color: Palette.lemon, shape: BoxShape.circle),
                          child: const Icon(Icons.check_rounded, size: 15, color: Palette.wine),
                        ),
                        const SizedBox(width: 12),
                        Expanded(child: Text(f, style: Fonts.sans(size: 15, color: Palette.white))),
                      ],
                    ),
                  ),
              ]),
              const Spacer(),
              FadeSlideIn(
                index: 9,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    DaylitButton(
                      "Get started — it's free",
                      variant: DaylitVariant.lemon,
                      height: 54,
                      fontSize: 16,
                      onTap: () => pushPage(
                        context,
                        store.demo ? const BusinessProfileScreen(onboarding: true) : const SignInScreen(signUp: true),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Pressable(
                      onTap: () {
                        if (store.demo) {
                          Navigator.of(context).pushReplacement(MaterialPageRoute<void>(builder: (_) => const AppShell()));
                        } else {
                          pushPage(context, const SignInScreen());
                        }
                      },
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Center(
                          child: Text(
                            store.demo ? 'Skip — explore the demo' : 'I already have an account',
                            style: Fonts.sans(size: 14, weight: FontWeight.w600, color: Palette.rose),
                          ),
                        ),
                      ),
                    ),
                    Center(
                      child: Wrap(
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Text('By continuing you agree to our ', style: Fonts.sans(size: 11.5, color: Palette.rose.withValues(alpha: 0.8))),
                          _LegalLink('Terms', termsOfService),
                          Text(' and ', style: Fonts.sans(size: 11.5, color: Palette.rose.withValues(alpha: 0.8))),
                          _LegalLink('Privacy Policy', privacyPolicy),
                        ],
                      ),
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
