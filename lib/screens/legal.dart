import 'package:flutter/material.dart';

import '../data/app_store.dart';
import '../legal/legal_texts.dart';
import '../motion/motion.dart';
import '../theme/tokens.dart';
import '../theme/typography.dart';
import '../widgets/widgets.dart';

/// More → Legal & privacy: every policy, plus data export and account deletion.
class LegalIndexScreen extends StatelessWidget {
  const LegalIndexScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final dl = context.dl;
    final store = AppScope.watch(context);
    const icons = {
      'privacy': Icons.shield_outlined,
      'terms': Icons.gavel_rounded,
      'subscription': Icons.autorenew_rounded,
      'deletion': Icons.delete_outline_rounded,
      'acceptable-use': Icons.rule_rounded,
      'cookies': Icons.cookie_outlined,
      'contact': Icons.support_agent_rounded,
    };

    return ScreenScaffold(
      bottomPadding: 40,
      header: const TopBar(title: 'Legal & privacy'),
      children: stagger([
        const SectionLabel('Policies'),
        ListCard(
          children: [
            for (final doc in legalDocs)
              SettingRow(doc.title, icon: icons[doc.id] ?? Icons.description_outlined,
                  onTap: () => pushPage(context, LegalDocScreen(doc: doc))),
          ],
        ),
        const SectionLabel('Your data'),
        ListCard(
          children: [
            SettingRow('Export my data', icon: Icons.download_rounded,
                onTap: () => toast(context, 'Email $legalEmail with the subject "Privacy request" — a one-tap export is coming next')),
            SettingRow('Delete account', icon: Icons.person_remove_outlined, onTap: () => _confirmDelete(context, store)),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          'Effective $legalEffective · $legalCompany',
          textAlign: TextAlign.center,
          style: Fonts.caption(dl.muted),
        ),
      ]),
    );
  }

  Future<void> _confirmDelete(BuildContext context, AppStore store) async {
    final dl = context.dl;
    final confirmed = await showModalBottomSheet<bool>(
      context: context,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        decoration: BoxDecoration(color: dl.surface, borderRadius: const BorderRadius.vertical(top: Radius.circular(28))),
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(width: 40, height: 5, decoration: BoxDecoration(color: Palette.sand, borderRadius: BorderRadius.circular(99))),
            ),
            const SizedBox(height: 16),
            Text('Delete your account?', style: Fonts.screen(dl.ink)),
            const SizedBox(height: 8),
            Text(
              'This permanently removes your business, clients, invoices, payments, expenses and files. It cannot be undone. '
              'Your Apple / Google subscription, if any, must be cancelled separately.',
              style: Fonts.bodyRegular(dl.muted),
            ),
            const SizedBox(height: 18),
            DaylitButton('Delete everything', icon: Icons.delete_forever_rounded, onTap: () => Navigator.of(ctx).pop(true)),
            const SizedBox(height: 8),
            DaylitButton('Keep my account', variant: DaylitVariant.ghost, onTap: () => Navigator.of(ctx).pop(false)),
          ],
        ),
      ),
    );
    if (confirmed != true || !context.mounted) return;
    try {
      await store.deleteAccount();
      if (!context.mounted) return;
      Haptics.heavy();
      Navigator.of(context).popUntil((r) => r.isFirst);
      toast(context, store.demo ? 'Demo mode — nothing to delete' : 'Your account and data have been deleted');
    } catch (e) {
      if (context.mounted) toast(context, "Couldn't delete the account: $e");
    }
  }
}

class LegalDocScreen extends StatelessWidget {
  const LegalDocScreen({super.key, required this.doc});

  final LegalDoc doc;

  @override
  Widget build(BuildContext context) {
    final dl = context.dl;
    return ScreenScaffold(
      bottomPadding: 48,
      header: TopBar(title: doc.title),
      children: [
        FadeSlideIn(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(doc.summary, style: Fonts.bodyRegular(dl.muted)),
              const SizedBox(height: 6),
              Eyebrow('Effective $legalEffective', size: 10),
              const SizedBox(height: 18),
              for (final s in doc.sections) ...[
                Text(s.heading, style: Fonts.section(dl.ink)),
                const SizedBox(height: 6),
                for (final p in s.paragraphs)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: p.startsWith('- ')
                        ? Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Padding(
                                padding: const EdgeInsets.only(top: 7, right: 10),
                                child: Container(width: 6, height: 6, decoration: const BoxDecoration(color: Palette.wine, shape: BoxShape.circle)),
                              ),
                              Expanded(child: Text(p.substring(2), style: Fonts.bodyRegular(dl.ink))),
                            ],
                          )
                        : Text(p, style: Fonts.bodyRegular(dl.ink)),
                  ),
                const SizedBox(height: 10),
              ],
            ],
          ),
        ),
      ],
    );
  }
}
