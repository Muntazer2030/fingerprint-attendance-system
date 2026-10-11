import 'package:flutter/material.dart';

import '../data/database.dart';
import '../l10n/app_localizations.dart';

/// Employee names for display.
///
/// Names exist only on this PC -- the terminal stores a rendered bitmap, not
/// text -- so anything showing a punch or a person has to look them up here.
/// Every page used to print "Employee ID 5" instead.
class NameBook {
  NameBook(Iterable<EmployeeRow> rows)
    : _names = {
        for (final r in rows)
          if (r.name.trim().isNotEmpty) r.id: r.name.trim(),
      };

  final Map<int, String> _names;

  static Future<NameBook> load(AppDatabase db) async =>
      NameBook(await db.allEmployees());

  String? nameOf(int id) => _names[id];

  /// The name, or "ID 5" when none has been given.
  String label(BuildContext context, int id) =>
      _names[id] ?? '${AppLocalizations.of(context)!.employeeId} $id';

  /// Up to two initials for an avatar. Arabic names get their first letter;
  /// initials are not a convention there, but a single letter still reads.
  static String initials(String name, int id) {
    final parts = name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty);
    if (parts.isEmpty) return '$id';
    final first = parts.first.characters.first;
    // Two Arabic letters side by side join into a word ("محمد علي" would read
    // as "مع"), so Arabic names get one letter.
    final arabic = RegExp(r'[؀-ۿ]').hasMatch(first);
    if (parts.length == 1 || arabic) return first.toUpperCase();
    return (first + parts.last.characters.first).toUpperCase();
  }
}
