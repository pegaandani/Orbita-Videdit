@echo off
setlocal EnableExtensions
set "PROJECT=%~1"
if "%PROJECT%"=="" set "PROJECT=videdit_project"
set "FONTS=%PROJECT%\assets\fonts"
if not exist "%FONTS%" mkdir "%FONTS%"

call :get "Roboto.ttf" "https://raw.githubusercontent.com/google/fonts/main/ofl/roboto/Roboto[wdth,wght].ttf" glob
if errorlevel 1 exit /b 1
call :get "OpenSans.ttf" "https://raw.githubusercontent.com/google/fonts/main/ofl/opensans/OpenSans[wdth,wght].ttf" glob
if errorlevel 1 exit /b 1
call :get "Montserrat.ttf" "https://raw.githubusercontent.com/google/fonts/main/ofl/montserrat/Montserrat[wght].ttf" glob
if errorlevel 1 exit /b 1
call :get "Poppins-Regular.ttf" "https://raw.githubusercontent.com/google/fonts/main/ofl/poppins/Poppins-Regular.ttf"
if errorlevel 1 exit /b 1
call :get "Inter.ttf" "https://raw.githubusercontent.com/google/fonts/main/ofl/inter/Inter[opsz,wght].ttf" glob
if errorlevel 1 exit /b 1
call :get "Lato-Regular.ttf" "https://raw.githubusercontent.com/google/fonts/main/ofl/lato/Lato-Regular.ttf"
if errorlevel 1 exit /b 1
call :get "Nunito.ttf" "https://raw.githubusercontent.com/google/fonts/main/ofl/nunito/Nunito[wght].ttf" glob
if errorlevel 1 exit /b 1
call :get "Raleway.ttf" "https://raw.githubusercontent.com/google/fonts/main/ofl/raleway/Raleway[wght].ttf" glob
if errorlevel 1 exit /b 1
call :get "Oswald.ttf" "https://raw.githubusercontent.com/google/fonts/main/ofl/oswald/Oswald[wght].ttf" glob
if errorlevel 1 exit /b 1
call :get "SourceSans3-Regular.ttf" "https://raw.githubusercontent.com/adobe-fonts/source-sans/release/TTF/SourceSans3-Regular.ttf"
if errorlevel 1 exit /b 1
call :get "Ubuntu-Regular.ttf" "https://raw.githubusercontent.com/google/fonts/main/ufl/ubuntu/Ubuntu-Regular.ttf"
if errorlevel 1 exit /b 1
call :get "Merriweather.ttf" "https://raw.githubusercontent.com/google/fonts/main/ofl/merriweather/Merriweather[opsz,wdth,wght].ttf" glob
if errorlevel 1 exit /b 1
call :get "PlayfairDisplay.ttf" "https://raw.githubusercontent.com/google/fonts/main/ofl/playfairdisplay/PlayfairDisplay[wght].ttf" glob
if errorlevel 1 exit /b 1
call :get "BebasNeue-Regular.ttf" "https://raw.githubusercontent.com/google/fonts/main/ofl/bebasneue/BebasNeue-Regular.ttf"
if errorlevel 1 exit /b 1
call :get "Caveat.ttf" "https://raw.githubusercontent.com/google/fonts/main/ofl/caveat/Caveat[wght].ttf" glob
if errorlevel 1 exit /b 1

echo All 15 bundled fonts downloaded.
exit /b 0

:get
set "NAME=%~1"
set "URL=%~2"
set "MODE=%~3"
if /I "%MODE%"=="glob" (
  curl.exe --globoff -L --fail --retry 3 -o "%FONTS%\%NAME%" "%URL%"
) else (
  curl.exe -L --fail --retry 3 -o "%FONTS%\%NAME%" "%URL%"
)
if errorlevel 1 exit /b 1
if not exist "%FONTS%\%NAME%" exit /b 1
for %%F in ("%FONTS%\%NAME%") do if %%~zF LSS 1024 exit /b 1
exit /b 0
