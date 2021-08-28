const std = @import("std");

pub fn main() !void {

    //
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    var arena = std.heap.ArenaAllocator.init(&gpa.allocator);
    defer arena.deinit();
    const alloc = &arena.allocator;


}
