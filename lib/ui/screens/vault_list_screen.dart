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

  Future<void> _syncAndReload() async {
    try {
      await SyncQueueService.flushPendingChanges();
    } catch (_) {}
    try {
      await VaultSyncService.pullFromCloud();
    } catch (_) {}
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

  void _navigateToEdit(VaultEntry entry) async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => AddEditEntryScreen(entry: entry)),
    );
    _loadEntries();
  }

  void _showEntryActionsModal(VaultEntry entry) {
    final colors = Theme.of(context).extension<VaultColors>()!;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: colors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return _VaultEntryBottomSheet(
          entry: entry,
          colors: colors,
          onCopyUsername: () {
            ClipboardCooldownService.copy(entry.username, label: 'Username');
            Navigator.pop(context);
          },
          onCopyPassword: () {
            ClipboardCooldownService.copy(entry.password, label: 'Password');
            Navigator.pop(context);
          },
          onOpenLink: entry.url != null && entry.url!.isNotEmpty
              ? () {
                  Navigator.pop(context);
                  _openUrl(entry.url!);
                }
              : null,
          onEdit: () {
            Navigator.pop(context);
            _navigateToEdit(entry);
          },
        );
      },
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
        if (_selectionMode) {
          _toggleSelection(entry.id!);
        } else {
          _showEntryActionsModal(entry);
        }
      },
      onLongPress: () {
        if (!_selectionMode) _enterSelectionMode(entry.id!);
      },
      onCopyPassword: () =>
          ClipboardCooldownService.copy(entry.password, label: 'Password'),
    );
  }
}

class _EntryCard extends StatelessWidget {
  final VaultEntry entry;
  final bool selectionMode;
  final bool selected;
  final VoidCallback onTap;
  final VoidCallback onLongPress;
  final VoidCallback onCopyPassword;

  const _EntryCard({
    required this.entry,
    required this.selectionMode,
    required this.selected,
    required this.onTap,
    required this.onLongPress,
    required this.onCopyPassword,
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
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
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
                Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: colors.accent.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        entry.label.isNotEmpty
                            ? entry.label[0].toUpperCase()
                            : '?',
                        style: TextStyle(
                          color: colors.accent,
                          fontWeight: FontWeight.w700,
                          fontSize: 18,
                        ),
                      ),
                    ),
                    if (entry.isPasswordDueForRotation)
                      Positioned(
                        top: -3,
                        right: -3,
                        child: Container(
                          padding: const EdgeInsets.all(3),
                          decoration: BoxDecoration(
                            color: colors.warning,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.priority_high,
                            size: 10,
                            color: Colors.black,
                          ),
                        ),
                      ),
                  ],
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
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 3),
                    Text(
                      entry.username,
                      style: TextStyle(
                        color: colors.textSecondary,
                        fontSize: 13,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              if (!selectionMode) ...[
                IconButton(
                  icon: Icon(Icons.copy_rounded,
                      color: colors.textSecondary, size: 20),
                  tooltip: 'Copy password',
                  onPressed: onCopyPassword,
                ),
                Icon(
                  Icons.chevron_right_rounded,
                  color: colors.textSecondary.withValues(alpha: 0.5),
                  size: 20,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _VaultEntryBottomSheet extends StatefulWidget {
  final VaultEntry entry;
  final VaultColors colors;
  final VoidCallback onCopyUsername;
  final VoidCallback onCopyPassword;
  final VoidCallback? onOpenLink;
  final VoidCallback onEdit;

  const _VaultEntryBottomSheet({
    required this.entry,
    required this.colors,
    required this.onCopyUsername,
    required this.onCopyPassword,
    required this.onOpenLink,
    required this.onEdit,
  });

  @override
  State<_VaultEntryBottomSheet> createState() => _VaultEntryBottomSheetState();
}

class _VaultEntryBottomSheetState extends State<_VaultEntryBottomSheet> {
  bool _obscurePassword = true;

  @override
  Widget build(BuildContext context) {
    final entry = widget.entry;
    final colors = widget.colors;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: colors.textSecondary.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
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
                      fontSize: 18,
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        entry.label,
                        style: TextStyle(
                          color: colors.textPrimary,
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (entry.url != null && entry.url!.isNotEmpty)
                        Text(
                          entry.url!,
                          style: TextStyle(
                            color: colors.textSecondary,
                            fontSize: 12,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                    ],
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.edit_outlined, color: colors.accent),
                  tooltip: 'Edit',
                  onPressed: widget.onEdit,
                ),
              ],
            ),
            const SizedBox(height: 20),
            Container(
              decoration: BoxDecoration(
                color: colors.surfaceVariant.withValues(alpha: 0.4),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: [
                  ListTile(
                    dense: true,
                    title: Text('Username / Email',
                        style: TextStyle(
                            fontSize: 12, color: colors.textSecondary)),
                    subtitle: Text(
                      entry.username,
                      style: TextStyle(
                          fontSize: 15,
                          color: colors.textPrimary,
                          fontWeight: FontWeight.w500),
                    ),
                    trailing: IconButton(
                      icon: const Icon(Icons.copy_rounded, size: 18),
                      tooltip: 'Copy username',
                      onPressed: widget.onCopyUsername,
                    ),
                  ),
                  Divider(
                      height: 1,
                      color: colors.surfaceVariant.withValues(alpha: 0.5)),
                  ListTile(
                    dense: true,
                    title: Text('Password',
                        style: TextStyle(
                            fontSize: 12, color: colors.textSecondary)),
                    subtitle: Text(
                      _obscurePassword ? '••••••••••••' : entry.password,
                      style: TextStyle(
                          fontSize: 15,
                          color: colors.textPrimary,
                          fontWeight: FontWeight.w500),
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: Icon(
                            _obscurePassword
                                ? Icons.visibility_outlined
                                : Icons.visibility_off_outlined,
                            size: 18,
                          ),
                          onPressed: () {
                            setState(() {
                              _obscurePassword = !_obscurePassword;
                            });
                          },
                        ),
                        IconButton(
                          icon: const Icon(Icons.copy_rounded, size: 18),
                          tooltip: 'Copy password',
                          onPressed: widget.onCopyPassword,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            if (widget.onOpenLink != null) ...[
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.open_in_new_rounded, size: 18),
                  label: const Text('Open Website'),
                  onPressed: widget.onOpenLink,
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
              ),
            ],
          ],
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