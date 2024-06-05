const std = @import("std");
const string = []const u8;
const zfetch = @import("zfetch");
const extras = @import("extras");
const git = @import("git");

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

    std.debug.assert(config.token.len > 0);
    std.debug.assert(config.user.len > 0);
    std.debug.assert(config.repo.len > 0);
    std.debug.assert(config.tag.len > 0);
    std.debug.assert(config.path.len > 0);

    if (config.title.len == 0) config.title = config.tag;
    if (config.commit.len == 0) config.commit = try rev_HEAD(alloc);

    const url = try std.fmt.allocPrint(alloc, "https://api.github.com/repos/{s}/{s}/releases", .{ config.user, config.repo });
    var req = try fetchJson(alloc, config.token, .POST, url, .{
        .tag_name = config.tag,
        .target_commitish = config.commit,
        .name = config.title,
        .body = config.body,
        .draft = config.draft,
        .prerelease = config.prerelease,
    });
    defer req.deinit();

    const stdout = std.io.getStdOut().writer();
    try stdout.print("info: creating release: {s} @ {s}:{s}\n", .{ config.title, config.tag, config.commit });
    std.testing.expectEqual(@as(u16, 201), @intFromEnum(req.status)) catch std.process.exit(1);

    const reader = req.reader();
    const body_content = try reader.readAllAlloc(alloc, std.math.maxInt(usize));
    const val = try extras.parse_json(alloc, body_content);
    var upload_url = val.value.object.get("upload_url").?.string;
    upload_url = upload_url[0..std.mem.indexOfScalar(u8, upload_url, '{').?];

    const dir = try std.fs.cwd().openDir(config.path, .{ .iterate = true });
    var iter = dir.iterate();
    while (try iter.next()) |item| {
        var arena2 = std.heap.ArenaAllocator.init(alloc);
        defer arena2.deinit();
        const alloc2 = arena2.allocator();

        if (item.kind != .file) continue;
        try stdout.print("--> Uploading: {s}\n", .{item.name});
        const path = try std.fs.path.join(alloc2, &.{ config.path, item.name });

        const file = try std.fs.cwd().openFile(path, .{});
        const contents = try file.reader().readAllAlloc(alloc2, std.math.maxInt(usize));

        const actualupurl = try std.mem.concat(alloc2, u8, &.{ upload_url, "?name=", item.name });
        var upreq = try fetchRaw(alloc2, config.token, .POST, actualupurl, contents);
        std.testing.expectEqual(@as(u16, 201), @intFromEnum(upreq.status)) catch {
            std.log.debug("{s}", .{try upreq.reader().readAllAlloc(alloc2, std.math.maxInt(usize))});
        };
    }
}

/// Returns the result of running `git rev-parse HEAD`
pub fn rev_HEAD(alloc: std.mem.Allocator) !string {
    var dirg = try std.fs.cwd().openDir(".git", .{});
    defer dirg.close();
    const commit = try git.getHEAD(alloc, dirg);
    return commit.?.id;
}

fn fetchJson(allocator: std.mem.Allocator, token: string, method: std.http.Method, url: string, body: anytype) !*zfetch.Request {
    var headers = zfetch.Headers.init(allocator);
    defer headers.deinit();
    try headers.appendValue("Accept", "application/vnd.github.v3+json");
    try headers.appendValue("Authorization", try std.mem.join(allocator, " ", &.{ "token", token }));
    try headers.appendValue("Content-Type", "application/json");

    var req = try zfetch.Request.init(allocator, url, null);
    try req.do(method, headers, try std.json.stringifyAlloc(allocator, body, .{}));
    return req;
}

fn fetchRaw(allocator: std.mem.Allocator, token: string, method: std.http.Method, url: string, body: []const u8) !*zfetch.Request {
    var headers = zfetch.Headers.init(allocator);
    defer headers.deinit();
    try headers.appendValue("Accept", "application/vnd.github.v3+json");
    try headers.appendValue("Authorization", try std.mem.join(allocator, " ", &.{ "token", token }));
    try headers.appendValue("Content-Type", "application/octet-stream");
    try headers.appendValue("Content-Length", try std.fmt.allocPrint(allocator, "{d}", .{body.len}));

    var req = try zfetch.Request.init(allocator, url, null);
    try req.do(method, headers, body);
    return req;
}
