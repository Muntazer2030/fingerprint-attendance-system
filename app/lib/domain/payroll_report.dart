import 'dart:typed_data';

import 'payroll.dart';
import 'timesheet_report.dart';
import 'xlsx_writer.dart';

/// Builds the monthly salary workbook.
///
/// One row per employee with every line of the payslip, so the sheet can be
/// checked by hand: base, plus each addition, minus each cut, equals net.
/// Figures the manager edited are marked, and so are rows resting on days
/// that still need review.
class PayrollReport {
  const PayrollReport._();

  static String fileName(DateTime month, String lang) =>
      'payroll-${month.year}-${month.month.toString().padLeft(2, '0')}'
      '${lang == 'ar' ? '-ar' : ''}.xlsx';

  static Uint8List build({
    required PayrollMonth payroll,
    required String currency,
    String lang = 'en',
  }) {
    final ar = lang == 'ar';
    final t = ar ? _ar : _en;
    return XlsxWriter.build([
      _summary(payroll, currency, t, ar),
      _adjustments(payroll, t, ar),
    ]);
  }

  static Sheet _summary(
    PayrollMonth m,
    String currency,
    Map<String, String> t,
    bool ar,
  ) {
    final s = Sheet(
      t['payroll']!,
      rightToLeft: ar,
      columnWidths: const [
        26, 12, 12, 10, 10, 12, 10, 12, 10, 12, //
        10, 12, 10, 12, 12, 12, 12, 12, 14, 30,
      ],
    );

    final title = TimesheetReport.title(m.month, ar ? 'ar' : 'en');
    s.add([
      Cell(
        '${t['title']} — $title${currency.isEmpty ? '' : ' ($currency)'}',
        style: CellStyle.bold,
      ),
    ]);
    s.add([
      Cell(
        m.isPaid ? '${t['paidOn']} ${_date(m.paidAt!)}' : t['draft']!,
        style: m.isPaid ? CellStyle.normal : CellStyle.flagged,
      ),
    ]);
    final r = m.rules;
    s.add([
      Cell(
        '${t['rules']}: ${t['overtime']} ×${r.overtimeRate} · '
        '${t['dayOff']} ×${r.dayOffRate} · ${t['late']} ×${r.lateRate} · '
        '${t['early']} ×${r.earlyLeaveRate} · '
        '${t['dayWage']} = ${t['salaryOver30']}',
        style: CellStyle.muted,
      ),
    ]);
    s.addBlank();

    const headers = [
      'employee', 'wageType', 'wage', 'daysWorked', 'absentDays', 'base', //
      'overtimeHours', 'overtimePay', 'dayOffHours', 'dayOffPay', //
      'lateMinutes', 'lateCut', 'earlyMinutes', 'earlyCut', 'absenceCut', //
      'bonuses', 'deductions', 'advances', 'net', 'note',
    ];
    s.add([for (final h in headers) Cell(t[h]!, style: CellStyle.header)]);

    for (final p in m.slips) {
      final flagged = !p.hasWage || p.daysNeedingReview > 0;
      final style = flagged ? CellStyle.flagged : CellStyle.normal;
      Cell n(num v) => Cell.number(v, style: style);
      s.add([
        Cell(p.name, style: style),
        Cell(p.wage == null ? '' : t[p.wage!.kind.name]!, style: style),
        n(p.wage?.amount ?? 0),
        n(p.daysWorked),
        n(p.paid.absentDays),
        n(p.basePay),
        n(_hours(p.paid.overtimeMinutes)),
        n(p.overtimePay),
        n(_hours(p.paid.dayOffMinutes)),
        n(p.dayOffPay),
        n(p.paid.lateMinutes),
        n(p.lateDeduction),
        n(p.paid.earlyLeaveMinutes),
        n(p.earlyLeaveDeduction),
        n(p.absenceDeduction),
        n(p.bonuses),
        n(p.deductions),
        n(p.advances),
        Cell.number(p.net, style: flagged ? style : CellStyle.bold),
        Cell(_note(p, t), style: style),
      ]);
    }

    s.addBlank();
    double sum(double Function(Payslip) f) =>
        double.parse(m.slips.fold(0.0, (a, p) => a + f(p)).toStringAsFixed(2));
    Cell b(num v) => Cell.number(v, style: CellStyle.bold);
    s.add([
      Cell(t['total']!, style: CellStyle.bold),
      Cell.empty,
      Cell.empty,
      Cell.empty,
      Cell.empty,
      b(sum((p) => p.basePay)),
      Cell.empty,
      b(sum((p) => p.overtimePay)),
      Cell.empty,
      b(sum((p) => p.dayOffPay)),
      Cell.empty,
      b(sum((p) => p.lateDeduction)),
      Cell.empty,
      b(sum((p) => p.earlyLeaveDeduction)),
      b(sum((p) => p.absenceDeduction)),
      b(sum((p) => p.bonuses)),
      b(sum((p) => p.deductions)),
      b(sum((p) => p.advances)),
      b(m.totalNet),
    ]);

    if (m.slips.any((p) => !p.hasWage || p.daysNeedingReview > 0)) {
      s.addBlank();
      s.add([Cell(t['reviewNote']!)]);
    }
    return s;
  }

