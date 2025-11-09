//! Envoy Dynamic Modules SDK for Zig
//!
//! This is the Zig SDK for the Dynamic Modules feature. This provides a high-level abstraction
//! layer for the Dynamic Modules ABI defined in abi.h.
//!
//! Usage:
//! ```zig
//! const envoy = @import("envoy-dynamic-modules");
//!
//! export fn envoy_dynamic_module_on_program_init() callconv(.C) ?[*:0]const u8 {
//!     return envoy.programInit(myProgramInit, myNewHttpFilterConfig);
//! }
//!
//! fn myProgramInit() bool {
//!     return true;
//! }
//!
//! fn myNewHttpFilterConfig(
//!     envoy_filter_config: *envoy.EnvoyHttpFilterConfig,
//!     name: []const u8,
//!     config: []const u8,
//! ) ?*MyHttpFilterConfig {
//!     return MyHttpFilterConfig.init(envoy_filter_config, name, config);
//! }
//!
//! const MyHttpFilterConfig = struct {
//!     // Your filter config implementation
//! };
//! ```

const std = @import("std");

// Import the C ABI from the header files
pub const c = @cImport({
    @cInclude("source/extensions/dynamic_modules/abi.h");
    @cInclude("source/extensions/dynamic_modules/abi_version.h");
});

// Re-export common types with Zig-friendly names
pub const AbiVersionPtr = c.envoy_dynamic_module_type_abi_version_envoy_ptr;
pub const HttpFilterConfigEnvoyPtr = c.envoy_dynamic_module_type_http_filter_config_envoy_ptr;
pub const HttpFilterConfigModulePtr = c.envoy_dynamic_module_type_http_filter_config_module_ptr;
pub const HttpFilterPerRouteConfigModulePtr = c.envoy_dynamic_module_type_http_filter_per_route_config_module_ptr;
pub const HttpFilterEnvoyPtr = c.envoy_dynamic_module_type_http_filter_envoy_ptr;
pub const HttpFilterModulePtr = c.envoy_dynamic_module_type_http_filter_module_ptr;
pub const HttpFilterSchedulerModulePtr = c.envoy_dynamic_module_type_http_filter_scheduler_module_ptr;
pub const BufferModulePtr = c.envoy_dynamic_module_type_buffer_module_ptr;
pub const BufferEnvoyPtr = c.envoy_dynamic_module_type_buffer_envoy_ptr;

// Re-export structs
pub const EnvoyBuffer = c.envoy_dynamic_module_type_envoy_buffer;
pub const ModuleBuffer = c.envoy_dynamic_module_type_module_buffer;
pub const ModuleHttpHeader = c.envoy_dynamic_module_type_module_http_header;
pub const HttpHeader = c.envoy_dynamic_module_type_http_header;

// Re-export enums
pub const FilterHeadersStatus = c.envoy_dynamic_module_type_on_http_filter_request_headers_status;
pub const FilterDataStatus = c.envoy_dynamic_module_type_on_http_filter_request_body_status;
pub const FilterTrailersStatus = c.envoy_dynamic_module_type_on_http_filter_request_trailers_status;
pub const LogLevel = c.envoy_dynamic_module_type_log_level;

/// Wrapper around Envoy's buffer type for safer Zig usage
pub const EnvoyBufferView = struct {
    ptr: [*]u8,
    len: usize,

    pub fn fromEnvoyBuffer(buf: EnvoyBuffer) EnvoyBufferView {
        return .{
            .ptr = @ptrCast(buf.ptr),
            .len = buf.length,
        };
    }

    pub fn toSlice(self: EnvoyBufferView) []u8 {
        return self.ptr[0..self.len];
    }

    pub fn toConstSlice(self: EnvoyBufferView) []const u8 {
        return self.ptr[0..self.len];
    }
};

/// Wrapper for module-owned buffers
pub const ModuleBufferView = struct {
    ptr: [*]u8,
    len: usize,

    pub fn fromModuleBuffer(buf: ModuleBuffer) ModuleBufferView {
        return .{
            .ptr = @ptrCast(buf.ptr),
            .len = buf.length,
        };
    }

    pub fn fromSlice(slice: []const u8) ModuleBuffer {
        return .{
            .ptr = @constCast(@ptrCast(slice.ptr)),
            .length = slice.len,
        };
    }

    pub fn toSlice(self: ModuleBufferView) []u8 {
        return self.ptr[0..self.len];
    }
};

