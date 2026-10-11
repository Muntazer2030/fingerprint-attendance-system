import 'dart:typed_data';

import 'attendance_rules.dart';
import 'timesheet.dart';
import 'xlsx_writer.dart';

/// Builds the monthly timesheet workbook.
///
/// Two sheets: a summary with one row per employee, and a detail sheet with
/// every day. Days that need review are shaded rather than quietly averaged
/// into a total — the person filing this needs to see which figures are soft.
class TimesheetReport {
  const TimesheetReport._();

  static const _monthsEn = [
    'January',
    'February',
    'March',
    'April',
    'May',
    'June',
    'July',
    'August',
    'September',
    'October',
    'November',
    'December',
  ];
  static const _monthsAr = [
    'يناير',
    'فبراير',
    'مارس',
    'أبريل',
    'مايو',
    'يونيو',
    'يوليو',
    'أغسطس',
    'سبتمبر',
    'أكتوبر',
    'نوفمبر',
    'ديسمبر',
  ];

  static String fileName(DateTime month, String lang) =>
      'timesheet-${month.year}-${month.month.toString().padLeft(2, '0')}'
      '${lang == 'ar' ? '-ar' : ''}.xlsx';

  static String title(DateTime month, String lang) => lang == 'ar'
      ? '${_monthsAr[month.month - 1]} ${month.year}'
      : '${_monthsEn[month.month - 1]} ${month.year}';

  static Uint8List build({
    required List<EmployeeTimesheet> sheets,
    required DateTime month,
    String lang = 'en',
  }) {
    final ar = lang == 'ar';
    final t = ar ? _ar : _en;

    return XlsxWriter.build([
      _summary(sheets, month, t, ar),
      _detail(sheets, t, ar),
    ]);
  }

  static Sheet _summary(
    List<EmployeeTimesheet> sheets,
    DateTime month,
    Map<String, String> t,
    bool ar,
  ) {
    final s = Sheet(
      t['summary']!,
      rightToLeft: ar,
      columnWidths: const [26, 12, 12, 12, 12, 12, 12, 14],
    );

    final heading = '${t['title']} — ${title(month, ar ? 'ar' : 'en')}';
    s.add([Cell(heading, style: CellStyle.bold)]);
    s.addBlank();

    s.add([
      Cell(t['employee']!, style: CellStyle.header),
      Cell(t['present']!, style: CellStyle.header),
      Cell(t['absent']!, style: CellStyle.header),
      Cell(t['hours']!, style: CellStyle.header),
      Cell(t['overtime']!, style: CellStyle.header),
      Cell(t['late']!, style: CellStyle.header),
      Cell(t['earlyLeave']!, style: CellStyle.header),
      Cell(t['review']!, style: CellStyle.header),
    ]);

    for (final e in sheets) {
      final flagged = e.daysNeedingReview > 0;
      final style = flagged ? CellStyle.flagged : CellStyle.normal;
      s.add([
        Cell(e.name, style: style),
        Cell.number(e.daysPresent, style: style),
        Cell.number(e.daysAbsent, style: style),
        // Hours as a decimal so the column can be summed in Excel.
        Cell.number(_hours(e.workedMinutes), style: style),
        Cell.number(_hours(e.overtimeMinutes), style: style),
        Cell.number(e.lateOccasions, style: style),
        Cell.number(_hours(e.earlyLeaveMinutes), style: style),
        Cell.number(e.daysNeedingReview, style: style),
      ]);
    }

    s.addBlank();
    s.add([
      Cell(t['total']!, style: CellStyle.bold),
      Cell.number(
        sheets.fold(0, (n, e) => n + e.daysPresent),
        style: CellStyle.bold,
      ),
      Cell.number(
        sheets.fold(0, (n, e) => n + e.daysAbsent),
        style: CellStyle.bold,
      ),
      Cell.number(
        _hours(sheets.fold(0, (n, e) => n + e.workedMinutes)),
        style: CellStyle.bold,
      ),
      Cell.number(
        _hours(sheets.fold(0, (n, e) => n + e.overtimeMinutes)),
        style: CellStyle.bold,
      ),
      Cell.number(
        sheets.fold(0, (n, e) => n + e.lateOccasions),
        style: CellStyle.bold,
      ),
      Cell.number(
        _hours(sheets.fold(0, (n, e) => n + e.earlyLeaveMinutes)),
        style: CellStyle.bold,
      ),
      Cell.number(
        sheets.fold(0, (n, e) => n + e.daysNeedingReview),
        style: CellStyle.bold,
      ),
    ]);

    if (sheets.any((e) => e.daysNeedingReview > 0)) {
      s.addBlank();
      s.add([Cell(t['reviewNote']!)]);
    }

    return s;
  }

