import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Connection details and UI preferences.
///
/// The device is addressed by IP rather than mDNS: `attendance.local` is not
/// reliably resolvable from a browser, and the web build is the current
/// target. Give the terminal a DHCP reservation or use its static fallback.
class Settings extends ChangeNotifier {
  static const _kHost = 'device_host';
  static const _kToken = 'device_token';
  static const _kLocale = 'locale';
  static const _kSyncSeq = 'synced_through_seq';
  static const _kTheme = 'theme_mode';

  String _host = '';
  String _token = '';
  Locale _locale = const Locale('en');
  ThemeMode _themeMode = ThemeMode.system;
  int _syncedThroughSeq = 0;
  bool _loaded = false;

  String get host => _host;
  String get token => _token;
  Locale get locale => _locale;
  ThemeMode get themeMode => _themeMode;
  int get syncedThroughSeq => _syncedThroughSeq;
  bool get loaded => _loaded;
  bool get isConfigured => _host.isNotEmpty && _token.isNotEmpty;

  Future<void> load() async {
    final p = await SharedPreferences.getInstance();
    _host = p.getString(_kHost) ?? '';
    _token = p.getString(_kToken) ?? '';
    _draftToken = p.getString(_kDraftToken) ?? '';
    _locale = Locale(p.getString(_kLocale) ?? 'en');
    _themeMode = switch (p.getString(_kTheme)) {
      'light' => ThemeMode.light,
      'dark' => ThemeMode.dark,
      _ => ThemeMode.system,
    };
    _syncedThroughSeq = p.getInt(_kSyncSeq) ?? 0;
    _loaded = true;
    notifyListeners();
  }

  /// Accepts what people actually paste: a bare IP, a full URL, a trailing
  /// slash, or stray whitespace. Uri.http() takes an authority, not a URL, so
  /// leaving a scheme in place produces a silently broken request.
  static String normaliseHost(String raw) {
    var h = raw.trim();
    h = h.replaceFirst(RegExp(r'^[a-zA-Z][a-zA-Z0-9+.-]*://'), '');
    h = h.split('/').first;
    return h.trim();
  }

  /// Commits a connection that has been checked against the device. The only
  /// way host and token become live together.
  Future<void> setConnection(String host, String token) async {
    _host = normaliseHost(host);
    _token = token.trim();
    final p = await SharedPreferences.getInstance();
    await p.setString(_kHost, _host);
    await p.setString(_kToken, _token);
    notifyListeners();
  }

  /// Forgets the device, returning the app to the connect screen. The token
  /// is kept as a remembered one for prefilling.
  Future<void> disconnect() async {
    if (_token.isNotEmpty) await rememberToken(_token);
    _token = '';
    final p = await SharedPreferences.getInstance();
    await p.remove(_kToken);
    notifyListeners();
  }

  Future<void> setThemeMode(ThemeMode m) async {
    _themeMode = m;
    final p = await SharedPreferences.getInstance();
    await p.setString(_kTheme, m.name);
    notifyListeners();
  }

  static const _kDraftToken = 'device_token_draft';
  String _draftToken = '';

  /// The last token typed, whether or not it has been verified yet. Used only
  /// to prefill token fields, so a token entered against a stale address is
  /// never lost.
  ///
  /// Kept apart from [token] on purpose. Writing typed text straight into the
  /// live token made the app "configured" on the first keystroke: it jumped
  /// from the connect screen into the main window with a one-character token,
  /// and editing the field in Settings swapped the whole app out mid-typing.
  String get rememberedToken => _draftToken.isNotEmpty ? _draftToken : _token;

  Future<void> rememberToken(String token) async {
    final t = token.trim();
    if (t.isEmpty || t == _draftToken) return;
    _draftToken = t;
    final p = await SharedPreferences.getInstance();
    await p.setString(_kDraftToken, t);
  }

  /// Moves an already-verified connection to a new address. Only for the
  /// device having been found elsewhere with the *same* token.
  Future<void> setHost(String host) async {
    final h = normaliseHost(host);
    if (h == _host) return;
    _host = h;
    final p = await SharedPreferences.getInstance();
    await p.setString(_kHost, h);
    notifyListeners();
  }

  Future<void> setLocale(Locale l) async {
    _locale = l;
    final p = await SharedPreferences.getInstance();
    await p.setString(_kLocale, l.languageCode);
    notifyListeners();
  }

  /// High-water mark of events durably stored on this PC. Kept here rather
  /// than on the device so that re-reading a range stays possible until the
  /// device's ring wraps.
  Future<void> setSyncedThroughSeq(int seq) async {
    if (seq <= _syncedThroughSeq) return;
    _syncedThroughSeq = seq;
    final p = await SharedPreferences.getInstance();
    await p.setInt(_kSyncSeq, seq);
    notifyListeners();
  }
}
