//! Error types and error collection

const std = @import("std");
const ArgSpec = @import("types.zig").ArgSpec;

// Helper type alias to work around namespace collision
const ParseErrorType = ParseError;

/// Error kind with associated data
pub const ErrorKind = union(enum) {
    /// Unknown argument
    unknown,
    /// Missing required argument
    missing_required,
    /// Missing value for an option that requires one
    missing_value,
    /// Invalid value for the argument type
    invalid_value: []const u8,
    /// Conflict with another argument
    conflict: []const u8,
    /// Requires another argument
    requires: []const u8,
    /// Validation failed
    validation_failed: []const u8,
    /// Unknown verb/subcommand
    unknown_verb,
    /// Out of memory
    out_of_memory,
    /// Short options not supported
    unsupported_short,
    /// Invalid placement (e.g., -ab where 'a' requires an arg)
    invalid_placement,
};

/// An argument parsing error
pub const ParseError = struct {
    /// The option that yielded the error
    option: []const u8,
    /// The kind of error, may include additional information
    kind: ErrorKind,

    /// Format the error message
    pub fn format(self: ParseError, writer: anytype) !void {
        try writer.print("error: ", .{});

        switch (self.kind) {
            .unknown => try writer.print("unknown argument '{s}'", .{self.option}),
            .missing_required => try writer.print("missing required argument '--{s}'", .{self.option}),
            .missing_value => try writer.print("missing value for argument '--{s}'", .{self.option}),
            .invalid_value => |value| try writer.print("invalid value '{s}' for argument '--{s}'", .{ value, self.option }),
            .conflict => |other| try writer.print("'--{s}' conflicts with '--{s}'", .{ self.option, other }),
            .requires => |other| try writer.print("'--{s}' requires '--{s}'", .{ self.option, other }),
            .validation_failed => |msg| try writer.print("validation failed for '--{s}': {s}", .{ self.option, msg }),
            .unknown_verb => try writer.print("unknown verb '{s}'", .{self.option}),
            .out_of_memory => try writer.print("out of memory while processing argument '--{s}'", .{self.option}),
            .unsupported_short => try writer.print("unsupported short argument '-{s}'", .{self.option}),
            .invalid_placement => try writer.print("invalid placement for argument '-{s}'", .{self.option}),
        }
    }

    /// Get a suggestion for the error (e.g., similar option names)
    pub fn suggest(self: ParseError, comptime specs: []const ArgSpec) ?[]const u8 {
        if (self.kind != .unknown and self.kind != .unknown_verb) return null;

        const target = self.option;
        var best_match: ?[]const u8 = null;
        var best_distance: usize = 3; // Max edit distance to suggest

        inline for (specs) |spec| {
            if (spec.long) |long| {
                const dist = editDistance(target, long);
                if (dist < best_distance) {
                    best_distance = dist;
                    best_match = long;
                }
            }
        }

        return best_match;
    }

    /// Simple edit distance (Levenshtein) for suggestions
    fn editDistance(a: []const u8, b: []const u8) usize {
        const len_a = a.len;
        const len_b = b.len;

        if (len_a == 0) return len_b;
        if (len_b == 0) return len_a;

        var matrix: [100][100]usize = undefined; // Support up to 99 chars

        // Initialize first row and column
        for (0..len_a + 1) |i| matrix[i][0] = i;
        for (0..len_b + 1) |j| matrix[0][j] = j;

        // Fill matrix
        for (1..len_a + 1) |i| {
            for (1..len_b + 1) |j| {
                const cost = if (a[i - 1] == b[j - 1]) @as(usize, 0) else 1;
                matrix[i][j] = @min(
                    @min(matrix[i - 1][j] + 1, matrix[i][j - 1] + 1),
                    matrix[i - 1][j - 1] + cost,
                );
            }
        }

        return matrix[len_a][len_b];
    }
};

