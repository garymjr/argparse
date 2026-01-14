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
