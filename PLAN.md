# Argparse: Zig Argument Parser with Clap Feature Parity

## Vision
Type-safe, zero-cost, comptime-driven argument parsing in Zig. Feature parity with Rust's clap.

---

## Phase 1: Core Foundation (Week 1-2)

### 1.1 Architecture Setup
```
src/
├── root.zig           # Public API, exports
├── parser.zig         # Main parsing engine
├── types.zig          # Argument types, specs
├── value.zig          # Value parsing/conversion
├── error.zig          # Error types, handling
├── help.zig           # Help generation
└── internal/
    ├── allocator.zig  # Arena wrapper
    └── utils.zig      # Comptime utilities
```

### 1.2 Core Types

**Argument Spec:**
```zig
pub const ArgKind = enum {
    flag,           // bool, no value
    option,         // takes value
    positional,     // positional arg
    multiple,       // multiple values
};

pub const ArgSpec = struct {
    name: []const u8,
    kind: ArgKind,
    type: type,
    default: ?const anytype,
    required: bool,
    help: ?[]const u8,
    short: ?u8,
    long: ?[]const u8,
    env: ?[]const u8,
    validator: ?*const fn (anytype) anyerror!void,
    // ... more
};
```

**Parse Result:**
```zig
pub fn ParseResult(comptime Spec: type) type {
    return struct {
        arena: std.heap.ArenaAllocator,
        options: Spec,
        positionals: [][:0]const u8,
        raw_args: ?[][]const u8,  // After --
        executable: ?[:0]const u8,
    };
}
```

### 1.3 Value Conversion Engine
- Int parsing with suffixes (k, M, G, Ki, Mi, Gi)
- Float parsing
- Bool parsing (true/false, yes/no, t/f, y/n, 1/0)
- String parsing
- Enum parsing
- Custom type parsing via `parse()` fn

### 1.4 Basic Parser
- Parse long opts: `--name=value`, `--name value`
- Parse short opts: `-abc`, `-a value`
- Parse positionals
- Handle `--` terminator
- Error accumulation (not fail-fast)

**Deliverables:**
- `Parser` type with `parse()` method
- Basic type conversions
- Tests for all conversions
- Error types

---

## Phase 2: Subcommands & Verbs (Week 2-3)

### 2.1 Subcommand Architecture
```zig
pub const Verb = union(enum) {
    add: AddOptions,
    commit: CommitOptions,
    push: PushOptions,
    // ...
};
```

### 2.2 Verb Parsing
- Detect verb as first positional
- Parse verb-specific options
- Global options (before/after verb)
- Nested subcommands (verbs within verbs)

### 2.3 Verb Metadata
```zig
pub const VerbMeta = struct {
    help: []const u8,
    options: type,
};
```

**Deliverables:**
- Verb parsing with tagged unions
- Global + verb-specific option handling
- Tests for nested verbs

---

## Phase 3: Advanced Argument Features (Week 3-4)

### 3.1 Multiple Values
- `--file a.txt b.txt c.txt` → `[]const []const u8`
- Counted flags: `-vvv` → count 3

