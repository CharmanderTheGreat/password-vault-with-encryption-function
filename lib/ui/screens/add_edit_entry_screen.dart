import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show Clipboard, ClipboardData;
import 'package:provider/provider.dart';
import '../../core/models/vault_entry.dart';
import '../../core/session/vault_session.dart';
import '../../features/generator/password_generator.dart';
import '../../features/strength_checker/strength_calculator.dart';
import '../../main.dart' show VaultColors;
import '../widgets/responsive_container.dart';

class AddEditEntryScreen extends StatefulWidget {
  final VaultEntry? entry; // null = adding a new entry

  const AddEditEntryScreen({super.key, this.entry});

  @override
  State<AddEditEntryScreen> createState() => _AddEditEntryScreenState();
}

class _AddEditEntryScreenState extends State<AddEditEntryScreen> {
  late final TextEditingController _labelController;
  late final TextEditingController _urlController;
  late final TextEditingController _usernameController;
  late final TextEditingController _passwordController;
  late final TextEditingController _notesController;

  bool _obscurePassword = true;
  bool _saving = false;

  bool get _isEditing => widget.entry != null;

  @override
  void initState() {
    super.initState();
    final e = widget.entry;
    _labelController = TextEditingController(text: e?.label ?? '');
    _urlController = TextEditingController(text: e?.url ?? '');
    _usernameController = TextEditingController(text: e?.username ?? '');
    _passwordController = TextEditingController(text: e?.password ?? '');
    _notesController = TextEditingController(text: e?.notes ?? '');
  }

  void _generatePassword() {
    final generated = PasswordGenerator.generate(
      const PasswordGeneratorOptions(length: 20),
    );
    setState(() {
      _passwordController.text = generated;
      _obscurePassword = false;
    });
  }

  void _copyPassword() {
    if (_passwordController.text.isEmpty) return;
    Clipboard.setData(ClipboardData(text: _passwordController.text));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Password copied to clipboard.')),
    );
  }

  Future<void> _save() async {
    if (_labelController.text.trim().isEmpty ||
        _usernameController.text.trim().isEmpty ||
        _passwordController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Label, username, and password are required.')),
      );
      return;
    }

    setState(() => _saving = true);
    final repo = context.read<VaultSession>().repository!;

    if (_isEditing) {
      final updated = widget.entry!.copyWith(
        label: _labelController.text.trim(),
        url: _urlController.text.trim().isEmpty
            ? null
            : _urlController.text.trim(),
        username: _usernameController.text.trim(),
        password: _passwordController.text,
        notes: _notesController.text.trim().isEmpty
            ? null
            : _notesController.text.trim(),
      );
      await repo.updateEntry(updated);
    } else {
      final newEntry = VaultEntry(
        label: _labelController.text.trim(),
        url: _urlController.text.trim().isEmpty
            ? null
            : _urlController.text.trim(),
        username: _usernameController.text.trim(),
        password: _passwordController.text,
        notes: _notesController.text.trim().isEmpty
            ? null
            : _notesController.text.trim(),
      );
      await repo.addEntry(newEntry);
    }

    if (!mounted) return;
    Navigator.of(context).pop();
  }

  Future<void> _delete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete this account?'),
        content: Text(
            'This will permanently delete the entry for "${widget.entry!.label}".'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Delete')),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      final repo = context.read<VaultSession>().repository!;
      await repo.deleteEntry(widget.entry!.id!);
      if (mounted) Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<VaultColors>()!;
    final strength = StrengthCalculator.calculate(_passwordController.text);

    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? 'Edit Account' : 'New Account'),
        actions: [
          if (_isEditing)
            IconButton(
              icon: Icon(Icons.delete_outline, color: colors.danger),
              onPressed: _delete,
            ),
        ],
      ),
      body: ResponsiveContainer(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const _SectionLabel('ACCOUNT INFO'),
            const SizedBox(height: 8),
            TextField(
              controller: _labelController,
              decoration: const InputDecoration(
                labelText: 'App / Website Name',
                hintText: 'e.g. Facebook, GCash, GitHub',
                prefixIcon: Icon(Icons.apps, size: 20),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _urlController,
              decoration: const InputDecoration(
                labelText: 'URL (optional)',
                hintText: 'e.g. https://facebook.com',
                prefixIcon: Icon(Icons.link, size: 20),
              ),
            ),
            const SizedBox(height: 24),
            const _SectionLabel('CREDENTIALS'),
            const SizedBox(height: 8),
            TextField(
              controller: _usernameController,
              decoration: const InputDecoration(
                labelText: 'Username / Email',
                prefixIcon: Icon(Icons.person_outline, size: 20),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _passwordController,
              obscureText: _obscurePassword,
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                labelText: 'Password',
                prefixIcon: const Icon(Icons.key_outlined, size: 20),
                suffixIcon: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.copy_outlined, size: 20),
                      tooltip: 'Copy password',
                      onPressed: _copyPassword,
                    ),
                    IconButton(
                      icon: Icon(_obscurePassword
                          ? Icons.visibility_outlined
                          : Icons.visibility_off_outlined),
                      tooltip: _obscurePassword ? 'Show' : 'Hide',
                      onPressed: () =>
                          setState(() => _obscurePassword = !_obscurePassword),
                    ),
                  ],
                ),
              ),
            ),
            if (_passwordController.text.isNotEmpty) ...[
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.only(left: 4),
                child: Text(
                  '${strength.label} · ~${strength.entropyBits.toStringAsFixed(0)} bits',
                  style: TextStyle(fontSize: 12, color: colors.textSecondary),
                ),
              ),
            ],
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: _generatePassword,
              icon: Icon(Icons.casino_outlined, size: 18, color: colors.accent),
              label: Text('Generate Strong Password',
                  style: TextStyle(color: colors.accent)),
            ),
            const SizedBox(height: 24),
            const _SectionLabel('NOTES'),
            const SizedBox(height: 8),
            TextField(
              controller: _notesController,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Notes (optional)',
                alignLabelWithHint: true,
              ),
            ),
            const SizedBox(height: 28),
            SizedBox(
              height: 52,
              child: ElevatedButton(
                onPressed: _saving ? null : _save,
                child: _saving
                    ? const SizedBox(
                        height: 22,
                        width: 22,
                        child: CircularProgressIndicator(
                            strokeWidth: 2.5, color: Colors.white),
                      )
                    : Text(_isEditing ? 'Save Changes' : 'Save to Vault'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<VaultColors>()!;
    return Text(
      text,
      style: TextStyle(
        color: colors.textSecondary,
        fontSize: 12,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.8,
      ),
    );
  }
}
