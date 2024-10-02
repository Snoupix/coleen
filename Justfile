export LD_LIBRARY_PATH := justfile_dir()

@run *args:
    cp ../rustbee/rustbee-common/librustbee.h ../rustbee/rustbee-common/target/release/librustbee_common.so .
    #go build -o ./coleen
    #sudo setcap cap_dac_read_search+ep ./coleen
    #./coleen
    go run . {{args}}

@clean:
    go clean -cache -modcache -i
