import 'dart:io';

void main(List<String> args) {
  if (args.isEmpty) {
    stderr.writeln('Usage: dart patch_text_export.dart <videdit_project>');
    exit(2);
  }
  final sep = Platform.pathSeparator;
  final file = File('${args.first}${sep}lib${sep}core${sep}services${sep}timeline_render_service.dart');
  var source = file.readAsStringSync().replaceAll('\r\n', '\n');

  void replaceRequired(String oldValue, String newValue, String label) {
    if (!source.contains(oldValue)) {
      stderr.writeln('Required block not found: $label');
      exit(3);
    }
    source = source.replaceFirst(oldValue, newValue);
  }

  replaceRequired(
    '''    final fontFiles = await FontAssetService().materializeAll();
''',
    '''    final hasTextClips = project.tracks.any((track) => track.clips.any((clip) => clip.kind == 'text'));
    final fontFiles = hasTextClips
        ? await FontAssetService().materializeAll()
        : const <String, String>{};
''',
    'conditional font materialization',
  );

  replaceRequired(
    '''      case 'typewriter':
        // drawtext cannot reveal graphemes incrementally without expanding into
        // one filter per character. Keep timing visible and deterministic in
        // export while the interactive preview performs the character reveal.
        alpha = "(\$alpha)*(\$entryP)";
        break;
''',
    '''      case 'typewriter':
        // The final draw chain below reveals the text in timed stages.
        break;
''',
    'typewriter animation',
  );

  const oldDraw = '''    final box = template == 'box' || template == 'lowerThird' || template == 'subtitle' || template == 'badge';
    final draw = StringBuffer()
      ..write("drawtext=text='\${_escapeDrawText(c.text ?? '')}'")
      ..write(fontPath == null ? ":font='\${_escapeDrawText(fontFamily)}'" : ":fontfile='\${_escapeFilterPath(fontPath)}'")
      ..write(":fontcolor=\$color:fontsize='\$fontSizeExpr'")
      ..write(":x='\$x':y='\$y':alpha='\$alpha'")
      ..write(":enable='between(t,\${_n(start)},\${_n(end)})'");
    if (box) draw.write(':box=1:boxcolor=black@0.55:boxborderw=18');
    if (template == 'outline') draw.write(':borderw=3:bordercolor=black@0.9');
    if (template == 'quote') draw.write(':shadowx=3:shadowy=3:shadowcolor=black@0.7');
    return draw.toString();
''';

  const newDraw = '''    final box = template == 'box' || template == 'lowerThird' || template == 'subtitle' || template == 'badge';

    String drawFor(String value, double from, double to) {
      final draw = StringBuffer()
        ..write("drawtext=text='\${_escapeDrawText(value)}'")
        ..write(fontPath == null ? ":font='\${_escapeDrawText(fontFamily)}'" : ":fontfile='\${_escapeFilterPath(fontPath)}'")
        ..write(":fontcolor=\$color:fontsize='\$fontSizeExpr'")
        ..write(":x='\$x':y='\$y':alpha='\$alpha'")
        ..write(":enable='between(t,\${_n(from)},\${_n(to)})'");
      if (box) draw.write(':box=1:boxcolor=black@0.55:boxborderw=18');
      if (template == 'outline') draw.write(':borderw=3:bordercolor=black@0.9');
      if (template == 'quote') draw.write(':shadowx=3:shadowy=3:shadowcolor=black@0.7');
      return draw.toString();
    }

    final draws = <String>[];
    final text = c.text ?? '';
    if (entry == 'typewriter' && text.isNotEmpty) {
      final runes = text.runes.toList(growable: false);
      final stages = math.min(40, runes.length);
      for (var stage = 0; stage < stages; stage++) {
        final revealCount = math.max(1, ((stage + 1) * runes.length / stages).ceil());
        final from = start + entryDur * stage / stages;
        final to = stage == stages - 1 ? end : start + entryDur * (stage + 1) / stages;
        draws.add(drawFor(String.fromCharCodes(runes.take(revealCount)), from, to));
      }
    } else {
      draws.add(drawFor(text, start, end));
    }

    if (entry == 'blurIn') {
      draws.add("gblur=sigma=3.2:steps=2:enable='between(t,\${_n(start)},\${_n(start + entryDur * .55)})'");
    }
    if (loop == 'blurPulse') {
      draws.add("gblur=sigma=1.8:steps=1:enable='gt(sin((\$localT)*3.5),0.45)*between(t,\${_n(start)},\${_n(end)})'");
    }
    if (exit == 'blurOut') {
      draws.add("gblur=sigma=3.2:steps=2:enable='between(t,\${_n(end - exitDur * .55)},\${_n(end)})'");
    }
    return draws.join(',');
''';

  replaceRequired(oldDraw, newDraw, 'text draw chain');
  file.writeAsStringSync(source);
  stdout.writeln('Text export patched with staged typewriter, real blur filters and lazy font materialization.');
}
