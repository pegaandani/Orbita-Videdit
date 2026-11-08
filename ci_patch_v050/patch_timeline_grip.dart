import 'dart:io';

void main(List<String> args) {
  if (args.isEmpty) exit(2);
  final file = File('${args.first}${Platform.pathSeparator}lib${Platform.pathSeparator}features${Platform.pathSeparator}editor${Platform.pathSeparator}editor_screen.dart');
  var source = file.readAsStringSync().replaceAll('\r\n', '\n');
  final start = source.indexOf('  Widget _timelineClip(');
  final end = source.indexOf('\n  IconData _clipKindIcon', start);
  if (start < 0 || end < 0) {
    stderr.writeln('Timeline clip block not found.');
    exit(3);
  }
  var block = source.substring(start, end);
  const marker = '''              Positioned(\n                left: 0,\n                top: 0,\n                bottom: 0,\n                width: 8,\n''';
  if (!block.contains(marker)) {
    stderr.writeln('Timeline trim handle marker not found.');
    exit(4);
  }
  const grip = '''              if (!track.locked && width > 64)\n                Positioned(\n                  top: 2,\n                  left: math.max(12.0, width / 2 - 12),\n                  width: 24,\n                  height: 18,\n                  child: IgnorePointer(\n                    child: DecoratedBox(\n                      decoration: BoxDecoration(\n                        color: Colors.black.withValues(alpha: .22),\n                        borderRadius: BorderRadius.circular(6),\n                      ),\n                      child: const Icon(Icons.open_with_rounded, size: 13, color: Colors.white70),\n                    ),\n                  ),\n                ),\n''';
  block = block.replaceFirst(marker, grip + marker);
  source = source.substring(0, start) + block + source.substring(end);
  file.writeAsStringSync(source);
  stdout.writeln('Timeline clip movement grip added.');
}
