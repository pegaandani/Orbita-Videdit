import 'dart:io';

void main(List<String> args) {
  if (args.isEmpty) exit(2);
  final root = args.first;
  final sep = Platform.pathSeparator;

  void patchFile(String relative, List<(String, String)> replacements) {
    final file = File('$root$sep${relative.replaceAll('/', sep)}');
    var source = file.readAsStringSync().replaceAll('\r\n', '\n');
    for (final pair in replacements) {
      if (!source.contains(pair.$1)) {
        stderr.writeln('Scroll patch target not found in $relative');
        exit(3);
      }
      source = source.replaceFirst(pair.$1, pair.$2);
    }
    file.writeAsStringSync(source);
  }

  patchFile('lib/features/editor/widgets/effects_panel.dart', [
    (
      "    return ListView(padding: const EdgeInsets.all(14), children: [",
      "    return Scrollbar(interactive: true, child: ListView(padding: const EdgeInsets.all(14), children: [",
    ),
    (
      "      ],\n    ]);\n  }\n\n  Widget _audioEffects(TimelineClip c) => ListView(",
      "      ],\n    ]));\n  }\n\n  Widget _audioEffects(TimelineClip c) => Scrollbar(interactive: true, child: ListView(",
    ),
    (
      "          if (c.effects.any((e) => e['type'] == 'stereoWiden'))\n            _effectSlider(c, 'stereoWiden', 'amount', 'Amplitud', 1, 2.5),\n        ],\n      );",
      "          if (c.effects.any((e) => e['type'] == 'stereoWiden'))\n            _effectSlider(c, 'stereoWiden', 'amount', 'Amplitud', 1, 2.5),\n        ],\n      ));",
    ),
  ]);

  patchFile('lib/features/editor/widgets/resources_panel.dart', [
    (
      "  Widget build(BuildContext context) => ListView(",
      "  Widget build(BuildContext context) => Scrollbar(interactive: true, child: ListView(",
    ),
    (
      "        ],\n      );\n\n  Widget _site",
      "        ],\n      ));\n\n  Widget _site",
    ),
  ]);

  stdout.writeln('Basic vertical content scrollbars patched.');
}
