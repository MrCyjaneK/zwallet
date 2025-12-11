set -x
export BUILD_DIR=$PWD

mkdir -p $HOME/.zcash-params
curl https://download.z.cash/downloads/sapling-output.params --output $HOME/.zcash-params/sapling-output.params
curl https://download.z.cash/downloads/sapling-spend.params --output $HOME/.zcash-params/sapling-spend.params
cp $HOME/.zcash-params/* $BUILD_DIR/assets/


sed -e 's/rlib/cdylib/' < native/zcash-sync/Cargo.toml >/tmp/out.toml
mv /tmp/out.toml native/zcash-sync/Cargo.toml

./configure.sh

cargo ndk --target arm64-v8a build --release --features=dart_ffi
mkdir -p ./packages/warp_api_ffi/android/src/main/jniLibs/arm64-v8a
cp ./target/aarch64-linux-android/release/libwarp_api_ffi.so ./packages/warp_api_ffi/android/src/main/jniLibs/arm64-v8a/
cargo ndk --target armeabi-v7a build --release --features=dart_ffi
mkdir -p ./packages/warp_api_ffi/android/src/main/jniLibs/armeabi-v7a
cp ./target/armv7-linux-androideabi/release/libwarp_api_ffi.so ./packages/warp_api_ffi/android/src/main/jniLibs/armeabi-v7a/
cargo ndk --target x86_64 build --release --features=dart_ffi
mkdir -p ./packages/warp_api_ffi/android/src/main/jniLibs/x86_64
cp ./target/x86_64-linux-android/release/libwarp_api_ffi.so ./packages/warp_api_ffi/android/src/main/jniLibs/x86_64/