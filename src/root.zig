//! argparse - Type-safe argument parsing for Zig with feature parity to Rust's clap
//!
//! # Basic Usage
//!
//! ```zig
//! const Options = struct {
//!     output: ?[:0]const u8 = null,
//!     verbose: bool = false,
//!     count: usize = 0,
//!
//!     pub const shorthands = .{
//!         .o = "output",
//!         .v = "verbose",
//!         .c = "count",
//!     };
//!
//!     pub const meta = .{
//!         .name = "myapp",
//!         .version = "1.0.0",
//!         .about = "Does cool things",
//!         .option_docs = .{
//!             .output = "Output file path",
//!             .verbose = "Enable verbose output",
//!             .count = "Number of iterations",
//!         },
//!     };
//! };
//!
//! pub fn main() !void {
//!     const gpa = std.heap.page_allocator;
//!     const result = try argparse.parseForCurrentProcess(Options, gpa);
//!     defer result.deinit();
//!
//!     if (result.options.verbose) {
//!         std.debug.print("Verbose mode\n", .{});
//!     }
//! }
//! ```
//!
//! # Subcommands
//!
//! ```zig
//! const Options = struct {
//!     debug: bool = false,
//! };
//!
//! const Verb = union(enum) {
//!     build: struct {
//!         release: bool = false,
//!     },
//!     test: struct {
//!         filter: ?[:0]const u8 = null,
//!     },
//! };
//!
//! const result = try argparse.parseWithVerbForCurrentProcess(Options, Verb, gpa);
//! if (result.verb) |verb| {
//!     switch (verb) {
//!         .build => |opts| { /* ... */ },
//!         .test => |opts| { /* ... */ },
//!     }
//! }
//! ```

const std = @import("std");

pub const types = @import("types.zig");
pub const value = @import("value.zig");
pub const error_module = @import("errors.zig");

// Re-export commonly used types
pub const ArgKind = types.ArgKind;
pub const ArgSpec = types.ArgSpec;
pub const Meta = types.Meta;
pub const Example = types.Example;
pub const ParseResult = types.ParseResult;
pub const isReserved = types.isReserved;

pub const ParseError = error_module.ParseError;
pub const ErrorKind = error_module.ErrorKind;
pub const ErrorCollection = error_module.ErrorCollection;

pub const parseInt = value.parseInt;
pub const parseFloat = value.parseFloat;
pub const parseBool = value.parseBool;
pub const parseEnum = value.parseEnum;
pub const requiresArg = value.requiresArg;
pub const convertValue = value.convertValue;

// TODO: Add parser.zig when implemented
// pub const Parser = @import("parser.zig").Parser;

// TODO: Add help.zig when implemented
// pub const generateHelp = @import("help.zig").generateHelp;
// pub const printHelp = @import("help.zig").printHelp;

// TODO: Add parse functions when parser.zig is implemented
// pub fn parseForCurrentProcess(comptime Spec: type, allocator: std.mem.Allocator) !ParseResult(Spec, null) { ... }
// pub fn parseWithVerbForCurrentProcess(comptime Spec: type, comptime Verb: type, allocator: std.mem.Allocator) !ParseResult(Spec, Verb) { ... }

test {
    std.testing.refAllDecls(@This());
    std.testing.refAllDecls(types);
    std.testing.refAllDecls(value);
    std.testing.refAllDecls(error_module);
}
