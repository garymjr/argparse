//! Parsing logic for command-line arguments.

const std = @import("std");
const Arg = @import("arg.zig").Arg;
const ArgKind = @import("arg.zig").ArgKind;
const Error = @import("error.zig").Error;

/// Container for parsed argument values.
pub const ParsedValues = struct {
    allocator: std.mem.Allocator,
    flags: std.StringHashMap(bool),
    options: std.StringHashMap([]const u8),
    positionals: std.ArrayList([]const u8),

    pub fn init(allocator: std.mem.Allocator) ParsedValues {
        return .{
            .allocator = allocator,
            .flags = std.StringHashMap(bool).init(allocator),
            .options = std.StringHashMap([]const u8).init(allocator),
            .positionals = std.ArrayList([]const u8){},
        };
    }

    pub fn deinit(self: *ParsedValues) void {
        self.flags.deinit();
        self.options.deinit();
        self.positionals.deinit(self.allocator);
    }

    /// Check if a flag was set.
    pub fn getFlag(self: *const ParsedValues, name: []const u8) bool {
        return self.flags.get(name) orelse false;
    }

    /// Get an option value, returns null if not set.
    pub fn getOption(self: *const ParsedValues, name: []const u8) ?[]const u8 {
        return self.options.get(name);
    }

    /// Get a required option value, error if not set.
    pub fn getRequiredOption(self: *const ParsedValues, name: []const u8) Error![]const u8 {
        return self.options.get(name) orelse error.MissingRequired;
    }

    /// Get all positional arguments.
    pub fn getPositionals(self: *const ParsedValues) []const []const u8 {
        return self.positionals.items;
    }
};

/// Parser for command-line arguments.
pub const Parser = struct {
    allocator: std.mem.Allocator,
    args: []const Arg,
    parsed: ParsedValues,

    /// Map short names to arg indices for fast lookup
    short_map: std.AutoHashMap(u8, usize),

    /// Map long names to arg indices for fast lookup
    long_map: std.StringHashMap(usize),

    pub fn init(allocator: std.mem.Allocator, args: []const Arg) !Parser {
        var short_map = std.AutoHashMap(u8, usize).init(allocator);
        var long_map = std.StringHashMap(usize).init(allocator);

        for (args, 0..) |arg, i| {
            if (arg.short) |s| {
                try short_map.put(s, i);
            }
            if (arg.long) |l| {
                try long_map.put(l, i);
            }
        }

        return .{
            .allocator = allocator,
            .args = args,
            .parsed = ParsedValues.init(allocator),
            .short_map = short_map,
            .long_map = long_map,
        };
    }

    pub fn deinit(self: *Parser) void {
        self.parsed.deinit();
        self.short_map.deinit();
        self.long_map.deinit();
    }

    /// Parse command-line arguments.
    pub fn parse(self: *Parser, argv: []const []const u8) !void {
        // Skip program name (argv[0])
        var i: usize = 1;
        while (i < argv.len) : (i += 1) {
            const arg_str = argv[i];

            // Check for long option: --name or --name=value
            if (std.mem.startsWith(u8, arg_str, "--")) {
                try self.parseLong(arg_str, &i, argv);
            }
            // Check for short option: -f or -fvalue
            else if (std.mem.startsWith(u8, arg_str, "-") and arg_str.len > 1) {
                try self.parseShort(arg_str, &i, argv);
            }
            // Otherwise, it's a positional
            else {
                try self.parsed.positionals.append(self.allocator, arg_str);
            }
        }

        // Validate required options
        for (self.args) |arg| {
            if (arg.required and arg.kind != .positional) {
                _ = try self.parsed.getRequiredOption(arg.name);
            }
        }
    }

    fn parseLong(self: *Parser, arg_str: []const u8, i: *usize, argv: []const []const u8) !void {
        const inner = arg_str[2..];

        // Check for --name=value syntax
        if (std.mem.indexOf(u8, inner, "=")) |eq_idx| {
            const name = inner[0..eq_idx];
            const value = inner[eq_idx + 1 ..];

            const arg_idx = self.long_map.get(name) orelse return Error.UnknownArgument;
            const arg = self.args[arg_idx];

            if (arg.kind == .flag) {
                try self.parsed.flags.put(arg.name, true);
            } else {
                try self.parsed.options.put(arg.name, value);
            }
        } else {
            // --name value syntax
            const arg_idx = self.long_map.get(inner) orelse return Error.UnknownArgument;
            const arg = self.args[arg_idx];

            if (arg.kind == .flag) {
                try self.parsed.flags.put(arg.name, true);
            } else {
                i.* += 1;
                if (i.* >= argv.len) return Error.MissingValue;
                try self.parsed.options.put(arg.name, argv[i.*]);
            }
        }
    }

    fn parseShort(self: *Parser, arg_str: []const u8, i: *usize, argv: []const []const u8) !void {
        // Single short flag: -f
        if (arg_str.len == 2) {
            const short = arg_str[1];
            const arg_idx = self.short_map.get(short) orelse return Error.UnknownArgument;
            const arg = self.args[arg_idx];

            if (arg.kind == .flag) {
                try self.parsed.flags.put(arg.name, true);
            } else {
                i.* += 1;
                if (i.* >= argv.len) return Error.MissingValue;
                try self.parsed.options.put(arg.name, argv[i.*]);
            }
        }
        // -fvalue syntax (short option with attached value)
        else {
            const short = arg_str[1];
            const arg_idx = self.short_map.get(short) orelse return Error.UnknownArgument;
            const arg = self.args[arg_idx];

            if (arg.kind == .flag) {
                // Multiple short flags combined: -vf
                for (arg_str[1..]) |c| {
                    const idx = self.short_map.get(c) orelse return Error.UnknownArgument;
                    const a = self.args[idx];
                    if (a.kind != .flag) return Error.UnknownArgument;
                    try self.parsed.flags.put(a.name, true);
                }
            } else {
                const value = arg_str[2..];
                try self.parsed.options.put(arg.name, value);
            }
        }
    }

    /// Get a flag value (convenience method).
    pub fn getFlag(self: *const Parser, name: []const u8) bool {
        return self.parsed.getFlag(name);
    }

    /// Get an option value (convenience method).
    pub fn getOption(self: *const Parser, name: []const u8) ?[]const u8 {
        return self.parsed.getOption(name);
    }

    /// Get a required option value (convenience method).
    pub fn getRequiredOption(self: *const Parser, name: []const u8) Error![]const u8 {
        return self.parsed.getRequiredOption(name);
    }

    /// Get positional arguments (convenience method).
    pub fn getPositionals(self: *const Parser) []const []const u8 {
        return self.parsed.getPositionals();
    }
};

