package main

/*
#cgo LDFLAGS: -L. -lrustbee
#include "librustbee.h"
*/
import "C"

import (
	"flag"
	"fmt"
	"image"
	"image/draw"
    _ "image/jpeg"
	"os"
	"strconv"
	"time"
	"unsafe"

	// "github.com/kbinani/screenshot"
)

var ADDRS [2][6]C.uint8_t = [2][6]C.uint8_t{
	{0xE8, 0xD4, 0xEA, 0xC4, 0x62, 0x00},
	{0xEC, 0x27, 0xA7, 0xD6, 0x5A, 0x9C},
}

func main() {
    x := flag.Uint("x", 0, "Unsigned integer that vertically splits the screen")
    y := flag.Uint("y", 0, "Unsigned integer that horizontally splits the screen")
    interval := flag.Uint("interval", 0, "Interval in milliseconds where the screen colors are taken")
    file := flag.String("file", "", "Screenshot file to test")
    flag.Parse()

    if *x == 0 || *y == 0 || *interval == 0 {
        fmt.Println("One or multiple flag is not set")
        os.Exit(1)
    }

    if file == nil || *file == "" {
        return
    }

    // _img, err := screenshot.CaptureDisplay(0)
    // if err != nil {
    //     panic(err)
    // }
    // img := image.Image(_img)

    f, err := os.Open(*file)
	if err != nil {
        panic(err)
	}
	defer f.Close()

	img, _, err := image.Decode(f)
	if err != nil {
        panic(err)
	}

	rgbaImage, ok := img.(*image.RGBA)
	if !ok {
		// Convert to RGBA if not already RGBA
		rect := img.Bounds()
		rgbaImage = image.NewRGBA(rect)
		draw.Draw(rgbaImage, rect, img, rect.Min, draw.Src)
	}

    // fmt.Println(img)
    // fmt.Println(rgbaImage)
    return

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
