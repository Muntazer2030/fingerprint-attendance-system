// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Arabic (`ar`).
class AppLocalizationsAr extends AppLocalizations {
  AppLocalizationsAr([String locale = 'ar']) : super(locale);

  @override
  String get appTitle => 'الحضور';

  @override
  String get navDashboard => 'لوحة المعلومات';

  @override
  String get navEmployees => 'الموظفون';

  @override
  String get navEvents => 'السجل';

  @override
  String get navSettings => 'الإعدادات';

  @override
  String get connect => 'اتصال';

  @override
  String get findDevice => 'البحث عن الجهاز';

  @override
  String get scanning => 'جارٍ البحث في الشبكة...';

  @override
  String get deviceFound => 'تم العثور على الجهاز';

  @override
  String get deviceNotFound => 'لم يتم العثور على جهاز في هذه الشبكة';

  @override
  String get disconnect => 'قطع الاتصال';

  @override
  String get connected => 'متصل';

  @override
  String get disconnected => 'غير متصل';

  @override
  String get deviceAddress => 'عنوان الجهاز';

  @override
  String get deviceToken => 'رمز الجهاز';

  @override
  String get deviceAddressHint => '192.168.137.245';

  @override
  String get save => 'حفظ';

  @override
  String get retry => 'إعادة المحاولة';

  @override
  String get cancel => 'إلغاء';

  @override
  String get add => 'إضافة';

  @override
  String get delete => 'حذف';

  @override
  String get refresh => 'تحديث';

  @override
  String get statusOnline => 'متصل';

  @override
  String get statusOffline => 'غير متصل';

  @override
  String get uptime => 'مدة التشغيل';

  @override
  String get firmware => 'إصدار البرنامج';

  @override
  String get board => 'اللوحة';

  @override
  String get freeMemory => 'الذاكرة المتاحة';

  @override
  String get clock => 'الساعة';

  @override
  String get clockUnset => 'غير مضبوطة';

  @override
  String get clockSourceNtp => 'توقيت الإنترنت';

  @override
  String get clockSourcePc => 'مضبوطة من هذا الحاسوب';

  @override
  String get clockSourceRestored => 'مستعادة (غير مؤكدة)';

  @override
  String get syncClock => 'مزامنة الساعة';

  @override
  String get eventsStored => 'السجلات المخزنة';

  @override
  String get eventsPending => 'بانتظار المزامنة';

  @override
  String get eventsCapacity => 'السعة';

  @override
  String get bufferFull => 'امتلأت الذاكرة - فُقدت أقدم السجلات';

  @override
  String get employeeId => 'رقم الموظف';

  @override
  String get employeeName => 'الاسم';

  @override
  String get fingersEnrolled => 'البصمات';

  @override
  String get lastDirection => 'آخر تسجيل';

  @override
  String get failedReads => 'محاولات فاشلة';

  @override
  String get active => 'نشط';

  @override
  String get addEmployee => 'إضافة موظف';

  @override
  String get enrollFinger => 'تسجيل بصمة';

  @override
  String get noEmployees => 'لا يوجد موظفون بعد';

  @override
  String get enrollPlaceFinger => 'ضع إصبعك على الجهاز';

  @override
  String get enrollLiftFinger => 'ارفع إصبعك';

  @override
  String get enrollPlaceAgain => 'ضع نفس الإصبع مرة أخرى';

  @override
  String get enrollSaving => 'جارٍ الحفظ...';

  @override
  String get enrollStored => 'تم التسجيل بنجاح';

  @override
  String get enrollFailed => 'فشل التسجيل';

  @override
  String get directionIn => 'دخول';

  @override
  String get directionOut => 'خروج';

  @override
  String get methodFinger => 'بصمة';

  @override
  String get methodManual => 'يدوي';

  @override
  String get methodPin => 'رمز';

  @override
  String get provisionalTime => 'الوقت غير مؤكد';

  @override
  String get noEvents => 'لا توجد سجلات';

  @override
  String get time => 'الوقت';

  @override
  String get employee => 'الموظف';

  @override
  String get direction => 'النوع';

  @override
  String get method => 'الطريقة';

  @override
  String get language => 'اللغة';

  @override
  String get english => 'English';

  @override
  String get arabic => 'العربية';

  @override
  String get connectionFailed => 'تعذر الوصول إلى الجهاز';

