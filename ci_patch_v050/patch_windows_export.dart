import 'dart:io';

void main(List<String> args) {
  if (args.isEmpty) {
    stderr.writeln('Usage: dart patch_windows_export.dart <videdit_project>');
    exit(2);
  }

  final sep = Platform.pathSeparator;
  final file = File('${args.first}${sep}lib${sep}core${sep}services${sep}timeline_render_service.dart');
  var source = file.readAsStringSync().replaceAll('\r\n', '\n');

  void replaceRequired(String oldValue, String newValue, String label) {
    if (!source.contains(oldValue)) {
      stderr.writeln('Required block not found: $label');
      exit(3);
    }
    source = source.replaceFirst(oldValue, newValue);
  }

  replaceRequired(
    "import 'dart:math' as math;\n",
    "import 'dart:convert';\nimport 'dart:io';\nimport 'dart:math' as math;\n",
    'dart imports',
  );

  replaceRequired(
    "      args.addAll(['-i', _q(c.sourcePath)]);",
    "      args.addAll(['-i', c.sourcePath]);",
    'raw input path',
  );

  const oldRender = '''    final command = [
      '-y',
      ...args,
      '-filter_complex_threads', '0',
      '-filter_complex', _q(filters.join(';')),
      '-map', _q('[\$videoLabel]'),
      '-map', _q('[\$audioLabel]'),
      '-c:v', 'libx264',
      '-preset', encoderPreset,
      if (!hasMotionVideo) ...['-tune', 'stillimage'],
      '-threads', '0',
      '-crf', '\$crf',
      '-c:a', 'aac',
      '-b:a', '192k',
      '-movflags', '+faststart',
      '-t', _n(durationSec),
      _q(outputPath),
    ].join(' ');

    final session = await FFmpegKit.executeAsync(
      command,
      (_) {},
      (_) {},
      (stats) {
        if (onProgress != null && durationMs > 0) {
          onProgress((stats.getTime() / durationMs).clamp(0.0, 1.0));
        }
      },
    );
    final rc = await session.getReturnCode();
    if (!ReturnCode.isSuccess(rc)) {
      final output = await session.getOutput();
      throw StateError('Falló la exportación: \$output');
    }
''';

  const newRender = '''    final commandArgs = <String>[
      '-y',
      ...args,
      '-filter_complex_threads', '0',
      '-filter_complex', filters.join(';'),
      '-map', '[\$videoLabel]',
      '-map', '[\$audioLabel]',
      '-c:v', 'libx264',
      '-preset', encoderPreset,
      if (!hasMotionVideo) ...['-tune', 'stillimage'],
      '-threads', '0',
      '-crf', '\$crf',
      '-c:a', 'aac',
      '-b:a', '192k',
      '-movflags', '+faststart',
      '-t', _n(durationSec),
      outputPath,
    ];

    if (Platform.isWindows) {
      await _runBundledWindowsFfmpeg(
        commandArgs,
        durationMs: durationMs,
        onProgress: onProgress,
      );
    } else {
      final command = commandArgs.map(_ffmpegKitArg).join(' ');
      final session = await FFmpegKit.executeAsync(
        command,
        (_) {},
        (_) {},
        (stats) {
          if (onProgress != null && durationMs > 0) {
            onProgress((stats.getTime() / durationMs).clamp(0.0, 1.0));
          }
        },
      );
      final rc = await session.getReturnCode();
      if (!ReturnCode.isSuccess(rc)) {
        final output = await session.getOutput();
        throw StateError('Orbita Videdit no pudo completar la exportación. Detalle: \$output');
      }
    }
''';

  replaceRequired(oldRender, newRender, 'platform export backend');

  const marker = '  List<String> _fitFilters(TimelineClip c, int w, int h) {';
  const helpers = r'''
  Future<void> _runBundledWindowsFfmpeg(
    List<String> args, {
    required int durationMs,
    void Function(double progress)? onProgress,
  }) async {
    final executableDir = File(Platform.resolvedExecutable).parent;
    final explicitPath = Platform.environment['ORBITA_FFMPEG_PATH'];
    final candidates = <File>[
      if (explicitPath != null && explicitPath.trim().isNotEmpty) File(explicitPath),
      File('${executableDir.path}${Platform.pathSeparator}ffmpeg.exe'),
      File('${executableDir.path}${Platform.pathSeparator}tools${Platform.pathSeparator}ffmpeg${Platform.pathSeparator}ffmpeg.exe'),
    ];
    File? ffmpeg;
    for (final candidate in candidates) {
      if (await candidate.exists()) {
        ffmpeg = candidate;
        break;
      }
    }
    if (ffmpeg == null) {
      throw StateError(
        'Orbita Videdit no pudo iniciar el motor de exportación de Windows. '
        'El archivo ffmpeg.exe incluido con la aplicación no está disponible.',
      );
    }

    // FFmpeg 9 removed -filter_complex_script. Load the generated graph and
    // pass it through the supported -filter_complex argument instead.
    final normalizedArgs = List<String>.from(args);
    final scriptIndex = normalizedArgs.indexOf('-filter_complex_script');
    if (scriptIndex >= 0) {
      if (scriptIndex + 1 >= normalizedArgs.length) {
        throw StateError('Falta la ruta del script de filtros de FFmpeg.');
      }
      final scriptPath = normalizedArgs[scriptIndex + 1];
      final filterScript = File(scriptPath);
      if (!await filterScript.exists()) {
        throw StateError('No existe el archivo de filtros: $scriptPath');
      }
      final graph = await filterScript.readAsString();
      if (graph.trim().isEmpty) {
        throw StateError('El archivo de filtros está vacío: $scriptPath');
      }
      normalizedArgs.replaceRange(
        scriptIndex, scriptIndex + 2, <String>['-filter_complex', graph],
      );
    }
    final output = StringBuffer();
    final process = await Process.start(
      ffmpeg.path,
      normalizedArgs,
      runInShell: false,
      mode: ProcessStartMode.normal,
    );

    final stdoutDone = process.stdout.drain<void>();
    final stderrDone = process.stderr
        .transform(utf8.decoder)
        .transform(const LineSplitter())
        .forEach((line) {
      if (output.length < 24000) output.writeln(line);
      if (onProgress == null || durationMs <= 0) return;
      final match = RegExp(r'time=(\d{2}):(\d{2}):(\d{2}(?:\.\d+)?)').firstMatch(line);
      if (match == null) return;
      final hours = int.tryParse(match.group(1) ?? '') ?? 0;
      final minutes = int.tryParse(match.group(2) ?? '') ?? 0;
      final seconds = double.tryParse(match.group(3) ?? '') ?? 0;
      final renderedMs = ((hours * 3600 + minutes * 60 + seconds) * 1000).round();
      onProgress((renderedMs / durationMs).clamp(0.0, 1.0));
    });

    final exitCode = await process.exitCode;
    await Future.wait([stdoutDone, stderrDone]);
    if (exitCode != 0) {
      throw StateError(
        'Orbita Videdit no pudo completar la exportación en Windows '
        '(FFmpeg terminó con código $exitCode). Detalle: ${output.toString()}',
      );
    }
    onProgress?.call(1.0);
  }

  String _ffmpegKitArg(String value) {
    if (value.isEmpty) return '""';
    if (!RegExp(r'[\s;\[\]\"]').hasMatch(value)) return value;
    return _q(value);
  }

''';

  replaceRequired(marker, '$helpers$marker', 'Windows FFmpeg helpers');
  file.writeAsStringSync(source);
  stdout.writeln('Windows export patched to use bundled ffmpeg.exe by absolute path.');
}
