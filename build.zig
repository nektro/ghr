const std = @import("std");
const builtin = @import("builtin");
const deps = @import("./deps.zig");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const mode = b.option(std.builtin.Mode, "mode", "") orelse .Debug;

    const use_full_name = b.option(bool, "full-name", "") orelse false;
    const exe = makeExe(b, use_full_name, target, mode);
    b.installArtifact(exe);

    //

    const run_cmd = b.addRunArtifact(exe);
    run_cmd.step.dependOn(b.getInstallStep());
    if (b.args) |args| {
        run_cmd.addArgs(args);
    }

    const run_step = b.step("run", "Run the app");
    run_step.dependOn(&run_cmd.step);

    //

    const all_step = b.step("all", "Build for all supported targets");
    all_step.dependOn(&b.addInstallArtifact(makeExe2(b, true, mode, "x86_64-linux-musl"), .{}).step);
    all_step.dependOn(&b.addInstallArtifact(makeExe2(b, true, mode, "x86_64-macos"), .{}).step);
    all_step.dependOn(&b.addInstallArtifact(makeExe2(b, true, mode, "x86_64-windows-gnu"), .{}).step);
    all_step.dependOn(&b.addInstallArtifact(makeExe2(b, true, mode, "aarch64-linux-musl"), .{}).step);
    all_step.dependOn(&b.addInstallArtifact(makeExe2(b, true, mode, "aarch64-macos"), .{}).step);
    all_step.dependOn(&b.addInstallArtifact(makeExe2(b, true, mode, "aarch64-windows-gnu"), .{}).step);
}

fn makeExe(b: *std.Build, use_fullname: bool, target: std.Build.ResolvedTarget, mode: std.builtin.Mode) *std.Build.Step.Compile {
    const with_os_arch = b.fmt("-{s}-{s}", .{ @tagName(target.result.os.tag), @tagName(target.result.cpu.arch) });
    const exe_name = b.fmt("{s}{s}", .{ "ghr", if (use_fullname) with_os_arch else "" });

    const exe = b.addExecutable(.{
        .name = exe_name,
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = mode,
    });
    deps.addAllTo(exe);
    return exe;
}

fn makeExe2(b: *std.Build, use_fullname: bool, mode: std.builtin.Mode, target_str: []const u8) *std.Build.Step.Compile {
    const target = b.resolveTargetQuery(std.Target.Query.parse(.{ .arch_os_abi = target_str }) catch @panic("bad target"));
    return makeExe(b, use_fullname, target, mode);
}
