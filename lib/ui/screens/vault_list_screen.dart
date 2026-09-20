import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/utils/app_launcher.dart';
import '../../core/utils/clipboard_cooldown_service.dart';
import '../../core/models/vault_entry.dart';
import '../../core/database/vault_sync_service.dart';
import '../../core/database/sync_queue_service.dart';
import '../../core/session/vault_session.dart';
import '../../core/theme/theme_controller.dart';
import '../../main.dart' show VaultColors;
import 'add_edit_entry_screen.dart';
import 'settings_screen.dart';
import 'unlock_screen.dart';

class VaultListScreen extends StatefulWidget {
  const VaultListScreen({super.key});

  @override
  State<VaultListScreen> createState() => _VaultListScreenState();
}

class _VaultListScreenState extends State<VaultListScreen> {
  List<VaultEntry> _entries = [];
  List<VaultEntry> _filtered = [];
  bool _loading = true;
  final _searchController = TextEditingController();

  bool _selectionMode = false;
  final Set<String> _selectedIds = {};

  @override
  void initState() {
    super.initState();
    _loadEntries();
    _searchController.addListener(_applyFilter);
  }

  void _applyFilter() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      _filtered = query.isEmpty
          ? _entries
          : _entries
              .where((e) =>
                  e.label.toLowerCase().contains(query) ||
                  e.username.toLowerCase().contains(query))
              .toList();
    });
  }

  Future<void> _loadEntries() async {
    // If sign-out happened while this screen was still around (e.g. the
    // user signed out from Settings, which fully clears the session and
    // navigates away), the repository is gone. This screen itself is
    // about to be removed from the stack, so just skip the reload
    // instead of crashing on the null check.
    final repo = context.read<VaultSession>().repository;
    if (repo == null) return;

    setState(() => _loading = true);
    final entries = await repo.getAllEntries();
    if (!mounted) return;
    setState(() {
      _entries = entries;
      _filtered = entries;
      _loading = false;
    });
  }

  /// Used by pull-to-refresh: a full two-way sync, not just a local
  /// re-read. Pushes any changes still waiting in the local outbox
  /// (e.g. made while offline), pulls anything added on other devices,
  /// then reloads the list from local storage.
  Future<void> _syncAndReload() async {
    try {
      await SyncQueueService.flushPendingChanges();
    } catch (_) {
      // Ignore — likely offline, will retry on next unlock/refresh.
    }
    try {
      await VaultSyncService.pullFromCloud();
    } catch (_) {
      // Ignore — local data is still usable.
    }
    await _loadEntries();
  }

  void _lockVault() {
    context.read<VaultSession>().lock();
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const UnlockScreen()),
      (route) => false,
    );
  }

  void _openSettings() async {
    await Navigator.of(context).push(
      MaterialPageRoute(
          builder: (_) => SettingsScreen(onDataChanged: _loadEntries)),
    );
    if (!mounted) return;
    _loadEntries();
  }

  int get _dueForRotationCount =>
      _entries.where((e) => e.isPasswordDueForRotation).length;

  void _enterSelectionMode(String id) {
    setState(() {
      _selectionMode = true;
      _selectedIds.add(id);
    });
  }

  void _toggleSelection(String id) {
    setState(() {
      if (_selectedIds.contains(id)) {
        _selectedIds.remove(id);
      } else {
        _selectedIds.add(id);
      }
      if (_selectedIds.isEmpty) _selectionMode = false;
    });
  }

  void _selectAll() {
    setState(() {
      _selectionMode = true;
      _selectedIds
        ..clear()
        ..addAll(_filtered.map((e) => e.id!));
    });
  }

  void _exitSelectionMode() {
    setState(() {
      _selectionMode = false;
      _selectedIds.clear();
    });
  }

  Future<void> _deleteSelected() async {
    final count = _selectedIds.length;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Delete $count account${count > 1 ? 's' : ''}?'),
        content: const Text('This action cannot be undone.'),
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

    if (confirmed != true) return;
    if (!mounted) return;

    final repo = context.read<VaultSession>().repository!;
    await repo.deleteMultiple(_selectedIds.toList());
    _exitSelectionMode();
    _loadEntries();
  }

  Future<void> _openUrl(String url) async {
    var normalized = url.trim();
    if (!normalized.startsWith('http://') &&
        !normalized.startsWith('https://')) {
      normalized = 'https://$normalized';
    }
    final uri = Uri.tryParse(normalized);
    if (uri == null) return;

    final launched = await AppLauncher.openUrl(uri.toString());
    if (!mounted) return;
    if (launched) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
          content:
              Text('Could not open the link. Check your internet connection.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<VaultColors>()!;
    final themeController = context.watch<ThemeController>();

    return Scaffold(
      appBar: _selectionMode
          ? AppBar(
              leading: IconButton(
                icon: const Icon(Icons.close),
                onPressed: _exitSelectionMode,
              ),
              title: Text('${_selectedIds.length} selected'),
              actions: [
                IconButton(
                  icon: const Icon(Icons.select_all),
                  tooltip: 'Select all',
                  onPressed: _selectAll,
                ),
                IconButton(
                  icon: Icon(Icons.delete_outline, color: colors.danger),
                  tooltip: 'Delete selected',
                  onPressed: _selectedIds.isEmpty ? null : _deleteSelected,
                ),
              ],
            )
          : AppBar(
              title: const Text('My Vault'),
              actions: [
                IconButton(
                  icon: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 300),
                    transitionBuilder: (child, animation) => RotationTransition(
                      turns: animation,
                      child: ScaleTransition(scale: animation, child: child),
                    ),
                    child: Icon(
                      themeController.mode == ThemeMode.dark
                          ? Icons.dark_mode_outlined
                          : Icons.light_mode_outlined,
                      key: ValueKey(themeController.mode),
                    ),
                  ),
                  tooltip: 'Toggle dark / light mode',
                  onPressed: themeController.toggle,
                ),
                IconButton(
                  icon: const Icon(Icons.settings_outlined),
                  tooltip: 'Settings',
                  onPressed: _openSettings,
                ),
                IconButton(
                  icon: const Icon(Icons.lock_outline),
                  tooltip: 'Lock vault',
                  onPressed: _lockVault,
                ),
                const SizedBox(width: 8),
              ],
            ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _syncAndReload,
              child: Column(
                children: [
                  if (!_selectionMode)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                      child: TextField(
                        controller: _searchController,
                        decoration: InputDecoration(
                          hintText: 'Search accounts...',
                          prefixIcon: Icon(Icons.search,
                              color: colors.textSecondary, size: 20),
                          isDense: true,
                        ),
                      ),
                    ),
                  if (_dueForRotationCount > 0 && !_selectionMode)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: _RotationBanner(count: _dueForRotationCount),
                    ),
                  if (_selectionMode)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                      child: Row(
                        children: [
                          Icon(Icons.info_outline,
                              size: 16, color: colors.textSecondary),
                          const SizedBox(width: 6),
                          Text(
                            'Tap accounts to select more',
                            style: TextStyle(
                                fontSize: 12, color: colors.textSecondary),
                          ),
                        ],
                      ),
                    ),
                  Expanded(
                    child: _filtered.isEmpty
                        ? _EmptyState(
                            hasSearch: _searchController.text.isNotEmpty)
                        : LayoutBuilder(
                            builder: (context, constraints) {
                              final wide = constraints.maxWidth > 700;
                              if (wide) {
                                return GridView.builder(
                                  padding:
                                      const EdgeInsets.fromLTRB(16, 8, 16, 90),
                                  gridDelegate:
                                      const SliverGridDelegateWithMaxCrossAxisExtent(
                                    maxCrossAxisExtent: 480,
                                    mainAxisExtent: 76,
                                    crossAxisSpacing: 12,
                                    mainAxisSpacing: 12,
                                  ),
                                  itemCount: _filtered.length,
                                  itemBuilder: (context, index) =>
                                      _buildCard(_filtered[index]),
                                );
                              }
                              return ListView.separated(
                                padding:
                                    const EdgeInsets.fromLTRB(16, 8, 16, 90),
                                itemCount: _filtered.length,
                                separatorBuilder: (_, __) =>
                                    const SizedBox(height: 8),
                                itemBuilder: (context, index) =>
                                    _buildCard(_filtered[index]),
                              );
                            },
                          ),
                  ),
                ],
              ),
            ),
      floatingActionButton: _selectionMode
          ? null
          : FloatingActionButton.extended(
              onPressed: () async {
                await Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const AddEditEntryScreen()),
                );
                _loadEntries();
              },
              icon: const Icon(Icons.add),
              label: const Text('Add Account'),
            ),
    );
  }

  Widget _buildCard(VaultEntry entry) {
    final isSelected = _selectedIds.contains(entry.id);
    return _EntryCard(
      entry: entry,
      selectionMode: _selectionMode,
      selected: isSelected,
      onTap: () {
        if (_selectionMode) _toggleSelection(entry.id!);
      },
      onLongPress: () {
        if (!_selectionMode) _enterSelectionMode(entry.id!);
      },
      onEdit: () async {
        await Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => AddEditEntryScreen(entry: entry)),
        );
        _loadEntries();
      },
      onCopyUsername: () =>
          ClipboardCooldownService.copy(entry.username, label: 'Username'),
      onCopyPassword: () =>
          ClipboardCooldownService.copy(entry.password, label: 'Password'),
      onOpenLink: entry.url != null && entry.url!.isNotEmpty
          ? () => _openUrl(entry.url!)
          : null,
    );
  }
}

