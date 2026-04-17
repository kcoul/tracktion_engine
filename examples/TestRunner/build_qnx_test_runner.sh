#!/usr/bin/env bash
set -euo pipefail

source /Users/kicoulter/qnx800/qnxsdp-env.sh

TARGET="${1:-12.2.0,gcc_ntoaarch64le}"
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")"/../.. && pwd)"
TARGET_DIR="${TARGET//,/_}"
BUILD_DIR="$ROOT/build/qnx_test_runner/$TARGET_DIR"
GENERATED_HEADER="$BUILD_DIR/GeneratedBuildVersion.h"
QNX_HEADER_DIR="$ROOT/examples/TestRunner/qnx"

mkdir -p "$BUILD_DIR"

cmake -DROOT="$ROOT" -DOUTPUT_HEADER="$GENERATED_HEADER" -P "$ROOT/examples/TestRunner/qnx/cmake/GenerateBuildVersion.cmake"

COMMON=(
  "-V${TARGET}"
  -std=gnu++20
  -DJUCE_GLOBAL_MODULE_SETTINGS_INCLUDED=1
  -DJUCE_USE_CURL=0
  -DJUCE_WEB_BROWSER=0
  -DJUCE_JACK=0
  -DJUCE_ALSA=1
  -DJUCE_USE_FONTCONFIG=0
  -DJUCE_MODAL_LOOPS_PERMITTED=1
  -DJUCE_STRICT_REFCOUNTEDPOINTER=1
  -DJUCE_PLUGINHOST_AU=1
  -DJUCE_PLUGINHOST_LADSPA=1
  -DJUCE_PLUGINHOST_VST3=1
  -DTRACKTION_UNIT_TESTS=1
  -DTRACKTION_LOG_DEVICES=0
  -DTRACKTION_ENABLE_TIMESTRETCH_SOUNDTOUCH=1
  -DTRACKTION_ENABLE_TIMESTRETCH_RUBBERBAND=0
  -DTRACKTION_BUILD_RUBBERBAND=0
  -I"$ROOT"
  -I"$ROOT/modules"
  -I"$ROOT/modules/juce/modules"
  -I"$ROOT/examples/TestRunner"
  -I"$QNX_HEADER_DIR"
  -I"$BUILD_DIR"
)

q++ "${COMMON[@]}" -c "$ROOT/modules/juce/modules/juce_core/juce_core.cpp" -o "$BUILD_DIR/juce_core.o"
q++ "${COMMON[@]}" -c "$ROOT/modules/juce/modules/juce_core/juce_core_CompilationTime.cpp" -o "$BUILD_DIR/juce_core_CompilationTime.o"
q++ "${COMMON[@]}" -c "$ROOT/modules/juce/modules/juce_events/juce_events.cpp" -o "$BUILD_DIR/juce_events.o"
q++ "${COMMON[@]}" -c "$ROOT/modules/juce/modules/juce_graphics/juce_graphics.cpp" -o "$BUILD_DIR/juce_graphics.o"
q++ "${COMMON[@]}" -c "$ROOT/modules/juce/modules/juce_graphics/juce_graphics_Harfbuzz.cpp" -o "$BUILD_DIR/juce_graphics_Harfbuzz.o"
qcc "-V${TARGET}" -DSB_CONFIG_UNITY=1 -I"$ROOT/modules/juce" -I"$ROOT/modules/juce/modules" -c "$ROOT/modules/juce/modules/juce_graphics/unicode/sheenbidi/Source/SheenBidi.c" -o "$BUILD_DIR/SheenBidi.o"
q++ "${COMMON[@]}" -c "$ROOT/modules/juce/modules/juce_data_structures/juce_data_structures.cpp" -o "$BUILD_DIR/juce_data_structures.o"
q++ "${COMMON[@]}" -c "$ROOT/modules/juce/modules/juce_gui_basics/juce_gui_basics.cpp" -o "$BUILD_DIR/juce_gui_basics.o"
q++ "${COMMON[@]}" -c "$ROOT/modules/juce/modules/juce_gui_extra/juce_gui_extra.cpp" -o "$BUILD_DIR/juce_gui_extra.o"
q++ "${COMMON[@]}" -c "$ROOT/modules/juce/modules/juce_audio_basics/juce_audio_basics.cpp" -o "$BUILD_DIR/juce_audio_basics.o"
q++ "${COMMON[@]}" -c "$ROOT/modules/juce/modules/juce_audio_devices/juce_audio_devices.cpp" -o "$BUILD_DIR/juce_audio_devices.o"
q++ "${COMMON[@]}" -c "$ROOT/modules/juce/modules/juce_audio_formats/juce_audio_formats.cpp" -o "$BUILD_DIR/juce_audio_formats.o"
q++ "${COMMON[@]}" -c "$ROOT/modules/juce/modules/juce_audio_processors/juce_audio_processors.cpp" -o "$BUILD_DIR/juce_audio_processors.o"
q++ "${COMMON[@]}" -c "$ROOT/modules/juce/modules/juce_audio_processors_headless/juce_audio_processors_headless.cpp" -o "$BUILD_DIR/juce_audio_processors_headless.o"
q++ "${COMMON[@]}" -c "$ROOT/modules/juce/modules/juce_audio_utils/juce_audio_utils.cpp" -o "$BUILD_DIR/juce_audio_utils.o"
q++ "${COMMON[@]}" -c "$ROOT/modules/juce/modules/juce_dsp/juce_dsp.cpp" -o "$BUILD_DIR/juce_dsp.o"
q++ "${COMMON[@]}" -c "$ROOT/modules/juce/modules/juce_osc/juce_osc.cpp" -o "$BUILD_DIR/juce_osc.o"

