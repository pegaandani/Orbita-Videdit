import 'dart:io';

String replaceSection(String source, String startMarker, String endMarker, String replacement, String label) {
  final start = source.indexOf(startMarker);
  if (start < 0) {
    stderr.writeln('Missing start marker for $label');
    exit(3);
  }
  final end = source.indexOf(endMarker, start);
  if (end < 0) {
    stderr.writeln('Missing end marker for $label');
    exit(4);
  }
  return source.substring(0, start) + replacement + source.substring(end);
}

void main(List<String> args) {
  if (args.isEmpty) {
    stderr.writeln('Usage: dart patch_text_model_preview.dart <videdit_project>');
    exit(2);
  }
  final root = args.first;
  final sep = Platform.pathSeparator;

  final timelineFile = File('$root${sep}lib${sep}core${sep}services${sep}timeline_edit_service.dart');
  var timelineSource = timelineFile.readAsStringSync().replaceAll('\r\n', '\n');
  timelineSource = replaceSection(
    timelineSource,
    '  TimelineClip appendText(',
    '  TimelineClip? split(',
    '''  TimelineClip appendText(\n    TimelineTrack track,\n    String text, {\n    required int startMs,\n    int durationMs = 5000,\n    String template = 'clean',\n    String fontFamily = 'Inter',\n    String entryAnimation = 'fadeIn',\n    String loopAnimation = 'none',\n    String exitAnimation = 'fadeOut',\n  }) {\n    final legalStart = nearestAvailableStart(track, startMs, durationMs);\n    final clip = TimelineClip(\n      id: '\${DateTime.now().microsecondsSinceEpoch}-text',\n      name: text,\n      sourcePath: '',\n      kind: 'text',\n      startMs: legalStart,\n      durationMs: durationMs,\n      text: text,\n      style: {\n        'template': template,\n        'fontFamily': fontFamily,\n        'entryAnimation': entryAnimation,\n        'loopAnimation': loopAnimation,\n        'exitAnimation': exitAnimation,\n        'fontSize': 48.0,\n        'color': '#FFFFFF',\n        'background': '#00000000',\n        'align': 'center',\n      },\n    );\n    track.clips.add(clip);\n    track.clips.sort((a, b) => a.startMs.compareTo(b.startMs));\n    return clip;\n  }\n\n''',
    'TimelineEditService.appendText',
  );
  timelineFile.writeAsStringSync(timelineSource);

  final editorFile = File('$root${sep}lib${sep}features${sep}editor${sep}editor_screen.dart');
  var editorSource = editorFile.readAsStringSync().replaceAll('\r\n', '\n');

  editorSource = replaceSection(
    editorSource,
    '  Future<void> _addText(',
    '  void _onPlayerPosition(',
    '''  Future<void> _addText(\n    String text,\n    String template,\n    String fontFamily,\n    String entryAnimation,\n    String loopAnimation,\n    String exitAnimation,\n  ) async {\n    final track = _defaultTrack;\n    if (track.locked) {\n      setState(() => status = '\${track.name} está bloqueada');\n      return;\n    }\n    _pushUndo();\n    final clip = timeline.appendText(\n      track,\n      text,\n      startMs: playheadMs,\n      durationMs: 5000,\n      template: template,\n      fontFamily: fontFamily,\n      entryAnimation: entryAnimation,\n      loopAnimation: loopAnimation,\n      exitAnimation: exitAnimation,\n    );\n    setState(() {\n      selectedTrackId = track.id;\n      selectedClipId = clip.id;\n    });\n    await _markChanged('Texto añadido al timeline');\n  }\n\n''',
    'EditorScreen._addText',
  );

  editorSource = replaceSection(
    editorSource,
    '  Widget _previewTextWidget(',
    '  Widget _quickFormatButton()',
    '''  Widget _previewTextWidget(TimelineClip c) {\n    final style = c.style;\n    final template = style['template'] ?? 'clean';\n    final legacy = (style['animation'] as String?) ?? 'static';\n    final entry = (style['entryAnimation'] as String?) ?? switch (legacy) {\n      'fade' => 'fadeIn',\n      'slideLeft' => 'slideLeftIn',\n      'slideRight' => 'slideRightIn',\n      'slideUp' => 'slideUpIn',\n      'slideDown' => 'slideDownIn',\n      'zoom' => 'zoomIn',\n      _ => 'none',\n    };\n    final loop = (style['loopAnimation'] as String?) ?? (legacy == 'pulse' ? 'pulse' : 'none');\n    final exit = (style['exitAnimation'] as String?) ?? (legacy == 'fade' ? 'fadeOut' : 'none');\n    final fontFamily = (style['fontFamily'] as String?) ?? 'Inter';\n    final progress = ((playheadMs - c.startMs) / math.max(1, c.durationMs)).clamp(0.0, 1.0).toDouble();\n    final localSeconds = math.max(0, playheadMs - c.startMs) / 1000.0;\n    final entryP = Curves.easeOutCubic.transform((progress / .18).clamp(0.0, 1.0).toDouble());\n    final exitP = Curves.easeInCubic.transform(((progress - .82) / .18).clamp(0.0, 1.0).toDouble());\n\n    var dx = 0.0;\n    var dy = 0.0;\n    var scaleX = 1.0;\n    var scaleY = 1.0;\n    var rotation = 0.0;\n    var opacity = 1.0;\n    var blur = 0.0;\n    var letterSpacing = 0.0;\n    var glowBlur = 4.0;\n    var textColor = Colors.white;\n    var displayText = c.text ?? '';\n\n    switch (entry) {\n      case 'fadeIn': opacity *= entryP; break;\n      case 'slideLeftIn': dx -= (1 - entryP) * 190; break;\n      case 'slideRightIn': dx += (1 - entryP) * 190; break;\n      case 'slideUpIn': dy += (1 - entryP) * 150; break;\n      case 'slideDownIn': dy -= (1 - entryP) * 150; break;\n      case 'zoomIn': scaleX *= .62 + .38 * entryP; scaleY *= .62 + .38 * entryP; opacity *= entryP; break;\n      case 'popIn':\n        final p = Curves.elasticOut.transform((progress / .22).clamp(0.0, 1.0).toDouble());\n        scaleX *= .45 + .55 * p; scaleY *= .45 + .55 * p; opacity *= entryP; break;\n      case 'bounceIn':\n        final p = Curves.bounceOut.transform((progress / .24).clamp(0.0, 1.0).toDouble());\n        dy += (1 - p) * 170; opacity *= entryP; break;\n      case 'typewriter':\n        final count = (displayText.length * entryP).ceil().clamp(0, displayText.length);\n        displayText = displayText.substring(0, count);\n        break;\n      case 'wipeLeftIn': dx -= (1 - entryP) * 95; opacity *= entryP; break;\n      case 'wipeRightIn': dx += (1 - entryP) * 95; opacity *= entryP; break;\n      case 'blurIn': blur += (1 - entryP) * 8; opacity *= entryP; break;\n      case 'rotateIn': rotation -= (1 - entryP) * .5; opacity *= entryP; break;\n      case 'stretchIn': scaleX *= .25 + .75 * entryP; opacity *= entryP; break;\n      case 'scaleFadeIn': scaleX *= .72 + .28 * entryP; scaleY *= .72 + .28 * entryP; opacity *= entryP; break;\n    }\n\n    switch (loop) {\n      case 'pulse': scaleX *= 1 + .055 * math.sin(localSeconds * math.pi * 2.4); scaleY *= 1 + .055 * math.sin(localSeconds * math.pi * 2.4); break;\n      case 'float': dy += math.sin(localSeconds * 2.2) * 10; break;\n      case 'bounce': dy -= math.sin(localSeconds * math.pi * 2).abs() * 14; break;\n      case 'shake': dx += math.sin(localSeconds * 24) * 6; break;\n      case 'wiggle': rotation += math.sin(localSeconds * 8) * .055; break;\n      case 'breathing': scaleX *= 1 + .035 * math.sin(localSeconds * 2); scaleY *= 1 + .035 * math.sin(localSeconds * 2); break;\n      case 'glowPulse': glowBlur = 4 + 12 * ((math.sin(localSeconds * 3) + 1) / 2); break;\n      case 'slowZoom': scaleX *= 1 + .035 * localSeconds; scaleY *= 1 + .035 * localSeconds; break;\n      case 'slowRotation': rotation += localSeconds * .055; break;\n      case 'sway': rotation += math.sin(localSeconds * 2.1) * .035; break;\n      case 'wave': dy += math.sin(localSeconds * 4) * 8; rotation += math.sin(localSeconds * 3) * .02; break;\n      case 'flicker': opacity *= .72 + .28 * ((math.sin(localSeconds * 18) + 1) / 2); break;\n      case 'colorPulse': textColor = Color.lerp(Colors.white, Colors.lightBlueAccent, (math.sin(localSeconds * 2.7) + 1) / 2)!; break;\n      case 'blurPulse': blur += 1.8 * ((math.sin(localSeconds * 3.2) + 1) / 2); break;\n      case 'trackingPulse': letterSpacing = 1.5 + 3.5 * ((math.sin(localSeconds * 2.5) + 1) / 2); break;\n    }\n\n    switch (exit) {\n      case 'fadeOut': opacity *= 1 - exitP; break;\n      case 'slideLeftOut': dx -= exitP * 190; opacity *= 1 - exitP * .35; break;\n      case 'slideRightOut': dx += exitP * 190; opacity *= 1 - exitP * .35; break;\n      case 'slideUpOut': dy -= exitP * 150; opacity *= 1 - exitP * .35; break;\n      case 'slideDownOut': dy += exitP * 150; opacity *= 1 - exitP * .35; break;\n      case 'zoomOut': scaleX *= 1 - .55 * exitP; scaleY *= 1 - .55 * exitP; opacity *= 1 - exitP; break;\n      case 'popOut': scaleX *= 1 + .4 * exitP; scaleY *= 1 + .4 * exitP; opacity *= 1 - exitP; break;\n      case 'bounceOut': dy += math.sin(exitP * math.pi) * 55 + exitP * 120; opacity *= 1 - exitP; break;\n      case 'wipeLeftOut': dx -= exitP * 95; opacity *= 1 - exitP; break;\n      case 'wipeRightOut': dx += exitP * 95; opacity *= 1 - exitP; break;\n      case 'blurOut': blur += exitP * 8; opacity *= 1 - exitP * .55; break;\n      case 'rotateOut': rotation += exitP * .65; opacity *= 1 - exitP; break;\n      case 'shrink': scaleX *= 1 - .75 * exitP; scaleY *= 1 - .75 * exitP; opacity *= 1 - exitP * .5; break;\n      case 'scaleFadeOut': scaleX *= 1 - .4 * exitP; scaleY *= 1 - .4 * exitP; opacity *= 1 - exitP; break;\n      case 'dissolve': opacity *= (1 - exitP) * (.78 + .22 * ((math.sin(localSeconds * 30) + 1) / 2)); break;\n    }\n\n    final boxed = template == 'box' || template == 'lowerThird' || template == 'subtitle' || template == 'badge';\n    final fontSize = (style['fontSize'] as num?)?.toDouble() ?? (template == 'subtitle' ? 24 : 28);\n    Widget content = Container(\n      padding: boxed ? const EdgeInsets.symmetric(horizontal: 16, vertical: 8) : EdgeInsets.zero,\n      color: boxed ? Colors.black54 : Colors.transparent,\n      child: Text(\n        displayText,\n        textAlign: TextAlign.center,\n        style: TextStyle(\n          fontFamily: fontFamily,\n          color: template == 'outline' ? null : textColor,\n          fontSize: fontSize,\n          fontWeight: FontWeight.w700,\n          letterSpacing: letterSpacing,\n          shadows: [Shadow(blurRadius: glowBlur, color: Colors.black)],\n          foreground: template == 'outline'\n              ? (Paint()..style = PaintingStyle.stroke..strokeWidth = 2.2..color = textColor)\n              : null,\n        ),\n      ),\n    );\n    if (blur > .05) {\n      content = ImageFiltered(imageFilter: ImageFilter.blur(sigmaX: blur, sigmaY: blur), child: content);\n    }\n    return Transform.translate(\n      offset: Offset(dx, dy),\n      child: Transform.rotate(\n        angle: rotation,\n        child: Transform(\n          alignment: Alignment.center,\n          transform: Matrix4.diagonal3Values(scaleX, scaleY, 1),\n          child: Opacity(opacity: opacity.clamp(0.0, 1.0).toDouble(), child: content),\n        ),\n      ),\n    );\n  }\n\n''',
    'EditorScreen._previewTextWidget',
  );

  editorFile.writeAsStringSync(editorSource);
  stdout.writeln('Advanced text model and preview patched.');
}
