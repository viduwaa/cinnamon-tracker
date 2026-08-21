import "package:flutter/material.dart";

/// Cinnamon Trace design tokens — the "Cinnamon Harvest" system.
///
/// Aesthetic direction: warm, earthy, organic — rooted in the product itself.
/// Deep cinnamon-bark browns, quill-gold amber, leaf green for growth/success,
/// on a warm cream paper background. Large touch targets and high contrast
/// for outdoor / sunlight readability by farmers.
abstract final class Ct {
  // ---- Palette -----------------------------------------------------------
  static const Color bark = Color(0xFF4A2C17); // deep cinnamon bark (primary dark)
  static const Color cinnamon = Color(0xFF8B4A2B); // warm cinnamon (primary)
  static const Color quill = Color(0xFFD98E32); // quill-gold amber (accent)
  static const Color leaf = Color(0xFF4C7A34); // leaf green (success / growth)
  static const Color clay = Color(0xFFB4452F); // terracotta (error / warning)
  static const Color cream = Color(0xFFFAF3E7); // warm cream paper (background)
  static const Color paper = Color(0xFFFFFDF8); // card surface
  static const Color ink = Color(0xFF2B1D12); // primary text
  static const Color faded = Color(0xFF7A6A58); // secondary text
  static const Color line = Color(0xFFE8DCC8); // hairline / divider
  static const Color leafSoft = Color(0xFFE7EFDD); // soft green tint
  static const Color quillSoft = Color(0xFFF7E8D2); // soft amber tint
  static const Color claySoft = Color(0xFFF6E0DA); // soft terracotta tint

  // ---- Fonts -------------------------------------------------------------
  static const String display = "Baloo2"; // rounded, friendly display
  static const String body = "NotoSansSinhala"; // Sinhala-capable body

  // ---- Metrics -----------------------------------------------------------
  static const double radius = 18;
  static const double radiusSm = 12;
  static const double touch = 56; // primary button / target height
  static const double pad = 20;

  static ThemeData theme() {
    const scheme = ColorScheme(
      brightness: Brightness.light,
      primary: cinnamon,
      onPrimary: paper,
      secondary: quill,
      onSecondary: bark,
      error: clay,
      onError: paper,
      surface: paper,
      onSurface: ink,
    );

    final base = ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: cream,
    );

    final text = base.textTheme.copyWith(
      displayLarge: const TextStyle(
        fontFamily: display,
        fontSize: 34,
        fontWeight: FontWeight.w700,
        color: ink,
        height: 1.1,
      ),
      headlineMedium: const TextStyle(
        fontFamily: display,
        fontSize: 26,
        fontWeight: FontWeight.w700,
        color: ink,
        height: 1.15,
      ),
      titleLarge: const TextStyle(
        fontFamily: display,
        fontSize: 21,
        fontWeight: FontWeight.w600,
        color: ink,
      ),
      titleMedium: const TextStyle(
        fontFamily: body,
        fontSize: 17,
        fontWeight: FontWeight.w600,
        color: ink,
      ),
      bodyLarge: const TextStyle(
        fontFamily: body,
        fontSize: 17,
        color: ink,
        height: 1.4,
      ),
      bodyMedium: const TextStyle(
        fontFamily: body,
        fontSize: 15,
        color: ink,
        height: 1.4,
      ),
      labelLarge: const TextStyle(
        fontFamily: body,
        fontSize: 17,
        fontWeight: FontWeight.w700,
        color: paper,
      ),
      labelMedium: const TextStyle(
        fontFamily: body,
        fontSize: 14,
        fontWeight: FontWeight.w600,
        color: faded,
      ),
    );

    return base.copyWith(
      textTheme: text,
      appBarTheme: const AppBarTheme(
        backgroundColor: cream,
        foregroundColor: ink,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          fontFamily: display,
          fontSize: 22,
          fontWeight: FontWeight.w700,
          color: ink,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: cinnamon,
          foregroundColor: paper,
          elevation: 0,
          minimumSize: const Size.fromHeight(touch),
          textStyle: text.labelLarge,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radius),
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: cinnamon,
          minimumSize: const Size.fromHeight(touch),
          side: const BorderSide(color: cinnamon, width: 1.6),
          textStyle:
              text.labelLarge?.copyWith(color: cinnamon) ??
                  const TextStyle(color: cinnamon),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radius),
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: paper,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
        hintStyle:
            text.bodyMedium?.copyWith(color: faded) ??
                const TextStyle(color: faded),
        labelStyle:
            text.bodyMedium?.copyWith(color: faded) ??
                const TextStyle(color: faded),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusSm),
          borderSide: const BorderSide(color: line, width: 1.4),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusSm),
          borderSide: const BorderSide(color: line, width: 1.4),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusSm),
          borderSide: const BorderSide(color: cinnamon, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusSm),
          borderSide: const BorderSide(color: clay, width: 1.6),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: paper,
        indicatorColor: quillSoft,
        height: 72,
        labelTextStyle: WidgetStatePropertyAll(
          TextStyle(
            fontFamily: body,
            fontSize: 12.5,
            fontWeight: FontWeight.w600,
            color: ink,
          ),
        ),
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: leaf,
        foregroundColor: paper,
      ),
      dividerTheme: const DividerThemeData(color: line, thickness: 1),
    );
  }
}
