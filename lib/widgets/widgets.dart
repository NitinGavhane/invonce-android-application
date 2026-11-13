import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../data/models.dart';
import '../motion/motion.dart';
import '../theme/tokens.dart';
import '../theme/typography.dart';

// ─── Navigation & feedback ──────────────────────────────────────────────────

Future<T?> pushPage<T>(BuildContext context, Widget page) =>
    Navigator.of(context).push<T>(MaterialPageRoute<T>(builder: (_) => page));

/// Brief confirmation. Floats above the bottom action/tab bars so it never
/// covers the button the user is about to press next.
void toast(BuildContext context, String message) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(
      content: Text(message),
      duration: const Duration(milliseconds: 2200),
      margin: const EdgeInsets.fromLTRB(20, 0, 20, 108),
    ));
}

// ─── Press feedback ─────────────────────────────────────────────────────────

/// Scales down slightly while pressed and fires a selection haptic.
class Pressable extends StatefulWidget {
  const Pressable({
    super.key,
    required this.child,
    this.onTap,
    this.onLongPress,
    this.scale = 0.97,
    this.semanticLabel,
  });

  final Widget child;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final double scale;
  final String? semanticLabel;

  @override
  State<Pressable> createState() => _PressableState();
}

class _PressableState extends State<Pressable> {
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    if (widget.onTap == null) return widget.child;
    return Semantics(
      button: true,
      label: widget.semanticLabel,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: (_) => setState(() => _down = true),
        onTapUp: (_) => setState(() => _down = false),
        onTapCancel: () => setState(() => _down = false),
        onTap: () {
          Haptics.tap();
          widget.onTap!();
        },
        onLongPress: widget.onLongPress == null
            ? null
            : () {
                setState(() => _down = false);
                Haptics.success();
                widget.onLongPress!();
              },
        child: AnimatedScale(
          scale: _down ? widget.scale : 1,
          duration: Motion.fast,
          curve: Curves.easeOut,
          child: widget.child,
        ),
      ),
    );
  }
}

// ─── Buttons, chips, pills ──────────────────────────────────────────────────

enum DaylitVariant { primary, lemon, ghost }

class DaylitButton extends StatelessWidget {
  const DaylitButton(
    this.label, {
    super.key,
    this.onTap,
    this.variant = DaylitVariant.primary,
    this.icon,
    this.height = 52,
    this.fontSize = 15,
  });

  final String label;
  final VoidCallback? onTap;
  final DaylitVariant variant;
  final IconData? icon;
  final double height;
  final double fontSize;

  @override
  Widget build(BuildContext context) {
    final dl = context.dl;
    final (Color bg, Color fg, BoxBorder? border) = switch (variant) {
      DaylitVariant.primary => (Palette.wine, Palette.white, null),
      DaylitVariant.lemon => (Palette.lemon, Palette.wine, null),
      DaylitVariant.ghost => (dl.surface, dl.ink, Border.all(color: Palette.sand)),
    };
    return Pressable(
      onTap: onTap,
      semanticLabel: label,
      child: Container(
        height: height,
        padding: const EdgeInsets.symmetric(horizontal: 22),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(Radii.pill),
          border: border,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 18, color: fg),
              const SizedBox(width: 8),
            ],
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Fonts.sans(size: fontSize, weight: FontWeight.w700, color: fg),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class DaylitChip extends StatelessWidget {
  const DaylitChip(this.label, {super.key, this.active = false, this.onTap});

  final String label;
  final bool active;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final dl = context.dl;
    return Pressable(
      onTap: onTap,
      semanticLabel: label,
      child: AnimatedContainer(
        duration: Motion.fast,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        decoration: BoxDecoration(
          color: active ? Palette.wine : dl.surface,
          borderRadius: BorderRadius.circular(Radii.pill),
          border: Border.all(color: active ? Palette.wine : dl.border),
        ),
        child: Text(
          label.toUpperCase(),
          style: Fonts.mono(size: 11, tracking: 0.04, color: active ? Palette.lemon : dl.rust),
        ),
      ),
    );
  }
}

/// Horizontal row of chips with a single selection.
class ChipBar extends StatelessWidget {
  const ChipBar({super.key, required this.labels, required this.selected, required this.onSelect});

