from pathlib import Path
import sys

root = Path(sys.argv[1] if len(sys.argv) > 1 else 'videdit_project')
screen = root / 'lib/features/editor/editor_screen.dart'
s = screen.read_text(encoding='utf-8').replace('\r\n','\n')

def once(before, after):
    global s
    if before not in s:
        raise SystemExit('Required export UI marker missing: '+before[:100])
    s=s.replace(before,after,1)

once("import 'package:flutter/material.dart';", "import 'package:file_picker/file_picker.dart';\nimport 'package:flutter/material.dart';")
once("    var quality = project.exportSettings.quality;\n", "    var quality = project.exportSettings.quality;\n    var outputName = 'Orbita_Videdit_' + DateTime.now().millisecondsSinceEpoch.toString();\n")
once("                const Text('MP4 · H.264 + AAC. La exportación usa originales aunque la vista previa use proxies.'),", """                TextFormField(
                  initialValue: outputName,
                  decoration: const InputDecoration(
                    labelText: 'Nombre del archivo',
                    helperText: 'Se guardará como video MP4',
                    border: OutlineInputBorder(),
                  ),
                  onChanged: (v) => outputName = v,
                ),
                const SizedBox(height: 10),
                const Text('Windows: podrás elegir carpeta y nombre en el explorador. Android: se abrirá el selector de archivos al terminar de renderizar; si cancelas, se guardará en Películas / Orbita Videdit / Exports.'),
                const SizedBox(height: 10),
                const Text('MP4 · H.264 + AAC. La exportación usa originales aunque la vista previa use proxies.'),""")
once("    if (exportAction == 'export') await _exportVideo();", "    if (exportAction == 'export') await _exportVideo(requestedName: outputName);")
start=s.index("  Future<void> _exportVideo() async {")
end=s.index("  Future<void> _setVisual(",start)
new_method = r"""  Future<Directory> _ensureExportDirectory() async {
    // Never place the only exported copy in temporary/cache storage.
    final Directory base;
    if (Platform.isWindows) {
      base = (await getDownloadsDirectory()) ?? await getApplicationDocumentsDirectory();
    } else {
      base = await getApplicationDocumentsDirectory();
    }
    final directory = Directory(base.path + Platform.pathSeparator +
        'Orbita Videdit' + Platform.pathSeparator + 'Exports');
    await directory.create(recursive: true);
    return directory;
  }

  Future<void> _exportVideo({String? requestedName}) async {
    if (busy) return;
    final safeBase = (requestedName ?? 'Orbita_Videdit_' +
      DateTime.now().millisecondsSinceEpoch.toString())
        .trim()
        .replaceAll(RegExp(r'[\\/:*?"<>|]'), '_')
        .replaceAll(RegExp(r'[. ]+$'), '');
    if (safeBase.isEmpty) {
      if (mounted) setState(() => status = 'Escribe un nombre válido para exportar.');
      return;
    }
    final fileName = safeBase.toLowerCase().endsWith('.mp4')
        ? safeBase : safeBase + '.mp4';
    String? destination;
    try {
      final directory = await _ensureExportDirectory();
      if (Platform.isWindows) {
        // file_picker 13+ uses static directory selection. It cannot choose
        // an output path via saveFile without first supplying all MP4 bytes.
        // Pick a real folder first, then render the video there directly.
        final chosenFolder = await FilePicker.getDirectoryPath(
          dialogTitle: 'Selecciona la carpeta donde guardar el MP4',
          initialDirectory: directory.path,
        );
        if (chosenFolder == null || chosenFolder.isEmpty) {
          if (mounted) setState(() => status = 'Exportación cancelada antes de comenzar.');
          return;
        }
        destination = chosenFolder + Platform.pathSeparator + fileName;
      } else {
        // Android renders to persistent app documents, not a temporary folder.
        destination = directory.path + Platform.pathSeparator + fileName;
      }
    } catch (e) {
      if (mounted) setState(() => status = 'No se pudo seleccionar la carpeta: ' + e.toString());
      return;
    }
    final outputPath = destination;
    setState(() { busy = true; status = 'Preparando exportación…'; });
    try {
      final output = File(outputPath);
      await output.parent.create(recursive: true);
      // Render to a distinct file first so an old output cannot be mistaken
      // for a successful new render.
      if (await output.exists()) await output.delete();
      await renderer.renderPrimaryVideoTrack(
        project, outputPath,
        onProgress: (value) {
          // FFmpeg may report 100% before closing the MP4 and finalizing the
          // moov atom; only report 100% after the file and destination exist.
          if (mounted) setState(() => status =
            'Exportando… ' + (value * 99).clamp(0,99).round().toString() + '%');
        },
      ).timeout(const Duration(minutes: 45));
      if (!await output.exists() || await output.length() < 1024) {
        throw StateError('El motor terminó sin crear un MP4 válido. No se guardó ningún video.');
      }

      String savedAt = outputPath;
      if (Platform.isAndroid) {
        if (mounted) setState(() => status = 'Video renderizado · selecciona dónde guardarlo');
        String? chosen;
        try {
          chosen = await _mediaStoreChannel.invokeMethod<String>('saveVideoAs', {
            'sourcePath': outputPath, 'displayName': fileName,
          });
        } on MissingPluginException {
          // Older native host: keep default public Gallery export.
        }
        if (chosen != null && chosen.isNotEmpty) {
          savedAt = 'Ubicación elegida en Archivos · ' + fileName;
        } else {
          final uri = await _mediaStoreChannel.invokeMethod<String>('publishVideo', {
            'sourcePath': outputPath, 'displayName': fileName,
          });
          if (uri == null || uri.isEmpty) {
            throw StateError('Android no confirmó la publicación del MP4 en la galería.');
          }
          savedAt = 'Películas / Orbita Videdit / Exports / ' + fileName;
        }
      }
      if (!mounted) return;
      setState(() => status = 'Exportación completada al 100% · ' + savedAt);
      await showDialog<void>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Video guardado correctamente'),
          content: SelectableText('Nombre: ' + fileName + '\nUbicación: ' + savedAt),
          actions: [
            TextButton(
              onPressed: () {
                Clipboard.setData(ClipboardData(text: savedAt));
                Navigator.pop(dialogContext);
              },
              child: const Text('Copiar ubicación'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Aceptar'),
            ),
          ],
        ),
      );
    } catch (e) {
      if (!mounted) return;
      final message = 'Error: el video NO se guardó. ' + e.toString();
      setState(() => status = message);
      await showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('No se pudo exportar'),
          content: SelectableText(message),
          actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cerrar'))],
        ),
      );
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

"""
s=s[:start]+new_method+s[end:]
screen.write_text(s,encoding='utf-8')
print('Export destination picker, filename, persistent folder, final check and clear result applied.')
