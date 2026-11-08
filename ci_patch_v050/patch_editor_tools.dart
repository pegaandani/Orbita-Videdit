import 'dart:io';

void main(List<String> args) {
  if (args.isEmpty) {
    stderr.writeln('Usage: dart patch_editor_tools.dart <videdit_project>');
    exit(2);
  }
  final file = File('${args.first}${Platform.pathSeparator}lib${Platform.pathSeparator}features${Platform.pathSeparator}editor${Platform.pathSeparator}editor_screen.dart');
  var source = file.readAsStringSync().replaceAll('\r\n', '\n');

  const oldTools = '''  static const _tools = <({IconData icon, String label})>[\n    (icon: Icons.video_library_outlined, label: 'Medios'),\n    (icon: Icons.title, label: 'Texto'),\n    (icon: Icons.emoji_emotions_outlined, label: 'Stickers'),\n    (icon: Icons.tune, label: 'Filtros'),\n    (icon: Icons.auto_fix_high, label: 'Efectos'),\n    (icon: Icons.compare_arrows, label: 'Transiciones'),\n    (icon: Icons.aspect_ratio, label: 'Formato'),\n    (icon: Icons.cloud_download_outlined, label: 'Recursos'),\n    (icon: Icons.auto_awesome, label: 'IA'),\n    (icon: Icons.palette_outlined, label: 'Apariencia'),\n  ];\n''';
  const newTools = '''  static const _tools = <({IconData icon, String label})>[\n    (icon: Icons.video_library_outlined, label: 'Medios'),\n    (icon: Icons.audiotrack, label: 'Audio'),\n    (icon: Icons.title, label: 'Texto'),\n    (icon: Icons.emoji_emotions_outlined, label: 'Stickers'),\n    (icon: Icons.tune, label: 'Filtros'),\n    (icon: Icons.auto_fix_high, label: 'Efectos'),\n    (icon: Icons.compare_arrows, label: 'Transiciones'),\n    (icon: Icons.aspect_ratio, label: 'Formato'),\n    (icon: Icons.cloud_download_outlined, label: 'Recursos'),\n    (icon: Icons.auto_awesome, label: 'IA'),\n    (icon: Icons.palette_outlined, label: 'Apariencia'),\n  ];\n''';

  const oldPanel = '''  Widget _toolPanel() {\n    switch (toolIndex) {\n      case 1:\n        return TextPanel(onAdd: _addText);\n      case 2:\n        return _stickersPanel();\n      case 3:\n        return FilterPanel(clip: selectedClip, onChanged: () {\n          setState(() {});\n          _markChanged('Filtro actualizado');\n        });\n      case 4:\n        return EffectsPanel(\n          clip: selectedClip,\n          playheadMs: playheadMs,\n          onRemoveBackground: _removeBackgroundSelected,\n          onEditStarted: _pushUndo,\n          onChanged: () => setState(() {}),\n          onEditEnded: () => _markChanged('Efecto actualizado'),\n        );\n      case 5:\n        return TransitionsPanel(\n          clip: selectedClip,\n          onEditStarted: _pushUndo,\n          onChanged: () => setState(() {}),\n          onEditEnded: () => _markChanged('Transición actualizada'),\n        );\n      case 6:\n        return FormatPanel(\n          value: project.canvas,\n          onChanged: (p) {\n            _pushUndo();\n            setState(() {\n              project.canvas = p;\n              project.exportSettings\n                ..width = p.width\n                ..height = p.height\n                ..fps = p.fps;\n            });\n            _markChanged('Formato actualizado');\n          },\n        );\n      case 7:\n        return ResourcesPanel(onImport: () => _import());\n      case 8:\n        return AiPanel(project: project, area: 'editor', selectedClip: selectedClip, playheadMs: playheadMs);\n      case 9:\n        return AppearancePanel(value: visual, onChanged: _setVisual);\n      default:\n        return _mediaPanel();\n    }\n  }\n''';

  const newPanel = '''  Widget _toolPanel() {\n    switch (toolIndex) {\n      case 1:\n        return _audioPanel();\n      case 2:\n        return TextPanel(onAdd: _addText);\n      case 3:\n        return _stickersPanel();\n      case 4:\n        return FilterPanel(clip: selectedClip, onChanged: () {\n          setState(() {});\n          _markChanged('Filtro actualizado');\n        });\n      case 5:\n        return EffectsPanel(\n          clip: selectedClip,\n          playheadMs: playheadMs,\n          onRemoveBackground: _removeBackgroundSelected,\n          onEditStarted: _pushUndo,\n          onChanged: () => setState(() {}),\n          onEditEnded: () => _markChanged('Efecto actualizado'),\n        );\n      case 6:\n        return TransitionsPanel(\n          clip: selectedClip,\n          onEditStarted: _pushUndo,\n          onChanged: () => setState(() {}),\n          onEditEnded: () => _markChanged('Transición actualizada'),\n        );\n      case 7:\n        return FormatPanel(\n          value: project.canvas,\n          onChanged: (p) {\n            _pushUndo();\n            setState(() {\n              project.canvas = p;\n              project.exportSettings\n                ..width = p.width\n                ..height = p.height\n                ..fps = p.fps;\n            });\n            _markChanged('Formato actualizado');\n          },\n        );\n      case 8:\n        return ResourcesPanel(onImport: () => _import());\n      case 9:\n        return AiPanel(project: project, area: 'editor', selectedClip: selectedClip, playheadMs: playheadMs);\n      case 10:\n        return AppearancePanel(value: visual, onChanged: _setVisual);\n      default:\n        return _mediaPanel();\n    }\n  }\n''';

  void replaceRequired(String from, String to, String label) {
    if (!source.contains(from)) {
      stderr.writeln('Required editor block not found: $label');
      exit(3);
    }
    source = source.replaceFirst(from, to);
  }

  replaceRequired(oldTools, newTools, 'tools list');
  replaceRequired(oldPanel, newPanel, 'tool panel');
  source = source.replaceAll("case 'filters': setState(() => toolIndex = 3);", "case 'filters': setState(() => toolIndex = 4);");
  source = source.replaceAll("case 'effects': setState(() => toolIndex = 4);", "case 'effects': setState(() => toolIndex = 5);");
  source = source.replaceAll('setState(() => toolIndex = 6);', 'setState(() => toolIndex = 7);');

  file.writeAsStringSync(source);
  stdout.writeln('Audio workspace exposed and editor tool indices aligned.');
}
