# argparse - Agent Notes

## Project

Zig argument parsing library with clap feature parity.

Owner: Gary Murray (@garymjr, <garymjr@gmail.com>)

---

## Build / Lint / Test Commands

### Build System
Uses Zig's built-in build system (`build.zig`).

```bash
# Build the project
zig build

# Run tests
zig build test

# Run the example executable
zig build run

# Run with args (e.g., for testing)
zig build run -- --help

# Clean build cache
rm -rf .zig-cache
```

### Running Individual Tests
Use Zig's built-in test filtering:

```bash
# Run specific test by name (direct zig test)
zig test src/value.zig --test-filter parseInt

# Run all tests matching pattern
zig test src/ --test-filter "parse"

# Run tests in specific module
zig test src/value.zig

# Run tests in specific module with filter
zig test src/value.zig --test-filter parseInt

# Run all tests via build system
zig build test

# NOTE: zig build doesn't support --test-filter
# Use direct zig test for filtering
```

### Code Formatting

```bash
# Check formatting (dry-run)
zig fmt --check src/

# Format all files
zig fmt src/

# Format specific file
zig fmt src/value.zig

# Watch mode (requires external tool)
# (Not configured - add if needed)
```

### Build Options

```bash
# List all available build steps
zig build --help

# Change optimization mode
zig build -Doptimize=ReleaseFast test
zig build -Doptimize=ReleaseSmall test
zig build -Doptimize=ReleaseSafe test

# Change target
zig build -Dtarget=x86_64-linux test

# Verbose build output
zig build -femit-asm=-
```

---

## Code Style Guidelines

### Imports and Module System

**Pattern:** All files use standard Zig imports. No external dependencies.

```zig
// Standard library import (always at top)
const std = @import("std");

// Local module imports (relative paths)
const types = @import("types.zig");
const value = @import("value.zig");
const error_module = @import("errors.zig");
const internal_utils = @import("internal/utils.zig");

// Re-export commonly used types for cleaner API
pub const ArgKind = types.ArgKind;
pub const ArgSpec = types.ArgSpec;
```

**File extensions:** `.zig` for all source files.

### Formatting Conventions

**Indentation:** 4 spaces (Zig standard - enforced by `zig fmt`)

```zig
// No tabs, use spaces
pub fn example() void {
    if (condition) {
        // 4 space indent
        doSomething();
    }
}
```

**Quotes:** Double quotes for strings

```zig
const name = "program";
const path = "/path/to/file";
```

**Semicolons:** Required at end of every statement

```zig
const value = 42;
return result;
```

**Comments:**

```zig
//! Module-level documentation (at top of file)

/// Public function/struct documentation
pub fn parse() !void { }

// Single-line inline comment
```

### Type Usage

**Comptime Types:** Heavy use of comptime for type safety

```zig
// Generic functions with comptime type parameter
pub fn parseInt(comptime T: type, str: []const u8) !T {
    // T is known at compile time
    const max: T = std.math.maxInt(T);
}

// Comptime struct generation
pub fn ParseResult(comptime Spec: type) type {
    return struct {
        options: Spec,
        // ...
    };
}
```

**Type Inference:** `@as` for explicit type casting in tests

```zig
try std.testing.expectEqual(@as(i32, 42), try parseInt(i32, "42"));
try std.testing.expectEqual(@as(usize, 0), list.items.len);
```

**Error Union Types:** Use `!T` for error unions

```zig
pub fn parseInt(comptime T: type, str: []const u8) !T {
    // Returns either T or an error
    if (error) return error.InvalidFormat;
    return value;
}
```

**Optional Types:** Use `?T` for optionals

```zig
const output: ?[:0]const u8 = null;
const short: ?u8 = null;

if (output) |o| {
    // o is non-null here
}
```

### Naming Conventions

**Files:** `snake_case.zig`

```
src/
├── root.zig
├── types.zig
├── value.zig
├── errors.zig
└── internal/
    └── utils.zig
```

**Types:** `PascalCase`

```zig
pub const ArgKind = enum { };
pub const ArgSpec = struct { };
pub const ErrorCollection = struct { };
pub const ParseResult = type;
```

**Functions:** `camelCase` (lowercase first letter for public functions)

```zig
pub fn parseInt(comptime T: type, str: []const u8) !T { }
pub fn parseBool(str: []const u8) !bool { }
fn helperFunction(value: u32) void { }
```

**Variables:** `camelCase`

```zig
const bufferSize: usize = 1024;
var multiplier: i32 = 1;
const argList: [][:0]const u8 = undefined;
```

**Constants:** `SCREAMING_SNAKE_CASE` or `PascalCase` (context-dependent)

```zig
const MAX_BUFFER_SIZE: usize = 4096;
const DefaultOptions = struct { };
```

**Enum Fields:** `lowercase_snake_case`

```zig
pub const ArgKind = enum {
    flag,
    option,
    positional,
    multiple,
};
```

**Struct Fields:** `snake_case`

