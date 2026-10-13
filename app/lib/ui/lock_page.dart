import 'package:flutter/material.dart';

import '../data/settings.dart';
import '../l10n/app_localizations.dart';
import '../main.dart';
import 'theme.dart';

/// Shown instead of the app until the password is entered.
class LockPage extends StatefulWidget {
  const LockPage({super.key});

  @override
  State<LockPage> createState() => _LockPageState();
}

class _LockPageState extends State<LockPage> {
  final _password = TextEditingController();
  final _focus = FocusNode();
  String? _error;

  @override
  void dispose() {
    _password.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _unlock() {
    final l = AppLocalizations.of(context)!;
    final ok = AppScope.settingsOf(context).unlock(_password.text);
    if (!ok) {
      setState(() => _error = l.wrongPassword);
      _password.clear();
      // Enter submits and drops focus; put it back so a retry is just typing.
      _focus.requestFocus();
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 340),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: scheme.primary,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Icon(Icons.lock_outline, color: scheme.onPrimary),
                ),
                const SizedBox(height: 16),
                Text(
                  l.appTitle,
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 6),
                Text(
                  l.enterPassword,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 24),
                TextField(
                  controller: _password,
                  focusNode: _focus,
                  autofocus: true,
                  obscureText: true,
                  onSubmitted: (_) => _unlock(),
                  decoration: InputDecoration(
                    labelText: l.password,
                    errorText: _error,
                    prefixIcon: const Icon(Icons.key_outlined),
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: _unlock,
                    child: Text(l.unlock),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Set, change or remove the app password. Changing or removing asks for the
/// current one first, so an unlocked PC left unattended cannot be re-keyed.
enum PasswordAction { set, change, remove }

class PasswordDialog extends StatefulWidget {
  const PasswordDialog({
    super.key,
    required this.action,
    required this.settings,
  });

  final PasswordAction action;

  /// Passed in explicitly so the dialog does not depend on where it is shown.
  /// (It once looked settings up through AppScope while AppScope only wrapped
  /// the home route, and Save crashed.)
  final Settings settings;

  @override
  State<PasswordDialog> createState() => _PasswordDialogState();
}

class _PasswordDialogState extends State<PasswordDialog> {
  final _current = TextEditingController();
  final _next = TextEditingController();
  final _repeat = TextEditingController();
  String? _currentError;
  String? _nextError;
  String? _repeatError;

  static const minLength = 4;

  bool get _needsCurrent => widget.action != PasswordAction.set;
  bool get _needsNew => widget.action != PasswordAction.remove;

  @override
  void dispose() {
    _current.dispose();
    _next.dispose();
    _repeat.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final l = AppLocalizations.of(context)!;
    final settings = widget.settings;
    setState(() {
      _currentError = _needsCurrent && !settings.checkPassword(_current.text)
          ? l.wrongPassword
          : null;
      _nextError = _needsNew && _next.text.length < minLength
          ? l.passwordTooShort
          : null;
      _repeatError =
          _needsNew && _nextError == null && _next.text != _repeat.text
          ? l.passwordsDontMatch
          : null;
    });
    if (_currentError != null || _nextError != null || _repeatError != null) {
      return;
    }
    if (_needsNew) {
      await settings.setPassword(_next.text);
    } else {
      await settings.removePassword();
    }
    if (mounted) Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final title = switch (widget.action) {
      PasswordAction.set => l.setPassword,
      PasswordAction.change => l.changePassword,
      PasswordAction.remove => l.removePassword,
    };

    Widget field(
      TextEditingController c,
      String label,
      String? error, {
      bool autofocus = false,
    }) => Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextField(
        controller: c,
        obscureText: true,
        autofocus: autofocus,
        onSubmitted: (_) => _save(),
        decoration: InputDecoration(labelText: label, errorText: error),
      ),
    );

    return AlertDialog(
      title: Text(title),
      content: SizedBox(
        width: 360,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (_needsCurrent)
              field(
                _current,
                l.currentPassword,
                _currentError,
                autofocus: true,
              ),
            if (_needsNew) ...[
              field(
                _next,
                l.newPassword,
                _nextError,
                autofocus: !_needsCurrent,
              ),
              field(_repeat, l.confirmPassword, _repeatError),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: Text(l.cancel),
        ),
        FilledButton(
          onPressed: _save,
          style: widget.action == PasswordAction.remove
              ? FilledButton.styleFrom(backgroundColor: AppTheme.danger)
              : null,
          child: Text(
            widget.action == PasswordAction.remove ? l.removePassword : l.save,
          ),
        ),
      ],
    );
  }
}
