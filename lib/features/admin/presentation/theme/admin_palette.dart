import 'package:flutter/material.dart';

/// Admin design tokens.
///
/// Two colour libraries, adopted verbatim from the approved mockups:
///   • light  — the sage-green editorial set (page `#F7F8F5`, flat white cards
///     on hairline `#E7EAE4` borders, brand green `#2D7853`, and warm clay/sand
///     standing in for errors and attention instead of red).
///   • dark   — the olive-black set (root `#131513`, panels `#1B1E1A`, inputs
///     sunk to `#151A13`, terracotta accent `#E3A079`).
///
/// Depth comes from borders and 3px focus rings, not elevation, so `panel()`
/// keeps its shadow barely-there in both modes.
///
/// Never hardcode `Colors.white` on a `*Solid` token: the dark library's solids
/// are light-on-dark, so take the foreground from [onSolid] instead.
class AdminPalette {
  const AdminPalette({
    required this.isDark,
    required this.canvas,
    required this.surface,
    required this.surfaceAlt,
    required this.surfaceSunken,
    required this.border,
    required this.borderStrong,
    required this.ink,
    required this.inkMuted,
    required this.inkFaint,
    required this.scrim,
    required this.clay,
    required this.claySolid,
    required this.clayDeep,
    required this.onClay,
    required this.claySoft,
    required this.onClaySoft,
    required this.honeySolid,
    required this.honeySoft,
    required this.honeyInk,
    required this.oliveSolid,
    required this.oliveSoft,
    required this.oliveInk,
    required this.chiliSolid,
    required this.chiliSoft,
    required this.chiliInk,
    required this.nileSolid,
    required this.nileSoft,
    required this.nileInk,
    required this.plumSolid,
    required this.plumSoft,
    required this.plumInk,
    required this.shadow,
    required this.brandGradient,
  });

  final bool isDark;

  // --- Neutrals ---
  final Color canvas;
  final Color surface;
  final Color surfaceAlt;
  final Color surfaceSunken;
  final Color border;
  final Color borderStrong;
  final Color ink;
  final Color inkMuted;
  final Color inkFaint;
  final Color scrim;

  // --- Clay: the brand colour — primary actions, nav, focus lines ---
  final Color clay;
  final Color claySolid;
  final Color clayDeep;
  final Color onClay;
  final Color claySoft;
  final Color onClaySoft;

  // --- Honey: attention, pending work, prep time ---
  final Color honeySolid;
  final Color honeySoft;
  final Color honeyInk;

  // --- Olive: approved, healthy, confirmations ---
  final Color oliveSolid;
  final Color oliveSoft;
  final Color oliveInk;

  // --- Chili: destructive, errors, rejection ---
  final Color chiliSolid;
  final Color chiliSoft;
  final Color chiliInk;

  // --- Nile: informational / aquatic data ---
  final Color nileSolid;
  final Color nileSoft;
  final Color nileInk;

  // --- Plum: secondary data accent (categories, profile) ---
  final Color plumSolid;
  final Color plumSoft;
  final Color plumInk;

  final Color shadow;
  final LinearGradient brandGradient;

  static const AdminPalette light = AdminPalette(
    isDark: false,
    canvas: Color(0xFFF7F8F5),
    surface: Color(0xFFFFFFFF),
    surfaceAlt: Color(0xFFF5F7F2),
    surfaceSunken: Color(0xFFF1F5E9),
    border: Color(0xFFE7EAE4),
    borderStrong: Color(0xFFD8DFCC),
    ink: Color(0xFF263B32),
    inkMuted: Color(0xFF8B938D),
    inkFaint: Color(0xFFA3A89F),
    scrim: Color(0x66203428),
    clay: Color(0xFF448162),
    claySolid: Color(0xFF2D7853),
    clayDeep: Color(0xFF215C40),
    onClay: Color(0xFFFFFFFF),
    claySoft: Color(0xFFEDF5EB),
    onClaySoft: Color(0xFF215C40),
    honeySolid: Color(0xFF8F6A2F),
    honeySoft: Color(0xFFF7F1E5),
    honeyInk: Color(0xFF8A6A33),
    oliveSolid: Color(0xFF4C7C44),
    oliveSoft: Color(0xFFEDF5E8),
    oliveInk: Color(0xFF45763C),
    chiliSolid: Color(0xFFA65E3F),
    chiliSoft: Color(0xFFFBF6ED),
    chiliInk: Color(0xFF96552F),
    nileSolid: Color(0xFF3F6B66),
    nileSoft: Color(0xFFEDF2F1),
    nileInk: Color(0xFF41696B),
    plumSolid: Color(0xFF7A5566),
    plumSoft: Color(0xFFF4EEF0),
    plumInk: Color(0xFF6C4A5B),
    shadow: Color(0x0A263C23),
    brandGradient: LinearGradient(
      colors: [Color(0xFF2D7853), Color(0xFF215C40)],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    ),
  );

