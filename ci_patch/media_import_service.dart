import 'dart:convert';
import 'dart:io';

import 'package:archive/archive_io.dart';
import 'package:file_picker/file_picker.dart';
import 'package:ffmpeg_kit_flutter_new_min_gpl/ffprobe_kit.dart';
import 'package:path_provider/path_provider.dart';

import '../models/media_asset.dart';

/// Windows imports use the ffprobe.exe bundled with the app, not the
/// mobile-only FFprobeKit platform channel. Imported ZIP resources remain
/// installed in persistent app storage, so projects can reopen them.
class MediaImportService {
  static const videos = <String>{
    'mp4','mov','mkv','avi','webm','m4v','mpeg','mpg','3gp','ts','mts','m2ts',
  };
  static const audios = <String>{
    'mp3','wav','m4a','aac','flac','ogg','opus','wma','aiff',
  };
  static const images = <String>{
    'jpg','jpeg','png','webp','bmp','gif','tif','tiff',
  };
  static const extensions = [
    'mp4','mov','mkv','avi','webm','m4v','mpeg','mpg','3gp','ts','mts','m2ts',
    'mp3','wav','m4a','aac','flac','ogg','opus','wma','aiff',
    'jpg','jpeg','png','webp','bmp','gif','tif','tiff','zip',
  ];

  static String _extension(String path) => path.split('.').last.toLowerCase();
  static bool isSupportedMedia(String path) {
    final ext = _extension(path);
    return videos.contains(ext) || audios.contains(ext) || images.contains(ext);
  }

