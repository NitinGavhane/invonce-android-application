import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../data/app_store.dart';
import '../data/format.dart';
import '../legal/legal_texts.dart';
import '../motion/motion.dart';
import '../theme/tokens.dart';
import '../theme/typography.dart';
import '../widgets/widgets.dart';
import 'business_profile.dart';
import 'expenses.dart';
import 'items.dart';
import 'legal.dart';
import 'payment_methods.dart';
import 'paywall.dart';
import 'reports.dart';
import 'signature.dart';
import 'tax_currency.dart';
import 'templates.dart';

class MoreScreen extends StatelessWidget {
  const MoreScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final dl = context.dl;
    final store = AppScope.watch(context);
    final b = store.business;
    final name = b.name.isEmpty ? 'Set up your business' : b.name;

    return ScreenScaffold(
      bottomPadding: 110,
      header: const PageHeader(title: 'More'),
      children: stagger([
        Pressable(
          onTap: () => pushPage(context, const BusinessProfileScreen()),
          scale: 0.985,
          child: DaylitCard(
            padding: const EdgeInsets.fromLTRB(12, 11, 12, 11),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(color: Palette.wine, borderRadius: BorderRadius.circular(13)),
                  child: Text(b.initials.isEmpty ? '·' : b.initials[0], style: Fonts.sans(size: 17, weight: FontWeight.w800, tracking: 0, color: Palette.lemon)),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(name, style: Fonts.body(dl.ink)),
                      Text(b.email.isEmpty ? 'Edit profile' : '${b.email} · Edit profile', style: Fonts.caption(dl.muted)),
                    ],
                  ),
                ),
                const Chevron(),
              ],
            ),
          ),
        ),
        const SizedBox(height: 10),
        if (!b.isPro)
          Pressable(
            onTap: () => pushPage(context, const PaywallScreen()),
            scale: 0.985,
            child: Container(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
              decoration: BoxDecoration(color: Palette.wine, borderRadius: BorderRadius.circular(16)),
              child: Row(
                children: [
                  const IconTile(Icons.workspace_premium_outlined, size: 30, color: Palette.lemon, fg: Palette.wine),
                  const SizedBox(width: 12),
                  Expanded(
                    child: RichText(
                      text: TextSpan(
                        text: 'Invonce Pro ',
                        style: Fonts.sans(size: 14, weight: FontWeight.w700, color: Palette.white),
                        children: [
                          TextSpan(text: '· unlimited invoices', style: Fonts.sans(size: 14, color: Palette.rose)),
                        ],
                      ),
                    ),
                  ),
                  const Pill('Upgrade', bg: Palette.lemon, fg: Palette.wine),
                ],
              ),
            ),
          ),
        const SectionLabel('Business'),
        ListCard(
          children: [
            SettingRow('Business profile & logo', icon: Icons.badge_outlined,
                onTap: () => pushPage(context, const BusinessProfileScreen())),
            SettingRow('Items & services', icon: Icons.inventory_2_outlined, hint: '${store.catalog.length}',
                onTap: () => pushPage(context, const ItemsScreen())),
            SettingRow('Payment methods', icon: Icons.credit_card_outlined, hint: 'Card · Bank',
                onTap: () => pushPage(context, const PaymentMethodsScreen())),
          ],
        ),
        const SectionLabel('Invoicing'),
        ListCard(
          children: [
            SettingRow('Templates', icon: Icons.article_outlined, hint: '150+',
                onTap: () => pushPage(context, const TemplatesScreen())),
            SettingRow('Tax & currency', icon: Icons.percent_rounded,
                hint: '${b.currency} · ${(b.taxRate * 100).round()}%',
                onTap: () => pushPage(context, const TaxCurrencyScreen())),
            SettingRow('Signature & defaults', icon: Icons.draw_outlined,
                onTap: () => pushPage(context, const SignatureScreen())),
          ],
        ),
        const SectionLabel('More'),
        ListCard(
          children: [
            SettingRow('Reports & exports', icon: Icons.bar_chart_rounded,
                onTap: () => pushPage(context, const ReportsScreen())),
            SettingRow('Expenses', icon: Icons.receipt_long_outlined, hint: money(store.totalExpenses, cents: false),
                onTap: () => pushPage(context, const ExpensesScreen())),
            SettingRow('Help & support', icon: Icons.help_outline_rounded,
                onTap: () => pushPage(context, LegalDocScreen(doc: contactSupport))),
            SettingRow('Legal & privacy', icon: Icons.shield_outlined,
                onTap: () => pushPage(context, const LegalIndexScreen())),
            if (!store.demo)
              SettingRow('Sign out', icon: Icons.logout_rounded, trailing: const SizedBox.shrink(),
                  onTap: () => Supabase.instance.client.auth.signOut()),
          ],
        ),
        if (store.demo)
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 14, 4, 0),
            child: Text(
              'Demo mode · sample data. Add SUPABASE_URL and SUPABASE_KEY to connect your account.',
              style: Fonts.caption(dl.muted),
            ),
          ),
      ]),
    );
  }
}
