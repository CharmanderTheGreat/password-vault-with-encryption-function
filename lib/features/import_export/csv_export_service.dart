import 'dart:io';
import '../../core/models/vault_entry.dart';

/// Exports vault entries to a CSV file using the same column format
/// browsers use (name,url,username,password,note), so the file can
/// also be re-imported into Chrome/Brave/Edge if ever needed.
///
/// IMPORTANT: this file is plain text, unencrypted — same as browser
/// exports. It should be deleted or stored somewhere safe right after
/// use.
class CsvExportService {
  static Future<File> exportToFile(List<VaultEntry> entries, String filePath) async {
    final buffer = StringBuffer();
    buffer.writeln('name,url,username,password,note');

    for (final entry in entries) {
      buffer.writeln([
        _escape(entry.label),
        _escape(entry.url ?? ''),
        _escape(entry.username),
        _escape(entry.password),
        _escape(entry.notes ?? ''),
      ].join(','));
    }

    final file = File(filePath);
    await file.writeAsString(buffer.toString());
    return file;
  }

  /// Wraps a field in quotes if it contains a comma, quote, or newline —
  /// standard CSV escaping so values with special characters survive
  /// round-tripping through Excel/Sheets/browsers.
  static String _escape(String value) {
    if (value.contains(',') || value.contains('"') || value.contains('\n')) {
      return '"${value.replaceAll('"', '""')}"';
    }
    return value;
  }
}
