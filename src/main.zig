const std = @import("std");

const clap = @import("clap");

const colors = @import("colors.zig");
const http = @import("http.zig");
const _d = @import("devices.zig");

const print = std.debug.print;
const assert = std.debug.assert;

const C = @cImport({
    @cInclude("screen_capture_lite/include/ScreenCapture_C_API.h");
});

const Devices = _d.Devices;
const DeviceError = _d.DeviceError;
const ADDR_LEN = _d.ADDR_LEN;

pub const State = struct { mux: std.Thread.Mutex = .{}, data: ?*[MAX_DIVIDED_BY][3]u8 = null };

pub const MAX_DIVIDED_BY = 8;
pub const MIN_DIVIDED_BY = 1;

var gpa = std.heap.GeneralPurposeAllocator(.{}){};
pub const alloc = gpa.allocator();

// Reorder lamp address if needed
pub const addrs: [2][ADDR_LEN]u8 = [_][ADDR_LEN]u8{
    [_]u8{ 0xEC, 0x27, 0xA7, 0xD6, 0x5A, 0x9C },
    [_]u8{ 0xE8, 0xD4, 0xEA, 0xC4, 0x62, 0x00 },
};

var divided_by: u8 = 2;
var interval: usize = 3000;
var enable_http_server = false;
var http_server_addr = .{ .ipv4 = [4]u8{ 127, 0, 0, 1 }, .port = 8081 };
var app_is_running = true;
var state: State = .{};

pub fn main() !void {
    defer _ = gpa.deinit();

    // TODO: Provide the screen number (index) to use else use default
    const params = comptime clap.parseParamsComptime(
        \\-h, --help             Display this help and exit.
        \\-x <u8>                Unsigned integer that vertically splits the screen. Between 1 and 8.
        \\-i, --interval <usize> Interval in ms at which the lights are changed (and screen capture taken).
        \\-s, --http <string>    If specified, it will also spawn a HTTP server that serves at the specified address (format: "ipv4:port"). It will return the current light state, e.g. splitted by 2: "r g b r g b 0 ...".
    );

    var diag = clap.Diagnostic{};
    var res = clap.parse(clap.Help, &params, clap.parsers.default, .{
        .diagnostic = &diag,
        .allocator = alloc,
    }) catch |err| {
        diag.report(std.io.getStdErr().writer(), err) catch {};
        return err;
    };
    defer res.deinit();

    if (res.args.help != 0) {
        return clap.help(std.io.getStdErr().writer(), clap.Help, &params, .{});
    }

    if (res.args.x) |n| {
        divided_by = n;
    }

    if (res.args.interval) |i| {
        interval = i;
    }

    if (res.args.http) |_| {
        enable_http_server = true;
        // TODO: Parse
    }

    assert(divided_by >= MIN_DIVIDED_BY);
    assert(divided_by <= MAX_DIVIDED_BY);

    const config = C.SCL_CreateMonitorCaptureConfiguration(C.SCL_GetMonitors);
    defer C.SCL_FreeMonitorCaptureConfiguration(config);

    C.SCL_MonitorOnNewFrame(config, on_new_frame);

    const frame_grabber = C.SCL_MonitorStartCapturing(config);
    defer C.SCL_FreeIScreenCaptureManagerWrapper(frame_grabber);

    C.SCL_SetFrameChangeInterval(frame_grabber, @intCast(interval - 100));

    const sigaction: std.posix.Sigaction = .{
        .handler = .{ .handler = handle_sigint },
        .mask = std.os.linux.empty_sigset,
        .flags = 0,
    };

    try std.posix.sigaction(std.posix.SIG.INT, &sigaction, null);

    if (enable_http_server) {
        const server_thread = try std.Thread.spawn(.{}, http.run_server, .{ &state, &alloc, http_server_addr.ipv4, http_server_addr.port });
        server_thread.detach();
    }

    var devices = try Devices.init();
    defer devices.deinit();

    while (app_is_running) {
        // Don't need to aquire the lock to read
        // + Avoids deadlock because the sigint action
        // is on the same thread and would cause a deadlock
        if (state.data == null) {
            continue;
        }

        try devices.set_color_rgb(&state.data.?.*);

        std.time.sleep(std.time.ns_per_ms * interval);
    }

    C.SCL_PauseCapturing(frame_grabber);
}

fn handle_sigint(_: i32) callconv(.C) void {
    print("\nExiting gracefully...\n", .{});

    state.mux.lock();
    defer state.mux.unlock();
    if (state.data) |data| {
        alloc.free(data);

        state.data = null;
    }

    app_is_running = false;
}

fn on_new_frame(img: C.SCL_ImageRefConst, _: C.SCL_MonitorRefConst) callconv(.C) c_int {
    if (!app_is_running) return 0;

    const bytes: [*]const u8 = @ptrCast(img);

    const width = std.mem.readPackedInt(u32, bytes[8..12], 0, .little);
    const height = std.mem.readPackedInt(u32, bytes[12..16], 0, .little);
    const stride = std.mem.readPackedInt(u32, bytes[16..20], 0, .little);

    const data_size = stride * height;
    // const data_size_f: f32 = @floatFromInt(data_size);

    // print("Dimensions: {}x{}, Stride: {} ({d:.02}M)\n", .{ width, height, stride, data_size_f / 1024 / 1024 });

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
        const most_common_color = colors.get_most_common_color(buffer, width, height, 0 * section_width, section_width * (i + 1));

        if (most_common_color[0] < 50 and most_common_color[1] < 50 and most_common_color[2] < 50) {
            sections[i] = colors.get_avg_color(buffer, width, height, 0 * section_width, section_width * (i + 1));
        }

        sections[i] = most_common_color;
    }

    return 0;
}
