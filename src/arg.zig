//! Argument definition and type handling.

pub const ArgKind = enum {
    /// Boolean flag: --verbose, -v
    flag,
    /// Option with value: --file <path>, -f <path>
    option,
    /// Positional argument: <file>
    positional,
};

/// Represents a command-line argument definition.
pub const Arg = struct {
    /// Internal name for lookup (used by get*)
    name: []const u8,

    /// Short form: single character like 'v' for -v
    short: ?u8 = null,

    /// Long form: multi-character like "verbose" for --verbose
    long: ?[]const u8 = null,

    /// Help text describing the argument
    help: []const u8 = "",

    /// Kind of argument (flag, option, positional)
    kind: ArgKind,

    /// Value type for type-safe parsing (Phase 2)
    value_type: ValueType = .string,

    /// Default value (Phase 2)
    default: ?Value = null,

    /// Whether this argument is required
    required: bool = false,
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
