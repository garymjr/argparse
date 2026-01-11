const std = @import("std");
const Arg = @import("arg.zig").Arg;
const Parser = @import("parser.zig").Parser;
const Error = @import("error.zig").Error;
const ErrorFormatConfig = @import("error.zig").ErrorFormatConfig;
const HelpConfig = @import("help.zig").HelpConfig;

fn validateEven(value: []const u8) anyerror!void {
    const number = std.fmt.parseInt(i64, value, 10) catch return Error.InvalidValue;
    if (@rem(number, 2) != 0) return Error.InvalidValue;
}

test "parse single flag long" {
    const args = [_]Arg{
        .{ .name = "verbose", .long = "verbose", .kind = .flag },
    };

    const argv = [_][]const u8{ "program", "--verbose" };

    var parser = try Parser.init(std.testing.allocator, &args);
    defer parser.deinit();

    try parser.parse(&argv);

    try std.testing.expect(parser.getFlag("verbose"));
}

test "parse single flag short" {
    const args = [_]Arg{
        .{ .name = "verbose", .short = 'v', .kind = .flag },
    };

    const argv = [_][]const u8{ "program", "-v" };

    var parser = try Parser.init(std.testing.allocator, &args);
    defer parser.deinit();

    try parser.parse(&argv);

    try std.testing.expect(parser.getFlag("verbose"));
}

test "parse option long with space" {
    const args = [_]Arg{
        .{ .name = "file", .long = "file", .kind = .option },
    };

    const argv = [_][]const u8{ "program", "--file", "test.txt" };

    var parser = try Parser.init(std.testing.allocator, &args);
    defer parser.deinit();

    try parser.parse(&argv);

    try std.testing.expectEqualStrings("test.txt", parser.getOption("file").?);
}

test "parse option long with equals" {
    const args = [_]Arg{
        .{ .name = "file", .long = "file", .kind = .option },
    };

    const argv = [_][]const u8{ "program", "--file=test.txt" };

    var parser = try Parser.init(std.testing.allocator, &args);
    defer parser.deinit();

    try parser.parse(&argv);

    try std.testing.expectEqualStrings("test.txt", parser.getOption("file").?);
}

test "parse option short with space" {
    const args = [_]Arg{
        .{ .name = "file", .short = 'f', .kind = .option },
    };

    const argv = [_][]const u8{ "program", "-f", "test.txt" };

    var parser = try Parser.init(std.testing.allocator, &args);
    defer parser.deinit();

    try parser.parse(&argv);

    try std.testing.expectEqualStrings("test.txt", parser.getOption("file").?);
}

test "parse option short attached" {
    const args = [_]Arg{
        .{ .name = "file", .short = 'f', .kind = .option },
    };

    const argv = [_][]const u8{ "program", "-ftest.txt" };

    var parser = try Parser.init(std.testing.allocator, &args);
    defer parser.deinit();

    try parser.parse(&argv);

    try std.testing.expectEqualStrings("test.txt", parser.getOption("file").?);
}

test "parse multiple combined short flags" {
    const args = [_]Arg{
        .{ .name = "verbose", .short = 'v', .kind = .flag },
        .{ .name = "quiet", .short = 'q', .kind = .flag },
        .{ .name = "force", .short = 'f', .kind = .flag },
    };

    const argv = [_][]const u8{ "program", "-vqf" };

    var parser = try Parser.init(std.testing.allocator, &args);
    defer parser.deinit();

    try parser.parse(&argv);

    try std.testing.expect(parser.getFlag("verbose"));
    try std.testing.expect(parser.getFlag("quiet"));
    try std.testing.expect(parser.getFlag("force"));
}

test "parse mixed flags and options" {
    const args = [_]Arg{
        .{ .name = "verbose", .short = 'v', .long = "verbose", .kind = .flag },
        .{ .name = "file", .short = 'f', .long = "file", .kind = .option },
        .{ .name = "output", .short = 'o', .long = "output", .kind = .option },
    };

    const argv = [_][]const u8{ "program", "-v", "--file", "input.txt", "-o", "out.txt" };

    var parser = try Parser.init(std.testing.allocator, &args);
    defer parser.deinit();

    try parser.parse(&argv);

    try std.testing.expect(parser.getFlag("verbose"));
    try std.testing.expectEqualStrings("input.txt", parser.getOption("file").?);
    try std.testing.expectEqualStrings("out.txt", parser.getOption("output").?);
}

