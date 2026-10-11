import 'package:flutter_test/flutter_test.dart';

import 'package:attendance_admin/data/models.dart';

void main() {
  test('parses a punch event from the device', () {
    final e = PunchEvent.fromJson(const {
      'seq': 34,
      'epoch': 1766217600,
      'employee_id': 100,
      'slot': 0,
      'direction': 'out',
      'method': 'finger',
      'manual': false,
      'provisional_time': true,
    });

    expect(e.seq, 34);
    expect(e.employeeId, 100);
    expect(e.direction, PunchDirection.outbound);
    expect(e.method, PunchMethod.finger);
    expect(e.provisionalTime, isTrue);
  });

  test('an employee is present when their last punch was inbound', () {
    Employee at(String dir, int epoch) => Employee.fromJson({
          'employee_id': 1,
          'active': true,
          'last_direction': dir,
          'last_epoch': epoch,
          'fail_count': 0,
          'fingers': 2,
        });

    expect(at('in', 1766217600).isPresent, isTrue);
    expect(at('out', 1766217600).isPresent, isFalse);
    // Never punched: absent, not present-by-default.
    expect(at('in', 0).isPresent, isFalse);
  });

  test('unknown enrol states fall back to idle rather than throwing', () {
    final s = EnrollStatus.fromJson(const {
      'session_id': 7,
      'state': 'something_new_from_a_newer_firmware',
    });
    expect(s.state, EnrollState.idle);
    expect(s.isRunning, isFalse);
  });
}
