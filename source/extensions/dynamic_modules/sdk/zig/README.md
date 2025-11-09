# Envoy Dynamic Modules Zig SDK

This directory contains the Zig SDK for the Dynamic Modules feature. This directory is organized so that it can be used as a standalone Zig module. The SDK provides a high-level abstraction layer for the Dynamic Modules ABI defined in [abi.h](../../abi.h).

## Overview

The Zig SDK provides:
- Type-safe wrappers around the C ABI
- Zig-idiomatic interfaces for implementing HTTP filters
- Convenient logging functions
- Memory-safe buffer handling

## Usage

### Installation

Add this SDK to your Zig project using the Zig package manager or by referencing the Envoy repository:

```zig
// In your build.zig.zon
.{
    .name = "my-envoy-filter",
    .version = "0.1.0",
    .dependencies = .{
        .envoy_dynamic_modules = .{
            .url = "https://github.com/envoyproxy/envoy/archive/vX.Y.Z.tar.gz",
            // Or use a specific commit:
            // .url = "https://github.com/envoyproxy/envoy/archive/<commit-hash>.tar.gz",
        },
    },
}
```

### Basic Example

```zig
const std = @import("std");
const envoy = @import("envoy-dynamic-modules");

// Program initialization
export fn envoy_dynamic_module_on_program_init() callconv(.C) ?[*:0]const u8 {
    if (!myProgramInit()) {
        return null;
    }
    return envoy.c.kAbiVersion;
}

fn myProgramInit() bool {
    envoy.logInfo("Dynamic module initialized!", .{});
    return true;
}

// HTTP Filter Config creation
export fn envoy_dynamic_module_on_http_filter_config_new(
    envoy_filter_config_ptr: envoy.HttpFilterConfigEnvoyPtr,
    name_ptr: [*]const u8,
    name_size: usize,
    config_ptr: [*]const u8,
    config_size: usize,
) callconv(.C) envoy.HttpFilterConfigModulePtr {
    const name = name_ptr[0..name_size];
    const config = config_ptr[0..config_size];

    const filter_config = MyHttpFilterConfig.init(
        envoy.EnvoyHttpFilterConfig.init(envoy_filter_config_ptr),
        name,
        config,
    ) catch {
        return null;
    };

    return @ptrCast(filter_config);
}

// HTTP Filter Config destruction
export fn envoy_dynamic_module_on_http_filter_config_destroy(
    filter_config_ptr: envoy.HttpFilterConfigModulePtr,
) callconv(.C) void {
    const config: *MyHttpFilterConfig = @ptrCast(@alignCast(filter_config_ptr));
    config.deinit();
}

// HTTP Filter creation
export fn envoy_dynamic_module_on_http_filter_new(
    filter_config_ptr: envoy.HttpFilterConfigModulePtr,
    envoy_filter_ptr: envoy.HttpFilterEnvoyPtr,
) callconv(.C) envoy.HttpFilterModulePtr {
    const config: *MyHttpFilterConfig = @ptrCast(@alignCast(filter_config_ptr));

    const filter = config.createFilter(envoy_filter_ptr) catch {
        return null;
    };

    return @ptrCast(filter);
}

// HTTP Filter request headers handler
export fn envoy_dynamic_module_on_http_filter_request_headers(
    filter_ptr: envoy.HttpFilterModulePtr,
    envoy_filter_ptr: envoy.HttpFilterEnvoyPtr,
    end_of_stream: bool,
) callconv(.C) envoy.FilterHeadersStatus {
    const filter: *MyHttpFilter = @ptrCast(@alignCast(filter_ptr));
    return filter.onRequestHeaders(envoy_filter_ptr, end_of_stream);
}

// HTTP Filter destruction
export fn envoy_dynamic_module_on_http_filter_destroy(
    filter_ptr: envoy.HttpFilterModulePtr,
) callconv(.C) void {
    const filter: *MyHttpFilter = @ptrCast(@alignCast(filter_ptr));
    filter.deinit();
}

// Your filter config implementation
const MyHttpFilterConfig = struct {
    allocator: std.mem.Allocator,
    envoy_config: envoy.EnvoyHttpFilterConfig,
    name: []const u8,

    pub fn init(
        envoy_config: envoy.EnvoyHttpFilterConfig,
        name: []const u8,
        config: []const u8,
    ) !*MyHttpFilterConfig {
        _ = config; // Parse your config here

        const allocator = std.heap.c_allocator;
        const self = try allocator.create(MyHttpFilterConfig);

        self.* = .{
            .allocator = allocator,
            .envoy_config = envoy_config,
            .name = try allocator.dupe(u8, name),
        };

        return self;
    }

    pub fn deinit(self: *MyHttpFilterConfig) void {
        self.allocator.free(self.name);
        self.allocator.destroy(self);
    }

    pub fn createFilter(self: *MyHttpFilterConfig, envoy_filter: envoy.HttpFilterEnvoyPtr) !*MyHttpFilter {
        const filter = try self.allocator.create(MyHttpFilter);
        filter.* = .{
            .allocator = self.allocator,
            .config = self,
            .envoy_filter = envoy_filter,
        };
        return filter;
    }
};

// Your filter implementation
const MyHttpFilter = struct {
    allocator: std.mem.Allocator,
    config: *MyHttpFilterConfig,
    envoy_filter: envoy.HttpFilterEnvoyPtr,

    pub fn onRequestHeaders(
        self: *MyHttpFilter,
        envoy_filter: envoy.HttpFilterEnvoyPtr,
        end_of_stream: bool,
    ) envoy.FilterHeadersStatus {
        _ = self;
        _ = envoy_filter;
        _ = end_of_stream;

        envoy.logInfo("Processing request headers", .{});

        // Return Continue to pass the request to the next filter
        return envoy.c.envoy_dynamic_module_type_on_http_filter_request_headers_status_Continue;
    }

    pub fn deinit(self: *MyHttpFilter) void {
        self.allocator.destroy(self);
    }
};
```

