package main

/*
#cgo LDFLAGS: -L. -lrustbee_common
#include "librustbee.h"
*/
import "C"

import (
    "unsafe"
    "time"
)

var ADDRS [2][6]C.uint8_t = [2][6]C.uint8_t{{0xE8, 0xD4, 0xEA, 0xC4, 0x62, 0x00}, {0xEC, 0x27, 0xA7, 0xD6, 0x5A, 0x9C}}

func main() {
    power_value := 1

    for _, addr := range ADDRS {
        C.connect((*C.uint8_t)(unsafe.Pointer(&addr)))
        C.set_power((*C.uint8_t)(unsafe.Pointer(&addr)), (*C.uint8_t)(unsafe.Pointer(&power_value)))
        time.Sleep(5 * time.Second)
    }
}
