import 'package:flutter/material.dart';
import '../../../core/models/orbita_project.dart';

class FilterPanel extends StatelessWidget {
  const FilterPanel({super.key, required this.clip, required this.onChanged});
  final TimelineClip? clip;
  final VoidCallback onChanged;

  static const presets = <({String id, String label})>[
    (id: 'cinema', label: 'Cine'),
    (id: 'deepBlack', label: 'Negros intensos'),
    (id: 'bw', label: 'Blanco y negro'),
    (id: 'noir', label: 'Noir'),
    (id: 'vintage', label: 'Vintage'),
    (id: 'sepia', label: 'Sepia'),
    (id: 'tealOrange', label: 'Teal & Orange'),
    (id: 'bleach', label: 'Bleach bypass'),
    (id: 'soft', label: 'Suave'),
    (id: 'dream', label: 'Ensueño'),
    (id: 'pastel', label: 'Pastel'),
    (id: 'sunset', label: 'Atardecer'),
    (id: 'warm', label: 'Cálido'),
    (id: 'cool', label: 'Frío'),
    (id: 'vivid', label: 'Vívido'),
  ];

  Map<String, dynamic> _colorEffect(TimelineClip c) {
    for (final e in c.effects) {
      if (e['type'] == 'color') return e;
    }
    final e = <String, dynamic>{
      'type': 'color',
      'brightness': 0.0,
      'contrast': 1.0,
      'saturation': 1.0,
      'hue': 0.0,
      'temperature': 0.0,
    };
    c.effects.add(e);
    return e;
  }

  bool _isPresetActive(TimelineClip c, String id) =>
      c.effects.any((e) => e['type'] == 'preset' && e['id'] == id);

  void _togglePreset(TimelineClip c, String id, bool enabled) {
    c.effects.removeWhere((e) => e['type'] == 'preset' && e['id'] == id);
    if (enabled) c.effects.add({'type': 'preset', 'id': id});
    onChanged();
  }

  void _clearPresets(TimelineClip c) {
    c.effects.removeWhere((e) => e['type'] == 'preset');
    onChanged();
  }

  @override
  Widget build(BuildContext context) {
    final c = clip;
    if (c == null || c.kind == 'audio' || c.kind == 'text') {
      return const Center(child: Padding(
        padding: EdgeInsets.all(22),
        child: Text('Selecciona un clip de video, imagen o GIF para ajustar color y filtros.', textAlign: TextAlign.center),
      ));
    }
    final color = _colorEffect(c);
    final activeCount = c.effects.where((e) => e['type'] == 'preset').length;
    return Scrollbar(
      thumbVisibility: true,
      child: ListView(
        padding: const EdgeInsets.all(14),
        children: [
          const Text('Filtros', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
          const SizedBox(height: 4),
          Text('Puedes combinar varios filtros. Activos: $activeCount'),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              FilterChip(
                label: const Text('Original'),
                selected: activeCount == 0,
                onSelected: (_) => _clearPresets(c),
              ),
              for (final item in presets)
                FilterChip(
                  label: Text(item.label),
                  selected: _isPresetActive(c, item.id),
                  onSelected: (v) => _togglePreset(c, item.id, v),
                ),
            ],
          ),
          const SizedBox(height: 18),
          const Text('Ajustes manuales', style: TextStyle(fontWeight: FontWeight.w700)),
          _slider('Brillo', color, 'brightness', -1, 1),
          _slider('Contraste', color, 'contrast', 0, 2),
          _slider('Saturación', color, 'saturation', 0, 3),
          _slider('Tonalidad', color, 'hue', -180, 180, suffix: '°'),
          _slider('Temperatura', color, 'temperature', -1, 1),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: () {
              color
                ..['brightness'] = 0.0
                ..['contrast'] = 1.0
                ..['saturation'] = 1.0
                ..['hue'] = 0.0
                ..['temperature'] = 0.0;
              c.effects.removeWhere((e) => e['type'] == 'preset');
              onChanged();
            },
            icon: const Icon(Icons.restart_alt),
            label: const Text('Restablecer color y filtros'),
          ),
        ],
      ),
    );
  }

  Widget _slider(
    String label,
    Map<String, dynamic> effect,
    String key,
    double min,
    double max, {
    String suffix = '',
  }) {
    final value = (effect[key] as num?)?.toDouble() ?? min;
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(child: Text(label)),
          Text('${value.toStringAsFixed(key == 'hue' ? 0 : 2)}$suffix'),
        ]),
        Slider(
          value: value.clamp(min, max).toDouble(),
          min: min,
          max: max,
          onChanged: (v) {
            effect[key] = v;
            onChanged();
          },
        ),
      ]),
    );
  }
}
