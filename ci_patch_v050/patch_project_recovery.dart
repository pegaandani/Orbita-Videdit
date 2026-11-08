import 'dart:io';

void main(List<String> args) {
  if (args.isEmpty) {
    stderr.writeln('Usage: dart patch_project_recovery.dart <videdit_project>');
    exit(2);
  }
  final sep = Platform.pathSeparator;
  final file = File('${args.first}${sep}lib${sep}features${sep}editor${sep}editor_screen.dart');
  var source = file.readAsStringSync().replaceAll('\r\n', '\n');

  void replaceRequired(String oldValue, String newValue, String label) {
    if (!source.contains(oldValue)) {
      stderr.writeln('Required editor block not found: $label');
      exit(3);
    }
    source = source.replaceFirst(oldValue, newValue);
  }

  replaceRequired(
    '''    autosave.start(() => project);
    unawaited(_loadVisual());
  }

  Future<void> _loadVisual() async {
''',
    '''    autosave.start(() => project);
    unawaited(_loadVisual());
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(_offerRecoveryIfAvailable());
    });
  }

  Future<void> _loadVisual() async {
''',
    'startup recovery hook',
  );

  const methodsMarker = '''  @override
  void dispose() {
''';
  const methods = r'''  bool get _projectHasContent =>
      project.media.isNotEmpty || project.tracks.any((track) => track.clips.isNotEmpty);

  Future<void> _replaceProject(OrbitaProject loaded, String message) async {
    await _pause();
    if (!mounted) return;
    setState(() {
      project = loaded;
      selectedTrackId = null;
      selectedClipId = null;
      _multiSelection.clear();
      _multiSelectMode = false;
      _undo.clear();
      _redo.clear();
      playheadMs = 0;
      currentPreviewClipId = null;
      status = message;
    });
    await _syncPlayerToTimeline(play: false);
  }

  Future<void> _newProject() async {
    if (_projectHasContent) {
      final create = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Nuevo proyecto'),
          content: const Text(
            'Se abrirá un proyecto vacío. El proyecto actual ya tiene una recuperación automática por seguridad.',
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
            FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Crear')),
          ],
        ),
      );
      if (create != true) return;
      await autosave.saveRecovery(project);
    }
    await _replaceProject(OrbitaProject.empty(), 'Nuevo proyecto');
  }

  Future<void> _openProject() async {
    try {
      if (_projectHasContent) await autosave.saveRecovery(project);
      final loaded = await files.pickAndOpen();
      if (loaded == null) return;
      await _replaceProject(loaded, 'Proyecto abierto · ${loaded.name}');
    } catch (error) {
      if (mounted) setState(() => status = 'No se pudo abrir el proyecto: $error');
    }
  }

  Future<void> _offerRecoveryIfAvailable() async {
    try {
      final candidates = await autosave.latestRecoveries(limit: 8);
      if (!mounted || candidates.isEmpty || _projectHasContent) return;
      File? newest;
      OrbitaProject? recovered;
      for (final candidate in candidates) {
        final parsed = await autosave.readRecovery(candidate);
        if (parsed == null) continue;
        final hasContent = parsed.media.isNotEmpty || parsed.tracks.any((track) => track.clips.isNotEmpty);
        if (!hasContent) continue;
        newest = candidate;
        recovered = parsed;
        break;
      }
      if (!mounted || newest == null || recovered == null) return;
      final modified = await newest.lastModified();
      final stamp = '${modified.day.toString().padLeft(2, '0')}/'
          '${modified.month.toString().padLeft(2, '0')}/${modified.year} '
          '${modified.hour.toString().padLeft(2, '0')}:'
          '${modified.minute.toString().padLeft(2, '0')}';
      final restore = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
          title: const Text('Recuperar trabajo'),
          content: Text(
            'Encontré un autoguardado de “${recovered!.name}” del $stamp. '
            '¿Quieres restaurarlo?',
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Ignorar')),
            FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Restaurar')),
          ],
        ),
      );
      if (restore == true && mounted) {
        await _replaceProject(recovered, 'Sesión recuperada · ${recovered.name}');
      }
    } catch (_) {
      // A damaged recovery must never prevent the editor from opening.
    }
  }

''';
  replaceRequired(methodsMarker, '$methods$methodsMarker', 'project/recovery methods');

  const duplicateDispose = '''    _audioVerticalScroll.dispose();
    super.dispose();
    super.dispose();
  }
''';
  const safeDispose = '''    _audioVerticalScroll.dispose();
    super.dispose();
  }
''';
  if (source.contains(duplicateDispose)) {
    source = source.replaceFirst(duplicateDispose, safeDispose);
  } else if (!source.contains(safeDispose)) {
    stderr.writeln('Required editor block not found: safe dispose');
    exit(3);
  }

  replaceRequired(
    '''            const SizedBox(width: 8),
            IconButton(tooltip: 'Guardar proyecto', onPressed: _save, icon: const Icon(Icons.save_outlined)),
            Padding(
''',
    '''            const SizedBox(width: 8),
            IconButton(tooltip: 'Nuevo proyecto', onPressed: _newProject, icon: const Icon(Icons.note_add_outlined)),
            IconButton(tooltip: 'Abrir proyecto', onPressed: _openProject, icon: const Icon(Icons.folder_open_outlined)),
            IconButton(tooltip: 'Guardar proyecto', onPressed: _save, icon: const Icon(Icons.save_outlined)),
            Padding(
''',
    'project action buttons',
  );

  file.writeAsStringSync(source);
  stdout.writeln('Editor patched with new/open project flow, autosave recovery UI, and safe dispose.');
}
