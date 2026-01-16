# argparse

Type-safe argument parsing for Zig with feature parity to Rust's clap.

## Status: 🚧 Work In Progress

This is an early-stage implementation. Core types and value conversion are implemented. Parser engine and help generation are in progress.

## Goals

- **Type-safe**: Comptime-driven, compile-time guarantees
- **Zero-cost**: Minimal runtime overhead
- **Feature parity with clap**: All the features you expect
- **Ergonomic**: Struct-based API with optional builder pattern

## Planned Features

- [x] Core type system (ArgKind, ArgSpec, Meta, ParseResult)
- [x] Value conversion (int, float, bool, string, enum, custom)
- [x] Error handling with suggestions
- [ ] Parser engine
- [ ] Subcommands (verbs)
- [ ] Help generation
- [ ] Environment variable support
- [ ] Validation framework
- [ ] Argument groups (required, exclusive)
- [ ] Shell completion (bash, zsh, fish, powershell)
- [ ] Builder API
- [ ] Derive-style helpers

## Example Usage (Planned)

```zig
const std = @import("std");
const argparse = @import("argparse");

const Options = struct {
    output: ?[:0]const u8 = null,
    verbose: bool = false,
    count: usize = 0,

    pub const shorthands = .{
        .o = "output",
        .v = "verbose",
        .c = "count",
    };

    pub const meta = .{
        .name = "myapp",
        .version = "1.0.0",
        .about = "Does cool things",
        .option_docs = .{
            .output = "Output file path",
            .verbose = "Enable verbose output",
            .count = "Number of iterations",
        },
    };
};

pub fn main() !void {
    const gpa = std.heap.page_allocator;
    const result = try argparse.parseForCurrentProcess(Options, gpa);
    defer result.deinit();

    if (result.options.verbose) {
        std.debug.print("Verbose mode\n", .{});
    }

    if (result.options.output) |path| {
        std.debug.print("Output: {s}\n", .{path});
    }

    for (result.positionals) |arg| {
        std.debug.print("Arg: {s}\n", .{arg});
    }
}
```

## Subcommands (Planned)

```zig
const Options = struct {
    debug: bool = false,
};

const Verb = union(enum) {
    build: struct {
        release: bool = false,
        target: ?[:0]const u8 = null,
    },
    test: struct {
        filter: ?[:0]const u8 = null,
        verbose: bool = false,
    },
};

pub fn main() !void {
    const gpa = std.heap.page_allocator;
    const result = try argparse.parseWithVerbForCurrentProcess(Options, Verb, gpa);
    defer result.deinit();

    if (result.verb) |verb| {
        switch (verb) {
            .build => |opts| { /* ... */ },
            .test => |opts| { /* ... */ },
        }
    }
}
```

## Documentation

- [PLAN.md](PLAN.md) - Detailed implementation plan
- [SPEC.md](SPEC.md) - Technical specification
- [MILESTONES.md](MILESTONES.md) - Implementation milestones

## Development

```bash
# Run tests
zig build test

# Run the example executable
zig build run

# Build the library
zig build
```

## License

MIT

## Acknowledgments

- Inspired by Rust's [clap](https://github.com/clap-rs/clap)
- Uses patterns from [zig-args](https://github.com/ikskuh/zig-args)
