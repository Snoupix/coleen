const std = @import("std");

const main = @import("main.zig");

pub fn run_server(state: *main.State, alloc: *const std.mem.Allocator, ipv4: [4]u8, port: u16) !void {
    std.log.debug("Listening on {d}.{d}.{d}.{d}:{d}", .{ipv4[0], ipv4[1], ipv4[2], ipv4[3], port});

    const addr = std.net.Address.initIp4(ipv4, port);
    var server = try addr.listen(.{});
    defer server.deinit();

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

        var body_buffer: std.ArrayList(u8) = .empty;
        defer body_buffer.deinit(alloc.*);

        for (data, 0..) |rgb, i| {
            if (i > 0 and i < data.len - 1) {
                try body_buffer.append(alloc.*, ' ');
            }

            try body_buffer.writer(alloc.*).print("{} {} {}", .{ rgb[0], rgb[1], rgb[2] });
        }

        const body = body_buffer.items;
        var buf: [8]u8 = undefined;
        var stream_writer = conn.stream.writer(&buf);

        std.log.debug("{any}", .{body});

        try stream_writer.interface.print("\r\nContent-Length: {}\r\n\r\n", .{body.len});
        try stream_writer.interface.writeAll(body);
    }
}
