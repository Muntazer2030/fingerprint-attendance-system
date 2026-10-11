import 'dart:convert';

import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:attendance_admin/domain/attendance_rules.dart';
import 'package:attendance_admin/domain/timesheet.dart';
import 'package:attendance_admin/domain/timesheet_report.dart';
import 'package:attendance_admin/domain/xlsx_writer.dart';

/// An .xlsx is a ZIP of XML parts, and Excel refuses the whole file rather
/// than complaining about one bad cell. These check the structure Excel
/// actually requires, and that Arabic survives the trip.
void main() {
  Archive open(List<int> bytes) => ZipDecoder().decodeBytes(bytes);

  String part(Archive a, String name) {
    final f = a.files.firstWhere((f) => f.name == name,
        orElse: () => throw StateError('missing part: $name'));
    return utf8.decode(f.content as List<int>);
  }

  group('workbook structure', () {
    test('contains every part Excel requires', () {
      final bytes = XlsxWriter.build([Sheet('One')..add([const Cell('hi')])]);
      final a = open(bytes);
      final names = a.files.map((f) => f.name).toSet();

      expect(names, containsAll(<String>[
        '[Content_Types].xml',
        '_rels/.rels',
        'xl/workbook.xml',
        'xl/_rels/workbook.xml.rels',
        'xl/styles.xml',
        'xl/worksheets/sheet1.xml',
      ]));
    });

    test('every sheet is declared, related and present', () {
      final bytes = XlsxWriter.build([
        Sheet('A')..add([const Cell('a')]),
        Sheet('B')..add([const Cell('b')]),
      ]);
      final a = open(bytes);

      expect(part(a, 'xl/workbook.xml'), contains('name="A"'));
      expect(part(a, 'xl/workbook.xml'), contains('name="B"'));
      expect(part(a, 'xl/_rels/workbook.xml.rels'),
          contains('worksheets/sheet2.xml'));
      expect(part(a, '[Content_Types].xml'), contains('sheet2.xml'));
      expect(a.files.any((f) => f.name == 'xl/worksheets/sheet2.xml'), isTrue);
    });

    test('an empty workbook is rejected rather than written corrupt', () {
      expect(() => XlsxWriter.build([]), throwsArgumentError);
    });
  });

  group('cells', () {
    test('numbers are numeric, not text, so Excel can sum them', () {
      final bytes =
          XlsxWriter.build([Sheet('S')..add([const Cell.number(7.5)])]);
      final xml = part(open(bytes), 'xl/worksheets/sheet1.xml');

      expect(xml, contains('<v>7.5</v>'));
      expect(xml, isNot(contains('t="inlineStr"')));
    });

    test('Arabic survives as UTF-8 inline text', () {
      final bytes = XlsxWriter.build([
        Sheet('S')..add([const Cell('تسجيل دخول')])
      ]);
      final xml = part(open(bytes), 'xl/worksheets/sheet1.xml');

      expect(xml, contains('تسجيل دخول'));
      expect(xml, contains('t="inlineStr"'));
    });

    test('XML-special characters are escaped, not emitted raw', () {
      final bytes = XlsxWriter.build([
        Sheet('S')..add([const Cell('Tom & Jerry <b> "x"')])
      ]);
      final xml = part(open(bytes), 'xl/worksheets/sheet1.xml');

      expect(xml, contains('&amp;'));
      expect(xml, contains('&lt;b&gt;'));
      expect(xml, isNot(contains('& J')));
    });

    test('control characters are dropped, since they make Excel refuse the file',
        () {
      final bytes = XlsxWriter.build([
        Sheet('S')..add([Cell('bad${String.fromCharCode(7)}char')])
      ]);
      final xml = part(open(bytes), 'xl/worksheets/sheet1.xml');
      expect(xml, contains('badchar'));
    });

    test('blank rows do not shift the rows after them', () {
      final s = Sheet('S')
        ..add([const Cell('first')])
        ..addBlank()
        ..add([const Cell('third')]);
      final xml = part(open(XlsxWriter.build([s])), 'xl/worksheets/sheet1.xml');

      // Row 2 is skipped entirely; "third" must still claim row 3.
      expect(xml, contains('r="A1"'));
      expect(xml, contains('r="A3"'));
      expect(xml, isNot(contains('r="A2"')));
    });

    test('column letters continue past Z', () {
      final s = Sheet('S')..add(List.filled(28, const Cell('x')));
      final xml = part(open(XlsxWriter.build([s])), 'xl/worksheets/sheet1.xml');
      expect(xml, contains('r="Z1"'));
      expect(xml, contains('r="AA1"'));
      expect(xml, contains('r="AB1"'));
    });
  });

  group('sheet names', () {
    test('illegal characters are replaced', () {
      final bytes = XlsxWriter.build([Sheet(r'a/b:c*d?e[f]')..add([const Cell('x')])]);
      final xml = part(open(bytes), 'xl/workbook.xml');
      for (final ch in [':', '/', r'\\', '?', '*', '[', ']']) {
        expect(xml.split('name="')[1].split('"')[0], isNot(contains(ch)));
      }
    });

    test('names are truncated to the 31-character limit', () {
      final long = 'x' * 60;
      final xml = part(
          open(XlsxWriter.build([Sheet(long)..add([const Cell('x')])])),
          'xl/workbook.xml');
      final name = xml.split('name="')[1].split('"')[0];
      expect(name.length, 31);
    });
  });

  group('timesheet report', () {
    EmployeeTimesheet sheetFor({required bool withGap}) {
      const shift = Shift(id: 1, name: 'Day', daysMask: 0x7F);
      return Timesheet.build(
        employeeId: 1,
        name: 'محمد',
        from: DateTime(2026, 8, 24),
        to: DateTime(2026, 8, 25),
        resolver: ShiftResolver(storeDefault: shift),
        punches: [
          Punch(at: DateTime(2026, 8, 24, 9, 0), isOut: false),
          Punch(at: DateTime(2026, 8, 24, 17, 0), isOut: true),
          Punch(at: DateTime(2026, 8, 25, 9, 0), isOut: false),
          if (!withGap) Punch(at: DateTime(2026, 8, 25, 17, 0), isOut: true),
        ],
      );
    }

    test('the Arabic report marks its sheets right-to-left', () {
      final bytes = TimesheetReport.build(
        sheets: [sheetFor(withGap: false)],
        month: DateTime(2026, 8),
        lang: 'ar',
      );
      final a = open(bytes);
      expect(part(a, 'xl/worksheets/sheet1.xml'), contains('rightToLeft="1"'));
      expect(part(a, 'xl/worksheets/sheet2.xml'), contains('rightToLeft="1"'));
    });

    test('the English report does not', () {
      final bytes = TimesheetReport.build(
        sheets: [sheetFor(withGap: false)],
        month: DateTime(2026, 8),
      );
      expect(part(open(bytes), 'xl/worksheets/sheet1.xml'),
          isNot(contains('rightToLeft')));
    });

    test('an Arabic employee name reaches the file intact', () {
      final bytes = TimesheetReport.build(
        sheets: [sheetFor(withGap: false)],
        month: DateTime(2026, 8),
        lang: 'ar',
      );
      expect(part(open(bytes), 'xl/worksheets/sheet1.xml'), contains('محمد'));
    });

    test('a day needing review is shaded rather than silently averaged in', () {
      final bytes = TimesheetReport.build(
        sheets: [sheetFor(withGap: true)],
        month: DateTime(2026, 8),
      );
      final xml = part(open(bytes), 'xl/worksheets/sheet1.xml');
      // Style index 3 is the amber "flagged" fill.
      expect(xml, contains('s="3"'));
    });

    test('the file name carries the month and language', () {
      expect(TimesheetReport.fileName(DateTime(2026, 8), 'en'),
          'timesheet-2026-08.xlsx');
      expect(TimesheetReport.fileName(DateTime(2026, 12), 'ar'),
          'timesheet-2026-12-ar.xlsx');
    });
  });
}
