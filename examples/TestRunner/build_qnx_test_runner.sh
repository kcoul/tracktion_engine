#!/usr/bin/env bash

# Cross-builds the TestRunner for QNX using the compiler from the QNX SDP.
#
# The engine and JUCE are compiled as their unity files directly, without CMake,
# which keeps the QNX build to a single script with no toolchain file to keep in
# sync. Pass the SDP target as the first argument, e.g.
#
#   ./build_qnx_test_runner.sh 12.2.0,gcc_ntoaarch64le
#
# The SDP environment is taken from $QNX_SDP_ENV, or from ~/qnx800/qnxsdp-env.sh
# if that is not set. If the environment is already sourced, it is left alone.

set -euo pipefail

TARGET="${1:-12.2.0,gcc_ntoaarch64le}"
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")"/../.. && pwd)"
JUCE_DIR="$ROOT/modules/juce"

if [[ -z "${QNX_HOST:-}" ]]; then
    SDP_ENV="${QNX_SDP_ENV:-$HOME/qnx800/qnxsdp-env.sh}"

    if [[ ! -f "$SDP_ENV" ]]; then
        echo "Cannot find the QNX SDP environment script at $SDP_ENV." >&2
        echo "Set QNX_SDP_ENV to its location, or source it before running this script." >&2
        exit 1
    fi

    # shellcheck disable=SC1090
    source "$SDP_ENV"
fi

if [[ -z "${QNX_TARGET:-}" ]]; then
    echo "QNX_TARGET is not set. Source the QNX SDP environment script first." >&2
    exit 1
fi

if [[ ! -f "$JUCE_DIR/modules/juce_core/juce_core.cpp" ]]; then
    echo "modules/juce is empty. Run: git submodule update --init --recursive" >&2
    exit 1
fi

BUILD_DIR="$ROOT/build/qnx_test_runner/${TARGET//,/_}"
mkdir -p "$BUILD_DIR"

describe() { git -C "$1" describe --tags --always --dirty 2> /dev/null || echo unknown; }

cat > "$BUILD_DIR/GeneratedBuildVersion.h" <<VERSION_EOF
#pragma once
#define TRACKTION_QNX_TEST_RUNNER_ENGINE_VERSION "$(describe "$ROOT")"
#define TRACKTION_QNX_TEST_RUNNER_JUCE_VERSION   "$(describe "$JUCE_DIR")"
VERSION_EOF

# The include paths and defines below mirror JUCE's QNX toolchain file, at
# extras/Build/CMake/QNXAarch64Toolchain.cmake, so that the two builds see the
# same platform. qnx_compat carries the headers the SDP does not ship.
QNX_COMPAT_INCLUDE_DIR="$JUCE_DIR/extras/Build/CMake/qnx_compat/include"
QNX_FREETYPE_INCLUDE_DIR="$QNX_TARGET/usr/include/freetype2"
QNX_FREETYPE_LIBRARY="$QNX_TARGET/aarch64le/usr/lib/libfreetype.so.24"

QNX_FLAGS=(
    -I"$QNX_COMPAT_INCLUDE_DIR"
    -I"$QNX_FREETYPE_INCLUDE_DIR"
    -D_QNX_SOURCE
    -D__EXT_QNX
    -D__EXT_UNIX_MISC
)

COMMON=(
    "-V${TARGET}"
    -std=gnu++20
    "${QNX_FLAGS[@]}"
    -include strings.h
    -DM_PI=3.14159265358979323846
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
    -I"$JUCE_DIR/modules"
    -I"$ROOT/examples/TestRunner"
    -I"$ROOT/examples/TestRunner/qnx"
    -I"$BUILD_DIR"
)

# Each module is built from the unity files at the root of its directory, so a
# module that is split into several of them - juce_gui_basics is five - needs no
# change here, and neither do the differences between JUCE versions.
# The vendored C dependencies (SheenBidi, and on JUCE 9 also pnglib, libjpeg and
# lunasvg) are compiled from the C unity files at the root of their module.
C_COMMON=(
    "-V${TARGET}"
    "${QNX_FLAGS[@]}"
    -DJUCE_GLOBAL_MODULE_SETTINGS_INCLUDED=1
    -I"$ROOT"
    -I"$ROOT/modules"
    -I"$JUCE_DIR/modules"
    -I"$BUILD_DIR"
)

JUCE_MODULES=(
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
)

ENGINE_MODULES=(
    tracktion_core
    tracktion_graph
    tracktion_engine
)

OBJECTS=()

compile()
{
    local source="$1"
    local object="$BUILD_DIR/$(basename "${source%.*}").o"

    echo "Compiling $(basename "$source")"
    q++ "${COMMON[@]}" -c "$source" -o "$object"
    OBJECTS+=("$object")
}

compile_c()
{
    local source="$1"
    local object="$BUILD_DIR/$(basename "${source%.*}").o"

    echo "Compiling $(basename "$source")"
    qcc "${C_COMMON[@]}" -c "$source" -o "$object"
    OBJECTS+=("$object")
}

compile_module()
{
    local root="$1" module="$2" source

    for source in "$root/$module/$module"*.cpp; do
        if [[ -e "$source" ]]; then
            compile "$source"
        fi
    done

    for source in "$root/$module/$module"*.c; do
        if [[ -e "$source" ]]; then
            compile_c "$source"
        fi
    done
}

for module in "${JUCE_MODULES[@]}"; do
    compile_module "$JUCE_DIR/modules" "$module"
done

for module in "${ENGINE_MODULES[@]}"; do
    compile_module "$ROOT/modules" "$module"
done

compile "$ROOT/examples/TestRunner/TestRunner.cpp"

echo "Linking TestRunner"
q++ "-V${TARGET}" "${OBJECTS[@]}" "$QNX_FREETYPE_LIBRARY" \
    -lscreen -lasound -lsocket -lz -lexpat -latomic \
    -o "$BUILD_DIR/TestRunner"

echo "Built: $BUILD_DIR/TestRunner"
