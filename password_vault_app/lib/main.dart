import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'core/session/vault_session.dart';
import 'core/theme/theme_controller.dart';
import 'features/auth/master_password_service.dart';
import 'features/auth/google_auth_service.dart';
import 'ui/screens/google_signin_screen.dart';
import 'ui/screens/setup_screen.dart';
import 'ui/screens/terms_screen.dart';
import 'ui/screens/unlock_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => VaultSession()),
        ChangeNotifierProvider(create: (_) => ThemeController()),
      ],
      child: const PasswordVaultApp(),
    ),
  );
}

class PasswordVaultApp extends StatelessWidget {
  const PasswordVaultApp({super.key});

  @override
  Widget build(BuildContext context) {
    final themeController = context.watch<ThemeController>();
    final currentTheme = _buildTheme(
        themeController.isDark ? Brightness.dark : Brightness.light);

    return MaterialApp(
      title: 'Vault',
      debugShowCheckedModeBanner: false,
      theme: currentTheme,
      builder: (context, child) => AnimatedTheme(
        data: currentTheme,
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeInOut,
        child: child!,
      ),
      home: const EntryRouter(),
    );
  }

  ThemeData _buildTheme(Brightness brightness) {
    final isDark = brightness == Brightness.dark;

    // Matched to the app icon: deep navy-purple background with a
    // gold/amber accent ring. Light mode keeps the same hue family
    // (lavender-tinted neutrals, gold accent) just lightened and
    // rebalanced for contrast on a bright background.
    final background =
        isDark ? const Color(0xFF16112A) : const Color(0xFFD6C2EC);
    final surface = isDark ? const Color(0xFF221A3B) : const Color(0xFFE3D3F5);
    final surfaceVariant =
        isDark ? const Color(0xFF2D2350) : const Color(0xFFC7AEE3);

    final accent = isDark ? const Color(0xFFD9AD6B) : const Color(0xFF8A5D26);
    final accentMuted =
        isDark ? const Color(0xFFE8C68F) : const Color(0xFFA1732F);

    final textPrimary =
        isDark ? const Color(0xFFEDE9F5) : const Color(0xFF201431);
    final textSecondary =
        isDark ? const Color(0xFFA79BC4) : const Color(0xFF52406E);
    final danger = isDark ? const Color(0xFFEF4444) : const Color(0xFFDC2626);
    final warning = isDark ? const Color(0xFFF59E0B) : const Color(0xFFD97706);
    final success = isDark ? const Color(0xFF22C55E) : const Color(0xFF16A34A);

    final colorScheme = isDark
        ? ColorScheme.dark(
            primary: accent,
            secondary: accentMuted,
            surface: surface,
            error: danger,
            onPrimary: const Color(0xFF16112A),
            onSurface: textPrimary,
          )
        : ColorScheme.light(
            primary: accent,
            secondary: accentMuted,
            surface: surface,
            error: danger,
            onPrimary: Colors.white,
            onSurface: textPrimary,
          );

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: background,
      textTheme: GoogleFonts.interTextTheme(
        isDark ? ThemeData.dark().textTheme : ThemeData.light().textTheme,
      )
          .copyWith(
            bodyLarge: GoogleFonts.inter(fontSize: 17, color: textPrimary),
            bodyMedium: GoogleFonts.inter(fontSize: 15, color: textPrimary),
            bodySmall: GoogleFonts.inter(fontSize: 13, color: textSecondary),
            titleLarge: GoogleFonts.inter(
                fontSize: 22, fontWeight: FontWeight.w700, color: textPrimary),
            titleMedium: GoogleFonts.inter(
                fontSize: 17, fontWeight: FontWeight.w600, color: textPrimary),
            titleSmall: GoogleFonts.inter(
                fontSize: 15, fontWeight: FontWeight.w600, color: textPrimary),
            labelLarge: GoogleFonts.inter(fontSize: 15, color: textPrimary),
          )
          .apply(
            bodyColor: textPrimary,
            displayColor: textPrimary,
          ),
      appBarTheme: AppBarTheme(
        backgroundColor: background,
        foregroundColor: textPrimary,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: GoogleFonts.inter(
          color: textPrimary,
          fontSize: 22,
          fontWeight: FontWeight.w700,
        ),
      ),
      cardTheme: CardThemeData(
        color: surface,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: BorderSide(color: surfaceVariant, width: 1),
        ),
      ),
      listTileTheme: ListTileThemeData(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surfaceVariant,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: accent, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: danger, width: 1.5),
        ),
        labelStyle: TextStyle(color: textSecondary),
        hintStyle: TextStyle(color: textSecondary),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: accent,
          foregroundColor: isDark ? const Color(0xFF16112A) : Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle:
              GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w600),
          elevation: 0,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: textPrimary,
          side: BorderSide(color: surfaceVariant, width: 1.2),
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(foregroundColor: accentMuted),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: accent,
        foregroundColor: isDark ? const Color(0xFF16112A) : Colors.white,
        elevation: 2,
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: surfaceVariant,
        contentTextStyle: TextStyle(color: textPrimary),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        behavior: SnackBarBehavior.floating,
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        titleTextStyle: GoogleFonts.inter(
          color: textPrimary,
          fontSize: 20,
          fontWeight: FontWeight.w700,
        ),
        contentTextStyle: GoogleFonts.inter(color: textSecondary, fontSize: 15),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: accent,
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected) ? accent : null,
        ),
        trackColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? accent.withValues(alpha: 0.4)
              : null,
        ),
      ),
      extensions: [
        VaultColors(
          background: background,
          surface: surface,
          surfaceVariant: surfaceVariant,
          textPrimary: textPrimary,
          textSecondary: textSecondary,
          accent: accent,
          danger: danger,
          warning: warning,
          success: success,
        ),
      ],
    );
  }
}

