//! Core type definitions for argument parsing

const std = @import("std");

/// The kind of argument
pub const ArgKind = enum {
    /// Boolean flag, no value needed (e.g., --verbose, -v)
    flag,
    /// Takes a value (e.g., --file path.txt, -f path.txt)
    option,
    /// Positional argument
    positional,
    /// Multiple values allowed (e.g., --file a.txt b.txt c.txt)
    multiple,
    /// Counted occurrences (e.g., -vvv = count 3)
    count,
};

/// Specification for a single argument (internal)
pub const ArgSpec = struct {
    /// Field name in the config struct
    name: []const u8,
    /// Argument kind
    kind: ArgKind,
    /// Whether the argument is required
    required: bool = false,
    /// Help text
    help: ?[]const u8 = null,
    /// Short flag character (without -)
    short: ?u8 = null,
    /// Long flag name (without --)
    long: ?[]const u8 = null,
    /// Environment variable name
    env: ?[]const u8 = null,
    /// Minimum value (for numbers/arrays)
    min: ?usize = null,
    /// Maximum value (for numbers/arrays)
    max: ?usize = null,
    /// Whether to hide from help
    hidden: bool = false,
};

/// Metadata for the argument parser
pub const Meta = struct {
    /// Program name
    name: []const u8 = "program",
    /// Program version
    version: []const u8 = "0.0.0",
    /// Short description (about)
    about: ?[]const u8 = null,
    /// Author information
    author: ?[]const u8 = null,
    /// Usage summary (appended to "Usage: <name>")
    usage_summary: ?[]const u8 = null,
    /// Long description
    long_about: ?[]const u8 = null,
    /// Examples
    examples: ?[]const Example = null,
    /// Help text wrap width
    wrap_width: usize = 80,
    /// Whether to enable colors in output
    color: bool = true,
};

/// Example usage
pub const Example = struct {
    description: []const u8,
    command: []const u8,
};

/// Build ParseResult type
pub fn ParseResult(comptime Spec: type, comptime Verb: ?type) type {
    if (@typeInfo(Spec) != .@"struct") {
        @compileError("Spec must be a struct type");
    }

    if (Verb) |V| {
        const ti = @typeInfo(V);
        if (ti != .@"union" or ti.@"union".tag_type == null) {
            @compileError("Verb must be a tagged union");
        }
    }

    return struct {
        const Self = @This();

        /// Arena allocator for all parsed strings
        arena: std.heap.ArenaAllocator,
        /// The options with parsed values
        options: Spec,
        /// The verb that was selected (if using verbs)
        verb: if (Verb) |V| ?V else void,
        /// Positional arguments
        positionals: [][:0]const u8,
        /// Raw arguments (after --)
        raw_args: ?[][]const u8,
        /// Index of first raw argument
        raw_start_index: ?usize = null,
        /// Executable name (argv[0])
        executable: ?[:0]const u8,

        /// Clean up resources
        pub fn deinit(self: Self) void {
            self.arena.child_allocator.free(self.positionals);
            if (self.raw_args) |raw| {
                self.arena.child_allocator.free(raw);
            }
            if (self.executable) |exe| {
                self.arena.child_allocator.free(exe);
            }
            self.arena.deinit();
        }
    };
}

/// Check if a field name is reserved (not an argument)
pub fn isReserved(name: []const u8) bool {
    return std.mem.eql(u8, name, "meta") or
        std.mem.eql(u8, name, "shorthands") or
        std.mem.eql(u8, name, "validators") or
        std.mem.eql(u8, name, "groups") or
        std.mem.eql(u8, name, "wrap_len");
}

test "ArgKind" {
    const flag: ArgKind = .flag;
    const option: ArgKind = .option;
    try std.testing.expect(flag == .flag);
    try std.testing.expect(option == .option);
}

test "isReserved" {
    try std.testing.expect(isReserved("meta"));
    try std.testing.expect(isReserved("shorthands"));
    try std.testing.expect(isReserved("validators"));
    try std.testing.expect(!isReserved("output"));
    try std.testing.expect(!isReserved("verbose"));
}