test "parse positional arguments" {
    const args = [_]Arg{
        .{ .name = "verbose", .short = 'v', .kind = .flag },
    };

    const argv = [_][]const u8{ "program", "file1.txt", "file2.txt", "-v" };

    var parser = try Parser.init(std.testing.allocator, &args);
    defer parser.deinit();

    try parser.parse(&argv);

    const positionals = parser.getPositionals();
    try std.testing.expectEqual(@as(usize, 2), positionals.len);
    try std.testing.expectEqualStrings("file1.txt", positionals[0]);
    try std.testing.expectEqualStrings("file2.txt", positionals[1]);
    try std.testing.expect(parser.getFlag("verbose"));
}

test "error unknown long argument" {
    const args = [_]Arg{
        .{ .name = "verbose", .long = "verbose", .kind = .flag },
    };

    const argv = [_][]const u8{ "program", "--unknown" };

    var parser = try Parser.init(std.testing.allocator, &args);
    defer parser.deinit();

    try std.testing.expectError(Error.UnknownArgument, parser.parse(&argv));
}

test "error unknown short argument" {
    const args = [_]Arg{
        .{ .name = "verbose", .short = 'v', .kind = .flag },
    };

    const argv = [_][]const u8{ "program", "-x" };

    var parser = try Parser.init(std.testing.allocator, &args);
    defer parser.deinit();

    try std.testing.expectError(Error.UnknownArgument, parser.parse(&argv));
}

test "error missing option value" {
    const args = [_]Arg{
        .{ .name = "file", .long = "file", .kind = .option },
    };

    const argv = [_][]const u8{ "program", "--file" };

    var parser = try Parser.init(std.testing.allocator, &args);
    defer parser.deinit();

    try std.testing.expectError(Error.MissingValue, parser.parse(&argv));
}

test "error missing required option" {
    const args = [_]Arg{
        .{ .name = "file", .long = "file", .kind = .option, .required = true },
    };

    const argv = [_][]const u8{ "program" };

    var parser = try Parser.init(std.testing.allocator, &args);
    defer parser.deinit();

    try std.testing.expectError(Error.MissingRequired, parser.parse(&argv));
}

test "no arguments" {
    const args = [_]Arg{
        .{ .name = "verbose", .short = 'v', .kind = .flag },
    };

    const argv = [_][]const u8{ "program" };

    var parser = try Parser.init(std.testing.allocator, &args);
    defer parser.deinit();

    try parser.parse(&argv);

    try std.testing.expect(!parser.getFlag("verbose"));
}

// Phase 2 Tests: Type Conversion

test "get int option valid" {
    const args = [_]Arg{
        .{ .name = "count", .long = "count", .kind = .option, .value_type = .int },
    };

    const argv = [_][]const u8{ "program", "--count", "42" };

    var parser = try Parser.init(std.testing.allocator, &args);
    defer parser.deinit();

    try parser.parse(&argv);

    const count = try parser.getInt("count");
    try std.testing.expectEqual(@as(i64, 42), count);
}

test "get int option invalid" {
    const args = [_]Arg{
        .{ .name = "count", .long = "count", .kind = .option, .value_type = .int },
    };

    const argv = [_][]const u8{ "program", "--count", "not-a-number" };

    var parser = try Parser.init(std.testing.allocator, &args);
    defer parser.deinit();

    try parser.parse(&argv);

    try std.testing.expectError(Error.InvalidValue, parser.getInt("count"));
}

test "get float option valid" {
    const args = [_]Arg{
        .{ .name = "ratio", .long = "ratio", .kind = .option, .value_type = .float },
    };

    const argv = [_][]const u8{ "program", "--ratio", "3.14159" };

    var parser = try Parser.init(std.testing.allocator, &args);
    defer parser.deinit();

    try parser.parse(&argv);

    const ratio = try parser.getFloat("ratio");
    try std.testing.expectApproxEqAbs(@as(f64, 3.14159), ratio, 0.00001);
}

test "get bool option true" {
    const args = [_]Arg{
        .{ .name = "enabled", .long = "enabled", .kind = .option, .value_type = .bool },
    };

    const argv = [_][]const u8{ "program", "--enabled", "true" };

    var parser = try Parser.init(std.testing.allocator, &args);
    defer parser.deinit();

    try parser.parse(&argv);

    const enabled = try parser.parsed.getBoolOption("enabled");
    try std.testing.expect(enabled);
}

