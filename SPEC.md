# Technical Specification

## Core Type System

### ArgKind
```zig
/// The kind of argument
pub const ArgKind = enum {
    /// Boolean flag, no value needed
    flag,
    /// Takes a value
    option,
    /// Positional argument
    positional,
    /// Multiple values allowed
    multiple,
    /// Counted occurrences (e.g., -vvv)
    count,
};
```

### ArgSpec (Internal)
```zig
/// Specification for a single argument
pub const ArgSpec = struct {
    /// Field name in the config struct
    name: []const u8,
    /// Argument kind
    kind: ArgKind,
    /// Type of the argument value
    type: type,
    /// Default value (if any)
    default: ?const anytype = null,
    /// Whether the argument is required
    required: bool = false,
    /// Help text
    help: ?[]const u8 = null,
    /// Short flag character
    short: ?u8 = null,
    /// Long flag name (without --)
    long: ?[]const u8 = null,
    /// Environment variable name
    env: ?[]const u8 = null,
    /// Validator function
    validator: ?*const fn (anytype) anyerror!void = null,
    /// Possible values (for enums/choices)
    choices: ?[]const []const u8 = null,
    /// Minimum value (for numbers/arrays)
    min: ?usize = null,
    /// Maximum value (for numbers/arrays)
    max: ?usize = null,
    /// Whether to hide from help
    hidden: bool = false,
};
```

### Meta (User-facing)
```zig
/// Metadata for the argument parser
pub const Meta = struct {
    /// Program name
    name: []const u8 = "program",
    /// Program version
    version: []const u8 = "0.0.0",
    /// Short description (about)
    about: ?[]const u8 = null,
    /// Author information
    author: ?[]const u8 = null,
    /// Usage summary (appended to "Usage: <name>")
    usage_summary: ?[]const u8 = null,
    /// Long description
    long_about: ?[]const u8 = null,
    /// Examples
    examples: ?[]const Example = null,
    /// Documentation for each option
    option_docs: OptionDocs,
    /// Documentation for each verb (if using subcommands)
    verb_docs: ?VerbDocs = null,
    /// Help text wrap width
    wrap_width: usize = 80,
    /// Whether to enable colors in output
    color: bool = true,
};

pub const Example = struct {
    description: []const u8,
    command: []const u8,
};

pub const OptionDocs = struct {
    // Field names → help text (comptime known)
    // Implemented as a struct or tuple
};

pub const VerbDocs = struct {
    // Verb names → help text
};
```

### ParseResult
```zig
/// Result of parsing arguments
pub fn ParseResult(comptime Spec: type, comptime Verb: ?type) type {
    return struct {
        const Self = @This();

        /// Arena allocator for all parsed strings
        arena: std.heap.ArenaAllocator,
        /// The options with parsed values
        options: Spec,
        /// The verb that was selected (if using verbs)
        verb: if (Verb) |V| ?V else void,
        /// Positional arguments
        positionals: [][:0]const u8,
        /// Raw arguments (after --)
        raw_args: ?[][]const u8,
        /// Index of first raw argument
        raw_start_index: ?usize = null,
        /// Executable name (argv[0])
        executable: ?[:0]const u8,

        /// Clean up resources
        pub fn deinit(self: Self) void {
            self.arena.child_allocator.free(self.positionals);
            if (self.raw_args) |raw| {
                self.arena.child_allocator.free(raw);
            }
            if (self.executable) |exe| {
                self.arena.child_allocator.free(exe);
            }
            self.arena.deinit();
        }
    };
}
```

---

## Value Parsing System

### parseInt
```zig
/// Parse an integer with optional suffixes
/// Supports: 10, 1k, 1M, 1G (1000-based)
///          1Ki, 1Mi, 1Gi (1024-based)
pub fn parseInt(comptime T: type, str: []const u8) !T
```

### parseFloat
```zig
/// Parse a floating point number
pub fn parseFloat(comptime T: type, str: []const u8) !T
```

### parseBool
```zig
/// Parse a boolean value
/// Accepts: true, false, yes, no, t, f, y, n, 1, 0
pub fn parseBool(str: []const u8) !bool
```

### parseEnum
```zig
/// Parse an enum from a string
/// Uses `std.meta.stringToEnum` or custom `parse()` method
pub fn parseEnum(comptime T: type, str: []const u8) !T
```

### convertValue
```zig
/// Generic value conversion
/// Dispatches to appropriate parser based on type
pub fn convertValue(comptime T: type, allocator: std.mem.Allocator, str: []const u8) !T
```

---

## Parser Engine