  static Sheet _adjustments(PayrollMonth m, Map<String, String> t, bool ar) {
    final s = Sheet(
      t['adjustments']!,
      rightToLeft: ar,
      columnWidths: const [26, 14, 12, 40],
    );
    s.add([
      Cell(t['employee']!, style: CellStyle.header),
      Cell(t['type']!, style: CellStyle.header),
      Cell(t['amount']!, style: CellStyle.header),
      Cell(t['noteCol']!, style: CellStyle.header),
    ]);
    for (final p in m.slips) {
      for (final a in p.adjustments) {
        s.add([
          Cell(p.name),
          Cell(t[a.kind.name]!),
          Cell.number(a.amount),
          Cell(a.note),
        ]);
      }
    }
    return s;
  }

  static String _note(Payslip p, Map<String, String> t) {
    final parts = <String>[];
    if (!p.hasWage) parts.add(t['noWage']!);
    if (p.edited) parts.add(t['edited']!);
    if (p.daysNeedingReview > 0) parts.add(t['needsReview']!);
    return parts.join(' · ');
  }

  static double _hours(int minutes) =>
      double.parse((minutes / 60).toStringAsFixed(2));

  static String _date(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';

  static const _en = {
    'title': 'Salaries',
    'payroll': 'Payroll',
    'adjustments': 'Adjustments',
    'paidOn': 'Paid on',
    'draft': 'Draft — not marked paid. Figures can still change.',
    'rules': 'Rules',
    'dayWage': 'day wage',
    'salaryOver30': 'monthly salary ÷ 30',
    'employee': 'Employee',
    'wageType': 'Paid',
    'wage': 'Wage',
    'monthly': 'Monthly',
    'daily': 'Daily',
    'hourly': 'Hourly',
    'daysWorked': 'Days worked',
    'absentDays': 'Absent days',
    'base': 'Base pay',
    'overtime': 'Overtime',
    'overtimeHours': 'Overtime h',
    'overtimePay': 'Overtime pay',
    'dayOff': 'Day off',
    'dayOffHours': 'Day-off h',
    'dayOffPay': 'Day-off pay',
    'late': 'Late',
    'lateMinutes': 'Late min',
    'lateCut': 'Late cut',
    'early': 'Early leave',
    'earlyMinutes': 'Early min',
    'earlyCut': 'Early leave cut',
    'absenceCut': 'Absence cut',
    'bonuses': 'Bonuses',
    'deductions': 'Deductions',
    'advances': 'Advances',
    'net': 'Net pay',
    'note': 'Note',
    'total': 'Total',
    'type': 'Type',
    'amount': 'Amount',
    'noteCol': 'Note',
    'bonus': 'Bonus',
    'deduction': 'Deduction',
    'advance': 'Advance',
    'noWage': 'No wage set',
    'edited': 'Edited by manager',
    'needsReview': 'Days need review',
    'reviewNote':
        'Shaded rows have no wage set or rest on days with missing punches or unverified times. Check them before paying.',
  };

  static const _ar = {
    'title': 'الرواتب',
    'payroll': 'الرواتب',
    'adjustments': 'الإضافات والخصومات',
    'paidOn': 'تم الصرف في',
    'draft': 'مسودة — لم يتم الصرف بعد. قد تتغير الأرقام.',
    'rules': 'القواعد',
    'dayWage': 'أجر اليوم',
    'salaryOver30': 'الراتب الشهري ÷ 30',
    'employee': 'الموظف',
    'wageType': 'نوع الأجر',
    'wage': 'الأجر',
    'monthly': 'شهري',
    'daily': 'يومي',
    'hourly': 'بالساعة',
    'daysWorked': 'أيام العمل',
    'absentDays': 'أيام الغياب',
    'base': 'الأجر الأساسي',
    'overtime': 'إضافي',
    'overtimeHours': 'ساعات إضافية',
    'overtimePay': 'أجر الإضافي',
    'dayOff': 'يوم الراحة',
    'dayOffHours': 'ساعات يوم الراحة',
    'dayOffPay': 'أجر يوم الراحة',
    'late': 'التأخير',
    'lateMinutes': 'دقائق التأخير',
    'lateCut': 'خصم التأخير',
    'early': 'الخروج المبكر',
    'earlyMinutes': 'دقائق الخروج المبكر',
    'earlyCut': 'خصم الخروج المبكر',
    'absenceCut': 'خصم الغياب',
    'bonuses': 'مكافآت',
    'deductions': 'خصومات',
    'advances': 'سلف',
    'net': 'صافي الراتب',
    'note': 'ملاحظة',
    'total': 'الإجمالي',
    'type': 'النوع',
    'amount': 'المبلغ',
    'noteCol': 'ملاحظة',
    'bonus': 'مكافأة',
    'deduction': 'خصم',
    'advance': 'سلفة',
    'noWage': 'لم يحدد الأجر',
    'edited': 'معدل من المدير',
    'needsReview': 'أيام بحاجة لمراجعة',
    'reviewNote':
        'الصفوف المظللة بدون أجر محدد أو تعتمد على أيام بتسجيلات ناقصة أو أوقات غير مؤكدة. راجعها قبل الصرف.',
  };
}
