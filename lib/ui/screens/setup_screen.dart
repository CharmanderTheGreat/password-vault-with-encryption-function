import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../features/auth/vault_access_service.dart';
import '../../features/auth/google_auth_service.dart';
import '../../core/session/vault_session.dart';
import '../../main.dart' show VaultColors;
import '../widgets/responsive_container.dart';
import 'vault_list_screen.dart';

/// First-run setup. No master password is typed here anymore — a strong
/// key is generated automatically behind the scenes and, when possible,
/// gated behind the device's own PIN/biometric lock instead.
/// See VaultAccessService for how this works.
class SetupScreen extends StatefulWidget {
  const SetupScreen({super.key});

  @override
  State<SetupScreen> createState() => _SetupScreenState();
}

class _SetupScreenState extends State<SetupScreen> {
  String _status = 'Preparing your vault...';
  String? _error;
  bool _retrying = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _runSetup());
  }

  Future<void> _runSetup() async {
    setState(() {
      _error = null;
      _retrying = false;
    });

    try {
      final deviceHasLock = await VaultAccessService.deviceHasLock();
      if (mounted) {
        setState(() {
          _status = deviceHasLock
              ? 'Linking your vault to your device lock...'
              : 'Preparing your vault...';
        });
      }

      final key = await VaultAccessService.setupAutomatically();

      if (!mounted) return;
      context.read<VaultSession>().unlock(key);
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const VaultListScreen()),
      );
    } catch (e) {
      // A failed setup (Firestore permission error, no internet on the
      // very first device, etc.) must never leave the user stuck on a
      // spinner with no way out — show what happened and let them retry
      // or back out to sign in with a different account.
      if (!mounted) return;
      setState(() {
        _error = _friendlyError(e);
      });
    }
  }

  String _friendlyError(Object e) {
    final text = e.toString();
    if (text.contains('permission-denied')) {
      return 'Could not set up your vault: the cloud database refused '
          'the request (permission denied). This usually means the '
          'Firestore security rules need to be checked.';
    }
    if (text.contains('unavailable') || text.contains('network')) {
      return 'Could not reach the cloud. Check your internet connection '
          'and try again.';
    }
    return 'Something went wrong while setting up your vault: $text';
  }

  Future<void> _signOut() async {
    await GoogleAuthService.signOut();
    if (!mounted) return;
    Navigator.of(context).popUntil((route) => route.isFirst);
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<VaultColors>()!;

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ResponsiveContainer(
            child: Padding(
              padding: const EdgeInsets.all(28),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 64,
                    height: 64,
                    decoration: BoxDecoration(
                      color: colors.accent.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Icon(Icons.shield_outlined,
                        color: colors.accent, size: 32),
                  ),
                  const SizedBox(height: 24),
                  if (_error == null) ...[
                    const CircularProgressIndicator(),
                    const SizedBox(height: 20),
                    Text(
                      _status,
                      textAlign: TextAlign.center,
                      style:
                          TextStyle(color: colors.textSecondary, fontSize: 14),
                    ),
                  ] else ...[
                    Icon(Icons.error_outline, color: colors.danger, size: 32),
                    const SizedBox(height: 16),
                    Text(
                      _error!,
                      textAlign: TextAlign.center,
                      style:
                          TextStyle(color: colors.textSecondary, fontSize: 14),
                    ),
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _retrying
                            ? null
                            : () {
                                setState(() => _retrying = true);
                                _runSetup();
                              },
                        child: const Text('Try again'),
                      ),
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton(
                        onPressed: _signOut,
                        child: const Text('Sign out'),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