class VaultColors extends ThemeExtension<VaultColors> {
  final Color background;
  final Color surface;
  final Color surfaceVariant;
  final Color textPrimary;
  final Color textSecondary;
  final Color accent;
  final Color danger;
  final Color warning;
  final Color success;

  const VaultColors({
    required this.background,
    required this.surface,
    required this.surfaceVariant,
    required this.textPrimary,
    required this.textSecondary,
    required this.accent,
    required this.danger,
    required this.warning,
    required this.success,
  });

  @override
  VaultColors copyWith() => this;

  @override
  VaultColors lerp(ThemeExtension<VaultColors>? other, double t) {
    if (other is! VaultColors) return this;
    return VaultColors(
      background: Color.lerp(background, other.background, t)!,
      surface: Color.lerp(surface, other.surface, t)!,
      surfaceVariant: Color.lerp(surfaceVariant, other.surfaceVariant, t)!,
      textPrimary: Color.lerp(textPrimary, other.textPrimary, t)!,
      textSecondary: Color.lerp(textSecondary, other.textSecondary, t)!,
      accent: Color.lerp(accent, other.accent, t)!,
      danger: Color.lerp(danger, other.danger, t)!,
      warning: Color.lerp(warning, other.warning, t)!,
      success: Color.lerp(success, other.success, t)!,
    );
  }
}

class EntryRouter extends StatefulWidget {
  const EntryRouter();

  @override
  State<EntryRouter> createState() => EntryRouterState();
}

class EntryRouterState extends State<EntryRouter> {
  bool? _termsAccepted;
  bool? _signedIn;
  bool? _initialized;

  @override
  void initState() {
    super.initState();
    _loadState();
  }

  String? _loadError;

  Future<void> _loadState() async {
    final termsAccepted = await TermsService.isAccepted();
    final signedIn = GoogleAuthService.currentUser != null;

    bool initialized;
    try {
      if (signedIn) {
        // If this device doesn't have a local salt/verifier yet, check
        // whether this account already set one up on another device
        // BEFORE deciding whether to show SetupScreen. Without this, a
        // returning user on a new/reinstalled device would silently get
        // a brand new encryption key that can't decrypt their synced
        // entries from Firestore.
        final alreadyLocal = await MasterPasswordService.isVaultInitialized();
        if (!alreadyLocal) {
          await MasterPasswordService.pullFromCloud();
        }
      }
      initialized = await MasterPasswordService.isVaultInitialized();
    } catch (e) {
      // A failed Firestore read (offline, permission error on a brand
      // new account doc, etc.) must never leave the UI stuck on the
      // loading spinner forever — fall through to SetupScreen/UnlockScreen
      // using whatever local state already exists, and surface the error
      // so the user isn't left guessing why nothing happened.
      initialized = await MasterPasswordService.isVaultInitialized();
      if (mounted) {
        setState(() => _loadError =
            'Could not reach the cloud (${e.runtimeType}). Continuing with local data.');
      }
    }

    if (!mounted) return;
    setState(() {
      _termsAccepted = termsAccepted;
      _signedIn = signedIn;
      _initialized = initialized;
    });
  }

  void _onTermsAccepted() {
    setState(() => _termsAccepted = true);
  }

  void _onSignedIn() {
    // Re-run the full load, not just flip a flag — signing in is exactly
    // when we need to check the cloud for an existing salt/verifier.
    setState(() {
      _termsAccepted = _termsAccepted;
      _signedIn = null;
      _initialized = null;
    });
    _loadState();
  }

  @override
  Widget build(BuildContext context) {
    if (_termsAccepted == null || _signedIn == null || _initialized == null) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(),
              if (_loadError != null) ...[
                const SizedBox(height: 16),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 32),
                  child: Text(
                    _loadError!,
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 12),
                  ),
                ),
              ],
            ],
          ),
        ),
      );
    }
    if (!_termsAccepted!) {
      return TermsScreen(onAccepted: _onTermsAccepted);
    }
    if (!_signedIn!) {
      return GoogleSignInScreen(onSignedIn: _onSignedIn);
    }
    return _initialized! ? const UnlockScreen() : const SetupScreen();
  }
}
