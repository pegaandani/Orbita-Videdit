import 'package:flutter/material.dart';
import '../../../core/models/orbita_project.dart';

class TransitionsPanel extends StatelessWidget {
  const TransitionsPanel({
    super.key,
    required this.clip,
    required this.onChanged,
    this.onEditStarted,
    this.onEditEnded,
  });

  final TimelineClip? clip;
  final VoidCallback onChanged;
  final VoidCallback? onEditStarted;
  final VoidCallback? onEditEnded;

  static const transitions = <({String id, String label, IconData icon})>[
    (id: 'fadeBlack', label: 'Fundido a negro', icon: Icons.dark_mode_outlined),
    (id: 'fadeWhite', label: 'Fundido a claro', icon: Icons.light_mode_outlined),
    (id: 'blurIn', label: 'Desenfoque', icon: Icons.blur_on),
    (id: 'zoomIn', label: 'Zoom suave', icon: Icons.zoom_in),
    (id: 'slideLeft', label: 'Deslizar izquierda', icon: Icons.arrow_back),
    (id: 'slideRight', label: 'Deslizar derecha', icon: Icons.arrow_forward),
    (id: 'wipeUp', label: 'Barrido arriba', icon: Icons.arrow_upward),
    (id: 'wipeDown', label: 'Barrido abajo', icon: Icons.arrow_downward),
    (id: 'flash', label: 'Flash', icon: Icons.flash_on),
    (id: 'pixelate', label: 'Pixelado', icon: Icons.grid_on),
  ];

  List<Map<String, dynamic>> _active(TimelineClip c) =>
      c.effects.where((e) => e['type'] == 'transition').toList();

  Map<String, dynamic>? _find(TimelineClip c, String id) {
    for (final e in c.effects) {
      if (e['type'] == 'transition' && e['id'] == id) return e;
    }
    return null;
  }

  void _toggle(TimelineClip c, String id, bool enabled) {
    onEditStarted?.call();
    c.effects.removeWhere((e) => e['type'] == 'transition' && e['id'] == id);
    if (enabled) {
      c.effects.add({'type': 'transition', 'id': id, 'duration': .45});
    }
    onChanged();
    onEditEnded?.call();
  }

  @override
  Widget build(BuildContext context) {
    final c = clip;
    if (c == null || !c.isVisual || c.kind == 'text') {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(22),
          child: Text('Selecciona un clip de video, imagen o GIF para aplicar transiciones.', textAlign: TextAlign.center),
        ),
      );
    }
    final active = _active(c);
    return Scrollbar(
      thumbVisibility: true,
      child: ListView(
        padding: const EdgeInsets.all(14),
        children: [
          const Text('Transiciones', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
          const SizedBox(height: 4),
          Text('Puedes combinar varias transiciones al inicio del clip. Activas: ${active.length}'),
          const SizedBox(height: 10),
          for (final item in transitions) ...[
            Builder(builder: (_) {
              final effect = _find(c, item.id);
              final enabled = effect != null;
              final duration = ((effect?['duration'] as num?)?.toDouble() ?? .45).clamp(.15, 2.0).toDouble();
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SwitchListTile(
                    value: enabled,
                    secondary: Icon(item.icon),
                    title: Text(item.label),
                    onChanged: (v) => _toggle(c, item.id, v),
                  ),
                  if (enabled)
                    Padding(
                      padding: const EdgeInsets.only(left: 16, right: 16, bottom: 8),
                      child: Column(children: [
                        Row(children: [
                          const Expanded(child: Text('Duración')),
                          Text('${duration.toStringAsFixed(2)} s'),
                        ]),
                        Slider(
                          value: duration,
                          min: .15,
                          max: 2.0,
                          onChangeStart: (_) => onEditStarted?.call(),
                          onChanged: (v) {
                            effect!['duration'] = v;
                            onChanged();
                          },
                          onChangeEnd: (_) => onEditEnded?.call(),
                        ),
                      ]),
                    ),
                ],
              );
            }),
          ],
          if (active.isNotEmpty)
            OutlinedButton.icon(
              onPressed: () {
                onEditStarted?.call();
                c.effects.removeWhere((e) => e['type'] == 'transition');
                onChanged();
                onEditEnded?.call();
              },
              icon: const Icon(Icons.close),
              label: const Text('Quitar todas las transiciones'),
            ),
        ],
      ),
    );
  }
}
