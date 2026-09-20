import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:file_picker/file_picker.dart';
import '../../core/utils/app_launcher.dart';
import '../../core/session/vault_session.dart';
import '../../core/models/vault_entry.dart';
import '../../features/auth/quick_unlock_service.dart';
import '../../features/auth/vault_access_service.dart';
import '../../features/import_export/csv_import_service.dart';
import '../../features/import_export/csv_export_service.dart';
import '../../main.dart' show VaultColors, EntryRouter;
import '../widgets/responsive_container.dart';

class SettingsScreen extends StatefulWidget {
  final VoidCallback onDataChanged;

  const SettingsScreen({super.key, required this.onDataChanged});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _quickUnlockSupported = false;
  bool _loadingQuickUnlock = true;

  @override
  void initState() {
    super.initState();
    _loadQuickUnlockStatus();
  }

  Future<void> _loadQuickUnlockStatus() async {
    final supported = await QuickUnlockService.isDeviceSupported();
    if (!mounted) return;
    setState(() {
      _quickUnlockSupported = supported;
      _loadingQuickUnlock = false;
    });
  }

  Future<void> _signOut() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Sign out?'),
        content: const Text(
          'This signs you out of this Google account and clears everything '
          'saved locally on this device. Your accounts stay safe in the '
          'cloud tied to that Google account, sign back in anytime to get '
          'them back. If you sign in with a different account afterward, '
          'that account starts fresh on this device.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Sign out'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    await VaultAccessService.signOutAndResetDevice();

    if (!mounted) return;
    context.read<VaultSession>().lock();

    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const EntryRouter()),
      (route) => false,
    );
  }

  Future<void> _importFromCsv() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['csv'],
      dialogTitle: 'Select browser password export (.csv)',
    );

    if (result == null || result.files.single.path == null) return;

    List<VaultEntry> imported;
    try {
      imported = await CsvImportService.parseFile(result.files.single.path!);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content:
                Text('Import failed: ${e is FormatException ? e.message : e}')),
      );
      return;
    }

    if (imported.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No valid entries found in that file.')),
      );
      return;
    }

    if (!mounted) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Import accounts?'),
        content: Text(
          'Found ${imported.length} account${imported.length > 1 ? 's' : ''} in this file. '
          'They\'ll be added to your vault and encrypted immediately. '
          'Delete the CSV file afterward, it\'s stored as plain text by your browser.',
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Import')),
        ],
      ),
    );

    if (confirmed != true) return;

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Importing ${imported.length} account'
            '${imported.length > 1 ? 's' : ''}...'),
        duration: const Duration(seconds: 30),
      ),
    );

    try {
      final repo = context.read<VaultSession>().repository!;
      for (final entry in imported) {
        await repo.addEntry(entry);
      }

      widget.onDataChanged();

      if (!mounted) return;
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(
                'Imported ${imported.length} account${imported.length > 1 ? 's' : ''}.')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Import failed partway through: $e')),
      );
      // Still refresh the list — some entries may have been saved
      // before the failure, so the screen should reflect that.
      widget.onDataChanged();
    }
  }

  Future<void> _exportToCsv() async {
    final repo = context.read<VaultSession>().repository!;
    final entries = await repo.getAllEntries();

    if (entries.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No accounts to export yet.')),
      );
      return;
    }

    if (!mounted) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Export vault as CSV?'),
        content: Text(
          'This creates a plain-text file with all ${entries.length} of your '
          'saved passwords, unencrypted, same as a browser password export. '
          'Store it somewhere safe and delete it when you\'re done.',
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Continue')),
        ],
      ),
    );

    if (confirmed != true) return;

    final savePath = await FilePicker.platform.saveFile(
      dialogTitle: 'Save vault export',
      fileName: 'vault_export.csv',
      type: FileType.custom,
      allowedExtensions: ['csv'],
    );

    if (savePath == null) return;

    final path =
        savePath.toLowerCase().endsWith('.csv') ? savePath : '$savePath.csv';

    try {
      await CsvExportService.exportToFile(entries, path);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Exported ${entries.length} accounts to $path')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Export failed: $e')),
      );
    }
  }

  Future<void> _openLink(String url) async {
    final uri = Uri.parse(url);
    final launched = await AppLauncher.openUrl(uri.toString());
    if (!launched && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open the link.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<VaultColors>()!;

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ResponsiveContainer(
        maxWidth: 560,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const _SectionHeader('SECURITY'),
            _SettingsCard(
              children: [
                if (_loadingQuickUnlock)
                  const Padding(
                    padding: EdgeInsets.all(16),
                    child: Center(child: CircularProgressIndicator()),
                  )
                else
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(
                      _quickUnlockSupported
                          ? Icons.lock_outline
                          : Icons.lock_open_outlined,
                      color: _quickUnlockSupported
                          ? colors.success
                          : colors.warning,
                    ),
                    title: const Text('Vault protection'),
                    subtitle: Text(
                      _quickUnlockSupported
                          ? 'Protected by this device\'s lock screen'
                          : 'No device lock screen found, vault opens with no prompt',
                      style:
                          TextStyle(color: colors.textSecondary, fontSize: 12),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 24),
            const _SectionHeader('ACCOUNT'),
            _SettingsCard(
              children: [
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(Icons.logout, color: colors.danger),
                  title: const Text('Sign out'),
                  subtitle: Text(
                    'Sign in with a different Google account on this device',
                    style: TextStyle(color: colors.textSecondary, fontSize: 12),
                  ),
                  onTap: _signOut,
                ),
              ],
            ),
            const SizedBox(height: 24),
            const _SectionHeader('DATA'),
            _SettingsCard(
              children: [
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading:
                      Icon(Icons.file_upload_outlined, color: colors.accent),
                  title: const Text('Import from browser'),
                  subtitle: Text('Load a CSV password export',
                      style:
                          TextStyle(color: colors.textSecondary, fontSize: 12)),
                  onTap: _importFromCsv,
                ),
                Divider(color: colors.surfaceVariant, height: 1),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading:
                      Icon(Icons.file_download_outlined, color: colors.accent),
                  title: const Text('Export vault'),
                  subtitle: Text('Save all accounts as a CSV file',
                      style:
                          TextStyle(color: colors.textSecondary, fontSize: 12)),
                  onTap: _exportToCsv,
                ),
              ],
            ),
            const SizedBox(height: 24),
            const _SectionHeader('ABOUT'),
            _SettingsCard(
              children: [
                _AboutExpander(colors: colors),
              ],
            ),
            const SizedBox(height: 24),
            const _SectionHeader('CREDITS'),
            _SettingsCard(
              children: [
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(Icons.email_outlined, color: colors.accent),
                  title: const Text('Email'),
                  subtitle: Text('albertlawrence.robinol@gmail.com',
                      style:
                          TextStyle(color: colors.textSecondary, fontSize: 12)),
                  onTap: () =>
                      _openLink('mailto:albertlawrence.robinol@gmail.com'),
                ),
                Divider(color: colors.surfaceVariant, height: 1),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(Icons.code, color: colors.accent),
                  title: const Text('GitHub'),
                  subtitle: Text('CharmanderTheGreat',
                      style:
                          TextStyle(color: colors.textSecondary, fontSize: 12)),
                  onTap: () =>
                      _openLink('https://github.com/CharmanderTheGreat'),
                ),
                Divider(color: colors.surfaceVariant, height: 1),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(Icons.facebook, color: colors.accent),
                  title: const Text('Facebook'),
                  subtitle: Text('albertlawrence.robinol',
                      style:
                          TextStyle(color: colors.textSecondary, fontSize: 12)),
                  onTap: () => _openLink(
                      'https://www.facebook.com/albertlawrence.robinol'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String text;
  const _SectionHeader(this.text);

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<VaultColors>()!;
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8),
      child: Text(
        text,
        style: TextStyle(
          color: colors.textSecondary,
          fontSize: 12,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.8,
        ),
      ),
    );
  }
}

