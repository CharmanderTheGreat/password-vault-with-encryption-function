import 'dart:convert';
import 'dart:io';
import '../../core/models/vault_entry.dart';

/// Parses the CSV file that Chrome, Brave, and Edge produce when you
/// export saved passwords (chrome://settings/passwords -> "Export
/// passwords"). All three use the same format:
///
///   name,url,username,password[,note]
///
/// This never touches the network — the file is read straight from
/// disk, entirely offline.
class CsvImportService {
  /// Reads and parses a browser password-export CSV file.
  /// Throws a [FormatException] with a friendly message if the file
  /// doesn't look like a supported export.
  static Future<List<VaultEntry>> parseFile(String filePath) async {
    final file = File(filePath);
    final content = await file.readAsString(encoding: utf8);
    return parseContent(content);
  }

  static List<VaultEntry> parseContent(String content) {
    final rows = _parseCsv(content);
    if (rows.isEmpty) {
      throw const FormatException('The file is empty.');
    }

    final header = rows.first.map((h) => h.trim().toLowerCase()).toList();
    final nameIdx = header.indexOf('name');
    final urlIdx = header.indexOf('url');
    final userIdx = header.indexOf('username');
    final passIdx = header.indexOf('password');
    final noteIdx = header.indexOf('note');

    if (nameIdx == -1 || userIdx == -1 || passIdx == -1) {
      throw const FormatException(
        'This doesn\'t look like a browser password export. '
        'Expected columns: name, url, username, password.',
      );
    }

    final entries = <VaultEntry>[];
    for (var i = 1; i < rows.length; i++) {
      final row = rows[i];
      if (row.length <= passIdx) continue; // skip malformed/blank rows

      final label = row[nameIdx].trim();
      final username = row[userIdx].trim();
      final password = row[passIdx].trim();

      if (label.isEmpty && username.isEmpty && password.isEmpty) continue;

      entries.add(VaultEntry(
        label: label.isEmpty ? 'Imported Account' : label,
        url: urlIdx != -1 && urlIdx < row.length && row[urlIdx].trim().isNotEmpty
            ? row[urlIdx].trim()
            : null,
        username: username,
        password: password,
        notes: noteIdx != -1 && noteIdx < row.length && row[noteIdx].trim().isNotEmpty
            ? row[noteIdx].trim()
            : null,
      ));
    }

    return entries;
  }

  /// Minimal CSV parser that handles quoted fields (values wrapped in
  /// "..." that may contain commas or escaped quotes ""), which browser
  /// exports commonly use for URLs and passwords with special characters.
  static List<List<String>> _parseCsv(String content) {
    final rows = <List<String>>[];
    var row = <String>[];
    var field = StringBuffer();
    var inQuotes = false;

    final normalized = content.replaceAll('\r\n', '\n');

    for (var i = 0; i < normalized.length; i++) {
      final char = normalized[i];

      if (inQuotes) {
        if (char == '"') {
          if (i + 1 < normalized.length && normalized[i + 1] == '"') {
            field.write('"');
            i++;
          } else {
            inQuotes = false;
          }
        } else {
          field.write(char);
        }
      } else {
        if (char == '"') {
          inQuotes = true;
        } else if (char == ',') {
          row.add(field.toString());
          field = StringBuffer();
        } else if (char == '\n') {
          row.add(field.toString());
          field = StringBuffer();
          rows.add(row);
          row = [];
        } else {
          field.write(char);
        }
      }
    }

    if (field.isNotEmpty || row.isNotEmpty) {
      row.add(field.toString());
      rows.add(row);
    }

    return rows.where((r) => r.any((cell) => cell.trim().isNotEmpty)).toList();
  }
}