### Parser Type
```zig
pub fn Parser(comptime Spec: type, comptime Verb: ?type) type {
    return struct {
        const Self = @This();

        allocator: std.mem.Allocator,
        errors: ErrorCollection,
        specs: []const ArgSpec,
        verb_specs: ?[]const ArgSpec = null,

        /// Create a new parser
        pub fn init(allocator: std.mem.Allocator) Self {
            return Self{
                .allocator = allocator,
                .errors = ErrorCollection.init(allocator),
                .specs = comptime buildArgSpecs(Spec),
                .verb_specs = if (Verb) |V| comptime buildArgSpecs(V) else null,
            };
        }

        /// Parse arguments from an iterator
        pub fn parse(self: *Self, args: anytype) !ParseResult(Spec, Verb) {
            // Implementation
        }

        /// Parse for current process
        pub fn parseForCurrentProcess(self: *Self) !ParseResult(Spec, Verb) {
            var iter = try std.process.argsWithAllocator(self.allocator);
            defer iter.deinit();
            return self.parse(&iter);
        }
    };
}
```

### Build ArgSpecs (Comptime)
```zig
/// Build ArgSpec array from a struct type
fn buildArgSpecs(comptime T: type) []const ArgSpec {
    comptime {
        var specs: []const ArgSpec = &.{};

        for (std.meta.fields(T)) |field| {
            // Skip reserved fields (meta, shorthands, etc.)
            if (isReserved(field.name)) continue;

            const spec = ArgSpec{
                .name = field.name,
                .kind = comptime inferArgKind(field.type),
                .type = field.type,
                .default = comptime getDefaultValue(field.type),
                .help = comptime getHelpText(T, field.name),
                .short = comptime getShortHand(T, field.name),
                .long = field.name,
                // ... more
            };
            specs = specs ++ .{spec};
        }

        return specs;
    }
}

fn inferArgKind(comptime T: type) ArgKind {
    // bool → flag
    // optional → option
    // array/slice → multiple
    // other → option
}

fn isReserved(name: []const u8) bool {
    return std.mem.eql(u8, name, "meta") or
           std.mem.eql(u8, name, "shorthands") or
           std.mem.eql(u8, name, "validators") or
           std.mem.eql(u8, name, "groups");
}
```

---

## Error Handling

### Error Type
```zig
pub const Error = struct {
    option: []const u8,
    kind: ErrorKind,

    pub const ErrorKind = union(enum) {
        unknown,
        missing_required,
        missing_value,
        invalid_value: []const u8,
        conflict: []const u8,  // Conflicting option
        requires: []const u8,  // Required option
        validation_failed: []const u8,
        unknown_verb,
        out_of_memory,
    };

    pub fn format(self: Error, writer: anytype) !void {
        // Format error with color and context
    }

    pub fn suggest(self: Error, specs: []const ArgSpec) ?[]const u8 {
        // Suggest similar option names on typos
    }
};
```

### ErrorCollection
```zig
pub const ErrorCollection = struct {
    arena: std.heap.ArenaAllocator,
    list: std.ArrayList(Error),

    pub fn init(allocator: std.mem.Allocator) ErrorCollection {
        return ErrorCollection{
            .arena = std.heap.ArenaAllocator.init(allocator),
            .list = std.ArrayList(Error).init(allocator),
        };
    }

    pub fn deinit(self: *ErrorCollection) void {
        self.arena.deinit();
        self.list.deinit();
    }

    pub fn add(self: *ErrorCollection, err: Error) !void {
        const dupe = Error{
            .option = try self.arena.allocator().dupe(u8, err.option),
            .kind = try dupeErrorKind(self.arena.allocator(), err.kind),
        };
        try self.list.append(dupe);
    }

    pub fn hasErrors(self: ErrorCollection) bool {
        return self.list.items.len > 0;
    }

    pub fn write(self: ErrorCollection, writer: anytype) !void {
        for (self.list.items) |err| {
            try err.format(writer);
        }
    }
};
```

---

## Help Generation

