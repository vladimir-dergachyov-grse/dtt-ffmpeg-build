@echo off
REM ===========================================================================
REM  Launcher: builds strictly-LGPL shared FFmpeg for Windows 10+ (x64)
REM  via the MSYS2 MINGW64 toolchain. Run from cmd or PowerShell, or
REM  double-click. Adjust MSYS2_ROOT below if MSYS2 is installed elsewhere.
REM ===========================================================================
setlocal
set "MSYS2_ROOT=C:\msys64"
if not exist "%MSYS2_ROOT%\usr\bin\bash.exe" (
    echo ERROR: MSYS2 not found at %MSYS2_ROOT%.
    echo Install it with:  winget install MSYS2.MSYS2
    exit /b 1
)

set "MSYSTEM=MINGW64"
set "CHERE_INVOKING=1"
set "SCRIPT_DIR=%~dp0"

REM Translate the script's Windows path to an MSYS2 path and run it in MINGW64.
"%MSYS2_ROOT%\usr\bin\bash.exe" -lc "cd \"$(cygpath -u '%SCRIPT_DIR%')\" && ./build-ffmpeg-lgpl.sh"

endlocal
