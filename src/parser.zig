//! Parsing logic for command-line arguments.

const std = @import("std");
const Arg = @import("arg.zig").Arg;
const ArgKind = @import("arg.zig").ArgKind;
const ValueType = @import("arg.zig").ValueType;
const Value = @import("arg.zig").Value;
const Error = @import("error.zig").Error;
const ErrorContext = @import("error.zig").ErrorContext;
const ErrorFormatConfig = @import("error.zig").ErrorFormatConfig;
const formatErrorMessage = @import("error.zig").formatError;
const HelpConfig = @import("help.zig").HelpConfig;
const generateHelp = @import("help.zig").generateHelp;
pub const ParsedValues = @import("parsed_values.zig").ParsedValues;

/// Parser for command-line arguments.
pub const Parser = struct {
    allocator: std.mem.Allocator,
    args: []const Arg,
    parsed: ParsedValues,
    owned_args: ?[]const Arg = null,

    /// Map short names to arg indices for fast lookup
    short_map: std.AutoHashMap(u8, usize),

    /// Map long names to arg indices for fast lookup
    long_map: std.StringHashMap(usize),

    /// Configuration for help generation (Phase 4)
    help_config: HelpConfig,

    last_error: ?ErrorContext = null,
    const accessors = @import("parser_accessors.zig");
    pub const getFlag = accessors.getFlag;
    pub const getCount = accessors.getCount;
    pub const getOption = accessors.getOption;
    pub const getOptionValues = accessors.getOptionValues;
    pub const getRequiredOption = accessors.getRequiredOption;
    pub const getPositionals = accessors.getPositionals;
    pub const getPositional = accessors.getPositional;
    pub const getRequiredPositional = accessors.getRequiredPositional;
    pub const getIntPositional = accessors.getIntPositional;
    pub const getFloatPositional = accessors.getFloatPositional;
    pub const getOptionDefault = accessors.getOptionDefault;
    pub const getInt = accessors.getInt;
    pub const getFloat = accessors.getFloat;
    pub const get = accessors.get;

    pub fn init(allocator: std.mem.Allocator, args: []const Arg) !Parser {
        return initWithConfig(allocator, args, HelpConfig{});
    }

    pub fn initWithConfig(allocator: std.mem.Allocator, args: []const Arg, config: HelpConfig) !Parser {
        var short_map = std.AutoHashMap(u8, usize).init(allocator);
        errdefer short_map.deinit();

        var long_map = std.StringHashMap(usize).init(allocator);
        errdefer long_map.deinit();

        for (args, 0..) |arg, i| {
            if (arg.short) |s| {
                if (short_map.contains(s)) return Error.DuplicateArgument;
                try short_map.put(s, i);
            }
            for (arg.short_aliases) |alias| {
                if (short_map.contains(alias)) return Error.DuplicateArgument;
                try short_map.put(alias, i);
            }
            if (arg.long) |l| {
                if (long_map.contains(l)) return Error.DuplicateArgument;
                try long_map.put(l, i);
            }
            for (arg.aliases) |alias| {
                if (long_map.contains(alias)) return Error.DuplicateArgument;
                try long_map.put(alias, i);
            }
        }

        return .{
            .allocator = allocator,
            .args = args,
            .parsed = ParsedValues.init(allocator),
            .owned_args = null,
            .short_map = short_map,
            .long_map = long_map,
            .help_config = config,
            .last_error = null,
        };
    }

    pub fn initComptime(allocator: std.mem.Allocator, comptime args: []const Arg) !Parser {
        @import("validate.zig").validateArgsComptime(args);
        return init(allocator, args);
    }

    pub fn initOwned(allocator: std.mem.Allocator, args: []const Arg, config: HelpConfig) !Parser {
        var parser = try initWithConfig(allocator, args, config);
        parser.owned_args = args;
        return parser;
    }

    pub fn deinit(self: *Parser) void {
        self.parsed.deinit();
        self.short_map.deinit();
        self.long_map.deinit();
        if (self.owned_args) |owned| {
            self.allocator.free(owned);
        }
    }

    /// Check if a string starting with '-' is a negative number.
    fn isNegativeNumber(s: []const u8) bool {
        if (s.len < 2) return false;
        // Must start with '-'
        if (s[0] != '-') return false;
        // Next char must be a digit
        if (!std.ascii.isDigit(s[1])) return false;
        // Check rest of string is valid number format (digits, optional decimal point)
        var has_decimal = false;
        for (s[1..]) |c| {
            if (c == '.') {
                if (has_decimal) return false; // Multiple decimals
                has_decimal = true;
            } else if (!std.ascii.isDigit(c)) {
                return false;
            }
        }
        return true;
    }

    /// Parse command-line arguments.
    pub fn parse(self: *Parser, argv: []const []const u8) !void {
        self.last_error = null;
        self.parsed.reset();
        // Auto-detect --help or -h flag (Phase 4)
        for (argv) |arg_str| {
            if (std.mem.eql(u8, arg_str, "--help") or std.mem.eql(u8, arg_str, "-h")) {
                return Error.ShowHelp;
            }
        }

        // Skip program name (argv[0])
        var i: usize = 1;
        var stop_parsing: bool = false;
        while (i < argv.len) : (i += 1) {
            const arg_str = argv[i];

            // Check for argument terminator --
            if (std.mem.eql(u8, arg_str, "--")) {
                stop_parsing = true;
                continue;
            }

            // After --, treat everything as positional
            if (stop_parsing) {
                try self.parsed.positionals.append(self.allocator, arg_str);
                continue;
            }

            // Check for long option: --name or --name=value
            if (std.mem.startsWith(u8, arg_str, "--")) {
                try self.parseLong(arg_str, &i, argv);
            }
            // Check for short option: -f or -fvalue
            // But first check if it's a negative number (positional)
            else if (std.mem.startsWith(u8, arg_str, "-") and arg_str.len > 1 and !isNegativeNumber(arg_str)) {
                try self.parseShort(arg_str, &i, argv);
            }
            // Otherwise, it's a positional (including negative numbers like -123)
            else {
                try self.parsed.positionals.append(self.allocator, arg_str);
            }
        }

        // Validate required arguments
        for (self.args) |*arg| {
            if (!arg.required) continue;
            switch (arg.kind) {
                .flag => {
                    if (!self.parsed.getFlag(arg.name)) return self.fail(Error.MissingRequired, null, arg, null);
                },
                .count => {
                    if (self.parsed.getCount(arg.name) == 0) return self.fail(Error.MissingRequired, null, arg, null);
                },
                .option => {
                    const has_option = self.parsed.options.contains(arg.name) or self.parsed.multi_options.contains(arg.name);
                    if (!has_option and arg.default == null) {
                        return self.fail(Error.MissingRequired, null, arg, null);
                    }
                },
                .positional => {
                    if (arg.position) |pos| {
                        if (pos >= self.parsed.positionals.items.len) {
                            return self.fail(Error.MissingRequired, null, arg, null);
                        }
                    }
                },
            }
        }

        try self.validatePositionals();
    }

    fn recordFlag(self: *Parser, arg: *const Arg) !void {
        try self.parsed.flags.put(arg.name, true);
    }

    fn recordCount(self: *Parser, arg: *const Arg) !void {
        const entry = try self.parsed.counts.getOrPut(arg.name);
        if (!entry.found_existing) {
            entry.value_ptr.* = 0;
        }
        entry.value_ptr.* += 1;
    }

    fn recordOption(self: *Parser, arg: *const Arg, value: []const u8) !void {
        // Validate and convert value based on value_type
        const typed_value = ParsedValues.convertValue(value, arg.value_type) catch |err| {
            if (err == Error.InvalidValue) return self.fail(Error.InvalidValue, null, arg, value);
            return err;
        };
        try self.parsed.setTypedOption(arg.name, typed_value);

        // Run custom validator if provided
        if (arg.validator) |validator| {
            validator(value) catch |err| {
                if (err == Error.InvalidValue) return self.fail(Error.InvalidValue, null, arg, value);
                return err;
            };
        }
        if (arg.multiple) {
            var entry = try self.parsed.multi_options.getOrPut(arg.name);
            if (!entry.found_existing) {
                entry.value_ptr.* = std.ArrayList([]const u8){};
            }
            try entry.value_ptr.append(self.allocator, value);
            try self.parsed.options.put(arg.name, value);
        } else {
            if (self.parsed.options.contains(arg.name)) {
                return self.fail(Error.DuplicateArgument, null, arg, value);
            }
            try self.parsed.options.put(arg.name, value);
        }
    }

    fn validatePositionals(self: *Parser) !void {
        for (self.args) |arg| {
            if (arg.kind != .positional) continue;
            if (arg.validator) |validator| {
                if (arg.position) |pos| {
                    if (pos < self.parsed.positionals.items.len) {
                        try validator(self.parsed.positionals.items[pos]);
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

            const arg_idx = self.long_map.get(name) orelse return self.fail(Error.UnknownArgument, arg_str, null, null);
            const arg = &self.args[arg_idx];

            switch (arg.kind) {
                .flag => try self.recordFlag(arg),
                .count => try self.recordCount(arg),
                .option => try self.recordOption(arg, value),
                .positional => return self.fail(Error.UnknownArgument, arg_str, null, null),
            }
        } else {
            // --name value syntax
            const arg_idx = self.long_map.get(inner) orelse return self.fail(Error.UnknownArgument, arg_str, null, null);
            const arg = &self.args[arg_idx];

            switch (arg.kind) {
                .flag => try self.recordFlag(arg),
                .count => try self.recordCount(arg),
                .option => {
                    i.* += 1;
                    if (i.* >= argv.len) return self.fail(Error.MissingValue, arg_str, arg, null);
                    try self.recordOption(arg, argv[i.*]);
                },
                .positional => return self.fail(Error.UnknownArgument, arg_str, null, null),
            }
        }
    }

    fn parseShort(self: *Parser, arg_str: []const u8, i: *usize, argv: []const []const u8) !void {
        // Single short flag: -f
        if (arg_str.len == 2) {
            const short = arg_str[1];
            const arg_idx = self.short_map.get(short) orelse return self.fail(Error.UnknownArgument, arg_str, null, null);
            const arg = &self.args[arg_idx];

            switch (arg.kind) {
                .flag => try self.recordFlag(arg),
                .count => try self.recordCount(arg),
                .option => {
                    i.* += 1;
                    if (i.* >= argv.len) return self.fail(Error.MissingValue, arg_str, arg, null);
                    try self.recordOption(arg, argv[i.*]);
                },
                .positional => return self.fail(Error.UnknownArgument, arg_str, null, null),
            }
        }
        // -fvalue syntax (short option with attached value)
        else {
            const short = arg_str[1];
            const arg_idx = self.short_map.get(short) orelse return self.fail(Error.UnknownArgument, arg_str, null, null);
            const arg = &self.args[arg_idx];

            if (arg.kind == .option) {
                const value = arg_str[2..];
                try self.recordOption(arg, value);
            } else {
                // Multiple short flags combined: -vf
                for (arg_str[1..]) |c| {
                    const idx = self.short_map.get(c) orelse return self.fail(Error.UnknownArgument, arg_str, null, null);
                    const a = &self.args[idx];
                    switch (a.kind) {
                        .flag => try self.recordFlag(a),
                        .count => try self.recordCount(a),
                        else => return self.fail(Error.UnknownArgument, arg_str, null, null),
                    }
                }
            }
        }
    }

    fn fail(self: *Parser, err: Error, token: ?[]const u8, arg: ?*const Arg, value: ?[]const u8) Error {
        self.last_error = .{
            .kind = err,
            .token = token,
            .arg = arg,
            .value = value,
        };
        return err;
    }

    /// Generate and return help text (Phase 4).
    pub fn help(self: *const Parser) ![]const u8 {
        return generateHelp(self.allocator, self.args, self.help_config);
    }

    /// Format a helpful error message for the last parse error.
    pub fn formatError(self: *const Parser, allocator: std.mem.Allocator, err: Error, config: ErrorFormatConfig) ![]const u8 {
        var context = self.last_error orelse ErrorContext{ .kind = err };
        if (context.kind != err) {
            context.kind = err;
        }
        return formatErrorMessage(allocator, context, config);
    }

    /// Update help configuration (Phase 4).
    pub fn setHelpConfig(self: *Parser, config: HelpConfig) void {
        self.help_config = config;
    }
};
