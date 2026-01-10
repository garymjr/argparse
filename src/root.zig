//! By convention, root.zig is the root source file when making a library.
//!
//! This is the public API for the argparse library.

pub const argparse = @import("argparse.zig");
pub const Arg = argparse.Arg;
pub const ArgKind = argparse.ArgKind;
pub const Parser = argparse.Parser;
pub const ParsedValues = argparse.ParsedValues;
pub const Error = argparse.Error;
