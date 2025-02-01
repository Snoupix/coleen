pub fn get_avg_color(data: []const u8, width: usize, height: usize, start_x: usize, end_x: usize) [3]u8 {
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

pub fn get_most_common_color(data: []const u8, width: usize, height: usize, start_x: usize, end_x: usize) [3]u8 {
    var r_counts: [256]usize = [_]usize{0} ** 256;
    var g_counts: [256]usize = [_]usize{0} ** 256;
    var b_counts: [256]usize = [_]usize{0} ** 256;

    var y: usize = 0;
    while (y < height) : (y += 1) {
        var x: usize = start_x;
        while (x < end_x) : (x += 1) {
            const idx = (y * width * 4) + (x * 4);
            b_counts[data[idx]] += 1;
            g_counts[data[idx + 1]] += 1;
            r_counts[data[idx + 2]] += 1;
        }
    }

    var most_common_r: u8 = 0;
    var most_common_g: u8 = 0;
    var most_common_b: u8 = 0;

    var max_r_count: usize = 0;
    var max_g_count: usize = 0;
    var max_b_count: usize = 0;

    var i: usize = 0;
    while (i < 256) : (i += 1) {
        if (r_counts[i] > max_r_count) {
            max_r_count = r_counts[i];
            most_common_r = @intCast(i);
        }
        if (g_counts[i] > max_g_count) {
            max_g_count = g_counts[i];
            most_common_g = @intCast(i);
        }
        if (b_counts[i] > max_b_count) {
            max_b_count = b_counts[i];
            most_common_b = @intCast(i);
        }
    }

    return [3]u8{ most_common_r, most_common_g, most_common_b };
}
