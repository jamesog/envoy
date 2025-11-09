load(
    "//bazel:envoy_build_system.bzl",
    "envoy_extension_package",
)

licenses(["notice"])  # Apache 2

envoy_extension_package()

# Note: Zig support in Bazel is still evolving. This is a basic integration
# that can be expanded based on the available Zig rules for Bazel.
# For now, this serves as a placeholder for future Bazel-Zig integration.

# The Zig SDK can be built using the native Zig build system (build.zig)
# or integrated into Bazel when proper Zig rules are available.

# Reference the ABI headers that this SDK depends on
filegroup(
    name = "abi_headers",
    srcs = [
        "//source/extensions/dynamic_modules:abi.h",
        "//source/extensions/dynamic_modules:abi_version.h",
    ],
    visibility = ["//visibility:public"],
)

# SDK source files
filegroup(
    name = "sdk_sources",
    srcs = [
        "lib.zig",
        "build.zig",
        "README.md",
    ],
    visibility = ["//visibility:public"],
)

# Complete SDK package for external use
filegroup(
    name = "envoy_dynamic_modules_zig_sdk",
    srcs = [
        ":sdk_sources",
        ":abi_headers",
    ],
    visibility = ["//visibility:public"],
)
