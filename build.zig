const std = @import("std");
const builtin = @import("builtin");
const deps = @import("./deps.zig");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const mode = b.option(std.builtin.Mode, "mode", "") orelse .Debug;

    const use_full_name = b.option(bool, "full-name", "") orelse false;
    const with_os_arch = b.fmt("-{s}-{s}", .{ @tagName(target.result.os.tag), @tagName(target.result.cpu.arch) });
    const exe_name = b.fmt("{s}{s}", .{ "ghr", if (use_full_name) with_os_arch else "" });

    const exe = b.addExecutable(.{
        .name = exe_name,
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = mode,
    });
    deps.addAllTo(exe);
    b.installArtifact(exe);

    const run_cmd = b.addRunArtifact(exe);
    run_cmd.step.dependOn(b.getInstallStep());
    if (b.args) |args| {
        run_cmd.addArgs(args);
    }

    const run_step = b.step("run", "Run the app");
    run_step.dependOn(&run_cmd.step);
}
