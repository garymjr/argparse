const std = @import("std");
const argparse = @import("argparse");

fn collectArgv(allocator: std.mem.Allocator) !std.ArrayList([]const u8) {
    var argv = std.ArrayList([]const u8){};
    for (std.os.argv) |arg| {
        try argv.append(allocator, std.mem.span(arg));
    }
    return argv;
}

fn handleInit(parser: *argparse.Parser, argv: []const []const u8) !void {
    _ = argv;
    const path = parser.getOptionDefault("path") orelse ".todo";
    const force = parser.getFlag("force");
    std.debug.print("Init at {s} (force={any})\n", .{ path, force });
}

fn handleAdd(parser: *argparse.Parser, argv: []const []const u8) !void {
    _ = argv;
    const title = try parser.getRequiredPositional("title");
    const priority = try parser.getInt("priority");
    std.debug.print("Add: {s} (priority {d})\n", .{ title, priority });
}

const app = argparse.Command{
    .name = "todo",
    .help = "Simple task tracker",
    .subcommands = &[_]argparse.Command{
        .{
            .name = "init",
            .help = "Initialize storage",
            .args = &[_]argparse.Arg{
                .{
                    .name = "path",
                    .short = 'p',
                    .long = "path",
                    .kind = .option,
                    .value_type = .string,
                    .default = .{ .string = ".todo" },
                    .help = "Storage directory",
                },
                .{
                    .name = "force",
                    .short = 'f',
                    .long = "force",
                    .kind = .flag,
                    .help = "Overwrite existing data",
                },
            },
            .handler = handleInit,
        },
        .{
            .name = "add",
            .help = "Add a new task",
            .args = &[_]argparse.Arg{
                .{
                    .name = "priority",
                    .short = 'p',
                    .long = "priority",
                    .kind = .option,
                    .value_type = .int,
                    .default = .{ .int = 2 },
                    .help = "Priority level (default: 2)",
                },
                .{
                    .name = "title",
                    .kind = .positional,
                    .position = 0,
                    .value_type = .string,
                    .help = "Task title",
                },
            },
            .handler = handleAdd,
        },
    },
};

pub fn main() !void {
    const gpa = std.heap.page_allocator;

    var argv = try collectArgv(gpa);
    defer argv.deinit(gpa);

    app.run(gpa, argv.items) catch |err| switch (err) {
        argparse.Error.ShowHelp => {
            const help = try app.helpFor(gpa, argv.items);
            defer gpa.free(help);
            std.debug.print("{s}", .{help});
        },
        else => {
            // Show error message for all parsing errors
            const message = try app.formatError(gpa, err, argv.items, .{});
            defer gpa.free(message);
            std.debug.print("{s}\n", .{message});

            // Show help after error to guide the user
            const help = try app.helpFor(gpa, argv.items);
            defer gpa.free(help);
            std.debug.print("\n{s}", .{help});

            std.process.exit(1);
        },
    };
}
