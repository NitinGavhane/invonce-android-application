import 'package:flutter/material.dart';

/// Daylit palette — burgundy ink on cream parchment.
/// Rule: burgundy = brand, green = money/paid, lemon = "tap here".
abstract final class Palette {
  static const wine = Color(0xFF4D1520);
  static const midnight = Color(0xFF360912);
  static const parchment = Color(0xFFFBF9F6);
  static const white = Color(0xFFFFFFFF);
  static const lemon = Color(0xFFFAFFA7);
  static const rust = Color(0xFF662F3D);
  static const mauve = Color(0xFF825B63);
  static const linen = Color(0xFFF2EEE7);
  static const sand = Color(0xFFD3CAC3);
  static const rose = Color(0xFFE9CDD2); // light text on wine
  static const citrine = Color(0xFFE6B800);

  static const paidGreen = Color(0xFF2F8F43);
  static const paidBg = Color(0xFFDCEBDC);
  static const paidText = Color(0xFF2F5D34);
  static const overdue = Color(0xFFC0443A);
  static const overdueBg = Color(0xFFF6DEDE);
  static const overdueText = Color(0xFF8F2525);
  static const sentBg = Color(0xFFE0E8F1);
  static const sentText = Color(0xFF33506B);
}

abstract final class Radii {
  static const card = 20.0;
  static const cardSm = 18.0;
  static const input = 14.0;
  static const tile = 13.0;
  static const icon = 12.0;
  static const pill = 999.0;
}

/// Surface roles that flip between light (parchment) and dark (midnight).
@immutable
class Daylit extends ThemeExtension<Daylit> {
  const Daylit({
    required this.bg,
    required this.surface,
    required this.border,
    required this.ink,
    required this.muted,
    required this.rust,
    required this.tile,
  });

  final Color bg;
  final Color surface;
  final Color border;
  final Color ink;
  final Color muted;
  final Color rust;
  final Color tile;

  static const light = Daylit(
    bg: Palette.parchment,
    surface: Palette.white,
    border: Palette.linen,
    ink: Palette.wine,
    muted: Palette.mauve,
    rust: Palette.rust,
    tile: Palette.linen,
  );

  static const dark = Daylit(
    bg: Palette.midnight,
    surface: Color(0xFF47161F),
    border: Color(0xFF5C2733),
    ink: Palette.parchment,
    muted: Color(0xFFC7A9B0),
    rust: Palette.rose,
    tile: Color(0xFF5C2733),
  );

  @override
  Daylit copyWith({
    Color? bg,
    Color? surface,
    Color? border,
    Color? ink,
    Color? muted,
    Color? rust,
    Color? tile,
  }) {
    return Daylit(
      bg: bg ?? this.bg,
      surface: surface ?? this.surface,
      border: border ?? this.border,
      ink: ink ?? this.ink,
      muted: muted ?? this.muted,
      rust: rust ?? this.rust,
      tile: tile ?? this.tile,
    );
  }

  @override
  Daylit lerp(ThemeExtension<Daylit>? other, double t) {
    if (other is! Daylit) return this;
    return Daylit(
      bg: Color.lerp(bg, other.bg, t)!,
      surface: Color.lerp(surface, other.surface, t)!,
      border: Color.lerp(border, other.border, t)!,
      ink: Color.lerp(ink, other.ink, t)!,
      muted: Color.lerp(muted, other.muted, t)!,
      rust: Color.lerp(rust, other.rust, t)!,
      tile: Color.lerp(tile, other.tile, t)!,
    );
  }
}

extension DaylitContext on BuildContext {
  Daylit get dl => Theme.of(this).extension<Daylit>() ?? Daylit.light;
}
