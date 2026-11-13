import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Hanken Grotesk + JetBrains Mono — open stand-ins for Daylit's
/// Tt Commons Pro + Geist Mono. `tracking` is an em fraction.
abstract final class Fonts {
  /// Loads every bundled weight up front (tests and screenshots use it so the
  /// first frame is drawn in the brand fonts, not a fallback).
  static Future<void> preload() {
    for (final w in const [FontWeight.w400, FontWeight.w500, FontWeight.w600, FontWeight.w700, FontWeight.w800]) {
      GoogleFonts.hankenGrotesk(fontWeight: w);
    }
    for (final w in const [FontWeight.w400, FontWeight.w500, FontWeight.w600]) {
      GoogleFonts.jetBrainsMono(fontWeight: w);
    }
    return GoogleFonts.pendingFonts();
  }

  static TextStyle sans({
    double size = 15,
    FontWeight weight = FontWeight.w500,
    double tracking = -0.01,
    Color? color,
    double? height,
  }) {
    return GoogleFonts.hankenGrotesk(
      fontSize: size,
      fontWeight: weight,
      letterSpacing: size * tracking,
      color: color,
      height: height,
    );
  }

  static TextStyle mono({
    double size = 11,
    FontWeight weight = FontWeight.w500,
    double tracking = 0.06,
    Color? color,
    double? height,
  }) {
    return GoogleFonts.jetBrainsMono(
      fontSize: size,
      fontWeight: weight,
      letterSpacing: size * tracking,
      color: color,
      height: height,
    );
  }

  static TextStyle display(Color c) =>
      sans(size: 40, weight: FontWeight.w800, tracking: -0.03, color: c, height: 1.0);
  static TextStyle title(Color c) =>
      sans(size: 28, weight: FontWeight.w700, tracking: -0.03, color: c, height: 1.0);
  static TextStyle screen(Color c) =>
      sans(size: 20, weight: FontWeight.w700, tracking: -0.02, color: c);
  static TextStyle section(Color c) =>
      sans(size: 17, weight: FontWeight.w700, tracking: -0.02, color: c);
  static TextStyle body(Color c) =>
      sans(size: 15, weight: FontWeight.w600, tracking: -0.01, color: c);
  static TextStyle bodyRegular(Color c) =>
      sans(size: 15, weight: FontWeight.w500, tracking: -0.01, color: c, height: 1.45);
  static TextStyle caption(Color c) =>
      sans(size: 12.5, weight: FontWeight.w500, tracking: 0, color: c, height: 1.35);
  static TextStyle eyebrow(Color c, {double size = 11}) =>
      mono(size: size, weight: FontWeight.w500, tracking: 0.08, color: c);
  static TextStyle label(Color c) =>
      mono(size: 10, weight: FontWeight.w500, tracking: 0.06, color: c);
  static TextStyle amount(Color c, {double size = 15}) =>
      mono(size: size, weight: FontWeight.w600, tracking: -0.02, color: c);
}
