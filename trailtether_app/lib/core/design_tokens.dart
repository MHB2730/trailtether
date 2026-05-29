import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Trailtether 2.0 design system.
///
/// Tokens follow the polish-pass mock in trailtether/project/index.html —
/// a deeper graphite + two-step burnt-ember palette, 14/16/24 spacing rhythm,
/// Manrope sans + JetBrains Mono numerals. All values keep `kColorOrange` /
/// `kColorCream` from constants.dart intact so legacy screens keep their
/// look until they're individually reskinned.
class TT {
  TT._();

  // ── Surfaces ──────────────────────────────────────────────────────────────
  static const bg = Color(0xFF07090C);
  static const bg2 = Color(0xFF0B0E12);
  static const bg3 = Color(0xFF0F1318);
  static const surf = Color(0xFF131820);
  static const surf2 = Color(0xFF1A2029);
  static const surf3 = Color(0xFF232A35);

  // ── Lines ─────────────────────────────────────────────────────────────────
  static const line = Color(0x0EFFFFFF); // ~5.5% white
  static const line2 = Color(0x1AFFFFFF); // 10% white
  static const line3 = Color(0x29FFFFFF); // 16% white

  // ── Text ──────────────────────────────────────────────────────────────────
  static const text = Color(0xFFEEF1F4);
  static const text2 = Color(0xFF98A1AC);
  static const text3 = Color(0xFF5A6470);
  static const text4 = Color(0xFF3D454D);

  // ── Burnt ember (brand) ───────────────────────────────────────────────────
  static const ember = Color(0xFFFF6A2C);
  static const ember2 = Color(0xFFFF8A4D);
  static const ember3 = Color(0xFFFFB486);
  static const emberDim = Color(0x24FF6A2C); // 14% ember
  static const emberSoft = Color(0x0FFF6A2C); // 6% ember
  static const emberInk = Color(0xFF1A0D04); // ink-on-ember (used for FAB text)

  // ── Status semantics ──────────────────────────────────────────────────────
  static const blue = Color(0xFF5AA1D6);
  static const green = Color(0xFF4CC38A);
  static const amber = Color(0xFFF2A93B);
  static const red = Color(0xFFE63D2E);

  // ── Radii ─────────────────────────────────────────────────────────────────
  static const rSm = 8.0;
  static const rMd = 12.0;
  static const rLg = 16.0;
  static const rXl = 22.0;

  // ── Spacing rhythm ────────────────────────────────────────────────────────
  static const s1 = 4.0;
  static const s2 = 8.0;
  static const s3 = 14.0;
  static const s4 = 16.0;
  static const s5 = 24.0;
  static const s6 = 32.0;

  // ── Shadows ───────────────────────────────────────────────────────────────
  static const shadowCard = [
    BoxShadow(
        color: Color(0x99000000),
        offset: Offset(0, 8),
        blurRadius: 24,
        spreadRadius: -12),
    BoxShadow(
        color: Color(0x66000000),
        offset: Offset(0, 2),
        blurRadius: 6,
        spreadRadius: -2),
  ];
  static const shadowEmber = [
    BoxShadow(
        color: Color(0x73FF6A2C),
        offset: Offset(0, 10),
        blurRadius: 30,
        spreadRadius: -8),
  ];

  // ── Animation curves & durations ──────────────────────────────────────────
  static const easeOut = Cubic(0.2, 0.7, 0.2, 1.0);
  static const drawCurve = Cubic(0.6, 0.2, 0.2, 1.0);
  static const dFast = Duration(milliseconds: 200);
  static const dMed = Duration(milliseconds: 350);
  static const dSlow = Duration(milliseconds: 700);
  static const dDraw = Duration(milliseconds: 1800);

  // ── Typography ────────────────────────────────────────────────────────────
  static TextStyle title(double size,
          {Color? color,
          FontWeight w = FontWeight.w800,
          double letterSpacing = -0.02 * 16}) =>
      GoogleFonts.manrope(
          fontSize: size,
          fontWeight: w,
          color: color ?? text,
          letterSpacing: letterSpacing,
          height: 1.1);
  static TextStyle label(
          {double size = 10.5,
          Color? color,
          FontWeight w = FontWeight.w700,
          double letterSpacing = 1.6}) =>
      GoogleFonts.manrope(
          fontSize: size,
          fontWeight: w,
          color: color ?? text3,
          letterSpacing: letterSpacing);
  static TextStyle body(
          {double size = 13, Color? color, FontWeight w = FontWeight.w600}) =>
      GoogleFonts.manrope(fontSize: size, fontWeight: w, color: color ?? text);
  static TextStyle mono(
          {double size = 11,
          Color? color,
          FontWeight w = FontWeight.w700,
          double letterSpacing = 0.04 * 11}) =>
      GoogleFonts.jetBrainsMono(
          fontSize: size,
          fontWeight: w,
          color: color ?? text2,
          letterSpacing: letterSpacing,
          fontFeatures: const [FontFeature.tabularFigures()]);
  static TextStyle numStyle(
          {double size = 17,
          Color? color,
          FontWeight w = FontWeight.w800,
          double letterSpacing = -0.02 * 17}) =>
      GoogleFonts.jetBrainsMono(
          fontSize: size,
          fontWeight: w,
          color: color ?? text,
          letterSpacing: letterSpacing,
          fontFeatures: const [FontFeature.tabularFigures()]);
}
