import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';

/// A very small .xlsx writer.
///
/// Written by hand rather than pulled from a package for two reasons: the
/// report has to be **right-to-left**, which means setting `rightToLeft` on the
/// sheet view — something the common Dart spreadsheet packages do not expose —
/// and Arabic text has historically been mangled by their shared-string
/// handling. Inline strings sidestep that entirely.
///
/// An .xlsx is a ZIP of XML parts. Only the handful Excel actually requires
/// are produced here.

enum CellStyle {
  normal,
  header,
  bold,

  /// Amber background: a figure that should be checked before it is trusted.
  flagged,

  /// Muted: a day nobody was scheduled.
  muted,
}

class Cell {
  const Cell(
    this.value, {
    this.style = CellStyle.normal,
    this.isNumber = false,
  });

  const Cell.number(num v, {this.style = CellStyle.normal})
    : value = v,
      isNumber = true;

  final Object? value;
  final CellStyle style;
  final bool isNumber;

  static const empty = Cell(null);
}

class Sheet {
  Sheet(this.name, {this.rightToLeft = false, this.columnWidths = const []});

  final String name;
  final bool rightToLeft;
  final List<double> columnWidths;
  final List<List<Cell>> rows = [];

  void add(List<Cell> row) => rows.add(row);
  void addBlank() => rows.add(const []);
}

class XlsxWriter {
  const XlsxWriter._();

  static Uint8List build(List<Sheet> sheets) {
    if (sheets.isEmpty) {
      throw ArgumentError('a workbook needs at least one sheet');
    }

    final archive = Archive();
    void put(String path, String xml) {
      final bytes = utf8.encode(xml);
      archive.addFile(ArchiveFile(path, bytes.length, bytes));
    }

    put('[Content_Types].xml', _contentTypes(sheets.length));
    put('_rels/.rels', _rootRels);
    put('xl/workbook.xml', _workbook(sheets));
    put('xl/_rels/workbook.xml.rels', _workbookRels(sheets.length));
    put('xl/styles.xml', _styles);

    for (var i = 0; i < sheets.length; i++) {
      put('xl/worksheets/sheet${i + 1}.xml', _sheetXml(sheets[i]));
    }

    final zipped = ZipEncoder().encode(archive);
    if (zipped == null) {
      throw StateError('failed to encode the workbook');
    }
    return Uint8List.fromList(zipped);
  }

  // --- parts --------------------------------------------------------------

  static String _contentTypes(int sheetCount) {
    final overrides = [
      for (var i = 1; i <= sheetCount; i++)
        '<Override PartName="/xl/worksheets/sheet$i.xml" '
            'ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.worksheet+xml"/>',
    ].join();

    return '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
        '<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">'
        '<Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>'
        '<Default Extension="xml" ContentType="application/xml"/>'
        '<Override PartName="/xl/workbook.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.sheet.main+xml"/>'
        '<Override PartName="/xl/styles.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.styles+xml"/>'
        '$overrides'
        '</Types>';
  }

  static const _rootRels =
      '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
      '<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">'
      '<Relationship Id="rId1" '
      'Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" '
      'Target="xl/workbook.xml"/>'
      '</Relationships>';

  static String _workbook(List<Sheet> sheets) {
    final tags = [
      for (var i = 0; i < sheets.length; i++)
        '<sheet name="${_attr(_sheetName(sheets[i].name))}" '
            'sheetId="${i + 1}" r:id="rId${i + 1}"/>',
    ].join();

    return '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
        '<workbook xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main" '
        'xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships">'
        '<sheets>$tags</sheets>'
        '</workbook>';
  }

  static String _workbookRels(int sheetCount) {
    final rels = [
      for (var i = 1; i <= sheetCount; i++)
        '<Relationship Id="rId$i" '
            'Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/worksheet" '
            'Target="worksheets/sheet$i.xml"/>',
      '<Relationship Id="rId${sheetCount + 1}" '
          'Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/styles" '
          'Target="styles.xml"/>',
    ].join();

    return '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
        '<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">'
        '$rels</Relationships>';
  }