class _AboutExpander extends StatefulWidget {
  final VaultColors colors;
  const _AboutExpander({required this.colors});

  @override
  State<_AboutExpander> createState() => _AboutExpanderState();
}

class _AboutExpanderState extends State<_AboutExpander> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final colors = widget.colors;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Password Vault'),
          subtitle: Text(
            'Offline, encrypted, AES-256-GCM',
            style: TextStyle(color: colors.textSecondary, fontSize: 12),
          ),
          trailing: Icon(
            _expanded ? Icons.expand_less : Icons.expand_more,
            color: colors.textSecondary,
          ),
          onTap: () => setState(() => _expanded = !_expanded),
        ),
        if (_expanded)
          Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: Text(
              _detailedAbout,
              style: TextStyle(
                color: colors.textSecondary,
                fontSize: 12.5,
                height: 1.6,
              ),
            ),
          ),
      ],
    );
  }
}

const _detailedAbout = '''
Every entry (username, password, notes) is encrypted with AES-256-GCM before it ever touches storage, on this device and in the cloud, so even the raw data is unreadable without the right key.

There's no password to create or type. Your vault is tied to your Google account, so signing into the same account on another device brings back the same saved accounts automatically.

On this device, access is tied to this device's own lock screen. Unlocking your device is what unlocks the vault.

If this device has no lock screen set up, the vault opens with no prompt at all, since there's nothing on the device itself to gate on.

Because your vault is tied to your Google account rather than a separate password, losing access to that Google account means losing access to the vault, there is no separate recovery method.
''';

class _SettingsCard extends StatelessWidget {
  final List<Widget> children;
  const _SettingsCard({required this.children});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<VaultColors>()!;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: colors.surfaceVariant),
      ),
      child: Column(children: children),
    );
  }
}
