//! Subcommand support for argparse.

const std = @import("std");
const array_list = std.array_list;
const Arg = @import("arg.zig").Arg;
const ValueType = @import("arg.zig").ValueType;
const Parser = @import("parser.zig").Parser;
const Error = @import("error.zig").Error;
const HelpConfig = @import("help.zig").HelpConfig;

/// Defines a command with optional subcommands.
pub const Command = struct {
    name: []const u8,
    args: []const Arg = &.{},
    subcommands: []const Command = &.{},
    help: []const u8 = "",
    handler: ?*const fn (*Parser, []const []const u8) anyerror!void = null,
    help_config: HelpConfig = .{},

    /// Run the command with argv (includes program name at argv[0]).
    pub fn run(self: *const Command, allocator: std.mem.Allocator, argv: []const []const u8) !void {
        const path = if (argv.len > 0) argv[0] else self.name;
        return self.runWithPath(allocator, argv, path);
    }

    /// Generate help for the command path indicated by argv.
    pub fn helpFor(self: *const Command, allocator: std.mem.Allocator, argv: []const []const u8) ![]const u8 {
        const path = if (argv.len > 0) argv[0] else self.name;
        return self.helpForPath(allocator, argv, path);
    }

    /// Generate help for this command only (no argv path inspection).
    pub fn helpText(self: *const Command, allocator: std.mem.Allocator) ![]const u8 {
        return self.generateHelp(allocator, self.name);
    }

    fn runWithPath(self: *const Command, allocator: std.mem.Allocator, argv: []const []const u8, path: []const u8) !void {
        const scan = scanForSubcommand(self, argv);
        if (scan.saw_help) return Error.ShowHelp;

        if (scan.match) |match| {
            const new_path = try joinPath(allocator, path, match.cmd.name);
            defer allocator.free(new_path);
            return match.cmd.runWithPath(allocator, argv[match.index..], new_path);
        }

        if (scan.first_positional != null and self.subcommands.len > 0 and !hasPositionals(self.args)) {
            return Error.UnknownCommand;
        }

        var config = self.help_config;
        config.program_name = path;
        if (config.description.len == 0) {
            config.description = self.help;
        }

        var parser = try Parser.initWithConfig(allocator, self.args, config);
        defer parser.deinit();

        try parser.parse(argv);

        if (self.handler) |handler| {
            try handler(&parser, argv);
        }
    }

    fn helpForPath(self: *const Command, allocator: std.mem.Allocator, argv: []const []const u8, path: []const u8) ![]const u8 {
        const scan = scanForSubcommand(self, argv);
        if (scan.match) |match| {
            const new_path = try joinPath(allocator, path, match.cmd.name);
            defer allocator.free(new_path);
            return match.cmd.helpForPath(allocator, argv[match.index..], new_path);
        }

        if (scan.first_positional != null and self.subcommands.len > 0 and !hasPositionals(self.args)) {
            return Error.UnknownCommand;
        }

        return self.generateHelp(allocator, path);
    }

    fn generateHelp(self: *const Command, allocator: std.mem.Allocator, path: []const u8) ![]const u8 {
        var config = self.help_config;
        config.program_name = path;
        if (config.description.len == 0) {
            config.description = self.help;
        }

        var buffer = array_list.AlignedManaged(u8, null).init(allocator);
        defer buffer.deinit();

        // Usage line
        try buffer.writer().print("Usage: {s}", .{config.program_name});

        if (hasOptions(self.args)) {
            try buffer.writer().writeAll(" [OPTIONS]");
        }

        if (self.subcommands.len > 0) {
            try buffer.writer().writeAll(" <subcommand>");
        }

        const positional_args = try collectPositionals(allocator, self.args);
        defer allocator.free(positional_args);

        for (positional_args) |arg| {
            if (arg.required) {
                try buffer.writer().print(" <{s}>", .{arg.name});
            } else {
                try buffer.writer().print(" [{s}]", .{arg.name});
            }
        }

        try buffer.writer().writeAll("\n\n");

        if (config.description.len > 0) {
            try buffer.writer().print("{s}\n\n", .{config.description});
        }

        if (self.args.len > 0) {
            try buffer.writer().writeAll("Arguments:\n");
            try displayArgs(buffer.writer(), allocator, self.args, config);
        }

        if (self.subcommands.len > 0) {
            try buffer.writer().writeAll("Subcommands:\n");
            try displaySubcommands(buffer.writer(), self.subcommands, config);
        }

        return buffer.toOwnedSlice();
    }
};

const SubcommandMatch = struct {
    cmd: *const Command,
    index: usize,
};

const SubcommandScan = struct {
    match: ?SubcommandMatch,
    first_positional: ?[]const u8,
    saw_help: bool,
};

