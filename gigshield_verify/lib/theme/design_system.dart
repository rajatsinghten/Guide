import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// ── GigShield Design System ──────────────────────────────────────────────
/// Centralized tokens: colors, typography, spacing, shadows, shapes.
/// All UI components should reference these instead of ad-hoc values.

class GsColors {
  GsColors._();

  // ── Primary palette (B&W) ───────────────────────────────────────────
  static const Color primary = Color(0xFF000000);       // Pure Black
  static const Color accent = Color(0xFF000000);        // Pure Black
  static const Color secondary = Color(0xFF64748B);

  // ── Semantic ────────────────────────────────────────────────────────
  static const Color success = Color(0xFF10B981);
  static const Color successSoft = Color(0xFFD1FAE5);
  static const Color error = Color(0xFFEF4444);         // Use this for "Not Covered"
  static const Color errorSoft = Color(0xFFFEE2E2);
  static const Color warning = Color(0xFFF59E0B);
  static const Color warningSoft = Color(0xFFFEF3C7);

  // ── Neutrals ────────────────────────────────────────────────────────
  static const Color surface = Color(0xFFF1F5F9);
  static const Color card = Colors.white;
  static const Color divider = Color(0xFFE2E8F0);
  static const Color textPrimary = Color(0xFF000000);
  static const Color textSecondary = Color(0xFF475569);
  static const Color textTertiary = Color(0xFF94A3B8);

  // ── Gradients (Removed/Replaced with Solid) ──────────────────────────
  static const LinearGradient primaryGradient = LinearGradient(
    colors: [primary, primary],
  );

  static const LinearGradient accentGradient = LinearGradient(
    colors: [accent, accent],
  );

  static const LinearGradient recordingGradient = LinearGradient(
    colors: [error, error],
  );
}

class GsTypography {
  GsTypography._();

  static TextStyle get heading => GoogleFonts.inter(
        fontSize: 24,
        fontWeight: FontWeight.w700,
        color: GsColors.textPrimary,
        height: 1.3,
      );

  static TextStyle get subheading => GoogleFonts.inter(
        fontSize: 16,
        fontWeight: FontWeight.w600,
        color: GsColors.textPrimary,
        height: 1.4,
      );

  static TextStyle get body => GoogleFonts.inter(
        fontSize: 14,
        fontWeight: FontWeight.w400,
        color: GsColors.textSecondary,
        height: 1.5,
      );

  static TextStyle get caption => GoogleFonts.inter(
        fontSize: 12,
        fontWeight: FontWeight.w400,
        color: GsColors.textTertiary,
        height: 1.4,
      );

  static TextStyle get label => GoogleFonts.inter(
        fontSize: 11,
        fontWeight: FontWeight.w600,
        color: GsColors.textTertiary,
        letterSpacing: 0.8,
      );

  static TextStyle get mono => GoogleFonts.jetBrainsMono(
        fontSize: 13,
        fontWeight: FontWeight.w500,
        color: GsColors.textPrimary,
        height: 1.4,
      );

  static TextStyle get button => GoogleFonts.inter(
        fontSize: 15,
        fontWeight: FontWeight.w600,
        height: 1.2,
      );
}

class GsSpacing {
  GsSpacing._();

  static const double xs = 4;
  static const double sm = 8;
  static const double md = 16;
  static const double lg = 24;
  static const double xl = 32;
  static const double xxl = 48;
}

class GsShadows {
  GsShadows._();

  static List<BoxShadow> get subtle => [
        BoxShadow(
          color: Colors.black.withOpacity(0.04),
          blurRadius: 8,
          offset: const Offset(0, 2),
        ),
      ];

  static List<BoxShadow> get card => [
        BoxShadow(
          color: Colors.black.withOpacity(0.06),
          blurRadius: 16,
          offset: const Offset(0, 4),
        ),
      ];

  static List<BoxShadow> get elevated => [
        BoxShadow(
          color: Colors.black.withOpacity(0.10),
          blurRadius: 24,
          offset: const Offset(0, 8),
        ),
      ];
}

class GsShapes {
  GsShapes._();

  static BorderRadius get sm => BorderRadius.circular(8);
  static BorderRadius get md => BorderRadius.circular(12);
  static BorderRadius get lg => BorderRadius.circular(16);
  static BorderRadius get xl => BorderRadius.circular(24);
}
