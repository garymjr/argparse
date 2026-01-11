//! Help generation for command-line arguments.

const std = @import("std");
const array_list = std.array_list;
const Arg = @import("arg.zig").Arg;
const ArgKind = @import("arg.zig").ArgKind;
const ValueType = @import("arg.zig").ValueType;
const Ansi = @import("style.zig").Ansi;
const ColorMode = @import("style.zig").ColorMode;
const useColorStdout = @import("style.zig").useColorStdout;

/// Configuration for help text formatting.
pub const HelpConfig = struct {
    /// Program name for the help header
    program_name: []const u8 = "program",

    /// Brief description of the program (shown after usage line)
    description: []const u8 = "",

    /// Maximum line width for wrapping (0 = no wrapping)
    max_width: usize = 80,

    /// Width of the options column (for alignment)
    options_width: usize = 25,

    /// Whether to show value placeholders in options
    show_placeholders: bool = true,

    /// Color mode for help output
    color: ColorMode = .auto,
};

/// Generate help text for a set of arguments.
pub fn generateHelp(allocator: std.mem.Allocator, args: []const Arg, config: HelpConfig) ![]const u8 {
    var buffer = array_list.AlignedManaged(u8, null).init(allocator);
    defer buffer.deinit();
    const color = useColorStdout(config.color);

    // Header: usage line
    try writeLabel(buffer.writer(), color, "Usage:");
    try buffer.writer().print(" {s}", .{config.program_name});

    // Add [OPTIONS] if there are any flags or options
    var has_options = false;
    for (args) |arg| {
        if (arg.kind == .flag or arg.kind == .option or arg.kind == .count) {
            has_options = true;
            break;
        }
    }
    if (has_options) {
        try buffer.writer().writeAll(" [OPTIONS]");
    }

    // Add positional arguments to usage
    const positional_args = try collectPositionals(allocator, args);
    defer allocator.free(positional_args);

    for (positional_args) |arg| {
        if (arg.required) {
            try buffer.writer().print(" <{s}>", .{arg.name});
        } else {
            try buffer.writer().print(" [{s}]", .{arg.name});
        }
    }

    try buffer.writer().writeAll("\n\n");

    // Description
    if (config.description.len > 0) {
        try buffer.writer().print("{s}\n\n", .{config.description});
    }

    // Arguments section
    try writeSectionHeader(buffer.writer(), color, "Arguments:");

    // Group and display arguments
    try displayArgs(buffer.writer(), allocator, args, config, color);

    return buffer.toOwnedSlice();
}

/// Generate a brief usage line.
pub fn generateUsage(allocator: std.mem.Allocator, args: []const Arg, config: HelpConfig) ![]const u8 {
    var buffer = array_list.AlignedManaged(u8, null).init(allocator);
    defer buffer.deinit();
    const color = useColorStdout(config.color);

    try writeLabel(buffer.writer(), color, "Usage:");
    try buffer.writer().print(" {s}", .{config.program_name});

    var has_options = false;
    for (args) |arg| {
        if (arg.kind == .flag or arg.kind == .option or arg.kind == .count) {
            has_options = true;
            break;
        }
    }
    if (has_options) {
        try buffer.writer().writeAll(" [OPTIONS]");
    }

    const positional_args = try collectPositionals(allocator, args);
    defer allocator.free(positional_args);

    for (positional_args) |arg| {
        if (arg.required) {
            try buffer.writer().print(" <{s}>", .{arg.name});
        } else {
            try buffer.writer().print(" [{s}]", .{arg.name});
        }
    }

    return buffer.toOwnedSlice();
}

/// Display arguments grouped by kind.
fn displayArgs(writer: anytype, allocator: std.mem.Allocator, args: []const Arg, config: HelpConfig, color: bool) !void {
    // Separate args by kind
    var flags = array_list.AlignedManaged(*const Arg, null).init(allocator);
    defer flags.deinit();
    var options = array_list.AlignedManaged(*const Arg, null).init(allocator);
    defer options.deinit();
    var positionals = array_list.AlignedManaged(*const Arg, null).init(allocator);
    defer positionals.deinit();

    for (args) |*arg| {
        if (arg.kind == .flag or arg.kind == .count) {
            try flags.append(arg);
        } else if (arg.kind == .option) {
            try options.append(arg);
        } else if (arg.kind == .positional) {
            try positionals.append(arg);
        }
    }

    // Display flags
    if (flags.items.len > 0) {
        try writeIndentedHeader(writer, color, "Flags:");
        for (flags.items) |arg| {
            try displayArg(writer, arg.*, config, true);
        }
    }

    // Display options
    if (options.items.len > 0) {
        try writeIndentedHeader(writer, color, "Options:");
        for (options.items) |arg| {
            try displayArg(writer, arg.*, config, true);
        }
    }

    // Display positionals
    if (positionals.items.len > 0) {
        try writeIndentedHeader(writer, color, "Positionals:");
        for (positionals.items) |arg| {
            try displayArg(writer, arg.*, config, false);
        }
    }
}

