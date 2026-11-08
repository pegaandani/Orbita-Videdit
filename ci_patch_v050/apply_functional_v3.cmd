@echo off
setlocal EnableExtensions
set "PROJECT=%~1"
if "%PROJECT%"=="" set "PROJECT=videdit_project"

if not exist "%PROJECT%\pubspec.yaml" (
  echo Project not found: %PROJECT%
  exit /b 2
)

copy /Y "ci_patch\media_import_service.dart" "%PROJECT%\lib\core\services\media_import_service.dart" >nul
if errorlevel 1 exit /b 1

type "ci_patch_v050\functional_v2.diff.gz.b64.part0" "ci_patch_v050\functional_v2.diff.gz.b64.part1" "ci_patch_v050\functional_v2.diff.gz.b64.part2" > "%TEMP%\functional_v2.diff.gz.b64"
if errorlevel 1 exit /b 1
certutil -f -decode "%TEMP%\functional_v2.diff.gz.b64" "%TEMP%\functional_v2.diff.gz" >nul
if errorlevel 1 exit /b 1
powershell.exe -NoProfile -ExecutionPolicy Bypass -Command "$in=[IO.File]::OpenRead('%TEMP%\functional_v2.diff.gz'); $gz=New-Object IO.Compression.GzipStream($in,[IO.Compression.CompressionMode]::Decompress); $out=[IO.File]::Create('%TEMP%\functional_v2.diff'); $gz.CopyTo($out); $out.Dispose(); $gz.Dispose(); $in.Dispose()"
if errorlevel 1 exit /b 1

git apply --check --directory="%PROJECT%" "%TEMP%\functional_v2.diff"
if errorlevel 1 exit /b 1
git apply --directory="%PROJECT%" "%TEMP%\functional_v2.diff"
if errorlevel 1 exit /b 1

copy /Y "ci_patch_v050\project_file_service_v2.dart" "%PROJECT%\lib\core\services\project_file_service.dart" >nul
if errorlevel 1 exit /b 1
copy /Y "ci_patch_v050\autosave_service_v2.dart" "%PROJECT%\lib\core\services\autosave_service.dart" >nul
if errorlevel 1 exit /b 1

set "DART=C:\actions-runner\orbita-flutter\flutter\bin\dart.bat"
if not exist "%DART%" set "DART=dart"
call %DART% "ci_patch_v050\patch_windows_export.dart" "%PROJECT%"
if errorlevel 1 exit /b 1
call %DART% "ci_patch_v050\patch_text_export.dart" "%PROJECT%"
if errorlevel 1 exit /b 1
call %DART% "ci_patch_v050\patch_project_recovery.dart" "%PROJECT%"
if errorlevel 1 exit /b 1
call %DART% "ci_patch_v050\patch_control_fidelity.dart" "%PROJECT%"
if errorlevel 1 exit /b 1
call %DART% "ci_patch_v050\patch_export_validation.dart" "%PROJECT%"
if errorlevel 1 exit /b 1

python "ci_patch_v050\patch_theme_palette.py" "%PROJECT%"
if errorlevel 1 exit /b 1
python "ci_patch_v050\patch_export_destination.py" "%PROJECT%"
if errorlevel 1 exit /b 1
python "ci_patch_v050\patch_android_save_as.py" "%PROJECT%"
if errorlevel 1 exit /b 1
python "ci_patch_v050\patch_ui_quality.py" "%PROJECT%"
if errorlevel 1 exit /b 1
python "ci_patch_v050\patch_outro_fade.py" "%PROJECT%"
if errorlevel 1 exit /b 1
python "ci_patch_v050\patch_android_export_reliability.py" "%PROJECT%"
if errorlevel 1 exit /b 1
python "ci_patch_v050\patch_version_60.py" "%PROJECT%"
if errorlevel 1 exit /b 1
python "ci_patch_v050\patch_android_ffmpeg_arguments.py" "%PROJECT%"
if errorlevel 1 exit /b 1
python "ci_patch_v050\patch_effect_timing_and_intensity.py" "%PROJECT%"
if errorlevel 1 exit /b 1

if not exist "%PROJECT%\test" mkdir "%PROJECT%\test"
copy /Y "ci_patch_v050\functional_persistence_test.dart" "%PROJECT%\test\functional_persistence_test.dart" >nul
if errorlevel 1 exit /b 1
copy /Y "ci_patch_v050\functional_export_smoke_test.dart" "%PROJECT%\test\functional_export_smoke_test.dart" >nul
if errorlevel 1 exit /b 1
copy /Y "ci_patch_v050\functional_controls_test.dart" "%PROJECT%\test\functional_controls_test.dart" >nul
if errorlevel 1 exit /b 1

if not exist "%PROJECT%\tool" mkdir "%PROJECT%\tool"
copy /Y "ci_patch_v050\functional_media_cli.dart" "%PROJECT%\tool\functional_media_cli.dart" >nul
if errorlevel 1 exit /b 1
copy /Y "ci_patch_v050\functional_media_native_test.dart" "%PROJECT%\test\functional_media_native_test.dart" >nul
if errorlevel 1 exit /b 1

echo Orbita Videdit functional V3 patches applied successfully.
exit /b 0
