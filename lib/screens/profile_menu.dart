import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../data/app_store.dart';
import '../theme/tokens.dart';
import '../theme/typography.dart';
import '../widgets/sheets.dart';
import '../widgets/widgets.dart';
import 'business_profile.dart';
import 'payment_methods.dart';
import 'paywall.dart';
import 'signature.dart';
import 'tax_currency.dart';

/// Opens from the avatar in the Home header.
Future<void> showProfileMenu(BuildContext context) => showSheet<void>(context, (_) => const _ProfileMenu());

class _ProfileMenu extends StatelessWidget {
  const _ProfileMenu();

  @override
  Widget build(BuildContext context) {
    final dl = context.dl;
    final store = AppScope.watch(context);
    final b = store.business;
    final name = b.name.isEmpty ? 'Set up your business' : b.name;
    final email = !store.demo ? (Supabase.instance.client.auth.currentUser?.email ?? b.email) : b.email;

    void go(Widget page) {
      Navigator.of(context).pop();
      pushPage(context, page);
    }

    return Container(
      decoration: BoxDecoration(color: dl.surface, borderRadius: const BorderRadius.vertical(top: Radius.circular(28))),
      padding: EdgeInsets.fromLTRB(20, 12, 20, 16 + MediaQuery.paddingOf(context).bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Container(width: 40, height: 5, decoration: BoxDecoration(color: Palette.sand, borderRadius: BorderRadius.circular(99))),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              AvatarTile(b.initials.isEmpty ? '·' : b.initials, size: 52, radius: 16),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(name, style: Fonts.sans(size: 18, weight: FontWeight.w700, tracking: -0.02, color: dl.ink)),
                    if (email.isNotEmpty) Text(email, style: Fonts.caption(dl.muted)),
                  ],
                ),
              ),
              Pill(b.isPro ? 'Pro' : 'Free', bg: b.isPro ? Palette.lemon : dl.tile, fg: b.isPro ? Palette.wine : dl.muted),
            ],
          ),
          const SizedBox(height: 14),
          ListCard(
            children: [
              SettingRow('Business profile & logo', icon: Icons.badge_outlined, onTap: () => go(const BusinessProfileScreen())),
              SettingRow('Tax & currency', icon: Icons.percent_rounded, hint: '${b.currency} · ${(b.taxRate * 100).round()}%',
                  onTap: () => go(const TaxCurrencyScreen())),
              SettingRow('Payment methods', icon: Icons.credit_card_outlined, onTap: () => go(const PaymentMethodsScreen())),
              SettingRow('Signature & defaults', icon: Icons.draw_outlined, onTap: () => go(const SignatureScreen())),
            ],
          ),
          const SizedBox(height: 10),
          if (!b.isPro)
            Pressable(
              onTap: () => go(const PaywallScreen()),
              scale: 0.985,
              child: Container(
                padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                decoration: BoxDecoration(color: Palette.wine, borderRadius: BorderRadius.circular(16)),
                child: Row(
                  children: [
                    const IconTile(Icons.workspace_premium_outlined, size: 30, color: Palette.lemon, fg: Palette.wine),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text('Upgrade to Invonce Pro', style: Fonts.sans(size: 14, weight: FontWeight.w700, color: Palette.white)),
                    ),
                    const Pill('Upgrade', bg: Palette.lemon, fg: Palette.wine),
                  ],
                ),
              ),
            ),
          const SizedBox(height: 10),
          if (store.demo)
            Text('Demo mode · sample data', textAlign: TextAlign.center, style: Fonts.caption(dl.muted))
          else
            DaylitButton(
              'Sign out',
              variant: DaylitVariant.ghost,
              icon: Icons.logout_rounded,
              onTap: () async {
                Navigator.of(context).pop();
                await Supabase.instance.client.auth.signOut();
              },
            ),
        ],
      ),
    );
  }
}
