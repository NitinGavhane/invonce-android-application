import 'package:flutter/material.dart';

import '../theme/tokens.dart';
import '../theme/typography.dart';
import 'widgets.dart';

/// Opens a Daylit bottom sheet that resizes above the keyboard.
Future<T?> showSheet<T>(BuildContext context, WidgetBuilder builder) {
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    builder: builder,
  );
}

/// Handle · title · fields · save button. Scrolls when the keyboard is up.
class SheetShell extends StatelessWidget {
  const SheetShell({
    super.key,
    required this.title,
    required this.children,
    required this.saveLabel,
    this.onSave,
    this.busy = false,
    this.subtitle,
  });

  final String title;
  final String? subtitle;
  final List<Widget> children;
  final String saveLabel;
  final VoidCallback? onSave;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final dl = context.dl;
    return Container(
      decoration: BoxDecoration(color: dl.surface, borderRadius: const BorderRadius.vertical(top: Radius.circular(28))),
      padding: EdgeInsets.fromLTRB(20, 12, 20, 20 + MediaQuery.viewInsetsOf(context).bottom),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(width: 40, height: 5, decoration: BoxDecoration(color: Palette.sand, borderRadius: BorderRadius.circular(99))),
            ),
            const SizedBox(height: 14),
            Text(title, style: Fonts.screen(dl.ink)),
            if (subtitle != null) ...[const SizedBox(height: 3), Text(subtitle!, style: Fonts.caption(dl.muted))],
            const SizedBox(height: 12),
            for (var i = 0; i < children.length; i++) ...[
              if (i > 0) const SizedBox(height: 10),
              children[i],
            ],
            const SizedBox(height: 16),
            DaylitButton(busy ? 'Saving…' : saveLabel, onTap: busy ? null : onSave),
          ],
        ),
      ),
    );
  }
}

/// A labelled text input in the FieldTile style.
class SheetInput extends StatelessWidget {
  const SheetInput({
    super.key,
    required this.label,
    required this.controller,
    this.hint = '',
    this.keyboard,
    this.lines = 1,
    this.mono = false,
    this.autofocus = false,
    this.onSubmit,
  });

  final String label;
  final TextEditingController controller;
  final String hint;
  final TextInputType? keyboard;
  final int lines;
  final bool mono;
  final bool autofocus;
  final VoidCallback? onSubmit;

  @override
  Widget build(BuildContext context) {
    final dl = context.dl;
    return FieldTile(
      label: label,
      child: TextField(
        controller: controller,
        keyboardType: keyboard,
        maxLines: lines,
        autofocus: autofocus,
        autocorrect: false,
        style: mono ? Fonts.mono(size: 15, weight: FontWeight.w600, tracking: 0, color: dl.ink) : Fonts.body(dl.ink),
        cursorColor: Palette.wine,
        onSubmitted: onSubmit == null ? null : (_) => onSubmit!(),
        decoration: InputDecoration.collapsed(hintText: hint, hintStyle: Fonts.sans(size: 15, color: dl.muted)),
      ),
    );
  }
}

/// Parses "1,240.50", "$99", "" → double?.
double? parseAmount(String raw) {
  final cleaned = raw.replaceAll(RegExp(r'[^0-9.]'), '');
  if (cleaned.isEmpty) return null;
  return double.tryParse(cleaned);
}