### generateHelp
```zig
pub fn generateHelp(comptime Spec: type, comptime Verb: ?type, meta: Meta, writer: anytype) !void {
    // 1. Print usage line
    try printUsage(writer, meta);

    // 2. Print about/long_about
    if (meta.about) |about| {
        try writer.print("{s}\n\n", .{about});
    }
    if (meta.long_about) |long| {
        try writer.print("{s}\n\n", .{long});
    }

    // 3. Print options
    try printOptions(writer, Spec, meta);

    // 4. Print verbs (if any)
    if (Verb) |_| {
        try printVerbs(writer, Verb, meta);
    }

    // 5. Print examples
    if (meta.examples) |examples| {
        try printExamples(writer, examples);
    }
}

fn printUsage(writer: anytype, meta: Meta) !void {
    try writer.writeAll("Usage: ");
    try writer.writeAll(meta.name);

    if (meta.usage_summary) |summary| {
        try writer.print(" {s}", .{summary});
    } else {
        try writer.writeAll(" [OPTIONS]");
    }

    try writer.writeByte('\n');
}

fn printOptions(writer: anytype, comptime Spec: type, meta: Meta) !void {
    try writer.writeAll("\nOptions:\n");

    comptime var max_width: usize = 0;
    inline for (std.meta.fields(Spec)) |field| {
        if (isReserved(field.name)) continue;
        max_width = @max(max_width, field.name.len + 2); // -- prefix
    }

    inline for (std.meta.fields(Spec)) |field| {
        if (isReserved(field.name)) continue;
        if (comptime isHidden(Spec, field.name)) continue;

        // Print short, long, and help
        const help = comptime getHelpText(Spec, field.name) orelse "";
        const short = comptime getShortHand(Spec, field.name);

        if (short) |s| {
            try writer.print("  -{c}, ", .{s});
        } else {
            try writer.writeAll("      ");
        }

        try writer.print("--{s:<{}}   {s}\n", .{
            field.name, max_width, help,
        });
    }
}
```

---

## Public API

### Main Entry Points
```zig
/// Parse arguments for the current process
pub fn parseForCurrentProcess(
    comptime Spec: type,
    allocator: std.mem.Allocator,
) !ParseResult(Spec, null) {
    const parser = Parser(Spec, null).init(allocator);
    return parser.parseForCurrentProcess();
}

/// Parse arguments with verb support
pub fn parseWithVerbForCurrentProcess(
    comptime Spec: type,
    comptime Verb: type,
    allocator: std.mem.Allocator,
) !ParseResult(Spec, Verb) {
    const parser = Parser(Spec, Verb).init(allocator);
    return parser.parseForCurrentProcess();
}

/// Parse from custom iterator
pub fn parse(
    comptime Spec: type,
    args: anytype,
    allocator: std.mem.Allocator,
) !ParseResult(Spec, null) {
    const parser = Parser(Spec, null).init(allocator);
    return parser.parse(args);
}

/// Parse with verb from custom iterator
pub fn parseWithVerb(
    comptime Spec: type,
    comptime Verb: type,
    args: anytype,
    allocator: std.mem.Allocator,
) !ParseResult(Spec, Verb) {
    const parser = Parser(Spec, Verb).init(allocator);
    return parser.parse(args);
}
```

### Help Functions
```zig
/// Generate and print help
pub fn printHelp(
    comptime Spec: type,
    comptime Verb: ?type,
    meta: Meta,
) !void {
    const stdout = std.io.getStdOut().writer();
    try generateHelp(Spec, Verb, meta, stdout);
}

/// Generate help as string
pub fn helpString(
    comptime Spec: type,
    comptime Verb: ?type,
    meta: Meta,
    allocator: std.mem.Allocator,
) ![]const u8 {
    var list = std.ArrayList(u8).init(allocator);
    defer list.deinit();
    try generateHelp(Spec, Verb, meta, list.writer());
    return list.toOwnedSlice();
}
```

---

## Implementation Priority

1. **types.zig** - Core types (ArgKind, ArgSpec, Meta, ParseResult)
2. **value.zig** - Value conversion functions
3. **error.zig** - Error types and ErrorCollection
4. **parser.zig** - Main Parser type and parse logic
5. **help.zig** - Help generation
6. **validator.zig** - Validation framework
7. **completion.zig** - Shell completions
8. **internal/utils.zig** - Comptime utilities
9. **api/derive.zig** - Comptime helpers
10. **api/builder.zig** - Builder API

---

## zig-args Reference Patterns

From the zig-args file, these patterns to adopt:

1. **Shorthands struct** - Maps single chars to field names
2. **Meta struct** - Stores help text and metadata
3. **Tagged union for verbs** - Clean subcommand representation
4. **Arena allocator** - All parsed strings from arena
5. **`parseForCurrentProcess`** - Convenience function
6. **`parseWithVerb`** - Verb-specific parsing
7. **Error handling modes** - Silent, print, collect, forward
8. **`--` terminator** - Marks start of raw args
9. **Combined short flags** - `-abc` parsed as `-a -b -c`
10. **`--opt=value`** syntax** - Equals sign variant
