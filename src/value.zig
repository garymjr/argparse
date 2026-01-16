//! Value parsing and type conversion

const std = @import("std");
const types = @import("types.zig");

/// Parse an integer with optional suffixes
/// Supports: 10, 1k, 1M, 1G (1000-based)
///          1Ki, 1Mi, 1Gi (1024-based)
pub fn parseInt(comptime T: type, str: []const u8) !T {
    var buf = str;
    var multiplier: T = 1;

    // Handle suffixes
    if (buf.len > 0) {
        var base1024 = false;

        // Check for 'i' suffix (Ki, Mi, Gi vs K, M, G)
        if (std.ascii.toLower(buf[buf.len - 1]) == 'i') {
            buf.len -= 1;
            base1024 = true;
        }

        // Check for multiplier suffix
        if (buf.len > 0) {
            const pow: u3 = switch (buf[buf.len - 1]) {
                'k', 'K' => 1,
                'm', 'M' => 2,
                'g', 'G' => 3,
                't', 'T' => 4,
                'p', 'P' => 5,
                else => 0,
            };

            if (pow != 0) {
                buf.len -= 1;

                if (comptime std.math.maxInt(T) < 1024) {
                    return error.Overflow;
                }

                const base: T = if (base1024) 1024 else 1000;
                multiplier = try std.math.powi(T, base, @as(T, @intCast(pow)));
            }
        }
    }

    const ret: T = switch (@typeInfo(T).int.signedness) {
        .signed => try std.fmt.parseInt(T, buf, 0),
        .unsigned => try std.fmt.parseUnsigned(T, buf, 0),
    };

    return try std.math.mul(T, ret, multiplier);
}

test "parseInt" {
    try std.testing.expectEqual(@as(i32, 50), try parseInt(i32, "50"));
    try std.testing.expectEqual(@as(i32, 6000), try parseInt(i32, "6k"));
    try std.testing.expectEqual(@as(u32, 2048), try parseInt(u32, "2Ki"));
    try std.testing.expectEqual(@as(i8, 0), try parseInt(i8, "0"));
    try std.testing.expectEqual(@as(usize, 16), try parseInt(usize, "0x10"));
    try std.testing.expectError(error.Overflow, parseInt(i2, "1m"));
    try std.testing.expectError(error.Overflow, parseInt(u16, "1Ti"));
}

/// Parse a floating point number
pub fn parseFloat(comptime T: type, str: []const u8) !T {
    return std.fmt.parseFloat(T, str);
}

test "parseFloat" {
    try std.testing.expectEqual(@as(f32, 3.14), try parseFloat(f32, "3.14"));
    try std.testing.expectEqual(@as(f64, -0.5), try parseFloat(f64, "-0.5"));
}

/// Parse a boolean value
/// Accepts: true, false, yes, no, t, f, y, n, 1, 0 (case insensitive)
pub fn parseBool(str: []const u8) !bool {
    return switch (str.len) {
        1 => switch (str[0]) {
            'y', 'Y', 't', 'T', '1' => true,
            'n', 'N', 'f', 'F', '0' => false,
            else => error.NotABooleanValue,
        },
        2 => if (std.ascii.eqlIgnoreCase("no", str)) false else error.NotABooleanValue,
        3 => if (std.ascii.eqlIgnoreCase("yes", str)) true else error.NotABooleanValue,
        4 => if (std.ascii.eqlIgnoreCase("true", str)) true else error.NotABooleanValue,
        5 => if (std.ascii.eqlIgnoreCase("false", str)) false else error.NotABooleanValue,
        else => error.NotABooleanValue,
    };
}

test "parseBool" {
    try std.testing.expectEqual(true, try parseBool("true"));
    try std.testing.expectEqual(false, try parseBool("false"));
    try std.testing.expectEqual(true, try parseBool("yes"));
    try std.testing.expectEqual(false, try parseBool("no"));
    try std.testing.expectEqual(true, try parseBool("t"));
    try std.testing.expectEqual(false, try parseBool("f"));
    try std.testing.expectEqual(true, try parseBool("Y"));
    try std.testing.expectEqual(false, try parseBool("N"));
    try std.testing.expectEqual(true, try parseBool("1"));
    try std.testing.expectEqual(false, try parseBool("0"));
    try std.testing.expectEqual(true, try parseBool("TRUE"));
    try std.testing.expectError(error.NotABooleanValue, parseBool("maybe"));
}

