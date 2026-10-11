import 'api_client.dart';
import 'name_raster.dart';

/// The phrases the terminal displays, and the machinery to push them to it.
///
/// The device has no Arabic font and no shaper (D3), so every on-screen string
/// is rasterised here and uploaded into a fixed slot. Slot numbers must match
/// the `ui_string_t` enum in firmware/main/cfg.h — they are a wire contract,
/// so never reorder them, only append.
enum DeviceString {
  placeFinger(0),
  welcome(1),
  inbound(2),
  outbound(3),
  tryAgain(4),
  notKnown(5),
  alreadyDone(6),
  unassigned(7),
  enrolling(8),
  liftFinger(9),
  placeAgain(10),
  saving(11),
  saved(12),
  failed(13),
  noTime(14),
  forcedIn(15),
  forcedOut(16),
  modeIn(17),
  modeOut(18);

  const DeviceString(this.slot);
  final int slot;
}

/// What each slot says, per language. Kept here rather than in the app's .arb
/// files because these are the *device's* strings: they are sized for a 128x16
/// strip and must stay short enough to fit.
const Map<DeviceString, ({String en, String ar})> deviceStringText = {
  DeviceString.placeFinger: (en: 'PLACE FINGER', ar: 'ضع إصبعك'),
  DeviceString.welcome: (en: 'WELCOME', ar: 'أهلاً وسهلاً'),
  DeviceString.inbound: (en: 'CHECKED IN', ar: 'تم الدخول'),
  DeviceString.outbound: (en: 'CHECKED OUT', ar: 'تم الخروج'),
  DeviceString.tryAgain: (en: 'TRY AGAIN', ar: 'حاول مرة أخرى'),
  DeviceString.notKnown: (en: 'NOT RECOGNISED', ar: 'بصمة غير معروفة'),
  DeviceString.alreadyDone: (en: 'ALREADY DONE', ar: 'مسجل مسبقاً'),
  DeviceString.unassigned: (en: 'UNASSIGNED', ar: 'غير مرتبط بموظف'),
  DeviceString.enrolling: (en: 'ENROLLING', ar: 'تسجيل بصمة'),
  DeviceString.liftFinger: (en: 'LIFT FINGER', ar: 'ارفع إصبعك'),
  DeviceString.placeAgain: (en: 'PLACE AGAIN', ar: 'ضع إصبعك ثانية'),
  DeviceString.saving: (en: 'SAVING...', ar: 'جارٍ الحفظ...'),
  DeviceString.saved: (en: 'SAVED', ar: 'تم الحفظ'),
  DeviceString.failed: (en: 'FAILED', ar: 'فشلت العملية'),
  DeviceString.noTime: (en: 'CLOCK NOT SET', ar: 'الساعة غير مضبوطة'),
  DeviceString.forcedIn: (en: 'FORCED: IN', ar: 'دخول إجباري'),
  DeviceString.forcedOut: (en: 'FORCED: OUT', ar: 'خروج إجباري'),
  DeviceString.modeIn: (en: 'CHECK IN', ar: 'تسجيل دخول'),
  DeviceString.modeOut: (en: 'CHECK OUT', ar: 'تسجيل خروج'),
};

class DeviceStrings {
  /// Renders and uploads every phrase in [language] ('en' or 'ar').
  ///
  /// Each slot is a separate request because the device stores them in
  /// individual NVS blobs; a single body holding all of them would also strain
  /// its HTTP buffer. The posts are small and take a couple of seconds total.
  static Future<void> pushAll(
    ApiClient api,
    String language, {
    void Function(int done, int total)? onProgress,
  }) async {
    final entries = deviceStringText.entries.toList();
    for (var i = 0; i < entries.length; i++) {
      final e = entries[i];
      final text = language == 'ar' ? e.value.ar : e.value.en;
      final bitmap = await NameRaster.render(text);
      await api.uploadString(e.key.slot, bitmap);
      onProgress?.call(i + 1, entries.length);
    }
  }

  static int get count => deviceStringText.length;
}