  static const AdminPalette dark = AdminPalette(
    isDark: true,
    canvas: Color(0xFF131513),
    surface: Color(0xFF1B1E1A),
    surfaceAlt: Color(0xFF23281E),
    surfaceSunken: Color(0xFF151A13),
    border: Color(0xFF31362C),
    borderStrong: Color(0xFF4B5B3D),
    ink: Color(0xFFECEEE8),
    inkMuted: Color(0xFF939B88),
    inkFaint: Color(0xFF6E756A),
    scrim: Color(0xBD0C130B),
    clay: Color(0xFFE3A079),
    claySolid: Color(0xFFE3A079),
    clayDeep: Color(0xFFB48159),
    onClay: Color(0xFF262A1E),
    claySoft: Color(0xFF352A21),
    onClaySoft: Color(0xFFEDB08B),
    honeySolid: Color(0xFF8A6A3A),
    honeySoft: Color(0xFF393323),
    honeyInk: Color(0xFFCCAD83),
    oliveSolid: Color(0xFF5F7D46),
    oliveSoft: Color(0xFF304226),
    oliveInk: Color(0xFFC5DCAC),
    chiliSolid: Color(0xFF966040),
    chiliSoft: Color(0xFF3A2820),
    chiliInk: Color(0xFFECB99A),
    nileSolid: Color(0xFF4E7168),
    nileSoft: Color(0xFF1E2B28),
    nileInk: Color(0xFFA8CCC2),
    plumSolid: Color(0xFF6E5566),
    plumSoft: Color(0xFF2A2229),
    plumInk: Color(0xFFD3BCCB),
    shadow: Color(0x40000000),
    brandGradient: LinearGradient(
      colors: [Color(0xFFE3A079), Color(0xFFB48159)],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    ),
  );

  static AdminPalette of(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark ? dark : light;

  /// Foreground that stays readable on a solid token. The dark library paints
  /// light solids (terracotta on olive), so white cannot be assumed. The 0.2
  /// cut-off is what keeps the light library's mid-greens on white while the
  /// dark library's warm accents flip to ink.
  Color onSolid(Color background) =>
      background.computeLuminance() > 0.2 ? surfaceSunken : Colors.white;

  /// Panel used by every card, dialog and sidebar block.
  BoxDecoration panel({
    Color? color,
    double radius = AdminRadii.lg,
    bool border = true,
    bool shadow = false,
    Color? borderColor,
  }) {
    return BoxDecoration(
      color: color ?? surface,
      borderRadius: BorderRadius.circular(radius),
      border: border
          ? Border.all(color: borderColor ?? this.border, width: 1)
          : null,
      boxShadow: shadow
          ? [
              BoxShadow(
                color: this.shadow,
                blurRadius: 10,
                offset: const Offset(0, 3),
              ),
            ]
          : null,
    );
  }

  /// Soft tint + readable foreground for a meal's protein type.
  ({Color bg, Color fg}) proteinTint(String proteinType) {
    switch (proteinType) {
      case 'meatless':
        return (bg: oliveSoft, fg: oliveInk);
      case 'beef':
        return (bg: chiliSoft, fg: chiliInk);
      case 'chicken':
        return (bg: honeySoft, fg: honeyInk);
      case 'fish':
        return (bg: nileSoft, fg: nileInk);
      default:
        return (bg: plumSoft, fg: plumInk);
    }
  }
}

class AdminRadii {
  AdminRadii._();

  static const double sm = 7;
  static const double md = 10;
  static const double lg = 12;
  static const double xl = 15;
  static const double pill = 999;
}
