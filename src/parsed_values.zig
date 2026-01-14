//! Parsed argument values storage.

const std = @import("std");
const Error = @import("error.zig").Error;
const Value = @import("arg.zig").Value;
const ValueType = @import("arg.zig").ValueType;

/// Container for parsed argument values.
pub const ParsedValues = struct {
    allocator: std.mem.Allocator,
    flags: std.StringHashMap(bool),
    counts: std.StringHashMap(usize),
    options: std.StringHashMap([]const u8),
    multi_options: std.StringHashMap(std.ArrayList([]const u8)),
    positionals: std.ArrayList([]const u8),
    // Typed storage for validated values (validated at parse time)
    typed_options: std.StringHashMap(Value),

    pub fn init(allocator: std.mem.Allocator) ParsedValues {
        return .{
            .allocator = allocator,
            .flags = std.StringHashMap(bool).init(allocator),
            .counts = std.StringHashMap(usize).init(allocator),
            .options = std.StringHashMap([]const u8).init(allocator),
            .multi_options = std.StringHashMap(std.ArrayList([]const u8)).init(allocator),
            .positionals = std.ArrayList([]const u8){},
            .typed_options = std.StringHashMap(Value).init(allocator),
        };
    }

    pub fn deinit(self: *ParsedValues) void {
        self.flags.deinit();
        self.counts.deinit();
        var iterator = self.multi_options.iterator();
        while (iterator.next()) |entry| {
            entry.value_ptr.deinit(self.allocator);
        }
        self.multi_options.deinit();
        self.options.deinit();
        self.positionals.deinit(self.allocator);
        self.typed_options.deinit();
    }

    pub fn reset(self: *ParsedValues) void {
        self.flags.clearRetainingCapacity();
        self.counts.clearRetainingCapacity();
        var iterator = self.multi_options.iterator();
        while (iterator.next()) |entry| {
            entry.value_ptr.deinit(self.allocator);
        }
        self.multi_options.clearRetainingCapacity();
        self.options.clearRetainingCapacity();
        self.positionals.clearRetainingCapacity();
        self.typed_options.clearRetainingCapacity();
    }

    /// Check if a flag was set.
    pub fn getFlag(self: *const ParsedValues, name: []const u8) bool {
        return self.flags.get(name) orelse false;
    }

    /// Get the count for a counted flag.
    pub fn getCount(self: *const ParsedValues, name: []const u8) usize {
        return self.counts.get(name) orelse 0;
    }

    /// Get an option value, returns null if not set.
    pub fn getOption(self: *const ParsedValues, name: []const u8) ?[]const u8 {
        return self.options.get(name);
    }

    /// Get all values for a multi-value option.
    pub fn getOptionValues(self: *const ParsedValues, name: []const u8) ?[]const []const u8 {
        if (self.multi_options.get(name)) |list| {
            return list.items;
        }
        return null;
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

    /// Convert and validate a string value to a typed Value based on value_type.
    /// Called during parsing to validate values immediately.
    pub fn convertValue(str: []const u8, value_type: ValueType) !Value {
        return switch (value_type) {
            .string => Value{ .string = str },
            .int => {
                const val = std.fmt.parseInt(i64, str, 10) catch return Error.InvalidValue;
                return Value{ .int = val };
            },
            .float => {
                const val = std.fmt.parseFloat(f64, str) catch return Error.InvalidValue;
                return Value{ .float = val };
            },
            .bool => {
                if (std.mem.eql(u8, str, "true") or std.mem.eql(u8, str, "1") or std.mem.eql(u8, str, "yes") or std.mem.eql(u8, str, "on")) {
                    return Value{ .bool = true };
                }
                if (std.mem.eql(u8, str, "false") or std.mem.eql(u8, str, "0") or std.mem.eql(u8, str, "no") or std.mem.eql(u8, str, "off")) {
                    return Value{ .bool = false };
                }
                return Error.InvalidValue;
            },
        };
    }

    /// Store a typed value for an option (validated at parse time).
    pub fn setTypedOption(self: *ParsedValues, name: []const u8, value: Value) !void {
        try self.typed_options.put(name, value);
    }

    /// Get a typed value for an option.
    pub fn getTypedOption(self: *const ParsedValues, name: []const u8) ?Value {
        return self.typed_options.get(name);
    }
};