test "parse single flag long" {
    const args = [_]Arg{
        .{ .name = "verbose", .long = "verbose", .kind = .flag },
    };

    const argv = [_][]const u8{ "program", "--verbose" };

    var parser = try Parser.init(std.testing.allocator, &args);
    defer parser.deinit();

    try parser.parse(&argv);

    try std.testing.expect(parser.getFlag("verbose"));
}

test "parse single flag short" {
    const args = [_]Arg{
        .{ .name = "verbose", .short = 'v', .kind = .flag },
    };

    const argv = [_][]const u8{ "program", "-v" };

    var parser = try Parser.init(std.testing.allocator, &args);
    defer parser.deinit();

    try parser.parse(&argv);

    try std.testing.expect(parser.getFlag("verbose"));
}

test "parse option long with space" {
    const args = [_]Arg{
        .{ .name = "file", .long = "file", .kind = .option },
    };

    const argv = [_][]const u8{ "program", "--file", "test.txt" };

    var parser = try Parser.init(std.testing.allocator, &args);
    defer parser.deinit();

    try parser.parse(&argv);

    try std.testing.expectEqualStrings("test.txt", parser.getOption("file").?);
}

test "parse option long with equals" {
    const args = [_]Arg{
        .{ .name = "file", .long = "file", .kind = .option },
    };

    const argv = [_][]const u8{ "program", "--file=test.txt" };

    var parser = try Parser.init(std.testing.allocator, &args);
    defer parser.deinit();

    try parser.parse(&argv);

    try std.testing.expectEqualStrings("test.txt", parser.getOption("file").?);
}

test "parse option short with space" {
    const args = [_]Arg{
        .{ .name = "file", .short = 'f', .kind = .option },
    };

    const argv = [_][]const u8{ "program", "-f", "test.txt" };

    var parser = try Parser.init(std.testing.allocator, &args);
    defer parser.deinit();

    try parser.parse(&argv);

    try std.testing.expectEqualStrings("test.txt", parser.getOption("file").?);
}

