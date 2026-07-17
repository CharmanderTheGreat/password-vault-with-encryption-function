import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'core/session/vault_session.dart';
import 'features/auth/master_password_service.dart';
import 'ui/screens/setup_screen.dart';
import 'ui/screens/unlock_screen.dart';

void main() {
  runApp(
    ChangeNotifierProvider(
      create: (_) => VaultSession(),
      child: const PasswordVaultApp(),
    ),
  );
}

class PasswordVaultApp extends StatelessWidget {
  const PasswordVaultApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Password Vault',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorSchemeSeed: Colors.indigo,
        useMaterial3: true,
      ),
      // Wrap everything so any tap/interaction resets the auto-lock timer.
      builder: (context, child) => _AutoLockListener(child: child!),
      home: const _EntryRouter(),
    );
  }
}

/// Decides whether to show the first-time setup screen or the unlock
/// screen, based on whether a master password has already been created.
class _EntryRouter extends StatefulWidget {
  const _EntryRouter();

  @override
  State<_EntryRouter> createState() => _EntryRouterState();
}

class _EntryRouterState extends State<_EntryRouter> {
  bool? _initialized;

  @override
  void initState() {
    super.initState();
    MasterPasswordService.isVaultInitialized().then((value) {
      if (mounted) setState(() => _initialized = value);
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_initialized == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    return _initialized! ? const UnlockScreen() : const SetupScreen();
  }
}

/// Listens for any user interaction and resets the auto-lock timer.
/// Also periodically checks whether the vault should be auto-locked
/// due to inactivity (default: 3 minutes — see VaultSession.autoLockAfter).
class _AutoLockListener extends StatefulWidget {
  final Widget child;
  const _AutoLockListener({required this.child});

  @override
  State<_AutoLockListener> createState() => _AutoLockListenerState();
}

class _AutoLockListenerState extends State<_AutoLockListener> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // When the app comes back to the foreground, check whether enough
    // time has passed to force a re-lock (e.g. user alt-tabbed away or
    // the phone screen was off for a while).
    if (state == AppLifecycleState.resumed) {
      final session = context.read<VaultSession>();
      if (session.isUnlocked && session.shouldAutoLock) {
        session.lock();
        Navigator.of(context, rootNavigator: true).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const UnlockScreen()),
          (route) => false,
        );
      }
    } else if (state == AppLifecycleState.paused) {
      // Stamp the time we went to background so the resumed check above
      // measures real elapsed away-time.
      context.read<VaultSession>().recordActivity();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      onPointerDown: (_) => context.read<VaultSession>().recordActivity(),
      behavior: HitTestBehavior.translucent,
      child: widget.child,
    );
  }
}
