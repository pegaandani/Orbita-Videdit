import 'package:flutter/material.dart';
import '../../../core/models/orbita_project.dart';

class TextPanel extends StatefulWidget {
  const TextPanel({
    super.key,
    required this.onAdd,
    required this.onChanged,
    this.clip,
    this.onEditStarted,
    this.onEditEnded,
  });

  final TimelineClip? clip;
  final void Function(String text, Map<String, dynamic> style) onAdd;
  final VoidCallback onChanged;
  final VoidCallback? onEditStarted;
  final VoidCallback? onEditEnded;

  @override
  State<TextPanel> createState() => _TextPanelState();
}

class _TextPanelState extends State<TextPanel> {
  final controller = TextEditingController();
  final editController = TextEditingController();
  final scrollController = ScrollController();

  String template = 'clean';
  String fontFamily = 'Roboto';
  String entryAnimation = 'fadeIn';
  String loopAnimation = 'none';
  String exitAnimation = 'fadeOut';
  double fontSize = 48;
  String? _editingClipId;

  static const fonts = <String>[
    'Roboto', 'Open Sans', 'Montserrat', 'Poppins', 'Inter', 'Lato', 'Nunito', 'Raleway', 'Oswald',
    'Source Sans 3', 'Ubuntu', 'Merriweather', 'Playfair Display', 'Bebas Neue', 'Caveat',
  ];

  static const entries = <({String id, String label})>[
    (id: 'fadeIn', label: 'Fade In'),
    (id: 'slideLeftIn', label: 'Desde izquierda'),
    (id: 'slideRightIn', label: 'Desde derecha'),
    (id: 'slideUpIn', label: 'Desde abajo'),
    (id: 'slideDownIn', label: 'Desde arriba'),
    (id: 'zoomIn', label: 'Zoom In'),
    (id: 'popIn', label: 'Pop In'),
    (id: 'bounceIn', label: 'Bounce In'),
    (id: 'typewriter', label: 'Máquina de escribir'),
    (id: 'wipeLeftIn', label: 'Wipe izquierda'),
    (id: 'wipeRightIn', label: 'Wipe derecha'),
    (id: 'blurIn', label: 'Blur In'),
    (id: 'rotateIn', label: 'Rotate In'),
    (id: 'stretchIn', label: 'Stretch In'),
    (id: 'scaleFadeIn', label: 'Scale + Fade'),
  ];

  static const loops = <({String id, String label})>[
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
    (id: 'trackingPulse', label: 'Spacing Pulse'),
  ];

  static const exits = <({String id, String label})>[
    (id: 'fadeOut', label: 'Fade Out'),
    (id: 'slideLeftOut', label: 'Salir izquierda'),
    (id: 'slideRightOut', label: 'Salir derecha'),
    (id: 'slideUpOut', label: 'Salir arriba'),
    (id: 'slideDownOut', label: 'Salir abajo'),
    (id: 'zoomOut', label: 'Zoom Out'),
    (id: 'popOut', label: 'Pop Out'),
    (id: 'bounceOut', label: 'Bounce Out'),
    (id: 'wipeLeftOut', label: 'Wipe izquierda'),
    (id: 'wipeRightOut', label: 'Wipe derecha'),
    (id: 'blurOut', label: 'Blur Out'),
    (id: 'rotateOut', label: 'Rotate Out'),
    (id: 'shrink', label: 'Shrink'),
    (id: 'scaleFadeOut', label: 'Scale + Fade'),
    (id: 'dissolve', label: 'Dissolve'),
  ];

  @override
  void initState() {
    super.initState();
    _syncSelectedClip();
  }