test "parse option short attached" {
    const args = [_]Arg{
        .{ .name = "file", .short = 'f', .kind = .option },
    };

    const argv = [_][]const u8{ "program", "-ftest.txt" };

    var parser = try Parser.init(std.testing.allocator, &args);
    defer parser.deinit();

    try parser.parse(&argv);

    try std.testing.expectEqualStrings("test.txt", parser.getOption("file").?);
}

test "parse multiple combined short flags" {
    const args = [_]Arg{
        .{ .name = "verbose", .short = 'v', .kind = .flag },
        .{ .name = "quiet", .short = 'q', .kind = .flag },
        .{ .name = "force", .short = 'f', .kind = .flag },
    };

    const argv = [_][]const u8{ "program", "-vqf" };

    var parser = try Parser.init(std.testing.allocator, &args);
    defer parser.deinit();

    try parser.parse(&argv);

    try std.testing.expect(parser.getFlag("verbose"));
    try std.testing.expect(parser.getFlag("quiet"));
    try std.testing.expect(parser.getFlag("force"));
}

test "parse mixed flags and options" {
    const args = [_]Arg{
        .{ .name = "verbose", .short = 'v', .long = "verbose", .kind = .flag },
        .{ .name = "file", .short = 'f', .long = "file", .kind = .option },
        .{ .name = "output", .short = 'o', .long = "output", .kind = .option },
    };

    const argv = [_][]const u8{ "program", "-v", "--file", "input.txt", "-o", "out.txt" };

    var parser = try Parser.init(std.testing.allocator, &args);
    defer parser.deinit();

    try parser.parse(&argv);

    try std.testing.expect(parser.getFlag("verbose"));
    try std.testing.expectEqualStrings("input.txt", parser.getOption("file").?);
    try std.testing.expectEqualStrings("out.txt", parser.getOption("output").?);
}

test "parse positional arguments" {
    const args = [_]Arg{
        .{ .name = "verbose", .short = 'v', .kind = .flag },
    };

    const argv = [_][]const u8{ "program", "file1.txt", "file2.txt", "-v" };

    var parser = try Parser.init(std.testing.allocator, &args);
    defer parser.deinit();

    try parser.parse(&argv);

    const positionals = parser.getPositionals();
    try std.testing.expectEqual(@as(usize, 2), positionals.len);
    try std.testing.expectEqualStrings("file1.txt", positionals[0]);
    try std.testing.expectEqualStrings("file2.txt", positionals[1]);
    try std.testing.expect(parser.getFlag("verbose"));
}

test "error unknown long argument" {
    const args = [_]Arg{
        .{ .name = "verbose", .long = "verbose", .kind = .flag },
    };

    const argv = [_][]const u8{ "program", "--unknown" };

    var parser = try Parser.init(std.testing.allocator, &args);
    defer parser.deinit();

    try std.testing.expectError(Error.UnknownArgument, parser.parse(&argv));
}

test "error unknown short argument" {
    const args = [_]Arg{
        .{ .name = "verbose", .short = 'v', .kind = .flag },
    };

    const argv = [_][]const u8{ "program", "-x" };

    var parser = try Parser.init(std.testing.allocator, &args);
    defer parser.deinit();

    try std.testing.expectError(Error.UnknownArgument, parser.parse(&argv));
}

test "error missing option value" {
    const args = [_]Arg{
        .{ .name = "file", .long = "file", .kind = .option },
    };

    const argv = [_][]const u8{ "program", "--file" };

    var parser = try Parser.init(std.testing.allocator, &args);
    defer parser.deinit();

    try std.testing.expectError(Error.MissingValue, parser.parse(&argv));
}

test "error missing required option" {
    const args = [_]Arg{
        .{ .name = "file", .long = "file", .kind = .option, .required = true },
    };

    const argv = [_][]const u8{ "program" };

    var parser = try Parser.init(std.testing.allocator, &args);
    defer parser.deinit();

    try std.testing.expectError(Error.MissingRequired, parser.parse(&argv));
}

test "no arguments" {
    const args = [_]Arg{
        .{ .name = "verbose", .short = 'v', .kind = .flag },
    };

    const argv = [_][]const u8{ "program" };

    var parser = try Parser.init(std.testing.allocator, &args);
    defer parser.deinit();

    try parser.parse(&argv);

    try std.testing.expect(!parser.getFlag("verbose"));
}
