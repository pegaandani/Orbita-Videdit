import 'dart:io';

void main(List<String> args) {
  if (args.isEmpty) exit(2);
  final file = File('${args.first}${Platform.pathSeparator}lib${Platform.pathSeparator}features${Platform.pathSeparator}editor${Platform.pathSeparator}editor_screen.dart');
  var source = file.readAsStringSync().replaceAll('\r\n', '\n');
  const oldValue = 'canvas.drawPoint(Offset(random.nextDouble() * size.width, random.nextDouble() * size.height), paint);';
  const newValue = 'canvas.drawCircle(Offset(random.nextDouble() * size.width, random.nextDouble() * size.height), .55, paint);';
  if (!source.contains(oldValue)) {
    stderr.writeln('Preview noise draw call not found.');
    exit(3);
  }
  source = source.replaceFirst(oldValue, newValue);
  file.writeAsStringSync(source);
  stdout.writeln('Preview grain painter fixed.');
}
