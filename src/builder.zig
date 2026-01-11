//! Builder API for argparse.

const std = @import("std");
const Arg = @import("arg.zig").Arg;
const ArgKind = @import("arg.zig").ArgKind;
const ValueType = @import("arg.zig").ValueType;
const Value = @import("arg.zig").Value;
const HelpConfig = @import("help.zig").HelpConfig;
const Parser = @import("parser.zig").Parser;

pub const ArgOptions = struct {
    short_aliases: []const u8 = &.{},
    aliases: []const []const u8 = &.{},
    value_type: ValueType = .string,
    multiple: bool = false,
    default: ?Value = null,
    required: bool = false,
    validator: ?*const fn ([]const u8) anyerror!void = null,
    position: ?usize = null,
};

pub const Builder = struct {
    allocator: std.mem.Allocator,
    args: std.ArrayList(Arg) = .{},
    help_config: HelpConfig = .{},
    next_positional_index: usize = 0,

    pub fn init(allocator: std.mem.Allocator) Builder {
        return .{
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *Builder) void {
        self.args.deinit(self.allocator);
    }

    pub fn setHelpConfig(self: *Builder, config: HelpConfig) *Builder {
        self.help_config = config;
        return self;
    }

    pub fn addArg(self: *Builder, arg: Arg) !*Builder {
        try self.args.append(self.allocator, arg);
        if (arg.kind == .positional) {
            if (arg.position) |pos| {
                if (pos >= self.next_positional_index) {
                    self.next_positional_index = pos + 1;
                }
            } else {
                self.next_positional_index += 1;
            }
        }
        return self;
    }

    pub fn addFlag(self: *Builder, name: []const u8, short: ?u8, long: ?[]const u8, help: []const u8) !*Builder {
        return self.addFlagWith(name, short, long, help, .{});
    }

    pub fn addFlagWith(self: *Builder, name: []const u8, short: ?u8, long: ?[]const u8, help: []const u8, options: ArgOptions) !*Builder {
        return self.addArg(.{
            .name = name,
            .short = short,
            .short_aliases = options.short_aliases,
            .long = long,
            .aliases = options.aliases,
            .help = help,
            .kind = .flag,
            .required = options.required,
        });
    }

    pub fn addCount(self: *Builder, name: []const u8, short: ?u8, long: ?[]const u8, help: []const u8) !*Builder {
        return self.addCountWith(name, short, long, help, .{});
    }

    pub fn addCountWith(self: *Builder, name: []const u8, short: ?u8, long: ?[]const u8, help: []const u8, options: ArgOptions) !*Builder {
        return self.addArg(.{
            .name = name,
            .short = short,
            .short_aliases = options.short_aliases,
            .long = long,
            .aliases = options.aliases,
            .help = help,
            .kind = .count,
            .required = options.required,
        });
    }

    pub fn addOption(self: *Builder, name: []const u8, short: ?u8, long: ?[]const u8, value_type: ValueType, help: []const u8) !*Builder {
        return self.addOptionWith(name, short, long, value_type, help, .{});
    }

    pub fn addOptionWith(self: *Builder, name: []const u8, short: ?u8, long: ?[]const u8, value_type: ValueType, help: []const u8, options: ArgOptions) !*Builder {
        return self.addArg(.{
            .name = name,
            .short = short,
            .short_aliases = options.short_aliases,
            .long = long,
            .aliases = options.aliases,
            .help = help,
            .kind = .option,
            .value_type = value_type,
            .multiple = options.multiple,
            .default = options.default,
            .required = options.required,
            .validator = options.validator,
        });
    }

    pub fn addPositional(self: *Builder, name: []const u8, value_type: ValueType, help: []const u8) !*Builder {
        return self.addPositionalWith(name, value_type, help, .{});
    }

    pub fn addPositionalWith(self: *Builder, name: []const u8, value_type: ValueType, help: []const u8, options: ArgOptions) !*Builder {
        const position = options.position orelse self.next_positional_index;
        if (options.position == null) {
            self.next_positional_index += 1;
        }

        return self.addArg(.{
            .name = name,
            .help = help,
            .kind = .positional,
            .value_type = value_type,
            .default = options.default,
            .required = options.required,
            .validator = options.validator,
            .position = position,
        });
    }

    pub fn build(self: *Builder) !Parser {
        const owned_args = try self.args.toOwnedSlice(self.allocator);
        self.args = .{};
        return Parser.initOwned(self.allocator, owned_args, self.help_config);
    }
};
