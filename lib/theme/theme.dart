import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../motion/motion.dart';
import 'tokens.dart';
import 'typography.dart';

ThemeData buildDaylitTheme(Brightness brightness) {
  final dl = brightness == Brightness.light ? Daylit.light : Daylit.dark;
  final base = ThemeData(useMaterial3: true, brightness: brightness);

  return base.copyWith(
    scaffoldBackgroundColor: dl.bg,
    canvasColor: dl.bg,
    colorScheme: base.colorScheme.copyWith(
      primary: Palette.wine,
      onPrimary: Palette.lemon,
      secondary: Palette.lemon,
      onSecondary: Palette.wine,
      surface: dl.surface,
      onSurface: dl.ink,
      outline: dl.border,
    ),
    textTheme: GoogleFonts.hankenGroteskTextTheme(base.textTheme)
        .apply(bodyColor: dl.ink, displayColor: dl.ink),
    extensions: <ThemeExtension<dynamic>>[dl],
    dividerColor: dl.border,
    splashFactory: NoSplash.splashFactory,
    highlightColor: Colors.transparent,
    pageTransitionsTheme: const PageTransitionsTheme(
      builders: {
        TargetPlatform.android: DaylitTransitionsBuilder(),
        TargetPlatform.iOS: DaylitTransitionsBuilder(),
        TargetPlatform.macOS: DaylitTransitionsBuilder(),
        TargetPlatform.linux: DaylitTransitionsBuilder(),
        TargetPlatform.windows: DaylitTransitionsBuilder(),
        TargetPlatform.fuchsia: DaylitTransitionsBuilder(),
      },
    ),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: Palette.wine,
      contentTextStyle:
          Fonts.sans(size: 14, weight: FontWeight.w600, color: Palette.parchment),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
    ),
    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor: Colors.transparent,
      surfaceTintColor: Colors.transparent,
    ),
  );
}
