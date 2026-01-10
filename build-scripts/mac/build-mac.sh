#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/../.."

FRAMEWORK_NAME="WarpApiFFI"
LIB_NAME="libwarp_api_ffi.dylib"
FEATURES="dart_ffi"

BASE_DIR="$(pwd)"
TARGET_DIR="$BASE_DIR/target"
TMP_DIR="$BASE_DIR/tmp_warp_frameworks"
OUTPUT_DIR="$BASE_DIR"
XCFRAMEWORK_OUT="$OUTPUT_DIR/${FRAMEWORK_NAME}.xcframework"

export BUILD_DIR="$BASE_DIR"

if [[ ! -f "$HOME/.zcash-params/sapling-output.params" ]];
then
    curl https://download.z.cash/downloads/sapling-output.params --output $HOME/.zcash-params/sapling-output.params
fi

if [[ ! -f "$HOME/.zcash-params/sapling-spend.params" ]];
then
    curl https://download.z.cash/downloads/sapling-spend.params --output $HOME/.zcash-params/sapling-spend.params
fi

mkdir -p assets
cp "$HOME/.zcash-params/"* assets/

./configure.sh

cargo build -r --target=x86_64-apple-darwin --features="$FEATURES"
cargo build -r --target=aarch64-apple-darwin --features="$FEATURES"
export IPHONEOS_DEPLOYMENT_TARGET=12.0
export SDKROOT=$(xcrun --sdk iphoneos --show-sdk-path)
export SDKROOT_SIM=$(xcrun --sdk iphonesimulator --show-sdk-path)
export CC_aarch64_apple_ios="$(xcrun --sdk iphoneos --find clang)"
export CFLAGS_aarch64_apple_ios="-isysroot $SDKROOT -miphoneos-version-min=12.0"
export AR_aarch64_apple_ios="$(xcrun --sdk iphoneos --find ar)"
export CC_aarch64_apple_ios_sim="$(xcrun --sdk iphonesimulator --find clang)"
export CFLAGS_aarch64_apple_ios_sim="-isysroot $SDKROOT_SIM -mios-simulator-version-min=12.0"
export AR_aarch64_apple_ios_sim="$(xcrun --sdk iphonesimulator --find ar)"
cargo build -r --target=aarch64-apple-ios --features="$FEATURES"
cargo build -r --target=aarch64-apple-ios-sim --features="$FEATURES"

rm -rf "$TMP_DIR" "$XCFRAMEWORK_OUT"
mkdir -p "$TMP_DIR"

create_framework_ios() {
  local dylib="$1"
  local out="$2"

  local fw="$out/$FRAMEWORK_NAME.framework"
  rm -rf "$fw"
  mkdir -p "$fw/Headers"

  cp "$dylib" "$fw/$FRAMEWORK_NAME"

  install_name_tool -id \
    "@rpath/$FRAMEWORK_NAME.framework/$FRAMEWORK_NAME" \
    "$fw/$FRAMEWORK_NAME"

  cat > "$fw/Info.plist" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN"
 "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleExecutable</key>
  <string>$FRAMEWORK_NAME</string>
  <key>CFBundleIdentifier</key>
  <string>com.cakewallet.warp.$FRAMEWORK_NAME</string>
  <key>CFBundlePackageType</key>
  <string>FMWK</string>
  <key>CFBundleVersion</key>
  <string>1</string>
  <key>CFBundleShortVersionString</key>
  <string>1.0</string>
</dict>
</plist>
EOF
}

create_framework_macos_universal() {
  local arm64_dylib="$1"
  local x86_dylib="$2"
  local out="$3"

  local fw="$out/$FRAMEWORK_NAME.framework"

  rm -rf "$fw"
  mkdir -p "$fw/Versions/A/Headers"
  mkdir -p "$fw/Versions/A/Resources"

  lipo -create \
    "$arm64_dylib" \
    "$x86_dylib" \
    -output "$fw/Versions/A/$FRAMEWORK_NAME"

  ln -sf A "$fw/Versions/Current"
  ln -sf Versions/Current/$FRAMEWORK_NAME "$fw/$FRAMEWORK_NAME"
  ln -sf Versions/Current/Headers "$fw/Headers"
  ln -sf Versions/Current/Resources "$fw/Resources"

  install_name_tool -id \
    "@rpath/$FRAMEWORK_NAME.framework/Versions/A/$FRAMEWORK_NAME" \
    "$fw/Versions/A/$FRAMEWORK_NAME"

  cat > "$fw/Versions/A/Resources/Info.plist" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN"
 "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleExecutable</key>
  <string>$FRAMEWORK_NAME</string>
  <key>CFBundleIdentifier</key>
  <string>com.cakewallet.warp.$FRAMEWORK_NAME</string>
  <key>CFBundlePackageType</key>
  <string>FMWK</string>
  <key>CFBundleVersion</key>
  <string>1</string>
  <key>CFBundleShortVersionString</key>
  <string>1.0</string>
</dict>
</plist>
EOF
}

IOS_DEVICE_OUT="$TMP_DIR/ios_device"
IOS_SIM_OUT="$TMP_DIR/ios_simulator"
MACOS_OUT="$TMP_DIR/macos"

mkdir -p "$IOS_DEVICE_OUT" "$IOS_SIM_OUT" "$MACOS_OUT"

create_framework_ios \
  "$TARGET_DIR/aarch64-apple-ios/release/$LIB_NAME" \
  "$IOS_DEVICE_OUT"

create_framework_ios \
  "$TARGET_DIR/aarch64-apple-ios-sim/release/$LIB_NAME" \
  "$IOS_SIM_OUT"

create_framework_macos_universal \
  "$TARGET_DIR/aarch64-apple-darwin/release/$LIB_NAME" \
  "$TARGET_DIR/x86_64-apple-darwin/release/$LIB_NAME" \
  "$MACOS_OUT"

echo "Creating ${FRAMEWORK_NAME}.xcframework…"

xcodebuild -create-xcframework \
  -framework "$IOS_DEVICE_OUT/$FRAMEWORK_NAME.framework" \
  -framework "$IOS_SIM_OUT/$FRAMEWORK_NAME.framework" \
  -framework "$MACOS_OUT/$FRAMEWORK_NAME.framework" \
  -output "$XCFRAMEWORK_OUT"

cp native/zcash-sync/binding.h \
  packages/warp_api_ffi/ios/Classes/binding.h

rm -rf "$TMP_DIR"

echo $XCFRAMEWORK_OUT
