/// Represents one saved credential set: an app or website, its username,
/// and its password. The password (and username) are stored ENCRYPTED
/// in the database — this model just carries the data around in memory
/// after it has already been decrypted (or before it's encrypted).
class VaultEntry {
  final int? id;
  final String label; // e.g. "Facebook", "GCash", "GitHub"
  final String? url; // optional, e.g. "https://facebook.com"
  final String username;
  final String password;
  final String? notes;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime lastPasswordChange;

  VaultEntry({
    this.id,
    required this.label,
    this.url,
    required this.username,
    required this.password,
    this.notes,
    DateTime? createdAt,
    DateTime? updatedAt,
    DateTime? lastPasswordChange,
  })  : createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now(),
        lastPasswordChange = lastPasswordChange ?? DateTime.now();

  /// True if this password is 30+ days old and due for rotation,
  /// matching the "change password monthly" requirement.
  bool get isPasswordDueForRotation {
    final daysSinceChange = DateTime.now().difference(lastPasswordChange).inDays;
    return daysSinceChange >= 30;
  }

  VaultEntry copyWith({
    int? id,
    String? label,
    String? url,
    String? username,
    String? password,
    String? notes,
    DateTime? createdAt,
    DateTime? updatedAt,
    DateTime? lastPasswordChange,
  }) {
    return VaultEntry(
      id: id ?? this.id,
      label: label ?? this.label,
      url: url ?? this.url,
      username: username ?? this.username,
      password: password ?? this.password,
      notes: notes ?? this.notes,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? DateTime.now(),
      lastPasswordChange: lastPasswordChange ?? this.lastPasswordChange,
    );
  }
}
