from pathlib import Path
import sys
root = Path(sys.argv[1] if len(sys.argv) > 1 else "videdit_project")
screen = root / "lib/features/editor/editor_screen.dart"
render = root / "lib/core/services/timeline_render_service.dart"
activities = list((root/"android").rglob("MainActivity.kt"))
if len(activities) != 1:
    raise RuntimeError("Cannot identify Android MainActivity")
android = activities[0]

def replace(path, before, after):
    s = path.read_text(encoding="utf-8")
    if s.count(before) != 1:
        raise RuntimeError(f"Android export marker in {path.name}: expected 1 got {s.count(before)}: {before[:100]}")
    path.write_text(s.replace(before,after,1), encoding="utf-8")

# Choose file destination BEFORE rendering, so the save sheet works even when
# rendering eventually fails. Render into persistent app documents, then copy.
replace(screen,
    "    String? destination;\n    try {\n      final directory = await _ensureExportDirectory();",
    """    String? destination;
    String? androidDestinationUri;
    try {
      final directory = await _ensureExportDirectory();""")
replace(screen,
    """      } else {
        // Android renders to persistent app documents, not a temporary folder.
        destination = directory.path + Platform.pathSeparator + fileName;
      }""",
    """      } else if (Platform.isAndroid) {
        androidDestinationUri =
            await _mediaStoreChannel.invokeMethod<String>(
              'chooseVideoDestination',
              {'displayName': fileName},
            );
        if (androidDestinationUri == null || androidDestinationUri.isEmpty) {
          if (mounted) setState(() => status = 'Exportación cancelada.');
          return;
        }
        destination = directory.path + Platform.pathSeparator + fileName;
      } else {
        destination = directory.path + Platform.pathSeparator + fileName;
      }""")
p=screen
s=p.read_text(encoding="utf-8")
start=s.index("      if (Platform.isAndroid) {\n        if (mounted) setState(() => status = 'Video renderizado")
end=s.index("      if (!mounted) return;",start)
replacement="""      if (Platform.isAndroid) {
        if (mounted) setState(() => status = 'Guardando MP4 en la ubicación elegida…');
        final savedUri = await _mediaStoreChannel.invokeMethod<String>(
          'writeVideoToUri',
          {'sourcePath': outputPath, 'destinationUri': androidDestinationUri},
        );
        if (savedUri == null || savedUri.isEmpty) {
          throw StateError('Android no confirmó la copia del video al destino.');
        }
        savedAt = 'Archivo elegido en Android: ' + fileName;
      }
"""
s=s[:start]+replacement+s[end:]
before="      final message = 'Error: el video NO se guardó. ' + e.toString();"
after="""      // Avoid leaving a zero-byte file in the user's chosen folder if FFmpeg
      // never generated a valid MP4.
      if (Platform.isAndroid && androidDestinationUri != null) {
        try {
          await _mediaStoreChannel.invokeMethod('deleteVideoDestination',
            {'destinationUri': androidDestinationUri});
        } catch (_) {}
      }
      final message = 'Error: el video NO se guardó. ' + e.toString();"""
if s.count(before)!=1: raise RuntimeError("Error dialogue anchor missing")
p.write_text(s.replace(before,after,1),encoding="utf-8")

# Show *last* FFmpeg errors, not the enormous FFmpeg version/configuration header.
replace(render,
    "      '-y',\n      ...args,\n      '-filter_complex_threads', '0',",
    "      '-y',\n      '-hide_banner',\n      '-loglevel', 'warning',\n      ...args,\n      '-filter_complex_threads', '0',")
replace(render,
    """        final output = await session.getOutput();
        throw StateError('Orbita Videdit no pudo completar la exportación. Detalle: $output');""",
    """        final output = (await session.getAllLogsAsString()) ??
            (await session.getOutput()) ?? '';
        final lines = output.trim().split(RegExp(r'[\\r\\n]+'));
        final diagnostics = lines.length > 22
            ? lines.sublist(lines.length - 22).join('\\n')
            : output.trim();
        final tail = diagnostics.length > 3200
            ? diagnostics.substring(diagnostics.length - 3200)
            : diagnostics;
        throw StateError(
          'FFmpeg no pudo generar el MP4 (código: $rc). '
          'Últimos mensajes: $tail',
        );""")

