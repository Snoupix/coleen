const std = @import("std");

const clap = @import("clap");

const http = @import("http.zig");

const assert = std.debug.assert;

const C = @cImport({
    @cInclude("rustbee/librustbee.h");
    @cInclude("screen_capture_lite/include/ScreenCapture_C_API.h");
});

pub const State = struct { mux: std.Thread.Mutex = .{}, data: ?*[10][3]u8 = null };

pub const MAX_DIVIDED_BY = 10;

var gpa = std.heap.GeneralPurposeAllocator(.{}){};
pub const alloc = gpa.allocator();

const addrs: [2][C.ADDR_LEN]u8 = [_][C.ADDR_LEN]u8{
    [_]u8{ 0xE8, 0xD4, 0xEA, 0xC4, 0x62, 0x00 },
    [_]u8{ 0xEC, 0x27, 0xA7, 0xD6, 0x5A, 0x9C },
};

var divided_by: u8 = 2;
var app_is_running = true;
var state: State = .{};

pub fn main() !void {
    const enable_http_server = true;

    defer _ = gpa.deinit();

    assert(divided_by <= MAX_DIVIDED_BY);

    std.debug.print("{}\n", .{std.os.linux.getpid()});

    const config = C.SCL_CreateMonitorCaptureConfiguration(C.SCL_GetMonitors);
    defer C.SCL_FreeMonitorCaptureConfiguration(config);

    C.SCL_MonitorOnNewFrame(config, on_new_frame);

    const frame_grabber = C.SCL_MonitorStartCapturing(config);
    defer C.SCL_FreeIScreenCaptureManagerWrapper(frame_grabber);

    C.SCL_SetFrameChangeInterval(frame_grabber, 1000);

    const sigaction: std.posix.Sigaction = .{
        .handler = .{ .handler = handle_sigint },
        .mask = std.os.linux.empty_sigset,
        .flags = 0,
    };

    try std.posix.sigaction(std.posix.SIG.INT, &sigaction, null);

    if (enable_http_server) {
        const server_thread = try std.Thread.spawn(.{}, http.run_server, .{ &state, &alloc, [_]u8{ 127, 0, 0, 1 }, 8081 });
        server_thread.detach();
    }

    while (app_is_running) {
        std.time.sleep(std.time.ns_per_s * 1);
    }

    C.SCL_PauseCapturing(frame_grabber);

    // TODO: Use zig clap
    // TODO: Hue Lamp ordering by uuid

    // Provide screen number or use the default/main one
    // x := flag.Uint("x", 0, "Unsigned integer that vertically splits the screen")
    // y := flag.Uint("y", 0, "Unsigned integer that horizontally splits the screen")
    // interval := flag.Uint("interval", 0, "Interval in milliseconds where the screen colors are taken")
    // h/http flag to be able to specify an address + port and retrieve the data via HTTP instead of stdout
}

fn handle_sigint(_: i32) callconv(.C) void {
    state.mux.lock();
    defer state.mux.unlock();
    if (state.data) |data| {
        alloc.free(data);
    }

    app_is_running = false;
}

fn on_new_frame(img: C.SCL_ImageRefConst, _: C.SCL_MonitorRefConst) callconv(.C) c_int {
    const bytes: [*]const u8 = @ptrCast(img);

    const width = std.mem.readPackedInt(u32, bytes[8..12], 0, .little);
    const height = std.mem.readPackedInt(u32, bytes[12..16], 0, .little);
    const stride = std.mem.readPackedInt(u32, bytes[16..20], 0, .little);

    const data_size = stride * height;
    const data_size_f: f32 = @floatFromInt(data_size);

    std.debug.print("Dimensions: {}x{}, Stride: {} ({d:.02}M)\n", .{ width, height, stride, data_size_f / 1024 / 1024 });

    // Allocate buffer for the image data
    const buffer = std.heap.c_allocator.alloc(u8, data_size) catch |err| std.debug.panic("Failed to allocate buffer: {}\n", .{err});
    defer std.heap.c_allocator.free(buffer);

    _ = C.SCL_Utility_CopyToContiguous(
        buffer.ptr,
        img,
    );

    state.mux.lock();
    defer state.mux.unlock();

    if (state.data) |data| {
        alloc.free(data);
    }

    const section_width = width / divided_by;
    const sections = alloc.create([MAX_DIVIDED_BY][3]u8) catch unreachable;
    sections.* = [_][3]u8{[_]u8{0} ** 3} ** MAX_DIVIDED_BY;

    state.data = sections;

    for (0..divided_by) |i| {
        sections[i] = get_avg_color(buffer, width, height, 0 * section_width, section_width * (i + 1));
        std.debug.print("Section {} Avg Color (R,G,B):\n{} {} {}\n", .{ i, sections[i][0], sections[i][1], sections[i][2] });
    }

    return 0;
}

fn get_avg_color(data: []const u8, width: usize, height: usize, start_x: usize, end_x: usize) [3]u8 {
    var total_r: u64 = 0;
    var total_g: u64 = 0;
    var total_b: u64 = 0;
    var pixel_count: usize = 0;

    var y: usize = 0;
    while (y < height) : (y += 1) {
        var x: usize = start_x;
        while (x < end_x) : (x += 1) {
            const idx = (y * width * 4) + (x * 4);
            total_b += data[idx];
            total_g += data[idx + 1];
            total_r += data[idx + 2];
            pixel_count += 1;
        }
    }

    return [3]u8{
        @intCast(total_r / pixel_count),
        @intCast(total_g / pixel_count),
        @intCast(total_b / pixel_count),
    };
}