  @override
  String get checkAddressAndToken =>
      'تحقق من العنوان والرمز، ومن أن الجهاز يعمل.';

  @override
  String get navDevice => 'الجهاز';

  @override
  String get displayLanguage => 'لغة الشاشة';

  @override
  String get clockFormat => 'نظام الساعة';

  @override
  String get hour24 => '٢٤ ساعة';

  @override
  String get hour12 => '١٢ ساعة';

  @override
  String get showSeconds => 'إظهار الثواني';

  @override
  String get timezoneOffset => 'فرق التوقيت عن UTC';

  @override
  String get brightness => 'سطوع الشاشة';

  @override
  String get buzzerSound => 'الصافرة';

  @override
  String get duplicateWindow => 'تجاهل التكرار خلال';

  @override
  String get dimAfter => 'تعتيم الشاشة بعد';

  @override
  String get blankAfter => 'إطفاء الشاشة بعد';

  @override
  String get seconds => 'ثانية';

  @override
  String get minutes => 'دقيقة';

  @override
  String get never => 'أبداً';

  @override
  String get burnInWarning =>
      'ترك الشاشة مضاءة دائماً سيؤدي إلى احتراق الصورة مع الوقت.';

  @override
  String get fingerDetectWire => 'سلك تنبيه المستشعر موصول';

  @override
  String get fingerDetectHelp =>
      'أوقفه إذا لم تكن أسلاك المستشعر الزرقاء والصفراء موصولة. سيقوم الجهاز بالفحص المستمر وسيومض ضوء المستشعر.';

  @override
  String get pushStrings => 'إرسال النصوص إلى الجهاز';

  @override
  String get pushStringsHelp =>
      'الجهاز لا يحتوي على خط عربي، لذا تُرسم النصوص هنا وتُرفع إليه.';

  @override
  String get pushing => 'جارٍ الإرسال...';

  @override
  String get stringsSent => 'تم إرسال النصوص إلى الجهاز';

  @override
  String get stringsMissing => 'لا توجد نصوص على الجهاز - أرسلها';

  @override
  String get applyToDevice => 'تطبيق';

  @override
  String get deviceSettings => 'إعدادات الجهاز';

  @override
  String get saved => 'تم الحفظ';

  @override
  String get ethResets => 'مرات استعادة الشبكة';

  @override
  String get dangerZone => 'مسح بيانات الجهاز';

  @override
  String get clearEvents => 'مسح سجل الحضور';

  @override
  String get clearEventsHelp =>
      'يمسح جميع التسجيلات المخزنة على الجهاز. السجلات التي تمت مزامنتها مع الحاسوب تبقى محفوظة.';

  @override
  String get clearFingerprints => 'مسح البصمات';

  @override
  String get clearFingerprintsHelp =>
      'يحذف جميع البصمات والموظفين من الجهاز. سيحتاج الموظفون إلى التسجيل من جديد.';

  @override
  String get clearConfig => 'إعادة ضبط الإعدادات';

  @override
  String get clearConfigHelp =>
      'يعيد الإعدادات الافتراضية ويحذف النصوص المرفوعة إلى الشاشة.';

  @override
  String get clearAll => 'مسح كل شيء';

  @override
  String get confirmClear => 'لا يمكن التراجع عن هذا. اكتب CLEAR للتأكيد.';

  @override
  String get clearedOk => 'تم مسح الجهاز';

  @override
  String get typeToConfirm => 'CLEAR';

  @override
  String get appearance => 'المظهر';

  @override
  String get themeSystem => 'النظام';

  @override
  String get themeLight => 'فاتح';

  @override
  String get themeDark => 'داكن';

  @override
  String get searching => 'جارٍ البحث عن الجهاز...';

  @override
  String get syncing => 'جارٍ المزامنة';

  @override
  String get lastSync => 'آخر مزامنة';

  @override
  String get never2 => 'أبداً';

  @override
  String get searchingNetwork => 'جارٍ البحث عن الجهاز';

  @override
  String get enterManually => 'إدخال العنوان يدوياً';

  @override
  String get tokenNeeded => 'أدخل رمز الجهاز لإكمال الاتصال';

  @override
  String get tokenWhere =>
      'يظهر الرمز في سجل تشغيل الجهاز، في السطر الذي يبدأ بـ \"api: listening\".';

