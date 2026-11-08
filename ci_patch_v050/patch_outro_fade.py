from pathlib import Path
import sys
root=Path(sys.argv[1] if len(sys.argv)>1 else "videdit_project")
lib=root/"lib"
transitions=lib/"features/editor/widgets/transitions_panel.dart"
preview=lib/"features/editor/editor_screen.dart"
renderer=lib/"core/services/timeline_render_service.dart"
def replace(path,before,after):
    s=path.read_text(encoding="utf8")
    if s.count(before)!=1: raise RuntimeError(f"Outro patch marker mismatch {path} {s.count(before)}: {before[:80]}")
    path.write_text(s.replace(before,after,1),encoding="utf8")
replace(transitions,
"          if (active.isNotEmpty)\n            OutlinedButton.icon(",
"""          const Divider(height: 25),
          const Text('Salida del clip', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
          const Text('Fundido final independiente de los efectos de entrada.'),
          SwitchListTile(
            secondary: const Icon(Icons.exit_to_app),
            title: const Text('Desvanecer al terminar'),
            value: c.effects.any((e) => e['type'] == 'outroFade'),
            onChanged: (enabled) {
              widget.onEditStarted?.call();
              c.effects.removeWhere((e) => e['type'] == 'outroFade');
              if (enabled) c.effects.add({'type': 'outroFade', 'duration': .65});
              widget.onChanged();
              widget.onEditEnded?.call();
            },
          ),
          if (c.effects.any((e) => e['type'] == 'outroFade'))
            Builder(builder: (context) {
              final effect = c.effects.firstWhere((e) => e['type'] == 'outroFade');
              final duration = ((effect['duration'] as num?)?.toDouble() ?? .65).clamp(.15, 3.0);
              return Column(children: [
                Row(children: [
                  const Expanded(child: Text('Duración de salida')),
                  Text(duration.toStringAsFixed(2) + ' s'),
                ]),
                Slider(
                  value: duration.toDouble(), min: .15, max: 3.0,
                  onChangeStart: (_) => widget.onEditStarted?.call(),
                  onChanged: (v) { effect['duration'] = v; widget.onChanged(); },
                  onChangeEnd: (_) => widget.onEditEnded?.call(),
                ),
              ]);
            }),
          if (active.isNotEmpty)
            OutlinedButton.icon(""")
replace(renderer,
"        filters.add('[$idx:v]${vf.join(',')}[$layer]');",
"""        final outro = c.effects.where((e) => e['type'] == 'outroFade').toList();
        if (outro.isNotEmpty) {
          final clipSeconds = c.durationMs / 1000.0;
          final fadeSeconds = ((outro.first['duration'] as num?)?.toDouble() ?? .65)
              .clamp(.15, math.max(.15, clipSeconds)).toDouble();
          final fadeStart = math.max(0.0, clipSeconds - fadeSeconds);
          vf.add("fade=t=out:st=${_n(fadeStart)}:d=${_n(fadeSeconds)}:alpha=1");
        }
        filters.add('[$idx:v]${vf.join(',')}[$layer]');""")
# Other functional patches replace the entire preview method before this script.
# Edit only the _applyPreviewEffects block, regardless of its implementation.
previewSource = preview.read_text(encoding="utf8")
previewStart = previewSource.find("  Widget _applyPreviewEffects(TimelineClip c, Widget child) {")
previewEnd = previewSource.find("  Widget _previewTextWidget(TimelineClip c) {", previewStart)
if previewStart < 0 or previewEnd < 0:
    raise RuntimeError("Cannot find active preview effects method")
block = previewSource[previewStart:previewEnd]
if "e['type'] == 'outroFade'" in block:
    print("Preview fade already patched.")
else:
    marker = "    return child;"
    if marker not in block:
        marker = "    return ColorFiltered(colorFilter: ColorFilter.matrix(_previewColorMatrix(c)), child: child);"
        if marker not in block:
            raise RuntimeError("No supported return statement in active preview effects")
    injected = """    for (final effect in c.effects.where((e) => e['type'] == 'outroFade')) {
      final durationMs = (((effect['duration'] as num?)?.toDouble() ?? .65) * 1000)
          .round().clamp(150, c.durationMs > 150 ? c.durationMs : 150);
      final remaining = c.endMs - playheadMs;
      final factor = (remaining / durationMs).clamp(0.0, 1.0).toDouble();
      child = Opacity(opacity: factor, child: child);
    }
"""
    block = block.replace(marker, injected + marker, 1)
    preview.write_text(previewSource[:previewStart] + block + previewSource[previewEnd:], encoding="utf8")
print("Outro fade preview, UI and export installed.")
