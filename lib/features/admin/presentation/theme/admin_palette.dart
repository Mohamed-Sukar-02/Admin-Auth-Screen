import 'package:flutter/material.dart';

/// Indigo-on-slate design tokens for the admin dashboard.
///
/// Every colour the dashboard paints comes from here — no raw hex values are
/// allowed in the screens. The system is anchored on the app's own brand
/// indigo (`#635BFF`, the same one the admin sign-in screens already use) and
/// a cool slate neutral scale, with four supporting hues:
///   indigo (brand)  • amber (attention)  • green (positive)  • red (negative)
/// plus sky and pink reserved for secondary data accents.
///
/// All solid tokens are tuned so plain white text clears WCAG AA (4.5:1)
/// on them in both modes, because the screens hardcode `Colors.white` on
/// solid pills, buttons and snackbars.
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

  // --- Neutrals: cool slate, clean and calm ---
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

  // --- Clay: the brand indigo, used for primary actions and nav ---
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
    canvas: Color(0xFFF8FAFC),
    surface: Color(0xFFFFFFFF),
    surfaceAlt: Color(0xFFF1F5F9),
    surfaceSunken: Color(0xFFE9EEF5),
    border: Color(0xFFE2E8F0),
    borderStrong: Color(0xFFCBD5E1),
    ink: Color(0xFF0F172A),
    inkMuted: Color(0xFF64748B),
    inkFaint: Color(0xFF94A3B8),
    scrim: Color(0x660F172A),
    clay: Color(0xFF635BFF),
    claySolid: Color(0xFF635BFF),
    clayDeep: Color(0xFF5149D9),
    onClay: Color(0xFFFFFFFF),
    claySoft: Color(0xFFECEDFD),
    onClaySoft: Color(0xFF5149D9),
    honeySolid: Color(0xFFB45309),
    honeySoft: Color(0xFFFEF3C7),
    honeyInk: Color(0xFF92400E),
    oliveSolid: Color(0xFF15803D),
    oliveSoft: Color(0xFFDCFCE7),
    oliveInk: Color(0xFF166534),
    chiliSolid: Color(0xFFDC2626),
    chiliSoft: Color(0xFFFEE2E2),
    chiliInk: Color(0xFFB91C1C),
    nileSolid: Color(0xFF0369A1),
    nileSoft: Color(0xFFE0F2FE),
    nileInk: Color(0xFF075985),
    plumSolid: Color(0xFFDB2777),
    plumSoft: Color(0xFFFCE7F3),
    plumInk: Color(0xFFBE185D),
    shadow: Color(0x140F172A),
    brandGradient: LinearGradient(
      colors: [Color(0xFF716AFF), Color(0xFF5149D9)],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    ),
  );

  static const AdminPalette dark = AdminPalette(
    isDark: true,
    canvas: Color(0xFF0F172A),
    surface: Color(0xFF1A2436),
    surfaceAlt: Color(0xFF222E45),
    surfaceSunken: Color(0xFF0B1220),
    border: Color(0xFF2B3752),
    borderStrong: Color(0xFF3E4C6E),
    ink: Color(0xFFF1F5F9),
    inkMuted: Color(0xFF94A3B8),
    inkFaint: Color(0xFF64748B),
    scrim: Color(0x990B1220),
    clay: Color(0xFF818CF8),
    claySolid: Color(0xFF5149D9),
    clayDeep: Color(0xFF463FBF),
    onClay: Color(0xFFFFFFFF),
    claySoft: Color(0xFF201F45),
    onClaySoft: Color(0xFFA5B4FC),
    honeySolid: Color(0xFFB45309),
    honeySoft: Color(0xFF382711),
    honeyInk: Color(0xFFFBBF24),
    oliveSolid: Color(0xFF15803D),
    oliveSoft: Color(0xFF12301E),
    oliveInk: Color(0xFF86EFAC),
    chiliSolid: Color(0xFFDC2626),
    chiliSoft: Color(0xFF391A1D),
    chiliInk: Color(0xFFFCA5A5),
    nileSolid: Color(0xFF0B7AB8),
    nileSoft: Color(0xFF0D2A3D),
    nileInk: Color(0xFF7DD3FC),
    plumSolid: Color(0xFFDB2777),
    plumSoft: Color(0xFF371A2B),
    plumInk: Color(0xFFF9A8D4),
    shadow: Color(0x66000000),
    brandGradient: LinearGradient(
      colors: [Color(0xFF716AFF), Color(0xFF5149D9)],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    ),
  );

  static AdminPalette of(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark ? dark : light;

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
                blurRadius: 18,
                offset: const Offset(0, 6),
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

  static const double sm = 10;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 22;
  static const double pill = 999;
}