q++ "${COMMON[@]}" -c "$ROOT/modules/tracktion_core/tracktion_core.cpp" -o "$BUILD_DIR/tracktion_core.o"
q++ "${COMMON[@]}" -c "$ROOT/modules/tracktion_graph/tracktion_graph.cpp" -o "$BUILD_DIR/tracktion_graph.o"
q++ "${COMMON[@]}" -c "$ROOT/modules/tracktion_engine/tracktion_engine_playback.cpp" -o "$BUILD_DIR/tracktion_engine_playback.o"
q++ "${COMMON[@]}" -c "$ROOT/modules/tracktion_engine/tracktion_engine_model_1.cpp" -o "$BUILD_DIR/tracktion_engine_model_1.o"
q++ "${COMMON[@]}" -c "$ROOT/modules/tracktion_engine/tracktion_engine_model_2.cpp" -o "$BUILD_DIR/tracktion_engine_model_2.o"
q++ "${COMMON[@]}" -c "$ROOT/modules/tracktion_engine/tracktion_engine_plugins.cpp" -o "$BUILD_DIR/tracktion_engine_plugins.o"
q++ "${COMMON[@]}" -c "$ROOT/modules/tracktion_engine/tracktion_engine_audio_files.cpp" -o "$BUILD_DIR/tracktion_engine_audio_files.o"
q++ "${COMMON[@]}" -c "$ROOT/modules/tracktion_engine/tracktion_engine_timestretch.cpp" -o "$BUILD_DIR/tracktion_engine_timestretch.o"
q++ "${COMMON[@]}" -c "$ROOT/modules/tracktion_engine/tracktion_engine_utils.cpp" -o "$BUILD_DIR/tracktion_engine_utils.o"
q++ "${COMMON[@]}" -c "$ROOT/modules/tracktion_engine/tracktion_engine_airwindows_1.cpp" -o "$BUILD_DIR/tracktion_engine_airwindows_1.o"
q++ "${COMMON[@]}" -c "$ROOT/modules/tracktion_engine/tracktion_engine_airwindows_2.cpp" -o "$BUILD_DIR/tracktion_engine_airwindows_2.o"
q++ "${COMMON[@]}" -c "$ROOT/modules/tracktion_engine/tracktion_engine_airwindows_3.cpp" -o "$BUILD_DIR/tracktion_engine_airwindows_3.o"

q++ "${COMMON[@]}" -c "$ROOT/examples/TestRunner/TestRunner.cpp" -o "$BUILD_DIR/TestRunner.o"

q++ "-V${TARGET}" \
  "$BUILD_DIR/juce_core.o" \
  "$BUILD_DIR/juce_core_CompilationTime.o" \
  "$BUILD_DIR/juce_events.o" \
  "$BUILD_DIR/juce_graphics.o" \
  "$BUILD_DIR/juce_graphics_Harfbuzz.o" \
  "$BUILD_DIR/SheenBidi.o" \
  "$BUILD_DIR/juce_data_structures.o" \
  "$BUILD_DIR/juce_gui_basics.o" \
  "$BUILD_DIR/juce_gui_extra.o" \
  "$BUILD_DIR/juce_audio_basics.o" \
  "$BUILD_DIR/juce_audio_devices.o" \
  "$BUILD_DIR/juce_audio_formats.o" \
  "$BUILD_DIR/juce_audio_processors.o" \
  "$BUILD_DIR/juce_audio_processors_headless.o" \
  "$BUILD_DIR/juce_audio_utils.o" \
  "$BUILD_DIR/juce_dsp.o" \
  "$BUILD_DIR/juce_osc.o" \
  "$BUILD_DIR/tracktion_core.o" \
  "$BUILD_DIR/tracktion_graph.o" \
  "$BUILD_DIR/tracktion_engine_playback.o" \
  "$BUILD_DIR/tracktion_engine_model_1.o" \
  "$BUILD_DIR/tracktion_engine_model_2.o" \
  "$BUILD_DIR/tracktion_engine_plugins.o" \
  "$BUILD_DIR/tracktion_engine_audio_files.o" \
  "$BUILD_DIR/tracktion_engine_timestretch.o" \
  "$BUILD_DIR/tracktion_engine_utils.o" \
  "$BUILD_DIR/tracktion_engine_airwindows_1.o" \
  "$BUILD_DIR/tracktion_engine_airwindows_2.o" \
  "$BUILD_DIR/tracktion_engine_airwindows_3.o" \
  "$BUILD_DIR/TestRunner.o" \
  -lscreen -lasound -lsocket -lz -lexpat -latomic \
  -o "$BUILD_DIR/TestRunner"

echo "Built: $BUILD_DIR/TestRunner"
