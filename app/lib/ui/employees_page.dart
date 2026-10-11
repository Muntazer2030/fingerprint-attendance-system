import 'package:flutter/material.dart';

import '../data/api_client.dart';
import '../data/database.dart';
import '../data/models.dart';
import '../data/sync_service.dart';
import '../l10n/app_localizations.dart';
import '../main.dart';
import 'names.dart';
import 'theme.dart';

/// One person as the app sees them: the name and history kept on this PC,
/// joined with what the terminal currently knows.
class _Person {
  _Person({required this.id, this.local, this.device});

  final int id;
  final EmployeeRow? local;
  final Employee? device;

  String get name => local?.name.trim() ?? '';
  String get jobTitle => local?.jobTitle.trim() ?? '';
  bool get removed => local?.removed ?? false;
  bool get onDevice => device != null;
  int get fingers => device?.fingers ?? 0;
  int get failCount => device?.failCount ?? 0;
  bool get present => device?.isPresent ?? false;
}

class _Roster {
  _Roster(this.people, {required this.deviceReachable, this.deviceError});
  final List<_Person> people;
  final bool deviceReachable;
  final Object? deviceError;

  int nextFreeId() {
    final used = people.map((p) => p.id).toSet();
    var id = 1;
    while (used.contains(id)) {
      id++;
    }
    return id;
  }
}

/// The staff list.
///
/// Built from the local database first, with the terminal's view merged in.
/// It used to come from the terminal alone, which meant it showed IDs with no
/// names, went blank whenever the terminal was unreachable, and had no way to
/// show people the terminal had forgotten (after "clear fingerprints").
class EmployeesPage extends StatefulWidget {
  const EmployeesPage({super.key, required this.api});

  final ApiClient api;

  @override
  State<EmployeesPage> createState() => _EmployeesPageState();
}

