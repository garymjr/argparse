# Known Issues

This file tracks issues found during development that are not part of the current implementation phase.

## Unrelated to Phase 2

### Unsigned Integer Support

The generic `get()` function in `parser.zig` currently only supports signed integer types (i8, i16, i32, i64). Unsigned integer types (u8, u16, u32, u64) are not yet supported.

**Example:**
```zig
const port = try parser.get("port", u16); // Compile error: Unsupported type
```

**Status:** Out of scope for Phase 2, should be addressed in Phase 7 (Polish & Ergonomics)

---

*Last updated: January 9, 2026*
