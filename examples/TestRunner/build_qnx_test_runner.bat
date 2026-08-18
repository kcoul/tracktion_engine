@echo off
setlocal enabledelayedexpansion

rem Cross-builds the TestRunner for QNX using the compiler from the QNX SDP.
rem
rem The engine and JUCE are compiled as their unity files directly, without
rem CMake, which keeps the QNX build to a single script with no toolchain file
rem to keep in sync. Pass the SDP target as the first argument, e.g.
rem
rem   build_qnx_test_runner.bat 12.2.0,gcc_ntoaarch64le
rem
rem The SDP environment is taken from %QNX_SDP_ENV%, or from
rem %USERPROFILE%\qnx800\qnxsdp-env.bat if that is not set. If the environment
rem is already set up, it is left alone.

set "TARGET=%~1"
if "%TARGET%"=="" set "TARGET=12.2.0,gcc_ntoaarch64le"

set "ROOT=%~dp0..\.."
for %%I in ("%ROOT%") do set "ROOT=%%~fI"
set "JUCE_DIR=%ROOT%\modules\juce"

if not defined QNX_HOST (
    if not defined QNX_SDP_ENV set "QNX_SDP_ENV=%USERPROFILE%\qnx800\qnxsdp-env.bat"

    if not exist "!QNX_SDP_ENV!" (
        echo Cannot find the QNX SDP environment script at !QNX_SDP_ENV!.>&2
        echo Set QNX_SDP_ENV to its location, or run it before this script.>&2
        exit /b 1
    )

    call "!QNX_SDP_ENV!"
    if errorlevel 1 exit /b 1

    rem The SDP environment script turns command echo back on.
    @echo off
)

if not defined QNX_TARGET (
    echo QNX_TARGET is not set. Run the QNX SDP environment script first.>&2
    exit /b 1
)

if not exist "%JUCE_DIR%\modules\juce_core\juce_core.cpp" (
    echo modules\juce is empty. Run: git submodule update --init --recursive>&2
    exit /b 1
)

set "TARGET_DIR=%TARGET:,=_%"
set "BUILD_DIR=%ROOT%\build\qnx_test_runner\%TARGET_DIR%"
if not exist "%BUILD_DIR%" mkdir "%BUILD_DIR%"

set "ENGINE_VERSION=unknown"
set "JUCE_VERSION=unknown"
for /f "delims=" %%V in ('git -C "%ROOT%" describe --tags --always --dirty 2^>nul') do set "ENGINE_VERSION=%%V"
for /f "delims=" %%V in ('git -C "%JUCE_DIR%" describe --tags --always --dirty 2^>nul') do set "JUCE_VERSION=%%V"

> "%BUILD_DIR%\GeneratedBuildVersion.h" (
    echo #pragma once
    echo #define TRACKTION_QNX_TEST_RUNNER_ENGINE_VERSION "!ENGINE_VERSION!"
    echo #define TRACKTION_QNX_TEST_RUNNER_JUCE_VERSION   "!JUCE_VERSION!"
)

rem The include paths and defines below mirror JUCE's QNX toolchain file, at
rem extras\Build\CMake\QNXAarch64Toolchain.cmake, so that the two builds see
rem the same platform. qnx_compat carries the headers the SDP does not ship.
set "QNX_COMPAT_INCLUDE_DIR=%JUCE_DIR%\extras\Build\CMake\qnx_compat\include"
set "QNX_FREETYPE_INCLUDE_DIR=%QNX_TARGET%\usr\include\freetype2"
set "QNX_FREETYPE_LIBRARY=%QNX_TARGET%\aarch64le\usr\lib\libfreetype.so.24"
set QNX_FLAGS=-I"%QNX_COMPAT_INCLUDE_DIR%" -I"%QNX_FREETYPE_INCLUDE_DIR%" -D_QNX_SOURCE -D__EXT_QNX -D__EXT_UNIX_MISC