test "get bool option false" {
    const args = [_]Arg{
        .{ .name = "enabled", .long = "enabled", .kind = .option, .value_type = .bool },
    };

    const argv = [_][]const u8{ "program", "--enabled", "false" };

    var parser = try Parser.init(std.testing.allocator, &args);
    defer parser.deinit();

    try parser.parse(&argv);

    const enabled = try parser.parsed.getBoolOption("enabled");
    try std.testing.expect(!enabled);
}

test "get bool option yes" {
    const args = [_]Arg{
        .{ .name = "enabled", .long = "enabled", .kind = .option, .value_type = .bool },
    };

    const argv = [_][]const u8{ "program", "--enabled", "yes" };

    var parser = try Parser.init(std.testing.allocator, &args);
    defer parser.deinit();

    try parser.parse(&argv);

    const enabled = try parser.parsed.getBoolOption("enabled");
    try std.testing.expect(enabled);
}

test "get bool option 1" {
    const args = [_]Arg{
        .{ .name = "enabled", .long = "enabled", .kind = .option, .value_type = .bool },
    };

    const argv = [_][]const u8{ "program", "--enabled", "1" };

    var parser = try Parser.init(std.testing.allocator, &args);
    defer parser.deinit();

    try parser.parse(&argv);

    const enabled = try parser.parsed.getBoolOption("enabled");
    try std.testing.expect(enabled);
}

test "get bool option invalid" {
    const args = [_]Arg{
        .{ .name = "enabled", .long = "enabled", .kind = .option, .value_type = .bool },
    };

    const argv = [_][]const u8{ "program", "--enabled", "maybe" };

    var parser = try Parser.init(std.testing.allocator, &args);
    defer parser.deinit();

    try parser.parse(&argv);

    try std.testing.expectError(Error.InvalidValue, parser.parsed.getBoolOption("enabled"));
}

test "get generic bool" {
    const args = [_]Arg{
        .{ .name = "flag", .long = "flag", .kind = .option, .value_type = .bool },
    };

    const argv = [_][]const u8{ "program", "--flag", "true" };

    var parser = try Parser.init(std.testing.allocator, &args);
    defer parser.deinit();

    try parser.parse(&argv);

    const flag = try parser.get("flag", bool);
    try std.testing.expect(flag);
}

test "get generic string" {
    const args = [_]Arg{
        .{ .name = "name", .long = "name", .kind = .option, .value_type = .string },
    };

    const argv = [_][]const u8{ "program", "--name", "ziggy" };

    var parser = try Parser.init(std.testing.allocator, &args);
    defer parser.deinit();

    try parser.parse(&argv);

    const name = try parser.get("name", []const u8);
    try std.testing.expectEqualStrings("ziggy", name);
}

test "get generic i64" {
    const args = [_]Arg{
        .{ .name = "count", .long = "count", .kind = .option, .value_type = .int },
    };

    const argv = [_][]const u8{ "program", "--count", "100" };

    var parser = try Parser.init(std.testing.allocator, &args);
    defer parser.deinit();

    try parser.parse(&argv);

    const count = try parser.get("count", i64);
    try std.testing.expectEqual(@as(i64, 100), count);
}

test "get generic i32" {
    const args = [_]Arg{
        .{ .name = "port", .long = "port", .kind = .option, .value_type = .int },
    };

    const argv = [_][]const u8{ "program", "--port", "8080" };

    var parser = try Parser.init(std.testing.allocator, &args);
    defer parser.deinit();

    try parser.parse(&argv);

    const port = try parser.get("port", i32);
    try std.testing.expectEqual(@as(i32, 8080), port);
}

test "get generic f64" {
    const args = [_]Arg{
        .{ .name = "ratio", .long = "ratio", .kind = .option, .value_type = .float },
    };

    const argv = [_][]const u8{ "program", "--ratio", "2.71828" };

    var parser = try Parser.init(std.testing.allocator, &args);
    defer parser.deinit();

    try parser.parse(&argv);

    const ratio = try parser.get("ratio", f64);
    try std.testing.expectApproxEqAbs(@as(f64, 2.71828), ratio, 0.00001);
}

// Phase 2 Tests: Default Values

test "default int value" {
    const args = [_]Arg{
        .{ .name = "count", .long = "count", .kind = .option, .value_type = .int, .default = .{ .int = 10 } },
    };

    const argv = [_][]const u8{ "program" };

    var parser = try Parser.init(std.testing.allocator, &args);
    defer parser.deinit();

    try parser.parse(&argv);

    const count = try parser.getInt("count");
    try std.testing.expectEqual(@as(i64, 10), count);
}

