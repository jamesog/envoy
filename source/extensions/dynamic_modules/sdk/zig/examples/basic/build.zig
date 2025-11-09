const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    // Build the example as a shared library (dynamic module)
    const lib = b.addSharedLibrary(.{
        .name = "envoy_zig_basic_example",
        .root_source_file = b.path("main.zig"),
        .target = target,
        .optimize = optimize,
    });

    // Link against libc for C interop
    lib.linkLibC();

    // Add include path to the Envoy source root
    // Adjust this path based on where you have Envoy checked out
    const envoy_root = b.option(
        []const u8,
        "envoy-root",
        "Path to Envoy source root",
    ) orelse "../../../..";

    lib.addIncludePath(.{ .cwd_relative = envoy_root });

    // Add the SDK as a module
    const sdk = b.addModule("envoy-dynamic-modules", .{
        .root_source_file = .{ .cwd_relative = "../../lib.zig" },
    });
    lib.root_module.addImport("envoy-dynamic-modules", sdk);

    // Install the library
    b.installArtifact(lib);
}
