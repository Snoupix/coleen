const std = @import("std");

const Step = std.Build.Step;
const fs = std.fs;

const cwd = fs.cwd();

pub fn build(b: *std.Build) !void {
    try fs.Dir.copyFile(cwd, "../rustbee/rustbee-common/librustbee.h", cwd, "deps/rustbee/librustbee.h", .{});
    try fs.Dir.copyFile(cwd, "../rustbee/rustbee-common/target/release/librustbee_common.so", cwd, "deps/rustbee/librustbee.so", .{});

    const compile_step: ?*Step = if (is_screen_capture_lite_compiled()) null else blk: {
        break :blk compile_screen_capture_lite(b);
    };

    const clap = b.dependency("clap", .{});

    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{ .preferred_optimize_mode = .Debug });

    const exe = b.addExecutable(.{
        .name = "coleen",
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
    });

    exe.root_module.addImport("clap", clap.module("clap"));

    if (compile_step) |step| {
        exe.step.dependOn(step);
    }

    exe.linkLibC();

    exe.addObjectFile(b.path("deps/rustbee/librustbee.so"));
    exe.addLibraryPath(b.path("deps/rustbee"));

    exe.addObjectFile(b.path("deps/screen_capture_lite/build/libscreen_capture_lite_shared.so"));
    exe.addLibraryPath(b.path("deps/screen_capture_lite/build"));

    exe.addIncludePath(b.path("./deps"));

    b.installArtifact(exe);

    // Just know that running the app with `zig build run` will not handle
    // SIGINT via CTRL + C so it will not gracefully shutdown in that case
    const run_cmd = b.addRunArtifact(exe);

    run_cmd.step.dependOn(b.getInstallStep());

    if (b.args) |args| {
        run_cmd.addArgs(args);
    }

    const run_step = b.step("run", "Run the app");
    run_step.dependOn(&run_cmd.step);
}

fn is_screen_capture_lite_compiled() bool {
    _ = fs.Dir.openDir(cwd, "deps/screen_capture_lite/build", .{}) catch return false;

    return true;
}

fn compile_screen_capture_lite(b: *std.Build) *Step {
    const build_dir = "build";

    var cmake_cmd = b.addSystemCommand(&[_][]const u8{
        "cmake",
        "-B",
        build_dir,
    });

    {
        cmake_cmd.cwd = b.path("deps/screen_capture_lite/");
        cmake_cmd.stdio = .inherit;

        if (cmake_cmd.captured_stdout) |out| {
            std.debug.print("{}", .{out.*});
        }
    }

    var make_cmd = b.addSystemCommand(&[_][]const u8{
        "cmake", "--build", build_dir, "--parallel",
    });

    {
        make_cmd.step.dependOn(&cmake_cmd.step);

        make_cmd.cwd = b.path("deps/screen_capture_lite/");
        make_cmd.stdio = .inherit;

        if (make_cmd.captured_stdout) |out| {
            std.debug.print("{}", .{out.*});
        }
    }

    return &make_cmd.step;
}