set COMMON=-V%TARGET% -std=gnu++20 %QNX_FLAGS% -include strings.h -DM_PI=3.14159265358979323846 -DJUCE_GLOBAL_MODULE_SETTINGS_INCLUDED=1 -DJUCE_USE_CURL=0 -DJUCE_WEB_BROWSER=0 -DJUCE_JACK=0 -DJUCE_ALSA=1 -DJUCE_USE_FONTCONFIG=0 -DJUCE_MODAL_LOOPS_PERMITTED=1 -DJUCE_STRICT_REFCOUNTEDPOINTER=1 -DJUCE_PLUGINHOST_AU=1 -DJUCE_PLUGINHOST_LADSPA=1 -DJUCE_PLUGINHOST_VST3=1 -DTRACKTION_UNIT_TESTS=1 -DTRACKTION_LOG_DEVICES=0 -DTRACKTION_ENABLE_TIMESTRETCH_SOUNDTOUCH=1 -DTRACKTION_ENABLE_TIMESTRETCH_RUBBERBAND=0 -DTRACKTION_BUILD_RUBBERBAND=0 -I"%ROOT%" -I"%ROOT%\modules" -I"%JUCE_DIR%\modules" -I"%ROOT%\examples\TestRunner" -I"%ROOT%\examples\TestRunner\qnx" -I"%BUILD_DIR%"

rem The vendored C dependencies (SheenBidi, and on JUCE 9 also pnglib, libjpeg
rem and lunasvg) are compiled from the C unity files at the root of their module.
set C_COMMON=-V%TARGET% %QNX_FLAGS% -DJUCE_GLOBAL_MODULE_SETTINGS_INCLUDED=1 -I"%ROOT%" -I"%ROOT%\modules" -I"%JUCE_DIR%\modules" -I"%BUILD_DIR%"

set "OBJECTS="

rem Each module is built from the unity files at the root of its directory, so a
rem module that is split into several of them - juce_gui_basics is five - needs no
rem change here, and neither do the differences between JUCE versions.
for %%M in (
    juce_core
    juce_events
    juce_graphics
    juce_data_structures
    juce_gui_basics
    juce_gui_extra
    juce_audio_basics
    juce_audio_devices
    juce_audio_formats
    juce_audio_processors
    juce_audio_processors_headless
    juce_audio_utils
    juce_dsp
    juce_osc
) do (
    for %%F in ("%JUCE_DIR%\modules\%%M\%%M*.cpp") do (
        echo Compiling %%~nxF
        q++ %COMMON% -c "%%~fF" -o "%BUILD_DIR%\%%~nF.o" || exit /b 1
        set OBJECTS=!OBJECTS! "%BUILD_DIR%\%%~nF.o"
    )

    for %%F in ("%JUCE_DIR%\modules\%%M\%%M*.c") do (
        echo Compiling %%~nxF
        qcc %C_COMMON% -c "%%~fF" -o "%BUILD_DIR%\%%~nF.o" || exit /b 1
        set OBJECTS=!OBJECTS! "%BUILD_DIR%\%%~nF.o"
    )
)

for %%M in (
    tracktion_core
    tracktion_graph
    tracktion_engine
) do (
    for %%F in ("%ROOT%\modules\%%M\%%M*.cpp") do (
        echo Compiling %%~nxF
        q++ %COMMON% -c "%%~fF" -o "%BUILD_DIR%\%%~nF.o" || exit /b 1
        set OBJECTS=!OBJECTS! "%BUILD_DIR%\%%~nF.o"
    )

    for %%F in ("%ROOT%\modules\%%M\%%M*.c") do (
        echo Compiling %%~nxF
        qcc %C_COMMON% -c "%%~fF" -o "%BUILD_DIR%\%%~nF.o" || exit /b 1
        set OBJECTS=!OBJECTS! "%BUILD_DIR%\%%~nF.o"
    )
)

echo Compiling TestRunner.cpp
q++ %COMMON% -c "%ROOT%\examples\TestRunner\TestRunner.cpp" -o "%BUILD_DIR%\TestRunner.o" || exit /b 1
set OBJECTS=!OBJECTS! "%BUILD_DIR%\TestRunner.o"

echo Linking TestRunner
q++ -V%TARGET% !OBJECTS! "%QNX_FREETYPE_LIBRARY%" -lscreen -lasound -lsocket -lz -lexpat -latomic -o "%BUILD_DIR%\TestRunner" || exit /b 1

echo Built: %BUILD_DIR%\TestRunner