  final List<String> labels;
  final int selected;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      clipBehavior: Clip.none,
      child: Row(
        children: [
          for (var i = 0; i < labels.length; i++) ...[
            if (i > 0) const SizedBox(width: 8),
            DaylitChip(labels[i], active: i == selected, onTap: () => onSelect(i)),
          ],
        ],
      ),
    );
  }
}

class Pill extends StatelessWidget {
  const Pill(this.text, {super.key, required this.bg, required this.fg});

  final String text;
  final Color bg;
  final Color fg;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(Radii.pill)),
      child: Text(
        text.toUpperCase(),
        style: Fonts.mono(size: 10, weight: FontWeight.w600, tracking: 0.03, color: fg),
      ),
    );
  }
}

class StatusPill extends StatelessWidget {
  const StatusPill(this.status, {super.key});

  final InvoiceStatus status;

  static (Color, Color, String) styleOf(InvoiceStatus s) => switch (s) {
        InvoiceStatus.paid => (Palette.paidBg, Palette.paidText, 'Paid'),
        InvoiceStatus.unpaid => (Palette.lemon, Palette.wine, 'Unpaid'),
        InvoiceStatus.overdue => (Palette.overdueBg, Palette.overdueText, 'Overdue'),
        InvoiceStatus.draft => (Palette.linen, Palette.mauve, 'Draft'),
        InvoiceStatus.sent => (Palette.sentBg, Palette.sentText, 'Sent'),
        InvoiceStatus.accepted => (Palette.paidBg, Palette.paidText, 'Accepted'),
        InvoiceStatus.voided => (Palette.linen, Palette.mauve, 'Voided'),
      };

  @override
  Widget build(BuildContext context) {
    final (bg, fg, label) = styleOf(status);
    return Pill(label, bg: bg, fg: fg);
  }
}

// ─── Surfaces ───────────────────────────────────────────────────────────────

class DaylitCard extends StatelessWidget {
  const DaylitCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.radius = Radii.cardSm,
    this.color,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final double radius;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final dl = context.dl;
    return Container(
      width: double.infinity,
      padding: padding,
      decoration: BoxDecoration(
        color: color ?? dl.surface,
        borderRadius: BorderRadius.circular(radius),
        border: color == null ? Border.all(color: dl.border) : null,
      ),
      child: child,
    );
  }
}

/// A list card: rows separated by hairlines, tight vertical padding.
class ListCard extends StatelessWidget {
  const ListCard({super.key, required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return DaylitCard(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
      child: DividedColumn(children: children),
    );
  }
}

class DividedColumn extends StatelessWidget {
  const DividedColumn({super.key, required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final dl = context.dl;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < children.length; i++) ...[
          if (i > 0) Divider(height: 1, thickness: 1, color: dl.border),
          children[i],
        ],
      ],
    );
  }
}

class AvatarTile extends StatelessWidget {
  const AvatarTile(
    this.initials, {
    super.key,
    this.size = 42,
    this.color = Palette.wine,
    this.fg = Palette.lemon,
    this.radius = Radii.tile,
  });

  final String initials;
  final double size;
  final Color color;
  final Color fg;
  final double radius;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(radius)),
      child: Text(
        initials,
        style: Fonts.sans(size: size * 0.34, weight: FontWeight.w700, tracking: 0, color: fg),
      ),
    );
  }
}

class IconSquare extends StatelessWidget {
  const IconSquare(
    this.icon, {
    super.key,
    this.onTap,
    this.filled = false,
    this.size = 40,
    this.label,
  });

  final IconData icon;
  final VoidCallback? onTap;
  final bool filled;
  final double size;
  final String? label;

  @override
  Widget build(BuildContext context) {
    final dl = context.dl;
    return Pressable(
      onTap: onTap,
      scale: 0.92,
      semanticLabel: label,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: filled ? Palette.wine : dl.surface,
          borderRadius: BorderRadius.circular(size >= 44 ? Radii.input : Radii.icon),
          border: filled ? null : Border.all(color: dl.border),
        ),
        child: Icon(icon, size: size * 0.5, color: filled ? Palette.lemon : dl.ink),
      ),
    );
  }
}

class IconTile extends StatelessWidget {
  const IconTile(this.icon, {super.key, this.size = 34, this.color, this.fg});

  final IconData icon;
  final double size;
  final Color? color;
  final Color? fg;