```zig
pub const ArgSpec = struct {
    name: []const u8,
    kind: ArgKind,
    long: ?[]const u8 = null,
};
```

### Error Handling Patterns

**Error Return Types:** Use `!T` syntax

```zig
pub fn parseInt(comptime T: type, str: []const u8) !T {
    return try std.fmt.parseInt(T, str, 0);
}
```

**Try-Catch:** Use `try` for error propagation (preferred)

```zig
pub fn example() !void {
    const value = try parseInt(i32, "42"); // Propagates error
    const result = try process(value);
}
```

**Custom Errors:** Use `error.{Name}` syntax

```zig
pub fn parseInt(comptime T: type, str: []const u8) !T {
    if (value > max) return error.Overflow;
    return value;
}
```

**Error Collections:** Centralized error handling with `ErrorCollection`

```zig
const errors = ErrorCollection.init(allocator);
defer errors.deinit();

try errors.add(ParseError{
    .option = "port",
    .kind = .invalid_value,
});

if (errors.hasErrors()) {
    return error.InvalidArguments;
}
```

### Testing Conventions

**Test Location:** Tests embedded in source files after functions

```zig
pub fn parseInt(comptime T: type, str: []const u8) !T {
    // implementation
}

test "parseInt" {
    try std.testing.expectEqual(@as(i32, 42), try parseInt(i32, "42"));
    try std.testing.expectEqual(@as(i32, 6000), try parseInt(i32, "6k"));
    try std.testing.expectError(error.Overflow, parseInt(i2, "1m"));
}
```

**Test Assertions:**

```zig
// Equality
try std.testing.expectEqual(expected, actual);

// Error expectation
try std.testing.expectError(error.SomeError, mightFail());

// String equality
try std.testing.expectEqualStrings("hello", str);

// Boolean
try std.testing.expect(true, condition);
```

**Test Naming:** Match function name, lowercase

```zig
pub fn parseInt(comptime T: type, str: []const u8) !T { }
test "parseInt" { }  // Matches

pub fn parseBool(str: []const u8) !bool { }
test "parseBool" { }  // Matches
```

---

## Architecture Overview

### Project Structure

```
argparse/
├── build.zig              # Build configuration
├── build.zig.zon           # Package manifest (dependencies, version)
├── src/
│   ├── root.zig            # Public API, exports all types
│   ├── types.zig           # Core types (ArgKind, ArgSpec, Meta)
│   ├── value.zig           # Type conversion (int, float, bool, enum)
│   ├── errors.zig          # Error handling (ParseError, ErrorCollection)
│   ├── main.zig            # Example CLI entry point
│   └── internal/
│       └── utils.zig       # Comptime helpers (inferArgKind, buildArgSpecs)
├── examples/               # Usage examples (planned)
├── tests/                 # Integration tests (planned)
└── .zig-cache/            # Zig build cache (gitignored)
```

### Main Entry Points

**`src/root.zig`** - Public API module
- Re-exports all commonly used types
- Defines top-level functions when parser is implemented
- Contains documentation and usage examples

**`src/types.zig`** - Core type definitions
- `ArgKind` enum (flag, option, positional, multiple, count)
- `ArgSpec` struct (specification for arguments)
- `Meta` struct (metadata for help/version)
- `ParseResult` type (result of parsing)
- `isReserved()` function (identifies reserved field names)

**`src/value.zig`** - Value conversion engine
- `parseInt()` - with k/M/G suffix support
- `parseFloat()` - floating point parsing
- `parseBool()` - multiple formats (true/false, yes/no, t/f, y/n)
- `parseEnum()` - enum string parsing
- `convertValue()` - generic value converter
- `requiresArg()` - checks if type needs a value

**`src/errors.zig`** - Error handling
- `ParseError` struct (option name + ErrorKind)
- `ErrorKind` union enum with associated data
- `ErrorCollection` struct (accumulate multiple errors)
- `editDistance()` - Levenshtein distance for suggestions

**`src/internal/utils.zig`** - Comptime utilities
- `inferArgKind()` - deduce ArgKind from type
- `getDefaultValue()` - get default for a type
- `getHelpText()` - extract help from meta struct
- `getShortHand()` - get short flag from shorthands struct
- `buildArgSpecs()` - comptime build spec array from struct
- `findSpecByLong()` / `findSpecByShort()` - lookup helpers

### Key Abstractions

**Comptime Spec Generation:**
```zig
// User defines a struct with fields
const Options = struct {
    output: ?[:0]const u8 = null,
    verbose: bool = false,
    pub const meta = .{ .name = "myapp" };
};

// Library builds ArgSpec array at comptime
const specs = comptime buildArgSpecs(Options);
```

**Arena Allocation Pattern:**
```zig
// All parsed strings from arena
const result = ParseResult{
    .arena = std.heap.ArenaAllocator.init(allocator),
    .options = Options{},
    // ... strings allocated from arena.allocator()
};

defer result.deinit(); // Cleans everything at once
```

