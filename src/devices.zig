const std = @import("std");

const main = @import("main.zig");

const C = @cImport({
    @cInclude("rustbee/librustbee.h");
});

pub const ADDR_LEN = C.ADDR_LEN;

pub const DeviceError = error{ CreationFail, ConnectionFail, ColorSettingFail };

pub const Devices = struct {
    const Self = @This();

    ptrs: [main.addrs.len][*c]C.Device = undefined,

    pub fn init() DeviceError!Self {
        var self = Self{};

        if (!C.launch_daemon()) {
            std.log.err("Failed to launch daemon\n", .{});
            return std.process.exit(1);
        }

        for (main.addrs, 0..) |addr, i| {
            const device = C.new_device(&addr);

            if (device == null) {
                std.log.err("Failed to create device\n", .{});
                return DeviceError.CreationFail;
            }

            if (!C.try_connect(device)) {
                std.log.err("Failed to connect to the device\n", .{});
                return DeviceError.ConnectionFail;
            }

            self.ptrs[i] = device;
        }

        return self;
    }

    pub fn deinit(self: *Self) void {
        for (self.ptrs) |device_ptr| {
            _ = C.try_disconnect(device_ptr);
            C.free_device(device_ptr);
        }

        self.ptrs = undefined;
    }

    pub fn set_color_rgb(self: *Self, colors: [][3]u8) DeviceError!void {
        for (self.ptrs, 0..) |device_ptr, i| {
            if (!C.set_color_rgb(device_ptr, colors[i][0], colors[i][1], colors[i][2])) {
                std.log.warn("Failed to set the device (uuid {any}) colors (r: {} g: {} b: {})\n", .{ main.addrs[i], colors[i][0], colors[i][1], colors[i][2] });
                return DeviceError.ColorSettingFail;
            }
        }
    }
};
