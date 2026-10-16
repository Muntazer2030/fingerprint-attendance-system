import 'package:flutter/material.dart';

import '../data/settings.dart';
import '../l10n/app_localizations.dart';
import 'theme.dart';

/// Confirms "Reset app". Nothing it deletes can be recovered, so it wants the
/// confirmation word typed out, and the app password when one is set: an
/// unlocked PC left unattended should not be one click from losing payroll.
///
/// Pops true once confirmed; the caller does the reset.
class ResetAppDialog extends StatefulWidget {
  const ResetAppDialog({super.key, required this.settings});

  /// Passed in for the same reason as PasswordDialog's: dialogs do not depend
  /// on where in the tree they are shown.
  final Settings settings;

  @override
  State<ResetAppDialog> createState() => _ResetAppDialogState();
}

class _ResetAppDialogState extends State<ResetAppDialog> {
  final _word = TextEditingController();
  final _password = TextEditingController();
  String? _passwordError;

  @override
  void dispose() {
    _word.dispose();
    _password.dispose();
    super.dispose();
  }

  /// The English word works in either language, so an Arabic interface on a
  /// PC without an Arabic keyboard layout is not a dead end.
  bool _wordOk(AppLocalizations l) {
    final typed = _word.text.trim().toUpperCase();
    return typed == l.resetConfirmWord.toUpperCase() || typed == 'RESET';
  }

  void _confirm() {
    final l = AppLocalizations.of(context)!;
    if (!_wordOk(l)) return;
    if (widget.settings.hasPassword &&
        !widget.settings.checkPassword(_password.text)) {
      setState(() => _passwordError = l.wrongPassword);
      return;
    }
    Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final text = Theme.of(context).textTheme;

    return AlertDialog(
      icon: const Icon(Icons.warning_amber_rounded, color: AppTheme.danger),
      title: Text(l.resetAppTitle),
      content: SizedBox(
        width: 420,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(l.resetAppBody, style: text.bodyMedium),
              const SizedBox(height: 10),
              Text(l.resetAppKeeps, style: text.bodySmall),
              const SizedBox(height: 20),
              TextField(
                controller: _word,
                autofocus: true,
                onChanged: (_) => setState(() {}),
                onSubmitted: (_) => _confirm(),
                decoration: InputDecoration(
                  labelText: l.resetConfirmLabel(l.resetConfirmWord),
                ),
              ),
              if (widget.settings.hasPassword) ...[
                const SizedBox(height: 12),
                TextField(
                  controller: _password,
                  obscureText: true,
                  onSubmitted: (_) => _confirm(),
                  decoration: InputDecoration(
                    labelText: l.currentPassword,
                    errorText: _passwordError,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: Text(l.cancel),
        ),
        FilledButton(
          onPressed: _wordOk(l) ? _confirm : null,
          style: FilledButton.styleFrom(backgroundColor: AppTheme.danger),
          child: Text(l.resetApp),
        ),
      ],
    );
  }
}
