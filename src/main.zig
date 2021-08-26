const std = @import("std");

pub fn main() !void {
    std.log.info("All your codebase are belong to us.", .{});

    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    var arena = std.heap.ArenaAllocator.init(&gpa.allocator);
    defer arena.deinit();
    const alloc = &arena.allocator;

    const proc_args = try std.process.argsAlloc(alloc);
    const args = proc_args;

    for (args) |item, i| {
        std.log.info("{d}: {s}", .{ i, item });
    }
}
