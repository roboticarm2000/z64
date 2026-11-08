// Copyright (c) 2024 Matheus C. França
// SPDX-License-Identifier: Apache-2.0
const std = @import("std");

pub const Platform = struct {
    name: []const u8,
    query: std.Target.Query,
};

pub const Libs = struct {
    crt: *std.Build.Step.Compile,
    crt0: *std.Build.Step.Compile,
    c: *std.Build.Step.Compile,
    // Platforms that need a strong __memset (overrides the weak recursive stub):
    // built as a TRUE object so ld.lld sees the strong definition before the archive.
    mem: *std.Build.Step.Compile,
    // C64/CBM: printf.cc + varint.cc compiled with lto=.none (C++ bitcode crashes LLVM LTO codegen for 6502).
    printf: *std.Build.Step.Compile,
    // C64/CBM: crt0.S must be a TRUE object (not an archive member).
    // common-crt0-o in CMake = add_platform_object_file → always force-linked.
    // Without this, .call_main (jsr main) is a section-only archive member with no
    // exported symbol, so ld.lld never extracts it → main is never called.
    crt0_obj: *std.Build.Step.Compile,
};

pub fn build(b: *std.Build) void {
    // llvm-mos-sdk git source — always required for headers, linker scripts, and platform libs.
    const sdk_dep = b.dependency("llvm-mos-sdk", .{});
    const sdk_src = sdk_dep.builder.root.root_dir.path orelse ".";
    const optimize = b.standardOptimizeOption(.{});

    // ---- C64 hello ----

    const step = b.step("c64-hello", "Build C64 hello example");
    const c64 = buildPlatform(b, sdk_src, optimize);
    const exe = addC64Exe(b, sdk_dep, sdk_src, c64, optimize, "hello", "src/hello.zig");

    const install = b.addInstallArtifact(exe, .{ .dest_sub_path = "hello.prg" });
    step.dependOn(&install.step);
    b.getInstallStep().dependOn(&install.step);
}

// translate-c is the one path that misses the -nostdinc normal C compiles get
// (src/Compilation.zig), so clang's builtin stdint.h does its hosted
// #include_next fallback into the HOST glibc headers — /usr/include/stdint.h →
// features.h → gnu/stubs.h, which has no stubs-32.h on Ubuntu CI. Every MOS
// target is bare metal, so translate as freestanding and keep the host out.
fn addTranslateC(b: *std.Build, options: std.Build.Step.TranslateC.Options) *std.Build.Step.TranslateC {
    const tc = b.addTranslateC(options);
    tc.defineCMacro("__STDC_HOSTED__", "0");
    tc.defineCMacro("__CBM__", "1");
    return tc;
}

fn addC64Exe(b: *std.Build, sdk_dep: *std.Build.Dependency, sdk_src: []const u8, libs: Libs, opt: std.builtin.OptimizeMode, name: []const u8, root_src: []const u8) *std.Build.Step.Compile {
    const target = b.resolveTargetQuery(.{ .cpu_arch = .mos, .os_tag = .c64 });

    const wf = b.addWriteFiles();
    const libc_txt = addLibcTxt(b, wf, sdk_src, "c64");
    // Inline c64/link.ld + commodore/commodore.ld, replacing INPUT() directives with
    // addAssemblyFile calls below (lld INPUT() doesn't search -L paths for .o files).
    const wrapper_ld = wf.add("c64-wrapper.ld", b.fmt(
        \\SEARCH_DIR("{s}/mos-platform/c64");
        \\SEARCH_DIR("{s}/mos-platform/commodore");
        \\SEARCH_DIR("{s}/mos-platform/common/ldscripts");
        \\__basic_zp_start = 0x0002;
        \\__basic_zp_end = 0x0090;
        \\MEMORY {{ ram (rw) : ORIGIN = 0x0801, LENGTH = 0xC7FF }}
        \\__rc0 = __basic_zp_start;
        \\INCLUDE "imag-regs.ld"
        \\__basic_zp_size = __basic_zp_end - __basic_zp_start;
        \\MEMORY {{ zp : ORIGIN = __rc31 + 1, LENGTH = __basic_zp_end - (__rc31 + 1) }}
        \\REGION_ALIAS("c_readonly", ram)
        \\REGION_ALIAS("c_writeable", ram)
        \\SECTIONS {{ .basic_header : {{ *(.basic_header) }} INCLUDE "c.ld" }}
        \\__stack = 0xD000;
        \\OUTPUT_FORMAT {{ SHORT(ORIGIN(ram)) TRIM(ram) }}
    , .{ sdk_src, sdk_src, sdk_src }));

    const exe = b.addExecutable(.{
        .name = name,
        .root_module = b.createModule(.{
            .root_source_file = b.path(root_src),
            .target = target,
            .optimize = opt,
            .sanitize_c = .off,
        }),
    });
    exe.bundle_compiler_rt = false;
    exe.lto = .full;
    exe.forceUndefinedSymbol("__zig_call_main_section");
    exe.forceUndefinedSymbol("main");
    exe.forceUndefinedSymbol("puts");
    // basic-header.S and unmap-basic.S replace INPUT(basic-header.o) / INPUT(unmap-basic.o).
    exe.root_module.addAssemblyFile(sdk_dep.path("mos-platform/c64/basic-header.S"));
    exe.root_module.addAssemblyFile(sdk_dep.path("mos-platform/c64/unmap-basic.S"));
    exe.root_module.addObject(libs.crt0_obj);
    exe.root_module.linkLibrary(libs.crt);
    exe.root_module.linkLibrary(libs.crt0);
    exe.root_module.linkLibrary(libs.c);
    exe.root_module.linkLibrary(libs.printf);
    exe.root_module.addObject(libs.mem);
    exe.setLibCFile(libc_txt);
    exe.root_module.link_libc = true;
    exe.setLinkerScript(wrapper_ld);

    exe.root_module.addImport("mos_panic", b.createModule(.{
        .root_source_file = b.path("src/panic.zig"),
        .target = target,
        .optimize = opt,
        .sanitize_c = .off,
    }));

    {
        const tc = addTranslateC(b, .{
            .root_source_file = sdk_dep.path("mos-platform/c64/c64.h"),
            .target = target,
            .optimize = opt,
            .link_libc = false,
        });
        tc.addIncludePath(sdk_dep.path("mos-platform/c64"));
        tc.addIncludePath(sdk_dep.path("mos-platform/commodore"));
        tc.addIncludePath(sdk_dep.path("mos-platform/common/include"));
        const c64_mod = tc.createModule();
        exe.root_module.addImport("c64", c64_mod);
    }
    {
        const tc = addTranslateC(b, .{
            .root_source_file = sdk_dep.path("mos-platform/commodore/cbm.h"),
            .target = target,
            .optimize = opt,
            .link_libc = false,
        });
        tc.addIncludePath(sdk_dep.path("mos-platform/c64"));
        tc.addIncludePath(sdk_dep.path("mos-platform/commodore"));
        tc.addIncludePath(sdk_dep.path("mos-platform/common/include"));
        const cbm_mod = tc.createModule();
        exe.root_module.addImport("cbm", cbm_mod);
    }
    return exe;
}

