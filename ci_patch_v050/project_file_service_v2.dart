import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';

import '../models/orbita_project.dart';

class ProjectFileService {
  Future<Directory> _root() async {
    final base = await getApplicationDocumentsDirectory();
    final dir = Directory('${base.path}${Platform.pathSeparator}Orbita Videdit');
    if (!await dir.exists()) await dir.create(recursive: true);
    return dir;
  }

  Future<File> save(OrbitaProject project, {String? customPath}) async {
    project.updatedAt = DateTime.now();
    final file = customPath != null
        ? File(customPath)
        : File('${(await _root()).path}${Platform.pathSeparator}${_safe(project.name)}.orbita');
    await file.parent.create(recursive: true);
    const encoder = JsonEncoder.withIndent('  ');
    await file.writeAsString(encoder.convert(project.toJson()), flush: true);
    return file;
  }

  Future<OrbitaProject> open(String path) async {
    final map = jsonDecode(await File(path).readAsString()) as Map<String, dynamic>;
    return OrbitaProject.fromJson(map);
  }

  Future<OrbitaProject?> pickAndOpen() async {
    final picked = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['orbita'],
    );
    if (picked.isEmpty) return null;
    final path = picked.first.path;
    if (path == null || path.isEmpty) return null;
    return open(path);
  }

  String _safe(String name) => name.replaceAll(RegExp(r'[<>:"/\\|?*]'), '_').trim();
}
