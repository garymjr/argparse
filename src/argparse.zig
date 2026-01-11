//! argparse - A command-line argument parser for Zig
//!
//! This library provides type-safe, ergonomic command-line argument parsing
//! with zero-allocation by default.

pub const Arg = @import("arg.zig").Arg;
pub const ArgKind = @import("arg.zig").ArgKind;
pub const ValueType = @import("arg.zig").ValueType;
pub const Value = @import("arg.zig").Value;

pub const Parser = @import("parser.zig").Parser;
pub const ParsedValues = @import("parser.zig").ParsedValues;
pub const Command = @import("command.zig").Command;

pub const Error = @import("error.zig").Error;

pub const HelpConfig = @import("help.zig").HelpConfig;
pub const helpArg = @import("help.zig").helpArg;
pub const generateHelp = @import("help.zig").generateHelp;
pub const generateUsage = @import("help.zig").generateUsage;