test "default string value" {
    const args = [_]Arg{
        .{ .name = "output", .long = "output", .kind = .option, .value_type = .string, .default = .{ .string = "out.txt" } },
    };

    const argv = [_][]const u8{ "program" };

    var parser = try Parser.init(std.testing.allocator, &args);
    defer parser.deinit();

    try parser.parse(&argv);

    const output = parser.getOptionDefault("output");
    try std.testing.expect(output != null);
    try std.testing.expectEqualStrings("out.txt", output.?);
}

test "default float value" {
    const args = [_]Arg{
        .{ .name = "threshold", .long = "threshold", .kind = .option, .value_type = .float, .default = .{ .float = 0.5 } },
    };

    const argv = [_][]const u8{ "program" };

    var parser = try Parser.init(std.testing.allocator, &args);
    defer parser.deinit();

    try parser.parse(&argv);

    const threshold = try parser.getFloat("threshold");
    try std.testing.expectApproxEqAbs(@as(f64, 0.5), threshold, 0.00001);
}

test "default value overridden by cli argument" {
    const args = [_]Arg{
        .{ .name = "count", .long = "count", .kind = .option, .value_type = .int, .default = .{ .int = 10 } },
    };

    const argv = [_][]const u8{ "program", "--count", "42" };

    var parser = try Parser.init(std.testing.allocator, &args);
    defer parser.deinit();

    try parser.parse(&argv);

    const count = try parser.getInt("count");
    try std.testing.expectEqual(@as(i64, 42), count);
}

test "generic get with default" {
    const args = [_]Arg{
        .{ .name = "port", .long = "port", .kind = .option, .value_type = .int, .default = .{ .int = 3000 } },
    };

    const argv = [_][]const u8{ "program" };

    var parser = try Parser.init(std.testing.allocator, &args);
    defer parser.deinit();

    try parser.parse(&argv);

    const port = try parser.get("port", i32);
    try std.testing.expectEqual(@as(i32, 3000), port);
}

test "get with default overridden" {
    const args = [_]Arg{
        .{ .name = "port", .long = "port", .kind = .option, .value_type = .int, .default = .{ .int = 3000 } },
    };

    const argv = [_][]const u8{ "program", "--port", "8080" };

    var parser = try Parser.init(std.testing.allocator, &args);
    defer parser.deinit();

    try parser.parse(&argv);

    const port = try parser.get("port", i32);
    try std.testing.expectEqual(@as(i32, 8080), port);
}

test "required with no value and no default" {
    const args = [_]Arg{
        .{ .name = "count", .long = "count", .kind = .option, .value_type = .int, .required = true },
    };

    const argv = [_][]const u8{ "program" };

    var parser = try Parser.init(std.testing.allocator, &args);
    defer parser.deinit();

    try std.testing.expectError(Error.MissingRequired, parser.parse(&argv));
}

test "required satisfied by default" {
    const args = [_]Arg{
        .{ .name = "count", .long = "count", .kind = .option, .value_type = .int, .required = true, .default = .{ .int = 5 } },
    };

    const argv = [_][]const u8{ "program" };

    var parser = try Parser.init(std.testing.allocator, &args);
    defer parser.deinit();

    try parser.parse(&argv);

    const count = try parser.getInt("count");
    try std.testing.expectEqual(@as(i64, 5), count);
}

test "parsed values get int option default" {
    const args = [_]Arg{
        .{ .name = "count", .long = "count", .kind = .option, .value_type = .int },
    };

    const argv = [_][]const u8{ "program" };

    var parser = try Parser.init(std.testing.allocator, &args);
    defer parser.deinit();

    try parser.parse(&argv);

    const count = try parser.parsed.getIntOptionDefault("count", 10);
    try std.testing.expectEqual(@as(i64, 10), count);
}

test "parsed values get float option default" {
    const args = [_]Arg{
        .{ .name = "ratio", .long = "ratio", .kind = .option, .value_type = .float },
    };

    const argv = [_][]const u8{ "program" };

    var parser = try Parser.init(std.testing.allocator, &args);
    defer parser.deinit();

    try parser.parse(&argv);

    const ratio = try parser.parsed.getFloatOptionDefault("ratio", 0.5);
    try std.testing.expectApproxEqAbs(@as(f64, 0.5), ratio, 0.00001);
}