  @override
  String get notFoundHelp =>
      'تأكد من أن الجهاز يعمل وأنه على نفس الشبكة مع هذا الحاسوب.';

  @override
  String get touchButtonWired => 'زر اللمس موصول';

  @override
  String get touchButtonHelp =>
      'أوقفه إذا لم يكن زر اللمس TTP223 موصولاً. المدخل غير الموصول يطفو ويبدّل الدخول/الخروج من تلقاء نفسه.';

  @override
  String get navTimesheet => 'سجل الدوام';

  @override
  String get hoursWorked => 'ساعات العمل';

  @override
  String get lateOccasions => 'مرات التأخير';

  @override
  String get absences => 'أيام الغياب';

  @override
  String get needsReview => 'بحاجة لمراجعة';

  @override
  String get daysPresent => 'أيام الحضور';

  @override
  String get overtime => 'ساعات إضافية';

  @override
  String get earlyLeave => 'خروج مبكر';

  @override
  String get statusPresent => 'حاضر';

  @override
  String get statusAbsent => 'غائب';

  @override
  String get statusIncomplete => 'ناقص';

  @override
  String get statusOff => 'إجازة';

  @override
  String get noTimesheetData => 'لا يوجد موظفون بعد';

  @override
  String get reviewHint =>
      'توجد تسجيلات ناقصة أو أوقات غير مؤكدة. راجعها قبل اعتماد هذه الأرقام.';

  @override
  String get previousMonth => 'الشهر السابق';

  @override
  String get nextMonth => 'الشهر التالي';

  @override
  String get totalsFor => 'الإجماليات';

  @override
  String get perEmployee => 'حسب الموظف';

  @override
  String get backToList => 'رجوع';

  @override
  String get shiftLabel => 'الوردية';

  @override
  String get noShift => 'غير مجدول';

  @override
  String get schedules => 'الورديات';

  @override
  String get addShift => 'إضافة وردية';

  @override
  String get editShift => 'تعديل الوردية';

  @override
  String get shiftName => 'اسم الوردية';

  @override
  String get shiftsHint =>
      'دقة سجل الدوام تعتمد على هذه الإعدادات. التأخير والغياب يُحسبان بناءً عليها.';

  @override
  String get fixedHours => 'أوقات ثابتة';

  @override
  String get flexibleHours => 'مرنة';

  @override
  String get fixedHint =>
      'حدد وقت البداية والنهاية. يتم حساب التأخير والخروج المبكر.';

  @override
  String get flexibleHint =>
      'يُحتسب مجموع الساعات فقط. لا يوجد وقت بداية، لذا لا يوجد تأخير.';

  @override
  String get startTime => 'البداية';

  @override
  String get endTime => 'النهاية';

  @override
  String get crossesMidnight => 'تنتهي في اليوم التالي — وردية ليلية.';

  @override
  String get breakLabel => 'استراحة';

  @override
  String get grace => 'سماح';

  @override
  String get graceIn => 'سماح التأخير';

  @override
  String get graceOut => 'سماح الخروج المبكر';

  @override
  String get requiredPerDay => 'المطلوب يومياً';

  @override
  String get perDay => 'يومياً';

  @override
  String get minutesShort => 'دقيقة';

  @override
  String get workingDays => 'أيام العمل';

  @override
  String get weekendHint =>
      'الأيام غير المحددة هي العطلة. تصلح للجمعة/السبت أو السبت/الأحد.';

  @override
  String get defaultShift => 'الافتراضية';

  @override
  String get makeDefault => 'جعلها افتراضية';

  @override
  String get assignTo => 'تعيين إلى';

  @override
  String get assignHint =>
      'الموظفون المحددون يستخدمون هذه الوردية بدل الافتراضية.';

  @override
  String get cannotDeleteLastShift => 'يجب أن تبقى وردية واحدة على الأقل';

  @override
  String get deleteShiftHint =>
      'من كان معيناً عليها سينتقل إلى الوردية الافتراضية.';

  @override
  String get exportXlsx => 'تصدير إلى Excel';

  @override
  String get exported => 'تم حفظ التقرير';

  @override
  String get exporting => 'جارٍ إنشاء التقرير...';

  @override
  String get tokenRejected =>
      'رفض الجهاز هذا الرمز. انسخه مرة أخرى من سجل تشغيل الجهاز.';

