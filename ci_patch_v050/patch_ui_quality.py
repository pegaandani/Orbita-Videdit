from pathlib import Path
import sys

root=Path(sys.argv[1] if len(sys.argv)>1 else 'videdit_project')
lib=root/'lib'
model=lib/'core/models/visual_settings.dart'
store=lib/'core/services/visual_settings_service.dart'
appearance=lib/'features/editor/widgets/appearance_panel.dart'
screen=lib/'features/editor/editor_screen.dart'
main=lib/'main.dart'

def edit(path,before,after):
    content=path.read_text(encoding='utf8')
    if content.count(before)!=1:
        raise SystemExit('Expected exact UI marker in '+str(path)+': '+before[:110]+' (found '+str(content.count(before))+')')
    path.write_text(content.replace(before,after,1),encoding='utf8')

edit(model,"    this.blur = 14,", "    this.blur = 14,\n    this.backgroundImagePath,")
edit(model,"  final double blur;", "  final double blur;\n  final String? backgroundImagePath;")
edit(model,"    double? blur,\n", "    double? blur,\n    String? backgroundImagePath,\n    bool clearBackgroundImage = false,\n")
edit(model,"        blur: blur ?? this.blur,", "        blur: blur ?? this.blur,\n        backgroundImagePath: clearBackgroundImage ? null : (backgroundImagePath ?? this.backgroundImagePath),")

prefix = chr(36)+'{_p}'
edit(store,"      blur: prefs.getDouble('"+prefix+"blur') ?? 14,", "      blur: prefs.getDouble('"+prefix+"blur') ?? 14,\n      backgroundImagePath: prefs.getString('"+prefix+"backgroundImage'),")
edit(store,"    await prefs.setDouble('"+prefix+"blur', value.blur);", "    await prefs.setDouble('"+prefix+"blur', value.blur);\n    if (value.backgroundImagePath == null) {\n      await prefs.remove('"+prefix+"backgroundImage');\n    } else {\n      await prefs.setString('"+prefix+"backgroundImage', value.backgroundImagePath!);\n    }")

edit(appearance,"import 'package:flutter/material.dart';", """import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';""")
edit(appearance,"          const SizedBox(height: 16),\n          _layer('Capa 1 · Fondo general',", """          const SizedBox(height: 14),
          const Text('Imagen propia en el fondo más profundo'),
          const SizedBox(height: 8),
          Wrap(spacing: 8, runSpacing: 8, children: [
            OutlinedButton.icon(
              onPressed: _selectBackgroundImage,
              icon: const Icon(Icons.image_outlined),
              label: const Text('Elegir imagen propia'),
            ),
            if (value.backgroundImagePath != null)
              TextButton.icon(
                onPressed: () => _manual(value.copyWith(clearBackgroundImage: true)),
                icon: const Icon(Icons.delete_outline),
                label: const Text('Quitar imagen'),
              ),
          ]),
          if (value.backgroundImagePath != null) ...[
            const SizedBox(height: 8),
            SizedBox(
              height: 84,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: Image.file(File(value.backgroundImagePath!), fit: BoxFit.cover,
                  errorBuilder: (context, error, stack) => const Text('La imagen anterior no está disponible')),
              ),
            ),
          ],
          const SizedBox(height: 16),
          _layer('Capa 1 · Fondo general',""")
edit(appearance,"  void _manual(OrbitaVisualSettings next) => onChanged(next.copyWith(autoSpecialDates: false));", """  Future<void> _selectBackgroundImage() async {
    try {
      final selected = await FilePicker.pickFile(type: FileType.image);
      if (selected == null) return;
      final data = await selected.readAsBytes();
      final support = await getApplicationSupportDirectory();
      await support.create(recursive: true);
      final ext = selected.name.toLowerCase().endsWith('.png') ? '.png' : '.jpg';
      final target = File(support.path + Platform.pathSeparator +
        'orbita_background_' + DateTime.now().microsecondsSinceEpoch.toString() + ext);
      await target.writeAsBytes(data, flush: true);
      _manual(value.copyWith(backgroundImagePath: target.path));
    } catch (error) {
      debugPrint('No se pudo seleccionar el fondo: ' + error.toString());
    }
  }

  void _manual(OrbitaVisualSettings next) => onChanged(next.copyWith(autoSpecialDates: false));""")
edit(screen,"          Positioned.fill(child: Container(color: _v.layer1)),", """          Positioned.fill(
            child: _v.backgroundImagePath == null
              ? Container(color: _v.layer1)
              : Image.file(
                  File(_v.backgroundImagePath!),
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stack) => Container(color: _v.layer1),
                ),
          ),""")
edit(screen,"  bool _previewPanelVisible = true;", "  bool _previewPanelVisible = true;\n  bool _previewExpanded = false;")
edit(screen,"          Positioned.fill(child: wide ? _wideLayout() : _compactLayout()),", "          Positioned.fill(child: _previewExpanded ? _previewPanel() : (wide ? _wideLayout() : _compactLayout())),")
edit(screen,"            IconButton(tooltip: 'Detener', onPressed: _stop, icon: const Icon(Icons.stop_rounded)),", """            IconButton(
              tooltip: _previewExpanded ? 'Salir de pantalla completa' : 'Pantalla completa del visor',
              onPressed: () => setState(() => _previewExpanded = !_previewExpanded),
              icon: Icon(_previewExpanded ? Icons.fullscreen_exit : Icons.fullscreen),
            ),
            IconButton(tooltip: 'Detener', onPressed: _stop, icon: const Icon(Icons.stop_rounded)),""")
edit(screen,"""          constraints: const BoxConstraints(minHeight: 48),
          color: _v.layer2.withValues(alpha: .92),""", """          constraints: const BoxConstraints(minHeight: 48),
          color: _v.layer2,""")
edit(screen,"                    return Draggable<MediaAsset>(", "                    return LongPressDraggable<MediaAsset>(")
edit(screen,"                          if (v == 'overlay') _addToTimeline(m, forceOverlay: true);", """                          if (v == 'overlay') _addToTimeline(m, forceOverlay: true);
                          if (v == 'remove') {
                            _pushUndo();
                            setState(() => project.media.removeWhere((item) => item.id == m.id));
                            _markChanged('Archivo quitado de la biblioteca (original conservado)');
                          }""")
edit(screen,"                          if (m.kind == 'video' || m.kind == 'image' || m.kind == 'gif') const PopupMenuItem(value: 'overlay', child: Text('Añadir como superposición')),", """                          if (m.kind == 'video' || m.kind == 'image' || m.kind == 'gif') const PopupMenuItem(value: 'overlay', child: Text('Añadir como superposición')),
                          const PopupMenuItem(value: 'remove', child: Text('Quitar de la biblioteca')),""")
edit(main,"import 'package:flutter/material.dart';", "import 'package:flutter/gestures.dart';\nimport 'package:flutter/material.dart';")
edit(main,"MaterialApp(", """MaterialApp(
      scrollBehavior: const MaterialScrollBehavior().copyWith(
        dragDevices: <PointerDeviceKind>{
          PointerDeviceKind.touch,
          PointerDeviceKind.stylus,
          PointerDeviceKind.mouse,
          PointerDeviceKind.trackpad,
        },
      ),""")
print('Custom background persisted, touch scrolling, preview expansion, readable toolbar, and non-destructive media removal patched.')
