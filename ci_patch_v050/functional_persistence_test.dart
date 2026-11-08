import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:orbita_editor/core/models/orbita_project.dart';

void main() {
  test('project round-trip preserves stacked editing state', () {
    final project = OrbitaProject.empty();
    final clip = TimelineClip(
      id: 'clip-functional-test',
      name: 'Texto funcional',
      sourcePath: '',
      kind: 'text',
      startMs: 1200,
      durationMs: 10000,
      text: 'Orbita Videdit',
      style: <String, dynamic>{
        'template': 'clean',
        'fontFamily': 'Montserrat',
        'fontSize': 62.0,
        'color': '#FFFFFF',
        'entryAnimation': 'typewriter',
        'loopAnimation': 'float',
        'exitAnimation': 'blurOut',
        'entryDurationMs': 700,
        'exitDurationMs': 600,
      },
      effects: <Map<String, dynamic>>[
        {'type': 'preset', 'id': 'vintage'},
        {'type': 'preset', 'id': 'sepia'},
        {'type': 'grain', 'amount': 8.0},
        {'type': 'vignette', 'strength': 5.0},
        {'type': 'transition', 'id': 'fadeBlack', 'duration': 0.45},
        {'type': 'transition', 'id': 'zoomIn', 'duration': 0.65},
      ],
    );
    project.primaryTrack.clips.add(clip);
    project.exportSettings
      ..width = 1080
      ..height = 1920
      ..fps = 30;

    final encoded = jsonEncode(project.toJson());
    final restored = OrbitaProject.fromJson(
      Map<String, dynamic>.from(jsonDecode(encoded) as Map),
    );

    expect(restored.tracks.length, project.tracks.length);
    expect(restored.primaryTrack.clips.length, 1);
    final loaded = restored.primaryTrack.clips.single;
    expect(loaded.text, 'Orbita Videdit');
    expect(loaded.style['fontFamily'], 'Montserrat');
    expect(loaded.style['fontSize'], 62.0);
    expect(loaded.style['entryAnimation'], 'typewriter');
    expect(loaded.style['loopAnimation'], 'float');
    expect(loaded.style['exitAnimation'], 'blurOut');
    expect(loaded.effects.where((e) => e['type'] == 'preset').length, 2);
    expect(loaded.effects.where((e) => ['grain', 'vignette'].contains(e['type'])).length, 2);
    expect(loaded.effects.where((e) => e['type'] == 'transition').length, 2);
    expect(restored.exportSettings.width, 1080);
    expect(restored.exportSettings.height, 1920);
    expect(restored.exportSettings.fps, 30);
  });
}
