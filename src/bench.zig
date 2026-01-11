const std = @import("std");
const argparse = @import("root.zig");

pub fn main() !void {
    const allocator = std.heap.page_allocator;

    const args = [_]argparse.Arg{
        .{ .name = "verbose", .short = 'v', .long = "verbose", .kind = .flag },
        .{ .name = "count", .short = 'c', .long = "count", .kind = .option, .value_type = .int },
        .{ .name = "file", .short = 'f', .long = "file", .kind = .option },
        .{ .name = "mode", .long = "mode", .kind = .option },
        .{ .name = "input", .kind = .positional, .position = 0 },
    };

    var argv = std.ArrayList([]const u8){};
    defer argv.deinit(allocator);

    try argv.append(allocator, "bench");
    try argv.append(allocator, "-v");
    try argv.append(allocator, "--count");
    try argv.append(allocator, "42");
    try argv.append(allocator, "--file");
    try argv.append(allocator, "data.txt");
    try argv.append(allocator, "--mode=fast");
    try argv.append(allocator, "input.txt");

    const iterations: usize = 10_000;

    var timer = try std.time.Timer.start();
    var i: usize = 0;
    while (i < iterations) : (i += 1) {
        var parser = try argparse.Parser.init(allocator, &args);
        try parser.parse(argv.items);
        parser.deinit();
    }
    const elapsed = timer.read();

    const per_iter = @as(u64, @intCast(elapsed / iterations));
    std.debug.print("parse: {d} ns/iter (total {d} ns)\n", .{ per_iter, elapsed });

    var help_timer = try std.time.Timer.start();
    var parser = try argparse.Parser.init(allocator, &args);
    const help = try parser.help();
    allocator.free(help);
    parser.deinit();
    const help_elapsed = help_timer.read();

    std.debug.print("help: {d} ns\n", .{help_elapsed});
}
