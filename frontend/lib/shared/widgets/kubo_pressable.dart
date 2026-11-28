import 'package:flutter/material.dart';

/// Press feedback for things a Material ripple cannot show on: photos,
/// map pins, avatars. While a finger is down the child shrinks a little and
/// dims, so a tap visibly lands before the next screen opens.
class KuboPressable extends StatefulWidget {
  const KuboPressable({super.key, required this.onTap, required this.child, this.pressedScale = 0.95});

  final VoidCallback? onTap;
  final Widget child;
  final double pressedScale;

  @override
  State<KuboPressable> createState() => _KuboPressableState();
}

class _KuboPressableState extends State<KuboPressable> {
  bool _pressed = false;

  void _setPressed(bool value) {
    if (_pressed != value && mounted) setState(() => _pressed = value);
  }

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onTap != null;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: widget.onTap,
      onTapDown: enabled ? (_) => _setPressed(true) : null,
      onTapUp: enabled ? (_) => _setPressed(false) : null,
      onTapCancel: enabled ? () => _setPressed(false) : null,
      child: AnimatedScale(
        scale: _pressed ? widget.pressedScale : 1,
        duration: const Duration(milliseconds: 90),
        curve: Curves.easeOut,
        child: AnimatedOpacity(
          opacity: _pressed ? 0.75 : 1,
          duration: const Duration(milliseconds: 90),
          child: widget.child,
        ),
      ),
    );
  }
}
