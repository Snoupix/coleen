#export LD_LIBRARY_PATH := "../rustbee/rustbee-common/target/release"
export LD_LIBRARY_PATH := "."

@run:
    cp ../rustbee/rustbee-common/librustbee.h ../rustbee/rustbee-common/target/release/librustbee_common.so .
    go run .
