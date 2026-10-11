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
