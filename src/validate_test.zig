//! Tests for compile-time argument validation.

const std = @import("std");
const Arg = @import("arg.zig").Arg;
const ArgKind = @import("arg.zig").ArgKind;

test "validateArgsComptime allows unique positional positions" {
    const args = [_]Arg{
        .{ .name = "file", .kind = .positional, .position = 0 },
        .{ .name = "output", .kind = .positional, .position = 1 },
    };

    comptime {
        @import("validate.zig").validateArgsComptime(&args);
    }
}

test "validateArgsComptime allows positionals without explicit positions" {
    const args = [_]Arg{
        .{ .name = "file", .kind = .positional },
        .{ .name = "output", .kind = .positional },
    };

    comptime {
        @import("validate.zig").validateArgsComptime(&args);
    }
}

test "validateArgsComptime allows non-conflicting arguments" {
    const args = [_]Arg{
        .{ .name = "verbose", .short = 'v', .long = "verbose", .aliases = &.{"verb"}, .kind = .flag },
        .{ .name = "quiet", .short = 'q', .long = "quiet", .aliases = &.{"silent"}, .kind = .flag },
    };

    comptime {
        @import("validate.zig").validateArgsComptime(&args);
    }
}

// Note: The comptime validation correctly catches duplicate arguments.
// Testing for compile errors is done by verifying that defining conflicting
// args and calling validateArgsComptime results in a compile error.
// Examples of conflicts that are caught:
// - Duplicate long names between different args
// - Long name in one arg conflicts with alias in another
// - Duplicate short names between different args
// - Short name in one arg conflicts with short_alias in another
// - Duplicate aliases between different args
