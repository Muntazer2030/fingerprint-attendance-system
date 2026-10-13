import 'package:flutter/material.dart';

import '../data/api_client.dart';
import '../data/models.dart';
import '../data/telegram_api.dart';
import '../l10n/app_localizations.dart';
import '../main.dart';
import 'theme.dart';

/// Telegram alerts, sent by the terminal itself.
///
/// The app's part is setup: checking the bot token, finding the admin's chat,
/// and choosing what to send. The terminal stores all of it and sends on its
/// own, judging lateness against the schedule the app pushes on every sync.
class TelegramPage extends StatefulWidget {
  const TelegramPage({super.key, required this.api});

  final ApiClient api;

  @override
  State<TelegramPage> createState() => _TelegramPageState();
}

class _TelegramPageState extends State<TelegramPage> {
  NotifyStatus? _status;
  Object? _loadError;
  bool _busy = false;

  final _token = TextEditingController();
  final _chat = TextEditingController();
  bool _enabled = false;
  bool _eachPunch = true;
  bool _late = true;
  int? _summaryMinute;

  String? _botName;
  String? _tokenError;
  List<TelegramChat>? _chats;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _token.dispose();
    _chat.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final s = await widget.api.notifyStatus();
      if (!mounted) return;
      setState(() {
        _status = s;
        _loadError = null;
        _enabled = s.enabled;
        _eachPunch = s.eachPunch;
        _late = s.late;
        _summaryMinute = s.summaryMinute;
        if (_chat.text.isEmpty) _chat.text = s.chatId;
      });
    } catch (e) {
      if (mounted) setState(() => _loadError = e);
    }
  }

  void _snack(String text) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));

  Future<void> _run(Future<void> Function() action) async {
    setState(() => _busy = true);
    try {
      await action();
    } catch (e) {
      if (mounted) _snack(e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// The token typed now, or none when the field is empty and the terminal
  /// already holds one -- it is never read back from the terminal.
  String? get _typedToken {
    final t = _token.text.trim();
    return t.isEmpty ? null : t;
  }

  Future<void> _checkToken() => _run(() async {
    final l = AppLocalizations.of(context)!;
    final t = _typedToken;
    if (t == null || !TelegramApi.looksLikeToken(t)) {
      setState(() => _tokenError = l.tgTokenInvalid);
      return;
    }
    final tg = TelegramApi(t);
    try {
      final name = await tg.botName();
      setState(() {
        _botName = name;
        _tokenError = null;
      });
    } on TelegramException catch (e) {
      setState(() {
        _botName = null;
        _tokenError = e.message;
      });
    } finally {
      tg.close();
    }
  });

  Future<void> _findChats() => _run(() async {
    final l = AppLocalizations.of(context)!;
    final t = _typedToken;
    if (t == null) {
      setState(() => _tokenError = l.tgTokenNeededForFind);
      return;
    }
    final tg = TelegramApi(t);
    try {
      final chats = await tg.recentChats();
      setState(() {
        _chats = chats;
        if (chats.length == 1) _chat.text = chats.first.id;
      });
    } on TelegramException catch (e) {
      _snack(e.message);
    } finally {
      tg.close();
    }
  });

  Future<void> _save() => _run(() async {
    final l = AppLocalizations.of(context)!;
    final t = _typedToken;
    if (t != null && !TelegramApi.looksLikeToken(t)) {
      setState(() => _tokenError = l.tgTokenInvalid);
      return;
    }
    final s = await widget.api.setNotify(
      enabled: _enabled,
      eachPunch: _eachPunch,
      late: _late,
      summaryMinute: _summaryMinute,
      clearSummary: _summaryMinute == null,
      chatId: _chat.text.trim(),
      botToken: t,
    );
    if (!mounted) return;
    // Names and the schedule go now rather than at the next sync, so the
    // first alert after saving already has them.
    await AppScope.syncOf(context).pushRosterNow(widget.api);
    if (!mounted) return;
    setState(() {
      _status = s;
      _token.clear();
    });
    _snack(l.saved);
    await _load();
  });

  /// The terminal queues the message and sends it in the background, so the
  /// outcome is only known a few seconds later.
  Future<void> _send(Future<NotifyStatus> Function() action) => _run(() async {
    final l = AppLocalizations.of(context)!;
    await action();
    if (mounted) _snack(l.tgQueued);
    await Future<void>.delayed(const Duration(seconds: 6));
    await _load();
  });

  Future<void> _pickTime() async {
    final m = _summaryMinute ?? 22 * 60;
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: m ~/ 60, minute: m % 60),
    );
    if (picked != null) {
      setState(() => _summaryMinute = picked.hour * 60 + picked.minute);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final s = _status;

    return Scaffold(
      appBar: AppBar(
        title: Text(l.tgTitle),
        actions: [
          IconButton(
            tooltip: l.refresh,
            onPressed: _busy ? null : _load,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: _loadError != null
          ? Center(child: Text(_loadError.toString()))
          : s == null
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(24),
              children: [
                CappedWidth(
                  maxWidth: 600,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l.tgIntro,
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                      const SizedBox(height: 16),
                      _StatusCard(status: s),
                      _section(context, l.tgStepBot),
                      Text(
                        l.tgStepBotHelp,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        controller: _token,
                        decoration: InputDecoration(
                          labelText: l.tgBotToken,
                          hintText: s.hasBotToken
                              ? l.tgTokenSet(s.botTokenHint)
                              : '123456789:AA…',
                          errorText: _tokenError,
                          helperText: _botName == null ? null : '✓ $_botName',
                          prefixIcon: const Icon(Icons.smart_toy_outlined),
                        ),
                        onChanged: (_) => setState(() {
                          _botName = null;
                          _tokenError = null;
                        }),
                      ),
                      const SizedBox(height: 8),
                      OutlinedButton.icon(
                        onPressed: _busy ? null : _checkToken,
                        icon: const Icon(Icons.verified_outlined),
                        label: Text(l.tgCheckToken),
                      ),
                      _section(context, l.tgStepChat),
                      Text(
                        l.tgStepChatHelp,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                      const SizedBox(height: 10),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _chat,
                              decoration: InputDecoration(
                                labelText: l.tgChatId,
                                prefixIcon: const Icon(
                                  Icons.chat_bubble_outline,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Padding(
                            padding: const EdgeInsets.only(top: 6),
                            child: OutlinedButton.icon(
                              onPressed: _busy ? null : _findChats,
                              icon: const Icon(Icons.search),
                              label: Text(l.tgFindChat),
                            ),
                          ),
                        ],
                      ),
                      if (_chats != null) ...[
                        const SizedBox(height: 8),
                        if (_chats!.isEmpty)
                          Text(
                            l.tgNoChats,
                            style: const TextStyle(color: AppTheme.warning),
                          )
                        else
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              for (final c in _chats!)
                                ChoiceChip(
                                  label: Text('${c.title} (${c.id})'),
                                  selected: _chat.text == c.id,
                                  onSelected: (_) =>
                                      setState(() => _chat.text = c.id),
                                ),
                            ],
                          ),
                      ],
                      _section(context, l.tgStepWhat),
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(l.tgEnabled),
                        value: _enabled,
                        onChanged: (v) => setState(() => _enabled = v),
                      ),
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(l.tgEachPunch),
                        subtitle: Text(l.tgEachPunchHelp),
                        value: _eachPunch,
                        onChanged: _enabled
                            ? (v) => setState(() => _eachPunch = v)
                            : null,
                      ),
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(l.tgLate),
                        subtitle: Text(l.tgLateHelp),
                        value: _late,
                        onChanged: _enabled
                            ? (v) => setState(() => _late = v)
                            : null,
                      ),
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(l.tgSummary),
                        subtitle: Text(l.tgSummaryHelp),
                        value: _summaryMinute != null,
                        onChanged: _enabled
                            ? (v) => setState(
                                () => _summaryMinute = v ? 22 * 60 : null,
                              )
                            : null,
                      ),
                      if (_summaryMinute != null)
                        Align(
                          alignment: AlignmentDirectional.centerStart,
                          child: TextButton.icon(
                            onPressed: _enabled ? _pickTime : null,
                            icon: const Icon(Icons.schedule),
                            label: Text(
                              l.tgSummaryAt(
                                TimeOfDay(
                                  hour: _summaryMinute! ~/ 60,
                                  minute: _summaryMinute! % 60,
                                ).format(context),
                              ),
                            ),
                          ),
                        ),
                      const SizedBox(height: 24),
                      Wrap(
                        spacing: 12,
                        runSpacing: 12,
                        children: [
                          FilledButton.icon(
                            onPressed: _busy ? null : _save,
                            icon: _busy
                                ? const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Icon(Icons.check),
                            label: Text(l.save),
                          ),
                          OutlinedButton.icon(
                            onPressed: _busy || !s.hasBotToken
                                ? null
                                : () => _send(widget.api.notifyTest),
                            icon: const Icon(Icons.send_outlined),
                            label: Text(l.tgSendTest),
                          ),
                          OutlinedButton.icon(
                            onPressed: _busy || !s.hasBotToken
                                ? null
                                : () => _send(widget.api.notifySummaryNow),
                            icon: const Icon(Icons.summarize_outlined),
                            label: Text(l.tgSendSummary),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }

  static Widget _section(BuildContext context, String title) => Padding(
    padding: const EdgeInsets.only(top: 28, bottom: 8),
    child: Text(title, style: Theme.of(context).textTheme.titleMedium),
  );
}

/// What the terminal reports: is it set up, is it delivering, and does it
/// hold a schedule to judge lateness against.
class _StatusCard extends StatelessWidget {
  const _StatusCard({required this.status});

  final NotifyStatus status;

  static String _day(int key) =>
      '${key % 100}/${(key ~/ 100) % 100}/${key ~/ 10000}';

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final s = status;
    final ready = s.enabled && s.hasBotToken && s.chatId.isNotEmpty;

    final lines = <(IconData, Color?, String)>[
      if (!ready)
        (Icons.notifications_off_outlined, AppTheme.absent, l.tgNotActive)
      else
        (Icons.notifications_active_outlined, AppTheme.present, l.tgActive),
      (Icons.outbox_outlined, null, l.tgCounters(s.sent, s.failed, s.dropped)),
      if (s.lastError.isNotEmpty)
        (Icons.error_outline, AppTheme.danger, l.tgLastError(s.lastError)),
      if (s.rosterDays == 0)
        (Icons.event_busy_outlined, AppTheme.warning, l.tgNoRoster)
      else
        (
          Icons.event_available_outlined,
          null,
          l.tgRoster(
            s.rosterNames,
            _day(s.rosterFirstDay),
            _day(s.rosterLastDay),
          ),
        ),
    ];

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (final (icon, color, text) in lines)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(icon, size: 18, color: color),
                    const SizedBox(width: 10),
                    Expanded(child: Text(text)),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}
