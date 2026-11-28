import 'package:flutter/material.dart';

/// Asks before a form with unsaved edits is left. True means discard them.
Future<bool> confirmDiscardChanges(
  BuildContext context, {
  String message = 'What you changed on this screen has not been saved.',
}) async {
  final discard = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: const Text('Discard Changes?'),
      content: Text(message),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(false),
          child: const Text('Keep Editing'),
        ),
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(true),
          style: TextButton.styleFrom(foregroundColor: Colors.red.shade700),
          child: const Text('Discard'),
        ),
      ],
    ),
  );
  return discard == true;
}

/// Wraps a form page so back (button, gesture or app-bar arrow through
/// [Navigator.maybePop]) asks first while [hasUnsavedChanges] is true.
class KuboUnsavedChangesScope extends StatelessWidget {
  const KuboUnsavedChangesScope({
    super.key,
    required this.hasUnsavedChanges,
    required this.child,
    this.message,
  });

  final bool hasUnsavedChanges;
  final Widget child;
  final String? message;

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !hasUnsavedChanges,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        final navigator = Navigator.of(context);
        final discard = message == null
            ? await confirmDiscardChanges(context)
            : await confirmDiscardChanges(context, message: message!);
        if (discard && navigator.mounted) navigator.pop();
      },
      child: child,
    );
  }
}