## API Reference

### Core Types

- `EnvoyBuffer`: Wrapper around Envoy-owned buffers
- `ModuleBuffer`: Wrapper around module-owned buffers
- `HttpHeader`: HTTP header key-value pair
- `EnvoyHttpFilterConfig`: Wrapper for Envoy's HTTP filter config
- `HttpFilterConfig`: Interface for implementing filter configurations
- `HttpFilter`: Interface for implementing HTTP filters

### Logging

The SDK provides convenient logging functions:

```zig
envoy.logTrace("Trace message: {}", .{value});
envoy.logDebug("Debug message: {}", .{value});
envoy.logInfo("Info message: {}", .{value});
envoy.logWarn("Warning message: {}", .{value});
envoy.logError("Error message: {}", .{value});
envoy.logCritical("Critical message: {}", .{value});
```

### Filter Status Types

- `FilterHeadersStatus`: Return values for header processing
- `FilterDataStatus`: Return values for body data processing
- `FilterTrailersStatus`: Return values for trailer processing

## Building

### With Zig Build System

Create a `build.zig` file:

```zig
const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const lib = b.addSharedLibrary(.{
        .name = "my_filter",
        .root_source_file = .{ .path = "src/main.zig" },
        .target = target,
        .optimize = optimize,
    });

    // Add C include path for Envoy headers
    lib.addIncludePath(.{ .path = "path/to/envoy" });
    lib.linkLibC();

    b.installArtifact(lib);
}
```

### With Bazel

See the BUILD file in this directory for Bazel integration examples.

## Examples

For complete examples, see the [Dynamic Modules Examples repository](https://github.com/envoyproxy/dynamic-modules-examples).

## ABI Compatibility

The SDK is compatible with Envoy when the ABI version matches exactly. The ABI version is checked at module load time. Always build your module against the same version of Envoy that you'll be running it with.

## License

Apache License 2.0
