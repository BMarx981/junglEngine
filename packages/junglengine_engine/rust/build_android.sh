#!/bin/sh
# Builds the engine for every Android ABI and leaves the shared objects where
# Gradle picks them up as jniLibs.
#
#   build_android.sh <ndk-dir> <jniLibs-dir>
#
# Called from android/build.gradle, which is where the NDK path comes from.
# Uses the NDK's own clang wrappers as linkers rather than depending on
# cargo-ndk, so building junglEngine needs rustup and nothing else.
#
# API 26 is not a preference. AAudio, which is cpal's Android backend and the
# only low latency output on the platform, arrives in API 26. See docs/M4.md
# for what that costs.

set -eu

NDK="${1:?usage: build_android.sh <ndk-dir> <jniLibs-dir>}"
OUT="${2:?usage: build_android.sh <ndk-dir> <jniLibs-dir>}"
HERE="$(cd "$(dirname "$0")" && pwd)"
API=26
LIB="libjunglengine_engine.so"

PATH="$PATH:$HOME/.cargo/bin:/opt/homebrew/bin:/usr/local/bin"
export PATH

if ! command -v cargo >/dev/null 2>&1; then
  echo "error: cargo is not on PATH. The Rust toolchain is a build requirement" >&2
  echo "       for junglEngine: https://rustup.rs" >&2
  exit 1
fi

case "$(uname -s)" in
  Darwin) HOST_TAG=darwin-x86_64 ;;
  Linux)  HOST_TAG=linux-x86_64 ;;
  *)      echo "error: no NDK toolchain for $(uname -s)" >&2; exit 1 ;;
esac
BIN="$NDK/toolchains/llvm/prebuilt/$HOST_TAG/bin"

build() {
  target="$1"
  abi="$2"
  clang="$3"
  rustup target add "$target" >/dev/null 2>&1 || true
  linker="$BIN/$clang$API-clang"
  if [ ! -x "$linker" ]; then
    echo "error: no NDK linker at $linker" >&2
    exit 1
  fi
  # The env var name is the target, upper cased with dashes as underscores.
  var="CARGO_TARGET_$(echo "$target" | tr 'a-z-' 'A-Z_')_LINKER"
  ( cd "$HERE" && env "$var=$linker" "AR=$BIN/llvm-ar" \
      cargo build --release --target "$target" )
  mkdir -p "$OUT/$abi"
  cp "$HERE/target/$target/release/$LIB" "$OUT/$abi/$LIB"
}

build aarch64-linux-android   arm64-v8a   aarch64-linux-android
build armv7-linux-androideabi armeabi-v7a armv7a-linux-androideabi
build x86_64-linux-android    x86_64      x86_64-linux-android