  @override
  Widget build(BuildContext context) {
    final dl = context.dl;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color ?? dl.tile,
        borderRadius: BorderRadius.circular(size * 0.3),
      ),
      child: Icon(icon, size: size * 0.55, color: fg ?? dl.ink),
    );
  }
}

class Chevron extends StatelessWidget {
  const Chevron({super.key, this.color});

  final Color? color;

  @override
  Widget build(BuildContext context) =>
      Icon(Icons.chevron_right_rounded, size: 20, color: color ?? Palette.sand);
}

// ─── Text helpers ───────────────────────────────────────────────────────────

class Eyebrow extends StatelessWidget {
  const Eyebrow(this.text, {super.key, this.color, this.size = 11});

  final String text;
  final Color? color;
  final double size;

  @override
  Widget build(BuildContext context) =>
      Text(text.toUpperCase(), style: Fonts.eyebrow(color ?? context.dl.muted, size: size));
}

class SectionLabel extends StatelessWidget {
  const SectionLabel(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(2, 6, 2, 8),
        child: Eyebrow(text, size: 10.5),
      );
}

class SectionHead extends StatelessWidget {
  const SectionHead(this.title, {super.key, this.action, this.onAction});

  final String title;
  final String? action;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final dl = context.dl;
    return Padding(
      padding: const EdgeInsets.fromLTRB(0, 4, 0, 10),
      child: Row(
        children: [
          Expanded(child: Text(title, style: Fonts.section(dl.ink))),
          if (action != null)
            Pressable(
              onTap: onAction,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                child: Text(action!, style: Fonts.sans(size: 13, weight: FontWeight.w600, color: dl.rust)),
              ),
            ),
        ],
      ),
    );
  }
}

// ─── Headers ────────────────────────────────────────────────────────────────

class PageHeader extends StatelessWidget {
  const PageHeader({super.key, required this.title, this.eyebrow, this.trailing});

  final String title;
  final String? eyebrow;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final dl = context.dl;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (eyebrow != null) ...[Eyebrow(eyebrow!), const SizedBox(height: 6)],
                Text(title, style: Fonts.title(dl.ink)),
              ],
            ),
          ),
          ?trailing,
        ],
      ),
    );
  }
}

class TopBar extends StatelessWidget {
  const TopBar({super.key, required this.title, this.trailing = const [], this.onBack});

  final String title;
  final List<Widget> trailing;
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) {
    final dl = context.dl;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 10),
      child: Row(
        children: [
          IconSquare(
            Icons.arrow_back_ios_new_rounded,
            label: 'Back',
            onTap: onBack ?? () => Navigator.of(context).maybePop(),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: Fonts.screen(dl.ink)),
          ),
          for (final t in trailing) ...[const SizedBox(width: 8), t],
        ],
      ),
    );
  }
}

// ─── Form-ish tiles ─────────────────────────────────────────────────────────

class FieldTile extends StatelessWidget {
  const FieldTile({
    super.key,
    required this.label,
    this.value,
    this.child,
    this.focused = false,
    this.mono = false,
    this.muted = false,
    this.minHeight,
  });

  final String label;
  final String? value;
  final Widget? child;
  final bool focused;
  final bool mono;
  final bool muted;
  final double? minHeight;

  @override
  Widget build(BuildContext context) {
    final dl = context.dl;
    final color = muted ? dl.muted : dl.ink;
    return Container(
      width: double.infinity,
      constraints: minHeight != null ? BoxConstraints(minHeight: minHeight!) : null,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: dl.surface,
        borderRadius: BorderRadius.circular(Radii.input),
        border: Border.all(color: focused ? Palette.wine : dl.border, width: focused ? 1.5 : 1),
        boxShadow: focused
            ? [BoxShadow(color: Palette.wine.withValues(alpha: 0.08), spreadRadius: 3)]
            : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Eyebrow(label, size: 10),
          const SizedBox(height: 3),
          child ??
              Text(
                value ?? '',
                style: mono
                    ? Fonts.mono(size: 14, weight: FontWeight.w600, tracking: 0, color: color)
                    : Fonts.sans(size: 15, weight: muted ? FontWeight.w500 : FontWeight.w600, color: color, height: 1.35),
              ),
        ],
      ),
    );
  }
}

