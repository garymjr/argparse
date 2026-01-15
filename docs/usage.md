# argparse usage

## Builder API

```zig
const argparse = @import("argparse");

var builder = argparse.Builder.init(allocator);
defer builder.deinit();

try builder
    .addFlag("verbose", 'v', "verbose", "Enable verbose output")
    .addOptionWith("count", 'c', "count", .int, "Number of items", .{ .required = true })
    .addPositional("input", .string, "Input file");

var parser = try builder.build();
defer parser.deinit();
try parser.parse(argv);
```

## Error formatting

```zig
const err = parser.parse(argv) catch |e| e;
const message = try parser.formatError(allocator, err, .{ .color = .auto });
defer allocator.free(message);
std.debug.print("{s}\n", .{message});
```

## Showing help on error

When a parsing error occurs, it's good practice to display the help text to guide the user:

```zig
parser.parse(argv) catch |err| {
    if (err == argparse.Error.ShowHelp) {
        const help = try parser.help();
        defer allocator.free(help);
        std.debug.print("{s}", .{help});
        std.process.exit(0);
    }

    // Show error message
    const message = try parser.formatError(allocator, err, .{});
    defer allocator.free(message);
    std.debug.print("{s}\n", .{message});

    // Show help after error
    const help = try parser.help();
    defer allocator.free(help);
    std.debug.print("\n{s}", .{help});
    std.process.exit(1);
};
```

## Comptime validation

```zig
const args = [_]argparse.Arg{
    .{ .name = "count", .short = 'c', .long = "count", .kind = .option },
};

argparse.validateArgsComptime(&args);
```

## Benchmarks

```
zig build bench
```
