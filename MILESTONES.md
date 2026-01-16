# Implementation Milestones

## M1: Core Types & Value Parsing ✅
- [ ] `ArgKind` enum (flag, option, positional, multiple)
- [ ] `ArgSpec` struct with all fields
- [ ] `ParseResult` type for returning parsed data
- [ ] `Meta` type for help/usage metadata
- [ ] Value conversion: int (with k/M/G suffixes)
- [ ] Value conversion: float
- [ ] Value conversion: bool (yes/no, t/f, 1/0)
- [ ] Value conversion: string
- [ ] Value conversion: enum
- [ ] Custom type parsing via `parse()` fn
- [ ] Tests for all conversions

## M2: Basic Parser Engine ✅
- [ ] Parser type with arena allocator
- [ ] Long opt parsing: `--name=value`
- [ ] Long opt parsing: `--name value`
- [ ] Short opt parsing: `-abc` (combined flags)
- [ ] Short opt parsing: `-a value`
- [ ] Positional argument tracking
- [ ] `--` terminator handling
- [ ] Raw argument capture (after `--`)
- [ ] Error accumulation (not fail-fast)
- [ ] Error type definitions
- [ ] Integration tests

## M3: Subcommands (Verbs) ✅
- [ ] Verb detection (first positional)
- [ ] Verb parsing via tagged unions
- [ ] Global options (before/after verb)
- [ ] Verb-specific options
- [ ] Verb metadata (help, about)
- [ ] Nested subcommands (verbs in verbs)
- [ ] Tests for verb scenarios

## M4: Advanced Argument Features ✅
- [ ] Multiple values: `--file a b c`
- [ ] Counted flags: `-vvv` → count
- [ ] Argument groups struct
- [ ] Required group validation
- [ ] Exclusive group validation
- [ ] Validator framework
- [ ] Min/max validators
- [ ] Choice validators
- [ ] Regex validators
- [ ] Custom validator functions
- [ ] Conflict rules
- [ ] Require rules

## M5: Help Generation ✅
- [ ] Help generator function
- [ ] Usage line generation
- [ ] Options section with short/long
- [ ] Subcommands section
- [ ] Examples section
- [ ] Text wrapping at configurable width
- [ ] Auto `--help` handling
- [ ] Auto `--version` handling
- [ ] Styled output (colors, bold)

## M6: Environment Variables ✅
- [ ] Env var lookup
- [ ] Type conversion from env
- [ ] Env prefix support
- [ ] Priority: CLI > Env > Default
- [ ] Tests

## M7: Shell Completion ✅
- [ ] Bash completion generator
- [ ] Zsh completion generator
- [ ] Fish completion generator
- [ ] PowerShell completion generator
- [ ] Dynamic arg completion hooks
- [ ] File completion
- [ ] Enum choice completion
- [ ] Subcommand completion

## M8: DX & Polish ✅
- [ ] Builder API
- [ ] Derive-style comptime helper
- [ ] Rich errors with suggestions
- [ ] Colorized error output
- [ ] Test utilities
- [ ] Documentation
- [ ] Examples (basic, verbs, validation, advanced)
- [ ] README
- [ ] CHANGELOG

---

## Quick Start Checklist

For immediate work:

**Start here:**
1. `src/types.zig` - Define core types
2. `src/value.zig` - Implement value conversion
3. `src/error.zig` - Define errors
4. `src/parser.zig` - Parser engine
5. `src/help.zig` - Help generation

**Then:**
6. `src/completion.zig` - Shell completions
7. `src/validator.zig` - Validation framework
8. `src/api/derive.zig` - Comptime helpers
9. `src/api/builder.zig` - Builder pattern
10. Examples and tests
