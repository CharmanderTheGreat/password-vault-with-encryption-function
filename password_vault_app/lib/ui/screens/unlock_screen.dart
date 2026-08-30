import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cryptography/cryptography.dart';
import '../../features/auth/vault_access_service.dart';
import '../../features/auth/google_auth_service.dart';
import '../../core/database/vault_sync_service.dart';
import '../../core/database/sync_queue_service.dart';
import '../../core/session/vault_session.dart';
import '../../main.dart' show VaultColors, EntryRouter;
import '../widgets/responsive_container.dart';
import 'vault_list_screen.dart';

/// No more typed master password. Two possible paths, decided
/// automatically at setup time (see VaultAccessService):
///  - Device has a PIN/pattern/biometric lock -> prompt for it here.
///  - Device has no lock at all -> skip straight through, no prompt.
///
/// `local_auth` (the PIN/biometric plugin) has no Windows/Linux/macOS
/// implementation, so this screen never even asks the question on
/// desktop — it's hard-guarded here in addition to the platform check
/// inside QuickUnlockService, so a stale/leftover stored flag from
/// before that fix can never resurface this prompt again.
bool get _isDesktopPlatform {
  if (kIsWeb) return false;
  return Platform.isWindows || Platform.isLinux || Platform.isMacOS;
}

class UnlockScreen extends StatefulWidget {
  const UnlockScreen({super.key});

  @override
  State<UnlockScreen> createState() => _UnlockScreenState();
}

class _UnlockScreenState extends State<UnlockScreen> {
  bool _checking = true;
  bool _authenticating = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    if (_isDesktopPlatform) {
      // Desktop never supports device PIN/biometric — go straight
      // through, no matter what any stored flag says.
      await _unlockWithoutPrompt();
      return;
    }

    final requiresAuth = await VaultAccessService.requiresDeviceAuth();
    if (!mounted) return;

    if (!requiresAuth) {
      // No device lock was available — the vault opens immediately.
      await _unlockWithoutPrompt();
      return;
    }

    setState(() => _checking = false);
    _handleDeviceUnlock();
  }

  Future<void> _unlockWithoutPrompt() async {
    // VaultAccessService.unlockWithoutPrompt() also covers the case
    // where this device has local salt/verifier but no cached
    // auto-unlock password yet — it fetches the account's existing
    // password from Firestore first, so this can still succeed on a
    // fresh sign-in without prompting for anything here.
    final key = await VaultAccessService.unlockWithoutPrompt();
    if (!mounted) return;

    if (key == null) {
      setState(() {
        _checking = false;
        _error =
            'Could not access the vault. Check your internet connection and try again, or sign out and start over.';
      });
      return;
    }
    await _proceed(key);
  }

  Future<void> _handleDeviceUnlock() async {
    setState(() {
      _authenticating = true;
      _error = null;
    });

    final key = await VaultAccessService.unlockWithDeviceAuth();
    if (!mounted) return;

    if (key == null) {
      setState(() {
        _authenticating = false;
        _error = 'Authentication cancelled or failed.';
      });
      return;
    }
    await _proceed(key);
  }

  Future<void> _proceed(SecretKey key) async {
    // Order matters here: flush any local changes made while this
    // device was offline BEFORE pulling from the cloud. If we pulled
    // first, an older cloud copy could overwrite a newer local edit
    // that hasn't been pushed yet. Flushing first means our own
    // pending changes land in Firestore, so the pull afterward just
    // confirms them back down instead of clobbering them.
    try {
      await SyncQueueService.flushPendingChanges();
    } catch (e) {
      debugPrint('flushPendingChanges failed during unlock: $e');
    }

    // Pull any entries added from OTHER devices before showing the
    // list. Firestore sign-in itself only happens once (the session
    // then persists across app launches), so without this, entries
    // added on another device after the first sign-in here would never
    // show up on this device — only a brand new sign-in used to
    // trigger the cloud pull. Unlocking happens on every app open, so
    // this is the right place for it to run every time instead.
    //
    // Failures here are non-fatal (e.g. offline) — the vault still
    // opens with whatever is already saved locally.
    try {
      await VaultSyncService.pullFromCloud();
    } catch (e, stack) {
      debugPrint('pullFromCloud failed during unlock: $e');
      debugPrint('$stack');
      // Ignore — local data is still usable.
    }

    if (!mounted) return;
    context.read<VaultSession>().unlock(key);
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const VaultListScreen()),
    );
  }

  Future<void> _resetAndSignOut() async {
    // Escape hatch for when local state is inconsistent (e.g. setup was
    // interrupted mid-way by an app restart, leaving a salt/verifier
    // saved locally but no matching auto-unlock password). Runs the
    // same full reset used from Settings, then routes back to sign-in.
    await VaultAccessService.signOutAndResetDevice();
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const EntryRouter()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<VaultColors>()!;

    if (_checking) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

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
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(
                      color: colors.accent.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child:
                        Icon(Icons.fingerprint, color: colors.accent, size: 36),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'Vault Locked',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Use your device\'s lock screen to continue',
                    style: TextStyle(color: colors.textSecondary, fontSize: 14),
                  ),
                  const SizedBox(height: 28),
                  if (_error != null) ...[
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.error_outline,
                            color: colors.danger, size: 18),
                        const SizedBox(width: 6),
                        Flexible(
                          child: Text(_error!,
                              style: TextStyle(
                                  color: colors.danger, fontSize: 13)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),
                  ],
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton.icon(
                      onPressed: _authenticating ? null : _handleDeviceUnlock,
                      icon: _authenticating
                          ? const SizedBox(
                              height: 18,
                              width: 18,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2.5, color: Colors.white),
                            )
                          : const Icon(Icons.fingerprint),
                      label: Text(_authenticating ? 'Waiting...' : 'Unlock'),
                    ),
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton(
                        onPressed: _resetAndSignOut,
                        child: const Text('Sign out and start over'),
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
