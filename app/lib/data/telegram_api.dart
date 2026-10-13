import 'dart:convert';

import 'package:http/http.dart' as http;

/// The few Bot API calls the app makes itself, all during setup: checking a
/// token and finding the admin's chat. Messages are sent by the terminal, not
/// from here, so they keep arriving with this PC switched off.
class TelegramChat {
  const TelegramChat({required this.id, required this.title});
  final String id;
  final String title;
}

class TelegramException implements Exception {
  TelegramException(this.message);
  final String message;
  @override
  String toString() => message;
}

class TelegramApi {
  TelegramApi(this.token, {http.Client? client})
    : _client = client ?? http.Client();

  final String token;
  final http.Client _client;

  /// A bot token looks like `123456789:AA...`; anything else is a paste error.
  static bool looksLikeToken(String t) =>
      RegExp(r'^\d{5,}:[A-Za-z0-9_-]{30,}$').hasMatch(t.trim());

  Future<dynamic> _call(String method, [Map<String, String>? query]) async {
    late http.Response r;
    try {
      r = await _client
          .get(Uri.https('api.telegram.org', '/bot$token/$method', query))
          .timeout(const Duration(seconds: 12));
    } catch (_) {
      throw TelegramException('Could not reach Telegram from this computer');
    }
    Map<String, dynamic> j;
    try {
      j = jsonDecode(r.body) as Map<String, dynamic>;
    } catch (_) {
      throw TelegramException('Unexpected answer from Telegram');
    }
    if (j['ok'] != true) {
      throw TelegramException(
        (j['description'] as String?) ?? 'Telegram error ${r.statusCode}',
      );
    }
    return j['result'];
  }

  /// The bot's @username, which also proves the token works.
  Future<String> botName() async {
    final me = await _call('getMe') as Map<String, dynamic>;
    return '@${me['username']}';
  }

  /// Chats that have messaged the bot recently, newest first. The admin sends
  /// /start to the bot, then picks their chat here -- nobody has to look up a
  /// numeric id.
  Future<List<TelegramChat>> recentChats() async {
    final updates = await _call('getUpdates', {'limit': '100'}) as List;
    final seen = <String>{};
    final out = <TelegramChat>[];
    for (final u in updates.reversed) {
      final msg =
          (u as Map)['message'] ??
          u['my_chat_member'] ??
          u['channel_post'] ??
          u['edited_message'];
      final chat = (msg as Map?)?['chat'] as Map?;
      if (chat == null) continue;
      final id = '${chat['id']}';
      if (!seen.add(id)) continue;
      final title =
          (chat['title'] as String?) ??
          [
            chat['first_name'],
            chat['last_name'],
          ].whereType<String>().join(' ').trim();
      final user = chat['username'] as String?;
      out.add(
        TelegramChat(
          id: id,
          title: [
            if (title.isNotEmpty) title,
            if (user != null) '@$user',
          ].join(' '),
        ),
      );
    }
    return out;
  }

  void close() => _client.close();
}
