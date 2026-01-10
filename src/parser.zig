//! Parsing logic for command-line arguments.

const std = @import("std");
const Arg = @import("arg.zig").Arg;
const ArgKind = @import("arg.zig").ArgKind;
const ValueType = @import("arg.zig").ValueType;
const Value = @import("arg.zig").Value;
const Error = @import("error.zig").Error;
const HelpConfig = @import("help.zig").HelpConfig;
const generateHelp = @import("help.zig").generateHelp;

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

    /// Get a positional argument by position index (Phase 3).
    pub fn getPositional(self: *const ParsedValues, pos: usize) ?[]const u8 {
        if (pos < self.positionals.items.len) {
            return self.positionals.items[pos];
        }
        return null;
    }

    /// Get a positional argument by position index, error if not set (Phase 3).
    pub fn getRequiredPositional(self: *const ParsedValues, pos: usize) Error![]const u8 {
        return self.getPositional(pos) orelse error.MissingRequired;
    }

    /// Get a positional argument as integer by position (Phase 3).
    pub fn getIntPositional(self: *const ParsedValues, pos: usize) !i64 {
        const str = try self.getRequiredPositional(pos);
        return std.fmt.parseInt(i64, str, 10) catch return Error.InvalidValue;
    }

    /// Get a positional argument as float by position (Phase 3).
    pub fn getFloatPositional(self: *const ParsedValues, pos: usize) !f64 {
        const str = try self.getRequiredPositional(pos);
        return std.fmt.parseFloat(f64, str) catch return Error.InvalidValue;
    }

    /// Get an option value as an integer.
    pub fn getIntOption(self: *const ParsedValues, name: []const u8) !i64 {
        const str = self.options.get(name) orelse return Error.MissingRequired;
        return std.fmt.parseInt(i64, str, 10) catch return Error.InvalidValue;
    }

    /// Get an option value as an integer, with optional default.
    pub fn getIntOptionDefault(self: *const ParsedValues, name: []const u8, default: i64) !i64 {
        const str = self.options.get(name) orelse return default;
        return std.fmt.parseInt(i64, str, 10) catch return Error.InvalidValue;
    }

    /// Get an option value as a float.
    pub fn getFloatOption(self: *const ParsedValues, name: []const u8) !f64 {
        const str = self.options.get(name) orelse return Error.MissingRequired;
        return std.fmt.parseFloat(f64, str) catch return Error.InvalidValue;
    }

    /// Get an option value as a float, with optional default.
    pub fn getFloatOptionDefault(self: *const ParsedValues, name: []const u8, default: f64) !f64 {
        const str = self.options.get(name) orelse return default;
        return std.fmt.parseFloat(f64, str) catch return Error.InvalidValue;
    }

    /// Get an option value as a boolean.
    pub fn getBoolOption(self: *const ParsedValues, name: []const u8) !bool {
        const str = self.options.get(name) orelse return Error.MissingRequired;
        if (std.mem.eql(u8, str, "true") or std.mem.eql(u8, str, "1") or std.mem.eql(u8, str, "yes") or std.mem.eql(u8, str, "on")) {
            return true;
        }
        if (std.mem.eql(u8, str, "false") or std.mem.eql(u8, str, "0") or std.mem.eql(u8, str, "no") or std.mem.eql(u8, str, "off")) {
            return false;
        }
        return Error.InvalidValue;
    }

    /// Get an option value as a boolean, with optional default.
    pub fn getBoolOptionDefault(self: *const ParsedValues, name: []const u8, default: bool) !bool {
        const str = self.options.get(name) orelse return default;
        if (std.mem.eql(u8, str, "true") or std.mem.eql(u8, str, "1") or std.mem.eql(u8, str, "yes") or std.mem.eql(u8, str, "on")) {
            return true;
        }
        if (std.mem.eql(u8, str, "false") or std.mem.eql(u8, str, "0") or std.mem.eql(u8, str, "no") or std.mem.eql(u8, str, "off")) {
            return false;
        }
        return Error.InvalidValue;
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

    /// Configuration for help generation (Phase 4)
    help_config: HelpConfig,

    pub fn init(allocator: std.mem.Allocator, args: []const Arg) !Parser {
        return initWithConfig(allocator, args, HelpConfig{});
    }

    pub fn initWithConfig(allocator: std.mem.Allocator, args: []const Arg, config: HelpConfig) !Parser {
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
            .help_config = config,
        };
    }

    pub fn deinit(self: *Parser) void {
        self.parsed.deinit();
        self.short_map.deinit();
        self.long_map.deinit();
    }

    /// Parse command-line arguments.
    pub fn parse(self: *Parser, argv: []const []const u8) !void {
        // Auto-detect --help or -h flag (Phase 4)
        for (argv) |arg_str| {
            if (std.mem.eql(u8, arg_str, "--help") or std.mem.eql(u8, arg_str, "-h")) {
                return Error.ShowHelp;
            }
        }

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
                // If no value provided and no default, error
                if (self.parsed.options.get(arg.name) == null and arg.default == null) {
                    return Error.MissingRequired;
                }
            }
        }

        // Validate required positionals (Phase 3)
        for (self.args) |arg| {
            if (arg.required and arg.kind == .positional) {
                if (arg.position) |pos| {
                    if (pos >= self.parsed.positionals.items.len) {
                        return Error.MissingRequired;
                    }
                }
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

    /// Get a positional argument by name (Phase 3).
    /// Looks up the position from arg definition.
    pub fn getPositional(self: *const Parser, name: []const u8) ?[]const u8 {
        for (self.args) |arg| {
            if (std.mem.eql(u8, arg.name, name)) {
                if (arg.position) |pos| {
                    return self.parsed.getPositional(pos);
                }
            }
        }
        return null;
    }

    /// Get a required positional argument by name (Phase 3).
    pub fn getRequiredPositional(self: *const Parser, name: []const u8) Error![]const u8 {
        for (self.args) |arg| {
            if (std.mem.eql(u8, arg.name, name)) {
                if (arg.position) |pos| {
                    return self.parsed.getRequiredPositional(pos);
                }
            }
        }
        return Error.UnknownArgument;
    }

    /// Get a positional argument as integer by name (Phase 3).
    pub fn getIntPositional(self: *const Parser, name: []const u8) !i64 {
        for (self.args) |arg| {
            if (std.mem.eql(u8, arg.name, name)) {
                if (arg.position) |pos| {
                    return self.parsed.getIntPositional(pos);
                }
            }
        }
        return Error.UnknownArgument;
    }

    /// Get a positional argument as float by name (Phase 3).
    pub fn getFloatPositional(self: *const Parser, name: []const u8) !f64 {
        for (self.args) |arg| {
            if (std.mem.eql(u8, arg.name, name)) {
                if (arg.position) |pos| {
                    return self.parsed.getFloatPositional(pos);
                }
            }
        }
        return Error.UnknownArgument;
    }

    /// Get an option value, using default if not set.
    pub fn getOptionDefault(self: *const Parser, name: []const u8) ?[]const u8 {
        if (self.parsed.options.get(name)) |val| {
            return val;
        }
        // Look for default in arg definition
        for (self.args) |arg| {
            if (std.mem.eql(u8, arg.name, name)) {
                if (arg.default) |def| {
                    if (def == .string) return def.string;
                }
            }
        }
        return null;
    }

    /// Get an option value as integer, with default support from Arg definition.
    pub fn getInt(self: *const Parser, name: []const u8) !i64 {
        if (self.parsed.options.get(name)) |str| {
            return std.fmt.parseInt(i64, str, 10) catch return Error.InvalidValue;
        }
        // Look for default in arg definition
        for (self.args) |arg| {
            if (std.mem.eql(u8, arg.name, name)) {
                if (arg.default) |def| {
                    if (def == .int) return def.int;
                }
                if (arg.required) return Error.MissingRequired;
            }
        }
        return Error.MissingRequired;
    }

    /// Get an option value as float, with default support from Arg definition.
    pub fn getFloat(self: *const Parser, name: []const u8) !f64 {
        if (self.parsed.options.get(name)) |str| {
            return std.fmt.parseFloat(f64, str) catch return Error.InvalidValue;
        }
        // Look for default in arg definition
        for (self.args) |arg| {
            if (std.mem.eql(u8, arg.name, name)) {
                if (arg.default) |def| {
                    if (def == .float) return def.float;
                }
                if (arg.required) return Error.MissingRequired;
            }
        }
        return Error.MissingRequired;
    }

    /// Generic typed getter (Phase 2).
    pub fn get(self: *const Parser, comptime name: []const u8, comptime T: type) !T {
        const str_opt = self.parsed.options.get(name);

        // Find arg definition to get type info and default
        var arg_def: ?*const Arg = null;
        for (self.args) |*arg| {
            if (std.mem.eql(u8, arg.name, name)) {
                arg_def = arg;
                break;
            }
        }

        const arg = arg_def orelse return Error.UnknownArgument;

        // If value not provided, use default or error
        if (str_opt == null) {
            if (arg.default) |def| {
                switch (T) {
                    bool => {
                        if (def == .bool) return def.bool;
                    },
                    []const u8 => {
                        if (def == .string) return def.string;
                    },
                    i64, i32, i16, i8 => {
                        if (def == .int) return @as(T, @intCast(def.int));
                    },
                    f64, f32 => {
                        if (def == .float) return @as(f64, def.float);
                    },
                    else => {},
                }
            }
            if (arg.required) return Error.MissingRequired;
            return Error.MissingRequired;
        }

        const str = str_opt.?;

        // Type conversion with type checking
        switch (T) {
            bool => {
                if (std.mem.eql(u8, str, "true") or std.mem.eql(u8, str, "1") or std.mem.eql(u8, str, "yes") or std.mem.eql(u8, str, "on")) {
                    return true;
                }
                if (std.mem.eql(u8, str, "false") or std.mem.eql(u8, str, "0") or std.mem.eql(u8, str, "no") or std.mem.eql(u8, str, "off")) {
                    return false;
                }
                return Error.InvalidValue;
            },
            []const u8 => {
                return str;
            },
            i64 => {
                return std.fmt.parseInt(i64, str, 10) catch return Error.InvalidValue;
            },
            i32 => {
                const val = std.fmt.parseInt(i64, str, 10) catch return Error.InvalidValue;
                return std.math.cast(i32, val) orelse return Error.InvalidValue;
            },
            i16 => {
                const val = std.fmt.parseInt(i64, str, 10) catch return Error.InvalidValue;
                return std.math.cast(i16, val) orelse return Error.InvalidValue;
            },
            i8 => {
                const val = std.fmt.parseInt(i64, str, 10) catch return Error.InvalidValue;
                return std.math.cast(i8, val) orelse return Error.InvalidValue;
            },
            f64 => {
                return std.fmt.parseFloat(f64, str) catch return Error.InvalidValue;
            },
            f32 => {
                return std.math.cast(f32, try std.fmt.parseFloat(f64, str)) orelse return Error.InvalidValue;
            },
            else => {
                @compileError("Unsupported type for get(): " ++ @typeName(T));
            },
        }
    }

    /// Generate and return help text (Phase 4).
    pub fn help(self: *const Parser) ![]const u8 {
        return generateHelp(self.allocator, self.args, self.help_config);
    }

    /// Update help configuration (Phase 4).
    pub fn setHelpConfig(self: *Parser, config: HelpConfig) void {
        self.help_config = config;
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

// Phase 2 Tests: Type Conversion

test "get int option valid" {
    const args = [_]Arg{
        .{ .name = "count", .long = "count", .kind = .option, .value_type = .int },
    };

    const argv = [_][]const u8{ "program", "--count", "42" };

    var parser = try Parser.init(std.testing.allocator, &args);
    defer parser.deinit();

    try parser.parse(&argv);

    const count = try parser.getInt("count");
    try std.testing.expectEqual(@as(i64, 42), count);
}

test "get int option invalid" {
    const args = [_]Arg{
        .{ .name = "count", .long = "count", .kind = .option, .value_type = .int },
    };

    const argv = [_][]const u8{ "program", "--count", "not-a-number" };

    var parser = try Parser.init(std.testing.allocator, &args);
    defer parser.deinit();

    try parser.parse(&argv);

    try std.testing.expectError(Error.InvalidValue, parser.getInt("count"));
}

test "get float option valid" {
    const args = [_]Arg{
        .{ .name = "ratio", .long = "ratio", .kind = .option, .value_type = .float },
    };

    const argv = [_][]const u8{ "program", "--ratio", "3.14159" };

    var parser = try Parser.init(std.testing.allocator, &args);
    defer parser.deinit();

    try parser.parse(&argv);

    const ratio = try parser.getFloat("ratio");
    try std.testing.expectApproxEqAbs(@as(f64, 3.14159), ratio, 0.00001);
}

test "get bool option true" {
    const args = [_]Arg{
        .{ .name = "enabled", .long = "enabled", .kind = .option, .value_type = .bool },
    };

    const argv = [_][]const u8{ "program", "--enabled", "true" };

    var parser = try Parser.init(std.testing.allocator, &args);
    defer parser.deinit();

    try parser.parse(&argv);

    const enabled = try parser.parsed.getBoolOption("enabled");
    try std.testing.expect(enabled);
}

test "get bool option false" {
    const args = [_]Arg{
        .{ .name = "enabled", .long = "enabled", .kind = .option, .value_type = .bool },
    };

    const argv = [_][]const u8{ "program", "--enabled", "false" };

    var parser = try Parser.init(std.testing.allocator, &args);
    defer parser.deinit();

    try parser.parse(&argv);

    const enabled = try parser.parsed.getBoolOption("enabled");
    try std.testing.expect(!enabled);
}

test "get bool option yes" {
    const args = [_]Arg{
        .{ .name = "enabled", .long = "enabled", .kind = .option, .value_type = .bool },
    };

    const argv = [_][]const u8{ "program", "--enabled", "yes" };

    var parser = try Parser.init(std.testing.allocator, &args);
    defer parser.deinit();

    try parser.parse(&argv);

    const enabled = try parser.parsed.getBoolOption("enabled");
    try std.testing.expect(enabled);
}

test "get bool option 1" {
    const args = [_]Arg{
        .{ .name = "enabled", .long = "enabled", .kind = .option, .value_type = .bool },
    };

    const argv = [_][]const u8{ "program", "--enabled", "1" };

    var parser = try Parser.init(std.testing.allocator, &args);
    defer parser.deinit();

    try parser.parse(&argv);

    const enabled = try parser.parsed.getBoolOption("enabled");
    try std.testing.expect(enabled);
}

test "get bool option invalid" {
    const args = [_]Arg{
        .{ .name = "enabled", .long = "enabled", .kind = .option, .value_type = .bool },
    };

    const argv = [_][]const u8{ "program", "--enabled", "maybe" };

    var parser = try Parser.init(std.testing.allocator, &args);
    defer parser.deinit();

    try parser.parse(&argv);

    try std.testing.expectError(Error.InvalidValue, parser.parsed.getBoolOption("enabled"));
}

test "get generic bool" {
    const args = [_]Arg{
        .{ .name = "flag", .long = "flag", .kind = .option, .value_type = .bool },
    };

    const argv = [_][]const u8{ "program", "--flag", "true" };

    var parser = try Parser.init(std.testing.allocator, &args);
    defer parser.deinit();

    try parser.parse(&argv);

    const flag = try parser.get("flag", bool);
    try std.testing.expect(flag);
}

test "get generic string" {
    const args = [_]Arg{
        .{ .name = "name", .long = "name", .kind = .option, .value_type = .string },
    };

    const argv = [_][]const u8{ "program", "--name", "ziggy" };

    var parser = try Parser.init(std.testing.allocator, &args);
    defer parser.deinit();

    try parser.parse(&argv);

    const name = try parser.get("name", []const u8);
    try std.testing.expectEqualStrings("ziggy", name);
}

test "get generic i64" {
    const args = [_]Arg{
        .{ .name = "count", .long = "count", .kind = .option, .value_type = .int },
    };

    const argv = [_][]const u8{ "program", "--count", "100" };

    var parser = try Parser.init(std.testing.allocator, &args);
    defer parser.deinit();

    try parser.parse(&argv);

    const count = try parser.get("count", i64);
    try std.testing.expectEqual(@as(i64, 100), count);
}

test "get generic i32" {
    const args = [_]Arg{
        .{ .name = "port", .long = "port", .kind = .option, .value_type = .int },
    };

    const argv = [_][]const u8{ "program", "--port", "8080" };

    var parser = try Parser.init(std.testing.allocator, &args);
    defer parser.deinit();

    try parser.parse(&argv);

    const port = try parser.get("port", i32);
    try std.testing.expectEqual(@as(i32, 8080), port);
}

test "get generic f64" {
    const args = [_]Arg{
        .{ .name = "ratio", .long = "ratio", .kind = .option, .value_type = .float },
    };

    const argv = [_][]const u8{ "program", "--ratio", "2.71828" };

    var parser = try Parser.init(std.testing.allocator, &args);
    defer parser.deinit();

    try parser.parse(&argv);

    const ratio = try parser.get("ratio", f64);
    try std.testing.expectApproxEqAbs(@as(f64, 2.71828), ratio, 0.00001);
}

// Phase 2 Tests: Default Values

test "default int value" {
    const args = [_]Arg{
        .{ .name = "count", .long = "count", .kind = .option, .value_type = .int, .default = .{ .int = 10 } },
    };

    const argv = [_][]const u8{ "program" };

    var parser = try Parser.init(std.testing.allocator, &args);
    defer parser.deinit();

    try parser.parse(&argv);

    const count = try parser.getInt("count");
    try std.testing.expectEqual(@as(i64, 10), count);
}

test "default string value" {
    const args = [_]Arg{
        .{ .name = "output", .long = "output", .kind = .option, .value_type = .string, .default = .{ .string = "out.txt" } },
    };

    const argv = [_][]const u8{ "program" };

    var parser = try Parser.init(std.testing.allocator, &args);
    defer parser.deinit();

    try parser.parse(&argv);

    const output = parser.getOptionDefault("output");
    try std.testing.expect(output != null);
    try std.testing.expectEqualStrings("out.txt", output.?);
}

test "default float value" {
    const args = [_]Arg{
        .{ .name = "threshold", .long = "threshold", .kind = .option, .value_type = .float, .default = .{ .float = 0.5 } },
    };

    const argv = [_][]const u8{ "program" };

    var parser = try Parser.init(std.testing.allocator, &args);
    defer parser.deinit();

    try parser.parse(&argv);

    const threshold = try parser.getFloat("threshold");
    try std.testing.expectApproxEqAbs(@as(f64, 0.5), threshold, 0.00001);
}

test "default value overridden by cli argument" {
    const args = [_]Arg{
        .{ .name = "count", .long = "count", .kind = .option, .value_type = .int, .default = .{ .int = 10 } },
    };

    const argv = [_][]const u8{ "program", "--count", "42" };

    var parser = try Parser.init(std.testing.allocator, &args);
    defer parser.deinit();

    try parser.parse(&argv);

    const count = try parser.getInt("count");
    try std.testing.expectEqual(@as(i64, 42), count);
}

test "generic get with default" {
    const args = [_]Arg{
        .{ .name = "port", .long = "port", .kind = .option, .value_type = .int, .default = .{ .int = 3000 } },
    };

    const argv = [_][]const u8{ "program" };

    var parser = try Parser.init(std.testing.allocator, &args);
    defer parser.deinit();

    try parser.parse(&argv);

    const port = try parser.get("port", i32);
    try std.testing.expectEqual(@as(i32, 3000), port);
}

test "get with default overridden" {
    const args = [_]Arg{
        .{ .name = "port", .long = "port", .kind = .option, .value_type = .int, .default = .{ .int = 3000 } },
    };

    const argv = [_][]const u8{ "program", "--port", "8080" };

    var parser = try Parser.init(std.testing.allocator, &args);
    defer parser.deinit();

    try parser.parse(&argv);

    const port = try parser.get("port", i32);
    try std.testing.expectEqual(@as(i32, 8080), port);
}

test "required with no value and no default" {
    const args = [_]Arg{
        .{ .name = "count", .long = "count", .kind = .option, .value_type = .int, .required = true },
    };

    const argv = [_][]const u8{ "program" };

    var parser = try Parser.init(std.testing.allocator, &args);
    defer parser.deinit();

    try std.testing.expectError(Error.MissingRequired, parser.parse(&argv));
}

test "required satisfied by default" {
    const args = [_]Arg{
        .{ .name = "count", .long = "count", .kind = .option, .value_type = .int, .required = true, .default = .{ .int = 5 } },
    };

    const argv = [_][]const u8{ "program" };

    var parser = try Parser.init(std.testing.allocator, &args);
    defer parser.deinit();

    try parser.parse(&argv);

    const count = try parser.getInt("count");
    try std.testing.expectEqual(@as(i64, 5), count);
}

test "parsed values get int option default" {
    const args = [_]Arg{
        .{ .name = "count", .long = "count", .kind = .option, .value_type = .int },
    };

    const argv = [_][]const u8{ "program" };

    var parser = try Parser.init(std.testing.allocator, &args);
    defer parser.deinit();

    try parser.parse(&argv);

    const count = try parser.parsed.getIntOptionDefault("count", 10);
    try std.testing.expectEqual(@as(i64, 10), count);
}

test "parsed values get float option default" {
    const args = [_]Arg{
        .{ .name = "ratio", .long = "ratio", .kind = .option, .value_type = .float },
    };

    const argv = [_][]const u8{ "program" };

    var parser = try Parser.init(std.testing.allocator, &args);
    defer parser.deinit();

    try parser.parse(&argv);

    const ratio = try parser.parsed.getFloatOptionDefault("ratio", 0.5);
    try std.testing.expectApproxEqAbs(@as(f64, 0.5), ratio, 0.00001);
}

test "parsed values get bool option default" {
    const args = [_]Arg{
        .{ .name = "enabled", .long = "enabled", .kind = .option, .value_type = .bool },
    };

    const argv = [_][]const u8{ "program" };

    var parser = try Parser.init(std.testing.allocator, &args);
    defer parser.deinit();

    try parser.parse(&argv);

    const enabled = try parser.parsed.getBoolOptionDefault("enabled", false);
    try std.testing.expect(!enabled);
}

// Phase 3 Tests: Positional Arguments

test "positional argument defined" {
    const args = [_]Arg{
        .{ .name = "input", .kind = .positional, .position = 0 },
    };

    const argv = [_][]const u8{ "program", "file.txt" };

    var parser = try Parser.init(std.testing.allocator, &args);
    defer parser.deinit();

    try parser.parse(&argv);

    const input = parser.getPositional("input");
    try std.testing.expect(input != null);
    try std.testing.expectEqualStrings("file.txt", input.?);
}

test "positional argument by position index" {
    const args = [_]Arg{
        .{ .name = "input", .kind = .positional, .position = 0 },
    };

    const argv = [_][]const u8{ "program", "file.txt" };

    var parser = try Parser.init(std.testing.allocator, &args);
    defer parser.deinit();

    try parser.parse(&argv);

    const input = parser.parsed.getPositional(0);
    try std.testing.expect(input != null);
    try std.testing.expectEqualStrings("file.txt", input.?);
}

test "multiple positional arguments" {
    const args = [_]Arg{
        .{ .name = "input", .kind = .positional, .position = 0 },
        .{ .name = "output", .kind = .positional, .position = 1 },
    };

    const argv = [_][]const u8{ "program", "input.txt", "output.txt" };

    var parser = try Parser.init(std.testing.allocator, &args);
    defer parser.deinit();

    try parser.parse(&argv);

    const input = parser.getPositional("input");
    const output = parser.getPositional("output");

    try std.testing.expect(input != null);
    try std.testing.expect(output != null);
    try std.testing.expectEqualStrings("input.txt", input.?);
    try std.testing.expectEqualStrings("output.txt", output.?);
}

test "required positional provided" {
    const args = [_]Arg{
        .{ .name = "input", .kind = .positional, .position = 0, .required = true },
    };

    const argv = [_][]const u8{ "program", "file.txt" };

    var parser = try Parser.init(std.testing.allocator, &args);
    defer parser.deinit();

    try parser.parse(&argv);

    const input = try parser.getRequiredPositional("input");
    try std.testing.expectEqualStrings("file.txt", input);
}

test "required positional missing" {
    const args = [_]Arg{
        .{ .name = "input", .kind = .positional, .position = 0, .required = true },
    };

    const argv = [_][]const u8{ "program" };

    var parser = try Parser.init(std.testing.allocator, &args);
    defer parser.deinit();

    try std.testing.expectError(Error.MissingRequired, parser.parse(&argv));
}

test "positional as integer" {
    const args = [_]Arg{
        .{ .name = "count", .kind = .positional, .position = 0, .value_type = .int },
    };

    const argv = [_][]const u8{ "program", "42" };

    var parser = try Parser.init(std.testing.allocator, &args);
    defer parser.deinit();

    try parser.parse(&argv);

    const count = try parser.getIntPositional("count");
    try std.testing.expectEqual(@as(i64, 42), count);
}

test "positional as float" {
    const args = [_]Arg{
        .{ .name = "ratio", .kind = .positional, .position = 0, .value_type = .float },
    };

    const argv = [_][]const u8{ "program", "3.14159" };

    var parser = try Parser.init(std.testing.allocator, &args);
    defer parser.deinit();

    try parser.parse(&argv);

    const ratio = try parser.getFloatPositional("ratio");
    try std.testing.expectApproxEqAbs(@as(f64, 3.14159), ratio, 0.00001);
}

test "positional invalid integer" {
    const args = [_]Arg{
        .{ .name = "count", .kind = .positional, .position = 0, .value_type = .int },
    };

    const argv = [_][]const u8{ "program", "not-a-number" };

    var parser = try Parser.init(std.testing.allocator, &args);
    defer parser.deinit();

    try parser.parse(&argv);

    try std.testing.expectError(Error.InvalidValue, parser.getIntPositional("count"));
}

test "mixed flags and positionals" {
    const args = [_]Arg{
        .{ .name = "verbose", .short = 'v', .long = "verbose", .kind = .flag },
        .{ .name = "input", .kind = .positional, .position = 0 },
        .{ .name = "output", .kind = .positional, .position = 1 },
    };

    const argv = [_][]const u8{ "program", "-v", "input.txt", "output.txt" };

    var parser = try Parser.init(std.testing.allocator, &args);
    defer parser.deinit();

    try parser.parse(&argv);

    try std.testing.expect(parser.getFlag("verbose"));
    try std.testing.expectEqualStrings("input.txt", parser.getPositional("input").?);
    try std.testing.expectEqualStrings("output.txt", parser.getPositional("output").?);
}

test "mixed options and positionals" {
    const args = [_]Arg{
        .{ .name = "file", .short = 'f', .long = "file", .kind = .option },
        .{ .name = "input", .kind = .positional, .position = 0 },
    };

    const argv = [_][]const u8{ "program", "--file", "config.txt", "data.txt" };

    var parser = try Parser.init(std.testing.allocator, &args);
    defer parser.deinit();

    try parser.parse(&argv);

    try std.testing.expectEqualStrings("config.txt", parser.getOption("file").?);
    try std.testing.expectEqualStrings("data.txt", parser.getPositional("input").?);
}

test "flags after positionals" {
    const args = [_]Arg{
        .{ .name = "verbose", .short = 'v', .kind = .flag },
        .{ .name = "input", .kind = .positional, .position = 0 },
    };

    const argv = [_][]const u8{ "program", "data.txt", "-v" };

    var parser = try Parser.init(std.testing.allocator, &args);
    defer parser.deinit();

    try parser.parse(&argv);

    try std.testing.expect(parser.getFlag("verbose"));
    try std.testing.expectEqualStrings("data.txt", parser.getPositional("input").?);
}

test "options after positionals" {
    const args = [_]Arg{
        .{ .name = "count", .short = 'c', .long = "count", .kind = .option },
        .{ .name = "input", .kind = .positional, .position = 0 },
    };

    const argv = [_][]const u8{ "program", "data.txt", "--count", "10" };

    var parser = try Parser.init(std.testing.allocator, &args);
    defer parser.deinit();

    try parser.parse(&argv);

    try std.testing.expectEqualStrings("10", parser.getOption("count").?);
    try std.testing.expectEqualStrings("data.txt", parser.getPositional("input").?);
}

test "fully mixed: flags, options, and positionals" {
    const args = [_]Arg{
        .{ .name = "verbose", .short = 'v', .kind = .flag },
        .{ .name = "output", .short = 'o', .long = "output", .kind = .option },
        .{ .name = "input", .kind = .positional, .position = 0 },
        .{ .name = "count", .kind = .positional, .position = 1 },
    };

    const argv = [_][]const u8{ "program", "-v", "input.txt", "5", "--output", "result.txt" };

    var parser = try Parser.init(std.testing.allocator, &args);
    defer parser.deinit();

    try parser.parse(&argv);

    try std.testing.expect(parser.getFlag("verbose"));
    try std.testing.expectEqualStrings("result.txt", parser.getOption("output").?);
    try std.testing.expectEqualStrings("input.txt", parser.getPositional("input").?);
    try std.testing.expectEqual(@as(i64, 5), try parser.getIntPositional("count"));
}

test "unnamed positionals collected" {
    const args = [_]Arg{
        .{ .name = "verbose", .short = 'v', .kind = .flag },
    };

    const argv = [_][]const u8{ "program", "file1.txt", "file2.txt", "file3.txt", "-v" };

    var parser = try Parser.init(std.testing.allocator, &args);
    defer parser.deinit();

    try parser.parse(&argv);

    const positionals = parser.getPositionals();
    try std.testing.expectEqual(@as(usize, 3), positionals.len);
    try std.testing.expectEqualStrings("file1.txt", positionals[0]);
    try std.testing.expectEqualStrings("file2.txt", positionals[1]);
    try std.testing.expectEqualStrings("file3.txt", positionals[2]);
    try std.testing.expect(parser.getFlag("verbose"));
}

test "partial named positionals with extras" {
    const args = [_]Arg{
        .{ .name = "input", .kind = .positional, .position = 0 },
    };

    const argv = [_][]const u8{ "program", "main.txt", "extra1.txt", "extra2.txt" };

    var parser = try Parser.init(std.testing.allocator, &args);
    defer parser.deinit();

    try parser.parse(&argv);

    try std.testing.expectEqualStrings("main.txt", parser.getPositional("input").?);

    const positionals = parser.getPositionals();
    try std.testing.expectEqual(@as(usize, 3), positionals.len);
}

test "missing positional at defined position" {
    const args = [_]Arg{
        .{ .name = "input", .kind = .positional, .position = 0 },
        .{ .name = "output", .kind = .positional, .position = 1 },
    };

    const argv = [_][]const u8{ "program", "only-input.txt" };

    var parser = try Parser.init(std.testing.allocator, &args);
    defer parser.deinit();

    try parser.parse(&argv);

    try std.testing.expectEqualStrings("only-input.txt", parser.getPositional("input").?);
    try std.testing.expect(parser.getPositional("output") == null);
}

// Phase 4 Tests: Help Generation

test "parser help method generates help" {
    const args = [_]Arg{
        .{ .name = "verbose", .short = 'v', .long = "verbose", .kind = .flag, .help = "Enable verbose output" },
        .{ .name = "output", .short = 'o', .long = "output", .kind = .option, .help = "Output file" },
    };

    var parser = try Parser.init(std.testing.allocator, &args);
    defer parser.deinit();

    const help = try parser.help();
    defer std.testing.allocator.free(help);

    try std.testing.expect(std.mem.indexOf(u8, help, "Usage:") != null);
    try std.testing.expect(std.mem.indexOf(u8, help, "-v, --verbose") != null);
    try std.testing.expect(std.mem.indexOf(u8, help, "Enable verbose output") != null);
    try std.testing.expect(std.mem.indexOf(u8, help, "-o, --output") != null);
}

test "parser with custom help config" {
    const args = [_]Arg{
        .{ .name = "verbose", .short = 'v', .long = "verbose", .kind = .flag, .help = "Enable verbose output" },
    };

    const config = HelpConfig{
        .program_name = "mytool",
        .description = "A tool for doing things",
        .options_width = 30,
    };

    var parser = try Parser.initWithConfig(std.testing.allocator, &args, config);
    defer parser.deinit();

    const help = try parser.help();
    defer std.testing.allocator.free(help);

    try std.testing.expect(std.mem.indexOf(u8, help, "Usage: mytool") != null);
    try std.testing.expect(std.mem.indexOf(u8, help, "A tool for doing things") != null);
}

test "parse returns ShowHelp for --help" {
    const args = [_]Arg{
        .{ .name = "verbose", .short = 'v', .long = "verbose", .kind = .flag },
    };

    const argv = [_][]const u8{ "program", "--help" };

    var parser = try Parser.init(std.testing.allocator, &args);
    defer parser.deinit();

    try std.testing.expectError(Error.ShowHelp, parser.parse(&argv));
}

test "parse returns ShowHelp for -h" {
    const args = [_]Arg{
        .{ .name = "verbose", .short = 'v', .long = "verbose", .kind = .flag },
    };

    const argv = [_][]const u8{ "program", "-h" };

    var parser = try Parser.init(std.testing.allocator, &args);
    defer parser.deinit();

    try std.testing.expectError(Error.ShowHelp, parser.parse(&argv));
}

test "setHelpConfig updates configuration" {
    const args = [_]Arg{
        .{ .name = "verbose", .short = 'v', .long = "verbose", .kind = .flag, .help = "Enable verbose output" },
    };

    var parser = try Parser.init(std.testing.allocator, &args);
    defer parser.deinit();

    parser.setHelpConfig(.{
        .program_name = "newname",
        .description = "New description",
    });

    const help = try parser.help();
    defer std.testing.allocator.free(help);

    try std.testing.expect(std.mem.indexOf(u8, help, "Usage: newname") != null);
    try std.testing.expect(std.mem.indexOf(u8, help, "New description") != null);
}