fn writeLabel(writer: anytype, color: bool, text: []const u8) !void {
    if (color) {
        try writer.writeAll(Ansi.bold);
        try writer.writeAll(Ansi.green);
    }
    try writer.writeAll(text);
    if (color) {
        try writer.writeAll(Ansi.reset);
    }
}

fn writeSectionHeader(writer: anytype, color: bool, text: []const u8) !void {
    if (color) {
        try writer.writeAll(Ansi.bold);
        try writer.writeAll(Ansi.cyan);
    }
    try writer.writeAll(text);
    if (color) {
        try writer.writeAll(Ansi.reset);
    }
    try writer.writeAll("\n");
}

fn writeIndentedHeader(writer: anytype, color: bool, text: []const u8) !void {
    try writer.writeAll("  ");
    try writeSectionHeader(writer, color, text);
}

/// Display a single argument.
fn displayArg(writer: anytype, arg: Arg, config: HelpConfig, has_prefix: bool) !void {
    var options_buffer: [256]u8 = undefined;
    var fbs = std.io.fixedBufferStream(&options_buffer);

    // Build the option specification
    const option_writer = fbs.writer();

    if (has_prefix) {
        const has_short = (arg.short != null) or (arg.short_aliases.len > 0);
        var wrote_any = false;

        if (has_short) {
            if (arg.short) |s| {
                try option_writer.print("  -{c}", .{s});
                wrote_any = true;
            }
            for (arg.short_aliases) |alias| {
                if (!wrote_any) {
                    try option_writer.print("  -{c}", .{alias});
                    wrote_any = true;
                } else {
                    try option_writer.print(", -{c}", .{alias});
                }
            }
            if (arg.long) |l| {
                if (!wrote_any) {
                    try option_writer.print("      --{s}", .{l});
                    wrote_any = true;
                } else {
                    try option_writer.print(", --{s}", .{l});
                }
            }
            for (arg.aliases) |alias| {
                if (!wrote_any) {
                    try option_writer.print("      --{s}", .{alias});
                    wrote_any = true;
                } else {
                    try option_writer.print(", --{s}", .{alias});
                }
            }
        } else {
            if (arg.long) |l| {
                try option_writer.print("      --{s}", .{l});
                wrote_any = true;
            }
            for (arg.aliases) |alias| {
                if (!wrote_any) {
                    try option_writer.print("      --{s}", .{alias});
                    wrote_any = true;
                } else {
                    try option_writer.print(", --{s}", .{alias});
                }
            }
        }

        // Add value placeholder for options
        if (arg.kind == .option and config.show_placeholders) {
            const placeholder = getValuePlaceholder(arg.value_type);
            try option_writer.print(" <{s}>", .{placeholder});
        }
    } else {
        // Positional: just show the name
        try option_writer.print("  <{s}>", .{arg.name});
    }

    const options_text = fbs.getWritten();

    // Write the options column
    try writer.writeAll(options_text);

    // Calculate padding for alignment
    const padding = if (options_text.len < config.options_width)
        config.options_width - options_text.len
    else
        1;

    // Add padding
    var i: usize = 0;
    while (i < padding) : (i += 1) {
        try writer.writeByte(' ');
    }

    // Write help text
    try writer.writeAll(arg.help);

    // Add required marker
    if (arg.required) {
        try writer.writeAll(" (required)");
    }

    // Add default value indicator
    if (arg.default) |def| {
        switch (def) {
            .bool => |b| try writer.print(" [default: {}]", .{b}),
            .string => |s| try writer.print(" [default: {s}]", .{s}),
            .int => |n| try writer.print(" [default: {d}]", .{n}),
            .float => |f| try writer.print(" [default: {d}]", .{f}),
        }
    }

    try writer.writeAll("\n");
}

/// Get the value placeholder for a given value type.
fn getValuePlaceholder(value_type: ValueType) []const u8 {
    return switch (value_type) {
        .string => "string",
        .int => "int",
        .float => "float",
        .bool => "bool",
    };
}

/// Collect positional arguments in order.
fn collectPositionals(allocator: std.mem.Allocator, args: []const Arg) ![]const Arg {
    var positionals = array_list.AlignedManaged(Arg, null).init(allocator);
    defer positionals.deinit();

    for (args) |arg| {
        if (arg.kind == .positional) {
            try positionals.append(arg);
        }
    }

    // Sort by position if specified
    std.sort.block(Arg, positionals.items, {}, struct {
        fn lessThan(_: void, a: Arg, b: Arg) bool {
            const pos_a = a.position orelse 999;
            const pos_b = b.position orelse 999;
            return pos_a < pos_b;
        }
    }.lessThan);

    return positionals.toOwnedSlice();
}