/// Wrapper for HTTP headers
pub const HttpHeaderView = struct {
    key: []const u8,
    value: []const u8,

    pub fn fromHttpHeader(header: HttpHeader) HttpHeaderView {
        return .{
            .key = @as([*]const u8, @ptrCast(header.key_ptr))[0..header.key_length],
            .value = @as([*]const u8, @ptrCast(header.value_ptr))[0..header.value_length],
        };
    }

    pub fn toModuleHttpHeader(self: HttpHeaderView) ModuleHttpHeader {
        return .{
            .key_ptr = @constCast(@ptrCast(self.key.ptr)),
            .key_length = self.key.len,
            .value_ptr = @constCast(@ptrCast(self.value.ptr)),
            .value_length = self.value.len,
        };
    }
};

/// Logging functions
pub fn log(level: LogLevel, message: []const u8) void {
    c.envoy_dynamic_module_callback_log(level, message.ptr, message.len);
}

pub fn logEnabled(level: LogLevel) bool {
    return c.envoy_dynamic_module_callback_log_enabled(level);
}

/// Convenience logging functions
pub fn logTrace(comptime fmt: []const u8, args: anytype) void {
    logFormatted(c.envoy_dynamic_module_type_log_level_Trace, fmt, args);
}

pub fn logDebug(comptime fmt: []const u8, args: anytype) void {
    logFormatted(c.envoy_dynamic_module_type_log_level_Debug, fmt, args);
}

pub fn logInfo(comptime fmt: []const u8, args: anytype) void {
    logFormatted(c.envoy_dynamic_module_type_log_level_Info, fmt, args);
}

pub fn logWarn(comptime fmt: []const u8, args: anytype) void {
    logFormatted(c.envoy_dynamic_module_type_log_level_Warn, fmt, args);
}

pub fn logError(comptime fmt: []const u8, args: anytype) void {
    logFormatted(c.envoy_dynamic_module_type_log_level_Error, fmt, args);
}

pub fn logCritical(comptime fmt: []const u8, args: anytype) void {
    logFormatted(c.envoy_dynamic_module_type_log_level_Critical, fmt, args);
}

fn logFormatted(level: LogLevel, comptime fmt: []const u8, args: anytype) void {
    if (!logEnabled(level)) return;

    var buf: [4096]u8 = undefined;
    const message = std.fmt.bufPrint(&buf, fmt, args) catch |err| {
        // If formatting fails, log the error
        const error_msg = std.fmt.bufPrint(&buf, "Log formatting failed: {}", .{err}) catch return;
        c.envoy_dynamic_module_callback_log(c.envoy_dynamic_module_type_log_level_Error, error_msg.ptr, error_msg.len);
        return;
    };

    c.envoy_dynamic_module_callback_log(level, message.ptr, message.len);
}

/// Interface for HTTP filter configuration
pub const HttpFilterConfig = struct {
    ptr: HttpFilterConfigModulePtr,
    vtable: *const VTable,

    pub const VTable = struct {
        /// Create a new HTTP filter for a stream
        newHttpFilter: *const fn (
            self: HttpFilterConfigModulePtr,
            envoy_filter: HttpFilterEnvoyPtr,
        ) ?HttpFilterModulePtr,

        /// Destroy the filter config
        destroy: *const fn (self: HttpFilterConfigModulePtr) void,
    };

    pub fn init(ptr: HttpFilterConfigModulePtr, vtable: *const VTable) HttpFilterConfig {
        return .{ .ptr = ptr, .vtable = vtable };
    }

    pub fn newHttpFilter(self: *const HttpFilterConfig, envoy_filter: HttpFilterEnvoyPtr) ?HttpFilterModulePtr {
        return self.vtable.newHttpFilter(self.ptr, envoy_filter);
    }

    pub fn destroy(self: *const HttpFilterConfig) void {
        self.vtable.destroy(self.ptr);
    }
};