/// Parse an enum from a string
/// Uses `std.meta.stringToEnum` or custom `parse()` method if available
pub fn parseEnum(comptime T: type, str: []const u8) !T {
    if (@hasDecl(T, "parse")) {
        return try T.parse(str);
    }
    return std.meta.stringToEnum(T, str) orelse error.InvalidEnumeration;
}

test "parseEnum" {
    const TestEnum = enum { default, special, fast, slow };
    try std.testing.expectEqual(TestEnum.default, try parseEnum(TestEnum, "default"));
    try std.testing.expectEqual(TestEnum.special, try parseEnum(TestEnum, "special"));
    try std.testing.expectError(error.InvalidEnumeration, parseEnum(TestEnum, "unknown"));
}

/// Check if a type requires an argument
pub fn requiresArg(comptime T: type) bool {
    const H = struct {
        fn doesTypeRequireArg(comptime Type: type) bool {
            return switch (@typeInfo(Type)) {
                .bool => false,
                .int, .float, .@"enum" => true,
                .pointer => |ptr| ptr.size == .slice and ptr.child == u8,
                .optional => |opt| doesTypeRequireArg(opt.child),
                .@"struct", .@"union" => true,
                else => false,
            };
        }
    };

    return H.doesTypeRequireArg(T);
}

test "requiresArg" {
    try std.testing.expect(requiresArg(i32));
    try std.testing.expect(requiresArg(f64));
    try std.testing.expect(requiresArg([]const u8));
    try std.testing.expect(requiresArg(?[]const u8));
    try std.testing.expect(!requiresArg(bool));
    try std.testing.expect(!requiresArg(?bool));
}

/// Generic value conversion
/// Dispatches to appropriate parser based on type
pub fn convertValue(comptime T: type, allocator: std.mem.Allocator, str: []const u8) !T {
    switch (@typeInfo(T)) {
        .optional => |opt| {
            const value = try convertValue(opt.child, allocator, str);
            return value;
        },
        .bool => {
            if (str.len == 0) return true; // Empty string = true for flags
            return try parseBool(str);
        },
        .int => return try parseInt(T, str),
        .float => return try parseFloat(T, str),
        .@"enum" => return try parseEnum(T, str),
        .pointer => |ptr| {
            if (ptr.size == .slice and ptr.child == u8) {
                // Check for sentinel (e.g., [:0]const u8)
                if (comptime std.meta.sentinel(T)) |sentinel| {
                    const data = try allocator.alloc(u8, str.len + 1);
                    @memcpy(data[0..str.len], str);
                    data[str.len] = sentinel;
                    return data[0..str.len :sentinel];
                }
                // Regular []const u8
                return str;
            }
            @compileError("Only slices of u8 are supported for pointer types");
        },
        .@"struct", .@"union" => {
            if (@hasDecl(T, "parse")) {
                return try T.parse(str);
            }
            @compileError("Type " ++ @typeName(T) ++ " must have a `parse([]const u8) !T` method");
        },
        else => @compileError("Type " ++ @typeName(T) ++ " is not supported"),
    }
}

test "convertValue" {
    const allocator = std.testing.allocator;

    // Basic types
    try std.testing.expectEqual(@as(i32, 42), try convertValue(i32, allocator, "42"));
    try std.testing.expectEqual(@as(f64, 3.14), try convertValue(f64, allocator, "3.14"));
    try std.testing.expectEqual(true, try convertValue(bool, allocator, "true"));
    try std.testing.expectEqual(true, try convertValue(bool, allocator, "")); // Empty = true (flag present without value)

    // Optional types
    try std.testing.expectEqual(@as(?i32, 42), try convertValue(?i32, allocator, "42"));

    // Strings
    try std.testing.expectEqualStrings("hello", try convertValue([]const u8, allocator, "hello"));

    // Enums
    const TestEnum = enum { a, b, c };
    try std.testing.expectEqual(TestEnum.b, try convertValue(TestEnum, allocator, "b"));

    // Integers with suffixes
    try std.testing.expectEqual(@as(i32, 6000), try convertValue(i32, allocator, "6k"));
}