test "parsed values get bool option default" {
    const args = [_]Arg{
        .{ .name = "enabled", .long = "enabled", .kind = .option, .value_type = .bool },
    };

    const argv = [_][]const u8{ "program" };

    var parser = try Parser.init(std.testing.allocator, &args);
    defer parser.deinit();

    try parser.parse(&argv);

    const enabled = try parser.parsed.getBoolOptionDefault("enabled", false);
    try std.testing.expect(!enabled);
}

// Phase 3 Tests: Positional Arguments

test "positional argument defined" {
    const args = [_]Arg{
        .{ .name = "input", .kind = .positional, .position = 0 },
    };

    const argv = [_][]const u8{ "program", "file.txt" };

    var parser = try Parser.init(std.testing.allocator, &args);
    defer parser.deinit();

    try parser.parse(&argv);

    const input = parser.getPositional("input");
    try std.testing.expect(input != null);
    try std.testing.expectEqualStrings("file.txt", input.?);
}

test "positional argument by position index" {
    const args = [_]Arg{
        .{ .name = "input", .kind = .positional, .position = 0 },
    };

    const argv = [_][]const u8{ "program", "file.txt" };

    var parser = try Parser.init(std.testing.allocator, &args);
    defer parser.deinit();

    try parser.parse(&argv);

    const input = parser.parsed.getPositional(0);
    try std.testing.expect(input != null);
    try std.testing.expectEqualStrings("file.txt", input.?);
}

test "multiple positional arguments" {
    const args = [_]Arg{
        .{ .name = "input", .kind = .positional, .position = 0 },
        .{ .name = "output", .kind = .positional, .position = 1 },
    };

    const argv = [_][]const u8{ "program", "input.txt", "output.txt" };

    var parser = try Parser.init(std.testing.allocator, &args);
    defer parser.deinit();

    try parser.parse(&argv);

    const input = parser.getPositional("input");
    const output = parser.getPositional("output");

    try std.testing.expect(input != null);
    try std.testing.expect(output != null);
    try std.testing.expectEqualStrings("input.txt", input.?);
    try std.testing.expectEqualStrings("output.txt", output.?);
}

test "required positional provided" {
    const args = [_]Arg{
        .{ .name = "input", .kind = .positional, .position = 0, .required = true },
    };

    const argv = [_][]const u8{ "program", "file.txt" };

    var parser = try Parser.init(std.testing.allocator, &args);
    defer parser.deinit();

    try parser.parse(&argv);

    const input = try parser.getRequiredPositional("input");
    try std.testing.expectEqualStrings("file.txt", input);
}

test "required positional missing" {
    const args = [_]Arg{
        .{ .name = "input", .kind = .positional, .position = 0, .required = true },
    };

    const argv = [_][]const u8{ "program" };

    var parser = try Parser.init(std.testing.allocator, &args);
    defer parser.deinit();

    try std.testing.expectError(Error.MissingRequired, parser.parse(&argv));
}

test "positional as integer" {
    const args = [_]Arg{
        .{ .name = "count", .kind = .positional, .position = 0, .value_type = .int },
    };

    const argv = [_][]const u8{ "program", "42" };

    var parser = try Parser.init(std.testing.allocator, &args);
    defer parser.deinit();

    try parser.parse(&argv);

    const count = try parser.getIntPositional("count");
    try std.testing.expectEqual(@as(i64, 42), count);
}

test "positional as float" {
    const args = [_]Arg{
        .{ .name = "ratio", .kind = .positional, .position = 0, .value_type = .float },
    };

    const argv = [_][]const u8{ "program", "3.14159" };

    var parser = try Parser.init(std.testing.allocator, &args);
    defer parser.deinit();

    try parser.parse(&argv);

    const ratio = try parser.getFloatPositional("ratio");
    try std.testing.expectApproxEqAbs(@as(f64, 3.14159), ratio, 0.00001);
}

test "positional invalid integer" {
    const args = [_]Arg{
        .{ .name = "count", .kind = .positional, .position = 0, .value_type = .int },
    };

    const argv = [_][]const u8{ "program", "not-a-number" };

    var parser = try Parser.init(std.testing.allocator, &args);
    defer parser.deinit();

    try parser.parse(&argv);

    try std.testing.expectError(Error.InvalidValue, parser.getIntPositional("count"));
}

