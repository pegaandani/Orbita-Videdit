import 'dart:io';

void main(List<String> args) {
  if (args.isEmpty) exit(2);
  final sep = Platform.pathSeparator;
  final file = File('${args.first}${sep}lib${sep}features${sep}editor${sep}editor_screen.dart');
  var source = file.readAsStringSync().replaceAll('\r\n', '\n');
  final start = source.indexOf('  Widget _applyPreviewEffects(TimelineClip c, Widget child) {');
  final end = source.indexOf('  Widget _previewTextWidget(TimelineClip c) {', start);
  if (start < 0 || end < 0) {
    stderr.writeln('Preview effects block not found');
    exit(3);
  }

  const replacement = r'''  Map<String, dynamic>? _effect(TimelineClip c, String type) {
    for (final e in c.effects) {
      if (e['type'] == type) return e;
    }
    return null;
  }

  double _transitionPreviewProgress(TimelineClip c, Map<String, dynamic> effect) {
    final durationMs = (((effect['duration'] as num?)?.toDouble() ?? .45) * 1000).round().clamp(150, 2000);
    return ((playheadMs - c.startMs) / durationMs).clamp(0.0, 1.0).toDouble();
  }

  Widget _applyPreviewEffects(TimelineClip c, Widget child) {
    if (_effect(c, 'mirror') != null) child = Transform.flip(flipX: true, child: child);
    if (_effect(c, 'flipVertical') != null) child = Transform.flip(flipY: true, child: child);
    if (_effect(c, 'rotate90') != null) child = RotatedBox(quarterTurns: 1, child: child);

    final negative = _effect(c, 'negative');
    if (negative != null) {
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

    final blur = _effect(c, 'blur');
    if (blur != null) {
      final amount = ((blur['amount'] as num?)?.toDouble() ?? 2).clamp(0.0, 12.0).toDouble();
      child = ImageFiltered(imageFilter: ImageFilter.blur(sigmaX: amount, sigmaY: amount), child: child);
    }
    final bokeh = _effect(c, 'bokeh');
    if (bokeh != null) {
      final amount = ((bokeh['amount'] as num?)?.toDouble() ?? 2.5).clamp(.5, 6.0).toDouble();
      child = ImageFiltered(imageFilter: ImageFilter.blur(sigmaX: amount * .7, sigmaY: amount * .7), child: child);
    }
    final sharpen = _effect(c, 'sharpen');
    if (sharpen != null) {
      final amount = ((sharpen['amount'] as num?)?.toDouble() ?? 1).clamp(0.0, 3.0).toDouble();
      final contrast = 1 + amount * .12;
      final bias = (1 - contrast) * 128;
      child = ColorFiltered(colorFilter: ColorFilter.matrix([
        contrast, 0, 0, 0, bias,
        0, contrast, 0, 0, bias,
        0, 0, contrast, 0, bias,
        0, 0, 0, 1, 0,
      ]), child: child);
    }
    if (_effect(c, 'edgeDetect') != null) {
      child = ColorFiltered(colorFilter: const ColorFilter.matrix([
        1.55, 0, 0, 0, -70,
        0, 1.55, 0, 0, -70,
        0, 0, 1.55, 0, -70,
        0, 0, 0, 1, 0,
      ]), child: child);
    }

    final shake = _effect(c, 'cameraShake');
    if (shake != null) {
      final amount = ((shake['amount'] as num?)?.toDouble() ?? 1).clamp(.2, 3.0).toDouble();
      final t = playheadMs / 1000.0;
      child = Transform.translate(
        offset: Offset(math.sin(t * 18) * 4 * amount, math.cos(t * 15) * 3 * amount),
        child: Transform.rotate(angle: math.sin(t * 18) * .010 * amount, child: child),
      );
    }
    final distortion = _effect(c, 'distortion');
    if (distortion != null) {
      final amount = ((distortion['amount'] as num?)?.toDouble() ?? .18).clamp(.02, .45).toDouble();
      child = Transform.scale(scale: 1 + amount * .08, child: child);
    }
    if (_effect(c, 'drunk') != null) {
      child = Stack(fit: StackFit.passthrough, children: [
        Opacity(opacity: .32, child: Transform.translate(offset: const Offset(4, 1), child: child)),
        Opacity(opacity: .32, child: Transform.translate(offset: const Offset(-4, -1), child: child)),
        child,
      ]);
    }
    if (_effect(c, 'glitch') != null) {
      final phase = ((playheadMs ~/ 55) % 5) - 2;
      child = Stack(fit: StackFit.passthrough, children: [
        Opacity(opacity: .22, child: Transform.translate(offset: Offset(phase * 2.0, 0), child: child)),
        child,
      ]);
    }

    child = ColorFiltered(colorFilter: ColorFilter.matrix(_previewColorMatrix(c)), child: child);

    final vignette = _effect(c, 'vignette');
    final grain = _effect(c, 'grain');
    if (vignette != null || grain != null) {
      final children = <Widget>[Positioned.fill(child: child)];
      if (vignette != null) {
        children.add(Positioned.fill(child: IgnorePointer(child: DecoratedBox(
          decoration: BoxDecoration(
            gradient: RadialGradient(
              radius: .78,
              colors: [Colors.transparent, Colors.black.withValues(alpha: .46)],
              stops: const [.55, 1],
            ),
          ),
        ))));
      }
      if (grain != null) {
        final amount = ((grain['amount'] as num?)?.toDouble() ?? 8).clamp(0.0, 30.0).toDouble();
        final alpha = (amount / 30 * .13).clamp(0.0, .13).toDouble();
        final flicker = ((playheadMs ~/ 42) % 2 == 0) ? alpha : alpha * .55;
        children.add(Positioned.fill(child: IgnorePointer(child: ColoredBox(color: Colors.white.withValues(alpha: flicker)))));
      }
      child = Stack(fit: StackFit.passthrough, children: children);
    }

    for (final transition in c.effects.where((e) => e['type'] == 'transition')) {
      final id = transition['id'] as String? ?? 'fadeBlack';
      final p = _transitionPreviewProgress(c, transition);
      switch (id) {
        case 'fadeBlack':
          child = Opacity(opacity: p, child: child);
          break;
        case 'fadeWhite':
          child = Stack(fit: StackFit.passthrough, children: [
            child,
            Positioned.fill(child: IgnorePointer(child: ColoredBox(color: Colors.white.withValues(alpha: 1 - p)))),
          ]);
          break;
        case 'blurIn':
          child = ImageFiltered(imageFilter: ImageFilter.blur(sigmaX: 4.5 * (1 - p), sigmaY: 4.5 * (1 - p)), child: child);
          break;
        case 'zoomIn':
          child = Transform.scale(scale: .72 + .28 * p, child: child);
          break;
        case 'slideLeft':
          child = Transform.translate(offset: Offset((1 - p) * 180, 0), child: child);
          break;
        case 'slideRight':
          child = Transform.translate(offset: Offset(-(1 - p) * 180, 0), child: child);
          break;
        case 'wipeUp':
          child = Transform.translate(offset: Offset(0, (1 - p) * 180), child: child);
          break;
        case 'wipeDown':
          child = Transform.translate(offset: Offset(0, -(1 - p) * 180), child: child);
          break;
        case 'flash':
          child = Stack(fit: StackFit.passthrough, children: [
            child,
            Positioned.fill(child: IgnorePointer(child: ColoredBox(color: Colors.white.withValues(alpha: .5 * (1 - p))))),
          ]);
          break;
        case 'pixelate':
          final scale = .18 + .82 * p;
          child = Transform.scale(scale: scale, child: ImageFiltered(imageFilter: ImageFilter.blur(sigmaX: 2.4 * (1 - p), sigmaY: 2.4 * (1 - p)), child: child));
          break;
      }
    }
    return child;
  }

''';

  source = source.substring(0, start) + replacement + source.substring(end);
  file.writeAsStringSync(source);
  stdout.writeln('Preview effects/transitions patched.');
}
