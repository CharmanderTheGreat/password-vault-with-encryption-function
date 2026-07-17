import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/models/vault_entry.dart';
import '../../core/session/vault_session.dart';
import '../../features/generator/password_generator.dart';
import '../../features/strength_checker/strength_calculator.dart';

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

  Future<void> _save() async {
    if (_labelController.text.trim().isEmpty ||
        _usernameController.text.trim().isEmpty ||
        _passwordController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Kailangan ng label, username, at password.')),
      );
      return;
    }

    setState(() => _saving = true);
    final repo = context.read<VaultSession>().repository!;

    if (_isEditing) {
      final updated = widget.entry!.copyWith(
        label: _labelController.text.trim(),
        url: _urlController.text.trim().isEmpty ? null : _urlController.text.trim(),
        username: _usernameController.text.trim(),
        password: _passwordController.text,
        notes: _notesController.text.trim().isEmpty ? null : _notesController.text.trim(),
      );
      await repo.updateEntry(updated);
    } else {
      final newEntry = VaultEntry(
        label: _labelController.text.trim(),
        url: _urlController.text.trim().isEmpty ? null : _urlController.text.trim(),
        username: _usernameController.text.trim(),
        password: _passwordController.text,
        notes: _notesController.text.trim().isEmpty ? null : _notesController.text.trim(),
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
        title: const Text('Burahin ang account na ito?'),
        content: Text('Permanenteng mabubura ang entry para sa "${widget.entry!.label}".'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Burahin')),
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
    final strength = StrengthCalculator.calculate(_passwordController.text);

    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? 'I-edit ang Account' : 'Bagong Account'),
        actions: [
          if (_isEditing)
            IconButton(icon: const Icon(Icons.delete_outline), onPressed: _delete),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(
            controller: _labelController,
            decoration: const InputDecoration(
              labelText: 'Pangalan ng App/Website',
              hintText: 'hal. Facebook, GCash, GitHub',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _urlController,
            decoration: const InputDecoration(
              labelText: 'URL (optional)',
              hintText: 'hal. https://facebook.com',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _usernameController,
            decoration: const InputDecoration(
              labelText: 'Username / Email',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _passwordController,
            obscureText: _obscurePassword,
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              labelText: 'Password',
              border: const OutlineInputBorder(),
              suffixIcon: IconButton(
                icon: Icon(_obscurePassword ? Icons.visibility : Icons.visibility_off),
                onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
              ),
            ),
          ),
          const SizedBox(height: 8),
          if (_passwordController.text.isNotEmpty)
            Text(
              '${strength.label} (~${strength.entropyBits.toStringAsFixed(0)} bits)',
              style: const TextStyle(fontSize: 12),
            ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: _generatePassword,
            icon: const Icon(Icons.casino),
            label: const Text('Gumawa ng Random Strong Password'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _notesController,
            maxLines: 3,
            decoration: const InputDecoration(
              labelText: 'Notes (optional)',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: _saving ? null : _save,
            child: _saving
                ? const CircularProgressIndicator()
                : Text(_isEditing ? 'I-save ang Changes' : 'I-save sa Vault'),
          ),
        ],
      ),
    );
  }
}