**Type-Driven Parsing:**
- Field type determines argument kind (`bool` → flag, `?T` → option, etc.)
- Shorthands mapping via `pub const shorthands = .{ .v = "verbose" }`
- Help docs via `pub const meta = .{ .option_docs = .{ .verbose = "..." } }`

---

## Important Patterns & Conventions

### Reserved Field Names

Structs used for arg specs reserve these field names:

```zig
const Options = struct {
    // User-defined fields
    output: ?[:0]const u8 = null,
    verbose: bool = false,

    // RESERVED - these are NOT parsed as args
    pub const meta = .{ .name = "myapp" };
    pub const shorthands = .{ .v = "verbose" };
    pub const validators = .{ .port = &validatePort };
    pub const groups = .{ .io = .{ .exclusive = true } };
};
```

### Namespace Collision Avoidance

Use module prefixes for imported types:

```zig
const types = @import("types.zig");

// Good: Clear module prefix
return types.ArgKind.flag;

// Bad: Could collide if other module has same name
pub const ArgKind = @import("types.zig").ArgKind;
```

### Comptime Type Safety

Use `comptime` and `@typeInfo` extensively:

```zig
pub fn inferArgKind(comptime T: type) types.ArgKind {
    return switch (@typeInfo(T)) {
        .bool => .flag,
        .optional => |opt| inferArgKind(opt.child),
        .pointer => |ptr| {
            if (ptr.size == .Slice and ptr.child == u8) {
                return .option;
            }
            @compileError("Unsupported pointer type: " ++ @typeName(T));
        },
        else => @compileError("Unsupported type: " ++ @typeName(T)),
    };
}
```

### Sentinel Strings

Use `[:0]const u8` for null-terminated strings:

```zig
const name: [:0]const u8 = null;  // Null-terminated
const data: []const u8 = null;     // Regular slice
```

---

## Dependencies

**None** - Uses only Zig standard library (`std`).

---

## Development Workflow

1. **Make changes** to source files in `src/`
2. **Run tests** to verify: `zig build test`
3. **Format code**: `zig fmt src/`
4. **Run specific tests** during development: `zig build test --test-filter test_name`
5. **Check all tests pass** before committing

---

## Extension Points

### Custom Type Parsing

Add custom type support by implementing `parse()`:

```zig
const CustomType = struct {
    value: u32,

    pub fn parse(str: []const u8) !CustomType {
        return CustomType{
            .value = try std.fmt.parseUnsigned(u32, str, 10),
        };
    }
};
```

### Custom Enum Parsing

Add `parse()` method to enum:

```zig
const Mode = enum {
    fast,
    slow,
    balanced,

    pub fn parse(str: []const u8) !Mode {
        if (std.mem.eql(u8, str, "fast")) return .fast;
        return error.InvalidMode;
    }
};
```

### Module Exports

Add new public types to `src/root.zig`:

```zig
pub const newType = @import("new_module.zig").NewType;
```

---

## Key Technical Notes

### ArrayList API Change in Zig 0.15

**CRITICAL**: Zig 0.15 changed `std.ArrayList` API:

```zig
// OLD (doesn't work in 0.15)
var list = std.ArrayList(T).init(allocator);
defer list.deinit();

// NEW (required in 0.15)
// Option 1: Empty list (no pre-allocated capacity)
var list = std.ArrayList(T).empty;
defer list.deinit(allocator);

// Option 2: With initial capacity
var list = try std.ArrayList(T).initCapacity(allocator, 10);
defer list.deinit(allocator);
```

**Key changes:**
1. `.init(allocator)` → `.empty` or `.initCapacity(allocator, n)`
2. `.deinit()` → `.deinit(allocator)` - now requires allocator parameter

**Common pattern for this project:**
```zig
const ErrorCollection = struct {
    list: std.ArrayList(ParseError),
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator) Self {
        return Self{
            .list = std.ArrayList(ParseError).empty, // NOT .init(allocator)
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *Self) void {
        self.list.deinit(self.allocator); // MUST pass allocator
        // ... other cleanup
    }
};
```

### Pointer Size Enum Change

Zig 0.15 also changed `.Slice` to `.slice` (lowercase):

```zig
// OLD
.ptr.size == .Slice

// NEW
.ptr.size == .slice
```

---

## Implementation Status

### ✅ Complete
- Core types (ArgKind, ArgSpec, Meta, ParseResult)
- Value conversion (int with k/M/G suffixes, float, bool, enum, custom types)
- Error handling with suggestions
- Comptime utilities for building specs from structs

### 🚧 In Progress
- Parser engine (src/parser.zig)
- Help generation (src/help.zig)

### 📋 Planned
- Subcommands/verbs
- Argument groups
- Validation framework
- Environment variable support
- Shell completion

---

## Next Steps

1. Implement `src/parser.zig` - main parsing engine
2. Implement `src/help.zig` - help generation
3. Create example files in `examples/`
4. Add integration tests in `tests/`
