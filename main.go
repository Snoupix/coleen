package main

/*
#cgo LDFLAGS: -L. -lrustbee_common
#include "librustbee.h"
*/
import "C"

import (
	"fmt"
	"os"
	"strconv"
	"time"
	"unsafe"
)

var ADDRS [2][6]C.uint8_t = [2][6]C.uint8_t{
	{0xE8, 0xD4, 0xEA, 0xC4, 0x62, 0x00},
	{0xEC, 0x27, 0xA7, 0xD6, 0x5A, 0x9C},
}

func main() {
    power_value, err := strconv.ParseUint(os.Args[1], 10, 8)
    if err != nil {
        panic(err)
    }

	if !C.launch_daemon() {
		fmt.Fprintf(os.Stderr, "[ERROR] Failed to launch daemon")
		os.Exit(1)
	}
	// force_shutdown := 0
	// defer func() {
	// 	if !C.shutdown_daemon((*C.uint8_t)(unsafe.Pointer(&force_shutdown))) {
	// 		fmt.Fprintf(os.Stderr, "[ERROR] Failed to shutdown daemon")
	// 		os.Exit(1)
	// 	}
	// }()

	for _, addr := range ADDRS {
		go func() {
			addr_ptr := (*C.uint8_t)(unsafe.Pointer(&addr))
			device_ptr := C.new_device(addr_ptr)
			defer C.free_device(device_ptr)
			if !C.try_connect(device_ptr) {
				fmt.Fprintf(os.Stderr, "[ERROR] Failed to connect\n")
				return
			}
            fmt.Printf("Brightness %d%%\n", *C.get_brightness(device_ptr))
			if !C.set_power(device_ptr, (*C.uint8_t)(unsafe.Pointer(&power_value))) {
				fmt.Fprintf(os.Stderr, "[ERROR] Failed to set power\n")
				return
			}
		}()
	}

	time.Sleep(6 * time.Second)
}