# Extend native Android DocumentProvider bridge with early picker + streaming.
p=android
s=p.read_text(encoding="utf-8")
def sub(a,b):
    global s
    if s.count(a)!=1:
        raise RuntimeError(f"MainActivity marker missing or duplicated ({s.count(a)}): {a[:90]}")
    s=s.replace(a,b,1)
sub("    private var pendingSource: File? = null",
    "    private var pendingSource: File? = null\n    private var pendingChooseOnly: Boolean = false")
sub("""                val sourcePath = call.argument<String>("sourcePath") ?: error("sourcePath requerido")
                val displayName = call.argument<String>("displayName") ?: File(sourcePath).name
                val source = File(sourcePath)
                if (!source.exists() || source.length() < 1024L) {
                    error("El archivo MP4 no existe o está vacío.")
                }""",
    """                val sourcePath = call.argument<String>("sourcePath")
                val displayName = call.argument<String>("displayName")
                    ?: sourcePath?.let { File(it).name } ?: "Orbita_Videdit.mp4"
                val source = sourcePath?.let { File(it) }
                if (call.method != "chooseVideoDestination" &&
                    call.method != "deleteVideoDestination" &&
                    (source == null || !source.exists() || source.length() < 1024L)) {
                    error("El archivo MP4 no existe o está vacío.")
                }""")
sub("val uri = publishVideo(source, displayName)",
    "val uri = publishVideo(source ?: error(\"sourcePath requerido\"), displayName)")
sub('                    "saveVideoAs" -> {',
    '                    "saveVideoAs", "chooseVideoDestination" -> {')
sub("""                            pendingSave = result
                            pendingSource = source
                            val intent = Intent(Intent.ACTION_CREATE_DOCUMENT).apply {""",
    """                            pendingSave = result
                            pendingChooseOnly = call.method == "chooseVideoDestination"
                            pendingSource = if (pendingChooseOnly) null else source
                            val intent = Intent(Intent.ACTION_CREATE_DOCUMENT).apply {""")
sub("""                                pendingSave = null
                                pendingSource = null
                                result.error("picker_failed", e.message, null)""",
    """                                pendingSave = null
                                pendingSource = null
                                pendingChooseOnly = false
                                result.error("picker_failed", e.message, null)""")
sub("""                    else -> result.notImplemented()""",
    """                    "writeVideoToUri" -> {
                        val rendered = source ?: error("sourcePath requerido")
                        val destination = Uri.parse(
                            call.argument<String>("destinationUri")
                                ?: error("destinationUri requerido")
                        )
                        Thread {
                            try {
                                contentResolver.openOutputStream(destination, "w")?.use { stream ->
                                    FileInputStream(rendered).use { input ->
                                        input.copyTo(stream, 1024 * 1024)
                                    }
                                } ?: error("No se pudo abrir el archivo de destino")
                                runOnUiThread { result.success(destination.toString()) }
                            } catch (e: Exception) {
                                runOnUiThread { result.error("save_failed", e.message, null) }
                            }
                        }.start()
                    }
                    "deleteVideoDestination" -> {
                        val destination = Uri.parse(
                            call.argument<String>("destinationUri")
                                ?: error("destinationUri requerido")
                        )
                        try {
                            contentResolver.delete(destination, null, null)
                            result.success(true)
                        } catch (_: Exception) {
                            result.success(false)
                        }
                    }
                    else -> result.notImplemented()""")
sub("""        val source = pendingSource
        pendingSave = null
        pendingSource = null
        val uri: Uri?""",
    """        val source = pendingSource
        val chooseOnly = pendingChooseOnly
        pendingSave = null
        pendingSource = null
        pendingChooseOnly = false
        val uri: Uri?""")
sub("""        if (source == null || !source.exists()) {
            pending.error("source_missing", "El MP4 renderizado ya no existe.", null)
            return
        }""",
    """        if (chooseOnly) {
            pending.success(uri.toString())
            return
        }
        if (source == null || !source.exists()) {
            pending.error("source_missing", "El MP4 renderizado ya no existe.", null)
            return
        }""")
p.write_text(s,encoding="utf-8")
print("Android export: early SAF save picker, verified streaming, cleanup on failure, useful FFmpeg tail diagnostics.")
