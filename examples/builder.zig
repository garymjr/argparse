const std = @import("std");
const argparse = @import("argparse");

fn collectArgv(allocator: std.mem.Allocator) !std.ArrayList([]const u8) {
    var argv = std.ArrayList([]const u8){};
    for (std.os.argv) |arg| {
        try argv.append(allocator, std.mem.span(arg));
    }
    return argv;
}

pub fn main() !void {
    const gpa = std.heap.page_allocator;

    var builder = argparse.Builder.init(gpa);
    defer builder.deinit();

    try builder
        .addFlag("verbose", 'v', "verbose", "Enable verbose output")
        .addCount("debug", 'd', "debug", "Increase debug verbosity")
        .addOptionWith("mode", null, "mode", .string, "Run mode", .{
            .default = .{ .string = "auto" },
        })
        .addPositionalWith("input", .string, "Input file", .{ .required = true });

    var parser = try builder.build();
    defer parser.deinit();

    var argv = try collectArgv(gpa);
    defer argv.deinit(gpa);

    parser.parse(argv.items) catch |err| {
        if (err == argparse.Error.ShowHelp) {
            const help = try parser.help();
            defer gpa.free(help);
            std.debug.print("{s}", .{help});
            return;
        }

        const message = try parser.formatError(gpa, err, .{});
        defer gpa.free(message);
        std.debug.print("{s}\n", .{message});
        return err;
    };

    const mode = parser.getOptionDefault("mode") orelse "auto";
    const input = try parser.getRequiredPositional("input");
    const debug_level = parser.getCount("debug");
    const verbose = parser.getFlag("verbose");

    std.debug.print("mode={s} input={s} verbose={any} debug={d}\n", .{ mode, input, verbose, debug_level });
}
