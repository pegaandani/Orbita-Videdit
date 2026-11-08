from pathlib import Path
import sys
root=Path(sys.argv[1] if len(sys.argv)>1 else "videdit_project")
render=root/"lib/core/services/timeline_render_service.dart"
preview=root/"lib/features/editor/editor_screen.dart"
def once(path,before,after):
    source=path.read_text(encoding="utf-8")
    count=source.count(before)
    if count!=1: raise RuntimeError(f"{path.name}: marker expected once, got {count}: {before[:110]}")
    path.write_text(source.replace(before,after,1),encoding="utf-8")

once(render,
"""      } else if (type == 'vignette') {
        out.add('vignette=PI/${_n((effect['strength'] as num?)?.toDouble() ?? 5)}');
      } else if (type == 'blur') {
        out.add('gblur=sigma=${_n((effect['amount'] as num?)?.toDouble() ?? 2)}');
""",
"""      } else if (type == 'vignette') {
        final strength = ((effect['strength'] as num?)?.toDouble() ?? 5.0)
            .clamp(0.0, 10.0).toDouble();
        if (strength > .001) {
          out.add('vignette=PI/${_n(12.0 - strength)}');
        }
      } else if (type == 'blur') {
        final amount = ((effect['amount'] as num?)?.toDouble() ?? 2.0)
            .clamp(0.0, 12.0).toDouble();
        if (amount > .001) out.add('gblur=sigma=${_n(amount)}');
""")
once(render,
"""      } else if (type == 'drunk') {
        out.addAll(['tmix=frames=3:weights=1 2 1', 'eq=saturation=1.18']);
      } else if (type == 'bokeh') {
""",
"""      } else if (type == 'drunk') {
        final amount = ((effect['amount'] as num?)?.toDouble() ?? 1.0)
            .clamp(0.0, 3.0).toDouble();
        if (amount > .001) {
          out.add('tmix=frames=3:weights=${_n(amount)} 2 ${_n(amount)}');
          out.add('eq=saturation=${_n(1.0 + amount * .18)}');
        }
      } else if (type == 'bokeh') {
""")
once(render,
"""      } else if (type == 'glitch') {
        out.addAll(['noise=alls=10:allf=t+u', "hue='6*sin(22*t)'"]);
      } else if (type == 'transition') {
""",
"""      } else if (type == 'glitch') {
        final amount = ((effect['amount'] as num?)?.toDouble() ?? 1.0)
            .clamp(0.0, 3.0).toDouble();
        if (amount > .001) {
          out.add('noise=alls=${_n(10 * amount)}:allf=t+u');
          out.add("hue='${_n(6 * amount)}*sin(22*t)'");
        }
      } else if (type == 'transition') {
""")
once(preview,
"""      final strength = ((vignette['strength'] as num?)?.toDouble() ?? 5).clamp(2.0, 12.0).toDouble();""",
"""      final strength = ((vignette['strength'] as num?)?.toDouble() ?? 5).clamp(0.0, 10.0).toDouble();""")
once(preview,
"""Colors.black.withValues(alpha: (0.12 + (strength - 2.0) * .055).clamp(.12, .68).toDouble()),""",
"""Colors.black.withValues(alpha: (strength * .068).clamp(0.0, .68).toDouble()),""")
once(preview,
"""      final amount = ((drunk['amount'] as num?)?.toDouble() ?? 1).clamp(.2, 3.0).toDouble();""",
"""      final amount = ((drunk['amount'] as num?)?.toDouble() ?? 1).clamp(0.0, 3.0).toDouble();""")
once(preview,
"""      final amount = ((glitch['amount'] as num?)?.toDouble() ?? 1).clamp(.2, 3.0).toDouble();""",
"""      final amount = ((glitch['amount'] as num?)?.toDouble() ?? 1).clamp(0.0, 3.0).toDouble();""")
print("Preview/export effect strengths: zero safe, glitch/afterimage amounts effective.")