test "mixed flags and positionals" {
    const args = [_]Arg{
        .{ .name = "verbose", .short = 'v', .long = "verbose", .kind = .flag },
        .{ .name = "input", .kind = .positional, .position = 0 },
        .{ .name = "output", .kind = .positional, .position = 1 },
    };

    const argv = [_][]const u8{ "program", "-v", "input.txt", "output.txt" };

    var parser = try Parser.init(std.testing.allocator, &args);
    defer parser.deinit();

    try parser.parse(&argv);

    try std.testing.expect(parser.getFlag("verbose"));
    try std.testing.expectEqualStrings("input.txt", parser.getPositional("input").?);
    try std.testing.expectEqualStrings("output.txt", parser.getPositional("output").?);
}

test "mixed options and positionals" {
    const args = [_]Arg{
        .{ .name = "file", .short = 'f', .long = "file", .kind = .option },
        .{ .name = "input", .kind = .positional, .position = 0 },
    };

    const argv = [_][]const u8{ "program", "--file", "config.txt", "data.txt" };

    var parser = try Parser.init(std.testing.allocator, &args);
    defer parser.deinit();

    try parser.parse(&argv);

    try std.testing.expectEqualStrings("config.txt", parser.getOption("file").?);
    try std.testing.expectEqualStrings("data.txt", parser.getPositional("input").?);
}

test "flags after positionals" {
    const args = [_]Arg{
        .{ .name = "verbose", .short = 'v', .kind = .flag },
        .{ .name = "input", .kind = .positional, .position = 0 },
    };

    const argv = [_][]const u8{ "program", "data.txt", "-v" };

    var parser = try Parser.init(std.testing.allocator, &args);
    defer parser.deinit();

    try parser.parse(&argv);

    try std.testing.expect(parser.getFlag("verbose"));
    try std.testing.expectEqualStrings("data.txt", parser.getPositional("input").?);
}

test "options after positionals" {
    const args = [_]Arg{
        .{ .name = "count", .short = 'c', .long = "count", .kind = .option },
        .{ .name = "input", .kind = .positional, .position = 0 },
    };

    const argv = [_][]const u8{ "program", "data.txt", "--count", "10" };

    var parser = try Parser.init(std.testing.allocator, &args);
    defer parser.deinit();

    try parser.parse(&argv);

    try std.testing.expectEqualStrings("10", parser.getOption("count").?);
    try std.testing.expectEqualStrings("data.txt", parser.getPositional("input").?);
}

test "fully mixed: flags, options, and positionals" {
    const args = [_]Arg{
        .{ .name = "verbose", .short = 'v', .kind = .flag },
        .{ .name = "output", .short = 'o', .long = "output", .kind = .option },
        .{ .name = "input", .kind = .positional, .position = 0 },
        .{ .name = "count", .kind = .positional, .position = 1 },
    };

    const argv = [_][]const u8{ "program", "-v", "input.txt", "5", "--output", "result.txt" };

    var parser = try Parser.init(std.testing.allocator, &args);
    defer parser.deinit();

    try parser.parse(&argv);

    try std.testing.expect(parser.getFlag("verbose"));
    try std.testing.expectEqualStrings("result.txt", parser.getOption("output").?);
    try std.testing.expectEqualStrings("input.txt", parser.getPositional("input").?);
    try std.testing.expectEqual(@as(i64, 5), try parser.getIntPositional("count"));
}

test "unnamed positionals collected" {
    const args = [_]Arg{
        .{ .name = "verbose", .short = 'v', .kind = .flag },
    };

    const argv = [_][]const u8{ "program", "file1.txt", "file2.txt", "file3.txt", "-v" };

    var parser = try Parser.init(std.testing.allocator, &args);
    defer parser.deinit();

    try parser.parse(&argv);

    const positionals = parser.getPositionals();
    try std.testing.expectEqual(@as(usize, 3), positionals.len);
    try std.testing.expectEqualStrings("file1.txt", positionals[0]);
    try std.testing.expectEqualStrings("file2.txt", positionals[1]);
    try std.testing.expectEqualStrings("file3.txt", positionals[2]);
    try std.testing.expect(parser.getFlag("verbose"));
}

test "partial named positionals with extras" {
    const args = [_]Arg{
        .{ .name = "input", .kind = .positional, .position = 0 },
    };

    const argv = [_][]const u8{ "program", "main.txt", "extra1.txt", "extra2.txt" };

    var parser = try Parser.init(std.testing.allocator, &args);
    defer parser.deinit();

    try parser.parse(&argv);

    try std.testing.expectEqualStrings("main.txt", parser.getPositional("input").?);

    const positionals = parser.getPositionals();
    try std.testing.expectEqual(@as(usize, 3), positionals.len);
}

