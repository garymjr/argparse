//! By convention, root.zig is the root source file when making a library.
//!
//! This is the public API for the argparse library.

pub const argparse = @import("argparse.zig");
pub const Arg = argparse.Arg;
pub const ArgKind = argparse.ArgKind;
pub const ValueType = argparse.ValueType;
pub const Value = argparse.Value;
pub const Parser = argparse.Parser;
pub const ParsedValues = argparse.ParsedValues;
pub const Error = argparse.Error;
pub const HelpConfig = argparse.HelpConfig;
pub const helpArg = argparse.helpArg;
pub const generateHelp = argparse.generateHelp;
pub const generateUsage = argparse.generateUsage;