test "Error.format" {
    var buffer: [256]u8 = undefined;
    var fbs = std.io.fixedBufferStream(&buffer);

    const err = ParseError{
        .option = "output",
        .kind = .{ .missing_value = {} },
    };
    try err.format(fbs.writer());
    try std.testing.expectEqualStrings("error: missing value for argument '--output'", fbs.getWritten());

    fbs.reset();
    const err2 = ParseError{
        .option = "port",
        .kind = .{ .invalid_value = "abc" },
    };
    try err2.format(fbs.writer());
    try std.testing.expectEqualStrings("error: invalid value 'abc' for argument '--port'", fbs.getWritten());
}

test "Error.suggest" {
    const specs = &[_]ArgSpec{
        .{ .name = "output", .kind = .option, .long = "output" },
        .{ .name = "input", .kind = .option, .long = "input" },
        .{ .name = "verbose", .kind = .flag, .long = "verbose" },
    };

    const err = ParseError{
        .option = "ouput",
        .kind = .unknown,
    };

    const suggestion = err.suggest(specs);
    try std.testing.expect(suggestion != null);
    try std.testing.expectEqualStrings("output", suggestion.?);
}

/// A collection of parsing errors
pub const ErrorCollection = struct {
    const Self = @This();

    arena: std.heap.ArenaAllocator,
    list: std.ArrayList(ParseError),
    allocator: std.mem.Allocator,

    /// Initialize a new error collection
    pub fn init(allocator: std.mem.Allocator) Self {
        return Self{
            .arena = std.heap.ArenaAllocator.init(allocator),
            .list = std.ArrayList(ParseError).empty,
            .allocator = allocator,
        };
    }

    /// Deinitialize the error collection
    pub fn deinit(self: *Self) void {
        self.arena.deinit();
        self.list.deinit(self.allocator);
        self.* = undefined;
    }

    /// Add an error to the collection
    pub fn add(self: *Self, err: ParseError) !void {
        const arena_alloc = self.arena.allocator();

        const dupe_option = try arena_alloc.dupe(u8, err.option);
        const dupe_kind = try dupeErrorKind(arena_alloc, err.kind);

        try self.list.append(self.allocator, ParseError{
            .option = dupe_option,
            .kind = dupe_kind,
        });
    }

    /// Check if there are any errors
    pub fn hasErrors(self: Self) bool {
        return self.list.items.len > 0;
    }

    /// Get the number of errors
    pub fn count(self: Self) usize {
        return self.list.items.len;
    }

    /// Get all errors
    pub fn errors(self: Self) []const ParseError {
        return self.list.items;
    }

    /// Write all errors to a writer
    pub fn write(self: Self, writer: anytype) !void {
        for (self.list.items) |err| {
            try err.format(writer);
            try writer.writeByte('\n');
        }
    }

    /// Get the first error
    pub fn first(self: Self) ?ParseError {
        if (self.list.items.len == 0) return null;
        return self.list.items[0];
    }
};

/// Duplicate an ErrorKind with arena allocation
fn dupeErrorKind(allocator: std.mem.Allocator, kind: ErrorKind) !ErrorKind {
    return switch (kind) {
        .invalid_value => |v| .{ .invalid_value = try allocator.dupe(u8, v) },
        .conflict => |c| .{ .conflict = try allocator.dupe(u8, c) },
        .requires => |r| .{ .requires = try allocator.dupe(u8, r) },
        .validation_failed => |m| .{ .validation_failed = try allocator.dupe(u8, m) },
        else => kind, // Flat copy for variants without owned data
    };
}

test "ErrorCollection" {
    var collection = ErrorCollection.init(std.testing.allocator);
    defer collection.deinit();

    try collection.add(ParseError{
        .option = "output",
        .kind = .missing_required,
    });

    try std.testing.expectEqual(true, collection.hasErrors());
    try std.testing.expectEqual(@as(usize, 1), collection.count());
    try std.testing.expectEqualStrings("output", collection.first().?.option);
}

test "editDistance" {
    try std.testing.expectEqual(@as(usize, 0), ParseError.editDistance("hello", "hello"));
    try std.testing.expectEqual(@as(usize, 1), ParseError.editDistance("hello", "hallo"));
    try std.testing.expectEqual(@as(usize, 3), ParseError.editDistance("kitten", "sitting"));
    try std.testing.expectEqual(@as(usize, 1), ParseError.editDistance("output", "ouput")); // 't' moved, insert 'u'
}
