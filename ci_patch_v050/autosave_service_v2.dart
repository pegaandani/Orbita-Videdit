import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

import '../models/orbita_project.dart';

class AutosaveService {
  Timer? _timer;
  int keepVersions = 8;

  void start(OrbitaProject Function() snapshot, {Duration interval = const Duration(seconds: 45)}) {
    _timer?.cancel();
    _timer = Timer.periodic(interval, (_) => saveRecovery(snapshot()));
  }

  void stop() => _timer?.cancel();

  Future<File> saveRecovery(OrbitaProject project) async {
    final base = await getApplicationSupportDirectory();
    final dir = Directory('${base.path}${Platform.pathSeparator}recovery${Platform.pathSeparator}${project.id}');
    await dir.create(recursive: true);
    final stamp = DateTime.now().toIso8601String().replaceAll(':', '-');
    final file = File('${dir.path}${Platform.pathSeparator}$stamp.orbita.autosave');
    await file.writeAsString(jsonEncode(project.toJson()), flush: true);
    await _trim(dir);
    return file;
  }

  Future<List<File>> recoveries(String projectId) async {
    final base = await getApplicationSupportDirectory();
    final dir = Directory('${base.path}${Platform.pathSeparator}recovery${Platform.pathSeparator}$projectId');
    if (!await dir.exists()) return [];
    final files = await dir.list().where((e) => e is File).cast<File>().toList();
    files.sort((a, b) => b.lastModifiedSync().compareTo(a.lastModifiedSync()));
    return files;
  }

  Future<List<File>> latestRecoveries({int limit = 8}) async {
    final base = await getApplicationSupportDirectory();
    final root = Directory('${base.path}${Platform.pathSeparator}recovery');
    if (!await root.exists()) return [];
    final files = await root
        .list(recursive: true, followLinks: false)
        .where((e) => e is File && e.path.endsWith('.orbita.autosave'))
        .cast<File>()
        .toList();
    files.sort((a, b) => b.lastModifiedSync().compareTo(a.lastModifiedSync()));
    return files.take(limit).toList(growable: false);
  }

  Future<OrbitaProject?> readRecovery(File file) async {
    try {
      final decoded = jsonDecode(await file.readAsString());
      if (decoded is! Map) return null;
      return OrbitaProject.fromJson(Map<String, dynamic>.from(decoded));
    } catch (_) {
      return null;
    }
  }

  Future<void> _trim(Directory dir) async {
    final files = await dir.list().where((e) => e is File).cast<File>().toList();
    files.sort((a, b) => b.lastModifiedSync().compareTo(a.lastModifiedSync()));
    for (final f in files.skip(keepVersions)) {
      await f.delete();
    }
  }
}
