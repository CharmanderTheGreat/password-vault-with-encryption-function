import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../main.dart' show VaultColors;
import '../widgets/responsive_container.dart';

/// Tracks whether the user has accepted the Terms & Conditions. Stored
/// once, checked on every app launch before anything else runs.
class TermsService {
  static const _acceptedKey = 'terms_accepted_v1';

  static Future<bool> isAccepted() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_acceptedKey) ?? false;
  }

  static Future<void> markAccepted() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_acceptedKey, true);
  }
}

class TermsScreen extends StatefulWidget {
  final VoidCallback onAccepted;
  const TermsScreen({super.key, required this.onAccepted});

  @override
  State<TermsScreen> createState() => _TermsScreenState();
}

class _TermsScreenState extends State<TermsScreen> {
  final _scrollController = ScrollController();
  bool _reachedBottom = false;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_checkScroll);
    // In case the content is short enough to not need scrolling at all.
    WidgetsBinding.instance.addPostFrameCallback((_) => _checkScroll());
  }

  void _checkScroll() {
    if (_reachedBottom || !_scrollController.hasClients) return;
    final pos = _scrollController.position;
    if (pos.maxScrollExtent <= 0 ||
        pos.pixels >= pos.maxScrollExtent - 24) {
      setState(() => _reachedBottom = true);
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _accept() async {
    await TermsService.markAccepted();
    widget.onAccepted();
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<VaultColors>()!;

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ResponsiveContainer(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Terms & Conditions',
                    style: Theme.of(context)
                        .textTheme
                        .headlineSmall
                        ?.copyWith(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Please read before using the app.',
                    style: TextStyle(color: colors.textSecondary, fontSize: 13),
                  ),
                  const SizedBox(height: 16),
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: colors.surface,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: colors.surfaceVariant),
                      ),
                      child: Scrollbar(
                        controller: _scrollController,
                        thumbVisibility: true,
                        child: SingleChildScrollView(
                          controller: _scrollController,
                          padding: const EdgeInsets.only(right: 8),
                          child: Text(
                            _termsText,
                            style: TextStyle(
                              color: colors.textPrimary,
                              fontSize: 13,
                              height: 1.6,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  if (!_reachedBottom)
                    Text(
                      'Scroll to the bottom to continue.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: colors.textSecondary, fontSize: 12),
                    ),
                  const SizedBox(height: 8),
                  SizedBox(
                    height: 52,
                    child: ElevatedButton(
                      onPressed: _reachedBottom ? _accept : null,
                      child: const Text('I Agree & Continue'),
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

const _termsText = '''
1. What this app is

Grand Vault is a personal password manager. It was built as a student
project and is provided as-is, without warranty of any kind. It is not a
commercial product and comes with no guarantee of support, updates, or
fitness for any particular purpose.

2. Your data and your Google account

Every entry you save is encrypted on this device before it is stored or
sent anywhere. Your encrypted vault is synced through your Google account
so it stays the same across every device you sign into, using Google's
Firestore service purely as encrypted storage. This app does not run
ads, does not collect analytics, and never has access to your passwords
in readable form, everything is encrypted before it leaves your device.

3. How your vault is protected

Access to your vault on this device is tied to this device's own lock
screen.

IMPORTANT: If this device does NOT have a lock screen set up, the app has
no additional protection layer of its own. The vault will open
immediately whenever the app is opened, with no prompt. Anyone with
access to this device will be able to view your saved passwords. For
meaningful protection, set up a lock screen on this device before storing
sensitive accounts.

4. Losing access

Because your vault is tied to your Google account, signing into that same
account on another device restores your saved passwords. If you lose
access to that Google account entirely, or if the account is deleted,
your vault cannot be recovered, there is no separate password or recovery
code held by this app.

5. Import and export

The CSV import/export feature reads and writes plain, unencrypted text
files (the same format browsers use for password exports). You are
responsible for safely storing or deleting any such file after use, since
it is not protected by this app once it exists on disk.

6. Limitation of liability

The developer of this app is not liable for any loss of data, unauthorized
access to your accounts, or any other damages arising from the use, misuse,
or inability to use this app, including but not limited to device loss,
theft, lack of a device lock screen, loss of Google account access, or
operating system/security failures outside this app's control.

7. Acceptance

By tapping "I Agree & Continue," you confirm that you have read and
understood the above, including the risk described in Section 3 when no
device lock is present, and you accept these terms.
''';
