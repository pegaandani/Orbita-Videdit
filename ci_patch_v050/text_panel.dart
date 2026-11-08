import 'package:flutter/material.dart';

class TextPanel extends StatefulWidget {
  const TextPanel({super.key, required this.onAdd});

  final void Function(
    String text,
    String template,
    String fontFamily,
    String entryAnimation,
    String loopAnimation,
    String exitAnimation,
  ) onAdd;

  @override
  State<TextPanel> createState() => _TextPanelState();
}

class _TextPanelState extends State<TextPanel> {
  final controller = TextEditingController();
  String template = 'clean';
  String fontFamily = 'Inter';
  String entryAnimation = 'fadeIn';
  String loopAnimation = 'none';
  String exitAnimation = 'fadeOut';

  static const fonts = <String>[
    'Inter',
    'Lato',
    'Cabin',
    'Cantarell',
    'Comic Neue',
    'Roboto Slab',
    'Liberation Sans',
    'Liberation Serif',
    'Liberation Mono',
    'FreeSans',
    'FreeSerif',
    'FreeMono',
    'Go',
    'Go Mono',
    'Amiri',
  ];

  static const entryAnimations = <({String id, String label})>[
    (id: 'fadeIn', label: 'Fade In'),
    (id: 'slideLeftIn', label: 'Slide Left'),
    (id: 'slideRightIn', label: 'Slide Right'),
    (id: 'slideUpIn', label: 'Slide Up'),
    (id: 'slideDownIn', label: 'Slide Down'),
    (id: 'zoomIn', label: 'Zoom In'),
    (id: 'popIn', label: 'Pop In'),
    (id: 'bounceIn', label: 'Bounce In'),
    (id: 'typewriter', label: 'Typewriter'),
    (id: 'wipeLeftIn', label: 'Wipe Left'),
    (id: 'wipeRightIn', label: 'Wipe Right'),
    (id: 'blurIn', label: 'Blur In'),
    (id: 'rotateIn', label: 'Rotate In'),
    (id: 'stretchIn', label: 'Stretch In'),
    (id: 'scaleFadeIn', label: 'Scale + Fade In'),
  ];

  static const loopAnimations = <({String id, String label})>[
    (id: 'pulse', label: 'Pulse'),
    (id: 'float', label: 'Float'),
    (id: 'bounce', label: 'Bounce'),
    (id: 'shake', label: 'Shake'),
    (id: 'wiggle', label: 'Wiggle'),
    (id: 'breathing', label: 'Breathing'),
    (id: 'glowPulse', label: 'Glow Pulse'),
    (id: 'slowZoom', label: 'Slow Zoom'),
    (id: 'slowRotation', label: 'Slow Rotation'),
    (id: 'sway', label: 'Sway'),
    (id: 'wave', label: 'Wave'),
    (id: 'flicker', label: 'Flicker'),
    (id: 'colorPulse', label: 'Color Pulse'),
    (id: 'blurPulse', label: 'Blur Pulse'),
    (id: 'trackingPulse', label: 'Tracking Pulse'),
  ];

  static const exitAnimations = <({String id, String label})>[
    (id: 'fadeOut', label: 'Fade Out'),
    (id: 'slideLeftOut', label: 'Slide Left'),
    (id: 'slideRightOut', label: 'Slide Right'),
    (id: 'slideUpOut', label: 'Slide Up'),
    (id: 'slideDownOut', label: 'Slide Down'),
    (id: 'zoomOut', label: 'Zoom Out'),
    (id: 'popOut', label: 'Pop Out'),
    (id: 'bounceOut', label: 'Bounce Out'),
    (id: 'wipeLeftOut', label: 'Wipe Left'),
    (id: 'wipeRightOut', label: 'Wipe Right'),
    (id: 'blurOut', label: 'Blur Out'),
    (id: 'rotateOut', label: 'Rotate Out'),
    (id: 'shrink', label: 'Shrink'),
    (id: 'scaleFadeOut', label: 'Scale + Fade Out'),
    (id: 'dissolve', label: 'Dissolve'),
  ];

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scrollbar(
        thumbVisibility: true,
        child: ListView(
          padding: const EdgeInsets.all(14),
          children: [
            const Text('Texto y títulos', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              minLines: 2,
              maxLines: 5,
              decoration: const InputDecoration(
                labelText: 'Escribe tu texto',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 14),
            const Text('Plantilla', style: TextStyle(fontWeight: FontWeight.w700)),
            Wrap(spacing: 8, runSpacing: 8, children: [
              _choice('clean', 'Limpio'),
              _choice('box', 'Caja'),
              _choice('lowerThird', 'Cintillo'),
              _choice('subtitle', 'Subtítulo'),
              _choice('outline', 'Contorno'),
              _choice('badge', 'Etiqueta'),
              _choice('quote', 'Cita'),
            ]),
            const SizedBox(height: 14),
            DropdownButtonFormField<String>(
              initialValue: fontFamily,
              decoration: const InputDecoration(labelText: 'Fuente', border: OutlineInputBorder()),
              items: [
                for (final family in fonts)
                  DropdownMenuItem(
                    value: family,
                    child: Text(family, style: TextStyle(fontFamily: family)),
                  ),
              ],
              onChanged: (value) => setState(() => fontFamily = value ?? fontFamily),
            ),
            const SizedBox(height: 14),
            _animationSelector(
              label: 'Animación de entrada',
              value: entryAnimation,
              items: entryAnimations,
              includeNone: true,
              onChanged: (value) => setState(() => entryAnimation = value),
            ),
            const SizedBox(height: 12),
            _animationSelector(
              label: 'Animación en bucle',
              value: loopAnimation,
              items: loopAnimations,
              includeNone: true,
              onChanged: (value) => setState(() => loopAnimation = value),
            ),
            const SizedBox(height: 12),
            _animationSelector(
              label: 'Animación de salida',
              value: exitAnimation,
              items: exitAnimations,
              includeNone: true,
              onChanged: (value) => setState(() => exitAnimation = value),
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: () {
                final text = controller.text.trim();
                if (text.isEmpty) return;
                widget.onAdd(
                  text,
                  template,
                  fontFamily,
                  entryAnimation,
                  loopAnimation,
                  exitAnimation,
                );
              },
              icon: const Icon(Icons.add),
              label: const Text('Añadir al cabezal'),
            ),
            const SizedBox(height: 10),
            const Text('Entrada, bucle y salida se guardan por separado y se combinan durante la previsualización y la exportación.'),
          ],
        ),
      );

  Widget _animationSelector({
    required String label,
    required String value,
    required List<({String id, String label})> items,
    required bool includeNone,
    required ValueChanged<String> onChanged,
  }) {
    return DropdownButtonFormField<String>(
      initialValue: value,
      decoration: InputDecoration(labelText: label, border: const OutlineInputBorder()),
      items: [
        if (includeNone) const DropdownMenuItem(value: 'none', child: Text('Ninguna')),
        for (final item in items) DropdownMenuItem(value: item.id, child: Text(item.label)),
      ],
      onChanged: (next) {
        if (next != null) onChanged(next);
      },
    );
  }

  Widget _choice(String id, String label) => ChoiceChip(
        label: Text(label),
        selected: template == id,
        onSelected: (_) => setState(() => template = id),
      );
}