class DaylitToggle extends StatelessWidget {
  const DaylitToggle({super.key, required this.value, this.onChanged});

  final bool value;
  final ValueChanged<bool>? onChanged;

  @override
  Widget build(BuildContext context) {
    return Pressable(
      onTap: onChanged == null ? null : () => onChanged!(!value),
      scale: 0.94,
      semanticLabel: value ? 'On' : 'Off',
      child: AnimatedContainer(
        duration: Motion.standard,
        curve: Motion.emphasized,
        width: 46,
        height: 28,
        padding: const EdgeInsets.all(3),
        decoration: BoxDecoration(
          color: value ? Palette.wine : Palette.sand,
          borderRadius: BorderRadius.circular(Radii.pill),
        ),
        child: AnimatedAlign(
          duration: Motion.standard,
          curve: Motion.emphasized,
          alignment: value ? Alignment.centerRight : Alignment.centerLeft,
          child: Container(
            width: 22,
            height: 22,
            decoration: BoxDecoration(
              color: value ? Palette.lemon : Palette.white,
              shape: BoxShape.circle,
            ),
          ),
        ),
      ),
    );
  }
}

class SearchBox extends StatelessWidget {
  const SearchBox(this.hint, {super.key, this.onChanged});

  final String hint;
  final ValueChanged<String>? onChanged;

  @override
  Widget build(BuildContext context) {
    final dl = context.dl;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: dl.surface,
        borderRadius: BorderRadius.circular(Radii.input),
        border: Border.all(color: dl.border),
      ),
      child: Row(
        children: [
          Icon(Icons.search_rounded, size: 20, color: dl.muted),
          const SizedBox(width: 10),
          Expanded(
            child: TextField(
              onChanged: onChanged,
              autocorrect: false,
              style: Fonts.sans(size: 14, weight: FontWeight.w600, color: dl.ink),
              cursorColor: Palette.wine,
              decoration: InputDecoration.collapsed(hintText: hint, hintStyle: Fonts.sans(size: 14, color: dl.muted)),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Rows ───────────────────────────────────────────────────────────────────

class RowTile extends StatelessWidget {
  const RowTile({
    super.key,
    required this.title,
    this.subtitle,
    this.leading,
    this.trailing,
    this.onTap,
    this.verticalPadding = 11,
    this.subtitleMono = true,
    this.subtitleWidget,
  });

  final String title;
  final String? subtitle;
  final Widget? subtitleWidget;
  final Widget? leading;
  final Widget? trailing;
  final VoidCallback? onTap;
  final double verticalPadding;
  final bool subtitleMono;

  @override
  Widget build(BuildContext context) {
    final dl = context.dl;
    return Pressable(
      onTap: onTap,
      scale: 0.985,
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: verticalPadding),
        child: Row(
          children: [
            if (leading != null) ...[leading!, const SizedBox(width: 12)],
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: Fonts.body(dl.ink)),
                  if (subtitleWidget != null) ...[const SizedBox(height: 2), subtitleWidget!]
                  else if (subtitle != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      subtitle!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: subtitleMono
                          ? Fonts.mono(size: 11, tracking: 0, color: dl.muted)
                          : Fonts.caption(dl.muted),
                    ),
                  ],
                ],
              ),
            ),
            if (trailing != null) ...[const SizedBox(width: 10), trailing!],
          ],
        ),
      ),
    );
  }
}

/// Settings-style row: icon tile · label · hint · chevron.
class SettingRow extends StatelessWidget {
  const SettingRow(this.label, {super.key, required this.icon, this.hint, this.onTap, this.trailing});

  final String label;
  final IconData icon;
  final String? hint;
  final VoidCallback? onTap;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final dl = context.dl;
    return Pressable(
      onTap: onTap,
      scale: 0.985,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 9),
        child: Row(
          children: [
            IconTile(icon, size: 32),
            const SizedBox(width: 12),
            Expanded(child: Text(label, style: Fonts.sans(size: 14.5, weight: FontWeight.w600, color: dl.ink))),
            if (hint != null) ...[
              Text(hint!, style: Fonts.mono(size: 10.5, tracking: 0.02, color: dl.muted)),
              const SizedBox(width: 6),
            ],
            trailing ?? const Chevron(),
          ],
        ),
      ),
    );
  }
}

