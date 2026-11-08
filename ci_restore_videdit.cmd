@echo off
setlocal EnableExtensions EnableDelayedExpansion
set "PARTS=videdit_ci_parts"
set "ENC=videdit_source.b64"
set "ARCHIVE=videdit_build_min.tar.xz"
set "OUT=videdit_project"
set "EXPECTED=80215bf9e018c2980fbc0dba7d210ba348025162ad05b96ef95c761d2da64c86"

del /Q "%ENC%" "%ARCHIVE%" 2>nul
if exist "%OUT%" rmdir /S /Q "%OUT%"

for /L %%I in (0,1,19) do (
  set "N=0%%I"
  set "N=!N:~-2!"
  type "%PARTS%\c!N!.b64" >> "%ENC%" || exit /b 1
)

type "%PARTS%\c20a.b64" >> "%ENC%" || exit /b 1
type "%PARTS%\c20b1.b64" >> "%ENC%" || exit /b 1
type "%PARTS%\c20b2.b64" >> "%ENC%" || exit /b 1

for /L %%I in (21,1,23) do (
  type "%PARTS%\c%%Ia.b64" >> "%ENC%" || exit /b 1
  type "%PARTS%\c%%Ib.b64" >> "%ENC%" || exit /b 1
)

type "%PARTS%\c24a.b64" >> "%ENC%" || exit /b 1
type "%PARTS%\c24b_00.b64" >> "%ENC%" || exit /b 1
type "%PARTS%\c24b_01.b64" >> "%ENC%" || exit /b 1

for %%H in (c24b_02_00.hex c24b_02_01.hex c24b_03_00.hex c24b_03_01.hex) do (
  certutil -f -decodehex "%PARTS%\%%H" "%TEMP%\%%H.txt" 12 >nul || exit /b 1
  type "%TEMP%\%%H.txt" >> "%ENC%" || exit /b 1
  del /Q "%TEMP%\%%H.txt" 2>nul
)

for /L %%I in (25,1,28) do (
  type "%PARTS%\c%%Ia.b64" >> "%ENC%" || exit /b 1
  type "%PARTS%\c%%Ib.b64" >> "%ENC%" || exit /b 1
)

for /L %%I in (29,1,32) do (
  type "%PARTS%\c%%Ia_0.b64" >> "%ENC%" || exit /b 1
  type "%PARTS%\c%%Ia_1.b64" >> "%ENC%" || exit /b 1
  type "%PARTS%\c%%Ib_0.b64" >> "%ENC%" || exit /b 1
  type "%PARTS%\c%%Ib_1.b64" >> "%ENC%" || exit /b 1
)

certutil -f -decode "%ENC%" "%ARCHIVE%" >nul || exit /b 1

set "ACTUAL="
for /f "tokens=* delims=" %%H in ('certutil -hashfile "%ARCHIVE%" SHA256 ^| findstr /R /C:"^[0-9A-Fa-f][0-9A-Fa-f]*$"') do set "ACTUAL=%%H"
set "ACTUAL=!ACTUAL: =!"
echo Reconstructed archive SHA256: !ACTUAL!
if /I not "!ACTUAL!"=="%EXPECTED%" (
  echo SHA256 mismatch. Expected %EXPECTED%, got !ACTUAL!
  exit /b 1
)

mkdir "%OUT%" || exit /b 1
tar.exe -xf "%ARCHIVE%" -C "%OUT%" || exit /b 1

if not exist "%OUT%\pubspec.yaml" exit /b 1
if not exist "%OUT%\lib" exit /b 1
if not exist "%OUT%\android" exit /b 1
if not exist "%OUT%\windows" exit /b 1
if not exist "%OUT%\assets\orbita_app_icon_1024.png" exit /b 1

echo Orbita Videdit v0.5.0 source restored and verified.
exit /b 0
