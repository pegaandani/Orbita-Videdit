import 'dart:io';

void main(List<String> args) {
  if (args.isEmpty) {
    stderr.writeln('Usage: dart patch_render.dart <videdit_project>');
    exit(2);
  }
  final file = File('${args.first}${Platform.pathSeparator}lib${Platform.pathSeparator}core${Platform.pathSeparator}services${Platform.pathSeparator}timeline_render_service.dart');
  var source = file.readAsStringSync().replaceAll('\r\n', '\n');

  const oldScale = '''        final transition = _transitionFor(c);\n        final transitionId = transition?['id'] as String?;\n        final transitionProgress = _transitionProgressExpr(c, startSec);\n        if (transitionId == 'zoomIn') {\n          scaleExpr = "(\$scaleExpr)*(0.72+0.28*(\$transitionProgress))";\n        }\n''';
  const newScale = '''        final transitions = _transitionsFor(c);\n        for (final transition in transitions) {\n          final transitionId = transition['id'] as String?;\n          final transitionProgress = _transitionProgressExprFor(transition, startSec);\n          if (transitionId == 'zoomIn') {\n            scaleExpr = "(\$scaleExpr)*(0.72+0.28*(\$transitionProgress))";\n          }\n        }\n''';

  const oldPosition = '''        if (transitionId == 'slideLeft') {\n          xExpr = "(\$xExpr)+(1-(\$transitionProgress))*1.15";\n        } else if (transitionId == 'slideRight') {\n          xExpr = "(\$xExpr)-(1-(\$transitionProgress))*1.15";\n        } else if (transitionId == 'wipeUp') {\n          yExpr = "(\$yExpr)+(1-(\$transitionProgress))*1.15";\n        } else if (transitionId == 'wipeDown') {\n          yExpr = "(\$yExpr)-(1-(\$transitionProgress))*1.15";\n        }\n''';
  const newPosition = '''        for (final transition in transitions) {\n          final transitionId = transition['id'] as String?;\n          final transitionProgress = _transitionProgressExprFor(transition, startSec);\n          if (transitionId == 'slideLeft') {\n            xExpr = "(\$xExpr)+(1-(\$transitionProgress))*1.15";\n          } else if (transitionId == 'slideRight') {\n            xExpr = "(\$xExpr)-(1-(\$transitionProgress))*1.15";\n          } else if (transitionId == 'wipeUp') {\n            yExpr = "(\$yExpr)+(1-(\$transitionProgress))*1.15";\n          } else if (transitionId == 'wipeDown') {\n            yExpr = "(\$yExpr)-(1-(\$transitionProgress))*1.15";\n          }\n        }\n''';

  const oldHelpers = '''  Map<String, dynamic>? _transitionFor(TimelineClip c) {\n    for (final effect in c.effects) {\n      if (effect['type'] == 'transition') return effect;\n    }\n    return null;\n  }\n\n  String _transitionProgressExpr(TimelineClip c, double startSec, {String timeVariable = 't'}) {\n    final effect = _transitionFor(c);\n    final d = ((effect?['duration'] as num?)?.toDouble() ?? .45).clamp(.15, 2.0);\n    return "max(0,min(1,(\$timeVariable-\${_n(startSec)})/\${_n(d)}))";\n  }\n''';
  const newHelpers = '''  List<Map<String, dynamic>> _transitionsFor(TimelineClip c) =>\n      c.effects.where((effect) => effect['type'] == 'transition').toList();\n\n  String _transitionProgressExprFor(\n    Map<String, dynamic> effect,\n    double startSec, {\n    String timeVariable = 't',\n  }) {\n    final d = ((effect['duration'] as num?)?.toDouble() ?? .45).clamp(.15, 2.0);\n    return "max(0,min(1,(\$timeVariable-\${_n(startSec)})/\${_n(d)}))";\n  }\n''';

  void replaceRequired(String oldValue, String newValue, String label) {
    if (!source.contains(oldValue)) {
      stderr.writeln('Required render block not found: $label');
      exit(3);
    }
    source = source.replaceFirst(oldValue, newValue);
  }

  replaceRequired(oldScale, newScale, 'scale transition');
  replaceRequired(oldPosition, newPosition, 'position transition');
  replaceRequired(oldHelpers, newHelpers, 'transition helpers');
  file.writeAsStringSync(source);
  stdout.writeln('Timeline render compositor patched for deterministic multiple transitions.');
}
