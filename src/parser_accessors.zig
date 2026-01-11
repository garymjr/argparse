const std = @import("std");
const Arg = @import("arg.zig").Arg;
const Error = @import("error.zig").Error;

pub fn getFlag(self: anytype, name: []const u8) bool {
    return self.parsed.getFlag(name);
}

pub fn getCount(self: anytype, name: []const u8) usize {
    return self.parsed.getCount(name);
}

pub fn getOption(self: anytype, name: []const u8) ?[]const u8 {
    return self.parsed.getOption(name);
}

pub fn getOptionValues(self: anytype, name: []const u8) ?[]const []const u8 {
    return self.parsed.getOptionValues(name);
}

pub fn getRequiredOption(self: anytype, name: []const u8) Error![]const u8 {
    return self.parsed.getRequiredOption(name);
}

pub fn getPositionals(self: anytype) []const []const u8 {
    return self.parsed.getPositionals();
}

pub fn getPositional(self: anytype, name: []const u8) ?[]const u8 {
    for (self.args) |arg| {
        if (std.mem.eql(u8, arg.name, name)) {
            if (arg.position) |pos| {
                return self.parsed.getPositional(pos);
            }
        }
    }
    return null;
}

pub fn getRequiredPositional(self: anytype, name: []const u8) Error![]const u8 {
    for (self.args) |arg| {
        if (std.mem.eql(u8, arg.name, name)) {
            if (arg.position) |pos| {
                return self.parsed.getRequiredPositional(pos);
            }
        }
    }
    return Error.UnknownArgument;
}

pub fn getIntPositional(self: anytype, name: []const u8) !i64 {
    for (self.args) |arg| {
        if (std.mem.eql(u8, arg.name, name)) {
            if (arg.position) |pos| {
                return self.parsed.getIntPositional(pos);
            }
        }
    }
    return Error.UnknownArgument;
}

pub fn getFloatPositional(self: anytype, name: []const u8) !f64 {
    for (self.args) |arg| {
        if (std.mem.eql(u8, arg.name, name)) {
            if (arg.position) |pos| {
                return self.parsed.getFloatPositional(pos);
            }
        }
    }
    return Error.UnknownArgument;
}

pub fn getOptionDefault(self: anytype, name: []const u8) ?[]const u8 {
    if (self.parsed.options.get(name)) |val| {
        return val;
    }
    for (self.args) |arg| {
        if (std.mem.eql(u8, arg.name, name)) {
            if (arg.default) |def| {
                if (def == .string) return def.string;
            }
        }
    }
    return null;
}

pub fn getInt(self: anytype, name: []const u8) !i64 {
    if (self.parsed.options.get(name)) |str| {
        return std.fmt.parseInt(i64, str, 10) catch return Error.InvalidValue;
    }
    for (self.args) |arg| {
        if (std.mem.eql(u8, arg.name, name)) {
            if (arg.default) |def| {
                if (def == .int) return def.int;
            }
            if (arg.required) return Error.MissingRequired;
        }
    }
    return Error.MissingRequired;
}

pub fn getFloat(self: anytype, name: []const u8) !f64 {
    if (self.parsed.options.get(name)) |str| {
        return std.fmt.parseFloat(f64, str) catch return Error.InvalidValue;
    }
    for (self.args) |arg| {
        if (std.mem.eql(u8, arg.name, name)) {
            if (arg.default) |def| {
                if (def == .float) return def.float;
            }
            if (arg.required) return Error.MissingRequired;
        }
    }
    return Error.MissingRequired;
}

pub fn get(self: anytype, comptime name: []const u8, comptime T: type) !T {
    const str_opt = self.parsed.options.get(name);

    var arg_def: ?*const Arg = null;
    for (self.args) |*arg| {
        if (std.mem.eql(u8, arg.name, name)) {
            arg_def = arg;
            break;
        }
    }

    const arg = arg_def orelse return Error.UnknownArgument;

    if (str_opt == null) {
        if (arg.default) |def| {
            switch (T) {
                bool => {
                    if (def == .bool) return def.bool;
                },
                []const u8 => {
                    if (def == .string) return def.string;
                },
                i64, i32, i16, i8 => {
                    if (def == .int) return @as(T, @intCast(def.int));
                },
                u64, u32, u16, u8, usize => {
                    if (def == .int and def.int >= 0) {
                        const value = @as(u64, @intCast(def.int));
                        return std.math.cast(T, value) orelse return Error.InvalidValue;
                    }
                },
                f64, f32 => {
                    if (def == .float) return @as(f64, def.float);
                },
                else => {},
            }
        }
        if (arg.required) return Error.MissingRequired;
        return Error.MissingRequired;
    }

    const str = str_opt.?;

    switch (T) {
        bool => {
            if (std.mem.eql(u8, str, "true") or std.mem.eql(u8, str, "1") or std.mem.eql(u8, str, "yes") or std.mem.eql(u8, str, "on")) {
                return true;
            }
            if (std.mem.eql(u8, str, "false") or std.mem.eql(u8, str, "0") or std.mem.eql(u8, str, "no") or std.mem.eql(u8, str, "off")) {
                return false;
            }
            return Error.InvalidValue;
        },
        []const u8 => {
            return str;
        },
        i64 => {
            return std.fmt.parseInt(i64, str, 10) catch return Error.InvalidValue;
        },
        i32 => {
            const val = std.fmt.parseInt(i64, str, 10) catch return Error.InvalidValue;
            return std.math.cast(i32, val) orelse return Error.InvalidValue;
        },
        i16 => {
            const val = std.fmt.parseInt(i64, str, 10) catch return Error.InvalidValue;
            return std.math.cast(i16, val) orelse return Error.InvalidValue;
        },
        i8 => {
            const val = std.fmt.parseInt(i64, str, 10) catch return Error.InvalidValue;
            return std.math.cast(i8, val) orelse return Error.InvalidValue;
        },
        u64 => {
            return std.fmt.parseInt(u64, str, 10) catch return Error.InvalidValue;
        },
        u32 => {
            const val = std.fmt.parseInt(u64, str, 10) catch return Error.InvalidValue;
            return std.math.cast(u32, val) orelse return Error.InvalidValue;
        },
        u16 => {
            const val = std.fmt.parseInt(u64, str, 10) catch return Error.InvalidValue;
            return std.math.cast(u16, val) orelse return Error.InvalidValue;
        },
        u8 => {
            const val = std.fmt.parseInt(u64, str, 10) catch return Error.InvalidValue;
            return std.math.cast(u8, val) orelse return Error.InvalidValue;
        },
        usize => {
            return std.fmt.parseInt(usize, str, 10) catch return Error.InvalidValue;
        },
        f64 => {
            return std.fmt.parseFloat(f64, str) catch return Error.InvalidValue;
        },
        f32 => {
            return std.math.cast(f32, try std.fmt.parseFloat(f64, str)) orelse return Error.InvalidValue;
        },
        else => {
            @compileError("Unsupported type for get(): " ++ @typeName(T));
        },
    }
}
