import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../features/auth/master_password_service.dart';
import '../../core/session/vault_session.dart';
import 'vault_list_screen.dart';

class UnlockScreen extends StatefulWidget {
  const UnlockScreen({super.key});

  @override
  State<UnlockScreen> createState() => _UnlockScreenState();
}

class _UnlockScreenState extends State<UnlockScreen> {
  final _passwordController = TextEditingController();
  String? _error;
  bool _loading = false;

  Future<void> _handleUnlock() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    final key = await MasterPasswordService.unlock(_passwordController.text);

    if (!mounted) return;

    if (key == null) {
      setState(() {
        _loading = false;
        _error = 'Maling master password. Subukan ulit.';
      });
      return;
    }

    context.read<VaultSession>().unlock(key);
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const VaultListScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.lock, size: 64),
              const SizedBox(height: 16),
              const Text('Vault Locked', style: TextStyle(fontSize: 20)),
              const SizedBox(height: 24),
              TextField(
                controller: _passwordController,
                obscureText: true,
                onSubmitted: (_) => _handleUnlock(),
                decoration: const InputDecoration(
                  labelText: 'Master Password',
                  border: OutlineInputBorder(),
                ),
              ),
              if (_error != null) ...[
                const SizedBox(height: 12),
                Text(_error!, style: const TextStyle(color: Colors.red)),
              ],
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _loading ? null : _handleUnlock,
                  child: _loading
                      ? const CircularProgressIndicator()
                      : const Text('I-unlock'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
