import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:path_provider/path_provider.dart';
import 'package:orbita_editor/core/models/orbita_project.dart';
import 'package:orbita_editor/core/services/timeline_render_service.dart';

Future<File> _makeImage(Directory directory) async {
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);
  canvas.drawRect(const Rect.fromLTWH(0, 0, 320, 240), Paint()..color = Colors.deepPurple);
  canvas.drawCircle(const Offset(155, 115), 65, Paint()..color = Colors.amber);
  final image = await recorder.endRecording().toImage(320, 240);
  final data = await image.toByteData(format: ui.ImageByteFormat.png);
  if (data == null) throw StateError('Cannot create image fixture');
  final f = File('${directory.path}/source_fixture.png');
  await f.writeAsBytes(data.buffer.asUint8List(), flush: true);
  image.dispose();
  return f;
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('Android FFmpegKit exports a real MP4 with compositing and fade out', (tester) async {
    final base = await getApplicationSupportDirectory();
    final work = Directory('${base.path}/orbita_android_export_integration');
    await work.create(recursive: true);
    final source = await _makeImage(work);
    final out = File('${work.path}/android_output.mp4');
    if (await out.exists()) await out.delete();
    final project = OrbitaProject.empty();
    project.exportSettings
      ..width = 320
      ..height = 240
      ..fps = 15;
    project.primaryTrack.clips.add(TimelineClip(
      id: 'android-test-1', name: 'Generated still image', sourcePath: source.path,
      kind: 'image', startMs: 0, durationMs: 1100, hasAudio: false,
      effects: <Map<String, dynamic>>[
        {'type':'preset', 'id':'warm'},
        {'type':'grain', 'amount':3.0},
        {'type':'vignette', 'strength':3.0},
        {'type':'transition', 'id':'fadeBlack', 'duration':.2},
        {'type':'outroFade', 'duration':.2},
      ],
    ));
    await TimelineRenderService().renderPrimaryVideoTrack(project, out.path)
      .timeout(const Duration(minutes: 4));
    expect(await out.exists(), true, reason: 'FFmpegKit must produce an MP4');
    expect(await out.length(), greaterThan(1024));
    final header = await out.openRead(0, 100).expand((chunk) => chunk).toList();
    expect(String.fromCharCodes(header), contains('ftyp'));
    stdout.writeln('ANDROID EXPORT PASS ${out.lengthSync()} bytes');
  }, timeout: const Timeout(Duration(minutes: 7)));
}
