import 'dart:io';

void replaceOne(File file, String before, String after, String description) {
  if (!file.existsSync()) {
    stderr.writeln('Missing source file for ' + description + ': ' + file.path);
    exit(3);
  }
  final source = file.readAsStringSync().replaceAll('\r\n', '\n');
  if (source.contains(after)) {
    stdout.writeln('Already patched: ' + description);
    return;
  }
  if (!source.contains(before)) {
    stderr.writeln('Cannot find source marker: ' + description);
    exit(4);
  }
  file.writeAsStringSync(source.replaceFirst(before, after));
  stdout.writeln('Fixed: ' + description);
}

void main(List<String> arguments) {
  if (arguments.isEmpty) {
    stderr.writeln('Usage: dart patch_control_fidelity.dart <videdit_project>');
    exit(2);
  }
  final sep = Platform.pathSeparator;
  final root = arguments.first + sep + 'lib' + sep;
  // New clips must own mutable maps and effect lists. The original model
  // used const defaults, which crash when filters, effects and transitions
  // attempt to add or remove entries.
  final clipModel = File(root + 'core' + sep + 'models' + sep + 'orbita_project.dart');
  replaceOne(
    clipModel,
    '''    this.style = const {},
    this.effects = const [],
    List<TransformKeyframe>? keyframes,
  }) : keyframes = keyframes ?? [];''',
    '''    Map<String, dynamic>? style,
    List<Map<String, dynamic>>? effects,
    List<TransformKeyframe>? keyframes,
  }) : style = Map<String, dynamic>.from(style ?? const <String, dynamic>{}),
       effects = (effects ?? const <Map<String, dynamic>>[])
           .map((effect) => Map<String, dynamic>.from(effect))
           .toList(),
       keyframes = keyframes ?? [];''',
    'each timeline clip receives editable, independently owned style and effects',
  );
  final manifest = File(arguments.first + sep + 'pubspec.yaml');
  replaceOne(manifest,
    '  file_picker: ^13.2.0\n',
    '  file_picker: ^13.2.0\n  archive: ^4.6.0\n',
    'ZIP resource pack reader dependency');

  replaceOne(manifest,
    '  android: "launcher_icon"\n',
    '  android: "ic_launcher"\n',
    'Launcher icon resource must match AndroidManifest');

  final preview = File(root + 'features' + sep + 'editor' + sep + 'editor_screen.dart');
  final texts = File(root + 'features' + sep + 'editor' + sep + 'widgets' + sep + 'text_panel.dart');

  final editorSource = preview.readAsStringSync().replaceAll('\r\n', '\n');
  const toolStart = '  static const _tools = <({IconData icon, String label})>[';
  final toolOffset = editorSource.indexOf(toolStart);
  if (toolOffset < 0) { stderr.writeln('Cannot locate toolbar'); exit(5); }
  final toolEnd = editorSource.indexOf('];', toolOffset);
  if (toolEnd < 0) { stderr.writeln('Cannot locate toolbar end'); exit(5); }
  var editorResult = editorSource;
  final toolBlock = editorResult.substring(toolOffset, toolEnd);
  if (!toolBlock.contains("label: 'Audio'")) {
    editorResult = editorResult.substring(0, toolEnd) +
        "    (icon: Icons.audiotrack, label: 'Audio'),\n  " +
        editorResult.substring(toolEnd);
  }
  const lastCase = "      case 9:\n        return AppearancePanel(value: visual, onChanged: _setVisual);\n";
  if (!editorResult.contains('case 10:')) {
    if (!editorResult.contains(lastCase)) { stderr.writeln('Cannot locate toolbar switch'); exit(5); }
    editorResult = editorResult.replaceFirst(
      lastCase, lastCase + "      case 10:\n        return _audioPanel();\n");
  }
  if (editorResult != editorSource) {
    preview.writeAsStringSync(editorResult);
    stdout.writeln('Audio tool exposed without reordering existing toolbar actions.');
  }

  final render = File(root + 'core' + sep + 'services' + sep + 'timeline_render_service.dart');
  final resources = File(root + 'features' + sep + 'editor' + sep + 'widgets' + sep + 'resources_panel.dart');
  replaceOne(
    resources,
    'Abre una biblioteca externa, descarga el recurso y luego impórtalo directamente a Órbita. Revisa siempre la licencia específica del archivo.',
    'Descarga videos, audio, imágenes, GIF o paquetes ZIP de las bibliotecas gratuitas. Luego pulsa Importar para instalarlos en tu biblioteca de Órbita y utilizarlos en la línea de tiempo. Comprueba la licencia de cada recurso.',
    'resource catalogue explains actual installation path',
  );
  replaceOne(
    resources,
    'Importar recurso descargado',
    'Importar recursos o instalar ZIP',
    'resource pack installation button',
  );


  // The Resources catalog installs local copies, not fragile references
  // to downloaded files that can vanish when Downloads is cleaned.
  replaceOne(
    preview,
    '  Future<void> _import({String? preferredKind}) async {',
    '  Future<void> _import({String? preferredKind, bool installResources = false}) async {',
    'resource installation mode in editor import flow',
  );
  replaceOne(
    preview,
    'final items = await importer.pickAndProbe(preferredKind: preferredKind);',
    'final items = await importer.pickAndProbe(preferredKind: preferredKind, installResources: installResources);',
    'pass persistent stock installation flag to media importer',
  );
  replaceOne(
    preview,
    'return ResourcesPanel(onImport: () => _import());',
    'return ResourcesPanel(onImport: () => _import(installResources: true));',
    'resource panel imports media into permanent library storage',
  );

  replaceOne(
    preview,
    'Colors.black.withValues(alpha: (0.16 + 2.0 / strength).clamp(.18, .72).toDouble()),',
    'Colors.black.withValues(alpha: (0.12 + (strength - 2.0) * .055).clamp(.12, .68).toDouble()),',
    'vignette preview intensity must increase with selected strength',
  );

  replaceOne(
    texts,
    r'''    return DropdownButtonFormField<String>(
      initialValue: valid,
''',
    r'''    return DropdownButtonFormField<String>(
      key: ValueKey<String>('font-' + (widget.clip?.id ?? 'new') + '-' + valid),
      initialValue: valid,
''',
    'text font selector must refresh when selecting a different text clip',
  );

  replaceOne(
    render,
    r'''      } else if (type == 'cameraShake') {
        out.add("rotate='0.010*sin(18*t)':fillcolor=black@0");
''',
    r'''      } else if (type == 'cameraShake') {
        final amount = ((effect['amount'] as num?)?.toDouble() ?? 1.0).clamp(.2, 3.0).toDouble();
        out.add("rotate='" + _n(.010 * amount) + "*sin(18*t)':fillcolor=black@0");
''',
    'export camera shake must respect switch intensity',
  );
  stdout.writeln('Orbita Videdit control fidelity patch completed.');
}
