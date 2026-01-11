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

    const args = [_]argparse.Arg{
        .{
            .name = "verbose",
            .short = 'v',
            .long = "verbose",
            .kind = .flag,
            .help = "Enable verbose output",
        },
        .{
            .name = "count",
            .short = 'c',
            .long = "count",
            .kind = .option,
            .value_type = .int,
            .default = .{ .int = 1 },
            .help = "Number of times to repeat",
        },
        .{
            .name = "input",
            .kind = .positional,
            .position = 0,
            .value_type = .string,
            .help = "Input file",
        },
    };

    var parser = try argparse.Parser.initWithConfig(gpa, &args, .{
        .program_name = "simple",
        .description = "Simple argparse example",
    });
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

    if (parser.getFlag("verbose")) {
        std.debug.print("Verbose enabled\n", .{});
    }

    const count = try parser.getInt("count");
    const input = parser.getPositional("input") orelse "-";
    std.debug.print("Input: {s} ({d}x)\n", .{ input, count });
}
