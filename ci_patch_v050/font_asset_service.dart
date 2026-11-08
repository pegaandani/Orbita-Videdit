import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';

class FontAssetService {
  static const files = <String, String>{
    'Roboto': 'Roboto.ttf',
    'Open Sans': 'OpenSans.ttf',
    'Montserrat': 'Montserrat.ttf',
    'Poppins': 'Poppins-Regular.ttf',
    'Inter': 'Inter.ttf',
    'Lato': 'Lato-Regular.ttf',
    'Nunito': 'Nunito.ttf',
    'Raleway': 'Raleway.ttf',
    'Oswald': 'Oswald.ttf',
    'Source Sans 3': 'SourceSans3-Regular.ttf',
    'Ubuntu': 'Ubuntu-Regular.ttf',
    'Merriweather': 'Merriweather.ttf',
    'Playfair Display': 'PlayfairDisplay.ttf',
    'Bebas Neue': 'BebasNeue-Regular.ttf',
    'Caveat': 'Caveat.ttf',
  };

  Future<Map<String, String>> materializeAll() async {
    final root = await getApplicationSupportDirectory();
    final dir = Directory('${root.path}${Platform.pathSeparator}fonts');
    if (!await dir.exists()) await dir.create(recursive: true);
    final out = <String, String>{};
    for (final entry in files.entries) {
      final target = File('${dir.path}${Platform.pathSeparator}${entry.value}');
      if (!await target.exists() || await target.length() < 1024) {
        final data = await rootBundle.load('assets/fonts/${entry.value}');
        final bytes = data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
        await target.writeAsBytes(Uint8List.fromList(bytes), flush: true);
      }
      out[entry.key] = target.path;
    }
    return out;
  }
}
