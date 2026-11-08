import 'dart:io';

String replaceSection(String source, String startMarker, String endMarker, String replacement, String label) {
  final start = source.indexOf(startMarker);
  if (start < 0) {
    stderr.writeln('Missing start marker for $label');
    exit(3);
  }
  final end = source.indexOf(endMarker, start);
  if (end < 0) {
    stderr.writeln('Missing end marker for $label');
    exit(4);
  }
  return source.substring(0, start) + replacement + source.substring(end);
}

void main(List<String> args) {
  if (args.isEmpty) {
    stderr.writeln('Usage: dart patch_text_render.dart <videdit_project>');
    exit(2);
  }
  final sep = Platform.pathSeparator;
  final file = File('${args.first}${sep}lib${sep}core${sep}services${sep}timeline_render_service.dart');
  var source = file.readAsStringSync().replaceAll('\r\n', '\n');

  const oldRotation = "          final rotationExpr = _transformExpr(c, 'rotation', c.rotation, timeVariable: 't');";
  const newRotation = "          final rotationExpr = _textRotationExpr(c, _transformExpr(c, 'rotation', c.rotation, timeVariable: 't'), startSec, endSec);";
  if (!source.contains(oldRotation)) {
    stderr.writeln('Text rotation line not found');
    exit(5);
  }
  source = source.replaceFirst(oldRotation, newRotation);

  source = replaceSection(
    source,
    '  String _drawText(',
    '  String _transformExpr(',
    r'''  String _drawText(TimelineClip c, int w, int h) {
    final start = c.startMs / 1000.0;
    final end = c.endMs / 1000.0;
    final style = c.style;
    final baseSize = (style['fontSize'] as num?)?.toDouble() ?? 48;
    final color = _ffColor((style['color'] as String?) ?? '#FFFFFF');
    final template = (style['template'] as String?) ?? 'clean';
    final fontFamily = (style['fontFamily'] as String?) ?? 'Inter';
    final legacy = (style['animation'] as String?) ?? 'static';
    final entry = (style['entryAnimation'] as String?) ?? switch (legacy) {
      'fade' => 'fadeIn',
      'slideLeft' => 'slideLeftIn',
      'slideRight' => 'slideRightIn',
      'slideUp' => 'slideUpIn',
      'slideDown' => 'slideDownIn',
      'zoom' => 'zoomIn',
      _ => 'none',
    };
    final loop = (style['loopAnimation'] as String?) ?? (legacy == 'pulse' ? 'pulse' : 'none');
    final exit = (style['exitAnimation'] as String?) ?? (legacy == 'fade' ? 'fadeOut' : 'none');
    final scaleExpr = _transformExpr(c, 'scale', c.scale, timeVariable: 't');
    final opacityExpr = _transformExpr(c, 'opacity', c.opacity, timeVariable: 't');

    var x = '(w-text_w)/2';
    var y = '(h-text_h)/2';
    var alpha = "max(0,min(1,$opacityExpr))";
    var fontSizeExpr = '${_n(baseSize)}*($scaleExpr)';
    final localT = '(t-${_n(start)})';
    final entryP = "max(0,min(1,$localT/0.45))";
    final exitP = "max(0,min(1,(t-${_n(end - .45)})/0.45))";

    if (legacy == 'credits') {
      y = 'h-$localT*80';
    } else if (legacy == 'starwars') {
      y = 'h-$localT*105';
    }

    switch (entry) {
      case 'fadeIn': alpha = "($alpha)*($entryP)"; break;
      case 'slideLeftIn': x = "-text_w+($entryP)*(w/2+text_w/2)"; break;
      case 'slideRightIn': x = "w-($entryP)*(w/2+text_w/2)"; break;
      case 'slideUpIn': y = "h-($entryP)*(h/2+text_h/2)"; break;
      case 'slideDownIn': y = "-text_h+($entryP)*(h/2+text_h/2)"; break;
      case 'zoomIn': fontSizeExpr = "($fontSizeExpr)*(0.62+0.38*($entryP))"; alpha = "($alpha)*($entryP)"; break;
      case 'popIn': fontSizeExpr = "($fontSizeExpr)*(0.45+0.68*($entryP)-0.13*pow($entryP,2))"; alpha = "($alpha)*($entryP)"; break;
      case 'bounceIn': y = "(h-text_h)/2+(1-($entryP))*95*abs(sin(($entryP)*PI*3))"; alpha = "($alpha)*($entryP)"; break;
      case 'typewriter': alpha = "($alpha)*min(1,($entryP)*1.35)"; x = "(w-text_w)/2-(1-($entryP))*text_w*0.16"; break;
      case 'wipeLeftIn': x = "(w-text_w)/2-(1-($entryP))*90"; alpha = "($alpha)*($entryP)"; break;
      case 'wipeRightIn': x = "(w-text_w)/2+(1-($entryP))*90"; alpha = "($alpha)*($entryP)"; break;
      case 'blurIn': fontSizeExpr = "($fontSizeExpr)*(0.92+0.08*($entryP))"; alpha = "($alpha)*($entryP)"; break;
      case 'rotateIn': alpha = "($alpha)*($entryP)"; break;
      case 'stretchIn': fontSizeExpr = "($fontSizeExpr)*(0.55+0.45*($entryP))"; alpha = "($alpha)*($entryP)"; break;
      case 'scaleFadeIn': fontSizeExpr = "($fontSizeExpr)*(0.72+0.28*($entryP))"; alpha = "($alpha)*($entryP)"; break;
    }

    switch (loop) {
      case 'pulse': fontSizeExpr = "($fontSizeExpr)*(1+0.055*sin($localT*7.5))"; break;
      case 'float': y = "($y)+10*sin($localT*2.2)"; break;
      case 'bounce': y = "($y)-14*abs(sin($localT*3.14159*2))"; break;
      case 'shake': x = "($x)+6*sin($localT*24)"; break;
      case 'breathing': fontSizeExpr = "($fontSizeExpr)*(1+0.035*sin($localT*2))"; break;
      case 'glowPulse': alpha = "($alpha)*(0.84+0.16*(sin($localT*3)+1)/2)"; break;
      case 'slowZoom': fontSizeExpr = "($fontSizeExpr)*(1+0.035*$localT)"; break;
      case 'wave': y = "($y)+8*sin($localT*4)"; break;
      case 'flicker': alpha = "($alpha)*(0.72+0.28*(sin($localT*18)+1)/2)"; break;
      case 'colorPulse': alpha = "($alpha)*(0.90+0.10*(sin($localT*2.7)+1)/2)"; break;
      case 'blurPulse': fontSizeExpr = "($fontSizeExpr)*(1+0.02*sin($localT*3.2))"; break;
      case 'trackingPulse': fontSizeExpr = "($fontSizeExpr)*(1+0.025*sin($localT*2.5))"; break;
    }

    switch (exit) {
      case 'fadeOut': alpha = "($alpha)*(1-($exitP))"; break;
      case 'slideLeftOut': x = "($x)-($exitP)*190"; alpha = "($alpha)*(1-0.35*($exitP))"; break;
      case 'slideRightOut': x = "($x)+($exitP)*190"; alpha = "($alpha)*(1-0.35*($exitP))"; break;
      case 'slideUpOut': y = "($y)-($exitP)*150"; alpha = "($alpha)*(1-0.35*($exitP))"; break;
      case 'slideDownOut': y = "($y)+($exitP)*150"; alpha = "($alpha)*(1-0.35*($exitP))"; break;
      case 'zoomOut': fontSizeExpr = "($fontSizeExpr)*(1-0.55*($exitP))"; alpha = "($alpha)*(1-($exitP))"; break;
      case 'popOut': fontSizeExpr = "($fontSizeExpr)*(1+0.40*($exitP))"; alpha = "($alpha)*(1-($exitP))"; break;
      case 'bounceOut': y = "($y)+sin(($exitP)*PI)*55+($exitP)*120"; alpha = "($alpha)*(1-($exitP))"; break;
      case 'wipeLeftOut': x = "($x)-($exitP)*95"; alpha = "($alpha)*(1-($exitP))"; break;
      case 'wipeRightOut': x = "($x)+($exitP)*95"; alpha = "($alpha)*(1-($exitP))"; break;
      case 'blurOut': fontSizeExpr = "($fontSizeExpr)*(1+0.05*($exitP))"; alpha = "($alpha)*(1-0.55*($exitP))"; break;
      case 'rotateOut': alpha = "($alpha)*(1-($exitP))"; break;
      case 'shrink': fontSizeExpr = "($fontSizeExpr)*(1-0.75*($exitP))"; alpha = "($alpha)*(1-0.50*($exitP))"; break;
      case 'scaleFadeOut': fontSizeExpr = "($fontSizeExpr)*(1-0.40*($exitP))"; alpha = "($alpha)*(1-($exitP))"; break;
      case 'dissolve': alpha = "($alpha)*(1-($exitP))*(0.78+0.22*(sin($localT*30)+1)/2)"; break;
    }

    final box = template == 'box' || template == 'lowerThird' || template == 'subtitle' || template == 'badge';
    final draw = StringBuffer()
      ..write("drawtext=text='${_escapeDrawText(c.text ?? '')}'")
      ..write(":font='${_escapeDrawText(fontFamily)}'")
      ..write(":fontcolor=$color:fontsize='$fontSizeExpr'")
      ..write(":x='$x':y='$y':alpha='$alpha'")
      ..write(":enable='between(t,${_n(start)},${_n(end)})'");
    if (box) draw.write(':box=1:boxcolor=black@0.55:boxborderw=18');
    if (template == 'outline') draw.write(':borderw=3:bordercolor=black@0.9');
    if (template == 'quote') draw.write(':shadowx=3:shadowy=3:shadowcolor=black@0.7');
    return draw.toString();
  }

  String _textRotationExpr(TimelineClip c, String baseExpr, double start, double end) {
    final style = c.style;
    final legacy = (style['animation'] as String?) ?? 'static';
    final entry = (style['entryAnimation'] as String?) ?? 'none';
    final loop = (style['loopAnimation'] as String?) ?? (legacy == 'pulse' ? 'pulse' : 'none');
    final exit = (style['exitAnimation'] as String?) ?? 'none';
    final localT = '(t-${_n(start)})';
    final entryP = "max(0,min(1,$localT/0.45))";
    final exitP = "max(0,min(1,(t-${_n(end - .45)})/0.45))";
    var expr = '($baseExpr)';
    if (entry == 'rotateIn') expr = "($expr)-28*(1-($entryP))";
    if (loop == 'wiggle') expr = "($expr)+3.2*sin($localT*8)";
    if (loop == 'slowRotation') expr = "($expr)+3.2*$localT";
    if (loop == 'sway') expr = "($expr)+2.1*sin($localT*2.1)";
    if (loop == 'wave') expr = "($expr)+1.2*sin($localT*3)";
    if (exit == 'rotateOut') expr = "($expr)+37*($exitP)";
    return expr;
  }

''',
    'TimelineRenderService._drawText',
  );

  file.writeAsStringSync(source);
  stdout.writeln('Advanced text render patched.');
}
