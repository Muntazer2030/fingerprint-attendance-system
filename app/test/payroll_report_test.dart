import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:attendance_admin/domain/attendance_rules.dart';
import 'package:attendance_admin/domain/payroll.dart';
import 'package:attendance_admin/domain/payroll_report.dart';
import 'package:attendance_admin/domain/timesheet.dart';

void main() {
  String part(List<int> bytes, String name) {
    final a = ZipDecoder().decodeBytes(bytes);
    final f = a.files.firstWhere((f) => f.name == name);
    return String.fromCharCodes(f.content as List<int>);
  }

  PayrollMonth month() {
    final sheet = Timesheet.build(
      employeeId: 1,
      name: 'سارة أحمد',
      from: DateTime(2026, 6, 1),
      to: DateTime(2026, 6, 30),
      resolver: ShiftResolver(storeDefault: const Shift(id: 1, name: 'Store')),
      punches: const [],
      now: DateTime(2026, 7, 15),
    );
    const rules = PayRules();
    return PayrollMonth(
      month: DateTime(2026, 6),
      rules: rules,
      slips: [
        Payroll.compute(
          sheet: sheet,
          wage: const Wage(kind: WageKind.monthly, amount: 3000),
          rules: rules,
          overrides: const PayOverrides(absentDays: 2),
          adjustments: const [
            PayAdjustment(
              kind: AdjustmentKind.advance,
              amount: 500,
              note: 'سلفة',
            ),
          ],
        ),
      ],
    );
  }

  test('the Arabic workbook is right to left with both sheets', () {
    final bytes = PayrollReport.build(
      payroll: month(),
      currency: 'ج.م',
      lang: 'ar',
    );
    final s1 = String.fromCharCodes(
      part(bytes, 'xl/worksheets/sheet1.xml').codeUnits,
    );
    expect(s1, contains('rightToLeft="1"'));
    expect(
      part(bytes, 'xl/worksheets/sheet2.xml'),
      contains('rightToLeft="1"'),
    );
  });

  test('net pay and the adjustment reach the file', () {
    final m = month();
    // 3000 - 2 excused-to absent days (200) - advance 500.
    expect(m.slips.single.net, 2300);
    final bytes = PayrollReport.build(payroll: m, currency: 'EGP');
    final s1 = part(bytes, 'xl/worksheets/sheet1.xml');
    expect(s1, contains('<v>2300.0</v>'));
    expect(s1, contains('Draft'));
    expect(part(bytes, 'xl/worksheets/sheet2.xml'), contains('<v>500.0</v>'));
  });

  test('a paid month says when it was paid', () {
    final live = month();
    final paid = PayrollMonth.fromSnapshot(
      live.month,
      DateTime(2026, 7, 2),
      live.toSnapshot('EGP'),
    );
    final bytes = PayrollReport.build(payroll: paid, currency: 'EGP');
    expect(
      part(bytes, 'xl/worksheets/sheet1.xml'),
      contains('Paid on 2026-07-02'),
    );
  });
}
