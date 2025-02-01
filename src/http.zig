const std = @import("std");

const main = @import("main.zig");

pub fn run_server(state: *main.State, alloc: *const std.mem.Allocator, ipv4: [4]u8, port: u16) !void {
    const addr = std.net.Address.initIp4(ipv4, port);
    var server = try addr.listen(.{});

    while (true) {
        var conn = try server.accept();
        defer conn.stream.close();

        state.mux.lock();
        defer state.mux.unlock();

        const data: [main.MAX_DIVIDED_BY][3]u8 = if (state.data) |_data| _data.* else [_][3]u8{[_]u8{0} ** 3} ** main.MAX_DIVIDED_BY;

        _ = try conn.stream.write(
            \\HTTP/1.1 200 OK
            \\Date: Mon, 27 Jul 2009 12:28:53 GMT
            \\Content-Type: text/pain
        );

        var body_buffer = std.ArrayList(u8).init(alloc.*);
        defer body_buffer.deinit();

        for (data, 0..) |rgb, i| {
            if (i > 0 and i < data.len - 1) {
                try body_buffer.append(' ');
            }

            try std.fmt.format(body_buffer.writer(), "{} {} {}", .{ rgb[0], rgb[1], rgb[2] });
        }

        const body = body_buffer.items;

        try conn.stream.writer().print("\r\nContent-Length: {}\r\n\r\n", .{body.len});
        try conn.stream.writeAll(body);
    }
}
