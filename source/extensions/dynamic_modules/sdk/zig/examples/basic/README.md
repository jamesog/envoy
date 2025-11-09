# Basic Envoy Dynamic Module Example in Zig

This is a simple example demonstrating how to write an Envoy HTTP filter as a dynamic module using Zig.

## What This Example Does

This example creates a basic HTTP filter that:
- Logs when it's initialized
- Logs when it processes request and response headers
- Logs when it processes request and response body data
- Logs when it processes trailers
- Passes all traffic through without modification (returns Continue status)

## Building

### Using Zig Build System

```bash
# From this directory
zig build -Denvoy-root=/path/to/envoy

# The compiled module will be in zig-out/lib/
```

### Build Options

- `-Doptimize=ReleaseFast`: Build with optimizations
- `-Doptimize=Debug`: Build with debug symbols
- `-Denvoy-root=/path/to/envoy`: Specify the path to the Envoy source root (defaults to `../../../..`)

## Using the Module

1. Build the module as shown above
2. Configure Envoy to load the dynamic module:

```yaml
# envoy.yaml
static_resources:
  listeners:
  - address:
      socket_address:
        address: 0.0.0.0
        port_value: 8080
    filter_chains:
    - filters:
      - name: envoy.filters.network.http_connection_manager
        typed_config:
          "@type": type.googleapis.com/envoy.extensions.filters.network.http_connection_manager.v3.HttpConnectionManager
          stat_prefix: ingress_http
          codec_type: AUTO
          route_config:
            name: local_route
            virtual_hosts:
            - name: backend
              domains: ["*"]
              routes:
              - match: { prefix: "/" }
                route: { cluster: service }
          http_filters:
          - name: envoy.filters.http.dynamic_module
            typed_config:
              "@type": type.googleapis.com/envoy.extensions.filters.http.dynamic_modules.v3.DynamicModuleFilter
              dynamic_module_config:
                name: basic_example
                do_not_close: true
                library_path: /path/to/libenvoy_zig_basic_example.so
                library_id: basic_example_v1
              filter_name: basic_filter
              filter_config: "{}"
          - name: envoy.filters.http.router
            typed_config:
              "@type": type.googleapis.com/envoy.extensions.filters.http.router.v3.Router
  clusters:
  - name: service
    connect_timeout: 5s
    type: STATIC
    lb_policy: ROUND_ROBIN
    load_assignment:
      cluster_name: service
      endpoints:
      - lb_endpoints:
        - endpoint:
            address:
              socket_address:
                address: 127.0.0.1
                port_value: 8000
```

3. Run Envoy:

```bash
envoy -c envoy.yaml --log-level debug
```

4. Send a request:

```bash
curl http://localhost:8080/
```

5. Check the Envoy logs - you should see log messages from the Zig module:

```
[dynamic_modules] Basic example module initialized successfully!
[dynamic_modules] Creating new filter config: basic_filter
[dynamic_modules] Processing request headers (request #1)
[dynamic_modules] Processing response headers
```

## Code Structure

- `envoy_dynamic_module_on_program_init()`: Module initialization, called once when loaded
- `BasicHttpFilterConfig`: Configuration for the HTTP filter, created per filter chain
- `BasicHttpFilter`: The actual filter instance, created per HTTP stream
- Request/response handlers: Process HTTP traffic as it flows through Envoy

## Next Steps

Try modifying this example to:
- Parse the configuration JSON
- Modify request/response headers
- Inspect body data
- Implement custom logic based on headers or body content

See the [Zig SDK README](../../README.md) for more details on the SDK API.