  /// Index order here defines the `s=` values used by [CellStyle].
  static const _styles =
      '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
      '<styleSheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main">'
      '<fonts count="4">'
      '<font><sz val="11"/><name val="Calibri"/></font>'
      '<font><b/><sz val="11"/><color rgb="FFFFFFFF"/><name val="Calibri"/></font>'
      '<font><b/><sz val="11"/><name val="Calibri"/></font>'
      '<font><sz val="11"/><color rgb="FF888888"/><name val="Calibri"/></font>'
      '</fonts>'
      '<fills count="4">'
      '<fill><patternFill patternType="none"/></fill>'
      '<fill><patternFill patternType="gray125"/></fill>'
      '<fill><patternFill patternType="solid"><fgColor rgb="FF4F46E5"/></patternFill></fill>'
      '<fill><patternFill patternType="solid"><fgColor rgb="FFFDE68A"/></patternFill></fill>'
      '</fills>'
      '<borders count="1"><border/></borders>'
      '<cellStyleXfs count="1"><xf/></cellStyleXfs>'
      '<cellXfs count="5">'
      '<xf xfId="0"/>'
      '<xf xfId="0" fontId="1" fillId="2" applyFont="1" applyFill="1">'
      '<alignment horizontal="center" vertical="center"/></xf>'
      '<xf xfId="0" fontId="2" applyFont="1"/>'
      '<xf xfId="0" fillId="3" applyFill="1"/>'
      '<xf xfId="0" fontId="3" applyFont="1"/>'
      '</cellXfs>'
      '</styleSheet>';

  static String _sheetXml(Sheet sheet) {
    final buf = StringBuffer()
      ..write('<?xml version="1.0" encoding="UTF-8" standalone="yes"?>')
      ..write(
        '<worksheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main">',
      )
      // The whole point of hand-rolling this: Arabic reports read right to
      // left, so column A must sit on the right.
      ..write('<sheetViews><sheetView workbookViewId="0"')
      ..write(sheet.rightToLeft ? ' rightToLeft="1"' : '')
      ..write('/></sheetViews>');

    if (sheet.columnWidths.isNotEmpty) {
      buf.write('<cols>');
      for (var i = 0; i < sheet.columnWidths.length; i++) {
        buf.write(
          '<col min="${i + 1}" max="${i + 1}" '
          'width="${sheet.columnWidths[i]}" customWidth="1"/>',
        );
      }
      buf.write('</cols>');
    }

    buf.write('<sheetData>');
    for (var r = 0; r < sheet.rows.length; r++) {
      final row = sheet.rows[r];
      if (row.isEmpty) continue; // spacer
      buf.write('<row r="${r + 1}">');
      for (var c = 0; c < row.length; c++) {
        final cell = row[c];
        if (cell.value == null) continue;
        final ref = '${_columnName(c)}${r + 1}';
        final s = cell.style.index;

        if (cell.isNumber) {
          buf.write('<c r="$ref" s="$s"><v>${cell.value}</v></c>');
        } else {
          // Inline strings rather than a shared-string table: fewer parts, and
          // no chance of an index mismatch mangling Arabic.
          buf.write(
            '<c r="$ref" s="$s" t="inlineStr"><is><t xml:space="preserve">'
            '${_text(cell.value.toString())}</t></is></c>',
          );
        }
      }
      buf.write('</row>');
    }
    buf.write('</sheetData></worksheet>');
    return buf.toString();
  }

  // --- helpers ------------------------------------------------------------

  /// Excel rejects sheet names over 31 characters or containing : \ / ? * [ ]
  static String _sheetName(String raw) {
    var s = raw.replaceAll(RegExp(r'[:\\/?*\[\]]'), ' ').trim();
    if (s.isEmpty) s = 'Sheet';
    return s.length <= 31 ? s : s.substring(0, 31);
  }

  static String _columnName(int index) {
    var n = index;
    var out = '';
    do {
      out = String.fromCharCode(65 + (n % 26)) + out;
      n = n ~/ 26 - 1;
    } while (n >= 0);
    return out;
  }

  static String _text(String s) {
    final buf = StringBuffer();
    for (final rune in s.runes) {
      switch (rune) {
        case 0x26:
          buf.write('&amp;');
        case 0x3C:
          buf.write('&lt;');
        case 0x3E:
          buf.write('&gt;');
        default:
          // Control characters are illegal in XML 1.0 and make Excel refuse
          // to open the file rather than complain about the cell.
          if (rune < 0x20 && rune != 0x09 && rune != 0x0A && rune != 0x0D) {
            continue;
          }
          buf.writeCharCode(rune);
      }
    }
    return buf.toString();
  }

  static String _attr(String s) =>
      _text(s).replaceAll('"', '&quot;').replaceAll("'", '&apos;');
}
