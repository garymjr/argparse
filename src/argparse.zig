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

pub const Error = @import("error.zig").Error;
