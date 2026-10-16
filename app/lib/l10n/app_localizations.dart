import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_ar.dart';
import 'app_localizations_en.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('ar'),
    Locale('en'),
  ];

  /// No description provided for @appTitle.
  ///
  /// In en, this message translates to:
  /// **'Attendance'**
  String get appTitle;

  /// No description provided for @navDashboard.
  ///
  /// In en, this message translates to:
  /// **'Dashboard'**
  String get navDashboard;

  /// No description provided for @navEmployees.
  ///
  /// In en, this message translates to:
  /// **'Employees'**
  String get navEmployees;

  /// No description provided for @navEvents.
  ///
  /// In en, this message translates to:
  /// **'Events'**
  String get navEvents;

  /// No description provided for @navSettings.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get navSettings;

  /// No description provided for @connect.
  ///
  /// In en, this message translates to:
  /// **'Connect'**
  String get connect;

  /// No description provided for @findDevice.
  ///
  /// In en, this message translates to:
  /// **'Find device'**
  String get findDevice;

  /// No description provided for @scanning.
  ///
  /// In en, this message translates to:
  /// **'Scanning the network...'**
  String get scanning;

  /// No description provided for @deviceFound.
  ///
  /// In en, this message translates to:
  /// **'Found the terminal'**
  String get deviceFound;

  /// No description provided for @deviceNotFound.
  ///
  /// In en, this message translates to:
  /// **'No terminal found on this network'**
  String get deviceNotFound;

  /// No description provided for @disconnect.
  ///
  /// In en, this message translates to:
  /// **'Disconnect'**
  String get disconnect;

  /// No description provided for @connected.
  ///
  /// In en, this message translates to:
  /// **'Connected'**
  String get connected;

  /// No description provided for @disconnected.
  ///
  /// In en, this message translates to:
  /// **'Not connected'**
  String get disconnected;

  /// No description provided for @deviceAddress.
  ///
  /// In en, this message translates to:
  /// **'Device address'**
  String get deviceAddress;

  /// No description provided for @deviceToken.
  ///
  /// In en, this message translates to:
  /// **'Device token'**
  String get deviceToken;

  /// No description provided for @deviceAddressHint.
  ///
  /// In en, this message translates to:
  /// **'192.168.137.245'**
  String get deviceAddressHint;

  /// No description provided for @save.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get save;

  /// No description provided for @retry.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get retry;

  /// No description provided for @cancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// No description provided for @add.
  ///
  /// In en, this message translates to:
  /// **'Add'**
  String get add;

  /// No description provided for @delete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get delete;

  /// No description provided for @refresh.
  ///
  /// In en, this message translates to:
  /// **'Refresh'**
  String get refresh;

  /// No description provided for @statusOnline.
  ///
  /// In en, this message translates to:
  /// **'Online'**
  String get statusOnline;

  /// No description provided for @statusOffline.
  ///
  /// In en, this message translates to:
  /// **'Offline'**
  String get statusOffline;

  /// No description provided for @uptime.
  ///
  /// In en, this message translates to:
  /// **'Uptime'**
  String get uptime;

  /// No description provided for @firmware.
  ///
  /// In en, this message translates to:
  /// **'Firmware'**
  String get firmware;

  /// No description provided for @board.
  ///
  /// In en, this message translates to:
  /// **'Board'**
  String get board;

  /// No description provided for @freeMemory.
  ///
  /// In en, this message translates to:
  /// **'Free memory'**
  String get freeMemory;

  /// No description provided for @clock.
  ///
  /// In en, this message translates to:
  /// **'Clock'**
  String get clock;

  /// No description provided for @clockUnset.
  ///
  /// In en, this message translates to:
  /// **'Not set'**
  String get clockUnset;

  /// No description provided for @clockSourceNtp.
  ///
  /// In en, this message translates to:
  /// **'Internet time'**
  String get clockSourceNtp;

  /// No description provided for @clockSourcePc.
  ///
  /// In en, this message translates to:
  /// **'Set by this PC'**
  String get clockSourcePc;

  /// No description provided for @clockSourceRestored.
  ///
  /// In en, this message translates to:
  /// **'Restored (unverified)'**
  String get clockSourceRestored;

  /// No description provided for @syncClock.
  ///
  /// In en, this message translates to:
  /// **'Sync clock'**
  String get syncClock;

  /// No description provided for @eventsStored.
  ///
  /// In en, this message translates to:
  /// **'Events stored'**
  String get eventsStored;

  /// No description provided for @eventsPending.
  ///
  /// In en, this message translates to:
  /// **'Awaiting sync'**
  String get eventsPending;

  /// No description provided for @eventsCapacity.
  ///
  /// In en, this message translates to:
  /// **'Capacity'**
  String get eventsCapacity;

  /// No description provided for @bufferFull.
  ///
  /// In en, this message translates to:
  /// **'Buffer overflowed - oldest events were lost'**
  String get bufferFull;

  /// No description provided for @employeeId.
  ///
  /// In en, this message translates to:
  /// **'Employee ID'**
  String get employeeId;

  /// No description provided for @employeeName.
  ///
  /// In en, this message translates to:
  /// **'Name'**
  String get employeeName;

  /// No description provided for @fingersEnrolled.
  ///
  /// In en, this message translates to:
  /// **'Fingers'**
  String get fingersEnrolled;

  /// No description provided for @lastDirection.
  ///
  /// In en, this message translates to:
  /// **'Last punch'**
  String get lastDirection;

  /// No description provided for @failedReads.
  ///
  /// In en, this message translates to:
  /// **'Failed reads'**
  String get failedReads;

  /// No description provided for @active.
  ///
  /// In en, this message translates to:
  /// **'Active'**
  String get active;

  /// No description provided for @addEmployee.
  ///
  /// In en, this message translates to:
  /// **'Add employee'**
  String get addEmployee;

  /// No description provided for @enrollFinger.
  ///
  /// In en, this message translates to:
  /// **'Enrol finger'**
  String get enrollFinger;

  /// No description provided for @noEmployees.
  ///
  /// In en, this message translates to:
  /// **'No employees yet'**
  String get noEmployees;

  /// No description provided for @enrollPlaceFinger.
  ///
  /// In en, this message translates to:
  /// **'Place finger on the sensor'**
  String get enrollPlaceFinger;

  /// No description provided for @enrollLiftFinger.
  ///
  /// In en, this message translates to:
  /// **'Lift your finger'**
  String get enrollLiftFinger;

  /// No description provided for @enrollPlaceAgain.
  ///
  /// In en, this message translates to:
  /// **'Place the same finger again'**
  String get enrollPlaceAgain;

  /// No description provided for @enrollSaving.
  ///
  /// In en, this message translates to:
  /// **'Saving...'**
  String get enrollSaving;

  /// No description provided for @enrollStored.
  ///
  /// In en, this message translates to:
  /// **'Enrolled successfully'**
  String get enrollStored;

  /// No description provided for @enrollFailed.
  ///
  /// In en, this message translates to:
  /// **'Enrolment failed'**
  String get enrollFailed;

  /// No description provided for @directionIn.
  ///
  /// In en, this message translates to:
  /// **'In'**
  String get directionIn;

  /// No description provided for @directionOut.
  ///
  /// In en, this message translates to:
  /// **'Out'**
  String get directionOut;

  /// No description provided for @methodFinger.
  ///
  /// In en, this message translates to:
  /// **'Fingerprint'**
  String get methodFinger;

  /// No description provided for @methodManual.
  ///
  /// In en, this message translates to:
  /// **'Manual'**
  String get methodManual;

  /// No description provided for @methodPin.
  ///
  /// In en, this message translates to:
  /// **'PIN'**
  String get methodPin;

  /// No description provided for @provisionalTime.
  ///
  /// In en, this message translates to:
  /// **'Time unverified'**
  String get provisionalTime;

  /// No description provided for @noEvents.
  ///
  /// In en, this message translates to:
  /// **'No events recorded'**
  String get noEvents;

  /// No description provided for @time.
  ///
  /// In en, this message translates to:
  /// **'Time'**
  String get time;

  /// No description provided for @employee.
  ///
  /// In en, this message translates to:
  /// **'Employee'**
  String get employee;

  /// No description provided for @direction.
  ///
  /// In en, this message translates to:
  /// **'Direction'**
  String get direction;

  /// No description provided for @method.
  ///
  /// In en, this message translates to:
  /// **'Method'**
  String get method;

  /// No description provided for @language.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get language;

  /// No description provided for @english.
  ///
  /// In en, this message translates to:
  /// **'English'**
  String get english;

  /// No description provided for @arabic.
  ///
  /// In en, this message translates to:
  /// **'العربية'**
  String get arabic;

  /// No description provided for @connectionFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not reach the device'**
  String get connectionFailed;

  /// No description provided for @checkAddressAndToken.
  ///
  /// In en, this message translates to:
  /// **'Check the address and token, and that the terminal is powered on.'**
  String get checkAddressAndToken;

  /// No description provided for @navDevice.
  ///
  /// In en, this message translates to:
  /// **'Device'**
  String get navDevice;

  /// No description provided for @displayLanguage.
  ///
  /// In en, this message translates to:
  /// **'Display language'**
  String get displayLanguage;

  /// No description provided for @clockFormat.
  ///
  /// In en, this message translates to:
  /// **'Clock format'**
  String get clockFormat;

  /// No description provided for @hour24.
  ///
  /// In en, this message translates to:
  /// **'24-hour'**
  String get hour24;

  /// No description provided for @hour12.
  ///
  /// In en, this message translates to:
  /// **'12-hour'**
  String get hour12;

  /// No description provided for @showSeconds.
  ///
  /// In en, this message translates to:
  /// **'Show seconds'**
  String get showSeconds;

  /// No description provided for @timezoneOffset.
  ///
  /// In en, this message translates to:
  /// **'Time offset from UTC'**
  String get timezoneOffset;

  /// No description provided for @brightness.
  ///
  /// In en, this message translates to:
  /// **'Brightness'**
  String get brightness;

  /// No description provided for @buzzerSound.
  ///
  /// In en, this message translates to:
  /// **'Buzzer'**
  String get buzzerSound;

  /// No description provided for @duplicateWindow.
  ///
  /// In en, this message translates to:
  /// **'Ignore repeat scans within'**
  String get duplicateWindow;

  /// No description provided for @dimAfter.
  ///
  /// In en, this message translates to:
  /// **'Dim screen after'**
  String get dimAfter;

  /// No description provided for @blankAfter.
  ///
  /// In en, this message translates to:
  /// **'Blank screen after'**
  String get blankAfter;

  /// No description provided for @seconds.
  ///
  /// In en, this message translates to:
  /// **'seconds'**
  String get seconds;

  /// No description provided for @minutes.
  ///
  /// In en, this message translates to:
  /// **'minutes'**
  String get minutes;

  /// No description provided for @never.
  ///
  /// In en, this message translates to:
  /// **'Never'**
  String get never;

  /// No description provided for @burnInWarning.
  ///
  /// In en, this message translates to:
  /// **'Leaving the screen always on will burn the display in over time.'**
  String get burnInWarning;

  /// No description provided for @fingerDetectWire.
  ///
  /// In en, this message translates to:
  /// **'Sensor wake wire connected'**
  String get fingerDetectWire;

  /// No description provided for @fingerDetectHelp.
  ///
  /// In en, this message translates to:
  /// **'Turn off if the sensor\'s blue and yellow wires are not connected. The device will poll instead, and the sensor LED will flash.'**
  String get fingerDetectHelp;

  /// No description provided for @pushStrings.
  ///
  /// In en, this message translates to:
  /// **'Send text to device'**
  String get pushStrings;

  /// No description provided for @pushStringsHelp.
  ///
  /// In en, this message translates to:
  /// **'The terminal has no Arabic font, so on-screen text is rendered here and uploaded.'**
  String get pushStringsHelp;

  /// No description provided for @pushing.
  ///
  /// In en, this message translates to:
  /// **'Sending...'**
  String get pushing;

  /// No description provided for @stringsSent.
  ///
  /// In en, this message translates to:
  /// **'Text sent to the device'**
  String get stringsSent;

  /// No description provided for @stringsMissing.
  ///
  /// In en, this message translates to:
  /// **'The device has no text yet - send it'**
  String get stringsMissing;

  /// No description provided for @applyToDevice.
  ///
  /// In en, this message translates to:
  /// **'Apply'**
  String get applyToDevice;

  /// No description provided for @deviceSettings.
  ///
  /// In en, this message translates to:
  /// **'Terminal settings'**
  String get deviceSettings;

  /// No description provided for @saved.
  ///
  /// In en, this message translates to:
  /// **'Saved'**
  String get saved;

  /// No description provided for @ethResets.
  ///
  /// In en, this message translates to:
  /// **'Network recoveries'**
  String get ethResets;

  /// No description provided for @dangerZone.
  ///
  /// In en, this message translates to:
  /// **'Clear the device'**
  String get dangerZone;

  /// No description provided for @clearEvents.
  ///
  /// In en, this message translates to:
  /// **'Clear attendance log'**
  String get clearEvents;

  /// No description provided for @clearEventsHelp.
  ///
  /// In en, this message translates to:
  /// **'Erases all punches stored on the terminal. Records already synced to this PC are kept.'**
  String get clearEventsHelp;

  /// No description provided for @clearFingerprints.
  ///
  /// In en, this message translates to:
  /// **'Clear fingerprints'**
  String get clearFingerprints;

  /// No description provided for @clearFingerprintsHelp.
  ///
  /// In en, this message translates to:
  /// **'Deletes every enrolled fingerprint and employee from the terminal. Staff will need to enrol again.'**
  String get clearFingerprintsHelp;

  /// No description provided for @clearConfig.
  ///
  /// In en, this message translates to:
  /// **'Reset settings'**
  String get clearConfig;

  /// No description provided for @clearConfigHelp.
  ///
  /// In en, this message translates to:
  /// **'Restores factory settings and removes the uploaded on-screen text.'**
  String get clearConfigHelp;

  /// No description provided for @clearAll.
  ///
  /// In en, this message translates to:
  /// **'Clear everything'**
  String get clearAll;

  /// No description provided for @confirmClear.
  ///
  /// In en, this message translates to:
  /// **'This cannot be undone. Type CLEAR to confirm.'**
  String get confirmClear;

  /// No description provided for @clearedOk.
  ///
  /// In en, this message translates to:
  /// **'Device cleared'**
  String get clearedOk;

  /// No description provided for @typeToConfirm.
  ///
  /// In en, this message translates to:
  /// **'CLEAR'**
  String get typeToConfirm;

  /// No description provided for @appearance.
  ///
  /// In en, this message translates to:
  /// **'Appearance'**
  String get appearance;

  /// No description provided for @themeSystem.
  ///
  /// In en, this message translates to:
  /// **'System'**
  String get themeSystem;

  /// No description provided for @themeLight.
  ///
  /// In en, this message translates to:
  /// **'Light'**
  String get themeLight;

  /// No description provided for @themeDark.
  ///
  /// In en, this message translates to:
  /// **'Dark'**
  String get themeDark;

  /// No description provided for @searching.
  ///
  /// In en, this message translates to:
  /// **'Looking for the device...'**
  String get searching;

  /// No description provided for @syncing.
  ///
  /// In en, this message translates to:
  /// **'Syncing'**
  String get syncing;

  /// No description provided for @lastSync.
  ///
  /// In en, this message translates to:
  /// **'Last sync'**
  String get lastSync;

  /// No description provided for @never2.
  ///
  /// In en, this message translates to:
  /// **'Never'**
  String get never2;

  /// No description provided for @searchingNetwork.
  ///
  /// In en, this message translates to:
  /// **'Searching for the terminal'**
  String get searchingNetwork;

  /// No description provided for @enterManually.
  ///
  /// In en, this message translates to:
  /// **'Enter the address manually'**
  String get enterManually;

  /// No description provided for @tokenNeeded.
  ///
  /// In en, this message translates to:
  /// **'Enter the device token to finish connecting'**
  String get tokenNeeded;

  /// No description provided for @tokenWhere.
  ///
  /// In en, this message translates to:
  /// **'It is printed in the terminal\'s startup log, on the line beginning \"api: listening\".'**
  String get tokenWhere;

  /// No description provided for @notFoundHelp.
  ///
  /// In en, this message translates to:
  /// **'Make sure the terminal is powered on and on the same network as this computer.'**
  String get notFoundHelp;

  /// No description provided for @touchButtonWired.
  ///
  /// In en, this message translates to:
  /// **'Touch button connected'**
  String get touchButtonWired;

  /// No description provided for @touchButtonHelp.
  ///
  /// In en, this message translates to:
  /// **'Turn off if the TTP223 touch button is not wired. An unconnected input floats and flips the IN/OUT override on its own.'**
  String get touchButtonHelp;

  /// No description provided for @navTimesheet.
  ///
  /// In en, this message translates to:
  /// **'Timesheet'**
  String get navTimesheet;

  /// No description provided for @hoursWorked.
  ///
  /// In en, this message translates to:
  /// **'Hours worked'**
  String get hoursWorked;

  /// No description provided for @lateOccasions.
  ///
  /// In en, this message translates to:
  /// **'Late arrivals'**
  String get lateOccasions;

  /// No description provided for @absences.
  ///
  /// In en, this message translates to:
  /// **'Absences'**
  String get absences;

  /// No description provided for @needsReview.
  ///
  /// In en, this message translates to:
  /// **'Needs review'**
  String get needsReview;

  /// No description provided for @daysPresent.
  ///
  /// In en, this message translates to:
  /// **'Days present'**
  String get daysPresent;

  /// No description provided for @overtime.
  ///
  /// In en, this message translates to:
  /// **'Overtime'**
  String get overtime;

  /// No description provided for @earlyLeave.
  ///
  /// In en, this message translates to:
  /// **'Early leave'**
  String get earlyLeave;

  /// No description provided for @statusPresent.
  ///
  /// In en, this message translates to:
  /// **'Present'**
  String get statusPresent;

  /// No description provided for @statusAbsent.
  ///
  /// In en, this message translates to:
  /// **'Absent'**
  String get statusAbsent;

  /// No description provided for @statusIncomplete.
  ///
  /// In en, this message translates to:
  /// **'Incomplete'**
  String get statusIncomplete;

  /// No description provided for @statusOff.
  ///
  /// In en, this message translates to:
  /// **'Day off'**
  String get statusOff;

  /// No description provided for @noTimesheetData.
  ///
  /// In en, this message translates to:
  /// **'No employees yet'**
  String get noTimesheetData;

  /// No description provided for @reviewHint.
  ///
  /// In en, this message translates to:
  /// **'Missing punches or unverified times. Check before using these figures.'**
  String get reviewHint;

  /// No description provided for @previousMonth.
  ///
  /// In en, this message translates to:
  /// **'Previous month'**
  String get previousMonth;

  /// No description provided for @nextMonth.
  ///
  /// In en, this message translates to:
  /// **'Next month'**
  String get nextMonth;

  /// No description provided for @totalsFor.
  ///
  /// In en, this message translates to:
  /// **'Totals'**
  String get totalsFor;

  /// No description provided for @perEmployee.
  ///
  /// In en, this message translates to:
  /// **'By employee'**
  String get perEmployee;

  /// No description provided for @backToList.
  ///
  /// In en, this message translates to:
  /// **'Back'**
  String get backToList;

  /// No description provided for @shiftLabel.
  ///
  /// In en, this message translates to:
  /// **'Shift'**
  String get shiftLabel;

  /// No description provided for @noShift.
  ///
  /// In en, this message translates to:
  /// **'Not scheduled'**
  String get noShift;

  /// No description provided for @schedules.
  ///
  /// In en, this message translates to:
  /// **'Shifts'**
  String get schedules;

  /// No description provided for @addShift.
  ///
  /// In en, this message translates to:
  /// **'Add shift'**
  String get addShift;

  /// No description provided for @editShift.
  ///
  /// In en, this message translates to:
  /// **'Edit shift'**
  String get editShift;

  /// No description provided for @shiftName.
  ///
  /// In en, this message translates to:
  /// **'Shift name'**
  String get shiftName;

  /// No description provided for @shiftsHint.
  ///
  /// In en, this message translates to:
  /// **'The timesheet is only as accurate as these. \"Late\" and \"absent\" are measured against them.'**
  String get shiftsHint;

  /// No description provided for @fixedHours.
  ///
  /// In en, this message translates to:
  /// **'Fixed hours'**
  String get fixedHours;

  /// No description provided for @flexibleHours.
  ///
  /// In en, this message translates to:
  /// **'Flexible'**
  String get flexibleHours;

  /// No description provided for @fixedHint.
  ///
  /// In en, this message translates to:
  /// **'Set start and end times. Lateness and early leave are measured.'**
  String get fixedHint;

  /// No description provided for @flexibleHint.
  ///
  /// In en, this message translates to:
  /// **'Only the daily total counts. No start time, so nobody is ever late.'**
  String get flexibleHint;

  /// No description provided for @startTime.
  ///
  /// In en, this message translates to:
  /// **'Start'**
  String get startTime;

  /// No description provided for @endTime.
  ///
  /// In en, this message translates to:
  /// **'End'**
  String get endTime;

  /// No description provided for @crossesMidnight.
  ///
  /// In en, this message translates to:
  /// **'Ends the next day — a night shift.'**
  String get crossesMidnight;

  /// No description provided for @breakLabel.
  ///
  /// In en, this message translates to:
  /// **'Break'**
  String get breakLabel;

  /// No description provided for @grace.
  ///
  /// In en, this message translates to:
  /// **'grace'**
  String get grace;

  /// No description provided for @graceIn.
  ///
  /// In en, this message translates to:
  /// **'Late grace'**
  String get graceIn;

  /// No description provided for @graceOut.
  ///
  /// In en, this message translates to:
  /// **'Early leave grace'**
  String get graceOut;

  /// No description provided for @requiredPerDay.
  ///
  /// In en, this message translates to:
  /// **'Required per day'**
  String get requiredPerDay;

  /// No description provided for @perDay.
  ///
  /// In en, this message translates to:
  /// **'per day'**
  String get perDay;

  /// No description provided for @minutesShort.
  ///
  /// In en, this message translates to:
  /// **'min'**
  String get minutesShort;

  /// No description provided for @workingDays.
  ///
  /// In en, this message translates to:
  /// **'Working days'**
  String get workingDays;

  /// No description provided for @weekendHint.
  ///
  /// In en, this message translates to:
  /// **'Unselected days are the weekend. Works for Fri/Sat or Sat/Sun alike.'**
  String get weekendHint;

  /// No description provided for @defaultShift.
  ///
  /// In en, this message translates to:
  /// **'Default'**
  String get defaultShift;

  /// No description provided for @makeDefault.
  ///
  /// In en, this message translates to:
  /// **'Make default'**
  String get makeDefault;

  /// No description provided for @assignTo.
  ///
  /// In en, this message translates to:
  /// **'Assign to'**
  String get assignTo;

  /// No description provided for @assignHint.
  ///
  /// In en, this message translates to:
  /// **'Selected employees use this shift instead of the default.'**
  String get assignHint;

  /// No description provided for @cannotDeleteLastShift.
  ///
  /// In en, this message translates to:
  /// **'At least one shift must remain'**
  String get cannotDeleteLastShift;

  /// No description provided for @deleteShiftHint.
  ///
  /// In en, this message translates to:
  /// **'Anyone assigned to it falls back to the default shift.'**
  String get deleteShiftHint;

  /// No description provided for @exportXlsx.
  ///
  /// In en, this message translates to:
  /// **'Export to Excel'**
  String get exportXlsx;

  /// No description provided for @exported.
  ///
  /// In en, this message translates to:
  /// **'Report saved'**
  String get exported;

  /// No description provided for @exporting.
  ///
  /// In en, this message translates to:
  /// **'Building report...'**
  String get exporting;

  /// No description provided for @tokenRejected.
  ///
  /// In en, this message translates to:
  /// **'The device rejected this token. Copy it again from the terminal\'s startup log.'**
  String get tokenRejected;

  /// No description provided for @tokenRejectedShort.
  ///
  /// In en, this message translates to:
  /// **'Wrong token'**
  String get tokenRejectedShort;

  /// No description provided for @employeesOffline.
  ///
  /// In en, this message translates to:
  /// **'The terminal is not reachable. Showing the staff list saved on this PC; changes need the terminal.'**
  String get employeesOffline;

  /// No description provided for @removedEmployees.
  ///
  /// In en, this message translates to:
  /// **'Former employees'**
  String get removedEmployees;

  /// No description provided for @removedHint.
  ///
  /// In en, this message translates to:
  /// **'Kept for past reports'**
  String get removedHint;

  /// No description provided for @restore.
  ///
  /// In en, this message translates to:
  /// **'Restore'**
  String get restore;

  /// No description provided for @restored.
  ///
  /// In en, this message translates to:
  /// **'Restored to the terminal'**
  String get restored;

  /// No description provided for @sentToTerminal.
  ///
  /// In en, this message translates to:
  /// **'Sent to the terminal'**
  String get sentToTerminal;

  /// No description provided for @deleteEmployeeHint.
  ///
  /// In en, this message translates to:
  /// **'Removes them and their fingerprints from the terminal. Their attendance history stays in past reports.'**
  String get deleteEmployeeHint;

  /// No description provided for @noFingers.
  ///
  /// In en, this message translates to:
  /// **'No fingerprint'**
  String get noFingers;

  /// No description provided for @onSite.
  ///
  /// In en, this message translates to:
  /// **'At work'**
  String get onSite;

  /// No description provided for @offSite.
  ///
  /// In en, this message translates to:
  /// **'Not at work'**
  String get offSite;

  /// No description provided for @notOnTerminal.
  ///
  /// In en, this message translates to:
  /// **'Not on the terminal. They cannot clock in until sent.'**
  String get notOnTerminal;

  /// No description provided for @sendToTerminal.
  ///
  /// In en, this message translates to:
  /// **'Send to terminal'**
  String get sendToTerminal;

  /// No description provided for @editEmployee.
  ///
  /// In en, this message translates to:
  /// **'Edit employee'**
  String get editEmployee;

  /// No description provided for @invalidEmployeeId.
  ///
  /// In en, this message translates to:
  /// **'Enter a number from 1 to 65535'**
  String get invalidEmployeeId;

  /// No description provided for @idInUse.
  ///
  /// In en, this message translates to:
  /// **'This ID is already in use'**
  String get idInUse;

  /// No description provided for @nameRequired.
  ///
  /// In en, this message translates to:
  /// **'Enter a name'**
  String get nameRequired;

  /// No description provided for @employeeIdHelp.
  ///
  /// In en, this message translates to:
  /// **'Cannot be changed later'**
  String get employeeIdHelp;

  /// No description provided for @jobTitle.
  ///
  /// In en, this message translates to:
  /// **'Job title (optional)'**
  String get jobTitle;

  /// No description provided for @enrollStarting.
  ///
  /// In en, this message translates to:
  /// **'Starting...'**
  String get enrollStarting;

  /// No description provided for @ok.
  ///
  /// In en, this message translates to:
  /// **'OK'**
  String get ok;

  /// No description provided for @syncNow.
  ///
  /// In en, this message translates to:
  /// **'Sync now'**
  String get syncNow;

  /// No description provided for @addPunch.
  ///
  /// In en, this message translates to:
  /// **'Add punch'**
  String get addPunch;

  /// No description provided for @allEmployees.
  ///
  /// In en, this message translates to:
  /// **'All employees'**
  String get allEmployees;

  /// No description provided for @anyDate.
  ///
  /// In en, this message translates to:
  /// **'Any date'**
  String get anyDate;

  /// No description provided for @clearFilters.
  ///
  /// In en, this message translates to:
  /// **'Clear'**
  String get clearFilters;

  /// No description provided for @punchAdded.
  ///
  /// In en, this message translates to:
  /// **'Punch added'**
  String get punchAdded;

  /// No description provided for @corrected.
  ///
  /// In en, this message translates to:
  /// **'Corrected'**
  String get corrected;

  /// No description provided for @reason.
  ///
  /// In en, this message translates to:
  /// **'Reason'**
  String get reason;

  /// No description provided for @reasonHint.
  ///
  /// In en, this message translates to:
  /// **'e.g. fingerprint would not read'**
  String get reasonHint;

  /// No description provided for @reasonRequired.
  ///
  /// In en, this message translates to:
  /// **'A reason is required. It is kept in the audit log.'**
  String get reasonRequired;

  /// No description provided for @futureNotAllowed.
  ///
  /// In en, this message translates to:
  /// **'That time is in the future'**
  String get futureNotAllowed;

  /// No description provided for @manualPunchHint.
  ///
  /// In en, this message translates to:
  /// **'For when a finger will not read. Manual punches are marked in every report.'**
  String get manualPunchHint;

  /// No description provided for @recordedTime.
  ///
  /// In en, this message translates to:
  /// **'Recorded'**
  String get recordedTime;

  /// No description provided for @provisionalExplained.
  ///
  /// In en, this message translates to:
  /// **'The terminal\'s clock was not verified when this was recorded. Correct the time if it is wrong.'**
  String get provisionalExplained;

  /// No description provided for @changeTime.
  ///
  /// In en, this message translates to:
  /// **'Change time'**
  String get changeTime;

  /// No description provided for @correctTime.
  ///
  /// In en, this message translates to:
  /// **'Correct the time'**
  String get correctTime;

  /// No description provided for @removeCorrection.
  ///
  /// In en, this message translates to:
  /// **'Remove correction'**
  String get removeCorrection;

  /// No description provided for @statusUpcoming.
  ///
  /// In en, this message translates to:
  /// **'Upcoming'**
  String get statusUpcoming;

  /// No description provided for @statusAtWork.
  ///
  /// In en, this message translates to:
  /// **'At work'**
  String get statusAtWork;

  /// No description provided for @terminalMode.
  ///
  /// In en, this message translates to:
  /// **'Each scan records'**
  String get terminalMode;

  /// No description provided for @modeCheckIn.
  ///
  /// In en, this message translates to:
  /// **'Check in'**
  String get modeCheckIn;

  /// No description provided for @modeCheckOut.
  ///
  /// In en, this message translates to:
  /// **'Check out'**
  String get modeCheckOut;

  /// No description provided for @modeAuto.
  ///
  /// In en, this message translates to:
  /// **'Alternate'**
  String get modeAuto;

  /// No description provided for @modeFixedHelp.
  ///
  /// In en, this message translates to:
  /// **'Every scan records the same direction, and the screen says which. Use one terminal per door, or switch it at closing time.'**
  String get modeFixedHelp;

  /// No description provided for @modeAutoHelp.
  ///
  /// In en, this message translates to:
  /// **'Each employee alternates: first scan in, next out. The screen cannot show which comes next.'**
  String get modeAutoHelp;

  /// No description provided for @showingLatest.
  ///
  /// In en, this message translates to:
  /// **'Showing the latest {count} punches. Filter by employee or date to see older ones.'**
  String showingLatest(int count);

  /// No description provided for @hoursAbbr.
  ///
  /// In en, this message translates to:
  /// **'h'**
  String get hoursAbbr;

  /// No description provided for @minutesAbbr.
  ///
  /// In en, this message translates to:
  /// **'m'**
  String get minutesAbbr;

  /// No description provided for @ofTotal.
  ///
  /// In en, this message translates to:
  /// **'of'**
  String get ofTotal;

  /// No description provided for @lowest.
  ///
  /// In en, this message translates to:
  /// **'lowest'**
  String get lowest;

  /// No description provided for @daysAbbr.
  ///
  /// In en, this message translates to:
  /// **'d'**
  String get daysAbbr;

  /// No description provided for @navPayroll.
  ///
  /// In en, this message translates to:
  /// **'Payroll'**
  String get navPayroll;

  /// No description provided for @payRules.
  ///
  /// In en, this message translates to:
  /// **'Pay rules'**
  String get payRules;

  /// No description provided for @payRulesHint.
  ///
  /// In en, this message translates to:
  /// **'Day wage = monthly salary ÷ 30. Hourly rate = day wage ÷ the employee\'s usual shift hours.'**
  String get payRulesHint;

  /// No description provided for @totalNet.
  ///
  /// In en, this message translates to:
  /// **'Total net pay'**
  String get totalNet;

  /// No description provided for @additionsLabel.
  ///
  /// In en, this message translates to:
  /// **'Overtime & bonuses'**
  String get additionsLabel;

  /// No description provided for @cutsLabel.
  ///
  /// In en, this message translates to:
  /// **'Cuts & advances'**
  String get cutsLabel;

  /// No description provided for @withoutWage.
  ///
  /// In en, this message translates to:
  /// **'Without a wage'**
  String get withoutWage;

  /// No description provided for @noWageSet.
  ///
  /// In en, this message translates to:
  /// **'No wage set'**
  String get noWageSet;

  /// No description provided for @noWageHint.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 employee has no wage set and is paid nothing this month.} other{{count} employees have no wage set and are paid nothing this month.}}'**
  String noWageHint(int count);

  /// No description provided for @setWage.
  ///
  /// In en, this message translates to:
  /// **'Set wage'**
  String get setWage;

  /// No description provided for @wage.
  ///
  /// In en, this message translates to:
  /// **'Wage'**
  String get wage;

  /// No description provided for @wageMonthly.
  ///
  /// In en, this message translates to:
  /// **'Monthly salary'**
  String get wageMonthly;

  /// No description provided for @wageDaily.
  ///
  /// In en, this message translates to:
  /// **'Per day'**
  String get wageDaily;

  /// No description provided for @wageHourly.
  ///
  /// In en, this message translates to:
  /// **'Per hour'**
  String get wageHourly;

  /// No description provided for @amount.
  ///
  /// In en, this message translates to:
  /// **'Amount'**
  String get amount;

  /// No description provided for @invalidAmount.
  ///
  /// In en, this message translates to:
  /// **'Enter an amount'**
  String get invalidAmount;

  /// No description provided for @wageFromMonth.
  ///
  /// In en, this message translates to:
  /// **'Applies from {month} onward. Earlier months keep the wage they had.'**
  String wageFromMonth(String month);

  /// No description provided for @dayRate.
  ///
  /// In en, this message translates to:
  /// **'Day wage'**
  String get dayRate;

  /// No description provided for @hourRate.
  ///
  /// In en, this message translates to:
  /// **'Hourly rate'**
  String get hourRate;

  /// No description provided for @basePay.
  ///
  /// In en, this message translates to:
  /// **'Base pay'**
  String get basePay;

  /// No description provided for @overtimePay.
  ///
  /// In en, this message translates to:
  /// **'Overtime'**
  String get overtimePay;

  /// No description provided for @dayOffPay.
  ///
  /// In en, this message translates to:
  /// **'Work on days off'**
  String get dayOffPay;

  /// No description provided for @lateCut.
  ///
  /// In en, this message translates to:
  /// **'Late arrivals'**
  String get lateCut;

  /// No description provided for @earlyCut.
  ///
  /// In en, this message translates to:
  /// **'Early leave'**
  String get earlyCut;

  /// No description provided for @absenceCut.
  ///
  /// In en, this message translates to:
  /// **'Absences'**
  String get absenceCut;

  /// No description provided for @bonus.
  ///
  /// In en, this message translates to:
  /// **'Bonus'**
  String get bonus;

  /// No description provided for @deduction.
  ///
  /// In en, this message translates to:
  /// **'Deduction'**
  String get deduction;

  /// No description provided for @advance.
  ///
  /// In en, this message translates to:
  /// **'Advance'**
  String get advance;

  /// No description provided for @adjustmentsTitle.
  ///
  /// In en, this message translates to:
  /// **'Bonuses, deductions and advances'**
  String get adjustmentsTitle;

  /// No description provided for @noAdjustments.
  ///
  /// In en, this message translates to:
  /// **'None this month'**
  String get noAdjustments;

  /// No description provided for @note.
  ///
  /// In en, this message translates to:
  /// **'Note'**
  String get note;

  /// No description provided for @noteRequired.
  ///
  /// In en, this message translates to:
  /// **'Enter a note. It is kept in the audit log.'**
  String get noteRequired;

  /// No description provided for @netPay.
  ///
  /// In en, this message translates to:
  /// **'Net pay'**
  String get netPay;

  /// No description provided for @clockFigure.
  ///
  /// In en, this message translates to:
  /// **'Clock: {value}'**
  String clockFigure(String value);

  /// No description provided for @editedPill.
  ///
  /// In en, this message translates to:
  /// **'Edited'**
  String get editedPill;

  /// No description provided for @editFigure.
  ///
  /// In en, this message translates to:
  /// **'Edit'**
  String get editFigure;

  /// No description provided for @useClockFigure.
  ///
  /// In en, this message translates to:
  /// **'Use clock figure'**
  String get useClockFigure;

  /// No description provided for @hoursUnit.
  ///
  /// In en, this message translates to:
  /// **'hours'**
  String get hoursUnit;

  /// No description provided for @daysUnit.
  ///
  /// In en, this message translates to:
  /// **'days'**
  String get daysUnit;

  /// No description provided for @excuseHint.
  ///
  /// In en, this message translates to:
  /// **'Lower the absent days to excuse an absence, e.g. sick leave.'**
  String get excuseHint;

  /// No description provided for @hourlyNoCuts.
  ///
  /// In en, this message translates to:
  /// **'Paid by the hour: time not worked is already unpaid, so lateness and absences are not cut again.'**
  String get hourlyNoCuts;

  /// No description provided for @dailyAbsenceNote.
  ///
  /// In en, this message translates to:
  /// **'Paid per day attended. Absent days are unpaid.'**
  String get dailyAbsenceNote;

  /// No description provided for @markPaid.
  ///
  /// In en, this message translates to:
  /// **'Mark month as paid'**
  String get markPaid;

  /// No description provided for @markPaidTitle.
  ///
  /// In en, this message translates to:
  /// **'Mark {month} as paid?'**
  String markPaidTitle(String month);

  /// No description provided for @markPaidBody.
  ///
  /// In en, this message translates to:
  /// **'The figures will be frozen. Later punch corrections and wage or rule changes will not change what was paid. You can reopen the month if you need to.'**
  String get markPaidBody;

  /// No description provided for @monthNotOver.
  ///
  /// In en, this message translates to:
  /// **'This month is not over yet. Figures are so far.'**
  String get monthNotOver;

  /// No description provided for @paidBanner.
  ///
  /// In en, this message translates to:
  /// **'Paid on {date}. These figures are frozen.'**
  String paidBanner(String date);

  /// No description provided for @reopen.
  ///
  /// In en, this message translates to:
  /// **'Reopen'**
  String get reopen;

  /// No description provided for @reopenBody.
  ///
  /// In en, this message translates to:
  /// **'The month will be recalculated from current data, which may differ from what was paid.'**
  String get reopenBody;

  /// No description provided for @monthClosed.
  ///
  /// In en, this message translates to:
  /// **'This month has been paid. Reopen it to make changes.'**
  String get monthClosed;

  /// No description provided for @currency.
  ///
  /// In en, this message translates to:
  /// **'Currency'**
  String get currency;

  /// No description provided for @currencyHint.
  ///
  /// In en, this message translates to:
  /// **'e.g. EGP'**
  String get currencyHint;

  /// No description provided for @overtimeRate.
  ///
  /// In en, this message translates to:
  /// **'Overtime rate'**
  String get overtimeRate;

  /// No description provided for @dayOffRate.
  ///
  /// In en, this message translates to:
  /// **'Day-off rate'**
  String get dayOffRate;

  /// No description provided for @lateRate.
  ///
  /// In en, this message translates to:
  /// **'Late minute cut'**
  String get lateRate;

  /// No description provided for @earlyRate.
  ///
  /// In en, this message translates to:
  /// **'Early leave minute cut'**
  String get earlyRate;

  /// No description provided for @rateHint.
  ///
  /// In en, this message translates to:
  /// **'× the hourly rate. 0 turns it off.'**
  String get rateHint;

  /// No description provided for @deductAbsence.
  ///
  /// In en, this message translates to:
  /// **'Deduct a day\'s wage for each absence'**
  String get deductAbsence;

  /// No description provided for @minOvertime.
  ///
  /// In en, this message translates to:
  /// **'Ignore daily overtime shorter than'**
  String get minOvertime;

  /// No description provided for @appPassword.
  ///
  /// In en, this message translates to:
  /// **'App password'**
  String get appPassword;

  /// No description provided for @appPasswordHint.
  ///
  /// In en, this message translates to:
  /// **'Asked for every time the app opens.'**
  String get appPasswordHint;

  /// No description provided for @appPasswordOff.
  ///
  /// In en, this message translates to:
  /// **'No password. Anyone at this computer can open the app.'**
  String get appPasswordOff;

  /// No description provided for @setPassword.
  ///
  /// In en, this message translates to:
  /// **'Set password'**
  String get setPassword;

  /// No description provided for @changePassword.
  ///
  /// In en, this message translates to:
  /// **'Change password'**
  String get changePassword;

  /// No description provided for @removePassword.
  ///
  /// In en, this message translates to:
  /// **'Remove password'**
  String get removePassword;

  /// No description provided for @currentPassword.
  ///
  /// In en, this message translates to:
  /// **'Current password'**
  String get currentPassword;

  /// No description provided for @newPassword.
  ///
  /// In en, this message translates to:
  /// **'New password'**
  String get newPassword;

  /// No description provided for @confirmPassword.
  ///
  /// In en, this message translates to:
  /// **'Repeat the new password'**
  String get confirmPassword;

  /// No description provided for @password.
  ///
  /// In en, this message translates to:
  /// **'Password'**
  String get password;

  /// No description provided for @enterPassword.
  ///
  /// In en, this message translates to:
  /// **'Enter the password to continue'**
  String get enterPassword;

  /// No description provided for @unlock.
  ///
  /// In en, this message translates to:
  /// **'Unlock'**
  String get unlock;

  /// No description provided for @lockApp.
  ///
  /// In en, this message translates to:
  /// **'Lock'**
  String get lockApp;

  /// No description provided for @wrongPassword.
  ///
  /// In en, this message translates to:
  /// **'Wrong password'**
  String get wrongPassword;

  /// No description provided for @passwordTooShort.
  ///
  /// In en, this message translates to:
  /// **'Use at least 4 characters'**
  String get passwordTooShort;

  /// No description provided for @passwordsDontMatch.
  ///
  /// In en, this message translates to:
  /// **'The passwords do not match'**
  String get passwordsDontMatch;

  /// No description provided for @passwordSaved.
  ///
  /// In en, this message translates to:
  /// **'Password saved'**
  String get passwordSaved;

  /// No description provided for @passwordRemoved.
  ///
  /// In en, this message translates to:
  /// **'Password removed'**
  String get passwordRemoved;

  /// No description provided for @tgTitle.
  ///
  /// In en, this message translates to:
  /// **'Telegram alerts'**
  String get tgTitle;

  /// No description provided for @tgTileHelp.
  ///
  /// In en, this message translates to:
  /// **'Check-ins, late arrivals and a daily summary, sent by the terminal'**
  String get tgTileHelp;

  /// No description provided for @tgIntro.
  ///
  /// In en, this message translates to:
  /// **'The terminal sends these itself, so they keep arriving with this computer off. It judges lateness against the shifts this app sends it on every sync, two weeks ahead.'**
  String get tgIntro;

  /// No description provided for @tgActive.
  ///
  /// In en, this message translates to:
  /// **'Active. The terminal is sending alerts.'**
  String get tgActive;

  /// No description provided for @tgNotActive.
  ///
  /// In en, this message translates to:
  /// **'Not active. Set a bot and chat below, and switch alerts on.'**
  String get tgNotActive;

  /// No description provided for @tgCounters.
  ///
  /// In en, this message translates to:
  /// **'Sent {sent} · failed attempts {failed} · gave up {dropped}'**
  String tgCounters(int sent, int failed, int dropped);

  /// No description provided for @tgLastError.
  ///
  /// In en, this message translates to:
  /// **'Last problem: {error}'**
  String tgLastError(String error);

  /// No description provided for @tgNoRoster.
  ///
  /// In en, this message translates to:
  /// **'The terminal has no schedule yet, so it cannot tell who is late. It gets one on the next sync after saving.'**
  String get tgNoRoster;

  /// No description provided for @tgRoster.
  ///
  /// In en, this message translates to:
  /// **'Schedule on the terminal: {names} names, {from} to {to}'**
  String tgRoster(int names, String from, String to);

  /// No description provided for @tgStepBot.
  ///
  /// In en, this message translates to:
  /// **'1. Bot'**
  String get tgStepBot;

  /// No description provided for @tgStepBotHelp.
  ///
  /// In en, this message translates to:
  /// **'In Telegram, open @BotFather, send /newbot and follow the steps. It gives you a token: paste it here.'**
  String get tgStepBotHelp;

  /// No description provided for @tgBotToken.
  ///
  /// In en, this message translates to:
  /// **'Bot token'**
  String get tgBotToken;

  /// No description provided for @tgTokenSet.
  ///
  /// In en, this message translates to:
  /// **'A token ending in …{hint} is set. Leave empty to keep it.'**
  String tgTokenSet(String hint);

  /// No description provided for @tgTokenInvalid.
  ///
  /// In en, this message translates to:
  /// **'That does not look like a bot token (123456789:AA…)'**
  String get tgTokenInvalid;

  /// No description provided for @tgTokenNeededForFind.
  ///
  /// In en, this message translates to:
  /// **'Paste the bot token first'**
  String get tgTokenNeededForFind;

  /// No description provided for @tgCheckToken.
  ///
  /// In en, this message translates to:
  /// **'Check token'**
  String get tgCheckToken;

  /// No description provided for @tgStepChat.
  ///
  /// In en, this message translates to:
  /// **'2. Where to send'**
  String get tgStepChat;

  /// No description provided for @tgStepChatHelp.
  ///
  /// In en, this message translates to:
  /// **'Open your new bot in Telegram and send it /start (or add it to a group and send a message there), then click Find.'**
  String get tgStepChatHelp;

  /// No description provided for @tgChatId.
  ///
  /// In en, this message translates to:
  /// **'Chat ID'**
  String get tgChatId;

  /// No description provided for @tgFindChat.
  ///
  /// In en, this message translates to:
  /// **'Find'**
  String get tgFindChat;

  /// No description provided for @tgNoChats.
  ///
  /// In en, this message translates to:
  /// **'No messages to the bot yet. Send it /start in Telegram, then click Find again.'**
  String get tgNoChats;

  /// No description provided for @tgStepWhat.
  ///
  /// In en, this message translates to:
  /// **'3. What to send'**
  String get tgStepWhat;

  /// No description provided for @tgEnabled.
  ///
  /// In en, this message translates to:
  /// **'Send alerts'**
  String get tgEnabled;

  /// No description provided for @tgEachPunch.
  ///
  /// In en, this message translates to:
  /// **'Every check-in and check-out'**
  String get tgEachPunch;

  /// No description provided for @tgEachPunchHelp.
  ///
  /// In en, this message translates to:
  /// **'One message per scan. Can be a lot with many staff.'**
  String get tgEachPunchHelp;

  /// No description provided for @tgLate.
  ///
  /// In en, this message translates to:
  /// **'Late arrivals'**
  String get tgLate;

  /// No description provided for @tgLateHelp.
  ///
  /// In en, this message translates to:
  /// **'When the first check-in of the day is past the shift\'s grace period.'**
  String get tgLateHelp;

  /// No description provided for @tgSummary.
  ///
  /// In en, this message translates to:
  /// **'Daily summary'**
  String get tgSummary;

  /// No description provided for @tgSummaryHelp.
  ///
  /// In en, this message translates to:
  /// **'Who came, who was late, who is absent, who has not checked out.'**
  String get tgSummaryHelp;

  /// No description provided for @tgSummaryAt.
  ///
  /// In en, this message translates to:
  /// **'Send at {time}'**
  String tgSummaryAt(String time);

  /// No description provided for @tgSendTest.
  ///
  /// In en, this message translates to:
  /// **'Send test message'**
  String get tgSendTest;

  /// No description provided for @tgSendSummary.
  ///
  /// In en, this message translates to:
  /// **'Send summary now'**
  String get tgSendSummary;

  /// No description provided for @tgQueued.
  ///
  /// In en, this message translates to:
  /// **'Sent to the terminal. Checking delivery…'**
  String get tgQueued;

  /// No description provided for @wifiTitle.
  ///
  /// In en, this message translates to:
  /// **'Wi-Fi fallback'**
  String get wifiTitle;

  /// No description provided for @wifiTileHelp.
  ///
  /// In en, this message translates to:
  /// **'Used only when the Ethernet cable is not connected'**
  String get wifiTileHelp;

  /// No description provided for @wifiIntro.
  ///
  /// In en, this message translates to:
  /// **'Ethernet stays the main connection. If the cable has no connection for 20 seconds, the terminal joins this Wi-Fi network instead, and goes back to the cable once it has been working again for a minute. Set it now, while the app can reach the terminal.'**
  String get wifiIntro;

  /// No description provided for @wifiActiveEth.
  ///
  /// In en, this message translates to:
  /// **'The terminal is on Ethernet.'**
  String get wifiActiveEth;

  /// No description provided for @wifiActiveWifi.
  ///
  /// In en, this message translates to:
  /// **'The terminal is on Wi-Fi at {ip} (no Ethernet).'**
  String wifiActiveWifi(String ip);

  /// No description provided for @wifiActiveNone.
  ///
  /// In en, this message translates to:
  /// **'The terminal reports no connection.'**
  String get wifiActiveNone;

  /// No description provided for @wifiNotSet.
  ///
  /// In en, this message translates to:
  /// **'No Wi-Fi network set. Without one, an unplugged cable means no connection.'**
  String get wifiNotSet;

  /// No description provided for @wifiStandby.
  ///
  /// In en, this message translates to:
  /// **'Standing by: will use \"{ssid}\" if the cable is unplugged.'**
  String wifiStandby(String ssid);

  /// No description provided for @wifiConnecting.
  ///
  /// In en, this message translates to:
  /// **'Connecting to \"{ssid}\"…'**
  String wifiConnecting(String ssid);

  /// No description provided for @wifiConnected.
  ///
  /// In en, this message translates to:
  /// **'Connected to \"{ssid}\", signal {rssi} dBm.'**
  String wifiConnected(String ssid, int rssi);

  /// No description provided for @wifiFailed.
  ///
  /// In en, this message translates to:
  /// **'Cannot connect to \"{ssid}\": {error}. Still retrying.'**
  String wifiFailed(String ssid, String error);

  /// No description provided for @wifiNetwork.
  ///
  /// In en, this message translates to:
  /// **'Network'**
  String get wifiNetwork;

  /// No description provided for @wifiSsid.
  ///
  /// In en, this message translates to:
  /// **'Network name (SSID)'**
  String get wifiSsid;

  /// No description provided for @wifiScan.
  ///
  /// In en, this message translates to:
  /// **'Scan'**
  String get wifiScan;

  /// No description provided for @wifiScanning.
  ///
  /// In en, this message translates to:
  /// **'The terminal is listening for networks. This takes a few seconds.'**
  String get wifiScanning;

  /// No description provided for @wifiNoneFound.
  ///
  /// In en, this message translates to:
  /// **'No networks found near the terminal.'**
  String get wifiNoneFound;

  /// No description provided for @wifiOpen.
  ///
  /// In en, this message translates to:
  /// **'open'**
  String get wifiOpen;

  /// No description provided for @wifiPassword.
  ///
  /// In en, this message translates to:
  /// **'Password'**
  String get wifiPassword;

  /// No description provided for @wifiPasswordKeep.
  ///
  /// In en, this message translates to:
  /// **'Type the password again when you change the network'**
  String get wifiPasswordKeep;

  /// No description provided for @wifiPasswordHelp.
  ///
  /// In en, this message translates to:
  /// **'Leave empty only for an open network. The terminal never sends the password back.'**
  String get wifiPasswordHelp;

  /// No description provided for @wifiPasswordShort.
  ///
  /// In en, this message translates to:
  /// **'A Wi-Fi password has at least 8 characters'**
  String get wifiPasswordShort;

  /// No description provided for @wifiShowPassword.
  ///
  /// In en, this message translates to:
  /// **'Show password'**
  String get wifiShowPassword;

  /// No description provided for @wifiForget.
  ///
  /// In en, this message translates to:
  /// **'Forget network'**
  String get wifiForget;

  /// No description provided for @wifiForgotten.
  ///
  /// In en, this message translates to:
  /// **'Wi-Fi network forgotten'**
  String get wifiForgotten;

  /// No description provided for @resetApp.
  ///
  /// In en, this message translates to:
  /// **'Reset app'**
  String get resetApp;

  /// No description provided for @resetAppHint.
  ///
  /// In en, this message translates to:
  /// **'Deletes everything this app keeps on this computer and starts again as if newly installed.'**
  String get resetAppHint;

  /// No description provided for @resetAppTitle.
  ///
  /// In en, this message translates to:
  /// **'Reset the app?'**
  String get resetAppTitle;

  /// No description provided for @resetAppBody.
  ///
  /// In en, this message translates to:
  /// **'This permanently deletes from this computer:\n• every punch, including manual punches and edits\n• shifts, wages, payroll and payment history\n• the terminal\'s address and token, the app password and all settings\n\nExport any reports you need first.'**
  String get resetAppBody;

  /// No description provided for @resetAppKeeps.
  ///
  /// In en, this message translates to:
  /// **'The terminal is not changed. Its employees and fingerprints stay on it, and punches it still holds are copied back when you connect again.'**
  String get resetAppKeeps;

  /// No description provided for @resetConfirmWord.
  ///
  /// In en, this message translates to:
  /// **'RESET'**
  String get resetConfirmWord;

  /// No description provided for @resetConfirmLabel.
  ///
  /// In en, this message translates to:
  /// **'Type {word} to confirm'**
  String resetConfirmLabel(String word);
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['ar', 'en'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'ar':
      return AppLocalizationsAr();
    case 'en':
      return AppLocalizationsEn();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
