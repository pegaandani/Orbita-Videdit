import 'dart:io';

import 'package:archive/archive.dart';
import 'package:orbita_editor/core/models/orbita_project.dart';
import 'package:orbita_editor/core/services/media_import_service.dart';
import 'package:orbita_editor/core/services/timeline_render_service.dart';

Future<void> execute(String executable, List<String> args) async {
  final result = await Process.run(executable, args, runInShell: false);
  if (result.exitCode != 0) {
    throw StateError('Command failed: ' + executable + ' ' + args.join(' ') +
      '\n' + result.stderr.toString());
  }
}

Future<void> main() async {
  final ffmpeg = Platform.environment['ORBITA_FFMPEG_PATH'];
  final ffprobe = Platform.environment['ORBITA_FFPROBE_PATH'];
  final resourceRoot = Platform.environment['ORBITA_RESOURCE_DIR'];
  if (ffmpeg == null || ffprobe == null || resourceRoot == null) {
    throw StateError('Test environment missing native ffmpeg, ffprobe or resources directory.');
  }
  final sandbox = await Directory.systemTemp.createTemp('Orbita Videdit export paths ');
  try {
    final sep = Platform.pathSeparator;
    final input = File(sandbox.path + sep + 'input clip with spaces.mp4');
    final output = File(sandbox.path + sep + 'export with spaces.mp4');
    await execute(ffmpeg, [
      '-y','-f','lavfi','-i','color=c=blue:s=320x240:d=1.5:r=24',
      '-c:v','libx264','-pix_fmt','yuv420p',input.path,
    ]);
    if (await input.length() < 1000) throw StateError('Source fixture missing.');

    // A downloaded media file is recognized on desktop using bundled ffprobe,
    // rather than invoking Android/iOS platform channels.
    final importer = MediaImportService();
    final found = await importer.probe(input.path);
    if (found.kind != 'video' || found.durationMs < 1000) {
      throw StateError('Imported file did not probe correctly: ' + found.kind);
    }
    stdout.writeln('PASS: desktop FFprobe reads imported MP4 file paths with spaces.');
    final installedSingle = await importer.installDownloadedMedia(input.path);
    if (!await File(installedSingle.path).exists() ||
        installedSingle.path == input.path || installedSingle.kind != 'video') {
      throw StateError('Standalone download was not permanently installed.');
    }
    stdout.writeln('PASS: standalone stock media installed in permanent app library.');


    final project = OrbitaProject.empty();
    project.exportSettings
      ..width = 320
      ..height = 240
      ..fps = 24;
    project.primaryTrack.clips.add(TimelineClip(
      id:'export-native-cli',
      name:'Video con filtros y transiciones',
      sourcePath:input.path,
      kind:'video',
      startMs:0,
      durationMs:1200,
      hasAudio:false,
      effects:<Map<String, dynamic>>[
        {'type':'preset','id':'warm'},
        {'type':'preset','id':'vivid'},
        {'type':'grain','amount':5.0},
        {'type':'vignette','strength':5.0},
        {'type':'transition','id':'fadeBlack','duration':.25},
        {'type':'transition','id':'zoomIn','duration':.3},
      ],
    ));
    var latestProgress=0.0;
    await TimelineRenderService().renderPrimaryVideoTrack(
      project,output.path,
      onProgress:(value) => latestProgress=value,
    );
    if (!await output.exists() || await output.length() < 1000) {
      throw StateError('Render did not produce output.');
    }
    final result=await Process.run(ffprobe,
      ['-v','error','-show_entries','format=duration','-of',
       'default=nw=1:nk=1',output.path],
      runInShell:false,
    );
    final duration=double.tryParse(result.stdout.toString().trim()) ?? 0;
    if (result.exitCode != 0 || duration < .8 || latestProgress < .99) {
      throw StateError('Output is not a playable MP4. ffprobe: ' +
        result.stderr.toString() + ' duration: ' + duration.toString());
    }
    stdout.writeln('PASS: native FFmpeg exported and verified a playable MP4 with stacked effects.');

    // A legitimate stock ZIP installs media, ignores unrelated README and
    // executable files, and imports its contents as local Videdit assets.
    final pack = Archive();
    final videoBytes = await input.readAsBytes();
    pack.addFile(ArchiveFile('clips/example.mp4',videoBytes.length,videoBytes));
    final readme = 'public-domain reference';
    pack.addFile(ArchiveFile('README.txt',readme.length,readme.codeUnits));
    pack.addFile(ArchiveFile('setup.exe',readme.length,readme.codeUnits));
    final zip = File(sandbox.path + sep + 'downloaded resource pack.zip');
    await zip.writeAsBytes(ZipEncoder().encodeBytes(pack));
    final media = await importer.installResourceZip(zip.path);
    if (media.length != 1 || media.single.kind != 'video' ||
        !await File(media.single.path).exists()) {
      throw StateError('ZIP resource was not installed as usable media.');
    }
    stdout.writeln('PASS: ZIP resources installed and usable; executable plugins skipped.');
  } finally {
    if (await sandbox.exists()) await sandbox.delete(recursive:true);
  }
}
