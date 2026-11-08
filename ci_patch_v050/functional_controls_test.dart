import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbita_editor/core/models/orbita_project.dart';
import 'package:orbita_editor/features/editor/widgets/effects_panel.dart';
import 'package:orbita_editor/features/editor/widgets/filter_panel.dart';
import 'package:orbita_editor/features/editor/widgets/transitions_panel.dart';
import 'package:orbita_editor/features/editor/widgets/text_panel.dart';

Widget shell(Widget panel) => MaterialApp(
  home: Scaffold(
    body: SizedBox(width: 540, height: 650, child: panel),
  ),
);

TimelineClip clipOf(String kind) => TimelineClip(
  id: 'functional-$kind',
  name: 'Interaction regression',
  sourcePath: '',
  kind: kind,
  startMs: 0,
  durationMs: 8000,
  text: kind == 'text' ? 'Título editable' : null,
  style: kind == 'text' ? <String, dynamic>{
    'fontFamily': 'Roboto',
    'entryAnimation': 'fadeIn',
    'loopAnimation': 'none',
    'exitAnimation': 'fadeOut',
  } : <String, dynamic>{},
);

void main() {
  testWidgets('Effects switch modifies the selected clip model', (tester) async {
    final clip = clipOf('video');
    var changed = 0;
    await tester.pumpWidget(shell(EffectsPanel(
      clip: clip,
      playheadMs: 1000,
      onChanged: () => changed++,
      onRemoveBackground: () async {},
    )));
    final button = find.widgetWithText(SwitchListTile, 'Granulado');
    expect(button, findsOneWidget);
    await tester.tap(button);
    expect(clip.effects.any((e) => e['type'] == 'grain'), isTrue);
    expect(changed, greaterThan(0));
  });

  testWidgets('Filter control stores a real preset selection', (tester) async {
    final clip = clipOf('video');
    var changed = 0;
    await tester.pumpWidget(shell(FilterPanel(clip: clip, onChanged: () => changed++)));
    final chip = find.widgetWithText(FilterChip, 'Cine');
    expect(chip, findsOneWidget);
    await tester.tap(chip);
    expect(clip.effects.any((e) => e['type'] == 'preset' && e['id'] == 'cinema'), isTrue);
    expect(changed, greaterThan(0));
  });

  testWidgets('Transition switch stores active transition and duration', (tester) async {
    final clip = clipOf('video');
    var changed = 0;
    await tester.pumpWidget(shell(TransitionsPanel(clip: clip, onChanged: () => changed++)));
    final button = find.widgetWithText(SwitchListTile, 'Fundido a negro');
    expect(button, findsOneWidget);
    await tester.tap(button);
    expect(clip.effects.any((e) => e['type'] == 'transition' && e['id'] == 'fadeBlack'), isTrue);
    expect(changed, greaterThan(0));
  });

  testWidgets('Text font selector edits existing clip rather than decorating the UI', (tester) async {
    final clip = clipOf('text');
    var changed = 0;
    await tester.pumpWidget(shell(TextPanel(
      clip: clip,
      onAdd: (value, style) {},
      onChanged: () => changed++,
    )));
    final dropdown = find.byKey(const ValueKey<String>('font-functional-text-Roboto'));
    expect(dropdown, findsOneWidget);
    await tester.tap(dropdown);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Montserrat').last);
    await tester.pumpAndSettle();
    expect(clip.style['fontFamily'], 'Montserrat');
    expect(changed, greaterThan(0));
  });
}
