const std = @import("std");
const Command = @import("command.zig").Command;
const Arg = @import("arg.zig").Arg;
const Parser = @import("parser.zig").Parser;
const Error = @import("error.zig").Error;

const TestHandlers = struct {
    var called_basic: bool = false;
    var called_nested: bool = false;

    fn basic(parser: *Parser, argv: []const []const u8) anyerror!void {
        _ = parser;
        _ = argv;
        called_basic = true;
    }

    fn nested(parser: *Parser, argv: []const []const u8) anyerror!void {
        _ = parser;
        _ = argv;
        called_nested = true;
    }
};

test "subcommand dispatch basic" {
    TestHandlers.called_basic = false;

    const args = [_]Arg{
        .{ .name = "value", .long = "value", .kind = .option },
    };

    const sub = Command{
        .name = "add",
        .args = &args,
        .help = "Add a value",
        .handler = TestHandlers.basic,
    };

    const root = Command{
        .name = "tool",
        .help = "Root tool",
        .subcommands = &.{sub},
    };

    const argv = [_][]const u8{ "tool", "add", "--value", "42" };

    try root.run(std.testing.allocator, &argv);

    try std.testing.expect(TestHandlers.called_basic);
}

test "subcommand dispatch nested" {
    TestHandlers.called_nested = false;

    const add = Command{
        .name = "add",
        .help = "Add item",
        .handler = TestHandlers.nested,
    };

    const remote = Command{
        .name = "remote",
        .help = "Manage remotes",
        .subcommands = &.{add},
    };

    const root = Command{
        .name = "git",
        .help = "Version control",
        .subcommands = &.{remote},
    };

    const argv = [_][]const u8{ "git", "remote", "add" };

    try root.run(std.testing.allocator, &argv);

    try std.testing.expect(TestHandlers.called_nested);
}

test "subcommand help includes subcommands" {
    const clone = Command{
        .name = "clone",
        .help = "Clone a repo",
    };

    const root = Command{
        .name = "git",
        .help = "Version control",
        .subcommands = &.{clone},
    };

    const argv = [_][]const u8{ "git" };

    const help = try root.helpFor(std.testing.allocator, &argv);
    defer std.testing.allocator.free(help);

    try std.testing.expect(std.mem.indexOf(u8, help, "Subcommands:") != null);
    try std.testing.expect(std.mem.indexOf(u8, help, "clone") != null);
}

test "per-subcommand help uses command path" {
    const clone = Command{
        .name = "clone",
        .help = "Clone a repo",
    };

    const root = Command{
        .name = "git",
        .help = "Version control",
        .subcommands = &.{clone},
    };

    const argv = [_][]const u8{ "git", "clone" };

    const help = try root.helpFor(std.testing.allocator, &argv);
    defer std.testing.allocator.free(help);

    try std.testing.expect(std.mem.indexOf(u8, help, "Usage: git clone") != null);
}

test "unknown subcommand without positionals" {
    const root = Command{
        .name = "tool",
        .help = "Root tool",
        .subcommands = &.{},
    };

    const cmd = Command{
        .name = "app",
        .help = "Has subcommands",
        .subcommands = &.{root},
    };

    const argv = [_][]const u8{ "app", "nope" };

    try std.testing.expectError(Error.UnknownCommand, cmd.run(std.testing.allocator, &argv));
}
