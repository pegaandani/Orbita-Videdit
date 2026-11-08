from pathlib import Path
import sys

root=Path(sys.argv[1] if len(sys.argv)>1 else "videdit_project")
file=root/"lib/core/services/timeline_render_service.dart"
source=file.read_text(encoding="utf-8")
old="""      final command = commandArgs.map(_ffmpegKitArg).join(' ');
      final session = await FFmpegKit.executeAsync(
        command,"""
new="""      // Never convert a complex FFmpeg filter graph to a shell command string.
      // FFmpegKit's string parser can split commas, colons, escaped quotes,
      // space-containing paths, and nested drawtext/overlay expressions.
      // List arguments preserve each -filter_complex value and file path intact.
      final session = await FFmpegKit.executeWithArgumentsAsync(
        commandArgs,"""
if source.count(old)!=1:
    raise RuntimeError(f"Expected FFmpegKit command string anchor exactly once; found {source.count(old)}")
source=source.replace(old,new,1)

# executeWithArgumentsAsync starts work but its Future resolves as soon as
# the session is created, NOT once encoding is done. Previously the application
# immediately checked the not-yet-set return code and reported a failure at 5%.
# Only the FFmpegSessionCompleteCallback guarantees encoding has finished.
before="""      final session = await FFmpegKit.executeWithArgumentsAsync(
        commandArgs,
        (_) {},
        (_) {},
        (stats) {"""
after="""      final finished = Completer<void>();
      final session = await FFmpegKit.executeWithArgumentsAsync(
        commandArgs,
        (_) {
          if (!finished.isCompleted) finished.complete();
        },
        (_) {},
        (stats) {"""
if source.count(before)!=1:
    raise RuntimeError("Android FFmpeg completion callback anchor not found")
source=source.replace(before,after,1)
before="""      final rc = await session.getReturnCode();
      if (!ReturnCode.isSuccess(rc)) {"""
after="""      // Wait for FFmpeg to close MP4 containers and flush their metadata.
      await finished.future.timeout(const Duration(minutes: 40));
      final rc = await session.getReturnCode();
      if (!ReturnCode.isSuccess(rc)) {"""
if source.count(before)!=1:
    raise RuntimeError("FFmpeg return-code timing anchor not found")
source=source.replace(before,after,1)
if "import 'dart:async';" not in source:
    source="import 'dart:async';\n"+source
file.write_text(source,encoding="utf-8")
print("Android FFmpegKit now waits for actual session completion before checking the return code and final MP4.")