// ─── Layout shells ──────────────────────────────────────────────────────────

/// Bottom action bar that fades up from the page background.
class BottomActionBar extends StatelessWidget {
  const BottomActionBar({super.key, required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final bg = context.dl.bg;
    final inset = MediaQuery.paddingOf(context).bottom;
    return Positioned(
      left: 0,
      right: 0,
      bottom: 0,
      child: Container(
        padding: EdgeInsets.fromLTRB(20, 18, 20, 18 + (inset > 0 ? inset : 10)),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [bg.withValues(alpha: 0), bg, bg],
            stops: const [0, 0.34, 1],
          ),
        ),
        child: Row(
          children: [
            for (var i = 0; i < children.length; i++) ...[
              if (i > 0) const SizedBox(width: 12),
              children[i],
            ],
          ],
        ),
      ),
    );
  }
}

/// A Column with Spacers that fills the screen when there is room and
/// scrolls when there is not (short phones, large text).
class FillOrScroll extends StatelessWidget {
  const FillOrScroll({super.key, required this.child, this.padding = EdgeInsets.zero});

  final Widget child;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: constraints.maxHeight),
          child: IntrinsicHeight(child: Padding(padding: padding, child: child)),
        ),
      ),
    );
  }
}

/// Header + scrolling body + optional bottom actions.
class ScreenScaffold extends StatelessWidget {
  const ScreenScaffold({
    super.key,
    required this.header,
    required this.children,
    this.bottom,
    this.bottomPadding = 120,
    this.background,
  });

  final Widget header;
  final List<Widget> children;
  final List<Widget>? bottom;
  final double bottomPadding;
  final Color? background;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: background ?? context.dl.bg,
      body: SafeArea(
        bottom: false,
        child: Stack(
          children: [
            Column(
              children: [
                header,
                Expanded(
                  child: ListView(
                    padding: EdgeInsets.fromLTRB(20, 4, 20, bottomPadding),
                    physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
                    children: children,
                  ),
                ),
              ],
            ),
            if (bottom != null) BottomActionBar(children: bottom!),
          ],
        ),
      ),
    );
  }
}

// ─── Brand mark ─────────────────────────────────────────────────────────────

/// The Invonce mark: a torn-edge receipt carrying a `$`.
class ReceiptMark extends StatelessWidget {
  const ReceiptMark({
    super.key,
    this.size = 48,
    this.paper = Palette.lemon,
    this.ink = Palette.wine,
    this.fontFamily,
  });

  final double size;
  final Color paper;
  final Color ink;

  /// Explicit family for the `$` (used when rendering the app icon offline).
  final String? fontFamily;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size.square(size),
      painter: _ReceiptPainter(paper: paper, ink: ink, fontFamily: fontFamily),
    );
  }
}

class _ReceiptPainter extends CustomPainter {
  _ReceiptPainter({required this.paper, required this.ink, this.fontFamily});

  final Color paper;
  final Color ink;
  final String? fontFamily;

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width / 48;
    final path = Path()
      ..moveTo(12 * s, 11 * s)
      ..arcToPoint(Offset(15 * s, 8 * s), radius: Radius.circular(3 * s))
      ..lineTo(33 * s, 8 * s)
      ..arcToPoint(Offset(36 * s, 11 * s), radius: Radius.circular(3 * s))
      ..lineTo(36 * s, 38 * s);
    for (var i = 0; i < 6; i++) {
      path
        ..relativeLineTo(-2 * s, -3 * s)
        ..relativeLineTo(-2 * s, 3 * s);
    }
    path.close();
    canvas.drawPath(path, Paint()..color = paper);

    final style = fontFamily != null
        ? TextStyle(fontFamily: fontFamily, fontSize: 23 * s, fontWeight: FontWeight.w800, color: ink)
        : GoogleFonts.hankenGrotesk(fontSize: 23 * s, fontWeight: FontWeight.w800, color: ink);
    final tp = TextPainter(text: TextSpan(text: r'$', style: style), textDirection: TextDirection.ltr)..layout();
    tp.paint(canvas, Offset(24 * s - tp.width / 2, 23 * s - tp.height / 2));
  }

  @override
  bool shouldRepaint(_ReceiptPainter old) =>
      old.paper != paper || old.ink != ink || old.fontFamily != fontFamily;
}
