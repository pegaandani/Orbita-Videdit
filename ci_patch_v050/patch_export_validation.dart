import 'dart:io';

void main(List<String> args) {
  if (args.isEmpty) {
    stderr.writeln('Usage: dart patch_export_validation.dart <videdit_project>');
    exit(2);
  }
  final sep = Platform.pathSeparator;
  final file = File(args.first + sep + 'lib' + sep + 'core' + sep +
      'services' + sep + 'timeline_render_service.dart');
  var source = file.readAsStringSync().replaceAll('\r\n', '\n');

  const old = '''    if (Platform.isWindows) {
      await _runBundledWindowsFfmpeg(
        commandArgs,
        durationMs: durationMs,
        onProgress: onProgress,
      );
    } else {
''';
  const updated = r'''    // Use the same process-based FFmpeg backend in desktop CI. On Windows it
    // always uses the ffmpeg.exe bundled in the application's release folder.
    final nativeBackend = Platform.isWindows ||
        (Platform.environment['ORBITA_FFMPEG_PATH']?.isNotEmpty ?? false);
    if (nativeBackend) {
      // Avoid the Windows 32K command-line limit when multiple clips, effects,
      // title animations and transition expressions build a large graph.
      final sep = Platform.pathSeparator;
      final script = File(Directory.systemTemp.path + sep +
          'orbita_videdit_' + DateTime.now().microsecondsSinceEpoch.toString() + '.ffgraph');
      await script.writeAsString(filters.join(';'), flush: true);
      final graphIndex = commandArgs.indexOf('-filter_complex');
      if (graphIndex < 0) throw StateError('No se encontró el grafo de exportación.');
      commandArgs.replaceRange(
        graphIndex, graphIndex + 2, <String>['-filter_complex_script', script.path],
      );
      try {
        await _runBundledWindowsFfmpeg(
          commandArgs,
          durationMs: durationMs,
          onProgress: onProgress,
        );
      } finally {
        if (await script.exists()) await script.delete();
      }
      final rendered = File(outputPath);
      if (!await rendered.exists() || await rendered.length() < 1024) {
        throw StateError('La exportación terminó sin crear un video MP4 válido: ' + outputPath);
      }
    } else {
''';
  if (!source.contains(old)) {
    stderr.writeln('Cannot find desktop FFmpeg backend patch point.');
    exit(3);
  }
  source = source.replaceFirst(old, updated);
  file.writeAsStringSync(source);
  stdout.writeln('FFmpeg exported via native script file, with output integrity check.');
}
