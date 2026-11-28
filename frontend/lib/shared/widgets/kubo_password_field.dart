import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';

/// A password field with an eye button to show or hide what was typed.
/// [decoration] is the page's usual field look; the button goes in its
/// suffix.
class KuboPasswordField extends StatefulWidget {
  const KuboPasswordField({
    super.key,
    required this.controller,
    required this.decoration,
    this.textInputAction,
    this.onSubmitted,
    this.autofillHints,
    this.onChanged,
  });

  final TextEditingController controller;
  final InputDecoration decoration;
  final TextInputAction? textInputAction;
  final ValueChanged<String>? onSubmitted;
  final ValueChanged<String>? onChanged;

  /// e.g. [AutofillHints.password] or [AutofillHints.newPassword], so the
  /// phone's password manager can fill or save it.
  final Iterable<String>? autofillHints;

  @override
  State<KuboPasswordField> createState() => _KuboPasswordFieldState();
}

class _KuboPasswordFieldState extends State<KuboPasswordField> {
  bool _hidden = true;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: widget.controller,
      obscureText: _hidden,
      enableSuggestions: false,
      autocorrect: false,
      keyboardType: TextInputType.visiblePassword,
      textInputAction: widget.textInputAction,
      onFieldSubmitted: widget.onSubmitted,
      onChanged: widget.onChanged,
      autofillHints: widget.autofillHints,
      decoration: widget.decoration.copyWith(
        suffixIcon: IconButton(
          tooltip: _hidden ? 'Show password' : 'Hide password',
          onPressed: () => setState(() => _hidden = !_hidden),
          icon: Icon(
            _hidden ? Icons.visibility_outlined : Icons.visibility_off_outlined,
            color: AppColors.gray,
          ),
        ),
      ),
    );
  }
}
