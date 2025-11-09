//! Basic example of an Envoy dynamic module written in Zig
//!
//! This example demonstrates:
//! - Module initialization
//! - HTTP filter configuration creation
//! - HTTP filter creation and request/response processing
//! - Logging

const std = @import("std");
const envoy = @import("envoy-dynamic-modules");

// ============================================================================
// Program Initialization
// ============================================================================

/// This is the entry point called when the dynamic module is loaded.
/// It must return the ABI version string on success, or null on failure.
export fn envoy_dynamic_module_on_program_init() callconv(.C) ?[*:0]const u8 {
    if (!programInit()) {
        return null;
    }
    return envoy.c.kAbiVersion;
}

fn programInit() bool {
    envoy.logInfo("Basic example module initialized successfully!", .{});
    return true;
}

// ============================================================================
// HTTP Filter Configuration
// ============================================================================

/// Called when a new HTTP filter configuration is created in Envoy
export fn envoy_dynamic_module_on_http_filter_config_new(
    envoy_filter_config_ptr: envoy.HttpFilterConfigEnvoyPtr,
    name_ptr: [*]const u8,
    name_size: usize,
    config_ptr: [*]const u8,
    config_size: usize,
) callconv(.C) envoy.HttpFilterConfigModulePtr {
    const name = name_ptr[0..name_size];
    const config = config_ptr[0..config_size];

    envoy.logInfo("Creating new filter config: {s}", .{name});
    envoy.logDebug("Config data: {s}", .{config});

    const filter_config = BasicHttpFilterConfig.init(
        envoy.EnvoyHttpFilterConfig.init(envoy_filter_config_ptr),
        name,
        config,
    ) catch |err| {
        envoy.logError("Failed to create filter config: {}", .{err});
        return @ptrCast(@alignCast(@as(?*anyopaque, null)));
    };

    return @ptrCast(filter_config);
}

/// Called when the HTTP filter configuration is destroyed
export fn envoy_dynamic_module_on_http_filter_config_destroy(
    filter_config_ptr: envoy.HttpFilterConfigModulePtr,
) callconv(.C) void {
    const config: *BasicHttpFilterConfig = @ptrCast(@alignCast(filter_config_ptr));
    config.deinit();
}

const BasicHttpFilterConfig = struct {
    allocator: std.mem.Allocator,
    envoy_config: envoy.EnvoyHttpFilterConfig,
    name: []const u8,
    config_data: []const u8,

    pub fn init(
        envoy_config: envoy.EnvoyHttpFilterConfig,
        name: []const u8,
        config: []const u8,
    ) !*BasicHttpFilterConfig {
        const allocator = std.heap.c_allocator;
        const self = try allocator.create(BasicHttpFilterConfig);
        errdefer allocator.destroy(self);

        self.* = .{
            .allocator = allocator,
            .envoy_config = envoy_config,
            .name = try allocator.dupe(u8, name),
            .config_data = try allocator.dupe(u8, config),
        };

        return self;
    }

    pub fn deinit(self: *BasicHttpFilterConfig) void {
        self.allocator.free(self.name);
        self.allocator.free(self.config_data);
        self.allocator.destroy(self);
    }

    pub fn createFilter(self: *BasicHttpFilterConfig, envoy_filter: envoy.HttpFilterEnvoyPtr) !*BasicHttpFilter {
        const filter = try self.allocator.create(BasicHttpFilter);
        errdefer self.allocator.destroy(filter);

        filter.* = .{
            .allocator = self.allocator,
            .config = self,
            .envoy_filter = envoy_filter,
            .request_count = 0,
        };

        return filter;
    }
};

// ============================================================================
// HTTP Filter
// ============================================================================

/// Called when a new HTTP filter is created for a stream
export fn envoy_dynamic_module_on_http_filter_new(
    filter_config_ptr: envoy.HttpFilterConfigModulePtr,
    envoy_filter_ptr: envoy.HttpFilterEnvoyPtr,
) callconv(.C) envoy.HttpFilterModulePtr {
    const config: *BasicHttpFilterConfig = @ptrCast(@alignCast(filter_config_ptr));

    const filter = config.createFilter(envoy_filter_ptr) catch |err| {
        envoy.logError("Failed to create filter: {}", .{err});
        return @ptrCast(@alignCast(@as(?*anyopaque, null)));
    };

    envoy.logTrace("Created new HTTP filter instance", .{});
    return @ptrCast(filter);
}

/// Called when request headers are received
export fn envoy_dynamic_module_on_http_filter_request_headers(
    filter_ptr: envoy.HttpFilterModulePtr,
    envoy_filter_ptr: envoy.HttpFilterEnvoyPtr,
    end_of_stream: bool,
) callconv(.C) envoy.FilterHeadersStatus {
    const filter: *BasicHttpFilter = @ptrCast(@alignCast(filter_ptr));
    return filter.onRequestHeaders(envoy_filter_ptr, end_of_stream);
}

/// Called when request body data is received
export fn envoy_dynamic_module_on_http_filter_request_body(
    filter_ptr: envoy.HttpFilterModulePtr,
    envoy_filter_ptr: envoy.HttpFilterEnvoyPtr,
    end_of_stream: bool,
) callconv(.C) envoy.FilterDataStatus {
    const filter: *BasicHttpFilter = @ptrCast(@alignCast(filter_ptr));
    return filter.onRequestBody(envoy_filter_ptr, end_of_stream);
}