### 3.2 Argument Groups
- Required groups (one of required)
- Exclusive groups (can't use together)
- All-required groups

### 3.3 Validation Rules
```zig
pub const Validator = struct {
    min: ?usize,
    max: ?usize,
    choices: ?[]const []const u8,
    pattern: ?[]const u8,  // regex
    custom: ?*const fn (anytype) anyerror!void,
};
```

### 3.4 Conflicts & Requires
```zig
pub const Rule = struct {
    kind: enum { conflict, require },
    args: []const []const u8,
};
```

**Deliverables:**
- Multiple value handling
- Argument groups
- Validation framework
- Conflict/require rules

---

## Phase 4: Help & Documentation (Week 4-5)

### 4.1 Help Generator
```zig
pub fn generateHelp(comptime Spec: type, writer: anytype) !void;
```

Features:
- Usage line with required args
- Options section (short, long, description)
- Subcommands section
- Examples section
- Wrapping at configurable width

### 4.2 Help Metadata
```zig
pub const Meta = struct {
    name: []const u8 = "program",
    version: []const u8 = "0.0.0",
    about: ?[]const u8 = null,
    author: ?[]const u8 = null,
    usage_summary: ?[]const u8 = null,
    long_about: ?[]const u8 = null,
    examples: ?[]const Example = null,
    option_docs: OptionDocs,
    verb_docs: ?VerbDocs = null,
    wrap_width: usize = 80,
};

pub const OptionDocs = struct {
    // Field names → help text
};

pub const Example = struct {
    description: []const u8,
    command: []const u8,
};
```

### 4.3 Auto Version Flag
- `--version`, `-V` automatic support
- Uses `meta.version`

### 4.4 Styling (Optional, Phase 6)
- Color support
- Bold/underline
- Terminal detection

**Deliverables:**
- Help generator with sections
- Usage line generation
- Auto `--help`, `--version`
- Pretty formatting

---

## Phase 5: Environment Variables (Week 5)

### 5.1 Env Var Support
- Fallback when arg not provided
- Type conversion from env strings
- Prefix support (e.g., `MY_APP_`)

### 5.2 Priority
1. CLI arg (highest)
2. Env var
3. Default (lowest)

**Deliverables:**
- Env var lookup
- Priority handling
- Type-safe env parsing

---

## Phase 6: Shell Completion (Week 6)

### 6.1 Completion Generator
```zig
pub fn generateCompletion(comptime Spec: type, shell: Shell, writer: anytype) !void;
```

Shells:
- Bash
- Zsh
- Fish
- PowerShell

### 6.2 Completion Data
- Dynamic arg completion
- File completion
- Choice completion (enums)
- Subcommand completion

**Deliverables:**
- Completion generators for 4 shells
- Dynamic arg hooks
- Tests

---

## Phase 7: Advanced Features (Week 7)

### 7.1 Raw Mode
- Stop parsing at specific arg
- Pass-through mode

### 7.2 Value Enums
- Restrict to enum variants
- Auto-choices from enum

### 7.3 Custom Parsers
```zig
pub const CustomType = struct {
    value: u32,

    pub fn parse(str: []const u8) !CustomType {
        // Custom parsing logic
    }
};
```

### 7.4 Last/Next Arguments
- Consume next N arguments
- Consume remaining arguments

### 7.5 Hidden Arguments
- Don't show in help
- Useful for internal/debug args

**Deliverables:**
- Raw parsing mode
- Custom type parsing
- Hidden arg support

---

## Phase 8: Developer Experience (Week 8)

### 8.1 Builder Pattern (Alternative API)
```zig
const parser = argparse.builder(args)
    .addOption("--output", .string, .{ .short = 'o' })
    .addFlag("--verbose", .{ .short = 'v' })
    .addPositional("input")
    .build();
```

### 8.2 Derive Macro Emulation (Comptime)
```zig
pub fn deriveParser(comptime Config: type) type {
    // Generate parser from struct
}
```

### 8.3 Rich Errors
- Did you mean? suggestions
- Colorized errors
- Context in error messages

### 8.4 Testing Utilities
- Test helpers
- Mock arg iterators

**Deliverables:**
- Builder API
- Derive-style comptime helper
- Rich error messages
- Test utilities

---

## API Design Examples

### Basic Usage
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

    // Handle positionals
    for (result.positionals) |arg| {
        std.debug.print("Arg: {s}\n", .{arg});
    }
}
```

### Subcommands
```zig
const Options = struct {
    debug: bool = false,

    pub const meta = .{ .about = "Global options" };
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
    run: struct {
        args: [][:0]const u8,
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
            .run => |opts| { /* ... */ },
        }
    }
}
```

### Validation
```zig
const Options = struct {
    port: u16 = 8080,
    size: usize = 0,
    mode: enum { fast, slow, balanced } = .balanced,

    pub const validators = .{
        .port = &validatePort,
        .size = &validateSize,
    };
};

fn validatePort(port: u16) !void {
    if (port == 0) return error.PortCannotBeZero;
    if (port < 1024) return error.ReservedPort;
}

fn validateSize(size: usize) !void {
    if (size == 0 or size > 1024 * 1024) {
        return error.InvalidSize;
    }
}
```

---

## File Structure (Final)

```
argparse/
├── src/
│   ├── root.zig              # Public API exports
│   ├── parser.zig            # Main Parser type, parse methods
│   ├── types.zig             # ArgSpec, ArgKind, Meta types
│   ├── value.zig             # Value parsing, type conversion
│   ├── error.zig             # Error types, ErrorCollection
│   ├── help.zig              # Help generation
│   ├── completion.zig       # Shell completion generators
│   ├── validator.zig         # Validation framework
│   ├── internal/
│   │   ├── allocator.zig     # Arena utilities
│   │   ├── utils.zig         # Comptime helpers
│   │   └── string.zig        # String manipulation
│   └── api/
│       ├── derive.zig        # Derive-style API helpers
│       └── builder.zig       # Builder API
├── examples/
│   ├── basic.zig
│   ├── subcommands.zig
│   ├── validation.zig
│   └── advanced.zig
├── tests/
│   ├── parser_tests.zig
│   ├── value_tests.zig
│   ├── help_tests.zig
│   └── integration_tests.zig
├── README.md
├── CHANGELOG.md
└── PLAN.md
```

---

## Testing Strategy

1. **Unit Tests**: Each module has comprehensive tests
2. **Integration Tests**: End-to-end parsing scenarios
3. **Property Tests**: Fuzzing for edge cases
4. **Examples as Tests**: All examples run as tests
5. **Cross-Shell Tests**: Completion scripts validated

---

## Compatibility

- **Zig 0.15** minimum
- **No external dependencies** (std only)
- **Cross-platform**: Linux, macOS, Windows, Wasm

---

## Success Metrics

- ✅ All clap features implemented
- ✅ Zero allocations during parsing (except arena)
- ✅ Compile-time type safety
- ✅ Great error messages
- ✅ Comprehensive tests (>90% coverage)
- ✅ Full documentation
- ✅ Rich examples

---

## Notes

- zig-args reference provides syntax patterns but we're extending significantly
- Focus on type safety and compile-time guarantees
- Performance: comptime heavy, runtime light
- API ergonomics: both struct-based and builder APIs
