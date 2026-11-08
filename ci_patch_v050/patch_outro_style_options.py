from pathlib import Path
import sys
root=Path(sys.argv[1] if len(sys.argv)>1 else "videdit_project")
panel=root/"lib/features/editor/widgets/transitions_panel.dart"
renderer=root/"lib/core/services/timeline_render_service.dart"
preview=root/"lib/features/editor/editor_screen.dart"

def once(path,before,after):
    source=path.read_text(encoding="utf-8")
    n=source.count(before)
    if n!=1: raise RuntimeError(f"{path.name}: expected one marker, found {n}: {before[:120]}")
    path.write_text(source.replace(before,after,1),encoding="utf-8")

once(panel,
"""              return Column(children: [
                Row(children: [
                  const Expanded(child: Text('Duración de salida')),""",
"""              return Column(children: [
                DropdownButtonFormField<String>(
                  initialValue: (effect['style'] as String?) ?? 'fade',
                  decoration: const InputDecoration(labelText: 'Tipo de salida'),
                  items: const [
                    DropdownMenuItem(value: 'fade', child: Text('Desvanecimiento')),
                    DropdownMenuItem(value: 'zoomOut', child: Text('Alejamiento')),
                    DropdownMenuItem(value: 'slideLeft', child: Text('Deslizar a la izquierda')),
                    DropdownMenuItem(value: 'slideRight', child: Text('Deslizar a la derecha')),
                    DropdownMenuItem(value: 'spinOut', child: Text('Giro de salida')),
                  ],
                  onChanged: (v) {
                    if (v == null) return;
                    widget.onEditStarted?.call();
                    effect['style'] = v;
                    widget.onChanged();
                    widget.onEditEnded?.call();
                  },
                ),
                const SizedBox(height: 8),
                Row(children: [
                  const Expanded(child: Text('Duración de salida')),""")

# FFmpeg visual compositor: the outgoing effect uses absolute clip end times.
once(renderer,
"""        final rotationExpr = _faceTrackExpr(c, 'rotation', timeVariable: 't') ?? animatedRotationExpr;
        final opacityExpr = _transformExpr(c, 'opacity', c.opacity, timeVariable: 'T');""",
"""        var rotationExpr = _faceTrackExpr(c, 'rotation', timeVariable: 't') ?? animatedRotationExpr;
        if (outro.isNotEmpty) {
          final exit = outro.first;
          final intensity = ((exit['intensity'] as num?)?.toDouble() ?? 1.0)
              .clamp(0.0, 1.0).toDouble();
          final duration = ((exit['duration'] as num?)?.toDouble() ?? .65)
              .clamp(.15, math.max(.15, c.durationMs / 1000.0)).toDouble();
          final start = math.max(0.0, c.endMs / 1000.0 - duration);
          final p = "max(0,min(1,(t-${_n(start)})/${_n(duration)}))";
          switch (exit['style']) {
            case 'zoomOut':
              scaleExpr = "($scaleExpr)*(1-${_n(.55 * intensity)}*($p))";
              break;
            case 'spinOut':
              rotationExpr = "($rotationExpr)+${_n(360 * intensity)}*($p)";
              break;
          }
        }
        final opacityExpr = _transformExpr(c, 'opacity', c.opacity, timeVariable: 'T');""")

once(renderer,
"""        final next = 'vcomp${visualIndex++}';
        filters.add(
          "[$videoLabel][$transformed]overlay=""",
"""        if (outro.isNotEmpty) {
          final exit = outro.first;
          final intensity = ((exit['intensity'] as num?)?.toDouble() ?? 1.0)
              .clamp(0.0, 1.0).toDouble();
          final duration = ((exit['duration'] as num?)?.toDouble() ?? .65)
              .clamp(.15, math.max(.15, c.durationMs / 1000.0)).toDouble();
          final start = math.max(0.0, c.endMs / 1000.0 - duration);
          final p = "max(0,min(1,(t-${_n(start)})/${_n(duration)}))";
          if (exit['style'] == 'slideLeft') {
            xExpr = "($xExpr)-${_n(1.2 * intensity)}*($p)";
          } else if (exit['style'] == 'slideRight') {
            xExpr = "($xExpr)+${_n(1.2 * intensity)}*($p)";
          }
        }
        final next = 'vcomp${visualIndex++}';
        filters.add(
          "[$videoLabel][$transformed]overlay=""")

once(preview,
"""      final progress = (1.0 - remaining / durationMs).clamp(0.0, 1.0).toDouble();
      child = Opacity(opacity: (1.0 - intensity * progress).clamp(0.0, 1.0).toDouble(), child: child);""",
"""      final progress = (1.0 - remaining / durationMs).clamp(0.0, 1.0).toDouble();
      switch (effect['style']) {
        case 'zoomOut':
          child = Transform.scale(scale: 1.0 - .55 * intensity * progress, child: child);
          break;
        case 'slideLeft':
          child = FractionalTranslation(
            translation: Offset(-1.2 * intensity * progress, 0), child: child);
          break;
        case 'slideRight':
          child = FractionalTranslation(
            translation: Offset(1.2 * intensity * progress, 0), child: child);
          break;
        case 'spinOut':
          child = Transform.rotate(
            angle: 2 * math.pi * intensity * progress, child: child);
          break;
      }
      child = Opacity(opacity: (1.0 - intensity * progress).clamp(0.0, 1.0).toDouble(), child: child);""")
print("5 outro styles connected to preview and MP4: fade, zoom-out, left/right slides, spin-out.")