class _EntryCard extends StatelessWidget {
  final VaultEntry entry;
  final bool selectionMode;
  final bool selected;
  final VoidCallback onTap;
  final VoidCallback onLongPress;
  final VoidCallback onEdit;
  final VoidCallback onCopyUsername;
  final VoidCallback onCopyPassword;
  final VoidCallback? onOpenLink;

  const _EntryCard({
    required this.entry,
    required this.selectionMode,
    required this.selected,
    required this.onTap,
    required this.onLongPress,
    required this.onEdit,
    required this.onCopyUsername,
    required this.onCopyPassword,
    required this.onOpenLink,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<VaultColors>()!;

    return Material(
      color: selected ? colors.accent.withValues(alpha: 0.12) : colors.surface,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        onLongPress: onLongPress,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: selected ? colors.accent : colors.surfaceVariant,
              width: selected ? 1.5 : 1,
            ),
          ),
          child: Row(
            children: [
              if (selectionMode) ...[
                Icon(
                  selected ? Icons.check_circle : Icons.circle_outlined,
                  color: selected ? colors.accent : colors.textSecondary,
                  size: 22,
                ),
                const SizedBox(width: 12),
              ],
              if (!selectionMode)
                Container(
                  width: 44,
                  height: 44,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: colors.accent.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    entry.label.isNotEmpty ? entry.label[0].toUpperCase() : '?',
                    style: TextStyle(
                        color: colors.accent,
                        fontWeight: FontWeight.w700,
                        fontSize: 18),
                  ),
                ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      entry.label,
                      style: TextStyle(
                        color: colors.textPrimary,
                        fontWeight: FontWeight.w600,
                        fontSize: 15,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      entry.username,
                      style:
                          TextStyle(color: colors.textSecondary, fontSize: 13),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              if (!selectionMode) ...[
                IconButton(
                  icon: Icon(Icons.person_outline,
                      color: colors.textSecondary, size: 20),
                  tooltip: 'Copy username',
                  onPressed: onCopyUsername,
                ),
                IconButton(
                  icon: Icon(Icons.key_outlined,
                      color: colors.textSecondary, size: 20),
                  tooltip: 'Copy password',
                  onPressed: onCopyPassword,
                ),
                if (onOpenLink != null)
                  IconButton(
                    icon: Icon(Icons.open_in_new,
                        color: colors.textSecondary, size: 20),
                    tooltip: 'Open link',
                    onPressed: onOpenLink,
                  ),
                IconButton(
                  icon:
                      Icon(Icons.edit_outlined, color: colors.accent, size: 20),
                  tooltip: 'Edit',
                  onPressed: onEdit,
                ),
              ],
              if (!selectionMode && entry.isPasswordDueForRotation)
                Icon(Icons.warning_amber_rounded,
                    color: colors.warning, size: 20),
            ],
          ),
        ),
      ),
    );
  }
}

class _RotationBanner extends StatelessWidget {
  final int count;
  const _RotationBanner({required this.count});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<VaultColors>()!;

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colors.warning.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colors.warning.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Icon(Icons.warning_amber_rounded, color: colors.warning, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              '$count account${count > 1 ? 's' : ''} overdue for a password change (30+ days old)',
              style: TextStyle(fontSize: 13, color: colors.textPrimary),
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final bool hasSearch;
  const _EmptyState({required this.hasSearch});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<VaultColors>()!;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              hasSearch ? Icons.search_off : Icons.inbox_outlined,
              size: 48,
              color: colors.textSecondary,
            ),
            const SizedBox(height: 16),
            Text(
              hasSearch ? 'No matching accounts' : 'No saved accounts yet',
              style: TextStyle(color: colors.textSecondary, fontSize: 15),
            ),
            if (!hasSearch) ...[
              const SizedBox(height: 6),
              Text(
                'Tap "Add Account" to save your first credential',
                style: TextStyle(color: colors.textSecondary, fontSize: 13),
                textAlign: TextAlign.center,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
