#!/bin/sh
# Builds the engine for an Apple platform and leaves it where the podspec
# expects it.
#
#   build_apple.sh ios     -> ios/junglengine_engine.xcframework
#   build_apple.sh macos   -> macos/libjunglengine_engine.a
#
# Called twice per build: once by the podspec's prepare_command, so `pod
# install` always has something to vendor, and once as a script phase before
# compile, so editing Rust and hitting run picks the change up. Cargo does
# nothing the second time when nothing changed.
#
# A device and a simulator slice cannot live in one static library -- they are
# different platforms, not different architectures -- which is the whole reason
# iOS gets an xcframework and macOS gets a plain fat archive.

set -eu

PLATFORM="${1:?usage: build_apple.sh ios|macos}"
HERE="$(cd "$(dirname "$0")" && pwd)"
PACKAGE="$(dirname "$HERE")"
LIB="libjunglengine_engine.a"

# Xcode puts its own toolchain on PATH and cargo is not on it.
PATH="$PATH:$HOME/.cargo/bin:/opt/homebrew/bin:/usr/local/bin"
export PATH

if ! command -v cargo >/dev/null 2>&1; then
  echo "error: cargo is not on PATH. The Rust toolchain is a build requirement" >&2
  echo "       for junglEngine: https://rustup.rs" >&2
  exit 1
fi

# Xcode exports SDKROOT and friends for the target it is building; cargo would
# hand them to the wrong slice.
unset SDKROOT MACOSX_DEPLOYMENT_TARGET IPHONEOS_DEPLOYMENT_TARGET || true

build() {
  target="$1"
  rustup target add "$target" >/dev/null 2>&1 || true
  ( cd "$HERE" && cargo build --release --target "$target" )
}

installed() {
  rustup target list --installed 2>/dev/null | grep -qx "$1"
}

case "$PLATFORM" in
  ios)
    export IPHONEOS_DEPLOYMENT_TARGET=15.0
    build aarch64-apple-ios
    build aarch64-apple-ios-sim

    OUT="$HERE/target/xcframework"
    rm -rf "$OUT"
    mkdir -p "$OUT"

    SIM_SLICES="$HERE/target/aarch64-apple-ios-sim/release/$LIB"
    if installed x86_64-apple-ios; then
      build x86_64-apple-ios
      lipo -create \
        "$HERE/target/aarch64-apple-ios-sim/release/$LIB" \
        "$HERE/target/x86_64-apple-ios/release/$LIB" \
        -output "$OUT/$LIB"
      SIM_SLICES="$OUT/$LIB"
    fi

    rm -rf "$PACKAGE/ios/junglengine_engine.xcframework"
    xcodebuild -create-xcframework \
      -library "$HERE/target/aarch64-apple-ios/release/$LIB" \
      -library "$SIM_SLICES" \
      -output "$PACKAGE/ios/junglengine_engine.xcframework" >/dev/null
    ;;

  macos)
    export MACOSX_DEPLOYMENT_TARGET=10.15
    build aarch64-apple-darwin
    SLICES="$HERE/target/aarch64-apple-darwin/release/$LIB"
    if installed x86_64-apple-darwin; then
      build x86_64-apple-darwin
      SLICES="$HERE/target/aarch64-apple-darwin/release/$LIB $HERE/target/x86_64-apple-darwin/release/$LIB"
    fi
    # shellcheck disable=SC2086
    lipo -create $SLICES -output "$PACKAGE/macos/$LIB"
    ;;

  *)
    echo "error: unknown platform $PLATFORM" >&2
    exit 1
    ;;
esac
