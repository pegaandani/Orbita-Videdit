import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/material.dart';
import '../../../core/models/orbita_project.dart';

Widget applyOrbitaPreviewEffects(
  TimelineClip clip,
  Widget child,
  int playheadMs,
) {
  bool has(String type) => clip.effects.any((e) => e['type'] == type);
  Map<String, dynamic>? effect(String type) {
    for (final e in clip.effects) {
      if (e['type'] == type) return e;
    }
    return null;
  }

  double value(String type, String key, double fallback) =>
      (effect(type)?[key] as num?)?.toDouble() ?? fallback;

  if (has('mirror')) child = Transform.flip(flipX: true, child: child);
  if (has('flipVertical')) child = Transform.flip(flipY: true, child: child);
  if (has('rotate90')) child = RotatedBox(quarterTurns: 1, child: child);

  if (has('negative')) {
    child = ColorFiltered(
      colorFilter: const ColorFilter.matrix([
        -1, 0, 0, 0, 255,
        0, -1, 0, 0, 255,
        0, 0, -1, 0, 255,
        0, 0, 0, 1, 0,
      ]),
      child: child,
    );
  }

  if (has('edgeDetect')) {
    child = ColorFiltered(
      colorFilter: const ColorFilter.matrix([
        1.8, -0.6, -0.6, 0, 0,
        -0.6, 1.8, -0.6, 0, 0,
        -0.6, -0.6, 1.8, 0, 0,
        0, 0, 0, 1, 0,
      ]),
      child: child,
    );
  }

  if (has('chroma')) {
    child = ColorFiltered(
      colorFilter: const ColorFilter.matrix([
        1.05, 0, 0, 0, 0,
        0, 0.62, 0, 0, 0,
        0, 0, 1.05, 0, 0,
        0, 0, 0, 1, 0,
      ]),
      child: child,
    );
  }

  if (has('blur')) {
    final amount = value('blur', 'amount', 2).clamp(0.0, 12.0);
    child = ImageFiltered(
      imageFilter: ImageFilter.blur(sigmaX: amount, sigmaY: amount),
      child: child,
    );
  }

  if (has('sharpen')) {
    final amount = value('sharpen', 'amount', 1).clamp(0.0, 3.0);
    final contrast = 1 + amount * .08;
    final offset = (1 - contrast) * 128;
    child = ColorFiltered(
      colorFilter: ColorFilter.matrix([
        contrast, 0, 0, 0, offset,
        0, contrast, 0, 0, offset,
        0, 0, contrast, 0, offset,
        0, 0, 0, 1, 0,
      ]),
      child: child,
    );
  }

  if (has('cameraShake')) {
    final amount = value('cameraShake', 'amount', 1).clamp(0.0, 3.0);
    final t = playheadMs / 1000.0;
    child = Transform.translate(
      offset: Offset(
        math.sin(t * 24) * 2.8 * amount,
        math.cos(t * 19) * 2.2 * amount,
      ),
      child: child,
    );
  }

  if (has('distortion')) {
    final amount = value('distortion', 'amount', .18).clamp(0.0, .6);
    child = Transform(
      alignment: Alignment.center,
      transform: Matrix4.identity()
        ..setEntry(3, 2, .0015 * amount)
        ..rotateZ(math.sin(playheadMs / 850.0) * amount * .025)
        ..scale(1 + amount * .04, 1 - amount * .02),
      child: child,
    );
  }

  if (has('drunk')) {
    final t = playheadMs / 1000.0;
    child = Stack(
      fit: StackFit.passthrough,
      children: [
        child,
        Transform.translate(
          offset: Offset(math.sin(t * 4) * 5, math.cos(t * 3.3) * 3),
          child: Opacity(opacity: .22, child: child),
        ),
      ],
    );
  }

  if (has('bokeh')) {
    final amount = value('bokeh', 'amount', 2.5).clamp(0.0, 8.0);
    child = Stack(
      fit: StackFit.passthrough,
      children: [
        ImageFiltered(
          imageFilter: ImageFilter.blur(
            sigmaX: amount * .35,
            sigmaY: amount * .35,
          ),
          child: child,
        ),
        const Positioned.fill(
          child: IgnorePointer(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: Alignment(-.3, -.35),
                  radius: 1.15,
                  colors: [Color(0x18FFFFFF), Color(0x00000000)],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  if (has('glitch')) {
    final t = playheadMs / 1000.0;
    final jump = math.sin(t * 31) * 5;
    child = Stack(
      fit: StackFit.passthrough,
      children: [
        child,
        Transform.translate(
          offset: Offset(jump, 0),
          child: Opacity(
            opacity: .18,
            child: ColorFiltered(
              colorFilter: const ColorFilter.matrix([
                1.25, 0, 0, 0, 18,
                0, .72, 0, 0, 0,
                0, 0, .72, 0, 0,
                0, 0, 0, 1, 0,
              ]),
              child: child,
            ),
          ),
        ),
      ],
    );
  }

  if (has('vignette')) {
    final strength = value('vignette', 'strength', 5).clamp(0.0, 10.0);
    child = Stack(
      fit: StackFit.passthrough,
      children: [
        child,
        Positioned.fill(
          child: IgnorePointer(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  radius: .92,
                  colors: [
                    Colors.transparent,
                    Colors.black.withValues(alpha: .12 + strength * .045),
                  ],
                  stops: const [.52, 1],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  if (has('grain')) {
    final amount = value('grain', 'amount', 8).clamp(0.0, 20.0);
    child = CustomPaint(
      foregroundPainter: _PreviewGrainPainter(
        amount: amount,
        seed: playheadMs ~/ 90,
      ),
      child: child,
    );
  }

  final localMs = (playheadMs - clip.startMs).clamp(0, clip.durationMs);
  for (final transition in clip.effects.where((e) => e['type'] == 'transition')) {
    final duration = ((transition['duration'] as num?)?.toDouble() ?? .45)
        .clamp(.15, 2.0);
    final p = (localMs / (duration * 1000)).clamp(0.0, 1.0).toDouble();
    final id = transition['id'] as String?;
    switch (id) {
      case 'fadeBlack':
        child = Stack(fit: StackFit.passthrough, children: [
          const Positioned.fill(child: ColoredBox(color: Colors.black)),
          Opacity(opacity: p, child: child),
        ]);
        break;
      case 'fadeWhite':
        child = Stack(fit: StackFit.passthrough, children: [
          const Positioned.fill(child: ColoredBox(color: Colors.white)),
          Opacity(opacity: p, child: child),
        ]);
        break;
      case 'blurIn':
        child = ImageFiltered(
          imageFilter: ImageFilter.blur(
            sigmaX: (1 - p) * 11,
            sigmaY: (1 - p) * 11,
          ),
          child: child,
        );
        break;
      case 'zoomIn':
        child = Transform.scale(scale: .72 + .28 * p, child: child);
        break;
      case 'slideLeft':
        child = Transform.translate(offset: Offset((1 - p) * 150, 0), child: child);
        break;
      case 'slideRight':
        child = Transform.translate(offset: Offset(-(1 - p) * 150, 0), child: child);
        break;
      case 'wipeUp':
        child = ClipRect(
          child: Align(alignment: Alignment.bottomCenter, heightFactor: p, child: child),
        );
        break;
      case 'wipeDown':
        child = ClipRect(
          child: Align(alignment: Alignment.topCenter, heightFactor: p, child: child),
        );
        break;
      case 'flash':
        child = Stack(fit: StackFit.passthrough, children: [
          child,
          Positioned.fill(
            child: IgnorePointer(
              child: ColoredBox(
                color: Colors.white.withValues(alpha: math.max(0, 1 - p * 2)),
              ),
            ),
          ),
        ]);
        break;
      case 'pixelate':
        child = ImageFiltered(
          imageFilter: ImageFilter.blur(
            sigmaX: (1 - p) * 4,
            sigmaY: (1 - p) * 4,
          ),
          child: Transform.scale(scale: .985 + .015 * p, child: child),
        );
        break;
    }
  }

  return child;
}

class _PreviewGrainPainter extends CustomPainter {
  const _PreviewGrainPainter({required this.amount, required this.seed});

  final double amount;
  final int seed;

  @override
  void paint(Canvas canvas, Size size) {
    if (amount <= .01 || size.isEmpty) return;
    final random = math.Random(seed);
    final count = (40 + amount * 18).round().clamp(40, 400);
    final alpha = (10 + amount * 4).round().clamp(8, 75);
    final paint = Paint()..strokeWidth = 1;
    for (var i = 0; i < count; i++) {
      paint.color = (random.nextBool() ? Colors.white : Colors.black)
          .withAlpha(alpha);
      canvas.drawPoint(
        Offset(random.nextDouble() * size.width, random.nextDouble() * size.height),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _PreviewGrainPainter oldDelegate) =>
      oldDelegate.seed != seed || oldDelegate.amount != amount;
}
