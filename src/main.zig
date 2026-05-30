const std = @import("std");
const string = []const u8;
const json = @import("json");
const nio = @import("nio");

const Config = struct {
    token: string,
    user: string,
    repo: string,
    commit: string,
    title: string,
    body: string,
    tag: string,
    path: string,
    draft: bool,
    prerelease: bool,
};

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    var arena = std.heap.ArenaAllocator.init(gpa.allocator());
    defer arena.deinit();
    const alloc = arena.allocator();

    var config: Config = .{
        .token = "",
        .user = "",
        .repo = "",
        .commit = "",
        .title = "",
        .body = "",
        .tag = "",
        .path = "",
        .draft = false,
        .prerelease = false,
    };

    var envmap = try std.process.getEnvMap(alloc);
    defer envmap.deinit();
    if (envmap.get("GITHUB_TOKEN")) |env| config.token = env;

    var argiter = try std.process.argsWithAllocator(alloc);
    defer argiter.deinit();
    var argi: usize = 0;
    while (argiter.next()) |item| : (argi += 1) {
        if (argi == 0) continue;

        // zig fmt: off
        if (std.mem.eql(u8, item, "-t")) { config.token = argiter.next().?;   continue; }
        if (std.mem.eql(u8, item, "-u")) { config.user = argiter.next().?;    continue; }
        if (std.mem.eql(u8, item, "-r")) { config.repo = argiter.next().?;    continue; }
        if (std.mem.eql(u8, item, "-c")) { config.commit = argiter.next().?;  continue; }
        if (std.mem.eql(u8, item, "-n")) { config.title = argiter.next().?;   continue; }
        if (std.mem.eql(u8, item, "-b")) { config.body = argiter.next().?;    continue; }
        if (std.mem.eql(u8, item, "-draft")) { config.draft = true;           continue; }
        if (std.mem.eql(u8, item, "-prerelease")) { config.prerelease = true; continue; }
        // zig fmt: on

        config.tag = item;
        config.path = argiter.next().?;
        break;
    }

    if (config.token.len == 0) {
        std.log.err("token is empty! pass -t option or set $GITHUB_TOKEN to continue", .{});
        std.process.exit(1);
    }

    if (config.user.len == 0) {
        std.log.warn("user (-u) is empty! reading $GITHUB_REPOSITORY instead", .{});
        config.user = std.posix.getenv("GITHUB_REPOSITORY_OWNER") orelse @panic("$GITHUB_REPOSITORY_OWNER not set");
    }

    if (config.repo.len == 0) {
        std.log.warn("repo (-r) is empty! reading $GITHUB_REPOSITORY instead", .{});
        config.repo = std.posix.getenv("GITHUB_REPOSITORY") orelse @panic("$GITHUB_REPOSITORY not set");
        config.repo = config.repo[std.mem.indexOfScalar(u8, config.repo, '/').? + 1 ..];
    }

    if (config.tag.len == 0) {
        std.log.err("tag is empty!", .{});
        std.log.err("   ghr [options] <tag> <path>", .{});
        std.process.exit(1);
    }

    if (config.path.len == 0) {
        std.log.err("path is empty!", .{});
        std.log.err("   ghr [options] <tag> <path>", .{});
        std.process.exit(1);
    }

    if (config.title.len == 0) config.title = config.tag;
    if (config.commit.len == 0) config.commit = std.posix.getenv("GITHUB_SHA") orelse @panic("-c option not set and $GITHUB_SHA empty!");

    var buf: [4096]u8 = @splat(0);
    var client: std.http.Client = .{ .allocator = alloc };
    defer client.deinit();

    const url = try nio.fmt.allocPrint(alloc, "https://api.github.com/repos/{s}/{s}/releases", .{ config.user, config.repo });
    const body = try json.stringifyAlloc(alloc, .{
        .tag_name = config.tag,
        .target_commitish = config.commit,
        .name = config.title,
        .body = config.body,
        .draft = config.draft,
        .prerelease = config.prerelease,
    }, .{});
    var req = try client.open(.POST, try std.Uri.parse(url), .{
        .server_header_buffer = &buf,
        .headers = .{
            .accept_encoding = .{ .override = "application/vnd.github.v3+json" },
            .authorization = .{ .override = try std.mem.join(alloc, " ", &.{ "token", config.token }) },
            .content_type = .{ .override = "application/json" },
        },
    });
    defer req.deinit();
    req.transfer_encoding = .{ .content_length = body.len };
    try req.send();
    try req.writeAll(body);
    try req.finish();
    try req.wait();

    std.log.info("creating release: {s} @ {s}:{s}\n", .{ config.title, config.tag, config.commit });
    std.testing.expectEqual(@as(u16, 201), @intFromEnum(req.response.status)) catch {
        std.log.err("{s}", .{try req.reader().readAllAlloc(alloc, std.math.maxInt(usize))});
    };

    const doc = try json.parse(alloc, "", nio.AnyReadable.fromStd(&req.reader()), .{ .support_trailing_commas = true, .maximum_depth = 100 });
    defer doc.deinit(alloc);
    doc.acquire();
    defer doc.release();

    var upload_url = doc.root.object().getS("upload_url").?;
    upload_url = upload_url[0..std.mem.indexOfScalar(u8, upload_url, '{').?];

    const dir = try std.fs.cwd().openDir(config.path, .{ .iterate = true });
    var iter = dir.iterate();
    while (try iter.next()) |item| {
        var arena2 = std.heap.ArenaAllocator.init(alloc);
        defer arena2.deinit();
        const alloc2 = arena2.allocator();

        if (item.kind != .file) continue;
        std.log.info("--> Uploading: {s}\n", .{item.name});
        const path = try std.fs.path.join(alloc2, &.{ config.path, item.name });

        const file = try std.fs.cwd().openFile(path, .{});
        const contents = try file.reader().readAllAlloc(alloc2, std.math.maxInt(usize));

        const actualupurl = try std.mem.concat(alloc2, u8, &.{ upload_url, "?name=", item.name });
        var upreq = try client.open(.POST, try std.Uri.parse(actualupurl), .{
            .server_header_buffer = &buf,
            .headers = .{
                .accept_encoding = .{ .override = "application/vnd.github.v3+json" },
                .authorization = .{ .override = try std.mem.join(alloc2, " ", &.{ "token", config.token }) },
                .content_type = .{ .override = "application/octet-stream" },
            },
        });
        defer upreq.deinit();
        upreq.transfer_encoding = .{ .content_length = contents.len };
        try upreq.send();
        try upreq.writeAll(contents);
        try upreq.finish();
        try upreq.wait();
        std.testing.expectEqual(@as(u16, 201), @intFromEnum(upreq.response.status)) catch {
            std.log.debug("{s}", .{try upreq.reader().readAllAlloc(alloc2, std.math.maxInt(usize))});
        };
    }
}
