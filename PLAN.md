# Zig argparse - Design Plan

## Vision

Build a command-line argument parser for Zig that rivals Rust's `clap` in ergonomics and features, while leveraging Zig's unique strengths (comptime, zero-allocation by default, type safety).

## Core Design Principles

1. **Type-safe API** - Use Zig's type system to catch errors at compile time
2. **Comptime-powered** - Define arguments with compile-time validation, generate help at comptime
3. **Zero-allocation default** - Parse without heap allocations in common cases
4. **Ergonomic** - Clean, declarative API for defining CLI interfaces
5. **Clear errors** - Helpful error messages for invalid arguments
6. **Extensible** - Support custom types, validators, and help formatting

## Architecture

### Module Structure

```
src/
├── root.zig           # Public API, re-exports
├── argparse.zig      # Core Parser and Command types
├── arg.zig            # Argument definition and type handling
├── parser.zig         # Actual parsing logic
├── error.zig          # Error types and formatting
└── help.zig           # Help generation
examples/              # Usage examples
tests/                 # Comprehensive tests
```

### Core Data Structures

#### Argument Types
```zig
pub const ArgKind = enum {
    flag,        // --verbose, -v (boolean)
    option,      // --file <path>, -f <path> (takes value)
    positional,  // <file> (no prefix, ordered)
    count,       // -vvv (count occurrences)
};

pub const Arg = struct {
    // Names
    name: []const u8,
    short: ?u8 = null,        // Single char: 'v'
    long: ?[]const u8 = null, // Multi-char: "verbose"

    // Metadata
    help: []const u8 = "",
    kind: ArgKind,

    // Value handling
    default: ?Value = null,
    required: bool = false,
    // For positionals: position in argument list
    position: ?usize = null,

    // Validation (optional)
    validator: ?fn ([]const u8) anyerror!void = null,

    // Value type
    value_type: ValueType,
};

pub const ValueType = enum {
    bool,
    string,
    int,
    float,
};

pub const Value = union(ValueType) {
    bool: bool,
    string: []const u8,
    int: i64,
    float: f64,
};
```

#### Parser
```zig
pub const Parser = struct {
    allocator: std.mem.Allocator,
    args: []const Arg,
    parsed: ParsedValues,

    pub fn init(allocator: std.mem.Allocator, args: []const Arg) Parser;
    pub fn parse(self: *Parser, argv: []const []const u8) !ParsedValues;
    pub fn get(self: *Parser, comptime name: []const u8, comptime T: type) !T;
    pub fn help(self: *Parser) []const u8;
};
```

#### Parsed Values (zero-copy)
```zig
pub const ParsedValues = struct {
    flags: std.StringHashMap(bool),
    options: std.StringHashMap([]const u8),
    positionals: std.ArrayList([]const u8),
    counts: std.StringHashMap(usize),

    // Convenience getters with type conversion
    pub fn getFlag(self: *const ParsedValues, name: []const u8) bool;
    pub fn getOption(self: *const ParsedValues, name: []const u8) ?[]const u8;
    pub fn getRequiredOption(self: *const ParsedValues, name: []const u8) error{MissingRequired}![]const u8;
    pub fn getIntOption(self: *const ParsedValues, name: []const u8) !i64;
};
```

#### Commands (subcommands)
```zig
pub const Command = struct {
    name: []const u8,
    args: []const Arg,
    subcommands: []const Command = &.{},
    help: []const u8 = "",
    handler: ?fn (*Parser, []const []const u8) anyerror!void = null,
};
```

### Error Handling

```zig
pub const Error = error{
    UnknownArgument,
    MissingValue,
    MissingRequired,
    InvalidValue,
    DuplicateArgument,
    TooManyPositionals,
    // ...
};
```

## API Design

### Simple Example

```zig
const argparse = @import("argparse");

pub fn main() !void {
    const gpa = std.heap.page_allocator;

    const args = [_]argparse.Arg{
        .{
            .name = "verbose",
            .short = 'v',
            .long = "verbose",
            .kind = .flag,
            .help = "Enable verbose output",
        },
        .{
            .name = "count",
            .short = 'c',
            .long = "count",
            .kind = .option,
            .value_type = .int,
            .help = "Number of items",
            .required = true,
        },
        .{
            .name = "file",
            .kind = .positional,
            .value_type = .string,
            .help = "Input file to process",
        },
    };

    var parser = argparse.Parser.init(gpa, &args);
    defer parser.deinit();

    try parser.parse(std.os.argv);

    const verbose = parser.getFlag("verbose");
    const count = try parser.getInt("count");
    const file = parser.getPositional("file") orelse "-";

    std.debug.print("Processing {d} items from {s}\n", .{count, file});
}
```

### Builder Pattern (Alternative)

```zig
const parser = argparse.Builder.init(gpa)
    .addFlag("verbose", 'v', "verbose", "Enable verbose output")
    .addOption("count", 'c', "count", .int, "Number of items", .required)
    .addPositional("file", .string, "Input file")
    .build();
defer parser.deinit();

try parser.parse(std.os.argv);
```

