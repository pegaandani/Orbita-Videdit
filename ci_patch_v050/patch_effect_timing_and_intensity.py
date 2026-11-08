from pathlib import Path
import sys
root=Path(sys.argv[1] if len(sys.argv)>1 else "videdit_project")
panel=root/"lib/features/editor/widgets/transitions_panel.dart"
effects=root/"lib/features/editor/widgets/effects_panel.dart"
renderer=root/"lib/core/services/timeline_render_service.dart"
preview=root/"lib/features/editor/editor_screen.dart"

def replace_one(path,old,new):
    s=path.read_text(encoding="utf-8")
    n=s.count(old)
    if n!=1: raise RuntimeError(f"{path.name}: marker found {n} times: {old[:110]}")
    path.write_text(s.replace(old,new,1),encoding="utf-8")

# Outgoing fade is a separately controllable animation with duration and
# 0..100% intensity. 0% means keep fully opaque; 100% fades to transparent.
replace_one(panel,
    "if (enabled) c.effects.add({'type': 'outroFade', 'duration': .65});",
    "if (enabled) c.effects.add({'type': 'outroFade', 'duration': .65, 'intensity': 1.0});")
replace_one(panel,
"""              final duration = ((effect['duration'] as num?)?.toDouble() ?? .65).clamp(.15, 3.0);
              return Column(children: [""",
"""              final duration = ((effect['duration'] as num?)?.toDouble() ?? .65).clamp(.15, 3.0);
              final intensity = ((effect['intensity'] as num?)?.toDouble() ?? 1.0).clamp(0.0, 1.0).toDouble();
              return Column(children: [""")
replace_one(panel,
"""                  onChanged: (v) { effect['duration'] = v; widget.onChanged(); },
                  onChangeEnd: (_) => widget.onEditEnded?.call(),
                ),
              ]);
""",
"""                  onChanged: (v) { effect['duration'] = v; widget.onChanged(); },
                  onChangeEnd: (_) => widget.onEditEnded?.call(),
                ),
                Row(children: [
                  const Expanded(child: Text('Intensidad del cierre')),
                  Text('\${(intensity * 100).round()} %'),
                ]),
                Slider(
                  value: intensity, min: 0, max: 1,
                  onChangeStart: (_) => widget.onEditStarted?.call(),
                  onChanged: (v) { effect['intensity'] = v; widget.onChanged(); },
                  onChangeEnd: (_) => widget.onEditEnded?.call(),
                ),
              ]);
""")

# The filtered visual is shifted to absolute timeline timestamps already by
# setpts; the outgoing fade must use the CLIP'S ABSOLUTE END, not duration alone.
# A geq alpha curve supports any fade strength and preserves RGB.
replace_one(renderer,
"""          final fadeStart = math.max(0.0, clipSeconds - fadeSeconds);
          vf.add("fade=t=out:st=\${_n(fadeStart)}:d=\${_n(fadeSeconds)}:alpha=1");""",
"""          final fadeStart = math.max(0.0, c.endMs / 1000.0 - fadeSeconds);
          final strength = ((outro.first['intensity'] as num?)?.toDouble() ?? 1.0)
              .clamp(0.0, 1.0).toDouble();
          if (strength > 0.0001) {
            final progress = "max(0,min(1,(T-\${_n(fadeStart)})/\${_n(fadeSeconds)}))";
            vf.add("geq=r='r(X,Y)':g='g(X,Y)':b='b(X,Y)':a='alpha(X,Y)*(1-\${_n(strength)}*($progress))'");
          }""")

# Match Android/iOS/desktop preview to rendered intensity and duration.
replace_one(preview,
"""      final factor = (remaining / durationMs).clamp(0.0, 1.0).toDouble();
      child = Opacity(opacity: factor, child: child);""",
"""      final intensity = ((effect['intensity'] as num?)?.toDouble() ?? 1.0)
          .clamp(0.0, 1.0).toDouble();
      final progress = (1.0 - remaining / durationMs).clamp(0.0, 1.0).toDouble();
      child = Opacity(opacity: (1.0 - intensity * progress).clamp(0.0, 1.0).toDouble(), child: child);""")

# Full-length effect intensity sliders: changes persist in the clip model and
# are not confined to the intro or outro.
replace_one(effects,
"""      if (c.kind == 'video' && c.hasAudio) ...[""",
"""      const Divider(height: 24),
      const Text('Intensidad de efectos permanentes',
          style: TextStyle(fontWeight: FontWeight.w700)),
      const Text('Los efectos activos duran todo el clip; ajusta su fuerza aquí.'),
      if (c.effects.any((e) => e['type'] == 'grain'))
        _effectSlider(c, 'grain', 'amount', 'Granulado', 0, 30),
      if (c.effects.any((e) => e['type'] == 'vignette'))
        _effectSlider(c, 'vignette', 'strength', 'Viñeta', 0, 10),
      if (c.effects.any((e) => e['type'] == 'blur'))
        _effectSlider(c, 'blur', 'amount', 'Desenfoque', 0, 12),
      if (c.effects.any((e) => e['type'] == 'sharpen'))
        _effectSlider(c, 'sharpen', 'amount', 'Nitidez', 0, 3),
      if (c.effects.any((e) => e['type'] == 'cameraShake'))
        _effectSlider(c, 'cameraShake', 'amount', 'Temblor', 0.2, 3),
      if (c.effects.any((e) => e['type'] == 'distortion'))
        _effectSlider(c, 'distortion', 'amount', 'Distorsión', .02, .45),
      if (c.effects.any((e) => e['type'] == 'bokeh'))
        _effectSlider(c, 'bokeh', 'amount', 'Bokeh', .5, 6),
      if (c.effects.any((e) => e['type'] == 'glitch'))
        _effectSlider(c, 'glitch', 'amount', 'Glitch', 0, 3),
      if (c.effects.any((e) => e['type'] == 'drunk'))
        _effectSlider(c, 'drunk', 'amount', 'Estela', 0, 3),
      if (c.kind == 'video' && c.hasAudio) ...[""")
print("Outro timing fixed to absolute timeline, fade strength supported in preview/export, full-clip effect sliders exposed.")
