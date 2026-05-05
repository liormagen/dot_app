import 'dart:async';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../models/drawing_model.dart';

// ---------------------------------------------------------------------------
// Flood fill isolate (top-level for compute())
// ---------------------------------------------------------------------------
Uint8List _floodFillIsolate(Map<String, dynamic> args) {
  final pixels = args['pixels'] as Uint8List;
  final width = args['width'] as int;
  final height = args['height'] as int;
  final startX = args['x'] as int;
  final startY = args['y'] as int;
  final fillR = args['r'] as int;
  final fillG = args['g'] as int;
  final fillB = args['b'] as int;

  final result = Uint8List.fromList(pixels);

  int idx(int x, int y) => (y * width + x) * 4;

  final si = idx(startX, startY);
  final targetR = result[si];
  final targetG = result[si + 1];
  final targetB = result[si + 2];

  // Don't fill if already that color
  if (targetR == fillR && targetG == fillG && targetB == fillB) return result;

  // Don't fill dark pixels (outline)
  if (targetR + targetG + targetB < 150) return result;

  final queue = <int>[];
  void enqueue(int x, int y) {
    if (x < 0 || x >= width || y < 0 || y >= height) return;
    final i = idx(x, y);
    final r = result[i];
    final g = result[i + 1];
    final b = result[i + 2];
    // Skip dark pixels (outlines) and already filled
    if (r + g + b < 150) return;
    if (r == fillR && g == fillG && b == fillB) return;
    // Only fill pixels similar to target
    if ((r - targetR).abs() > 60 ||
        (g - targetG).abs() > 60 ||
        (b - targetB).abs() > 60) return;
    result[i] = fillR;
    result[i + 1] = fillG;
    result[i + 2] = fillB;
    result[i + 3] = 255;
    queue.add(x | (y << 16));
  }

  enqueue(startX, startY);

  while (queue.isNotEmpty) {
    final val = queue.removeLast();
    final x = val & 0xFFFF;
    final y = val >> 16;
    enqueue(x + 1, y);
    enqueue(x - 1, y);
    enqueue(x, y + 1);
    enqueue(x, y - 1);
  }

  return result;
}

// ---------------------------------------------------------------------------
// Widget
// ---------------------------------------------------------------------------
class ColorFillCanvas extends StatefulWidget {
  const ColorFillCanvas({
    super.key,
    required this.drawing,
    required this.onDone,
  });

  final DrawingModel drawing;
  final VoidCallback onDone;

  @override
  State<ColorFillCanvas> createState() => _ColorFillCanvasState();
}

class _ColorFillCanvasState extends State<ColorFillCanvas> {
  ui.Image? _image;
  bool _loading = true;
  bool _processing = false;
  int _selectedColorIndex = 0;

  static const _palette = [
    Color(0xFFE74C3C), // red
    Color(0xFFE67E22), // orange
    Color(0xFFF1C40F), // yellow
    Color(0xFF2ECC71), // green
    Color(0xFF3498DB), // blue
    Color(0xFF9B59B6), // purple
    Color(0xFFE91E63), // pink
    Color(0xFF795548), // brown
  ];

  @override
  void initState() {
    super.initState();
    _loadImage();
  }

  Future<void> _loadImage() async {
    try {
      final data =
          await rootBundle.load(widget.drawing.imageOutline);
      final bytes = data.buffer.asUint8List();
      final completer = Completer<ui.Image>();
      ui.decodeImageFromList(bytes, (img) => completer.complete(img));
      final image = await completer.future;
      if (mounted) {
        setState(() {
          _image = image;
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _onTapCanvas(Offset tapOffset, Size widgetSize) async {
    if (_processing || _image == null) return;

    final img = _image!;
    final scaleX = img.width / widgetSize.width;
    final scaleY = img.height / widgetSize.height;

    final x = (tapOffset.dx * scaleX).round().clamp(0, img.width - 1);
    final y = (tapOffset.dy * scaleY).round().clamp(0, img.height - 1);

    final color = _palette[_selectedColorIndex];

    setState(() => _processing = true);

    try {
      final byteData =
          await img.toByteData(format: ui.ImageByteFormat.rawRgba);
      if (byteData == null) return;

      final resultPixels = await compute(_floodFillIsolate, {
        'pixels': byteData.buffer.asUint8List(),
        'width': img.width,
        'height': img.height,
        'x': x,
        'y': y,
        'r': color.red,
        'g': color.green,
        'b': color.blue,
      });

      final newImageCompleter = Completer<ui.Image>();
      ui.decodeImageFromPixels(
        resultPixels,
        img.width,
        img.height,
        ui.PixelFormat.rgba8888,
        (newImg) => newImageCompleter.complete(newImg),
      );
      final newImage = await newImageCompleter.future;

      if (mounted) {
        setState(() {
          _image = newImage;
          _processing = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _processing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    return Column(
      children: [
        // Canvas
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final size =
                  Size(constraints.maxWidth, constraints.maxHeight);
              return GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTapDown: (details) =>
                    _onTapCanvas(details.localPosition, size),
                child: Stack(
                  children: [
                    if (_image != null)
                      CustomPaint(
                        size: size,
                        painter: _ImagePainter(image: _image!),
                      ),
                    if (_processing)
                      const Center(child: CircularProgressIndicator()),
                  ],
                ),
              );
            },
          ),
        ),
        // Color palette
        Container(
          color: Colors.white,
          padding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              // Colors
              Expanded(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: List.generate(_palette.length, (i) {
                      final selected = i == _selectedColorIndex;
                      return GestureDetector(
                        onTap: () =>
                            setState(() => _selectedColorIndex = i),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 150),
                          margin:
                              const EdgeInsets.symmetric(horizontal: 6),
                          width: selected ? 48 : 36,
                          height: selected ? 48 : 36,
                          decoration: BoxDecoration(
                            color: _palette[i],
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: selected
                                  ? Colors.white
                                  : Colors.transparent,
                              width: 3,
                            ),
                            boxShadow: selected
                                ? [
                                    BoxShadow(
                                      color:
                                          _palette[i].withOpacity(0.6),
                                      blurRadius: 8,
                                      spreadRadius: 2,
                                    )
                                  ]
                                : null,
                          ),
                        ),
                      );
                    }),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              // Done button
              ElevatedButton.icon(
                onPressed: widget.onDone,
                icon: const Icon(Icons.check),
                label: const Text('Done'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF6B4EFF),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                      horizontal: 20, vertical: 12),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ImagePainter extends CustomPainter {
  const _ImagePainter({required this.image});

  final ui.Image image;

  @override
  void paint(Canvas canvas, Size size) {
    final src = Rect.fromLTWH(
        0, 0, image.width.toDouble(), image.height.toDouble());
    final dst = Rect.fromLTWH(0, 0, size.width, size.height);
    canvas.drawImageRect(image, src, dst, Paint());
  }

  @override
  bool shouldRepaint(_ImagePainter old) => old.image != image;
}
