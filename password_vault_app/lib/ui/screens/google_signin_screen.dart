import 'package:flutter/material.dart';
import '../../features/auth/google_auth_service.dart';
import '../../main.dart' show VaultColors;
import '../widgets/responsive_container.dart';

class GoogleSignInScreen extends StatefulWidget {
  final VoidCallback onSignedIn;
  const GoogleSignInScreen({super.key, required this.onSignedIn});

  @override
  State<GoogleSignInScreen> createState() => _GoogleSignInScreenState();
}

class _GoogleSignInScreenState extends State<GoogleSignInScreen> {
  bool _signingIn = false;
  String? _error;

  Future<void> _handleSignIn() async {
    setState(() {
      _signingIn = true;
      _error = null;
    });

    try {
      final user = await GoogleAuthService.signIn();
      if (!mounted) return;

      if (user == null) {
        setState(() {
          _signingIn = false;
          _error = 'Sign in was cancelled.';
        });
        return;
      }

      widget.onSignedIn();
    } catch (e, stack) {
      // TEMPORARY: prints the real error to the terminal (VS Code Debug
      // Console) so we can see what's actually failing under the hood.
      // The UI message stays generic on purpose — remove these two
      // debugPrint lines once the real cause is found and fixed.
      debugPrint('Google sign-in failed: $e');
      debugPrint('$stack');
      if (!mounted) return;
      setState(() {
        _signingIn = false;
        _error = 'Sign in failed. Please try again.';
      });
    }
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
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(
                      color: colors.accent.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Icon(Icons.shield_outlined,
                        color: colors.accent, size: 36),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'Sign in to continue',
                    style: Theme.of(context)
                        .textTheme
                        .headlineSmall
                        ?.copyWith(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Your Google account keeps your vault the same across all your devices.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: colors.textSecondary, fontSize: 14),
                  ),
                  const SizedBox(height: 32),
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
                      onPressed: _signingIn ? null : _handleSignIn,
                      icon: _signingIn
                          ? const SizedBox(
                              height: 18,
                              width: 18,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2.5, color: Colors.white),
                            )
                          : const Icon(Icons.login),
                      label: Text(
                          _signingIn ? 'Signing in...' : 'Sign in with Google'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
