//! Argument definition and type handling.

pub const ArgKind = enum {
    /// Boolean flag: --verbose, -v
    flag,
    /// Option with value: --file <path>, -f <path>
    option,
    /// Positional argument: <file>
    positional,
    /// Counted flag: -vvv (count occurrences)
    count,
};

/// Represents a command-line argument definition.
pub const Arg = struct {
    /// Internal name for lookup (used by get*)
    name: []const u8,

    /// Short form: single character like 'v' for -v
    short: ?u8 = null,

    /// Additional short aliases
    short_aliases: []const u8 = &.{},

    /// Long form: multi-character like "verbose" for --verbose
    long: ?[]const u8 = null,

    /// Additional long aliases
    aliases: []const []const u8 = &.{},

    /// Help text describing the argument
    help: []const u8 = "",

    /// Kind of argument (flag, option, positional, count)
    kind: ArgKind,

    /// Value type for type-safe parsing (Phase 2)
    value_type: ValueType = .string,

    /// Allow multiple values for this option (Phase 5)
    multiple: bool = false,

    /// Default value (Phase 2)
    default: ?Value = null,

    /// Whether this argument is required
    required: bool = false,

    /// Custom value validator (Phase 5)
    validator: ?*const fn ([]const u8) anyerror!void = null,

    /// Position for positional arguments (Phase 3)
    /// Defines the order of positionals (0-indexed)
    position: ?usize = null,
};

/// Value type for type-safe parsing (Phase 2)
pub const ValueType = enum {
    bool,
    string,
    int,
    float,
};

/// Union value storage (Phase 2)
pub const Value = union(ValueType) {
    bool: bool,
    string: []const u8,
    int: i64,
    float: f64,
};
