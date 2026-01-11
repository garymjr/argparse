//! Compile-time argument validation helpers.

const std = @import("std");
const Arg = @import("arg.zig").Arg;
const ArgKind = @import("arg.zig").ArgKind;

pub fn validateArgsComptime(comptime args: []const Arg) void {
    comptime {
        var i: usize = 0;
        while (i < args.len) : (i += 1) {
            const arg = args[i];

            if (arg.name.len == 0) {
                @compileError("Arg name must not be empty");
            }

            if (arg.kind == .positional) {
                if (hasOptionNames(arg)) {
                    @compileError("Positional arg '" ++ arg.name ++ "' must not define short/long names");
                }
            } else if (!hasOptionNames(arg)) {
                @compileError("Arg '" ++ arg.name ++ "' must define a short or long name");
            }

            var j: usize = i + 1;
            while (j < args.len) : (j += 1) {
                const other = args[j];

                if (std.mem.eql(u8, arg.name, other.name)) {
                    @compileError("Duplicate arg name: " ++ arg.name);
                }

                if (hasDuplicateShort(arg, other)) {
                    @compileError("Duplicate short flag detected (" ++ arg.name ++ " vs " ++ other.name ++ ")");
                }

                if (hasDuplicateLong(arg, other)) {
                    @compileError("Duplicate long flag detected (" ++ arg.name ++ " vs " ++ other.name ++ ")");
                }

                if (arg.kind == .positional and other.kind == .positional) {
                    if (arg.position) |pos_a| {
                        if (other.position) |pos_b| {
                            if (pos_a == pos_b) {
                                @compileError("Duplicate positional index " ++ std.fmt.comptimePrint("{d}", .{pos_a}));
                            }
                        }
                    }
                }
            }
        }
    }
}

fn hasOptionNames(arg: Arg) bool {
    if (arg.short != null) return true;
    if (arg.long != null) return true;
    if (arg.short_aliases.len > 0) return true;
    if (arg.aliases.len > 0) return true;
    return false;
}

fn hasDuplicateShort(a: Arg, b: Arg) bool {
    if (a.short) |s| {
        if (hasShort(b, s)) return true;
    }
    for (a.short_aliases) |s| {
        if (hasShort(b, s)) return true;
    }
    return false;
}

fn hasShort(arg: Arg, value: u8) bool {
    if (arg.short) |s| {
        if (s == value) return true;
    }
    for (arg.short_aliases) |alias| {
        if (alias == value) return true;
    }
    return false;
}

fn hasDuplicateLong(a: Arg, b: Arg) bool {
    if (a.long) |l| {
        if (hasLong(b, l)) return true;
    }
    for (a.aliases) |alias| {
        if (hasLong(b, alias)) return true;
    }
    return false;
}

fn hasLong(arg: Arg, value: []const u8) bool {
    if (arg.long) |l| {
        if (std.mem.eql(u8, l, value)) return true;
    }
    for (arg.aliases) |alias| {
        if (std.mem.eql(u8, alias, value)) return true;
    }
    return false;
}