/// Create a --help argument definition.
pub const helpArg = Arg{
    .name = "help",
    .short = 'h',
    .long = "help",
    .kind = .flag,
    .help = "Show this help message and exit",
};

test "generate basic help" {
    const args = [_]Arg{
        .{ .name = "verbose", .short = 'v', .long = "verbose", .kind = .flag, .help = "Enable verbose output" },
        .{ .name = "output", .short = 'o', .long = "output", .kind = .option, .help = "Output file path" },
        .{ .name = "count", .long = "count", .kind = .option, .value_type = .int, .help = "Number of iterations" },
        .{ .name = "input", .kind = .positional, .position = 0, .help = "Input file to process" },
    };

    const config = HelpConfig{
        .program_name = "myapp",
        .description = "A sample application for demonstration",
        .max_width = 80,
        .options_width = 25,
        .color = .never,
    };

    const help_text = try generateHelp(std.testing.allocator, &args, config);
    defer std.testing.allocator.free(help_text);

    // Verify key components are present
    try std.testing.expect(std.mem.indexOf(u8, help_text, "Usage: myapp") != null);
    try std.testing.expect(std.mem.indexOf(u8, help_text, "[OPTIONS]") != null);
    try std.testing.expect(std.mem.indexOf(u8, help_text, "<input>") != null);
    try std.testing.expect(std.mem.indexOf(u8, help_text, "-v, --verbose") != null);
    try std.testing.expect(std.mem.indexOf(u8, help_text, "Enable verbose output") != null);
    try std.testing.expect(std.mem.indexOf(u8, help_text, "-o, --output <string>") != null);
    try std.testing.expect(std.mem.indexOf(u8, help_text, "--count <int>") != null);
    try std.testing.expect(std.mem.indexOf(u8, help_text, "<input>") != null);
}

test "generate usage line" {
    const args = [_]Arg{
        .{ .name = "verbose", .short = 'v', .kind = .flag },
        .{ .name = "file", .kind = .positional, .position = 0, .required = true },
    };

    const config = HelpConfig{
        .program_name = "tool",
        .color = .never,
    };

    const usage = try generateUsage(std.testing.allocator, &args, config);
    defer std.testing.allocator.free(usage);

    try std.testing.expectEqualStrings("Usage: tool [OPTIONS] <file>", usage);
}

test "generate help with defaults" {
    const args = [_]Arg{
        .{ .name = "count", .long = "count", .kind = .option, .value_type = .int, .default = .{ .int = 10 }, .help = "Number of items" },
        .{ .name = "enabled", .long = "enabled", .kind = .option, .value_type = .bool, .default = .{ .bool = true }, .help = "Enable feature" },
        .{ .name = "output", .long = "output", .kind = .option, .value_type = .string, .default = .{ .string = "out.txt" }, .help = "Output file" },
    };

    const config = HelpConfig{
        .program_name = "app",
        .color = .never,
    };

    const help = try generateHelp(std.testing.allocator, &args, config);
    defer std.testing.allocator.free(help);

    try std.testing.expect(std.mem.indexOf(u8, help, "[default: 10]") != null);
    try std.testing.expect(std.mem.indexOf(u8, help, "[default: true]") != null);
    try std.testing.expect(std.mem.indexOf(u8, help, "[default: out.txt]") != null);
}

test "generate help with required marker" {
    const args = [_]Arg{
        .{ .name = "file", .long = "file", .kind = .option, .required = true, .help = "Input file" },
        .{ .name = "output", .long = "output", .kind = .option, .help = "Output file" },
    };

    const config = HelpConfig{
        .program_name = "app",
        .color = .never,
    };

    const help = try generateHelp(std.testing.allocator, &args, config);
    defer std.testing.allocator.free(help);

    try std.testing.expect(std.mem.indexOf(u8, help, "(required)") != null);
}

test "generate help no placeholders" {
    const args = [_]Arg{
        .{ .name = "file", .short = 'f', .long = "file", .kind = .option, .help = "Input file" },
    };

    const config = HelpConfig{
        .program_name = "app",
        .show_placeholders = false,
        .color = .never,
    };

    const help = try generateHelp(std.testing.allocator, &args, config);
    defer std.testing.allocator.free(help);

    try std.testing.expect(std.mem.indexOf(u8, help, "<string>") == null);
    try std.testing.expect(std.mem.indexOf(u8, help, "-f, --file") != null);
}