  @override
  void didUpdateWidget(covariant TextPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.clip?.id != widget.clip?.id) _syncSelectedClip();
  }

  void _syncSelectedClip() {
    final c = widget.clip;
    _editingClipId = c?.id;
    editController.text = c?.text ?? '';
  }

  @override
  void dispose() {
    controller.dispose();
    editController.dispose();
    scrollController.dispose();
    super.dispose();
  }

  Map<String, dynamic> _newStyle() => <String, dynamic>{
        'template': template,
        'animation': 'static',
        'fontFamily': fontFamily,
        'fontSize': fontSize,
        'color': '#FFFFFF',
        'background': '#00000000',
        'align': 'center',
        'entryAnimation': entryAnimation,
        'loopAnimation': loopAnimation,
        'exitAnimation': exitAnimation,
        'entryDurationMs': 450,
        'exitDurationMs': 450,
      };

  void _edit(VoidCallback mutate) {
    final c = widget.clip;
    if (c == null || c.kind != 'text') return;
    widget.onEditStarted?.call();
    mutate();
    widget.onChanged();
    widget.onEditEnded?.call();
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final selected = widget.clip?.kind == 'text' ? widget.clip : null;
    return Scrollbar(
      controller: scrollController,
      thumbVisibility: true,
      child: ListView(
        controller: scrollController,
        padding: const EdgeInsets.all(14),
        children: [
          const Text('Texto y títulos', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
          if (selected != null) ...[
            const SizedBox(height: 12),
            const Text('Editar texto seleccionado', style: TextStyle(fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            TextField(
              controller: editController,
              minLines: 1,
              maxLines: 4,
              decoration: const InputDecoration(border: OutlineInputBorder()),
              onChanged: (value) {
                if (_editingClipId != selected.id) return;
                _edit(() => selected.text = value);
              },
            ),
            const SizedBox(height: 10),
            _fontSelector(selected.style['fontFamily'] as String? ?? 'Roboto', (v) => _edit(() => selected.style['fontFamily'] = v)),
            _fontSizeSlider((selected.style['fontSize'] as num?)?.toDouble() ?? 48, (v) => _edit(() => selected.style['fontSize'] = v)),
            const SizedBox(height: 10),
            const Text('Entrada', style: TextStyle(fontWeight: FontWeight.w700)),
            _animationWrap(entries, selected.style['entryAnimation'] as String? ?? _legacyEntry(selected.style['animation'] as String?), (id) => _edit(() => selected.style['entryAnimation'] = id)),
            const SizedBox(height: 10),
            const Text('Bucle', style: TextStyle(fontWeight: FontWeight.w700)),
            _animationWrapWithNone(loops, selected.style['loopAnimation'] as String? ?? _legacyLoop(selected.style['animation'] as String?), (id) => _edit(() => selected.style['loopAnimation'] = id)),
            const SizedBox(height: 10),
            const Text('Salida', style: TextStyle(fontWeight: FontWeight.w700)),
            _animationWrap(exits, selected.style['exitAnimation'] as String? ?? 'fadeOut', (id) => _edit(() => selected.style['exitAnimation'] = id)),
            const Divider(height: 30),
          ],
          const Text('Añadir nuevo texto', style: TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          TextField(controller: controller, minLines: 2, maxLines: 5, decoration: const InputDecoration(labelText: 'Escribe tu texto', border: OutlineInputBorder())),
          const SizedBox(height: 14),
          const Text('Plantilla', style: TextStyle(fontWeight: FontWeight.w700)),
          Wrap(spacing: 8, runSpacing: 8, children: [
            _choice('clean', 'Limpio'), _choice('box', 'Caja'), _choice('lowerThird', 'Cintillo'),
            _choice('subtitle', 'Subtítulo'), _choice('outline', 'Contorno'), _choice('badge', 'Etiqueta'), _choice('quote', 'Cita'),
          ]),
          const SizedBox(height: 14),
          _fontSelector(fontFamily, (v) => setState(() => fontFamily = v)),
          _fontSizeSlider(fontSize, (v) => setState(() => fontSize = v)),
          const SizedBox(height: 14),
          const Text('Animación de entrada', style: TextStyle(fontWeight: FontWeight.w700)),
          _animationWrap(entries, entryAnimation, (id) => setState(() => entryAnimation = id)),
          const SizedBox(height: 14),
          const Text('Animación en bucle', style: TextStyle(fontWeight: FontWeight.w700)),
          _animationWrapWithNone(loops, loopAnimation, (id) => setState(() => loopAnimation = id)),
          const SizedBox(height: 14),
          const Text('Animación de salida', style: TextStyle(fontWeight: FontWeight.w700)),
          _animationWrap(exits, exitAnimation, (id) => setState(() => exitAnimation = id)),
          const SizedBox(height: 14),
          FilledButton.icon(
            onPressed: () {
              final text = controller.text.trim();
              if (text.isEmpty) return;
              widget.onAdd(text, _newStyle());
            },
            icon: const Icon(Icons.add),
            label: const Text('Añadir al cabezal'),
          ),
          const SizedBox(height: 10),
          const Text('Entrada, bucle y salida se guardan por separado y pueden combinarse en un mismo texto.'),
        ],
      ),
    );
  }

  String _legacyEntry(String? id) => switch (id) {
        'slideUp' => 'slideUpIn', 'slideDown' => 'slideDownIn', 'slideLeft' => 'slideLeftIn',
        'slideRight' => 'slideRightIn', 'zoom' => 'zoomIn', _ => 'fadeIn',
      };
  String _legacyLoop(String? id) => id == 'pulse' ? 'pulse' : 'none';

  Widget _fontSelector(String value, ValueChanged<String> onChanged) {
    final valid = fonts.contains(value) ? value : fonts.first;
    return DropdownButtonFormField<String>(
      initialValue: valid,
      isExpanded: true,
      decoration: const InputDecoration(labelText: 'Fuente', border: OutlineInputBorder()),
      items: [for (final font in fonts) DropdownMenuItem(value: font, child: Text(font, style: TextStyle(fontFamily: font)))],
      onChanged: (v) { if (v != null) onChanged(v); },
    );
  }

  Widget _fontSizeSlider(double value, ValueChanged<double> onChanged) => Padding(
        padding: const EdgeInsets.only(top: 10),
        child: Column(children: [
          Row(children: [const Expanded(child: Text('Tamaño')), Text('${value.round()} px')]),
          Slider(value: value.clamp(12, 160).toDouble(), min: 12, max: 160, onChanged: onChanged),
        ]),
      );

  Widget _choice(String id, String label) => ChoiceChip(label: Text(label), selected: template == id, onSelected: (_) => setState(() => template = id));

  Widget _animationWrap(List<({String id, String label})> options, String selected, ValueChanged<String> onChanged) => Wrap(
        spacing: 6, runSpacing: 6,
        children: [for (final option in options) ChoiceChip(label: Text(option.label), selected: selected == option.id, onSelected: (_) => onChanged(option.id))],
      );

  Widget _animationWrapWithNone(List<({String id, String label})> options, String selected, ValueChanged<String> onChanged) => Wrap(
        spacing: 6, runSpacing: 6,
        children: [
          ChoiceChip(label: const Text('Ninguna'), selected: selected == 'none', onSelected: (_) => onChanged('none')),
          for (final option in options) ChoiceChip(label: Text(option.label), selected: selected == option.id, onSelected: (_) => onChanged(option.id)),
        ],
      );
}
