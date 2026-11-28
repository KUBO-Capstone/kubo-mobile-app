import 'package:flutter/material.dart';

import '../../../shared/data/profile_service.dart';
import '../../../shared/widgets/kubo_discard_changes.dart';
import '../../../shared/widgets/kubo_password_field.dart';

class ChangePasswordPage extends StatefulWidget {
  const ChangePasswordPage({super.key, required this.userId});

  final int userId;

  @override
  State<ChangePasswordPage> createState() => _ChangePasswordPageState();
}

class _ChangePasswordPageState extends State<ChangePasswordPage> {
  static const _minLength = 8;

  final _current = TextEditingController();
  final _next = TextEditingController();
  final _confirmation = TextEditingController();
  final _service = ProfileService();
  bool _saving = false;

  /// Set by Save; before that a field only complains once something is in it.
  bool _submitted = false;

  @override
  void initState() {
    super.initState();
    for (final controller in [_current, _next, _confirmation]) {
      controller.addListener(() => setState(() {}));
    }
  }

  @override
  void dispose() {
    _current.dispose();
    _next.dispose();
    _confirmation.dispose();
    _service.dispose();
    super.dispose();
  }

  String? get _currentError => _submitted && _current.text.isEmpty ? 'Enter your current password.' : null;

  String? get _nextError {
    final text = _next.text;
    if (text.isEmpty) return _submitted ? 'Choose a new password.' : null;
    if (text.length < _minLength) return 'At least $_minLength characters (${text.length} so far).';
    return null;
  }

  String? get _confirmationError {
    final text = _confirmation.text;
    if (text.isEmpty) return _submitted ? 'Type the new password again.' : null;
    // Wait until it is as long as the new one before calling it a mismatch.
    if (text != _next.text && (_submitted || text.length >= _next.text.length)) return 'Does not match the new password.';
    return null;
  }

  bool get _hasUnsavedChanges =>
      !_saving && (_current.text.isNotEmpty || _next.text.isNotEmpty || _confirmation.text.isNotEmpty);

  Future<void> _save() async {
    setState(() => _submitted = true);
    if (_currentError != null || _nextError != null || _confirmationError != null) return;
    setState(() => _saving = true);
    try {
      await _service.changePassword(
        userId: widget.userId,
        currentPassword: _current.text,
        newPassword: _next.text,
      );
      if (mounted) {
        _message('Password updated successfully.');
        Navigator.of(context).pop();
      }
    } catch (error) {
      if (mounted) _message(error.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _message(String text) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  @override
  Widget build(BuildContext context) {
    return KuboUnsavedChangesScope(
      hasUnsavedChanges: _hasUnsavedChanges,
      message: 'The passwords you typed will be cleared.',
      child: Scaffold(
        appBar: AppBar(title: const Text('Change Password')),
        body: AutofillGroup(
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              KuboPasswordField(
                controller: _current,
                textInputAction: TextInputAction.next,
                autofillHints: const [AutofillHints.password],
                decoration: InputDecoration(labelText: 'Current Password', errorText: _currentError),
              ),
              const SizedBox(height: 16),
              KuboPasswordField(
                controller: _next,
                textInputAction: TextInputAction.next,
                autofillHints: const [AutofillHints.newPassword],
                decoration: InputDecoration(
                  labelText: 'New Password',
                  helperText: 'At least $_minLength characters',
                  errorText: _nextError,
                ),
              ),
              const SizedBox(height: 16),
              KuboPasswordField(
                controller: _confirmation,
                textInputAction: TextInputAction.done,
                autofillHints: const [AutofillHints.newPassword],
                onSubmitted: (_) {
                  if (!_saving) _save();
                },
                decoration: InputDecoration(labelText: 'Confirm New Password', errorText: _confirmationError),
              ),
              const SizedBox(height: 24),
              SizedBox(
                height: 50,
                child: FilledButton(
                  onPressed: _saving ? null : _save,
                  child: Text(_saving ? 'Saving...' : 'Update Password'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