test "missing positional at defined position" {
    const args = [_]Arg{
        .{ .name = "input", .kind = .positional, .position = 0 },
        .{ .name = "output", .kind = .positional, .position = 1 },
    };

    const argv = [_][]const u8{ "program", "only-input.txt" };

    var parser = try Parser.init(std.testing.allocator, &args);
    defer parser.deinit();

    try parser.parse(&argv);

    try std.testing.expectEqualStrings("only-input.txt", parser.getPositional("input").?);
    try std.testing.expect(parser.getPositional("output") == null);
}

// Phase 4 Tests: Help Generation

test "parser help method generates help" {
    const args = [_]Arg{
        .{ .name = "verbose", .short = 'v', .long = "verbose", .kind = .flag, .help = "Enable verbose output" },
        .{ .name = "output", .short = 'o', .long = "output", .kind = .option, .help = "Output file" },
    };

    var parser = try Parser.init(std.testing.allocator, &args);
    defer parser.deinit();

    const help = try parser.help();
    defer std.testing.allocator.free(help);

    try std.testing.expect(std.mem.indexOf(u8, help, "Usage:") != null);
    try std.testing.expect(std.mem.indexOf(u8, help, "-v, --verbose") != null);
    try std.testing.expect(std.mem.indexOf(u8, help, "Enable verbose output") != null);
    try std.testing.expect(std.mem.indexOf(u8, help, "-o, --output") != null);
}

test "parser with custom help config" {
    const args = [_]Arg{
        .{ .name = "verbose", .short = 'v', .long = "verbose", .kind = .flag, .help = "Enable verbose output" },
    };

    const config = HelpConfig{
        .program_name = "mytool",
        .description = "A tool for doing things",
        .options_width = 30,
        .color = .never,
    };

    var parser = try Parser.initWithConfig(std.testing.allocator, &args, config);
    defer parser.deinit();

    const help = try parser.help();
    defer std.testing.allocator.free(help);

    try std.testing.expect(std.mem.indexOf(u8, help, "Usage: mytool") != null);
    try std.testing.expect(std.mem.indexOf(u8, help, "A tool for doing things") != null);
}

test "parse returns ShowHelp for --help" {
    const args = [_]Arg{
        .{ .name = "verbose", .short = 'v', .long = "verbose", .kind = .flag },
    };

    const argv = [_][]const u8{ "program", "--help" };

    var parser = try Parser.init(std.testing.allocator, &args);
    defer parser.deinit();

    try std.testing.expectError(Error.ShowHelp, parser.parse(&argv));
}

test "parse returns ShowHelp for -h" {
    const args = [_]Arg{
        .{ .name = "verbose", .short = 'v', .long = "verbose", .kind = .flag },
    };

    const argv = [_][]const u8{ "program", "-h" };

    var parser = try Parser.init(std.testing.allocator, &args);
    defer parser.deinit();

    try std.testing.expectError(Error.ShowHelp, parser.parse(&argv));
}

test "setHelpConfig updates configuration" {
    const args = [_]Arg{
        .{ .name = "verbose", .short = 'v', .long = "verbose", .kind = .flag, .help = "Enable verbose output" },
    };

    var parser = try Parser.init(std.testing.allocator, &args);
    defer parser.deinit();

    parser.setHelpConfig(.{
        .program_name = "newname",
        .description = "New description",
        .color = .never,
    });

    const help = try parser.help();
    defer std.testing.allocator.free(help);

    try std.testing.expect(std.mem.indexOf(u8, help, "Usage: newname") != null);
    try std.testing.expect(std.mem.indexOf(u8, help, "New description") != null);
}

// Phase 5 Tests: Advanced Features

test "counted short flags" {
    const args = [_]Arg{
        .{ .name = "verbose", .short = 'v', .kind = .count },
    };

    const argv = [_][]const u8{ "program", "-vvv" };

    var parser = try Parser.init(std.testing.allocator, &args);
    defer parser.deinit();

    try parser.parse(&argv);

    try std.testing.expectEqual(@as(usize, 3), parser.getCount("verbose"));
}

