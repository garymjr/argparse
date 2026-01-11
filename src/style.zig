//! ANSI styling helpers.

const std = @import("std");

pub const ColorMode = enum {
    never,
    auto,
    always,
};

pub const Ansi = struct {
    pub const reset = "\x1b[0m";
    pub const bold = "\x1b[1m";
    pub const dim = "\x1b[2m";
    pub const red = "\x1b[31m";
    pub const green = "\x1b[32m";
    pub const yellow = "\x1b[33m";
    pub const blue = "\x1b[34m";
    pub const magenta = "\x1b[35m";
    pub const cyan = "\x1b[36m";
};

pub fn useColorStdout(mode: ColorMode) bool {
    return switch (mode) {
        .never => false,
        .always => true,
        .auto => std.fs.File.stdout().isTty(),
    };
}

pub fn useColorStderr(mode: ColorMode) bool {
    return switch (mode) {
        .never => false,
        .always => true,
        .auto => std.fs.File.stderr().isTty(),
    };
}
