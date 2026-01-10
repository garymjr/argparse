const std = @import("std");
const argparse = @import("root.zig");

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
            .default = .{ .int = 10 },
            .help = "Number of iterations (default: 10)",
        },
        .{
            .name = "file",
            .short = 'f',
            .long = "file",
            .kind = .option,
            .help = "Input file to process",
        },
        .{
            .name = "output",
            .short = 'o',
            .long = "output",
            .kind = .option,
            .required = true,
            .help = "Output file (required)",
        },
        .{
            .name = "input",
            .kind = .positional,
            .position = 0,
            .help = "Input data",
        },
    };

    var parser = try argparse.Parser.initWithConfig(gpa, &args, .{
        .program_name = "example",
        .description = "Demonstrates argparse library with help generation",
    });
    defer parser.deinit();

    // Convert std.os.argv to the expected format
    var argv_slice = std.ArrayList([]const u8){};
    defer argv_slice.deinit(gpa);
    for (std.os.argv) |arg| {
        try argv_slice.append(gpa, std.mem.span(arg));
    }

    parser.parse(argv_slice.items) catch |err| {
        if (err == argparse.Error.ShowHelp) {
            const help = try parser.help();
            defer gpa.free(help);
            std.debug.print("{s}", .{help});
            return;
        }
        return err;
    };

    if (parser.getFlag("verbose")) {
        std.debug.print("Verbose mode enabled\n", .{});
    }

    const count = try parser.getInt("count");
    std.debug.print("Count: {d}\n", .{count});

    const output = try parser.getRequiredOption("output");
    std.debug.print("Output file: {s}\n", .{output});

    if (parser.getOption("file")) |file| {
        std.debug.print("Input file: {s}\n", .{file});
    }

    const positionals = parser.getPositionals();
    if (positionals.len > 0) {
        std.debug.print("Positional arguments:\n", .{});
        for (positionals) |arg| {
            std.debug.print("  {s}\n", .{arg});
        }
    }
}