  static Sheet _detail(
    List<EmployeeTimesheet> sheets,
    Map<String, String> t,
    bool ar,
  ) {
    final s = Sheet(
      t['detail']!,
      rightToLeft: ar,
      columnWidths: const [26, 10, 12, 14, 10, 10, 10, 10, 22],
    );

    s.add([
      Cell(t['employee']!, style: CellStyle.header),
      Cell(t['date']!, style: CellStyle.header),
      Cell(t['status']!, style: CellStyle.header),
      Cell(t['shift']!, style: CellStyle.header),
      Cell(t['in']!, style: CellStyle.header),
      Cell(t['out']!, style: CellStyle.header),
      Cell(t['hours']!, style: CellStyle.header),
      Cell(t['late']!, style: CellStyle.header),
      Cell(t['note']!, style: CellStyle.header),
    ]);

    for (final e in sheets) {
      for (final d in e.days) {
        // Days off with nothing worked would triple the row count and say
        // nothing; leave them out. Days still to come likewise.
        if (d.status == DayStatus.off && d.workedMinutes == 0) continue;
        if (d.status == DayStatus.upcoming) continue;

        final style = d.needsReview
            ? CellStyle.flagged
            : (d.status == DayStatus.off ? CellStyle.muted : CellStyle.normal);

        s.add([
          Cell(e.name, style: style),
          Cell(_date(d.day), style: style),
          Cell(t[_statusKey(d.status)]!, style: style),
          Cell(d.shift?.name ?? t['notScheduled']!, style: style),
          Cell(_clock(d.firstIn), style: style),
          Cell(_clock(d.lastOut), style: style),
          Cell.number(_hours(d.workedMinutes), style: style),
          Cell.number(d.lateMinutes, style: style),
          Cell(_note(d, t), style: style),
        ]);
      }
    }

    return s;
  }

  static String _note(DayResult d, Map<String, String> t) {
    final parts = <String>[];
    if (d.unpairedPunches > 0) parts.add(t['missingPunch']!);
    if (d.hasProvisionalTime) parts.add(t['unverifiedTime']!);
    if (d.hasManualPunch) parts.add(t['manualEntry']!);
    return parts.join(' · ');
  }

  static String _statusKey(DayStatus s) => switch (s) {
    DayStatus.present => 'statusPresent',
    DayStatus.absent => 'statusAbsent',
    DayStatus.incomplete => 'statusIncomplete',
    DayStatus.off => 'statusOff',
    DayStatus.upcoming => 'statusUpcoming',
  };

  /// Minutes to decimal hours, two places. Excel can sum these; "7h 30m"
  /// cannot.
  static double _hours(int minutes) =>
      double.parse((minutes / 60).toStringAsFixed(2));

  static String _two(int n) => n.toString().padLeft(2, '0');
  static String _date(DateTime d) =>
      '${d.year}-${_two(d.month)}-${_two(d.day)}';
  static String _clock(DateTime? t) =>
      t == null ? '' : '${_two(t.hour)}:${_two(t.minute)}';

  static const _en = {
    'title': 'Attendance timesheet',
    'summary': 'Summary',
    'detail': 'Daily detail',
    'employee': 'Employee',
    'present': 'Days present',
    'absent': 'Days absent',
    'hours': 'Hours',
    'overtime': 'Overtime',
    'late': 'Late',
    'earlyLeave': 'Early leave',
    'review': 'Needs review',
    'total': 'Total',
    'date': 'Date',
    'status': 'Status',
    'shift': 'Shift',
    'in': 'In',
    'out': 'Out',
    'note': 'Note',
    'statusPresent': 'Present',
    'statusAbsent': 'Absent',
    'statusIncomplete': 'Incomplete',
    'statusOff': 'Day off',
    'statusUpcoming': 'Upcoming',
    'notScheduled': 'Not scheduled',
    'missingPunch': 'Missing punch',
    'unverifiedTime': 'Time unverified',
    'manualEntry': 'Entered manually',
    'reviewNote':
        'Shaded rows contain missing punches or unverified times. Check them before using these figures for pay.',
  };

  static const _ar = {
    'title': 'سجل الحضور والانصراف',
    'summary': 'الملخص',
    'detail': 'التفاصيل اليومية',
    'employee': 'الموظف',
    'present': 'أيام الحضور',
    'absent': 'أيام الغياب',
    'hours': 'الساعات',
    'overtime': 'ساعات إضافية',
    'late': 'التأخير',
    'earlyLeave': 'خروج مبكر',
    'review': 'بحاجة لمراجعة',
    'total': 'الإجمالي',
    'date': 'التاريخ',
    'status': 'الحالة',
    'shift': 'الوردية',
    'in': 'دخول',
    'out': 'خروج',
    'note': 'ملاحظة',
    'statusPresent': 'حاضر',
    'statusAbsent': 'غائب',
    'statusIncomplete': 'ناقص',
    'statusOff': 'إجازة',
    'statusUpcoming': 'قادم',
    'notScheduled': 'غير مجدول',
    'missingPunch': 'تسجيل ناقص',
    'unverifiedTime': 'وقت غير مؤكد',
    'manualEntry': 'إدخال يدوي',
    'reviewNote':
        'الصفوف المظللة تحتوي على تسجيلات ناقصة أو أوقات غير مؤكدة. راجعها قبل اعتمادها في الرواتب.',
  };
}