  @override
  String get tokenRejectedShort => 'رمز غير صحيح';

  @override
  String get employeesOffline =>
      'الجهاز غير متصل. تُعرض قائمة الموظفين المحفوظة على هذا الحاسوب، والتعديل يتطلب اتصال الجهاز.';

  @override
  String get removedEmployees => 'موظفون سابقون';

  @override
  String get removedHint => 'محفوظ للتقارير السابقة';

  @override
  String get restore => 'استعادة';

  @override
  String get restored => 'تمت الاستعادة إلى الجهاز';

  @override
  String get sentToTerminal => 'أُرسل إلى الجهاز';

  @override
  String get deleteEmployeeHint =>
      'يحذف الموظف وبصماته من الجهاز. يبقى سجل حضوره في التقارير السابقة.';

  @override
  String get noFingers => 'لا توجد بصمة';

  @override
  String get onSite => 'في العمل';

  @override
  String get offSite => 'خارج العمل';

  @override
  String get notOnTerminal =>
      'غير موجود على الجهاز، ولا يمكنه التسجيل حتى يُرسل.';

  @override
  String get sendToTerminal => 'إرسال إلى الجهاز';

  @override
  String get editEmployee => 'تعديل الموظف';

  @override
  String get invalidEmployeeId => 'أدخل رقماً من 1 إلى 65535';

  @override
  String get idInUse => 'هذا الرقم مستخدم';

  @override
  String get nameRequired => 'أدخل الاسم';

  @override
  String get employeeIdHelp => 'لا يمكن تغييره لاحقاً';

  @override
  String get jobTitle => 'المسمى الوظيفي (اختياري)';

  @override
  String get enrollStarting => 'جارٍ البدء...';

  @override
  String get ok => 'حسناً';

  @override
  String get syncNow => 'مزامنة الآن';

  @override
  String get addPunch => 'إضافة تسجيل';

  @override
  String get allEmployees => 'جميع الموظفين';

  @override
  String get anyDate => 'أي تاريخ';

  @override
  String get clearFilters => 'مسح';

  @override
  String get punchAdded => 'تمت إضافة التسجيل';

  @override
  String get corrected => 'مُصحّح';

  @override
  String get reason => 'السبب';

  @override
  String get reasonHint => 'مثال: لم تُقرأ البصمة';

  @override
  String get reasonRequired => 'السبب مطلوب ويُحفظ في سجل التدقيق.';

  @override
  String get futureNotAllowed => 'هذا الوقت في المستقبل';

  @override
  String get manualPunchHint =>
      'عند تعذّر قراءة البصمة. التسجيلات اليدوية تُميَّز في كل التقارير.';

  @override
  String get recordedTime => 'وقت التسجيل';

  @override
  String get provisionalExplained =>
      'لم تكن ساعة الجهاز مؤكدة عند هذا التسجيل. صحّح الوقت إن كان خاطئاً.';

  @override
  String get changeTime => 'تغيير الوقت';

  @override
  String get correctTime => 'تصحيح الوقت';

  @override
  String get removeCorrection => 'إزالة التصحيح';

  @override
  String get statusUpcoming => 'قادم';

  @override
  String get statusAtWork => 'في العمل';

  @override
  String get terminalMode => 'كل مسح يسجّل';

  @override
  String get modeCheckIn => 'دخول';

  @override
  String get modeCheckOut => 'خروج';

  @override
  String get modeAuto => 'تبديل تلقائي';

  @override
  String get modeFixedHelp =>
      'كل مسح يسجّل الاتجاه نفسه وتعرضه الشاشة. استخدم جهازاً لكل باب أو بدّله عند الإغلاق.';

  @override
  String get modeAutoHelp =>
      'يتبادل كل موظف: المسح الأول دخول والتالي خروج. لا تستطيع الشاشة عرض الاتجاه التالي.';

  @override
  String showingLatest(int count) {
    return 'تُعرض آخر $count تسجيلات. صفِّ حسب الموظف أو التاريخ لرؤية الأقدم.';
  }

  @override
  String get hoursAbbr => 'س';

  @override
  String get minutesAbbr => 'د';

  @override
  String get ofTotal => 'من';

  @override
  String get lowest => 'الأدنى';

  @override
  String get daysAbbr => 'ي';
}