  Future<List<MediaAsset>> pickAndProbe({String? preferredKind, bool installResources = false}) async {
    final allowed = switch (preferredKind) {
      'video' => videos.toList(),
      'audio' => audios.toList(),
      'image' => images.toList(),
      _ => extensions,
    };
    final picked = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: allowed,
    );
    if (picked.isEmpty) return <MediaAsset>[];
    final assets = <MediaAsset>[];
    final errors = <String>[];
    for (final file in picked) {
      if (file.path == null) continue;
      try {
        final batch = _extension(file.path!) == 'zip'
            ? await installResourceZip(file.path!)
            : <MediaAsset>[installResources
                ? await installDownloadedMedia(file.path!, displayName: file.name)
                : await probe(file.path!, displayName: file.name)];
        for (final media in batch) {
          if (preferredKind == null || preferredKind == 'media' ||
              media.kind == preferredKind ||
              (preferredKind == 'image' && media.kind == 'gif')) {
            assets.add(media);
          }
        }
      } catch (e) {
        errors.add(file.name + ': ' + e.toString());
      }
    }
    if (assets.isEmpty && errors.isNotEmpty) {
      throw StateError('No se pudo importar: ' + errors.join(' | '));
    }
    if (errors.isNotEmpty) {
      stderr.writeln('Videdit omitió recursos no compatibles: ' + errors.join(' | '));
    }
    return assets;
  }

  /// Copy stock media into permanent library storage. Removing the original
  /// download will not break an Orbita project using the installed resource.
  Future<MediaAsset> installDownloadedMedia(String path, {String? displayName}) async {
    if (!isSupportedMedia(path)) throw StateError('Formato no compatible: $path');
    final original = File(path);
    if (!await original.exists()) throw StateError('No existe el recurso descargado: $path');
    final override = Platform.environment['ORBITA_RESOURCE_DIR'];
    final base = override != null && override.isNotEmpty
        ? Directory(override)
        : await getApplicationSupportDirectory();
    final sep = Platform.pathSeparator;
    final directory = Directory(base.path + sep + 'orbita_resource_packs' + sep + 'downloaded');
    await directory.create(recursive: true);
    final filename = original.uri.pathSegments.last.replaceAll(RegExp(r'[<>:"/\\|?*]'), '_');
    final destination = File(
      directory.path + sep + DateTime.now().microsecondsSinceEpoch.toString() + '_' + filename,
    );
    try {
      await original.copy(destination.path);
      return await probe(destination.path, displayName: displayName ?? filename);
    } catch (_) {
      if (await destination.exists()) await destination.delete();
      rethrow;
    }
  }

  /// ZIP packages install only usable media; never unpack or run scripts,
  /// programs, extensions or executable plugins.
  Future<List<MediaAsset>> installResourceZip(String zipPath) async {
    final zip = File(zipPath);
    if (!await zip.exists()) throw StateError('No existe: $zipPath');
    if (await zip.length() > 256 * 1024 * 1024) {
      throw StateError('ZIP mayor a 256 MB. Extrae el paquete e importa sus archivos.');
    }

    final override = Platform.environment['ORBITA_RESOURCE_DIR'];
    final support = override != null && override.isNotEmpty
        ? Directory(override)
        : await getApplicationSupportDirectory();
    final sep = Platform.pathSeparator;
    final root = Directory(
      support.path + sep + 'orbita_resource_packs' + sep +
      'pack_' + DateTime.now().microsecondsSinceEpoch.toString(),
    );
    await root.create(recursive: true);
    final input = InputFileStream(zipPath);
    try {
      final archive = ZipDecoder().decodeStream(input, verify: true);
      final entries = archive.files.where((f) => f.isFile && !f.isSymbolicLink).toList();
      if (entries.length > 500) throw StateError('Demasiados archivos: máximo 500 por paquete.');
      final outputFiles = <({ArchiveFile item, File path})>[];
      var totalBytes = 0;
      for (final entry in entries) {
        final relative = entry.name.replaceAll('\\', '/');
        final parts = relative.split('/');
        if (relative.startsWith('/') || relative.startsWith('~') ||
            parts.any((p) => p.isEmpty || p == '.' || p == '..' || p.contains(':'))) {
          throw StateError('ZIP contiene una ruta insegura: $relative');
        }
        if (!isSupportedMedia(relative)) continue;
        totalBytes += entry.size;
        if (entry.size > 512 * 1024 * 1024 || totalBytes > 1024 * 1024 * 1024) {
          throw StateError('Paquete demasiado grande para instalarlo.');
        }
        outputFiles.add((
          item: entry,
          path: File(root.path + sep + parts.join(sep)),
        ));
      }
      if (outputFiles.isEmpty) {
        throw StateError('El ZIP no contiene imágenes, GIF, audio o video compatibles.');
      }

      final imported = <MediaAsset>[];
      for (final item in outputFiles) {
        await item.path.parent.create(recursive: true);
        final writer = OutputFileStream(item.path.path);
        try {
          item.item.writeContent(writer);
        } finally {
          writer.closeSync();
        }
        imported.add(await probe(item.path.path, displayName: item.item.name.split('/').last));
      }
      return imported;
    } catch (_) {
      if (await root.exists()) await root.delete(recursive: true);
      rethrow;
    } finally {
      input.closeSync();
    }
  }

  Future<Map<String, dynamic>> _readMediaInfo(String path) async {
    final sep = Platform.pathSeparator;
    final override = Platform.environment['ORBITA_FFPROBE_PATH'];
    if (Platform.isWindows || (override != null && override.isNotEmpty)) {
      final executableDir = File(Platform.resolvedExecutable).parent.path;
      final ffmpegOverride = Platform.environment['ORBITA_FFMPEG_PATH'];
      final options = <File>[
        if (override != null && override.isNotEmpty) File(override),
        if (ffmpegOverride != null && ffmpegOverride.isNotEmpty)
          File(ffmpegOverride.replaceFirst(
            RegExp(r'ffmpeg(\.exe)?$', caseSensitive: false),
            Platform.isWindows ? 'ffprobe.exe' : 'ffprobe',
          )),
        File(executableDir + sep + 'ffprobe.exe'),
        File(executableDir + sep + 'tools' + sep + 'ffmpeg' + sep + 'ffprobe.exe'),
      ];
      File? program;
      for (final candidate in options) {
        if (await candidate.exists()) { program = candidate; break; }
      }
      if (program == null) {
        throw StateError('Falta ffprobe.exe junto a Videdit. Reinstala la versión completa.');
      }
      final result = await Process.run(
        program.path,
        <String>['-v','error','-show_format','-show_streams','-of','json',path],
        runInShell: false,
      );
      if (result.exitCode != 0) {
        throw StateError('No se pudo leer el archivo multimedia: ' + result.stderr.toString());
      }
      return Map<String, dynamic>.from(jsonDecode(result.stdout.toString()) as Map);
    }
    final session = await FFprobeKit.getMediaInformation(path);
    final info = await session.getMediaInformation();
    return Map<String, dynamic>.from(info?.getAllProperties() ?? const <String, dynamic>{});
  }

  Future<MediaAsset> probe(String path, {String? displayName}) async {
    if (!await File(path).exists()) throw StateError('No existe el archivo: $path');
    if (!isSupportedMedia(path)) throw StateError('Formato no compatible: $path');

    final props = await _readMediaInfo(path);
    final format = (props['format'] as Map?)?.cast<String, dynamic>() ?? const <String, dynamic>{};
    final streams = ((props['streams'] as List?) ?? const [])
        .whereType<Map>().map((e) => e.cast<String, dynamic>()).toList();
    Map<String, dynamic>? video, audio;
    for (final s in streams) {
      if (video == null && s['codec_type'] == 'video') video = s;
      if (audio == null && s['codec_type'] == 'audio') audio = s;
    }
    final ext = _extension(path);
    final kind = ext == 'gif' ? 'gif'
        : images.contains(ext) ? 'image'
        : video != null ? 'video'
        : audio != null ? 'audio' : 'unknown';
    if (kind == 'unknown') throw StateError('El archivo no contiene pistas multimedia compatibles.');
    final duration = _toDouble(format['duration']) ??
      _toDouble(video?['duration']) ?? _toDouble(audio?['duration']) ?? 0;
    return MediaAsset(
      id: DateTime.now().microsecondsSinceEpoch.toString() + '-' + path.hashCode.toString(),
      path: path,
      name: displayName ?? File(path).uri.pathSegments.last,
      durationMs: kind == 'image' ? 5000 : ((duration > 0 ? duration : 5) * 1000).round(),
      kind: kind,
      width: _toInt(video?['width']),
      height: _toInt(video?['height']),
      fps: _fps(video?['avg_frame_rate'] ?? video?['r_frame_rate']),
      codec: video?['codec_name']?.toString() ?? audio?['codec_name']?.toString(),
      hasAudio: audio != null,
      hasVideo: video != null,
    );
  }

  double? _fps(dynamic value) {
    if (value == null) return null;
    final s = value.toString();
    if (!s.contains('/')) return double.tryParse(s);
    final p = s.split('/');
    final a = double.tryParse(p[0]), b = double.tryParse(p[1]);
    return a != null && b != null && b != 0 ? a / b : null;
  }
  int? _toInt(dynamic value) => value is num ? value.round() : int.tryParse('$value');
  double? _toDouble(dynamic value) => value is num ? value.toDouble() : double.tryParse('$value');
}
