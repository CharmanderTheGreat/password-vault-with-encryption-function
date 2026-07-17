import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../features/auth/master_password_service.dart';
import '../../features/strength_checker/strength_calculator.dart';
import '../../core/session/vault_session.dart';
import 'vault_list_screen.dart';

class SetupScreen extends StatefulWidget {
  const SetupScreen({super.key});

  @override
  State<SetupScreen> createState() => _SetupScreenState();
}

class _SetupScreenState extends State<SetupScreen> {
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();
  String? _error;
  bool _loading = false;

  PasswordStrengthResult get _strength =>
      StrengthCalculator.calculate(_passwordController.text);

  Future<void> _handleSetup() async {
    if (_passwordController.text.length < 8) {
      setState(() => _error = 'Dapat 8+ characters ang master password mo.');
      return;
    }
    if (_passwordController.text != _confirmController.text) {
      setState(() => _error = 'Hindi magkatugma ang dalawang password.');
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    final key = await MasterPasswordService.setupMasterPassword(
      _passwordController.text,
    );

    if (!mounted) return;
    context.read<VaultSession>().unlock(key);

    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const VaultListScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final strength = _strength;

    return Scaffold(
      appBar: AppBar(title: const Text('Gawa ng Master Password')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Ito ang isang password na tatandaan mo — ito lang '
              'ang susi para ma-unlock ang buong vault mo. Walang '
              '"forgot password" dito kasi offline at hindi namin ito '
              'nakikita o naka-store kahit saan.',
              style: TextStyle(fontSize: 14, color: Colors.black87),
            ),
            const SizedBox(height: 24),
            TextField(
              controller: _passwordController,
              obscureText: true,
              onChanged: (_) => setState(() {}),
              decoration: const InputDecoration(
                labelText: 'Master Password',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 8),
            if (_passwordController.text.isNotEmpty)
              _StrengthBar(strength: strength),
            const SizedBox(height: 16),
            TextField(
              controller: _confirmController,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: 'Ulitin ang Master Password',
                border: OutlineInputBorder(),
              ),
            ),
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(_error!, style: const TextStyle(color: Colors.red)),
            ],
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _loading ? null : _handleSetup,
              child: _loading
                  ? const CircularProgressIndicator()
                  : const Text('Gawin ang Vault'),
            ),
          ],
        ),
      ),
    );
  }
}

class _StrengthBar extends StatelessWidget {
  final PasswordStrengthResult strength;
  const _StrengthBar({required this.strength});

  Color get _color {
    switch (strength.level) {
      case StrengthLevel.veryWeak:
        return Colors.red;
      case StrengthLevel.weak:
        return Colors.orange;
      case StrengthLevel.fair:
        return Colors.amber;
      case StrengthLevel.strong:
        return Colors.lightGreen;
      case StrengthLevel.veryStrong:
        return Colors.green;
    }
  }

  double get _fraction {
    switch (strength.level) {
      case StrengthLevel.veryWeak:
        return 0.2;
      case StrengthLevel.weak:
        return 0.4;
      case StrengthLevel.fair:
        return 0.6;
      case StrengthLevel.strong:
        return 0.8;
      case StrengthLevel.veryStrong:
        return 1.0;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: _fraction,
            color: _color,
            backgroundColor: Colors.grey.shade300,
            minHeight: 8,
          ),
        ),
        const SizedBox(height: 4),
        Text(strength.label, style: TextStyle(color: _color, fontSize: 12)),
      ],
    );
  }
}
