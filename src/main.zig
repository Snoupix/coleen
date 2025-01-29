const std = @import("std");

const C = @cImport({
    @cInclude("rustbee/librustbee.h");
    @cInclude("screen_capture_lite/include/ScreenCapture_C_API.h");
});

const addrs: [2][C.ADDR_LEN]u8 = [_][C.ADDR_LEN]u8{
    [_]u8{ 0xE8, 0xD4, 0xEA, 0xC4, 0x62, 0x00 },
    [_]u8{ 0xEC, 0x27, 0xA7, 0xD6, 0x5A, 0x9C },
};

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();

    const alloc = gpa.allocator();
    _ = alloc;

    const frame_grabber: C.SCL_ICaptureConfigurationScreenCaptureCallbackWrapperRef = C.SCL_CreateMonitorCaptureConfiguration(&screenshot_callback);
    _ = frame_grabber;

    // C.SCL_MonitorOnNewFrame(ptr: SCL_ICaptureConfigurationScreenCaptureCallbackWrapperRef, cb: SCL_ScreenCaptureCallback)

    // TODO: Use zig clap

    // Provide screen number or use the default/main one
    // x := flag.Uint("x", 0, "Unsigned integer that vertically splits the screen")
    // y := flag.Uint("y", 0, "Unsigned integer that horizontally splits the screen")
    // interval := flag.Uint("interval", 0, "Interval in milliseconds where the screen colors are taken")
}

fn screenshot_callback(monitors: C.SCL_MonitorRef, monitors_size: c_int) callconv(.C) c_int {
    std.debug.print("{any}", .{monitors});
    return C.SCL_GetMonitors(monitors, monitors_size);
}

// https://github.com/smasherprog/screen_capture_lite

//Setup Screen Capture for all monitors
// var framgrabber = SL.Screen_Capture.CaptureConfiguration.CreateCaptureConfiguration(() =>
// {
//    var mons = SL.Screen_Capture.SCL_GetMonitors();
//    Console.WriteLine("Library is requesting the list of monitors to capture!");
//    for (int i = 0; i < mons.Length; ++i)
//    {
// 	   WriteLine( mons[i]);
//    }
//    return mons;
// }).onNewFrame(( SL.Screen_Capture.Image img,  SL.Screen_Capture.Monitor monitor) =>
// {
//
// }).onFrameChanged(( SL.Screen_Capture.Image img,  SL.Screen_Capture.Monitor monitor) =>
// {
//
// }).onMouseChanged((SL.Screen_Capture.Image img, SL.Screen_Capture.MousePoint mousePoint) =>
// {
//
// }).start_capturing();
// framgrabber.SCL_SetFrameChangeInterval(100);
// framgrabber.SCL_SetMouseChangeInterval(100);
//
//
// //Setup Screen Capture for windows that have the title "google" in it
// var framgrabber = SL.Screen_Capture.CaptureConfiguration.CreateCaptureConfiguration(() =>
// {
// 	var windows = SL.Screen_Capture.SCL_GetWindows();
// 	Console.WriteLine("Library is requesting the list of windows to capture!");
// 	for (int i = 0; i < windows.Length; ++i)
// 	{
// 		WriteLine(windows[i]);
// 	}
// 	return windows.Where(a => a.Name.ToLower().Contains("google")).ToArray();
// }).onNewFrame(( SL.Screen_Capture.Image img,  SL.Screen_Capture.Window monitor) =>
// {
//
// }).onFrameChanged(( SL.Screen_Capture.Image img,  SL.Screen_Capture.Window monitor) =>
// {
// }).onMouseChanged(( SL.Screen_Capture.Image img,  SL.Screen_Capture.MousePoint mousePoint) =>
// {
//
// }).start_capturing();
//
// framgrabber.SCL_SetFrameChangeInterval(100);
// framgrabber.SCL_SetMouseChangeInterval(100);
