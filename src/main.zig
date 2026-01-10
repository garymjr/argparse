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
    };

    var parser = try argparse.Parser.init(gpa, &args);
    defer parser.deinit();

    // Convert std.os.argv to the expected format
    var argv_slice = std.ArrayList([]const u8){};
    defer argv_slice.deinit(gpa);
    for (std.os.argv) |arg| {
        try argv_slice.append(gpa, std.mem.span(arg));
    }

    try parser.parse(argv_slice.items);

    if (parser.getFlag("verbose")) {
        std.debug.print("Verbose mode enabled\n", .{});
    }

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
