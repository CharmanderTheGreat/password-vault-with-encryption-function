import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/models/vault_entry.dart';
import '../../core/session/vault_session.dart';
import 'add_edit_entry_screen.dart';
import 'unlock_screen.dart';

class VaultListScreen extends StatefulWidget {
  const VaultListScreen({super.key});

  @override
  State<VaultListScreen> createState() => _VaultListScreenState();
}

class _VaultListScreenState extends State<VaultListScreen> {
  List<VaultEntry> _entries = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadEntries();
  }

  Future<void> _loadEntries() async {
    setState(() => _loading = true);
    final repo = context.read<VaultSession>().repository!;
    final entries = await repo.getAllEntries();
    if (!mounted) return;
    setState(() {
      _entries = entries;
      _loading = false;
    });
  }

  void _lockVault() {
    context.read<VaultSession>().lock();
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const UnlockScreen()),
      (route) => false,
    );
  }

  int get _dueForRotationCount =>
      _entries.where((e) => e.isPasswordDueForRotation).length;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Aking Vault'),
        actions: [
          IconButton(
            icon: const Icon(Icons.lock_outline),
            tooltip: 'I-lock ang vault',
            onPressed: _lockVault,
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadEntries,
              child: Column(
                children: [
                  if (_dueForRotationCount > 0) _RotationBanner(count: _dueForRotationCount),
                  Expanded(
                    child: _entries.isEmpty
                        ? const Center(
                            child: Text('Wala pang naka-save na account. Mag-dagdag ka!'),
                          )
                        : ListView.builder(
                            itemCount: _entries.length,
                            itemBuilder: (context, index) {
                              final entry = _entries[index];
                              return ListTile(
                                leading: CircleAvatar(
                                  child: Text(entry.label.isNotEmpty ? entry.label[0].toUpperCase() : '?'),
                                ),
                                title: Text(entry.label),
                                subtitle: Text(entry.username),
                                trailing: entry.isPasswordDueForRotation
                                    ? const Icon(Icons.warning_amber, color: Colors.orange)
                                    : null,
                                onTap: () async {
                                  await Navigator.of(context).push(
                                    MaterialPageRoute(
                                      builder: (_) => AddEditEntryScreen(entry: entry),
                                    ),
                                  );
                                  _loadEntries();
                                },
                              );
                            },
                          ),
                  ),
                ],
              ),
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          await Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const AddEditEntryScreen()),
          );
          _loadEntries();
        },
        child: const Icon(Icons.add),
      ),
    );
  }
}

class _RotationBanner extends StatelessWidget {
  final int count;
  const _RotationBanner({required this.count});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      color: Colors.orange.shade100,
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          const Icon(Icons.warning_amber, color: Colors.orange),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              '$count account(s) na overdue na para baguhin ang password (30+ araw na).',
              style: const TextStyle(fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }
}
