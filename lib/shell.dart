import 'package:flutter/material.dart';

import 'motion/motion.dart';
import 'screens/clients.dart';
import 'screens/home.dart';
import 'screens/invoice_editor.dart';
import 'screens/invoices.dart';
import 'screens/more.dart';
import 'theme/tokens.dart';
import 'theme/typography.dart';
import 'widgets/widgets.dart';

/// Lets any tab screen switch tabs (e.g. Home → "See all" → Invoices).
class ShellScope extends InheritedWidget {
  const ShellScope({super.key, required this.goTo, required super.child});

  final void Function(int index) goTo;

  static ShellScope? of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<ShellScope>();

  @override
  bool updateShouldNotify(ShellScope oldWidget) => false;
}

class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int _index = 0;

  static const _tabs = <Widget>[
    HomeScreen(),
    InvoicesScreen(),
    ClientsScreen(),
    MoreScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return ShellScope(
      goTo: (i) => setState(() => _index = i),
      child: Scaffold(
        backgroundColor: context.dl.bg,
        body: Stack(
          children: [
            AnimatedSwitcher(
              duration: Motion.standard,
              switchInCurve: Motion.emphasized,
              switchOutCurve: Curves.easeInCubic,
              transitionBuilder: (child, anim) => FadeTransition(
                opacity: anim,
                child: SlideTransition(
                  position: Tween(begin: const Offset(0, 0.012), end: Offset.zero).animate(anim),
                  child: child,
                ),
              ),
              child: KeyedSubtree(key: ValueKey(_index), child: _tabs[_index]),
            ),
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: AppTabBar(
                index: _index,
                onTap: (i) => setState(() => _index = i),
                onCreate: () => pushPage(context, const InvoiceEditorScreen()),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class AppTabBar extends StatelessWidget {
  const AppTabBar({super.key, required this.index, required this.onTap, required this.onCreate});

  final int index;
  final ValueChanged<int> onTap;
  final VoidCallback onCreate;

  @override
  Widget build(BuildContext context) {
    final dl = context.dl;
    final inset = MediaQuery.paddingOf(context).bottom;
    return Container(
      padding: EdgeInsets.fromLTRB(14, 10, 14, inset > 0 ? inset : 18),
      decoration: BoxDecoration(
        color: dl.bg.withValues(alpha: 0.94),
        border: Border(top: BorderSide(color: dl.border)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _tab(context, 0, Icons.home_outlined, 'Home'),
          _tab(context, 1, Icons.description_outlined, 'Invoices'),
          Transform.translate(
            offset: const Offset(0, -8),
            child: Pressable(
              onTap: onCreate,
              scale: 0.9,
              semanticLabel: 'Create invoice',
              child: Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: Palette.wine,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Palette.wine.withValues(alpha: 0.30),
                      blurRadius: 26,
                      offset: const Offset(0, 12),
                    ),
                  ],
                ),
                child: const Icon(Icons.add_rounded, color: Palette.lemon, size: 28),
              ),
            ),
          ),
          _tab(context, 2, Icons.people_outline_rounded, 'Clients'),
          _tab(context, 3, Icons.grid_view_rounded, 'More'),
        ],
      ),
    );
  }

  Widget _tab(BuildContext context, int i, IconData icon, String label) {
    final dl = context.dl;
    final active = i == index;
    final color = active ? dl.ink : dl.muted;
    return Expanded(
      child: Pressable(
        onTap: () => onTap(i),
        scale: 0.94,
        semanticLabel: label,
        child: Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AnimatedScale(
                scale: active ? 1.0 : 0.94,
                duration: Motion.standard,
                curve: Motion.spring,
                child: Icon(icon, size: 24, color: color),
              ),
              const SizedBox(height: 4),
              Text(label, style: Fonts.sans(size: 11, weight: FontWeight.w600, color: color)),
            ],
          ),
        ),
      ),
    );
  }
}
