FLUTTER_VERSION=$1


mkdir -p $HOME/.zcash-params
if [[ ! -f "$HOME/.zcash-params/sapling-output.params" ]];
then
    curl https://download.z.cash/downloads/sapling-output.params --output $HOME/.zcash-params/sapling-output.params
fi

if [[ ! -f "$HOME/.zcash-params/sapling-spend.params" ]];
then
    curl https://download.z.cash/downloads/sapling-spend.params --output $HOME/.zcash-params/sapling-spend.params
fi

cp $HOME/.zcash-params/* assets/

cargo b -r --features=dart_ffi

cp target/release/libwarp_api_ffi.so .
