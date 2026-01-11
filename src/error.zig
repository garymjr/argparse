//! Error types for argument parsing.

const std = @import("std");
const Arg = @import("arg.zig").Arg;
const ColorMode = @import("style.zig").ColorMode;
const Ansi = @import("style.zig").Ansi;
const useColorStderr = @import("style.zig").useColorStderr;

pub const Error = error{
    /// Unknown argument provided
    UnknownArgument,
    /// Option value missing after flag
    MissingValue,
    /// Required argument not provided
    MissingRequired,
    /// Invalid value for argument type
    InvalidValue,
    /// Duplicate argument provided
    DuplicateArgument,
    /// Unknown subcommand provided
    UnknownCommand,
    /// Help requested (--help or -h)
    ShowHelp,
};

pub const ErrorContext = struct {
    kind: Error,
    token: ?[]const u8 = null,
    arg: ?*const Arg = null,
    value: ?[]const u8 = null,
};

pub const ErrorFormatConfig = struct {
    color: ColorMode = .auto,
};

pub fn formatError(allocator: std.mem.Allocator, context: ErrorContext, config: ErrorFormatConfig) ![]const u8 {
    var buffer = std.array_list.AlignedManaged(u8, null).init(allocator);
    defer buffer.deinit();

    const color = useColorStderr(config.color);
    try writeErrorPrefix(buffer.writer(), color);

    switch (context.kind) {
        Error.UnknownArgument => {
            try buffer.writer().writeAll("unknown argument");
            if (context.token) |token| {
                try buffer.writer().writeAll(" ");
                try writeToken(buffer.writer(), color, token);
            }
        },
        Error.MissingValue => {
            try buffer.writer().writeAll("missing value for ");
            try writeArgRef(buffer.writer(), color, context.arg, "option");
        },
        Error.MissingRequired => {
            try buffer.writer().writeAll("missing required ");
            try writeArgRef(buffer.writer(), color, context.arg, "argument");
        },
        Error.InvalidValue => {
            try buffer.writer().writeAll("invalid value");
            if (context.value) |value| {
                try buffer.writer().writeAll(" ");
                try writeToken(buffer.writer(), color, value);
            }
            try buffer.writer().writeAll(" for ");
            try writeArgRef(buffer.writer(), color, context.arg, "argument");
        },
        Error.DuplicateArgument => {
            try buffer.writer().writeAll("duplicate argument ");
            try writeArgRef(buffer.writer(), color, context.arg, "argument");
        },
        Error.UnknownCommand => {
            try buffer.writer().writeAll("unknown command");
            if (context.token) |token| {
                try buffer.writer().writeAll(" ");
                try writeToken(buffer.writer(), color, token);
            }
        },
        Error.ShowHelp => {
            try buffer.writer().writeAll("help requested");
        },
    }

    return buffer.toOwnedSlice();
}

fn writeErrorPrefix(writer: anytype, color: bool) !void {
    if (color) {
        try writer.writeAll(Ansi.bold);
        try writer.writeAll(Ansi.red);
    }
    try writer.writeAll("error");
    if (color) {
        try writer.writeAll(Ansi.reset);
    }
    try writer.writeAll(": ");
}

fn writeToken(writer: anytype, color: bool, token: []const u8) !void {
    if (color) {
        try writer.writeAll(Ansi.bold);
        try writer.writeAll(Ansi.yellow);
    }
    try writer.writeAll("'");
    try writer.writeAll(token);
    try writer.writeAll("'");
    if (color) {
        try writer.writeAll(Ansi.reset);
    }
}

fn writeArgRef(writer: anytype, color: bool, arg: ?*const Arg, fallback: []const u8) !void {
    if (arg) |def| {
        if (color) {
            try writer.writeAll(Ansi.bold);
            try writer.writeAll(Ansi.cyan);
        }
        if (def.kind == .positional) {
            try writer.print("<{s}>", .{def.name});
        } else if (def.long) |long_name| {
            try writer.print("--{s}", .{long_name});
        } else if (def.short) |short_name| {
            try writer.print("-{c}", .{short_name});
        } else if (def.aliases.len > 0) {
            try writer.print("--{s}", .{def.aliases[0]});
        } else if (def.short_aliases.len > 0) {
            try writer.print("-{c}", .{def.short_aliases[0]});
        } else {
            try writer.writeAll(def.name);
        }
        if (color) {
            try writer.writeAll(Ansi.reset);
        }
        return;
    }

    try writer.writeAll(fallback);
}