class _EmployeesPageState extends State<EmployeesPage> {
  Future<_Roster>? _future;
  SyncService? _sync;
  int _seenRevision = -1;
  bool _showRemoved = false;
  _Roster? _roster;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final sync = AppScope.syncOf(context);
    if (!identical(sync, _sync)) {
      _sync?.removeListener(_onSync);
      _sync = sync..addListener(_onSync);
      _seenRevision = sync.revision;
    }
    _future ??= _startLoad();
  }

  @override
  void dispose() {
    _sync?.removeListener(_onSync);
    super.dispose();
  }

  void _onSync() {
    final rev = _sync!.revision;
    if (rev != _seenRevision && mounted) {
      _seenRevision = rev;
      _refresh();
    }
  }

  /// Loads, and hands the result to the floating button too -- it lives in
  /// the Scaffold, outside the FutureBuilder that would otherwise rebuild it.
  Future<_Roster> _startLoad() {
    final f = _load();
    f.then((r) {
      if (mounted) setState(() => _roster = r);
    }, onError: (_) {});
    return f;
  }

  Future<_Roster> _load() async {
    final db = AppScope.dbOf(context);
    List<Employee>? remote;
    Object? error;
    try {
      remote = await widget.api.employees();
    } catch (e) {
      error = e;
    }

    final local = await db.allEmployees();
    final byId = <int, _Person>{};
    for (final r in local) {
      byId[r.id] = _Person(id: r.id, local: r);
    }
    for (final e in remote ?? const <Employee>[]) {
      byId[e.id] = _Person(id: e.id, local: byId[e.id]?.local, device: e);
    }
    final people = byId.values.toList()..sort((a, b) => a.id.compareTo(b.id));
    return _Roster(people, deviceReachable: remote != null, deviceError: error);
  }

  void _refresh() => setState(() {
    _future = _startLoad();
  });

  void _toast(String msg, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: error ? AppTheme.danger : null,
      ),
    );
  }

  /// Runs an action that talks to the terminal and reports failure instead
  /// of letting it vanish. These handlers used to be bare `await`s: with the
  /// terminal offline the button did nothing and said nothing.
  Future<bool> _guard(Future<void> Function() action, {String? success}) async {
    try {
      await action();
      if (success != null) _toast(success);
      return true;
    } catch (e) {
      _toast(e.toString(), error: true);
      return false;
    } finally {
      _refresh();
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;

    final roster = _roster;
    final reachable = roster?.deviceReachable ?? false;

    return Scaffold(
      // The Scaffold's own slot, not a Positioned inside the body: a snackbar
      // ("Saved") slid over a hand-placed button and made it unclickable for
      // four seconds after every save. Scaffold moves its FAB clear of it.
      floatingActionButton: roster == null
          ? null
          : FloatingActionButton.extended(
              onPressed: reachable ? () => _edit(roster, null) : null,
              backgroundColor: reachable
                  ? null
                  : Theme.of(context).disabledColor,
              icon: const Icon(Icons.person_add),
              label: Text(l.addEmployee),
            ),
      appBar: AppBar(
        title: Text(l.navEmployees),
        actions: [
          IconButton(
            onPressed: _refresh,
            icon: const Icon(Icons.refresh),
            tooltip: l.refresh,
          ),
        ],
      ),
      body: FutureBuilder<_Roster>(
        future: _future,
        builder: (context, snap) {
          if (!snap.hasData) {
            return snap.hasError
                ? Center(child: Text(snap.error.toString()))
                : const Center(child: CircularProgressIndicator());
          }
          final roster = snap.data!;
          final current = roster.people.where((p) => !p.removed).toList();
          final removed = roster.people.where((p) => p.removed).toList();

          return Stack(
            children: [
              ListView(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 96),
                children: [
                  if (!roster.deviceReachable)
                    _Notice(
                      icon: Icons.cloud_off,
                      text: l.employeesOffline,
                      color: AppTheme.warning,
                    ),
                  if (current.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 48),
                      child: Center(child: Text(l.noEmployees)),
                    ),
                  for (final p in current)
                    _EmployeeCard(
                      person: p,
                      deviceReachable: roster.deviceReachable,
                      onEnroll: () => _enroll(p),
                      onEdit: () => _edit(roster, p),
                      onDelete: () => _delete(p),
                      onPush: () => _push(p),
                    ),
                  if (removed.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    TextButton.icon(
                      onPressed: () =>
                          setState(() => _showRemoved = !_showRemoved),
                      icon: Icon(
                        _showRemoved ? Icons.expand_less : Icons.expand_more,
                      ),
                      label: Text('${l.removedEmployees} (${removed.length})'),
                    ),
                    if (_showRemoved)
                      for (final p in removed)
                        _RemovedCard(
                          person: p,
                          onRestore: roster.deviceReachable
                              ? () => _push(p, restoring: true)
                              : null,
                        ),
                  ],
                ],
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _edit(_Roster roster, _Person? existing) async {
    final l = AppLocalizations.of(context)!;
    final result = await showDialog<_EmployeeForm>(
      context: context,
      builder: (_) => _EmployeeDialog(
        existing: existing,
        suggestedId: roster.nextFreeId(),
        taken: {
          for (final p in roster.people)
            if (p.id != existing?.id) p.id: p.name,
        },
      ),
    );
    if (result == null || !mounted) return;

    final sync = AppScope.syncOf(context);
    await _guard(
      () => sync.saveEmployee(
        widget.api,
        id: result.id,
        name: result.name,
        jobTitle: result.jobTitle,
      ),
      success: l.saved,
    );
  }

  /// Sends someone the terminal does not have (again) -- after the terminal's
  /// fingerprints were cleared, or to restore a removed employee.
  Future<void> _push(_Person p, {bool restoring = false}) async {
    final l = AppLocalizations.of(context)!;
    final sync = AppScope.syncOf(context);
    await _guard(
      () => sync.saveEmployee(
        widget.api,
        id: p.id,
        name: p.name,
        jobTitle: p.jobTitle,
      ),
      success: restoring ? l.restored : l.sentToTerminal,
    );
  }

  Future<void> _delete(_Person p) async {
    final l = AppLocalizations.of(context)!;
    final label = p.name.isEmpty ? '${l.employeeId} ${p.id}' : p.name;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('${l.delete} $label?'),
        content: Text(l.deleteEmployeeHint),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(l.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: AppTheme.danger),
            child: Text(l.delete),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;

    // Through the sync service, not straight to the API. Calling the API
    // alone removed them from the terminal but left the row here, where it
    // could never be removed again.
    final sync = AppScope.syncOf(context);
    await _guard(() => sync.removeEmployee(widget.api, p.id));
  }

  Future<void> _enroll(_Person p) async {
    final enrolled = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => EnrollDialog(
        api: widget.api,
        employeeId: p.id,
        employeeName: p.name,
        finger: p.fingers,
      ),
    );
    if (!mounted) return;
    if (enrolled == true) {
      // Pull so the cached finger count used by reports is current too.
      await AppScope.syncOf(context).pull();
    }
    _refresh();
  }
}

class _Notice extends StatelessWidget {
  const _Notice({required this.icon, required this.text, required this.color});
  final IconData icon;
  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(icon, size: 20),
          const SizedBox(width: 12),
          Expanded(child: Text(text)),
        ],
      ),
    );
  }
}

class _EmployeeCard extends StatelessWidget {
  const _EmployeeCard({
    required this.person,
    required this.deviceReachable,
    required this.onEnroll,
    required this.onEdit,
    required this.onDelete,
    required this.onPush,
  });

