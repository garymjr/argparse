//! Comptime utilities for argument parsing

const std = @import("std");
const types = @import("../types.zig");

/// Infer the argument kind from a type
pub fn inferArgKind(comptime T: type) types.ArgKind {
    return switch (@typeInfo(T)) {
        .bool => .flag,
        .optional => |opt| inferArgKind(opt.child),
        .pointer => |ptr| {
            if (ptr.size == .Slice and ptr.child == u8) {
                return .option;
            }
            @compileError("Unsupported pointer type: " ++ @typeName(T));
        },
        .array => .multiple,
        .int, .float, .@"enum" => .option,
        else => @compileError("Unsupported type for argument: " ++ @typeName(T)),
    };
}

test "inferArgKind" {
    try std.testing.expectEqual(types.ArgKind.flag, inferArgKind(bool));
    try std.testing.expectEqual(types.ArgKind.flag, inferArgKind(?bool));
    try std.testing.expectEqual(types.ArgKind.option, inferArgKind([]const u8));
    try std.testing.expectEqual(types.ArgKind.option, inferArgKind(?[]const u8));
    try std.testing.expectEqual(types.ArgKind.option, inferArgKind(i32));
    try std.testing.expectEqual(types.ArgKind.option, inferArgKind(f64));
    try std.testing.expectEqual(types.ArgKind.option, inferArgKind(enum { a, b }));
}

/// Get the default value for a type
pub fn getDefaultValue(comptime T: type) ?const anytype {
    return switch (@typeInfo(T)) {
        .optional => null,
        .bool => false,
        .pointer => null,
        else => null,
    };
}

/// Get the help text for a field from the meta struct
pub fn getHelpText(comptime Spec: type, comptime field_name: []const u8) ?[]const u8 {
    if (!@hasDecl(Spec, "meta")) return null;

    const MetaType = @TypeOf(Spec.meta);
    if (!@hasField(MetaType, "option_docs")) return null;

    const docs = Spec.meta.option_docs;
    const DocsType = @TypeOf(docs);

    // Check if field_name exists in option_docs
    inline for (std.meta.fields(DocsType)) |field| {
        if (std.mem.eql(u8, field.name, field_name)) {
            return @field(docs, field.name);
        }
    }

    return null;
}

test "getHelpText" {
    const Spec = struct {
        output: ?[:0]const u8 = null,

        pub const meta = .{
            .option_docs = .{
                .output = "Output file path",
            },
        };
    };

    try std.testing.expectEqualStrings("output", getHelpText(Spec, "output").?);
    try std.testing.expect(getHelpText(Spec, "input") == null);
}

/// Get the short flag for a field from the shorthands struct
pub fn getShortHand(comptime Spec: type, comptime field_name: []const u8) ?u8 {
    if (!@hasDecl(Spec, "shorthands")) return null;

    const ShorthandsType = @TypeOf(Spec.shorthands);

    inline for (std.meta.fields(ShorthandsType)) |field| {
        if (field.name.len != 1) {
            @compileError("All shorthand field names must be exactly one character");
        }

        const shorthand_name = @field(Spec.shorthands, field.name);
        if (std.mem.eql(u8, shorthand_name, field_name)) {
            return field.name[0];
        }
    }

    return null;
}

test "getShortHand" {
    const Spec = struct {
        output: ?[:0]const u8 = null,
        verbose: bool = false,

        pub const shorthands = .{
            .o = "output",
            .v = "verbose",
        };
    };

    try std.testing.expectEqual(@as(u8, 'o'), getShortHand(Spec, "output").?);
    try std.testing.expectEqual(@as(u8, 'v'), getShortHand(Spec, "verbose").?);
    try std.testing.expect(getShortHand(Spec, "input") == null);
}

