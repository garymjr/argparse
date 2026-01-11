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
pub const Command = argparse.Command;
pub const Builder = argparse.Builder;
pub const ArgOptions = argparse.ArgOptions;
pub const Error = argparse.Error;
pub const ErrorContext = argparse.ErrorContext;
pub const ErrorFormatConfig = argparse.ErrorFormatConfig;
pub const formatError = argparse.formatError;
pub const ColorMode = argparse.ColorMode;
pub const HelpConfig = argparse.HelpConfig;
pub const helpArg = argparse.helpArg;
pub const generateHelp = argparse.generateHelp;
pub const generateUsage = argparse.generateUsage;
pub const validateArgsComptime = argparse.validateArgsComptime;

test {
    _ = @import("command_test.zig");
    _ = @import("parser_test.zig");
    _ = @import("builder_test.zig");
}
