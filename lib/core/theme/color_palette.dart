import 'package:flutter/material.dart';

/// One tonal variant (either the dark or light half) of a color palette.
class PaletteTone {
  final Color background;
  final Color surface;
  final Color surfaceVariant;
  final Color accent;
  final Color accentMuted;
  final Color textPrimary;
  final Color textSecondary;

  const PaletteTone({
    required this.background,
    required this.surface,
    required this.surfaceVariant,
    required this.accent,
    required this.accentMuted,
    required this.textPrimary,
    required this.textSecondary,
  });
}

/// A named color theme, with its own dark and light variant. Danger,
/// warning, and success colors are intentionally NOT part of a palette —
/// those stay the same everywhere so status colors are always
/// recognizable regardless of which theme is selected.
class AppPalette {
  final String id;
  final String label;
  final PaletteTone dark;
  final PaletteTone light;

  const AppPalette({
    required this.id,
    required this.label,
    required this.dark,
    required this.light,
  });

  /// Representative color for the little swatch in the theme picker.
  Color get swatchColor => dark.accent;
}

const List<AppPalette> kAppPalettes = [
  AppPalette(
    id: 'indigo_gold',
    label: 'Indigo & Gold',
    dark: PaletteTone(
      background: Color(0xFF16112A),
      surface: Color(0xFF221A3B),
      surfaceVariant: Color(0xFF2D2350),
      accent: Color(0xFFD9AD6B),
      accentMuted: Color(0xFFE8C68F),
      textPrimary: Color(0xFFEDE9F5),
      textSecondary: Color(0xFFA79BC4),
    ),
    light: PaletteTone(
      background: Color(0xFFD6C2EC),
      surface: Color(0xFFE3D3F5),
      surfaceVariant: Color(0xFFC7AEE3),
      accent: Color(0xFF8A5D26),
      accentMuted: Color(0xFFA1732F),
      textPrimary: Color(0xFF201431),
      textSecondary: Color(0xFF52406E),
    ),
  ),
  AppPalette(
    id: 'ocean_blue',
    label: 'Ocean Blue',
    dark: PaletteTone(
      background: Color(0xFF0D1B2A),
      surface: Color(0xFF16273B),
      surfaceVariant: Color(0xFF1F3550),
      accent: Color(0xFF4FD1E8),
      accentMuted: Color(0xFF7EE0F0),
      textPrimary: Color(0xFFE8F4FA),
      textSecondary: Color(0xFF8FB4C9),
    ),
    light: PaletteTone(
      background: Color(0xFFC7E3F0),
      surface: Color(0xFFD9EDF7),
      surfaceVariant: Color(0xFFB0D4E8),
      accent: Color(0xFF0E7C91),
      accentMuted: Color(0xFF149FB8),
      textPrimary: Color(0xFF0E1E27),
      textSecondary: Color(0xFF3D6478),
    ),
  ),
  AppPalette(
    id: 'emerald_forest',
    label: 'Emerald Forest',
    dark: PaletteTone(
      background: Color(0xFF0F1F17),
      surface: Color(0xFF17301F),
      surfaceVariant: Color(0xFF204028),
      accent: Color(0xFF6FCF7A),
      accentMuted: Color(0xFF97DE9F),
      textPrimary: Color(0xFFE7F5E8),
      textSecondary: Color(0xFF9CC0A0),
    ),
    light: PaletteTone(
      background: Color(0xFFCBE8CE),
      surface: Color(0xFFDCF2DE),
      surfaceVariant: Color(0xFFB4DAB8),
      accent: Color(0xFF2E7D34),
      accentMuted: Color(0xFF3F9A46),
      textPrimary: Color(0xFF102113),
      textSecondary: Color(0xFF4D6B50),
    ),
  ),
  AppPalette(
    id: 'sunset_coral',
    label: 'Sunset Coral',
    dark: PaletteTone(
      background: Color(0xFF241211),
      surface: Color(0xFF391E1B),
      surfaceVariant: Color(0xFF4B2823),
      accent: Color(0xFFFF7F5C),
      accentMuted: Color(0xFFFFA285),
      textPrimary: Color(0xFFFBEAE5),
      textSecondary: Color(0xFFCBA095),
    ),
    light: PaletteTone(
      background: Color(0xFFF3D2C6),
      surface: Color(0xFFF8E1D8),
      surfaceVariant: Color(0xFFEAB9A5),
      accent: Color(0xFFC4441F),
      accentMuted: Color(0xFFE05A2E),
      textPrimary: Color(0xFF2B1512),
      textSecondary: Color(0xFF6E4137),
    ),
  ),
  AppPalette(
    id: 'rose_quartz',
    label: 'Rose Quartz',
    dark: PaletteTone(
      background: Color(0xFF250E1C),
      surface: Color(0xFF3A162C),
      surfaceVariant: Color(0xFF4C1E3B),
      accent: Color(0xFFF06AA8),
      accentMuted: Color(0xFFF694C0),
      textPrimary: Color(0xFFFAE7F1),
      textSecondary: Color(0xFFCB9AB5),
    ),
    light: PaletteTone(
      background: Color(0xFFF3CFE2),
      surface: Color(0xFFF8DFEC),
      surfaceVariant: Color(0xFFECB6D5),
      accent: Color(0xFFC22E76),
      accentMuted: Color(0xFFDB4590),
      textPrimary: Color(0xFF2B0F22),
      textSecondary: Color(0xFF6E3F58),
    ),
  ),
  AppPalette(
    id: 'midnight_teal',
    label: 'Midnight Teal',
    dark: PaletteTone(
      background: Color(0xFF0B1F1E),
      surface: Color(0xFF123330),
      surfaceVariant: Color(0xFF184441),
      accent: Color(0xFF3FD9C7),
      accentMuted: Color(0xFF74E6D8),
      textPrimary: Color(0xFFE3F7F3),
      textSecondary: Color(0xFF8FBFB8),
    ),
    light: PaletteTone(
      background: Color(0xFFC5E9E4),
      surface: Color(0xFFD7F1EC),
      surfaceVariant: Color(0xFFACDAD2),
      accent: Color(0xFF0D7A6C),
      accentMuted: Color(0xFF14988A),
      textPrimary: Color(0xFF0D2220),
      textSecondary: Color(0xFF3E6862),
    ),
  ),
  AppPalette(
    id: 'royal_plum',
    label: 'Royal Plum',
    dark: PaletteTone(
      background: Color(0xFF1B0F2A),
      surface: Color(0xFF2B1940),
      surfaceVariant: Color(0xFF3A2153),
      accent: Color(0xFFC77DFF),
      accentMuted: Color(0xFFDBA3FF),
      textPrimary: Color(0xFFF0E7FA),
      textSecondary: Color(0xFFB49BCF),
    ),
    light: PaletteTone(
      background: Color(0xFFDBC9F0),
      surface: Color(0xFFE7D9F7),
      surfaceVariant: Color(0xFFC7AAE6),
      accent: Color(0xFF7A2FCC),
      accentMuted: Color(0xFF9647DF),
      textPrimary: Color(0xFF1E1130),
      textSecondary: Color(0xFF564173),
    ),
  ),
  AppPalette(
    id: 'amber_earth',
    label: 'Amber Earth',
    dark: PaletteTone(
      background: Color(0xFF221708),
      surface: Color(0xFF352511),
      surfaceVariant: Color(0xFF463119),
      accent: Color(0xFFF2A83E),
      accentMuted: Color(0xFFF6C36D),
      textPrimary: Color(0xFFF8ECD9),
      textSecondary: Color(0xFFCBAF87),
    ),
    light: PaletteTone(
      background: Color(0xFFEEDBB8),
      surface: Color(0xFFF5E8CF),
      surfaceVariant: Color(0xFFDFC290),
      accent: Color(0xFFAD6A0C),
      accentMuted: Color(0xFFCB8419),
      textPrimary: Color(0xFF261B0C),
      textSecondary: Color(0xFF6B5734),
    ),
  ),
  AppPalette(
    id: 'slate_mono',
    label: 'Slate Mono',
    dark: PaletteTone(
      background: Color(0xFF17191C),
      surface: Color(0xFF24272B),
      surfaceVariant: Color(0xFF31353A),
      accent: Color(0xFF9FB4C7),
      accentMuted: Color(0xFFC0D0DE),
      textPrimary: Color(0xFFECEEF0),
      textSecondary: Color(0xFFA7AFB6),
    ),
    light: PaletteTone(
      background: Color(0xFFD6DADE),
      surface: Color(0xFFE4E7EA),
      surfaceVariant: Color(0xFFC2C8CD),
      accent: Color(0xFF48606F),
      accentMuted: Color(0xFF5F7E8F),
      textPrimary: Color(0xFF1B1E21),
      textSecondary: Color(0xFF515A61),
    ),
  ),
  AppPalette(
    id: 'cherry_blossom',
    label: 'Cherry Blossom',
    dark: PaletteTone(
      background: Color(0xFF260F16),
      surface: Color(0xFF3B1822),
      surfaceVariant: Color(0xFF4E1F2D),
      accent: Color(0xFFFF8FA3),
      accentMuted: Color(0xFFFFB0BE),
      textPrimary: Color(0xFFFCE9EC),
      textSecondary: Color(0xFFCE9CA6),
    ),
    light: PaletteTone(
      background: Color(0xFFF6D2DA),
      surface: Color(0xFFFAE1E6),
      surfaceVariant: Color(0xFFEFB3C0),
      accent: Color(0xFFD1355A),
      accentMuted: Color(0xFFE85476),
      textPrimary: Color(0xFF2C1116),
      textSecondary: Color(0xFF6E4048),
    ),
  ),
];

AppPalette paletteById(String id) => kAppPalettes.firstWhere(
      (p) => p.id == id,
      orElse: () => kAppPalettes.first,
    );