### Subcommands Example

```zig
const app = argparse.Command{
    .name = "git",
    .help = "The stupid content tracker",
    .subcommands = &.{
        .{
            .name = "clone",
            .help = "Clone a repository",
            .args = &.{
                .{ .name = "url", .kind = .positional, .value_type = .string },
            },
        },
        .{
            .name = "commit",
            .help = "Record changes",
            .args = &.{
                .{ .name = "message", .long = "message", .short = 'm', .kind = .option },
            },
        },
    },
};

try app.run(gpa, std.os.argv);
```

## Implementation Phases

### Phase 1: Core Foundation (MVP)
**Target:** Basic flag and option parsing

- [ ] Create module structure (argparse.zig, arg.zig, parser.zig)
- [ ] Define Arg and ArgKind types
- [ ] Implement basic parser for flags (--flag, -f)
- [ ] Implement option parsing (--opt=value, --opt value)
- [ ] Add ParsedValues storage
- [ ] Error handling basics (unknown arg, missing value)
- [ ] Tests: simple flag/option cases

### Phase 2: Value Types & Conversion
**Target:** Type-safe value access

- [ ] Implement ValueType enum
- [ ] Add type conversion (string → int, string → bool)
- [ ] Implement get[T] with type checking
- [ ] Add default value support
- [ ] Required argument validation
- [ ] Tests: type conversion, defaults, required

### Phase 3: Positional Arguments
**Target:** Handle positional args and mixing with flags

- [ ] Positional argument type
- [ ] Ordering logic (flags vs positionals)
- [ ] Positional value extraction
- [ ] Mixed parsing (flags before/after positionals)
- [ ] Tests: positionals, mixed args

### Phase 4: Help Generation
**Target:** Auto-generated --help

- [ ] Help text formatting
- [ ] Argument description display
- [ ] Group related arguments
- [ ] Auto-add --help flag
- [ ] Tests: help output

### Phase 5: Advanced Features
**Target:** Count args, validators, aliases

- [ ] Count arguments (-vvv)
- [ ] Custom validators
- [ ] Argument aliases
- [ ] Multiple value support (--file=a --file=b)
- [ ] Tests: counts, validators, multi-values

### Phase 6: Subcommands
**Target:** Git-style subcommands

- [ ] Command type
- [ ] Subcommand dispatch
- [ ] Nested subcommands
- [ ] Per-subcommand help
- [ ] Tests: basic subcommands, nesting

### Phase 7: Polish & Ergonomics
**Target:** Production-ready API

- [ ] Builder pattern API
- [ ] Better error messages
- [ ] Color output for errors/help
- [ ] Validation at comptime
- [ ] Documentation
- [ ] Performance benchmarks

### Phase 8: Examples & Documentation
**Target:** Easy onboarding

- [ ] Simple example
- [ ] Complex example with subcommands
- [ ] Builder pattern example
- [ ] README with API docs
- [ ] Migration guide from argparse libraries

## Key Design Decisions

### 1. Zero-Allocation by Default
- Parse into temporary structs
- String slices point directly to argv
- Optional heap allocation for complex cases (subcommands, multi-values)

### 2. Comptime String Interning
- Argument names checked at comptime
- Type mismatches caught at compile time
- Help generation partially at comptime

### 3. Error Sets
- Custom error types for each failure mode
- Clear error messages with context
- Suggestion for typos (argumetn → argument?)

### 4. Flexible API
- Both struct-based and builder APIs
- Easy to start simple, scale up
- No dependencies outside stdlib

## Testing Strategy

### Unit Tests
- Each module: 80%+ coverage
- Edge cases: empty input, malformed args, unicode

### Integration Tests
- Full parse cycles
- Real-world CLI examples (git-style tools)

### Property Tests (fuzz)
- Random argument sequences
- Boundary conditions

### Benchmark Tests
- Parse performance (should be fast!)
- Memory usage (track allocations)

## Open Questions

1. **Multi-value arguments**: Support natively? `--file=a --file=b` → `[]const []const u8`?
2. **Exclusive groups**: Enforce `--format=json OR --format=xml`?
3. **Dependent arguments**: `--from` requires `--to`?
4. **Environment variable fallback**: Read from `ENV_VAR` if not provided?
5. **Config file support**: Read from `config.toml` as additional source?
6. **Shell completion**: Generate bash/zsh/fish completion scripts?

## Performance Targets

- Parse 1000 arguments in < 1ms (no alloc)
- Parse 1000 arguments in < 5ms (with alloc)
- Help generation: < 100μs at comptime
- Binary size impact: < 20KB optimized

## Success Metrics

- API passes "looks like Zig" review
- Zero external dependencies
- Comprehensive test coverage
- Clear documentation with examples
- Competitive performance vs similar libs

---

*Next: Start Phase 1 implementation*
