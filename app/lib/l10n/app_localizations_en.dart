// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'Attendance';

  @override
  String get navDashboard => 'Dashboard';

  @override
  String get navEmployees => 'Employees';

  @override
  String get navEvents => 'Events';

  @override
  String get navSettings => 'Settings';

  @override
  String get connect => 'Connect';

  @override
  String get findDevice => 'Find device';

  @override
  String get scanning => 'Scanning the network...';

  @override
  String get deviceFound => 'Found the terminal';

  @override
  String get deviceNotFound => 'No terminal found on this network';

  @override
  String get disconnect => 'Disconnect';

  @override
  String get connected => 'Connected';

  @override
  String get disconnected => 'Not connected';

  @override
  String get deviceAddress => 'Device address';

  @override
  String get deviceToken => 'Device token';

  @override
  String get deviceAddressHint => '192.168.137.245';

  @override
  String get save => 'Save';

  @override
  String get retry => 'Retry';

  @override
  String get cancel => 'Cancel';

  @override
  String get add => 'Add';

  @override
  String get delete => 'Delete';

  @override
  String get refresh => 'Refresh';

  @override
  String get statusOnline => 'Online';

  @override
  String get statusOffline => 'Offline';

  @override
  String get uptime => 'Uptime';

  @override
  String get firmware => 'Firmware';

  @override
  String get board => 'Board';

  @override
  String get freeMemory => 'Free memory';

  @override
  String get clock => 'Clock';

  @override
  String get clockUnset => 'Not set';

  @override
  String get clockSourceNtp => 'Internet time';

  @override
  String get clockSourcePc => 'Set by this PC';

  @override
  String get clockSourceRestored => 'Restored (unverified)';

  @override
  String get syncClock => 'Sync clock';

  @override
  String get eventsStored => 'Events stored';

  @override
  String get eventsPending => 'Awaiting sync';

  @override
  String get eventsCapacity => 'Capacity';

  @override
  String get bufferFull => 'Buffer overflowed - oldest events were lost';

  @override
  String get employeeId => 'Employee ID';

  @override
  String get employeeName => 'Name';

  @override
  String get fingersEnrolled => 'Fingers';

  @override
  String get lastDirection => 'Last punch';

  @override
  String get failedReads => 'Failed reads';

  @override
  String get active => 'Active';

  @override
  String get addEmployee => 'Add employee';

  @override
  String get enrollFinger => 'Enrol finger';

  @override
  String get noEmployees => 'No employees yet';

  @override
  String get enrollPlaceFinger => 'Place finger on the sensor';

  @override
  String get enrollLiftFinger => 'Lift your finger';

  @override
  String get enrollPlaceAgain => 'Place the same finger again';

  @override
  String get enrollSaving => 'Saving...';

  @override
  String get enrollStored => 'Enrolled successfully';

  @override
  String get enrollFailed => 'Enrolment failed';

  @override
  String get directionIn => 'In';

  @override
  String get directionOut => 'Out';

  @override
  String get methodFinger => 'Fingerprint';

  @override
  String get methodManual => 'Manual';

  @override
  String get methodPin => 'PIN';

  @override
  String get provisionalTime => 'Time unverified';

  @override
  String get noEvents => 'No events recorded';

  @override
  String get time => 'Time';

  @override
  String get employee => 'Employee';

  @override
  String get direction => 'Direction';

  @override
  String get method => 'Method';

  @override
  String get language => 'Language';

  @override
  String get english => 'English';

  @override
  String get arabic => 'العربية';

  @override
  String get connectionFailed => 'Could not reach the device';

  @override
  String get checkAddressAndToken =>
      'Check the address and token, and that the terminal is powered on.';

  @override
  String get navDevice => 'Device';

  @override
  String get displayLanguage => 'Display language';

  @override
  String get clockFormat => 'Clock format';

  @override
  String get hour24 => '24-hour';

  @override
  String get hour12 => '12-hour';

  @override
  String get showSeconds => 'Show seconds';

  @override
  String get timezoneOffset => 'Time offset from UTC';

  @override
  String get brightness => 'Brightness';

  @override
  String get buzzerSound => 'Buzzer';

  @override
  String get duplicateWindow => 'Ignore repeat scans within';

  @override
  String get dimAfter => 'Dim screen after';

  @override
  String get blankAfter => 'Blank screen after';

  @override
  String get seconds => 'seconds';

  @override
  String get minutes => 'minutes';

  @override
  String get never => 'Never';

  @override
  String get burnInWarning =>
      'Leaving the screen always on will burn the display in over time.';

  @override
  String get fingerDetectWire => 'Sensor wake wire connected';

  @override
  String get fingerDetectHelp =>
      'Turn off if the sensor\'s blue and yellow wires are not connected. The device will poll instead, and the sensor LED will flash.';

  @override
  String get pushStrings => 'Send text to device';

  @override
  String get pushStringsHelp =>
      'The terminal has no Arabic font, so on-screen text is rendered here and uploaded.';

  @override
  String get pushing => 'Sending...';

  @override
  String get stringsSent => 'Text sent to the device';

  @override
  String get stringsMissing => 'The device has no text yet - send it';

  @override
  String get applyToDevice => 'Apply';

  @override
  String get deviceSettings => 'Terminal settings';

  @override
  String get saved => 'Saved';

  @override
  String get ethResets => 'Network recoveries';

  @override
  String get dangerZone => 'Clear the device';

  @override
  String get clearEvents => 'Clear attendance log';

  @override
  String get clearEventsHelp =>
      'Erases all punches stored on the terminal. Records already synced to this PC are kept.';

  @override
  String get clearFingerprints => 'Clear fingerprints';

  @override
  String get clearFingerprintsHelp =>
      'Deletes every enrolled fingerprint and employee from the terminal. Staff will need to enrol again.';

  @override
  String get clearConfig => 'Reset settings';

  @override
  String get clearConfigHelp =>
      'Restores factory settings and removes the uploaded on-screen text.';

  @override
  String get clearAll => 'Clear everything';

  @override
  String get confirmClear => 'This cannot be undone. Type CLEAR to confirm.';

  @override
  String get clearedOk => 'Device cleared';

  @override
  String get typeToConfirm => 'CLEAR';

  @override
  String get appearance => 'Appearance';

  @override
  String get themeSystem => 'System';

  @override
  String get themeLight => 'Light';

  @override
  String get themeDark => 'Dark';

  @override
  String get searching => 'Looking for the device...';

  @override
  String get syncing => 'Syncing';

  @override
  String get lastSync => 'Last sync';

  @override
  String get never2 => 'Never';

  @override
  String get searchingNetwork => 'Searching for the terminal';

  @override
  String get enterManually => 'Enter the address manually';

  @override
  String get tokenNeeded => 'Enter the device token to finish connecting';

  @override
  String get tokenWhere =>
      'It is printed in the terminal\'s startup log, on the line beginning \"api: listening\".';

  @override
  String get notFoundHelp =>
      'Make sure the terminal is powered on and on the same network as this computer.';

  @override
  String get touchButtonWired => 'Touch button connected';

  @override
  String get touchButtonHelp =>
      'Turn off if the TTP223 touch button is not wired. An unconnected input floats and flips the IN/OUT override on its own.';

  @override
  String get navTimesheet => 'Timesheet';

  @override
  String get hoursWorked => 'Hours worked';

  @override
  String get lateOccasions => 'Late arrivals';

  @override
  String get absences => 'Absences';

  @override
  String get needsReview => 'Needs review';

  @override
  String get daysPresent => 'Days present';

  @override
  String get overtime => 'Overtime';

  @override
  String get earlyLeave => 'Early leave';

  @override
  String get statusPresent => 'Present';

  @override
  String get statusAbsent => 'Absent';

  @override
  String get statusIncomplete => 'Incomplete';

  @override
  String get statusOff => 'Day off';

  @override
  String get noTimesheetData => 'No employees yet';

  @override
  String get reviewHint =>
      'Missing punches or unverified times. Check before using these figures.';

  @override
  String get previousMonth => 'Previous month';

  @override
  String get nextMonth => 'Next month';

  @override
  String get totalsFor => 'Totals';

  @override
  String get perEmployee => 'By employee';

  @override
  String get backToList => 'Back';

  @override
  String get shiftLabel => 'Shift';

  @override
  String get noShift => 'Not scheduled';

  @override
  String get schedules => 'Shifts';

  @override
  String get addShift => 'Add shift';

  @override
  String get editShift => 'Edit shift';

  @override
  String get shiftName => 'Shift name';

  @override
  String get shiftsHint =>
      'The timesheet is only as accurate as these. \"Late\" and \"absent\" are measured against them.';

  @override
  String get fixedHours => 'Fixed hours';

  @override
  String get flexibleHours => 'Flexible';

  @override
  String get fixedHint =>
      'Set start and end times. Lateness and early leave are measured.';

  @override
  String get flexibleHint =>
      'Only the daily total counts. No start time, so nobody is ever late.';

  @override
  String get startTime => 'Start';

  @override
  String get endTime => 'End';

  @override
  String get crossesMidnight => 'Ends the next day — a night shift.';

  @override
  String get breakLabel => 'Break';

  @override
  String get grace => 'grace';

  @override
  String get graceIn => 'Late grace';

  @override
  String get graceOut => 'Early leave grace';

  @override
  String get requiredPerDay => 'Required per day';

  @override
  String get perDay => 'per day';

  @override
  String get minutesShort => 'min';

  @override
  String get workingDays => 'Working days';

  @override
  String get weekendHint =>
      'Unselected days are the weekend. Works for Fri/Sat or Sat/Sun alike.';

  @override
  String get defaultShift => 'Default';

  @override
  String get makeDefault => 'Make default';

  @override
  String get assignTo => 'Assign to';

  @override
  String get assignHint =>
      'Selected employees use this shift instead of the default.';

  @override
  String get cannotDeleteLastShift => 'At least one shift must remain';

  @override
  String get deleteShiftHint =>
      'Anyone assigned to it falls back to the default shift.';

  @override
  String get exportXlsx => 'Export to Excel';

  @override
  String get exported => 'Report saved';

  @override
  String get exporting => 'Building report...';

  @override
  String get tokenRejected =>
      'The device rejected this token. Copy it again from the terminal\'s startup log.';

  @override
  String get tokenRejectedShort => 'Wrong token';

  @override
  String get employeesOffline =>
      'The terminal is not reachable. Showing the staff list saved on this PC; changes need the terminal.';

  @override
  String get removedEmployees => 'Former employees';

  @override
  String get removedHint => 'Kept for past reports';

  @override
  String get restore => 'Restore';

  @override
  String get restored => 'Restored to the terminal';

  @override
  String get sentToTerminal => 'Sent to the terminal';

  @override
  String get deleteEmployeeHint =>
      'Removes them and their fingerprints from the terminal. Their attendance history stays in past reports.';

  @override
  String get noFingers => 'No fingerprint';

  @override
  String get onSite => 'At work';

  @override
  String get offSite => 'Not at work';

  @override
  String get notOnTerminal =>
      'Not on the terminal. They cannot clock in until sent.';

  @override
  String get sendToTerminal => 'Send to terminal';

  @override
  String get editEmployee => 'Edit employee';

  @override
  String get invalidEmployeeId => 'Enter a number from 1 to 65535';

  @override
  String get idInUse => 'This ID is already in use';

  @override
  String get nameRequired => 'Enter a name';

  @override
  String get employeeIdHelp => 'Cannot be changed later';

  @override
  String get jobTitle => 'Job title (optional)';

  @override
  String get enrollStarting => 'Starting...';

  @override
  String get ok => 'OK';

  @override
  String get syncNow => 'Sync now';

  @override
  String get addPunch => 'Add punch';

  @override
  String get allEmployees => 'All employees';

  @override
  String get anyDate => 'Any date';

  @override
  String get clearFilters => 'Clear';

  @override
  String get punchAdded => 'Punch added';

  @override
  String get corrected => 'Corrected';

  @override
  String get reason => 'Reason';

  @override
  String get reasonHint => 'e.g. fingerprint would not read';

  @override
  String get reasonRequired =>
      'A reason is required. It is kept in the audit log.';

  @override
  String get futureNotAllowed => 'That time is in the future';

  @override
  String get manualPunchHint =>
      'For when a finger will not read. Manual punches are marked in every report.';

  @override
  String get recordedTime => 'Recorded';

  @override
  String get provisionalExplained =>
      'The terminal\'s clock was not verified when this was recorded. Correct the time if it is wrong.';

  @override
  String get changeTime => 'Change time';

  @override
  String get correctTime => 'Correct the time';

  @override
  String get removeCorrection => 'Remove correction';

  @override
  String get statusUpcoming => 'Upcoming';

  @override
  String get statusAtWork => 'At work';

  @override
  String get terminalMode => 'Each scan records';

  @override
  String get modeCheckIn => 'Check in';

  @override
  String get modeCheckOut => 'Check out';

  @override
  String get modeAuto => 'Alternate';

  @override
  String get modeFixedHelp =>
      'Every scan records the same direction, and the screen says which. Use one terminal per door, or switch it at closing time.';

  @override
  String get modeAutoHelp =>
      'Each employee alternates: first scan in, next out. The screen cannot show which comes next.';

  @override
  String showingLatest(int count) {
    return 'Showing the latest $count punches. Filter by employee or date to see older ones.';
  }

  @override
  String get hoursAbbr => 'h';

  @override
  String get minutesAbbr => 'm';

  @override
  String get ofTotal => 'of';

  @override
  String get lowest => 'lowest';

  @override
  String get daysAbbr => 'd';

  @override
  String get navPayroll => 'Payroll';

  @override
  String get payRules => 'Pay rules';

  @override
  String get payRulesHint =>
      'Day wage = monthly salary ÷ 30. Hourly rate = day wage ÷ the employee\'s usual shift hours.';

  @override
  String get totalNet => 'Total net pay';

  @override
  String get additionsLabel => 'Overtime & bonuses';

  @override
  String get cutsLabel => 'Cuts & advances';

  @override
  String get withoutWage => 'Without a wage';

  @override
  String get noWageSet => 'No wage set';

  @override
  String noWageHint(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          '$count employees have no wage set and are paid nothing this month.',
      one: '1 employee has no wage set and is paid nothing this month.',
    );
    return '$_temp0';
  }

  @override
  String get setWage => 'Set wage';

  @override
  String get wage => 'Wage';

  @override
  String get wageMonthly => 'Monthly salary';

  @override
  String get wageDaily => 'Per day';

  @override
  String get wageHourly => 'Per hour';

  @override
  String get amount => 'Amount';

  @override
  String get invalidAmount => 'Enter an amount';

  @override
  String wageFromMonth(String month) {
    return 'Applies from $month onward. Earlier months keep the wage they had.';
  }

  @override
  String get dayRate => 'Day wage';

  @override
  String get hourRate => 'Hourly rate';

  @override
  String get basePay => 'Base pay';

  @override
  String get overtimePay => 'Overtime';

  @override
  String get dayOffPay => 'Work on days off';

  @override
  String get lateCut => 'Late arrivals';

  @override
  String get earlyCut => 'Early leave';

  @override
  String get absenceCut => 'Absences';

  @override
  String get bonus => 'Bonus';

  @override
  String get deduction => 'Deduction';

  @override
  String get advance => 'Advance';

  @override
  String get adjustmentsTitle => 'Bonuses, deductions and advances';

  @override
  String get noAdjustments => 'None this month';

  @override
  String get note => 'Note';

  @override
  String get noteRequired => 'Enter a note. It is kept in the audit log.';

  @override
  String get netPay => 'Net pay';

  @override
  String clockFigure(String value) {
    return 'Clock: $value';
  }

  @override
  String get editedPill => 'Edited';

  @override
  String get editFigure => 'Edit';

  @override
  String get useClockFigure => 'Use clock figure';

  @override
  String get hoursUnit => 'hours';

  @override
  String get daysUnit => 'days';

  @override
  String get excuseHint =>
      'Lower the absent days to excuse an absence, e.g. sick leave.';

  @override
  String get hourlyNoCuts =>
      'Paid by the hour: time not worked is already unpaid, so lateness and absences are not cut again.';

  @override
  String get dailyAbsenceNote =>
      'Paid per day attended. Absent days are unpaid.';

  @override
  String get markPaid => 'Mark month as paid';

  @override
  String markPaidTitle(String month) {
    return 'Mark $month as paid?';
  }

  @override
  String get markPaidBody =>
      'The figures will be frozen. Later punch corrections and wage or rule changes will not change what was paid. You can reopen the month if you need to.';

  @override
  String get monthNotOver => 'This month is not over yet. Figures are so far.';

  @override
  String paidBanner(String date) {
    return 'Paid on $date. These figures are frozen.';
  }

  @override
  String get reopen => 'Reopen';

  @override
  String get reopenBody =>
      'The month will be recalculated from current data, which may differ from what was paid.';

  @override
  String get monthClosed =>
      'This month has been paid. Reopen it to make changes.';

  @override
  String get currency => 'Currency';

  @override
  String get currencyHint => 'e.g. EGP';

  @override
  String get overtimeRate => 'Overtime rate';

  @override
  String get dayOffRate => 'Day-off rate';

  @override
  String get lateRate => 'Late minute cut';

  @override
  String get earlyRate => 'Early leave minute cut';

  @override
  String get rateHint => '× the hourly rate. 0 turns it off.';

  @override
  String get deductAbsence => 'Deduct a day\'s wage for each absence';

  @override
  String get minOvertime => 'Ignore daily overtime shorter than';

  @override
  String get appPassword => 'App password';

  @override
  String get appPasswordHint => 'Asked for every time the app opens.';

  @override
  String get appPasswordOff =>
      'No password. Anyone at this computer can open the app.';

  @override
  String get setPassword => 'Set password';

  @override
  String get changePassword => 'Change password';

  @override
  String get removePassword => 'Remove password';

  @override
  String get currentPassword => 'Current password';

  @override
  String get newPassword => 'New password';

  @override
  String get confirmPassword => 'Repeat the new password';

  @override
  String get password => 'Password';

  @override
  String get enterPassword => 'Enter the password to continue';

  @override
  String get unlock => 'Unlock';

  @override
  String get lockApp => 'Lock';

  @override
  String get wrongPassword => 'Wrong password';

  @override
  String get passwordTooShort => 'Use at least 4 characters';

  @override
  String get passwordsDontMatch => 'The passwords do not match';

  @override
  String get passwordSaved => 'Password saved';

  @override
  String get passwordRemoved => 'Password removed';

  @override
  String get tgTitle => 'Telegram alerts';

  @override
  String get tgTileHelp =>
      'Check-ins, late arrivals and a daily summary, sent by the terminal';

  @override
  String get tgIntro =>
      'The terminal sends these itself, so they keep arriving with this computer off. It judges lateness against the shifts this app sends it on every sync, two weeks ahead.';

  @override
  String get tgActive => 'Active. The terminal is sending alerts.';

  @override
  String get tgNotActive =>
      'Not active. Set a bot and chat below, and switch alerts on.';

  @override
  String tgCounters(int sent, int failed, int dropped) {
    return 'Sent $sent · failed attempts $failed · gave up $dropped';
  }

  @override
  String tgLastError(String error) {
    return 'Last problem: $error';
  }

  @override
  String get tgNoRoster =>
      'The terminal has no schedule yet, so it cannot tell who is late. It gets one on the next sync after saving.';

  @override
  String tgRoster(int names, String from, String to) {
    return 'Schedule on the terminal: $names names, $from to $to';
  }

  @override
  String get tgStepBot => '1. Bot';

  @override
  String get tgStepBotHelp =>
      'In Telegram, open @BotFather, send /newbot and follow the steps. It gives you a token: paste it here.';

  @override
  String get tgBotToken => 'Bot token';

  @override
  String tgTokenSet(String hint) {
    return 'A token ending in …$hint is set. Leave empty to keep it.';
  }

  @override
  String get tgTokenInvalid =>
      'That does not look like a bot token (123456789:AA…)';

  @override
  String get tgTokenNeededForFind => 'Paste the bot token first';

  @override
  String get tgCheckToken => 'Check token';

  @override
  String get tgStepChat => '2. Where to send';

  @override
  String get tgStepChatHelp =>
      'Open your new bot in Telegram and send it /start (or add it to a group and send a message there), then click Find.';

  @override
  String get tgChatId => 'Chat ID';

  @override
  String get tgFindChat => 'Find';

  @override
  String get tgNoChats =>
      'No messages to the bot yet. Send it /start in Telegram, then click Find again.';

  @override
  String get tgStepWhat => '3. What to send';

  @override
  String get tgEnabled => 'Send alerts';

  @override
  String get tgEachPunch => 'Every check-in and check-out';

  @override
  String get tgEachPunchHelp =>
      'One message per scan. Can be a lot with many staff.';

  @override
  String get tgLate => 'Late arrivals';

  @override
  String get tgLateHelp =>
      'When the first check-in of the day is past the shift\'s grace period.';

  @override
  String get tgSummary => 'Daily summary';

  @override
  String get tgSummaryHelp =>
      'Who came, who was late, who is absent, who has not checked out.';

  @override
  String tgSummaryAt(String time) {
    return 'Send at $time';
  }

  @override
  String get tgSendTest => 'Send test message';

  @override
  String get tgSendSummary => 'Send summary now';

  @override
  String get tgQueued => 'Sent to the terminal. Checking delivery…';

  @override
  String get wifiTitle => 'Wi-Fi fallback';

  @override
  String get wifiTileHelp =>
      'Used only when the Ethernet cable is not connected';

  @override
  String get wifiIntro =>
      'Ethernet stays the main connection. If the cable has no connection for 20 seconds, the terminal joins this Wi-Fi network instead, and goes back to the cable once it has been working again for a minute. Set it now, while the app can reach the terminal.';

  @override
  String get wifiActiveEth => 'The terminal is on Ethernet.';

  @override
  String wifiActiveWifi(String ip) {
    return 'The terminal is on Wi-Fi at $ip (no Ethernet).';
  }

  @override
  String get wifiActiveNone => 'The terminal reports no connection.';

  @override
  String get wifiNotSet =>
      'No Wi-Fi network set. Without one, an unplugged cable means no connection.';

  @override
  String wifiStandby(String ssid) {
    return 'Standing by: will use \"$ssid\" if the cable is unplugged.';
  }

  @override
  String wifiConnecting(String ssid) {
    return 'Connecting to \"$ssid\"…';
  }

  @override
  String wifiConnected(String ssid, int rssi) {
    return 'Connected to \"$ssid\", signal $rssi dBm.';
  }

  @override
  String wifiFailed(String ssid, String error) {
    return 'Cannot connect to \"$ssid\": $error. Still retrying.';
  }

  @override
  String get wifiNetwork => 'Network';

  @override
  String get wifiSsid => 'Network name (SSID)';

  @override
  String get wifiScan => 'Scan';

  @override
  String get wifiScanning =>
      'The terminal is listening for networks. This takes a few seconds.';

  @override
  String get wifiNoneFound => 'No networks found near the terminal.';

  @override
  String get wifiOpen => 'open';

  @override
  String get wifiPassword => 'Password';

  @override
  String get wifiPasswordKeep =>
      'Type the password again when you change the network';

  @override
  String get wifiPasswordHelp =>
      'Leave empty only for an open network. The terminal never sends the password back.';

  @override
  String get wifiPasswordShort => 'A Wi-Fi password has at least 8 characters';

  @override
  String get wifiShowPassword => 'Show password';

  @override
  String get wifiForget => 'Forget network';

  @override
  String get wifiForgotten => 'Wi-Fi network forgotten';

  @override
  String get resetApp => 'Reset app';

  @override
  String get resetAppHint =>
      'Deletes everything this app keeps on this computer and starts again as if newly installed.';

  @override
  String get resetAppTitle => 'Reset the app?';

  @override
  String get resetAppBody =>
      'This permanently deletes from this computer:\n• every punch, including manual punches and edits\n• shifts, wages, payroll and payment history\n• the terminal\'s address and token, the app password and all settings\n\nExport any reports you need first.';

  @override
  String get resetAppKeeps =>
      'The terminal is not changed. Its employees and fingerprints stay on it, and punches it still holds are copied back when you connect again.';

  @override
  String get resetConfirmWord => 'RESET';

  @override
  String resetConfirmLabel(String word) {
    return 'Type $word to confirm';
  }
}
