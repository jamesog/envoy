const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    // Create the SDK as a module that can be imported
    const sdk_module = b.addModule("envoy-dynamic-modules", .{
        .root_source_file = b.path("lib.zig"),
        .target = target,
        .optimize = optimize,
    });

    // Link against libc for C interop
    sdk_module.link_libc = true;

    // Add the parent directory to include path for accessing abi.h
    sdk_module.addIncludePath(b.path("../.."));

    // Create a test executable
    const lib_tests = b.addTest(.{
        .root_source_file = b.path("lib.zig"),
        .target = target,
        .optimize = optimize,
    });

    lib_tests.linkLibC();
    lib_tests.addIncludePath(b.path("../.."));

    const run_lib_tests = b.addRunArtifact(lib_tests);
    const test_step = b.step("test", "Run library tests");
    test_step.dependOn(&run_lib_tests.step);
}