  final _Person person;
  final bool deviceReachable;
  final VoidCallback onEnroll;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onPush;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final scheme = Theme.of(context).colorScheme;
    final p = person;
    final title = p.name.isEmpty ? '${l.employeeId} ${p.id}' : p.name;
    final missing = deviceReachable && !p.onDevice;

    final details = <Widget>[
      Text('#${p.id}'),
      if (p.jobTitle.isNotEmpty) Text(p.jobTitle),
      if (p.onDevice) ...[
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.fingerprint,
              size: 14,
              color: p.fingers == 0 ? AppTheme.warning : scheme.outline,
            ),
            const SizedBox(width: 3),
            Text(
              p.fingers == 0 ? l.noFingers : '${p.fingers}',
              style: p.fingers == 0 ? TextStyle(color: AppTheme.warning) : null,
            ),
          ],
        ),
        Text(p.present ? l.onSite : l.offSite),
      ],
      if (p.failCount > 0)
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline, size: 14, color: scheme.error),
            const SizedBox(width: 3),
            Text(
              '${p.failCount} ${l.failedReads}',
              style: TextStyle(color: scheme.error),
            ),
          ],
        ),
    ];

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            CircleAvatar(
              backgroundColor: (p.present ? AppTheme.present : AppTheme.absent)
                  .withValues(alpha: 0.15),
              child: Text(NameBook.initials(p.name, p.id)),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 4),
                  DefaultTextStyle.merge(
                    style: Theme.of(context).textTheme.bodySmall,
                    child: Wrap(
                      spacing: 14,
                      runSpacing: 4,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: details,
                    ),
                  ),
                  if (missing) ...[
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Icon(
                          Icons.sync_problem,
                          size: 16,
                          color: AppTheme.warning,
                        ),
                        const SizedBox(width: 6),
                        Flexible(
                          child: Text(
                            l.notOnTerminal,
                            style: TextStyle(color: AppTheme.warning),
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            if (missing)
              FilledButton.tonalIcon(
                onPressed: onPush,
                icon: const Icon(Icons.upload, size: 18),
                label: Text(l.sendToTerminal),
              )
            else
              TextButton.icon(
                onPressed: deviceReachable ? onEnroll : null,
                icon: const Icon(Icons.fingerprint, size: 18),
                label: Text(l.enrollFinger),
              ),
            IconButton(
              onPressed: deviceReachable ? onEdit : null,
              icon: const Icon(Icons.edit_outlined),
              tooltip: l.editEmployee,
            ),
            IconButton(
              onPressed: deviceReachable ? onDelete : null,
              icon: const Icon(Icons.delete_outline),
              tooltip: l.delete,
            ),
          ],
        ),
      ),
    );
  }
}

class _RemovedCard extends StatelessWidget {
  const _RemovedCard({required this.person, required this.onRestore});
  final _Person person;
  final VoidCallback? onRestore;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final p = person;
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      color: Theme.of(
        context,
      ).colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
      child: ListTile(
        leading: CircleAvatar(child: Text(NameBook.initials(p.name, p.id))),
        title: Text(p.name.isEmpty ? '${l.employeeId} ${p.id}' : p.name),
        subtitle: Text('#${p.id} · ${l.removedHint}'),
        trailing: TextButton.icon(
          onPressed: onRestore,
          icon: const Icon(Icons.restore, size: 18),
          label: Text(l.restore),
        ),
      ),
    );
  }
}

class _EmployeeForm {
  _EmployeeForm(this.id, this.name, this.jobTitle);
  final int id;
  final String name;
  final String jobTitle;
}

class _EmployeeDialog extends StatefulWidget {
  const _EmployeeDialog({
    required this.existing,
    required this.suggestedId,
    required this.taken,
  });

  final _Person? existing;
  final int suggestedId;

  /// IDs already used, with the name using them.
  final Map<int, String> taken;

  @override
  State<_EmployeeDialog> createState() => _EmployeeDialogState();
}

class _EmployeeDialogState extends State<_EmployeeDialog> {
  late final _id = TextEditingController(
    text: '${widget.existing?.id ?? widget.suggestedId}',
  );
  late final _name = TextEditingController(text: widget.existing?.name ?? '');
  late final _title = TextEditingController(
    text: widget.existing?.jobTitle ?? '',
  );
  String? _idError;
  String? _nameError;

  @override
  void dispose() {
    _id.dispose();
    _name.dispose();
    _title.dispose();
    super.dispose();
  }