/// Called when request trailers are received
export fn envoy_dynamic_module_on_http_filter_request_trailers(
    filter_ptr: envoy.HttpFilterModulePtr,
    envoy_filter_ptr: envoy.HttpFilterEnvoyPtr,
) callconv(.C) envoy.FilterTrailersStatus {
    const filter: *BasicHttpFilter = @ptrCast(@alignCast(filter_ptr));
    return filter.onRequestTrailers(envoy_filter_ptr);
}

/// Called when response headers are received
export fn envoy_dynamic_module_on_http_filter_response_headers(
    filter_ptr: envoy.HttpFilterModulePtr,
    envoy_filter_ptr: envoy.HttpFilterEnvoyPtr,
    end_of_stream: bool,
) callconv(.C) envoy.FilterHeadersStatus {
    const filter: *BasicHttpFilter = @ptrCast(@alignCast(filter_ptr));
    return filter.onResponseHeaders(envoy_filter_ptr, end_of_stream);
}

/// Called when response body data is received
export fn envoy_dynamic_module_on_http_filter_response_body(
    filter_ptr: envoy.HttpFilterModulePtr,
    envoy_filter_ptr: envoy.HttpFilterEnvoyPtr,
    end_of_stream: bool,
) callconv(.C) envoy.FilterDataStatus {
    const filter: *BasicHttpFilter = @ptrCast(@alignCast(filter_ptr));
    return filter.onResponseBody(envoy_filter_ptr, end_of_stream);
}

/// Called when response trailers are received
export fn envoy_dynamic_module_on_http_filter_response_trailers(
    filter_ptr: envoy.HttpFilterModulePtr,
    envoy_filter_ptr: envoy.HttpFilterEnvoyPtr,
) callconv(.C) envoy.FilterTrailersStatus {
    const filter: *BasicHttpFilter = @ptrCast(@alignCast(filter_ptr));
    return filter.onResponseTrailers(envoy_filter_ptr);
}

/// Called when the HTTP filter is destroyed
export fn envoy_dynamic_module_on_http_filter_destroy(
    filter_ptr: envoy.HttpFilterModulePtr,
) callconv(.C) void {
    const filter: *BasicHttpFilter = @ptrCast(@alignCast(filter_ptr));
    filter.deinit();
}

const BasicHttpFilter = struct {
    allocator: std.mem.Allocator,
    config: *BasicHttpFilterConfig,
    envoy_filter: envoy.HttpFilterEnvoyPtr,
    request_count: u64,

    pub fn onRequestHeaders(
        self: *BasicHttpFilter,
        envoy_filter: envoy.HttpFilterEnvoyPtr,
        end_of_stream: bool,
    ) envoy.FilterHeadersStatus {
        _ = envoy_filter;

        self.request_count += 1;

        envoy.logInfo("Processing request headers (request #{})", .{self.request_count});
        if (end_of_stream) {
            envoy.logDebug("Request has no body", .{});
        }

        // Continue processing - pass to next filter
        return envoy.c.envoy_dynamic_module_type_on_http_filter_request_headers_status_Continue;
    }

    pub fn onRequestBody(
        self: *BasicHttpFilter,
        envoy_filter: envoy.HttpFilterEnvoyPtr,
        end_of_stream: bool,
    ) envoy.FilterDataStatus {
        _ = envoy_filter;

        envoy.logDebug("Processing request body (end_of_stream: {})", .{end_of_stream});

        // Continue processing - pass to next filter
        return envoy.c.envoy_dynamic_module_type_on_http_filter_request_body_status_Continue;
    }

    pub fn onRequestTrailers(
        self: *BasicHttpFilter,
        envoy_filter: envoy.HttpFilterEnvoyPtr,
    ) envoy.FilterTrailersStatus {
        _ = self;
        _ = envoy_filter;

        envoy.logDebug("Processing request trailers", .{});

        // Continue processing - pass to next filter
        return envoy.c.envoy_dynamic_module_type_on_http_filter_request_trailers_status_Continue;
    }

    pub fn onResponseHeaders(
        self: *BasicHttpFilter,
        envoy_filter: envoy.HttpFilterEnvoyPtr,
        end_of_stream: bool,
    ) envoy.FilterHeadersStatus {
        _ = self;
        _ = envoy_filter;

        envoy.logInfo("Processing response headers", .{});
        if (end_of_stream) {
            envoy.logDebug("Response has no body", .{});
        }

        // Continue processing - pass to next filter
        return envoy.c.envoy_dynamic_module_type_on_http_filter_response_headers_status_Continue;
    }

    pub fn onResponseBody(
        self: *BasicHttpFilter,
        envoy_filter: envoy.HttpFilterEnvoyPtr,
        end_of_stream: bool,
    ) envoy.FilterDataStatus {
        _ = self;
        _ = envoy_filter;

        envoy.logDebug("Processing response body (end_of_stream: {})", .{end_of_stream});

        // Continue processing - pass to next filter
        return envoy.c.envoy_dynamic_module_type_on_http_filter_response_body_status_Continue;
    }

    pub fn onResponseTrailers(
        self: *BasicHttpFilter,
        envoy_filter: envoy.HttpFilterEnvoyPtr,
    ) envoy.FilterTrailersStatus {
        _ = self;
        _ = envoy_filter;

        envoy.logDebug("Processing response trailers", .{});

        // Continue processing - pass to next filter
        return envoy.c.envoy_dynamic_module_type_on_http_filter_response_trailers_status_Continue;
    }

    pub fn deinit(self: *BasicHttpFilter) void {
        envoy.logTrace("Destroying HTTP filter instance", .{});
        self.allocator.destroy(self);
    }
};