test "counted long flags" {
    const args = [_]Arg{
        .{ .name = "verbose", .long = "verbose", .kind = .count },
    };

    const argv = [_][]const u8{ "program", "--verbose", "--verbose" };

    var parser = try Parser.init(std.testing.allocator, &args);
    defer parser.deinit();

    try parser.parse(&argv);

    try std.testing.expectEqual(@as(usize, 2), parser.getCount("verbose"));
}

test "option validator rejects value" {
    const args = [_]Arg{
        .{ .name = "count", .long = "count", .kind = .option, .validator = validateEven },
    };

    const argv = [_][]const u8{ "program", "--count", "3" };

    var parser = try Parser.init(std.testing.allocator, &args);
    defer parser.deinit();

    try std.testing.expectError(Error.InvalidValue, parser.parse(&argv));
}

test "positional validator rejects value" {
    const args = [_]Arg{
        .{ .name = "count", .kind = .positional, .position = 0, .validator = validateEven },
    };

    const argv = [_][]const u8{ "program", "3" };

    var parser = try Parser.init(std.testing.allocator, &args);
    defer parser.deinit();

    try std.testing.expectError(Error.InvalidValue, parser.parse(&argv));
}

test "parse long alias" {
    const args = [_]Arg{
        .{ .name = "output", .long = "output", .aliases = &.{ "out" }, .kind = .option },
    };

    const argv = [_][]const u8{ "program", "--out", "file.txt" };

    var parser = try Parser.init(std.testing.allocator, &args);
    defer parser.deinit();

    try parser.parse(&argv);

    try std.testing.expectEqualStrings("file.txt", parser.getOption("output").?);
}

test "parse short alias" {
    const args = [_]Arg{
        .{ .name = "output", .short = 'o', .short_aliases = &.{ 'O' }, .kind = .option },
    };

    const argv = [_][]const u8{ "program", "-O", "file.txt" };

    var parser = try Parser.init(std.testing.allocator, &args);
    defer parser.deinit();

    try parser.parse(&argv);

    try std.testing.expectEqualStrings("file.txt", parser.getOption("output").?);
}

test "multi-value option collects values" {
    const args = [_]Arg{
        .{ .name = "file", .long = "file", .kind = .option, .multiple = true },
    };

    const argv = [_][]const u8{ "program", "--file", "a.txt", "--file", "b.txt" };

    var parser = try Parser.init(std.testing.allocator, &args);
    defer parser.deinit();

    try parser.parse(&argv);

    const values = parser.getOptionValues("file").?;
    try std.testing.expectEqual(@as(usize, 2), values.len);
    try std.testing.expectEqualStrings("a.txt", values[0]);
    try std.testing.expectEqualStrings("b.txt", values[1]);
    try std.testing.expectEqualStrings("b.txt", parser.getOption("file").?);
}

test "get generic u16" {
    const args = [_]Arg{
        .{ .name = "port", .long = "port", .kind = .option, .value_type = .int },
    };

    const argv = [_][]const u8{ "program", "--port", "65535" };

    var parser = try Parser.init(std.testing.allocator, &args);
    defer parser.deinit();

    try parser.parse(&argv);

    const port = try parser.get("port", u16);
    try std.testing.expectEqual(@as(u16, 65535), port);
}

test "formatError uses context" {
    const args = [_]Arg{
        .{ .name = "verbose", .long = "verbose", .kind = .flag },
    };

    const argv = [_][]const u8{ "program", "--unknown" };

    var parser = try Parser.init(std.testing.allocator, &args);
    defer parser.deinit();

    parser.parse(&argv) catch |err| {
        try std.testing.expectEqual(Error.UnknownArgument, err);

        const message = try parser.formatError(std.testing.allocator, Error.UnknownArgument, .{ .color = .never });
        defer std.testing.allocator.free(message);

        try std.testing.expect(std.mem.indexOf(u8, message, "unknown argument") != null);
        try std.testing.expect(std.mem.indexOf(u8, message, "--unknown") != null);
        return;
    };

    try std.testing.expect(false);
}

test "parse resets previous values" {
    const args = [_]Arg{
        .{ .name = "verbose", .short = 'v', .kind = .flag },
    };

    const argv_first = [_][]const u8{ "program", "-v" };
    const argv_second = [_][]const u8{ "program" };

    var parser = try Parser.init(std.testing.allocator, &args);
    defer parser.deinit();

    try parser.parse(&argv_first);
    try std.testing.expect(parser.getFlag("verbose"));

    try parser.parse(&argv_second);
    try std.testing.expect(!parser.getFlag("verbose"));
}
