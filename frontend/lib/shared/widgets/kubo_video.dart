import 'dart:io';

import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import '../../core/constants/app_colors.dart';
import 'kubo_pressable.dart';

export '../../core/utils/media_files.dart';

/// Stands in for a video's picture: dark, with a play button. A tap opens
/// [KuboVideoPlayerPage]. [source] is a URL or a local file path.
class KuboVideoTile extends StatelessWidget {
  const KuboVideoTile({super.key, required this.source, required this.width, required this.height, this.onTap});

  final String source;
  final double width;
  final double height;

  /// Defaults to opening the player.
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Video',
      onTapHint: 'play',
      excludeSemantics: true,
      child: KuboPressable(
        onTap: onTap ?? () => KuboVideoPlayerPage.open(context, source),
        child: Container(
          width: width,
          height: height,
          decoration: BoxDecoration(color: const Color(0xFF1E2220), borderRadius: BorderRadius.circular(8)),
          alignment: Alignment.center,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.18), shape: BoxShape.circle),
                child: Icon(Icons.play_arrow_rounded, color: Colors.white, size: width < 100 ? 22 : 34),
              ),
              if (height >= 100) ...[
                const SizedBox(height: 6),
                const Text('Video', style: TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.w600)),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Full-screen player: tap to play or pause, a scrubber along the bottom,
/// close at the top left.
class KuboVideoPlayerPage extends StatefulWidget {
  const KuboVideoPlayerPage({super.key, required this.source});

  final String source;

  static Future<void> open(BuildContext context, String source) {
    return Navigator.of(context, rootNavigator: true).push(
      MaterialPageRoute<void>(fullscreenDialog: true, builder: (_) => KuboVideoPlayerPage(source: source)),
    );
  }

  @override
  State<KuboVideoPlayerPage> createState() => _KuboVideoPlayerPageState();
}

class _KuboVideoPlayerPageState extends State<KuboVideoPlayerPage> {
  late final VideoPlayerController _controller;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    final source = widget.source;
    _controller = source.startsWith('http://') || source.startsWith('https://')
        ? VideoPlayerController.networkUrl(Uri.parse(source))
        : VideoPlayerController.file(File(source));
    _controller.addListener(_onTick);
    _controller.initialize().then((_) {
      if (!mounted) return;
      setState(() {});
      _controller.play();
    }).catchError((Object _) {
      if (mounted) setState(() => _failed = true);
    });
  }

  void _onTick() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _controller.removeListener(_onTick);
    _controller.dispose();
    super.dispose();
  }

  void _togglePlay() {
    if (!_controller.value.isInitialized) return;
    _controller.value.isPlaying ? _controller.pause() : _controller.play();
  }

  @override
  Widget build(BuildContext context) {
    final value = _controller.value;
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Stack(
          children: [
            Positioned.fill(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: _togglePlay,
                child: Center(
                  child: _failed
                      ? const Text('This video could not be played.', style: TextStyle(color: Colors.white70))
                      : !value.isInitialized
                          ? const CircularProgressIndicator(color: Colors.white)
                          : AspectRatio(aspectRatio: value.aspectRatio, child: VideoPlayer(_controller)),
                ),
              ),
            ),
            if (value.isInitialized && !value.isPlaying)
              const IgnorePointer(
                child: Center(child: Icon(Icons.play_circle_fill_rounded, color: Colors.white70, size: 72)),
              ),
            Positioned(
              top: 4,
              left: 4,
              child: IconButton(
                tooltip: 'Close',
                icon: const Icon(Icons.close, color: Colors.white),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ),
            if (value.isInitialized)
              Positioned(
                left: 16,
                right: 16,
                bottom: 16,
                child: VideoProgressIndicator(
                  _controller,
                  allowScrubbing: true,
                  colors: const VideoProgressColors(playedColor: AppColors.green, bufferedColor: Colors.white38),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