/// Check if a field should be hidden from help
pub fn isHidden(comptime Spec: type, comptime field_name: []const u8) bool {
    // Hidden if field name starts with underscore
    if (field_name.len > 0 and field_name[0] == '_') return true;

    // Check meta.hidden_fields if it exists
    if (!@hasDecl(Spec, "meta")) return false;

    const MetaType = @TypeOf(Spec.meta);
    if (!@hasField(MetaType, "hidden_fields")) return false;

    const hidden = Spec.meta.hidden_fields;
    const HiddenType = @TypeOf(hidden);

    inline for (std.meta.fields(HiddenType)) |field| {
        if (std.mem.eql(u8, field.name, field_name)) {
            return @field(hidden, field.name);
        }
    }

    return false;
}

/// Build ArgSpec array from a struct type (comptime)
pub fn buildArgSpecs(comptime T: type) []const types.ArgSpec {
    comptime {
        var specs: []const types.ArgSpec = &.{};

        for (std.meta.fields(T)) |field| {
            if (types.isReserved(field.name)) continue;

            const spec = types.ArgSpec{
                .name = field.name,
                .kind = inferArgKind(field.type),
                .help = getHelpText(T, field.name),
                .short = getShortHand(T, field.name),
                .long = field.name,
                .hidden = isHidden(T, field.name),
            };

            specs = specs ++ .{spec};
        }

        return specs;
    }
}

test "buildArgSpecs" {
    const Spec = struct {
        output: ?[:0]const u8 = null,
        verbose: bool = false,
        count: usize = 0,

        pub const shorthands = .{
            .o = "output",
            .v = "verbose",
        };

        pub const meta = .{
            .option_docs = .{
                .output = "Output file path",
                .verbose = "Enable verbose output",
                .count = "Number of iterations",
            },
        };
    };

    const specs = buildArgSpecs(Spec);

    try std.testing.expectEqual(@as(usize, 3), specs.len);
    try std.testing.expectEqualStrings("output", specs[0].name);
    try std.testing.expectEqual(types.ArgKind.option, specs[0].kind);
    try std.testing.expectEqual(@as(?u8, 'o'), specs[0].short);
    try std.testing.expectEqualStrings("Output file path", specs[0].help);

    try std.testing.expectEqualStrings("verbose", specs[1].name);
    try std.testing.expectEqual(types.ArgKind.flag, specs[1].kind);
    try std.testing.expectEqual(@as(?u8, 'v'), specs[1].short);
}

/// Find a spec by long name
pub fn findSpecByLong(specs: []const types.ArgSpec, name: []const u8) ?*const types.ArgSpec {
    for (specs) |*spec| {
        if (spec.long) |long| {
            if (std.mem.eql(u8, long, name)) return spec;
        }
    }
    return null;
}

test "findSpecByLong" {
    const specs = &[_]types.ArgSpec{
        .{ .name = "output", .kind = .option, .long = "output" },
        .{ .name = "input", .kind = .option, .long = "input" },
    };

    const found = findSpecByLong(specs, "output");
    try std.testing.expect(found != null);
    try std.testing.expectEqualStrings("output", found.?.name);

    const not_found = findSpecByLong(specs, "unknown");
    try std.testing.expect(not_found == null);
}

/// Find a spec by short flag
pub fn findSpecByShort(specs: []const types.ArgSpec, short: u8) ?*const types.ArgSpec {
    for (specs) |*spec| {
        if (spec.short) |s| {
            if (s == short) return spec;
        }
    }
    return null;
}

test "findSpecByShort" {
    const specs = &[_]types.ArgSpec{
        .{ .name = "output", .kind = .option, .short = 'o', .long = "output" },
        .{ .name = "verbose", .kind = .flag, .short = 'v', .long = "verbose" },
    };

    const found = findSpecByShort(specs, 'o');
    try std.testing.expect(found != null);
    try std.testing.expectEqualStrings("output", found.?.name);

    const not_found = findSpecByShort(specs, 'x');
    try std.testing.expect(not_found == null);
}

/// Format a usage string
pub fn formatUsage(comptime Spec: type, meta: types.Meta, writer: anytype) !void {
    try writer.writeAll("Usage: ");
    try writer.writeAll(meta.name);

    if (meta.usage_summary) |summary| {
        try writer.print(" {s}", .{summary});
    } else {
        try writer.writeAll(" [OPTIONS]");
    }

    try writer.writeByte('\n');
}