fn scanForSubcommand(command: *const Command, argv: []const []const u8) SubcommandScan {
    var scan = SubcommandScan{ .match = null, .first_positional = null, .saw_help = false };

    var i: usize = 1;
    while (i < argv.len) : (i += 1) {
        const token = argv[i];

        if (std.mem.eql(u8, token, "--")) {
            break;
        }

        if (std.mem.eql(u8, token, "--help") or std.mem.eql(u8, token, "-h")) {
            scan.saw_help = true;
            break;
        }

        if (token.len > 0 and token[0] == '-') {
            continue;
        }

        scan.first_positional = token;
        if (findSubcommand(command, token)) |cmd| {
            scan.match = .{ .cmd = cmd, .index = i };
        }
        break;
    }

    return scan;
}

fn findSubcommand(command: *const Command, name: []const u8) ?*const Command {
    for (command.subcommands) |*sub| {
        if (std.mem.eql(u8, sub.name, name)) return sub;
    }
    return null;
}

fn hasOptions(args: []const Arg) bool {
    for (args) |arg| {
        if (arg.kind == .flag or arg.kind == .option or arg.kind == .count) return true;
    }
    return false;
}

fn hasPositionals(args: []const Arg) bool {
    for (args) |arg| {
        if (arg.kind == .positional) return true;
    }
    return false;
}

fn joinPath(allocator: std.mem.Allocator, prefix: []const u8, name: []const u8) ![]const u8 {
    var buffer = array_list.AlignedManaged(u8, null).init(allocator);
    defer buffer.deinit();

    try buffer.writer().print("{s} {s}", .{ prefix, name });
    return buffer.toOwnedSlice();
}

fn displaySubcommands(writer: anytype, subcommands: []const Command, config: HelpConfig) !void {
    for (subcommands) |cmd| {
        var options_buffer: [256]u8 = undefined;
        var fbs = std.io.fixedBufferStream(&options_buffer);

        try fbs.writer().print("  {s}", .{cmd.name});
        const options_text = fbs.getWritten();

        try writer.writeAll(options_text);

        const padding = if (options_text.len < config.options_width)
            config.options_width - options_text.len
        else
            1;

        var i: usize = 0;
        while (i < padding) : (i += 1) {
            try writer.writeByte(' ');
        }

        try writer.writeAll(cmd.help);
        try writer.writeAll("\n");
    }
}

fn displayArgs(writer: anytype, allocator: std.mem.Allocator, args: []const Arg, config: HelpConfig) !void {
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

    if (flags.items.len > 0) {
        try writer.writeAll("  Flags:\n");
        for (flags.items) |arg| {
            try displayArg(writer, arg.*, config, true);
        }
    }

    if (options.items.len > 0) {
        try writer.writeAll("  Options:\n");
        for (options.items) |arg| {
            try displayArg(writer, arg.*, config, true);
        }
    }

    if (positionals.items.len > 0) {
        try writer.writeAll("  Positionals:\n");
        for (positionals.items) |arg| {
            try displayArg(writer, arg.*, config, false);
        }
    }
}

fn displayArg(writer: anytype, arg: Arg, config: HelpConfig, has_prefix: bool) !void {
    var options_buffer: [256]u8 = undefined;
    var fbs = std.io.fixedBufferStream(&options_buffer);

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

        if (arg.kind == .option and config.show_placeholders) {
            const placeholder = getValuePlaceholder(arg.value_type);
            try option_writer.print(" <{s}>", .{placeholder});
        }
    } else {
        try option_writer.print("  <{s}>", .{arg.name});
    }

    const options_text = fbs.getWritten();

    try writer.writeAll(options_text);

    const padding = if (options_text.len < config.options_width)
        config.options_width - options_text.len
    else
        1;

    var i: usize = 0;
    while (i < padding) : (i += 1) {
        try writer.writeByte(' ');
    }

    try writer.writeAll(arg.help);

    if (arg.required) {
        try writer.writeAll(" (required)");
    }

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

fn getValuePlaceholder(value_type: ValueType) []const u8 {
    return switch (value_type) {
        .string => "string",
        .int => "int",
        .float => "float",
        .bool => "bool",
    };
}

fn collectPositionals(allocator: std.mem.Allocator, args: []const Arg) ![]const Arg {
    var positionals = array_list.AlignedManaged(Arg, null).init(allocator);
    defer positionals.deinit();

    for (args) |arg| {
        if (arg.kind == .positional) {
            try positionals.append(arg);
        }
    }

    std.sort.block(Arg, positionals.items, {}, struct {
        fn lessThan(_: void, a: Arg, b: Arg) bool {
            const pos_a = a.position orelse 999;
            const pos_b = b.position orelse 999;
            return pos_a < pos_b;
        }
    }.lessThan);

    return positionals.toOwnedSlice();
}