/// Interface for HTTP per-route filter configuration
pub const HttpFilterPerRouteConfig = struct {
    ptr: HttpFilterPerRouteConfigModulePtr,
    vtable: *const VTable,

    pub const VTable = struct {
        /// Destroy the per-route config
        destroy: *const fn (self: HttpFilterPerRouteConfigModulePtr) void,
    };

    pub fn init(ptr: HttpFilterPerRouteConfigModulePtr, vtable: *const VTable) HttpFilterPerRouteConfig {
        return .{ .ptr = ptr, .vtable = vtable };
    }

    pub fn destroy(self: *const HttpFilterPerRouteConfig) void {
        self.vtable.destroy(self.ptr);
    }
};

/// Interface for HTTP filters
pub const HttpFilter = struct {
    ptr: HttpFilterModulePtr,
    vtable: *const VTable,

    pub const VTable = struct {
        /// Called when request headers are received
        onRequestHeaders: ?*const fn (
            self: HttpFilterModulePtr,
            envoy_filter: HttpFilterEnvoyPtr,
            end_of_stream: bool,
        ) FilterHeadersStatus,

        /// Called when request body data is received
        onRequestBody: ?*const fn (
            self: HttpFilterModulePtr,
            envoy_filter: HttpFilterEnvoyPtr,
            end_of_stream: bool,
        ) FilterDataStatus,

        /// Called when request trailers are received
        onRequestTrailers: ?*const fn (
            self: HttpFilterModulePtr,
            envoy_filter: HttpFilterEnvoyPtr,
        ) FilterTrailersStatus,

        /// Called when response headers are received
        onResponseHeaders: ?*const fn (
            self: HttpFilterModulePtr,
            envoy_filter: HttpFilterEnvoyPtr,
            end_of_stream: bool,
        ) FilterHeadersStatus,

        /// Called when response body data is received
        onResponseBody: ?*const fn (
            self: HttpFilterModulePtr,
            envoy_filter: HttpFilterEnvoyPtr,
            end_of_stream: bool,
        ) FilterDataStatus,

        /// Called when response trailers are received
        onResponseTrailers: ?*const fn (
            self: HttpFilterModulePtr,
            envoy_filter: HttpFilterEnvoyPtr,
        ) FilterTrailersStatus,

        /// Destroy the filter
        destroy: *const fn (self: HttpFilterModulePtr) void,
    };

    pub fn init(ptr: HttpFilterModulePtr, vtable: *const VTable) HttpFilter {
        return .{ .ptr = ptr, .vtable = vtable };
    }

    pub fn destroy(self: *const HttpFilter) void {
        self.vtable.destroy(self.ptr);
    }
};

/// Wrapper around Envoy's HTTP filter config pointer
pub const EnvoyHttpFilterConfig = struct {
    ptr: HttpFilterConfigEnvoyPtr,

    pub fn init(ptr: HttpFilterConfigEnvoyPtr) EnvoyHttpFilterConfig {
        return .{ .ptr = ptr };
    }

    /// Get most specific per-route config
    pub fn getMostSpecificRouteConfig(self: *const EnvoyHttpFilterConfig, filter: HttpFilterEnvoyPtr) ?HttpFilterPerRouteConfigModulePtr {
        return c.envoy_dynamic_module_callback_get_most_specific_route_config(self.ptr, filter);
    }
};

/// Helper to create program init function
pub fn programInit(
    comptime initFn: fn () bool,
    comptime newHttpFilterConfigFn: anytype,
) callconv(.C) ?[*:0]const u8 {
    // Store the function pointers in thread-local or global storage
    // This is a simplified version - in production you'd want proper storage
    if (!initFn()) {
        return null;
    }
    return c.kAbiVersion;
}

/// Helper structure to store callbacks
var httpFilterConfigCallback: ?*const anyopaque = null;
var httpFilterPerRouteConfigCallback: ?*const anyopaque = null;

/// Register HTTP filter config callback
pub fn registerHttpFilterConfigCallback(callback: anytype) void {
    httpFilterConfigCallback = @ptrCast(&callback);
}

/// Register HTTP filter per-route config callback
pub fn registerHttpFilterPerRouteConfigCallback(callback: anytype) void {
    httpFilterPerRouteConfigCallback = @ptrCast(&callback);
}

test "basic types" {
    const testing = std.testing;

    // Test that buffer conversion works
    const test_data = "hello world";
    const module_buf = ModuleBufferView.fromSlice(test_data);
    try testing.expectEqual(test_data.len, module_buf.length);
}
