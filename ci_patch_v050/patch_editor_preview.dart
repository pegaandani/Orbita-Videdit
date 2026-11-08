import 'dart:io';

void main(List<String> args) {
  if (args.isEmpty) {
    stderr.writeln('Usage: dart patch_editor_preview.dart <videdit_project>');
    exit(2);
  }

  final file = File('${args.first}${Platform.pathSeparator}lib${Platform.pathSeparator}features${Platform.pathSeparator}editor${Platform.pathSeparator}editor_screen.dart');
  var source = file.readAsStringSync().replaceAll('\r\n', '\n');

  final start = source.indexOf('  Widget _applyPreviewEffects(TimelineClip c, Widget child) {');
  final end = source.indexOf('\n  Widget _previewTextWidget', start);
  if (start < 0 || end < 0) {
    stderr.writeln('Preview effects block was not found.');
    exit(3);
  }

  const replacement = r'''  Widget _applyPreviewEffects(TimelineClip c, Widget child) {
    var blurSigma = 0.0;
    var translateX = 0.0;
    var translateY = 0.0;
    var scale = 1.0;
    var rotation = 0.0;
    var transitionOpacity = 1.0;
    var flashAmount = 0.0;
    var vignetteStrength = 0.0;
    var grainAmount = 0.0;
    var edgePreview = false;
    var chromaPreview = false;
    var sharpenAmount = 0.0;
    var glitchAmount = 0.0;

    for (final effect in c.effects) {
      final type = effect['type'];
      if (type == 'mirror') {
        child = Transform.flip(flipX: true, child: child);
      } else if (type == 'flipVertical') {
        child = Transform.flip(flipY: true, child: child);
      } else if (type == 'rotate90') {
        child = RotatedBox(quarterTurns: 1, child: child);
      } else if (type == 'negative') {
        child = ColorFiltered(
          colorFilter: const ColorFilter.matrix([
            -1, 0, 0, 0, 255,
            0, -1, 0, 0, 255,
            0, 0, -1, 0, 255,
            0, 0, 0, 1, 0,
          ]),
          child: child,
        );
      } else if (type == 'blur') {
        blurSigma += ((effect['amount'] as num?)?.toDouble() ?? 2.0).clamp(0.0, 8.0);
      } else if (type == 'bokeh') {
        blurSigma += (((effect['amount'] as num?)?.toDouble() ?? 2.5) * .65).clamp(0.0, 6.0);
      } else if (type == 'vignette') {
        vignetteStrength = math.max(vignetteStrength, ((effect['strength'] as num?)?.toDouble() ?? 5.0).clamp(2.0, 12.0));
      } else if (type == 'grain') {
        grainAmount = math.max(grainAmount, ((effect['amount'] as num?)?.toDouble() ?? 8.0).clamp(0.0, 30.0));
      } else if (type == 'sharpen') {
        sharpenAmount = math.max(sharpenAmount, ((effect['amount'] as num?)?.toDouble() ?? 1.0).clamp(0.0, 2.0));
      } else if (type == 'edgeDetect') {
        edgePreview = true;
      } else if (type == 'chroma') {
        chromaPreview = true;
      } else if (type == 'cameraShake') {
        final amount = ((effect['amount'] as num?)?.toDouble() ?? 1.0).clamp(.2, 3.0);
        translateX += math.sin(playheadMs / 42.0) * 3.2 * amount;
        translateY += math.cos(playheadMs / 55.0) * 2.4 * amount;
        rotation += math.sin(playheadMs / 95.0) * .006 * amount;
      } else if (type == 'distortion') {
        final amount = ((effect['amount'] as num?)?.toDouble() ?? .18).clamp(.02, .45);
        scale *= 1.0 + amount * .12;
      } else if (type == 'drunk') {
        translateX += math.sin(playheadMs / 135.0) * 4.5;
        translateY += math.cos(playheadMs / 160.0) * 3.5;
        rotation += math.sin(playheadMs / 240.0) * .018;
        blurSigma += .7;
      } else if (type == 'glitch') {
        final amount = ((effect['amount'] as num?)?.toDouble() ?? 1.0).clamp(.2, 3.0);
        glitchAmount = math.max(glitchAmount, amount);
        translateX += math.sin(playheadMs / 18.0) * 3.0 * amount;
      } else if (type == 'transition') {
        final durationMs = ((((effect['duration'] as num?)?.toDouble() ?? .45) * 1000).round()).clamp(150, 2000);
        final localMs = (playheadMs - c.startMs).clamp(0, durationMs);
        final p = (localMs / durationMs).clamp(0.0, 1.0).toDouble();
        switch (effect['id']) {
          case 'fadeBlack':
          case 'fadeWhite':
            transitionOpacity *= p;
            break;
          case 'blurIn':
            blurSigma += 4.5 * (1 - p);
            break;
          case 'zoomIn':
            scale *= .72 + .28 * p;
            break;
          case 'slideLeft':
            translateX += -(1 - p) * 90;
            break;
          case 'slideRight':
            translateX += (1 - p) * 90;
            break;
          case 'wipeUp':
            translateY += -(1 - p) * 90;
            break;
          case 'wipeDown':
            translateY += (1 - p) * 90;
            break;
          case 'flash':
            flashAmount = math.max(flashAmount, .7 * (1 - p));
            break;
          case 'pixelate':
            blurSigma += 2.2 * (1 - p);
            scale *= .985 + .015 * p;
            break;
        }
      }
    }

    if (sharpenAmount > .01) {
      final c = 1.0 + sharpenAmount * .12;
      final o = (1 - c) * 128;
      child = ColorFiltered(
        colorFilter: ColorFilter.matrix([
          c, 0, 0, 0, o,
          0, c, 0, 0, o,
          0, 0, c, 0, o,
          0, 0, 0, 1, 0,
        ]),
        child: child,
      );
    }
    if (edgePreview) {
      child = ColorFiltered(
        colorFilter: const ColorFilter.matrix([
          1.8, -1.2, -.6, 0, 12,
          -.6, 1.8, -1.2, 0, 12,
          -1.2, -.6, 1.8, 0, 12,
          0, 0, 0, 1, 0,
        ]),
        child: child,
      );
    }
    if (chromaPreview) {
      child = ColorFiltered(
        colorFilter: const ColorFilter.matrix([
          1, 0, 0, 0, 0,
          0, .28, 0, 0, 0,
          0, 0, 1, 0, 0,
          0, -.55, 0, 1, 90,
        ]),
        child: child,
      );
    }
    if (glitchAmount > .01) {
      child = ColorFiltered(
        colorFilter: ColorFilter.matrix([
          1 + .08 * glitchAmount, 0, 0, 0, 8 * glitchAmount,
          0, 1, 0, 0, 0,
          0, 0, 1 + .06 * glitchAmount, 0, -6 * glitchAmount,
          0, 0, 0, 1, 0,
        ]),
        child: child,
      );
    }
    if (blurSigma > .01) {
      child = ImageFiltered(
        imageFilter: ImageFilter.blur(sigmaX: blurSigma, sigmaY: blurSigma),
        child: child,
      );
    }

    if (scale != 1 || rotation != 0 || translateX != 0 || translateY != 0) {
      child = Transform.translate(
        offset: Offset(translateX, translateY),
        child: Transform.rotate(
          angle: rotation,
          child: Transform.scale(scale: scale, child: child),
        ),
      );
    }

    child = ColorFiltered(colorFilter: ColorFilter.matrix(_previewColorMatrix(c)), child: child);
    child = Opacity(opacity: transitionOpacity.clamp(0.0, 1.0).toDouble(), child: child);

    if (vignetteStrength > .01 || grainAmount > .01 || flashAmount > .01) {
      child = Stack(
        fit: StackFit.expand,
        children: [
          child,
          if (vignetteStrength > .01)
            IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    colors: [Colors.transparent, Colors.black.withValues(alpha: (.16 + vignetteStrength * .035).clamp(.18, .62))],
                    stops: const [.48, 1],
                  ),
                ),
              ),
            ),
          if (grainAmount > .01)
            IgnorePointer(
              child: CustomPaint(
                painter: _PreviewNoisePainter(
                  strength: (grainAmount / 30).clamp(0.0, 1.0).toDouble(),
                  phase: (playheadMs ~/ 67) % 997,
                ),
              ),
            ),
          if (flashAmount > .01)
            IgnorePointer(child: ColoredBox(color: Colors.white.withValues(alpha: flashAmount.clamp(0.0, .8).toDouble()))),
        ],
      );
    }
    return child;
  }
''';

  source = source.substring(0, start) + replacement + source.substring(end);

  if (!source.contains('class _PreviewNoisePainter extends CustomPainter')) {
    const marker = 'class _FrameGuidePainter extends CustomPainter {';
    final markerIndex = source.indexOf(marker);
    if (markerIndex < 0) {
      stderr.writeln('Painter insertion point was not found.');
      exit(4);
    }
    const painter = r'''class _PreviewNoisePainter extends CustomPainter {
  const _PreviewNoisePainter({required this.strength, required this.phase});
  final double strength;
  final int phase;

  @override
  void paint(Canvas canvas, Size size) {
    if (strength <= 0 || size.isEmpty) return;
    final random = math.Random(1337 + phase);
    final paint = Paint()..strokeWidth = 1;
    final dots = (120 + 420 * strength).round();
    for (var i = 0; i < dots; i++) {
      final white = random.nextBool();
      paint.color = (white ? Colors.white : Colors.black).withValues(alpha: (.025 + .11 * strength) * random.nextDouble());
      canvas.drawPoint(Offset(random.nextDouble() * size.width, random.nextDouble() * size.height), paint);
    }
  }

  @override
  bool shouldRepaint(covariant _PreviewNoisePainter oldDelegate) =>
      oldDelegate.strength != strength || oldDelegate.phase != phase;
}

''';
    source = source.substring(0, markerIndex) + painter + source.substring(markerIndex);
  }

  file.writeAsStringSync(source);
  stdout.writeln('Editor preview patched for visible effects and transitions.');
}
