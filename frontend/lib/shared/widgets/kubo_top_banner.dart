import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';

/// A message that drops down from the top of the screen, above every page
/// and sheet, then slides back up on its own after a few seconds, when its
/// button is tapped, or when it is swiped away (up, or to either side).
///
/// One at a time: showing the same message again keeps the one on screen
/// up for longer instead of dropping it in twice; a different message takes
/// its place.
abstract final class KuboTopBanner {
  static _ShownBanner? _current;

  static void show(
    BuildContext context, {
    required String title,
    required String message,
    IconData icon = Icons.info_outline,
    String? actionLabel,
    VoidCallback? onAction,
    Duration duration = const Duration(seconds: 5),
  }) {
    final overlay = Overlay.maybeOf(context, rootOverlay: true);
    if (overlay == null) return;

    final current = _current;
    if (current != null && current.title == title && current.message == message) {
      current.key.currentState?.restartTimer();
      return;
    }
    current?.remove();

    final key = GlobalKey<_TopBannerState>();
    late final _ShownBanner shown;
    final entry = OverlayEntry(
      builder: (_) => _TopBanner(
        key: key,
        title: title,
        message: message,
        icon: icon,
        actionLabel: actionLabel,
        onAction: onAction,
        duration: duration,
        onGone: () => shown.remove(),
        onDisposed: () => shown.forget(),
      ),
    );
    shown = _ShownBanner(entry, key, title, message);
    _current = shown;
    overlay.insert(entry);
  }

  /// Slides away the banner on screen, if there is one.
  static void hide() => _current?.key.currentState?.close();
}

class _ShownBanner {
  _ShownBanner(this.entry, this.key, this.title, this.message);

  final OverlayEntry entry;
  final GlobalKey<_TopBannerState> key;
  final String title;
  final String message;
  bool _removed = false;

  void remove() {
    if (_removed) return;
    entry.remove();
    forget();
  }

  /// No longer the banner on screen. Also called when the screen under it
  /// was torn down without it closing (a test ending, a hot restart), so
  /// the next banner is not mistaken for a repeat of one that is gone.
  void forget() {
    _removed = true;
    if (KuboTopBanner._current == this) KuboTopBanner._current = null;
  }
}

class _TopBanner extends StatefulWidget {
  const _TopBanner({
    super.key,
    required this.title,
    required this.message,
    required this.icon,
    required this.duration,
    required this.onGone,
    required this.onDisposed,
    this.actionLabel,
    this.onAction,
  });

  final String title;
  final String message;
  final IconData icon;
  final String? actionLabel;
  final VoidCallback? onAction;

  /// How long it stays before sliding back up by itself.
  final Duration duration;

  /// Called once it is off screen, however it left.
  final VoidCallback onGone;

  /// Called when its state goes, whether or not [onGone] ran first.
  final VoidCallback onDisposed;

  @override
  State<_TopBanner> createState() => _TopBannerState();
}

class _TopBannerState extends State<_TopBanner> with SingleTickerProviderStateMixin {
  // Eases out as it drops in and eases in as it leaves, so it settles gently
  // and then gets out of the way without lingering.
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 380),
    reverseDuration: const Duration(milliseconds: 260),
  );
  late final CurvedAnimation _curve = CurvedAnimation(
    parent: _controller,
    curve: Curves.easeOutCubic,
    reverseCurve: Curves.easeInCubic,
  );
  late final Animation<Offset> _slide = Tween<Offset>(
    begin: const Offset(0, -1.4),
    end: Offset.zero,
  ).animate(_curve);

  Timer? _timer;
  bool _leaving = false;

  @override
  void initState() {
    super.initState();
    // MediaQuery is not readable until the first frame is laid out.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (MediaQuery.disableAnimationsOf(context)) {
        _controller.value = 1;
      } else {
        _controller.forward();
      }
      restartTimer();
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    widget.onDisposed();
    _curve.dispose();
    _controller.dispose();
    super.dispose();
  }

  /// Starts the countdown to sliding away again from the full duration.
  void restartTimer() {
    _timer?.cancel();
    if (!mounted || _leaving) return;
    // With a screen reader the user needs time to hear the message and
    // reach the button, so it stays until dismissed, as a SnackBar with an
    // action does.
    if (MediaQuery.accessibleNavigationOf(context)) return;
    _timer = Timer(widget.duration, close);
  }

  /// Slides back up out of view, then goes.
  Future<void> close() async {
    if (_leaving || !mounted) return;
    _leaving = true;
    _timer?.cancel();
    if (!MediaQuery.disableAnimationsOf(context)) {
      try {
        await _controller.reverse().orCancel;
      } on TickerCanceled {
        return; // Removed some other way meanwhile.
      }
    }
    widget.onGone();
  }

  // Swiped off: Dismissible has already moved it out of view.
  void _swiped(DismissDirection _) {
    _leaving = true;
    _timer?.cancel();
    widget.onGone();
  }

  // The countdown waits while a finger is on it, and starts over if it is
  // let go without being swiped off.
  void _dragged(DismissUpdateDetails details) {
    if (_leaving) return;
    if (details.progress > 0) {
      _timer?.cancel();
    } else {
      restartTimer();
    }
  }

  void _act() {
    widget.onAction?.call();
    close();
  }

  @override
  Widget build(BuildContext context) {
    final topInset = MediaQuery.paddingOf(context).top;
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: SlideTransition(
        position: _slide,
        child: Padding(
          padding: EdgeInsets.fromLTRB(12, topInset + 8, 12, 0),
          // One for each way it can be swiped off: up, or to either side.
          child: Dismissible(
            key: const ValueKey<String>('top-banner-up'),
            direction: DismissDirection.up,
            resizeDuration: null,
            onUpdate: _dragged,
            onDismissed: _swiped,
            child: Dismissible(
              key: const ValueKey<String>('top-banner-side'),
              direction: DismissDirection.horizontal,
              resizeDuration: null,
              onUpdate: _dragged,
              onDismissed: _swiped,
              child: _card(),
            ),
          ),
        ),
      ),
    );
  }

  Widget _card() {
    final actionLabel = widget.actionLabel;
    return Semantics(
      container: true,
      liveRegion: true,
      child: Material(
        color: AppColors.white,
        elevation: 8,
        shadowColor: Colors.black26,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 14, 10, 6),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: const BoxDecoration(color: AppColors.softBackground, shape: BoxShape.circle),
                    child: Icon(widget.icon, color: AppColors.green, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.title,
                          style: const TextStyle(color: AppColors.black, fontSize: 15, fontWeight: FontWeight.w800),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          widget.message,
                          style: const TextStyle(color: AppColors.gray, fontSize: 13, height: 1.35),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              if (actionLabel != null)
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: _act,
                    style: TextButton.styleFrom(foregroundColor: AppColors.green),
                    child: Text(actionLabel, style: const TextStyle(fontWeight: FontWeight.w700)),
                  ),
                )
              else
                const SizedBox(height: 8),
              // The handle hints that it can be swiped away.
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(color: AppColors.border, borderRadius: BorderRadius.circular(2)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