  void _submit() {
    final l = AppLocalizations.of(context)!;
    final id = int.tryParse(_id.text.trim());
    String? idError;
    if (id == null || id < 1 || id > 65535) {
      idError = l.invalidEmployeeId;
    } else if (widget.taken.containsKey(id)) {
      final who = widget.taken[id]!;
      idError = who.isEmpty ? l.idInUse : '${l.idInUse}: $who';
    }
    final nameError = _name.text.trim().isEmpty ? l.nameRequired : null;

    setState(() {
      _idError = idError;
      _nameError = nameError;
    });
    if (idError != null || nameError != null) return;

    Navigator.pop(
      context,
      _EmployeeForm(id!, _name.text.trim(), _title.text.trim()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final editing = widget.existing != null;

    return AlertDialog(
      title: Text(editing ? l.editEmployee : l.addEmployee),
      content: SizedBox(
        width: 360,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _id,
              enabled: !editing, // the terminal keys templates by this ID
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: l.employeeId,
                errorText: _idError,
                helperText: editing ? null : l.employeeIdHelp,
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _name,
              autofocus: true,
              decoration: InputDecoration(
                labelText: l.employeeName,
                errorText: _nameError,
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _title,
              decoration: InputDecoration(labelText: l.jobTitle),
              onSubmitted: (_) => _submit(),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(l.cancel),
        ),
        FilledButton(onPressed: _submit, child: Text(editing ? l.save : l.add)),
      ],
    );
  }
}

/// Mirrors the device-side enrolment state machine so the user knows what to
/// do at each step. The device drives the sequence; this only reports it.
/// Pops `true` when a finger was stored.
class EnrollDialog extends StatefulWidget {
  const EnrollDialog({
    super.key,
    required this.api,
    required this.employeeId,
    this.employeeName = '',
    required this.finger,
  });

  final ApiClient api;
  final int employeeId;
  final String employeeName;
  final int finger;

  @override
  State<EnrollDialog> createState() => _EnrollDialogState();
}

class _EnrollDialogState extends State<EnrollDialog> {
  EnrollStatus? _status;
  Object? _error;
  int _sessionId = 0;
  bool _cancelling = false;

  @override
  void initState() {
    super.initState();
    _run();
  }

  Future<void> _run() async {
    try {
      final started = await widget.api.startEnroll(
        widget.employeeId,
        finger: widget.finger,
      );
      _sessionId = started.sessionId;
      if (mounted) setState(() => _status = started);

      await for (final s in widget.api.watchEnroll()) {
        if (!mounted) return;
        setState(() => _status = s);
      }
    } catch (e) {
      if (mounted) setState(() => _error = e);
    }
  }

  Future<void> _cancel() async {
    setState(() => _cancelling = true);
    if (_sessionId != 0) {
      try {
        await widget.api.cancelEnroll(_sessionId);
      } catch (_) {
        // The session may already have ended on the device; closing the
        // dialog is still the right outcome. Previously an error here left
        // the dialog stuck open with no way out.
      }
    }
    if (mounted) Navigator.pop(context, false);
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final s = _status;

    final (String message, IconData icon) = switch (s?.state) {
      EnrollState.waitingFinger => (l.enrollPlaceFinger, Icons.fingerprint),
      EnrollState.liftFinger => (l.enrollLiftFinger, Icons.pan_tool_outlined),
      EnrollState.waitingFingerAgain => (l.enrollPlaceAgain, Icons.fingerprint),
      EnrollState.merging => (l.enrollSaving, Icons.hourglass_top),
      EnrollState.stored => (l.enrollStored, Icons.check_circle_outline),
      EnrollState.failed => (s?.reason ?? l.enrollFailed, Icons.error_outline),
      _ => (l.enrollStarting, Icons.hourglass_empty),
    };

    final stored = s?.state == EnrollState.stored;
    final done = stored || s?.state == EnrollState.failed || _error != null;
    final who = widget.employeeName.isEmpty
        ? '${l.employeeId} ${widget.employeeId}'
        : widget.employeeName;

    return AlertDialog(
      title: Text('${l.enrollFinger} · $who'),
      content: SizedBox(
        width: 320,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 56,
              color: _error != null || s?.state == EnrollState.failed
                  ? Theme.of(context).colorScheme.error
                  : stored
                  ? AppTheme.present
                  : Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(height: 16),
            Text(
              _error?.toString() ?? message,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 16),
            if (!done) const LinearProgressIndicator(),
          ],
        ),
      ),
      actions: [
        if (!done)
          TextButton(
            onPressed: _cancelling ? null : _cancel,
            child: Text(l.cancel),
          )
        else
          FilledButton(
            onPressed: () => Navigator.pop(context, stored),
            child: Text(l.ok),
          ),
      ],
    );
  }
}
