# AGENTS

## Build, Lint, Test

Build/install (default step installs to `zig-out/`):

```sh
zig build
```

Run the example binary:

```sh
zig build run -- --help
```

Run all tests (library + executable test targets from `build.zig`):

```sh
zig build test
```

Run a single test file or named test:

```sh
zig test src/parser_test.zig
zig test src/parser_test.zig --test-filter "parse single flag long"
zig test src/root.zig --test-filter "parse single flag long"
```

Benchmarks:

```sh
zig build bench
```

Format (no linting tools configured):

```sh
zig fmt src/*.zig examples/*.zig
```

## Code Style

- Imports/modules: Zig `@import("...")` with `.zig` file paths for local modules and package imports like `@import("argparse")`.
- Formatting: standard `zig fmt` output (4-space indentation, braces on same line, trailing commas in multiline structs/arrays, doc comments `//!` and `///`).
- Types: explicit public types (`Arg`, `Parser`, `Command`), error sets in `error.zig`, `[]const u8` for strings, optionals with `?T`, and `anyerror` only for validator callbacks.
- Naming: files `snake_case.zig`, tests `*_test.zig`, types `PascalCase`, functions/vars `lowerCamelCase`, enum tags `lowercase`.
- Error handling: `try` for propagation, `catch |err|` for branching, custom error set `Error`, `Error.ShowHelp` for help flow, `formatError` for user-facing messages.
- Testing: `test "name"` blocks, `std.testing.expect*`, allocate with `std.testing.allocator`, `defer parser.deinit()` cleanup.

Example import style:

```zig
const std = @import("std");
const Parser = @import("parser.zig").Parser;
```

Example error flow:

```zig
parser.parse(argv) catch |err| {
    if (err == argparse.Error.ShowHelp) return;
    return err;
};
```

## Existing Rules

- Cursor rules: none found (`.cursor/rules/`, `.cursorrules`).
- Copilot instructions: none found (`.github/copilot-instructions.md`).

## Architecture Overview

- `src/root.zig`: public API surface; re-exports the library modules and test imports.
- `src/argparse.zig`: central re-exports for internal modules.
- Core modules:
  - `arg.zig`: `Arg` definition, `ArgKind`, `ValueType`, `Value`.
  - `parser.zig`: parsing pipeline, error handling, option/flag tracking.
  - `parsed_values.zig`, `parser_accessors.zig`: parsed storage + accessor helpers.
  - `builder.zig`: fluent builder API; `ArgOptions`.
  - `command.zig`: subcommand handling and help integration.
  - `help.zig`, `style.zig`: help rendering + color handling.
  - `validate.zig`: comptime validation helpers.
- `src/main.zig`: example CLI using the library.
- Tests live in `src/*_test.zig` and are included via `root.zig`.
- `examples/` contains usage samples; `docs/usage.md` has feature notes.
- `build.zig` defines `run`, `test`, and `bench` steps.

## Other Helpful Information

- Dependencies: no external packages listed in `build.zig.zon`; uses Zig stdlib only.
- Workflow: define `Arg` arrays or use `Builder`, parse with `Parser`, use `HelpConfig` for output, `ErrorFormatConfig` for error formatting.
- Extension points: custom validators on `Arg.validator`, custom help config, custom error formatting, subcommands via `Command`.
