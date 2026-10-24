import 'dart:io';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;

class ProfilePhotoEditorPage extends StatefulWidget {
  const ProfilePhotoEditorPage({super.key, required this.source});

  final File source;

  @override
  State<ProfilePhotoEditorPage> createState() => _ProfilePhotoEditorPageState();
}

class _ProfilePhotoEditorPageState extends State<ProfilePhotoEditorPage> {
  int _quarterTurns = 0;
  double _scale = 1;
  double _startScale = 1;
  Offset _offset = Offset.zero;
  Offset _startOffset = Offset.zero;
  Offset _startFocalPoint = Offset.zero;
  int _sourceWidth = 1;
  int _sourceHeight = 1;
  double _viewportSize = 320;
  bool _processing = false;

  @override
  void initState() {
    super.initState();
    _loadSourceDimensions();
  }

  Future<void> _loadSourceDimensions() async {
    final decoded = img.decodeImage(await widget.source.readAsBytes());
    if (!mounted || decoded == null) return;
    setState(() {
      _sourceWidth = decoded.width;
      _sourceHeight = decoded.height;
      _offset = _clampOffset(_offset, _viewportSize);
    });
  }

  Size _rotatedSourceSize() {
    final turnsSideways = _quarterTurns.isOdd;
    return Size(
      (turnsSideways ? _sourceHeight : _sourceWidth).toDouble(),
      (turnsSideways ? _sourceWidth : _sourceHeight).toDouble(),
    );
  }

  Offset _clampOffset(Offset value, double viewportSize) {
    final sourceSize = _rotatedSourceSize();
    final guideSize = viewportSize * 0.86;
    final baseScale = max(viewportSize / sourceSize.width, viewportSize / sourceSize.height);
    final displayScale = baseScale * _scale;
    final maxX = max(0.0, (sourceSize.width * displayScale - guideSize) / 2);
    final maxY = max(0.0, (sourceSize.height * displayScale - guideSize) / 2);
    return Offset(
      value.dx.clamp(-maxX, maxX).toDouble(),
      value.dy.clamp(-maxY, maxY).toDouble(),
    );
  }

  Future<File?> _createAvatar(double viewportSize) async {
    final decoded = img.decodeImage(await widget.source.readAsBytes());
    if (decoded == null) return null;

    final rotated = img.copyRotate(decoded, angle: _quarterTurns * 90);
    final guideSize = viewportSize * 0.86;
    final baseScale = max(viewportSize / rotated.width, viewportSize / rotated.height);
    final displayScale = baseScale * _scale;
    final displayedWidth = rotated.width * displayScale;
    final displayedHeight = rotated.height * displayScale;
    final imageLeft = (viewportSize - displayedWidth) / 2 + _offset.dx;
    final imageTop = (viewportSize - displayedHeight) / 2 + _offset.dy;
    final guideLeft = (viewportSize - guideSize) / 2;
    final guideTop = (viewportSize - guideSize) / 2;
    final cropSize = guideSize / displayScale;
    final cropX = ((guideLeft - imageLeft) / displayScale).clamp(0.0, rotated.width - cropSize);
    final cropY = ((guideTop - imageTop) / displayScale).clamp(0.0, rotated.height - cropSize);
    final outputSize = cropSize.round().clamp(1, min(rotated.width, rotated.height)).toInt();
    final cropped = img.copyCrop(
      rotated,
      x: cropX.round(),
      y: cropY.round(),
      width: outputSize,
      height: outputSize,
    );
    final output = File('${Directory.systemTemp.path}/kubo-avatar-${DateTime.now().microsecondsSinceEpoch}.jpg');
    await output.writeAsBytes(img.encodeJpg(cropped, quality: 90), flush: true);
    return output;
  }

  Future<void> _confirm(double viewportSize) async {
    setState(() => _processing = true);
    try {
      final avatar = await _createAvatar(viewportSize);
      if (!mounted) return;
      if (avatar == null) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('This image could not be edited.')));
        return;
      }
      Navigator.of(context).pop(avatar);
    } catch (error) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Could not edit image: $error')));
    } finally {
      if (mounted) setState(() => _processing = false);
    }
  }

  void _onScaleStart(ScaleStartDetails details) {
    _startScale = _scale;
    _startOffset = _offset;
    _startFocalPoint = details.focalPoint;
  }

  void _onScaleUpdate(ScaleUpdateDetails details) {
    setState(() {
      _scale = (_startScale * details.scale).clamp(1.0, 5.0);
      final scaleRatio = _scale / _startScale;
      final center = Offset(_viewportSize / 2, _viewportSize / 2);
      final focalMovement = details.focalPoint - _startFocalPoint;
      final focalZoom = (_startFocalPoint - center) * (1 - scaleRatio);
      _offset = _clampOffset(_startOffset + focalMovement + focalZoom, _viewportSize);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: const Text('Adjust profile photo'),
        actions: [
          IconButton(
            tooltip: 'Use this photo',
            onPressed: _processing ? null : () => _confirm(_viewportSize),
            icon: _processing
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Icon(Icons.check),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final viewportSize = min(constraints.maxWidth, constraints.maxHeight);
                  _viewportSize = viewportSize;
                  _offset = _clampOffset(_offset, viewportSize);
                  return Center(
                    child: SizedBox.square(
                      dimension: viewportSize,
                      child: GestureDetector(
                        onScaleStart: _onScaleStart,
                        onScaleUpdate: _onScaleUpdate,
                        child: ClipRect(
                          child: Stack(
                            fit: StackFit.expand,
                            children: [
                              Transform.translate(
                                offset: _offset,
                                child: Transform.scale(
                                  scale: _scale,
                                  child: RotatedBox(
                                    quarterTurns: _quarterTurns,
                                    child: Image.file(widget.source, fit: BoxFit.cover),
                                  ),
                                ),
                              ),
                              const IgnorePointer(child: CustomPaint(painter: _CircleCropGuidePainter())),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  IconButton.filledTonal(
                    tooltip: 'Rotate left',
                    onPressed: _processing ? null : () => setState(() {
                      _quarterTurns = (_quarterTurns + 3) % 4;
                      _offset = Offset.zero;
                    }),
                    icon: const Icon(Icons.rotate_left),
                  ),
                  const SizedBox(width: 40),
                  IconButton.filledTonal(
                    tooltip: 'Rotate right',
                    onPressed: _processing ? null : () => setState(() {
                      _quarterTurns = (_quarterTurns + 1) % 4;
                      _offset = Offset.zero;
                    }),
                    icon: const Icon(Icons.rotate_right),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CircleCropGuidePainter extends CustomPainter {
  const _CircleCropGuidePainter();

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = size.shortestSide * 0.43;
    final outside = Paint()..color = Colors.black.withValues(alpha: 0.5);
    final border = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    canvas.saveLayer(Offset.zero & size, Paint());
    canvas.drawRect(Offset.zero & size, outside);
    final clear = Paint()..blendMode = BlendMode.clear;
    canvas.drawCircle(center, radius, clear);
    canvas.drawCircle(center, radius, border);
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}