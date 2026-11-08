// Copyright (c) 2024 Matheus C. França
// SPDX-License-Identifier: Apache-2.0
//! C64 VIC-II border and background colour cycling demo.
//! Uses the translated c64.h module for VIC struct type and color constants.
pub const panic = @import("mos_panic");

const std = @import("std");
const commodore = @import("cbm");

//extern fn cbm_k_chrout(char : u8) void;
fn putc(c: u8) void {
    commodore.cbm_k_chrout(c);
}
fn puts(s: []const u8) void {
    for (s) |c| {
        putc(c);
    }
}

export fn main() void {
    putc(0x8e);
    putc('F');
    putc('U');
    putc('C');
    putc('K');
    putc('f');
    putc('u');
    putc('c');
    putc('k');
    puts("HELLO WORLD");
}
