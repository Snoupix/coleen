const std = @import("std");

const C = @cImport({
    @cInclude("librustbee.h");
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

    // TODO: Use zig clap

    // Provide screen number or use the default/main one
    // x := flag.Uint("x", 0, "Unsigned integer that vertically splits the screen")
    // y := flag.Uint("y", 0, "Unsigned integer that horizontally splits the screen")
    // interval := flag.Uint("interval", 0, "Interval in milliseconds where the screen colors are taken")
}