fn addLibcTxt(b: *std.Build, wf: *std.Build.Step.WriteFile, sdk_src: []const u8, plat: []const u8) std.Build.LazyPath {
    return wf.add("libc.txt", b.fmt(
        "include_dir={s}/mos-platform/{s}\n" ++
            "sys_include_dir={s}/mos-platform/common/include\n" ++
            "crt_dir={s}/mos-platform/{s}\n" ++
            "msvc_lib_dir=\nkernel32_lib_dir=\ngcc_dir=\ndarwin_sdk_dir=\n",
        .{ sdk_src, plat, sdk_src, sdk_src, plat },
    ));
}

/// Build platform libraries for `pd` from the SDK source tree at `sdk_root`.
/// Returns the compile artifacts; the caller decides how to install/link them.
pub fn buildPlatform(b: *std.Build, sdk_root: []const u8, opt: std.builtin.OptimizeMode) Libs {
    const name = "c64";
    const target = b.resolveTargetQuery(.{ .cpu_arch = .mos, .os_tag = .c64 });

    const common = b.fmt("{s}/mos-platform/common", .{sdk_root});
    const com_inc = b.fmt("{s}/include", .{common});
    const com_asm = b.fmt("{s}/asminc", .{common});
    const crt_dir = b.fmt("{s}/crt", .{common});
    const crt0_dir = b.fmt("{s}/crt0", .{common});
    const plat_dir = b.fmt("{s}/mos-platform/{s}", .{ sdk_root, name });
    const comm_dir = b.fmt("{s}/mos-platform/commodore", .{sdk_root});
    const com_c_dir = b.fmt("{s}/c", .{common});

    // libcrt — compiler runtime builtins (all platforms share this).
    const libcrt = addLib(b, "crt", target, .fast);
    libcrt.root_module.addIncludePath(.{ .cwd_relative = crt_dir });
    libcrt.root_module.addIncludePath(.{ .cwd_relative = com_inc });
    libcrt.root_module.addIncludePath(.{ .cwd_relative = com_asm });

    const crt_files: []const []const u8 = &.{ "const.S", "call-indir.S", "divmod.cc", "divmod-large.cc", "mul.cc", "shift.cc", "rotate.cc" };
    libcrt.root_module.addCSourceFiles(.{
        .root = .{ .cwd_relative = crt_dir },
        .files = crt_files,
    });

    // libcrt0 — startup: stack init + data copy + exit handler.
    const libcrt0 = addLib(b, "crt0", target, opt);
    libcrt0.lto = .none;
    libcrt0.root_module.addIncludePath(.{ .cwd_relative = com_asm });
    libcrt0.root_module.addIncludePath(.{ .cwd_relative = com_inc });
    libcrt0.root_module.addCSourceFiles(.{
        .root = .{ .cwd_relative = crt0_dir },
        .files = &.{"init-stack.S"},
    });
    libcrt0.root_module.addCSourceFiles(.{
        .root = .{ .cwd_relative = crt0_dir },
        .files = &.{"copy-zp-data.c"},
    });
    // CBM exit: exit-custom.S defines __after_main (jmp exit) so crt0.S's undefined
    // __after_main reference pulls it from the archive.  exit.c provides exit() which
    // calls _fini() + _Exit().  exit-loop.c provides _Exit() = infinite loop.
    const exit_files: []const []const u8 =
        &.{ "exit-custom.S", "exit-loop.c", "exit.c" };
    libcrt0.root_module.addCSourceFiles(.{
        .root = .{ .cwd_relative = b.fmt("{s}/exit", .{crt0_dir}) },
        .files = exit_files,
    });

    // libc — platform I/O and kernal wrappers.
    const libc = addLib(b, "c", target, opt);

    const asm_files: []const []const u8 =
        &.{ "basic-header.S", "kernal.S", "unmap-basic.S", "devnum.s" };
    libc.root_module.addIncludePath(.{ .cwd_relative = plat_dir });
    libc.root_module.addIncludePath(.{ .cwd_relative = comm_dir });
    libc.root_module.addIncludePath(.{ .cwd_relative = com_c_dir });
    libc.root_module.addIncludePath(.{ .cwd_relative = com_asm });
    libc.root_module.addIncludePath(.{ .cwd_relative = com_inc });
    libc.root_module.addCSourceFiles(.{
        .root = .{ .cwd_relative = plat_dir },
        .files = asm_files,
    });
    libc.root_module.addCSourceFiles(.{
        .root = .{ .cwd_relative = comm_dir },
        .files = &.{ "abort.c", "cbm_k_bsout.c", "cbm_k_chrout.c", "chrout.c", "char-conv.c", "putchar.c", "getchar.c" },
    });
    libc.root_module.addCSourceFiles(.{
        .root = .{ .cwd_relative = com_c_dir },
        .files = &.{ "stdio-minimal.c", "mem.c", "util.c", "string.c" },
    });
    // Build printf.cc + varint.cc with lto=.none: C++ bitcode crashes LLVM LTO
    // codegen for the 6502 target. Pre-compiling to native code avoids the crash.
    const libprintf = addLib(b, "printf", target, opt);
    libprintf.lto = .none;
    libprintf.root_module.addIncludePath(.{ .cwd_relative = plat_dir });
    libprintf.root_module.addIncludePath(.{ .cwd_relative = comm_dir });
    libprintf.root_module.addIncludePath(.{ .cwd_relative = com_c_dir });
    libprintf.root_module.addIncludePath(.{ .cwd_relative = com_asm });
    libprintf.root_module.addIncludePath(.{ .cwd_relative = com_inc });
    libprintf.root_module.addCSourceFiles(.{
        .root = .{ .cwd_relative = com_c_dir },
        .files = &.{ "printf.cc", "varint.cc" },
        .flags = &.{ "-fno-exceptions", "-fno-rtti" },
    });
    // sdk/mem.s — strong __memset + abort TRUE object (same pattern as NES/SNES).
    const mem_obj = b.addObject(.{
        .name = "mem",
        .root_module = b.createModule(.{ .target = target, .optimize = opt }),
    });
    mem_obj.root_module.addCSourceFiles(.{ .root = b.path("src/c_code"), .files = &.{"mem.s"} });
    mem_obj.lto = .none;
    // crt0.S TRUE object — mirrors cmake add_platform_object_file(common-crt0-o).
    // Must be linked directly (not via archive) so its .call_main / .fini_rts
    // anonymous sections reach the linker.  lto=.none matches libcrt0 policy.
    const crt0_obj = b.addObject(.{
        .name = "crt0",
        .root_module = b.createModule(.{ .target = target, .optimize = opt }),
    });
    crt0_obj.root_module.addIncludePath(.{ .cwd_relative = com_asm });
    crt0_obj.root_module.addIncludePath(.{ .cwd_relative = com_inc });
    crt0_obj.root_module.addCSourceFiles(.{
        .root = .{ .cwd_relative = crt0_dir },
        .files = &.{"crt0.S"},
    });
    crt0_obj.lto = .none;
    // save-basic.S: TRUE object for MEGA65/Commodore clean BASIC exit (PR #430).
    // Contains .init.005 (save ZP) and .fini.989 (restore ZP) section-only contributions
    // with no exported symbol → must be a TRUE object, not an archive member (Hard rule #5).
    return .{ .crt = libcrt, .crt0 = libcrt0, .c = libc, .printf = libprintf, .mem = mem_obj, .crt0_obj = crt0_obj };
}

fn addLib(b: *std.Build, name: []const u8, target: std.Build.ResolvedTarget, opt: std.builtin.OptimizeMode) *std.Build.Step.Compile {
    const lib = b.addLibrary(.{ .name = name, .linkage = .static, .root_module = b.createModule(.{ .target = target, .optimize = opt, .sanitize_c = .off }) });
    // Match prebuilt llvm-mos-sdk behaviour: libraries were built with LTO enabled.
    // Startup libs (libcrt0, libnes_c_startup) override this with lto = .none after creation.
    lib.lto = .full;
    return lib;
}
