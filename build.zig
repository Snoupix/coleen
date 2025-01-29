const std = @import("std");

const fs = std.fs;

const cwd = fs.cwd();

pub fn build(b: *std.Build) !void {
    try fs.Dir.copyFile(cwd, "../rustbee/rustbee-common/librustbee.h", cwd, "librustbee.h", .{});
    try fs.Dir.copyFile(cwd, "../rustbee/rustbee-common/target/release/librustbee_common.so", cwd, "librustbee.so", .{});

    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{ .preferred_optimize_mode = .Debug });

    const exe = b.addExecutable(.{
        .name = "coleen",
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
    });

    exe.linkLibC();
    exe.addObjectFile(b.path("./librustbee.so"));
    exe.addIncludePath(b.path("."));

    b.installArtifact(exe);

    const run_cmd = b.addRunArtifact(exe);

    run_cmd.step.dependOn(b.getInstallStep());

    if (b.args) |args| {
        run_cmd.addArgs(args);
    }

    const run_step = b.step("run", "Run the app");
    run_step.dependOn(&run_cmd.step);
}
