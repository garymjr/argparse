const std = @import("std");
const Builder = @import("builder.zig").Builder;
const ArgOptions = @import("builder.zig").ArgOptions;
const ValueType = @import("arg.zig").ValueType;
const Error = @import("error.zig").Error;

test "builder builds parser" {
    var builder = Builder.init(std.testing.allocator);
    defer builder.deinit();

    _ = try builder.addFlag("verbose", 'v', "verbose", "Enable verbose output");
    _ = try builder.addOptionWith("count", 'c', "count", .int, "Number of items", .{ .required = true });
    _ = try builder.addPositional("input", .string, "Input file");

    var parser = try builder.build();
    defer parser.deinit();

    const argv = [_][]const u8{ "program", "-v", "--count", "5", "data.txt" };
    try parser.parse(&argv);

    try std.testing.expect(parser.getFlag("verbose"));
    try std.testing.expectEqual(@as(i64, 5), try parser.get("count", i64));
    try std.testing.expectEqualStrings("data.txt", parser.getPositional("input").?);
}

test "builder positional auto-order" {
    var builder = Builder.init(std.testing.allocator);
    defer builder.deinit();

    _ = try builder.addPositional("first", .string, "First");
    _ = try builder.addPositional("second", .string, "Second");

    var parser = try builder.build();
    defer parser.deinit();

    const argv = [_][]const u8{ "program", "one", "two" };
    try parser.parse(&argv);

    try std.testing.expectEqualStrings("one", parser.getPositional("first").?);
    try std.testing.expectEqualStrings("two", parser.getPositional("second").?);
}

test "builder surfaces missing required" {
    var builder = Builder.init(std.testing.allocator);
    defer builder.deinit();

    _ = try builder.addOptionWith("count", 'c', "count", .int, "Number of items", .{ .required = true });

    var parser = try builder.build();
    defer parser.deinit();

    const argv = [_][]const u8{"program"};
    try std.testing.expectError(Error.MissingRequired, parser.parse(&argv));
}
