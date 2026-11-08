import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:orbita_editor/core/models/orbita_project.dart';
import 'package:orbita_editor/core/services/timeline_render_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('TimelineRenderService produces a playable Windows MP4 with effects and spaced paths', () async {
    if (!Platform.isWindows) return;

    final sourceFixturePath = Platform.environment['ORBITA_TEST_VIDEO'];
    final ffmpegPath = Platform.environment['ORBITA_FFMPEG_PATH'];
    expect(sourceFixturePath, isNotNull, reason: 'ORBITA_TEST_VIDEO is required');
    expect(ffmpegPath, isNotNull, reason: 'ORBITA_FFMPEG_PATH is required');
    final sourceFixture = sourceFixturePath!;
    final ffmpegExe = ffmpegPath!;
    expect(File(sourceFixture).existsSync(), isTrue);
    expect(File(ffmpegExe).existsSync(), isTrue);

    final sep = Platform.pathSeparator;
    final workDir = Directory('${Directory.systemTemp.path}${sep}Orbita Videdit smoke paths');
    if (workDir.existsSync()) workDir.deleteSync(recursive: true);
    workDir.createSync(recursive: true);
    addTearDown(() {
      if (workDir.existsSync()) workDir.deleteSync(recursive: true);
    });

    final input = File('${workDir.path}${sep}input clip with spaces.mp4');
    File(sourceFixture).copySync(input.path);
    final output = File('${workDir.path}${sep}render output with spaces.mp4');

    final project = OrbitaProject.empty();
    project.exportSettings
      ..width = 320
      ..height = 240
      ..fps = 24;

    project.primaryTrack.clips.add(
      TimelineClip(
        id: 'render-smoke-video',
        name: 'Render smoke input',
        sourcePath: input.path,
        kind: 'video',
        startMs: 0,
        durationMs: 1200,
        hasAudio: false,
        effects: <Map<String, dynamic>>[
          {'type': 'preset', 'id': 'warm'},
          {'type': 'preset', 'id': 'vivid'},
          {'type': 'vignette', 'strength': 5.0},
          {'type': 'grain', 'amount': 6.0},
          {'type': 'transition', 'id': 'fadeBlack', 'duration': 0.25},
          {'type': 'transition', 'id': 'zoomIn', 'duration': 0.3},
        ],
      ),
    );

    var lastProgress = 0.0;
    await TimelineRenderService().renderPrimaryVideoTrack(
      project,
      output.path,
      onProgress: (value) => lastProgress = value,
    );

    expect(output.existsSync(), isTrue);
    expect(output.lengthSync(), greaterThan(1000));
    expect(lastProgress, greaterThanOrEqualTo(0.99));

    final ffprobePath = ffmpegExe.replaceFirst(
      RegExp(r'ffmpeg\.exe$', caseSensitive: false),
      'ffprobe.exe',
    );
    expect(File(ffprobePath).existsSync(), isTrue);

    final probe = await Process.run(
      ffprobePath,
      ['-v', 'error', '-show_entries', 'format=duration', '-of', 'default=nw=1:nk=1', output.path],
      runInShell: false,
    );
    expect(probe.exitCode, 0, reason: '${probe.stderr}');
    final duration = double.tryParse('${probe.stdout}'.trim()) ?? 0;
    expect(duration, greaterThan(0.8));
  });
}
