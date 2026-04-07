const std = @import("std");
const Vapor = @import("../Vapor.zig");
const isWasi = Vapor.isWasi;
const Wasm = Vapor.Wasm;
const utils = @import("../utils.zig");
const hashKey = utils.hashKey;
const getUnderlyingType = utils.getUnderlyingType;
const getUnderlyingValue = utils.getUnderlyingValue;
const DynamicObject = @import("../Dynamic.zig");
pub const Json = @import("JSON.zig");

pub const Kit = @This();

pub fn init() void {
    Vapor.fetch_registry = std.AutoHashMap(u32, *Kit.FetchNode).init(Vapor.arena(.persist)); ///// This bad boy is 19kb addition
    Fetch.init();
}

pub const Window = struct {
    pub fn openTab(url: []const u8) void {
        if (isWasi) {
            Wasm.windowOpenWasm(url.ptr, url.len);
        }
    }
};

/// This function takes a slice of json and parses it into a struct
/// # Parameters:
/// - `T`: struct type
/// - `slice`: []const u8,
///
/// # Returns:
/// T: struct
///
/// # Usage:
/// ```zig
/// const my_struct = try Kit.glue(MyStruct, json_slice);
/// ```
/// NOTE: This function dellocates the parsed struct, after use, clone it if you need it beyond the scope of the function
pub fn glue(comptime T: type, slice: []const u8) !T {
    const parsed = std.json.parseFromSlice(
        T,
        Vapor.getFrameAllocator(),
        slice,
        .{},
    ) catch return error.MalformedJson;

    return parsed.value;
}

pub const String = struct {
    start: usize,
    len: usize,
    capacity: usize,
    contents: [65535]u8 = undefined,

    pub fn new() String {
        return String{
            .start = 0,
            .len = 0,
            .capacity = 65535,
        };
    }

    pub fn init(initial: []const u8) String {
        var new_string = String.new();
        new_string.append_str(initial);
        return new_string;
    }

    pub fn append_str(self: *String, input: []const u8) void {
        const required_len = self.len + input.len;
        const required_capacity = required_len + (10 - required_len % 10);

        // Case 1: contents exists and is big enough
        if (required_capacity <= self.capacity) {
            @memcpy(self.contents[self.len .. self.len + input.len], input);
            self.len = required_len;
        }
    }
};

pub fn fastJson(comptime T: type, data: T, writer: *String) !void {
    const fields = @typeInfo(T).@"struct".fields;
    writer.append_str("{");
    inline for (fields, 0..) |f, j| {
        const field_value_optional = @field(data, f.name);
        const is_optional = @typeInfo(f.type) == .optional;
        const field_type: type = getUnderlyingType(@TypeOf(field_value_optional));
        if (!is_optional or (is_optional and field_value_optional != null)) {
            const field_value = getUnderlyingValue(field_type, @TypeOf(field_value_optional), field_value_optional);
            writer.append_str("\"");
            writer.append_str(f.name);
            writer.append_str("\"");
            writer.append_str(": ");
            switch (field_type) {
                i8, i16, i32, i64, i128, f16, f32, f64, f128 => {
                    const max_len = 20;
                    var buf: [max_len]u8 = undefined;
                    const value = try std.fmt.bufPrint(&buf, "{any}", .{field_value});
                    writer.append_str(value);
                },
                bool => {
                    if (field_value) {
                        writer.append_str("true");
                    } else {
                        writer.append_str("false");
                    }
                },
                [][]const u8, []const []const u8 => {
                    writer.append_str("[");
                    for (field_value, 0..) |e, i| {
                        writer.append_str("\"");
                        writer.append_str(e);
                        writer.append_str("\"");
                        if (i < field_value.len - 1) writer.append_str(",");
                    }
                    writer.append_str("]");
                },
                []i8, []i16, []i32, []i64, []i128, []f16, []f32, []f64, []f128 => {
                    writer.append_str("[");
                    for (field_value, 0..) |e, i| {
                        const max_len = 4;
                        var buf: [max_len]u8 = undefined;
                        const value = try std.fmt.bufPrint(&buf, "{any}", .{e});
                        writer.append_str(value);
                        if (i > 0) writer.append_str(",");
                    }
                    writer.append_str("]");
                },
                []const u8 => {
                    writer.append_str("\"");
                    writer.append_str(field_value);
                    writer.append_str("\"");
                },
                else => {
                    switch (@typeInfo(field_type)) {
                        .@"struct" => {
                            var inner_writer = String.new();
                            try fastJson(field_type, field_value, &inner_writer);
                            const payload = inner_writer.contents[0..inner_writer.len];
                            writer.append_str(payload);
                        },
                        else => {},
                    }
                },
            }
            if (j < fields.len - 1) writer.append_str(", ");
        }
    }
    writer.append_str("}");
}

const AbortController = enum {
    signal,
};

pub const FetchAction = struct {
    runFn: FetchActionProto,
    deinitFn: FetchNodeProto,
    allocator: FetchNodeProtoAlloc,
};

const FetchActionProto = *const fn (*FetchAction, Response) void;
const FetchNodeProto = *const fn (*FetchNode) void;
const FetchNodeProtoAlloc = *const fn (*FetchNode) std.mem.Allocator;

pub const FetchNode = struct { data: FetchAction };

const Future = struct {
    id: u32,
    pub fn await(future: *@This()) ?Response {
        if (Vapor.response_registry.get(future.id)) |resp| {
            return resp;
        }
        _ = Wasm.tick(future.id);
        return null;
    }
};

pub fn fetchAwait(url: []const u8, http_req: HttpReq) *Future {
    var writer = String.new();
    writer.append_str("{\n\"method\": ");
    writer.append_str("\"");
    writer.append_str(@tagName(http_req.method));
    writer.append_str("\"");
    if (http_req.headers) |headers| {
        writer.append_str(",\n\"headers\": {\n");
        constructHeaders(headers, http_req.extra_headers, &writer);
        writer.append_str("\n}");
    } else if (http_req.extra_headers.len > 0) {
        writer.append_str(",\n\"headers\": {\n");
        var count: usize = 1;
        for (http_req.extra_headers) |header| {
            writer.append_str("\"");
            writer.append_str(header.name);
            writer.append_str("\"");
            writer.append_str(": ");
            writer.append_str("\"");
            writer.append_str(header.value);
            writer.append_str("\"");
            if (count < http_req.extra_headers.len) {
                writer.append_str(",\n");
            }
            count += 1;
        }
        writer.append_str("\n}");
    }

    if (http_req.credentials) |credentials| {
        writer.append_str(",\n\"credentials\": ");
        writer.append_str("\"");
        writer.append_str(credentials);
        writer.append_str("\"");
    }

    if (http_req.body) |body| {
        writer.append_str(",\n\"body\": ");
        switch (http_req.body_type) {
            .string => {
                writer.append_str("\"");
                writer.append_str(body);
                writer.append_str("\"");
            },
            .json => {
                writer.append_str(body);
            },
        }
    }
    writer.append_str("\n}");

    const final = writer.contents[0..writer.len];
    const json = std.json.fmt(final, .{ .whitespace = .indent_1 }).value;

    const id = Vapor.fetch_registry.count() + 1;

    const future = Vapor.allocator_global.create(Future) catch |err| {
        Vapor.println("Error could not create closure {any}\n ", .{err});
        unreachable;
    };
    future.* = .{
        .id = id,
    };

    if (Vapor.isWasi) {
        fetchWasm(url.ptr, url.len, id, json.ptr, json.len);
    }
    return future;
}

pub const Fetch = struct {
    pub const RequestKey = struct {
        url: []const u8,
        method: Methods,
    };

    pub const RequestKeyContext = struct {
        pub fn hash(_: RequestKeyContext, key: RequestKey) u64 {
            var h = std.hash.Wyhash.init(0);
            h.update(key.url);
            h.update(std.mem.asBytes(&key.method));
            return h.final();
        }

        pub fn eql(_: RequestKeyContext, a: RequestKey, b: RequestKey) bool {
            return a.method == b.method and std.mem.eql(u8, a.url, b.url);
        }
    };

    pub const RequestEntry = struct {
        arena: std.heap.ArenaAllocator,
        callback_id: u32,
        // The response data lives in `arena` — valid until next fetch to same key
        last_response: ?Response = null,

        pub fn allocator(self: *RequestEntry) std.mem.Allocator {
            return self.arena.allocator();
        }

        /// Reset the arena, invalidating all previous response data
        pub fn reset(self: *RequestEntry) void {
            _ = self.arena.reset(.retain_capacity);
            self.last_response = null;
        }

        pub fn deinit(self: *RequestEntry) void {
            self.arena.deinit();
        }
    };

    // Module-level registry: URL+method -> entry with its own arena
    pub var request_registry: std.HashMap(
        RequestKey,
        *RequestEntry,
        RequestKeyContext,
        80, // max load percentage
    ) = undefined;

    pub fn init() void {
        request_registry = std.HashMap(RequestKey, *RequestEntry, RequestKeyContext, 80).init(Vapor.arena(.persist));
    }

    _cbs: []*const fn (Response) void = &.{},
    http_req: HttpReq,
    url: []const u8,
    debug: bool = false,
    force_error: bool = false,

    pub fn fetch(url: []const u8, http_req: HttpReq) Fetch {
        return .{
            .http_req = http_req,
            .url = url,
        };
    }

    fn getOrCreateEntry(key: RequestKey) *RequestEntry {
        if (request_registry.get(key)) |existing| {
            // Same endpoint hit again — reset the arena, old response data dies
            existing.reset();
            return existing;
        }

        // First time hitting this endpoint — create a new entry
        // The entry itself lives in the global allocator (it's long-lived)
        const entry = Vapor.allocator_global.create(RequestEntry) catch unreachable;
        entry.* = .{
            .arena = std.heap.ArenaAllocator.init(Vapor.allocator_global),
            .callback_id = 0,
        };

        // Key strings need to outlive the frame, so dupe into global
        const owned_key = RequestKey{
            .url = Vapor.allocator_global.dupe(u8, key.url) catch unreachable,
            .method = key.method,
        };
        request_registry.put(owned_key, entry) catch unreachable;
        return entry;
    }

    pub fn handle(self: *const Fetch, cb: fn (Response) void) void {
        const http_req = self.http_req;
        const url = self.url;

        const key = RequestKey{ .url = url, .method = http_req.method };
        const entry = getOrCreateEntry(key);

        // Build the JSON request using the entry's arena (gets reset next fetch)
        const arena_alloc = entry.allocator();
        var writer = String.new();
        writer.append_str("{\n\"method\": \"");
        writer.append_str(@tagName(http_req.method));
        writer.append_str("\"");

        if (http_req.headers) |headers| {
            writer.append_str(",\n\"headers\": {\n");
            constructHeaders(headers, http_req.extra_headers, &writer);
            writer.append_str("\n}");
        } else if (http_req.extra_headers.len > 0) {
            writer.append_str(",\n\"headers\": {\n");
            var count: usize = 1;
            for (http_req.extra_headers) |header| {
                writer.append_str("\"");
                writer.append_str(header.name);
                writer.append_str("\": \"");
                writer.append_str(header.value);
                writer.append_str("\"");
                if (count < http_req.extra_headers.len) {
                    writer.append_str(",\n");
                }
                count += 1;
            }
            writer.append_str("\n}");
        }

        if (http_req.credentials) |credentials| {
            writer.append_str(",\n\"credentials\": \"");
            writer.append_str(credentials);
            writer.append_str("\"");
        }

        if (http_req.body) |body| {
            writer.append_str(",\n\"body\": ");
            switch (http_req.body_type) {
                .string => {
                    var io_writer = std.Io.Writer.Allocating.init(arena_alloc);
                    std.json.Stringify.encodeJsonString(body, .{}, &io_writer.writer) catch unreachable;
                    defer io_writer.deinit();
                    writer.append_str(io_writer.written());
                },
                .json => {
                    writer.append_str(body);
                },
            }
        }
        writer.append_str("\n}");

        const final_str = writer.contents[0..writer.len];
        const json = std.json.fmt(final_str, .{ .whitespace = .indent_1 }).value;

        // Callback closure — allocated globally since the registry needs stable pointers
        // but the callback itself parses into the entry's arena
        const Closure = struct {
            fetch_node: FetchNode = .{ .data = .{ .runFn = runFn, .deinitFn = deinitFn, .allocator = allocator } },
            entry_ptr: *RequestEntry,

            fn runFn(action: *FetchAction, resp: Response) void {
                // Store the response in the entry so it's accessible between requests
                const node: *FetchNode = @alignCast(@fieldParentPtr("data", action));
                const self_closure: *@This() = @alignCast(@fieldParentPtr("fetch_node", node));
                self_closure.entry_ptr.last_response = resp;
                @call(.auto, cb, .{resp});
            }

            fn deinitFn(node: *FetchNode) void {
                const closure: *@This() = @alignCast(@fieldParentPtr("fetch_node", node));
                Vapor.allocator_global.destroy(closure);
            }

            fn allocator(node: *FetchNode) std.mem.Allocator {
                const closure: *@This() = @alignCast(@fieldParentPtr("fetch_node", node));
                return closure.entry_ptr.allocator();
            }
        };

        const closure = Vapor.allocator_global.create(Closure) catch unreachable;
        closure.* = .{ .entry_ptr = entry };

        const id = Vapor.fetch_registry.count() + 1;
        entry.callback_id = id;

        Vapor.fetch_registry.put(id, &closure.fetch_node) catch |err| {
            Vapor.printlnSrcErr("Registry error {any}\n", .{err}, @src());
            return;
        };

        if (self.debug) {
            std.log.info("Fetching {s}\n", .{url});
            std.log.info("Request: {s}\n", .{json});
        }

        if (self.force_error) {
            const resp = Response{ .Err = .{
                .code = 404,
                .message = "Sample error",
                .type = "",
                .ok = false,
                .url = url,
                .redirected = false,
                .body = "",
                .headers = null,
                .content_type = "",
                .content_length = 0,
                .elapsed_ms = 0,
                .error_kind = "",
                .error_name = "",
            } };
            @call(.auto, cb, .{resp});
            return;
        }

        if (Vapor.isWasi) {
            fetchWasm(url.ptr, url.len, id, json.ptr, json.len);
        }
    }
};

// pub const Fetch = struct {
//     _cbs: []*const fn (Response) void = &.{},
//     http_req: HttpReq,
//     url: []const u8,
//
//     const FetchEntry = struct {
//         node: *FetchNode,
//         arena: std.mem.Allocator,
//     };
//
//     pub fn fetch(url: []const u8, http_req: HttpReq) Fetch {
//         return .{
//             .http_req = http_req,
//             .url = url,
//         };
//     }
//
//     pub fn handle(self: *const Fetch, cb: fn (Response) void) void {
//         const http_req = self.http_req;
//         const url = self.url;
//
//         var writer = String.new();
//         writer.append_str("{\n\"method\": ");
//         writer.append_str("\"");
//         writer.append_str(@tagName(http_req.method));
//         writer.append_str("\"");
//         if (http_req.headers) |headers| {
//             writer.append_str(",\n\"headers\": {\n");
//             constructHeaders(headers, http_req.extra_headers, &writer);
//             writer.append_str("\n}");
//         } else if (http_req.extra_headers.len > 0) {
//             writer.append_str(",\n\"headers\": {\n");
//             var count: usize = 1;
//             for (http_req.extra_headers) |header| {
//                 writer.append_str("\"");
//                 writer.append_str(header.name);
//                 writer.append_str("\"");
//                 writer.append_str(": ");
//                 writer.append_str("\"");
//                 writer.append_str(header.value);
//                 writer.append_str("\"");
//                 if (count < http_req.extra_headers.len) {
//                     writer.append_str(",\n");
//                 }
//                 count += 1;
//             }
//             writer.append_str("\n}");
//         }
//
//         if (http_req.credentials) |credentials| {
//             writer.append_str(",\n\"credentials\": ");
//             writer.append_str("\"");
//             writer.append_str(credentials);
//             writer.append_str("\"");
//         }
//
//         if (http_req.body) |body| {
//             writer.append_str(",\n\"body\": ");
//             switch (http_req.body_type) {
//                 .string => {
//                     var io_writer = std.Io.Writer.Allocating.init(Vapor.allocator_global);
//                     std.json.Stringify.encodeJsonString(body, .{}, &io_writer.writer) catch unreachable;
//                     defer io_writer.deinit();
//                     writer.append_str(io_writer.written());
//                 },
//                 .json => {
//                     writer.append_str(body);
//                 },
//             }
//         }
//         writer.append_str("\n}");
//
//         const final = writer.contents[0..writer.len];
//         const json = std.json.fmt(final, .{ .whitespace = .indent_1 }).value;
//
//         const Closure = struct {
//             fetch_node: FetchNode = .{ .data = .{ .runFn = runFn, .deinitFn = deinitFn } },
//             fn runFn(_: *FetchAction, resp: Response) void {
//                 @call(.auto, cb, .{resp});
//             }
//             fn deinitFn(node: *FetchNode) void {
//                 const closure: *@This() = @alignCast(@fieldParentPtr("fetch_node", node));
//                 Vapor.allocator_global.destroy(closure);
//             }
//         };
//
//         const closure = Vapor.allocator_global.create(Closure) catch |err| {
//             Vapor.println("Error could not create closure {any}\n ", .{err});
//             unreachable;
//         };
//         closure.* = .{};
//
//         const id = Vapor.fetch_registry.count() + 1;
//         Vapor.fetch_registry.put(id, &closure.fetch_node) catch |err| {
//             Vapor.println("Button Function Registry {any}\n", .{err});
//             return;
//         };
//         if (Vapor.isWasi) {
//             fetchWasm(url.ptr, url.len, id, json.ptr, json.len);
//         }
//         return;
//     }
// };

pub fn fetch(url: []const u8, cb: fn (Response) void, http_req: HttpReq) void {
    var writer = String.new();
    writer.append_str("{\n\"method\": ");
    writer.append_str("\"");
    writer.append_str(@tagName(http_req.method));
    writer.append_str("\"");
    if (http_req.headers) |headers| {
        writer.append_str(",\n\"headers\": {\n");
        constructHeaders(headers, http_req.extra_headers, &writer);
        writer.append_str("\n}");
    } else if (http_req.extra_headers.len > 0) {
        writer.append_str(",\n\"headers\": {\n");
        var count: usize = 1;
        for (http_req.extra_headers) |header| {
            writer.append_str("\"");
            writer.append_str(header.name);
            writer.append_str("\"");
            writer.append_str(": ");
            writer.append_str("\"");
            writer.append_str(header.value);
            writer.append_str("\"");
            if (count < http_req.extra_headers.len) {
                writer.append_str(",\n");
            }
            count += 1;
        }
        writer.append_str("\n}");
    }

    if (http_req.credentials) |credentials| {
        writer.append_str(",\n\"credentials\": ");
        writer.append_str("\"");
        writer.append_str(credentials);
        writer.append_str("\"");
    }

    if (http_req.body) |body| {
        writer.append_str(",\n\"body\": ");
        switch (http_req.body_type) {
            .string => {
                var io_writer = std.Io.Writer.Allocating.init(Vapor.allocator_global);
                std.json.Stringify.encodeJsonString(body, .{}, &io_writer.writer) catch unreachable;
                defer io_writer.deinit();
                writer.append_str(io_writer.written());
            },
            .json => {
                writer.append_str(body);
            },
        }
    }
    writer.append_str("\n}");

    const final = writer.contents[0..writer.len];
    const json = std.json.fmt(final, .{ .whitespace = .indent_1 }).value;

    const Closure = struct {
        fetch_node: FetchNode = .{ .data = .{ .runFn = runFn, .deinitFn = deinitFn } },
        fn runFn(_: *FetchAction, resp: Response) void {
            @call(.auto, cb, .{resp});
        }
        fn deinitFn(node: *FetchNode) void {
            const closure: *@This() = @alignCast(@fieldParentPtr("fetch_node", node));
            Vapor.allocator_global.destroy(closure);
        }
    };

    const closure = Vapor.allocator_global.create(Closure) catch |err| {
        Vapor.println("Error could not create closure {any}\n ", .{err});
        unreachable;
    };
    closure.* = .{};

    const id = Vapor.fetch_registry.count() + 1;
    Vapor.fetch_registry.put(id, &closure.fetch_node) catch |err| {
        Vapor.println("Button Function Registry {any}\n", .{err});
        return;
    };
    if (Vapor.isWasi) {
        fetchWasm(url.ptr, url.len, id, json.ptr, json.len);
    }
    // return id;
}

var last_time: i64 = 0;
pub fn throttle(delay: i64) bool {
    const current_time = std.time.milliTimestamp();
    if (current_time - last_time < delay) {
        return true;
    }
    last_time = current_time;
    return false;
}

extern fn fetchWasm(
    url_ptr: [*]const u8,
    url_len: usize,
    callback_id: usize,
    http_req_offset_ptr: [*]u8,
    size: usize,
) void;

extern fn fetchParamsWasm(
    url_ptr: [*]const u8,
    url_len: usize,
    callback_id: usize,
    http_req_offset_ptr: [*]u8,
    size: usize,
) void;

extern fn setWindowLocationWasm(
    url_ptr: [*]const u8,
    url_len: usize,
) void;

pub fn setWindowLocation(url: []const u8) void {
    if (isWasi) {
        setWindowLocationWasm(url.ptr, url.len);
    } else {
        Vapor.printlnSrc("Attempted to reroute, but not wasi {s}", .{url}, @src());
    }
}

extern fn navigateWasm(
    path_ptr: [*]const u8,
    path_len: usize,
) void;

pub fn navigate(path: []const u8) void {
    if (isWasi) {
        navigateWasm(path.ptr, path.len);
    } else {
        Vapor.printlnSrc("Attempted to reroute, but not wasi {s}", .{path}, @src());
    }
}

extern fn backWasm() void;

pub fn back() void {
    if (isWasi) {
        backWasm();
    } else {
        Vapor.printlnSrc("Attempted to reroute, but not wasi", .{}, @src());
    }
}

extern fn routePushWASM(
    path_ptr: [*]const u8,
    path_len: usize,
) void;

pub fn routePush(path: []const u8) void {
    if (isWasi) {
        routePushWASM(path.ptr, path.len);
    } else {
        Vapor.printlnSrc("Attempted to reroute, but not wasi {s}", .{path}, @src());
    }
}

extern fn getWindowInformationWasm() [*:0]u8;

pub fn getWindowPath() ?[]const u8 {
    if (isWasi) {
        return std.mem.span(getWindowInformationWasm());
    } else {
        return null;
    }
}

extern fn getWindowParamsWasm() [*:0]u8;

pub fn getWindowParams() ?[]const u8 {
    if (isWasi) {
        const params = getWindowParamsWasm();
        const params_str = std.mem.span(params);
        if (params_str.len == 0) {
            return null;
        } else {
            return params_str;
        }
    } else {
        Vapor.printlnSrc("Attempted to get params, but not wasi", .{}, @src());
        return null;
    }
}

pub fn findIndex(haystack: []const u8, needle: u8) ?usize {
    const vec_len = 16;
    const Vec16 = @Vector(16, u8);
    const splt_16: Vec16 = @splat(@as(u8, needle));
    if (haystack.len >= vec_len) {
        var i: usize = 0;
        while (i + vec_len <= haystack.len) : (i += vec_len) {
            const v = haystack[i..][0..vec_len].*;
            const vec: Vec16 = @bitCast(v);
            const mask = vec == splt_16;
            const bits: u16 = @bitCast(mask);
            if (bits != 0) {
                return i + @ctz(bits);
            }
        }
    }
    var i: usize = 0;
    while (i < haystack.len) : (i += 1) {
        if (haystack[i] == needle) return i;
    }
    return null;
}

fn decoder(encoded: []const u8, decoded: *std.array_list.Managed(u8)) !void {
    var i: usize = 0;
    while (i < encoded.len) : (i += 1) {
        if (encoded[i] == '%') {
            // Ensure there's enough room for two hex characters
            if (i + 2 >= encoded.len) {
                return error.InvalidInput;
            }

            const hex = encoded[i + 1 .. i + 3];
            const decodedByte = try std.fmt.parseInt(u8, hex, 16);
            try decoded.append(decodedByte);
            i += 2; // Skip over the two hex characters
        } else if (encoded[i] == '+') {
            // Replace '+' with a space
            try decoded.append(' ');
        } else {
            try decoded.append(encoded[i]);
        }
    }
}

pub fn parseParams(url: []const u8, allocator: std.mem.Allocator) !?std.StringHashMap([]const u8) {
    const params_start = findIndex(url, '?') orelse return null;

    var params = std.StringHashMap([]const u8).init(allocator);
    errdefer {
        // Clean up allocated values on error
        var it = params.valueIterator();
        while (it.next()) |value| {
            allocator.free(value.*);
        }
        params.deinit();
    }

    var pos = params_start + 1;

    while (pos < url.len) {
        // Find end of this pair
        const remaining = url[pos..];
        const param_pair_end = findIndex(remaining, '&') orelse remaining.len;
        const pair = remaining[0..param_pair_end];

        if (pair.len == 0) {
            pos += 1;
            continue;
        }

        // Find the separator
        const seperator = findIndex(pair, '=') orelse return error.SeperatorNotFound;

        const key_encoded = pair[0..seperator];
        const value_encoded = pair[seperator + 1 ..];

        // Decode key (also needs decoding!)
        var key_decoded = std.array_list.Managed(u8).init(allocator);
        defer key_decoded.deinit();
        try decoder(key_encoded, &key_decoded);
        const key = try key_decoded.toOwnedSlice();
        errdefer allocator.free(key);

        // Decode value
        var value_decoded = std.array_list.Managed(u8).init(allocator);
        defer value_decoded.deinit();
        try decoder(value_encoded, &value_decoded);
        const value = try value_decoded.toOwnedSlice();

        try params.put(key, value);

        pos += param_pair_end + 1; // +1 to skip the '&'
    }

    return params;
}

pub const HeadersHM = std.json.ArrayHashMap([]const u8);

pub const OkResponse = struct {
    code: u32,
    message: []const u8,
    type: []const u8,
    ok: bool,
    url: []const u8,
    redirected: bool,
    body: []const u8,
    headers: HeadersHM,
    content_type: []const u8,
    content_length: u32,
    elapsed_ms: u32,

    /// Try to parse body as JSON
    pub fn json(self: OkResponse, comptime T: type, allocator: std.mem.Allocator) !std.json.Parsed(T) {
        return std.json.parseFromSlice(T, allocator, self.body, .{});
    }

    pub fn isJson(self: OkResponse) bool {
        return std.mem.startsWith(u8, self.content_type, "application/json");
    }

    pub fn isRedirect(self: OkResponse) bool {
        return self.code >= 300 and self.code < 400;
    }

    pub fn isClientError(self: OkResponse) bool {
        return self.code >= 400 and self.code < 500;
    }

    pub fn isServerError(self: OkResponse) bool {
        return self.code >= 500;
    }

    pub fn header(self: OkResponse, key: []const u8) ?[]const u8 {
        return self.headers.map.get(key);
    }

    pub fn bind(self: *const OkResponse, comptime T: type, allocator: std.mem.Allocator) !T {
        const parsed = std.json.parseFromSlice(
            T,
            allocator,
            self.body,
            .{},
        ) catch return error.MalformedJson;

        return parsed.value;
    }
};

pub const ErrorKind = enum {
    network,
    timeout,
    aborted,
    cors,
    dns,
    tls,
    http,
    unknown,
};

pub const ErrResponse = struct {
    code: u32,
    type: []const u8,
    message: []const u8,
    ok: bool,
    url: []const u8,
    redirected: bool,
    body: []const u8,
    headers: ?HeadersHM,
    content_type: []const u8,
    content_length: u32,
    elapsed_ms: u32,
    error_kind: []const u8,
    error_name: []const u8,

    pub fn kind(self: ErrResponse) ErrorKind {
        const map = std.StaticStringMap(ErrorKind).initComptime(.{
            .{ "network", .network },
            .{ "timeout", .timeout },
            .{ "aborted", .aborted },
            .{ "cors", .cors },
            .{ "dns", .dns },
            .{ "tls", .tls },
            .{ "http", .http },
        });
        return map.get(self.error_kind) orelse .unknown;
    }

    pub fn isTimeout(self: ErrResponse) bool {
        return self.kind() == .timeout;
    }

    pub fn isNetworkError(self: ErrResponse) bool {
        return self.kind() == .network;
    }

    pub fn clone(self: ErrResponse, arena_type: Vapor.ArenaType) ErrResponse {
        var allocated_headers: ?std.json.ArrayHashMap([]const u8) = null;
        const allocator = Vapor.arena(arena_type);
        if (self.headers) |headers| {
            allocated_headers = undefined;
            allocated_headers.?.map = headers.map.clone(allocator) catch unreachable;
        }

        return ErrResponse{
            .code = self.code,
            .type = Vapor.dupe(self.type, arena_type),
            .message = Vapor.dupe(self.message, arena_type),
            .ok = self.ok,
            .url = Vapor.dupe(self.url, arena_type),
            .redirected = self.redirected,
            .body = Vapor.dupe(self.body, arena_type),
            .headers = allocated_headers,
            .content_type = Vapor.dupe(self.content_type, arena_type),
            .content_length = self.content_length,
            .elapsed_ms = self.elapsed_ms,
            .error_kind = Vapor.dupe(self.error_kind, arena_type),
            .error_name = Vapor.dupe(self.error_name, arena_type),
        };
    }

    pub fn deinit(self: *ErrResponse, arena_type: Vapor.ArenaType) void {
        const allocator = Vapor.arena(arena_type);
        allocator.free(self.type);
        allocator.free(self.message);
        allocator.free(self.url);
        allocator.free(self.content_type);
        allocator.free(self.error_kind);
        allocator.free(self.error_name);
        if (self.headers) |*headers| {
            headers.deinit(allocator);
        }
    }
};

pub const Response = union(enum) {
    Ok: OkResponse,
    Err: ErrResponse,

    pub fn isOk(self: Response) bool {
        return self == .Ok;
    }

    pub fn isErr(self: Response) bool {
        return self == .Err;
    }

    /// Returns the status code (0 for network errors)
    pub fn statusCode(self: Response) u32 {
        return switch (self) {
            .Ok => |r| r.code,
            .Err => |r| r.code,
        };
    }

    /// Returns the URL (final URL after redirects for ok)
    pub fn url(self: Response) []const u8 {
        return switch (self) {
            .Ok => |r| r.url,
            .Err => |r| r.url,
        };
    }

    /// Returns elapsed time in ms
    pub fn elapsedMs(self: Response) u32 {
        return switch (self) {
            .Ok => |r| r.elapsed_ms,
            .Err => |r| r.elapsed_ms,
        };
    }

    /// Unwrap the ok response or return null
    pub fn ok(self: Response) ?OkResponse {
        return switch (self) {
            .Ok => |r| r,
            .Err => null,
        };
    }

    /// Unwrap the err response or return null
    pub fn err(self: Response) ?ErrResponse {
        return switch (self) {
            .Err => |r| r,
            .Ok => null,
        };
    }
};

// pub fn resumeCallback(id: u32, resp_ptr: [*:0]u8) callconv(.c) void {
//     const resp = std.mem.span(resp_ptr);
//     const parsed_value = std.json.parseFromSlice(Response, Vapor.arena(.persist), resp, .{}) catch |err| {
//         Vapor.printlnSrcErr("Error could not parse response {any} {s}\n", .{ err, resp }, @src());
//         return;
//     };
//
//     const json_resp: Response = parsed_value.value;
//
//     if (json_resp.isErr()) {
//         const e = json_resp.err().?;
//         Vapor.printlnErr(
//             "\nFETCH ERROR [{s}] {s}\n  URL: {s}\n  Code: {d} - {s}\n  Time: {d}ms\n",
//             .{ e.error_kind, e.error_name, e.url, e.code, e.message, e.elapsed_ms },
//         );
//     }
//
//     const node = Vapor.fetch_registry.get(id) orelse return;
//     @call(.auto, node.data.runFn, .{ &node.data, json_resp });
// }

pub const HttpReqOffset = struct {
    method_ptr: [*]const u8 = undefined,
    method_len: usize = 0,
    content_type_ptr: ?[*]const u8 = null,
    content_type_len: ?usize = null,
    authorization_ptr: ?[*]const u8 = null,
    authorization_len: ?usize = null,
    accept_ptr: ?[*]const u8 = null,
    accept_len: ?usize = null,
    user_agent_ptr: ?[*]const u8 = null,
    user_agent_len: ?usize = null,
    body_ptr: ?[*]const u8 = null,
    body_len: ?usize = null,
    extra_headers_ptr: ?[*]const HttpHeader = null,
    extra_headers_len: ?usize = null,
    mode_ptr: ?[*]const u8 = null,
    mode_len: ?usize = null,
    redirect_ptr: ?[*]const u8 = null,
    redirect_len: ?usize = null,
    referrer_policy_ptr: ?[*]const u8 = null,
    referrer_policy_len: ?usize = null,
    integrity_ptr: ?[*]const u8 = null,
    integrity_len: ?usize = null,
    use_credentials: bool = false,
};

pub const HttpHeader = struct {
    name: []const u8,
    value: []const u8,
};

const Headers = struct {
    content_type: []const u8 = "text/html",
    authorization: ?[]const u8 = null,
    accept: ?[]const u8 = null,
    user_agent: ?[]const u8 = null,
};

const BodyType = enum {
    string,
    json,
};

pub const Methods = enum {
    GET,
    POST,
    PATCH,
    DELETE,
    PUT,
    OPTIONS,
};

pub const HttpReq = struct {
    method: Methods,
    headers: ?Headers = null,
    body: ?[]const u8 = null,
    body_type: BodyType = .string,
    mode: ?[]const u8 = null,
    redirect: ?[]const u8 = null,
    referrer_policy: ?[]const u8 = null,
    integrity: ?[]const u8 = null,
    use_credentials: bool = false,
    credentials: ?[]const u8 = null,
    extra_headers: []const HttpHeader = &.{},
};

var http_req_view: HttpReqOffset = HttpReqOffset{};
fn generateHttpLayout(http_req: HttpReq) *u8 {
    http_req_view.method_ptr = @tagName(http_req.method).ptr;
    http_req_view.method_len = @tagName(http_req.method).len;

    if (http_req.headers) |h| {
        if (h.content_type) |ct| {
            http_req_view.content_type_ptr = ct.ptr;
            http_req_view.content_type_len = ct.len;
        }
        if (h.authorization) |au| {
            http_req_view.authorization_ptr = au.ptr;
            http_req_view.authorization_len = au.len;
        }
        if (h.accept) |ac| {
            http_req_view.accept_ptr = ac.ptr;
            http_req_view.accept_len = ac.len;
        }
        if (h.user_agent) |us| {
            http_req_view.user_agent_ptr = us.ptr;
            http_req_view.user_agent_len = us.len;
        }

        if (http_req.extra_headers.len > 0) {
            http_req_view.extra_headers_ptr = http_req.extra_headers.ptr;
            http_req_view.extra_headers_len = http_req.extra_headers.len;
        }
    }
    if (http_req.body) |b| {
        http_req_view.body_ptr = b.ptr;
        http_req_view.body_len = b.len;
    }
    if (http_req.mode) |m| {
        http_req_view.mode_ptr = m.ptr;
        http_req_view.mode_len = m.len;
    }
    if (http_req.redirect) |r| {
        http_req_view.redirect_ptr = r.ptr;
        http_req_view.redirect_len = r.len;
    }
    if (http_req.referrer_policy) |rp| {
        http_req_view.referrer_policy_ptr = rp.ptr;
        http_req_view.referrer_policy_len = rp.len;
    }
    if (http_req.integrity) |i| {
        http_req_view.integrity_ptr = i.ptr;
        http_req_view.integrity_len = i.len;
    }
    http_req_view.use_credentials = http_req.use_credentials;

    const ptr: *u8 = @ptrCast(&http_req_view);
    return ptr;
}

var http_buf: [4096]u8 = undefined;
fn constructHeaders(headers: Headers, extra_headers: []const HttpHeader, writer: *String) void {
    writer.append_str("\"Content-Type\": ");
    writer.append_str("\"");
    writer.append_str(headers.content_type);
    writer.append_str("\"");
    if (headers.user_agent) |user_agent| {
        writer.append_str(",\n");
        writer.append_str("\"User-Agent\": ");
        writer.append_str("\"");
        writer.append_str(user_agent);
        writer.append_str("\"");
    }
    if (headers.authorization) |authorization| {
        writer.append_str(",\n");
        writer.append_str("\"Authorization\": ");
        writer.append_str("\"");
        writer.append_str(authorization);
        writer.append_str("\"");
    }
    if (headers.accept) |accept| {
        writer.append_str(",\n");
        writer.append_str("\"Accept\": ");
        writer.append_str("\"");
        writer.append_str(accept);
        writer.append_str("\"");
    }

    for (extra_headers) |header| {
        writer.append_str(",\n");
        writer.append_str("\"");
        writer.append_str(header.name);
        writer.append_str("\"");
        writer.append_str(": ");
        writer.append_str("\"");
        writer.append_str(header.value);
        writer.append_str("\"");
    }
}

pub fn fetchWithParams(url: []const u8, self: anytype, cb: anytype, http_req: HttpReq) void {
    var writer = String.new();
    writer.append_str("{\n\"method\": ");
    writer.append_str("\"");
    writer.append_str(@tagName(http_req.method));
    writer.append_str("\"");
    if (http_req.headers) |headers| {
        writer.append_str(",\n\"headers\": {\n");
        constructHeaders(headers, http_req.extra_headers, &writer);
        writer.append_str("\n}");
    } else if (http_req.extra_headers.len > 0) {
        writer.append_str(",\n\"headers\": {\n");
        var count: usize = 1;
        for (http_req.extra_headers) |header| {
            writer.append_str("\"");
            writer.append_str(header.name);
            writer.append_str("\"");
            writer.append_str(": ");
            writer.append_str("\"");
            writer.append_str(header.value);
            writer.append_str("\"");
            if (count < http_req.extra_headers.len) {
                writer.append_str(",\n");
            }
            count += 1;
        }
        writer.append_str("\n}");
    }

    if (http_req.credentials) |credentials| {
        writer.append_str(",\n\"credentials\": ");
        writer.append_str("\"");
        writer.append_str(credentials);
        writer.append_str("\"");
    }

    if (http_req.body) |body| {
        writer.append_str(",\n\"body\": ");
        switch (http_req.body_type) {
            .string => {
                writer.append_str("\"");
                writer.append_str(body);
                writer.append_str("\"");
            },
            .json => {
                writer.append_str(body);
            },
        }
    }
    writer.append_str("\n}");

    const final = writer.contents[0..writer.len];
    const json = std.json.fmt(final, .{ .whitespace = .indent_1 }).value;
    // const http_req_offset_ptr = generateHttpLayout(http_req);

    const Args = @TypeOf(self);
    const Closure = struct {
        self: Args,
        fetch_node: FetchNode = .{ .data = .{ .runFn = runFn, .deinitFn = deinitFn } },
        //
        fn runFn(action: *FetchAction, resp: Response) void {
            const fetch_node: *FetchNode = @fieldParentPtr("data", action);
            const closure: *@This() = @alignCast(@fieldParentPtr("fetch_node", fetch_node));
            @call(.auto, cb, .{ closure.self, resp });
        }
        //
        fn deinitFn(node: *FetchNode) void {
            const closure: *@This() = @alignCast(@fieldParentPtr("fetch_node", node));
            Vapor.allocator_global.destroy(closure);
        }
    };

    const closure = Vapor.allocator_global.create(Closure) catch |err| {
        Vapor.println("Error could not create closure {any}\n ", .{err});
        unreachable;
    };
    closure.* = .{
        .self = self,
    };

    const id = Vapor.fetch_registry.count() + 1;
    Vapor.fetch_registry.put(id, &closure.fetch_node) catch |err| {
        Vapor.println("Button Function Registry {any}\n", .{err});
        return;
    };
    fetchParamsWasm(url.ptr, url.len, id, json.ptr, json.len);
}

const http = std.http;

const Param = struct {
    key: []const u8,
    value: []const u8,
};

pub fn scrollTo(x: f32, y: f32) void {
    if (isWasi) {
        Wasm.scrollToWasm(x, y);
    }
}

pub const QueryBuilder = struct {
    allocator: std.mem.Allocator,
    params: std.array_list.Managed(Param),
    str: []const u8,

    /// This function takes a pointer to this QueryBuilder instance.
    /// Deinitializes the query builder instance
    /// # Parameters:
    /// - `target`: *QueryBuilder.
    /// - `allocator`: std.mem.Allocator.
    ///
    /// # Returns:
    /// void.
    pub fn init(query_builder: *QueryBuilder, allocator: std.mem.Allocator) !void {
        query_builder.* = .{
            .allocator = allocator,
            .params = std.array_list.Managed(Param).init(allocator),
            .str = "",
        };
    }

    /// This function takes a pointer to this QueryBuilder instance.
    /// Deinitializes the query builder instance, loops over the keys and values to free
    /// # Parameters:
    /// - `target`: *QueryBuilder.
    ///
    /// # Returns:
    /// void.
    pub fn deinit(query_builder: *QueryBuilder) void {
        for (query_builder.params.items) |param| {
            query_builder.allocator.free(param.key);
            query_builder.allocator.free(param.value);
        }
        query_builder.params.deinit();
        if (query_builder.str.len > 0) {
            query_builder.allocator.free(query_builder.str);
        }
    }

    /// This function adds a value and key to the query builder.
    /// # Example
    /// try query.add("client_id", "98f3$j%gw54u4562$");
    ///
    /// # Parameters:
    /// - `key`: []const u8.
    /// - `value`: []const u8.
    ///
    /// # Returns:
    /// void and adds to query builder list.
    pub fn add(query_builder: *QueryBuilder, key: []const u8, value: []const u8) !void {
        const key_dup = try query_builder.allocator.dupe(u8, key);
        const value_dup = try query_builder.allocator.dupe(u8, value);
        try query_builder.params.append(.{ .key = key_dup, .value = value_dup });
    }

    /// This function removes a key.
    /// # Example
    /// try query.remove("client_id");
    ///
    /// # Parameters:
    /// - `key`: []const u8.
    ///
    /// # Returns:
    /// void
    pub fn remove(query_builder: *QueryBuilder, key: []const u8) !void {
        // utils.assert_cm(query_builder.query_param_list.capacity > 0, "QueryBuilder not initilized");
        for (query_builder.params.items, 0..) |query_param, i| {
            if (std.mem.eql(u8, query_param.key, key)) {
                _ = query_builder.query_param_list.orderedRemove(i);
                break;
            }
        }
    }

    /// This function encodes the url pass.
    /// # Example
    /// try query.urlEncoder("https://accounts.google.com/o/oauth2/v2/auth");
    ///
    /// # Parameters:
    /// - `url`: []const u8.
    ///
    /// # Returns:
    /// []const u8
    pub fn urlEncoder(query_builder: *QueryBuilder, url: []const u8) ![]const u8 {
        var encoded = std.array_list.Managed(u8).init(query_builder.allocator);
        defer encoded.deinit();

        for (url) |c| {
            switch (c) {
                'a'...'z', 'A'...'Z', '0'...'9', '-', '_', '.', '~' => try encoded.append(c),
                ' ' => try encoded.appendSlice("%20"),
                else => {
                    try encoded.writer().print("%{X:0>2}", .{c});
                },
            }
        }

        return encoded.toOwnedSlice();
    }

    /// This function encodes the query and set query_builder.str.
    /// # Example
    /// try query.queryStrEncode();
    ///
    /// # Returns:
    /// void
    pub fn queryStrEncode(query_builder: *QueryBuilder) !void {
        if (query_builder.params.items.len == 0) {
            query_builder.str = "";
            return;
        }

        var list = std.array_list.Managed(u8).init(query_builder.allocator);
        errdefer list.deinit();

        for (query_builder.params.items, 0..) |param, i| {
            if (i > 0) {
                try list.append('&');
            }

            // URL encode key
            const encoded_key = try query_builder.urlEncoder(param.key);
            defer query_builder.allocator.free(encoded_key);
            try list.appendSlice(encoded_key);

            try list.append('=');

            // URL encode value
            const encoded_value = try query_builder.urlEncoder(param.value);
            defer query_builder.allocator.free(encoded_value);
            try list.appendSlice(encoded_value);
        }

        query_builder.str = try list.toOwnedSlice();
    }

    /// This function generates the queried url plus the precursor url.
    /// # Example
    /// try query.generateUrl("https://accounts.google.com/o/oauth2/v2/auth", query.str);
    ///
    /// # Parameters:
    /// - `base_url`: []const u8.
    /// - `query`: []const u8.
    ///
    /// # Returns:
    /// []const u8
    pub fn generateUrl(query_builder: *QueryBuilder, base_url: []const u8, query: []const u8) ![]const u8 {
        var result = std.array_list.Managed(u8).init(query_builder.allocator);
        errdefer result.deinit();

        try result.appendSlice(base_url);
        if (query.len > 0) {
            try result.append('?');
            try result.appendSlice(query);
        }

        return result.toOwnedSlice();
    }

    // Helper function to get parameters in order
    pub fn getParams(query_builder: *QueryBuilder) []const Param {
        return query_builder.params.items;
    }
};

pub const ObserverOptions = struct {
    threshold: f32 = 0,
    rootMargin_top: i32 = 0,
    rootMargin_right: i32 = 0,
    rootMargin_bottom: i32 = 0,
    rootMargin_left: i32 = 0,
};

// Field type enum that JS can understand
pub const FieldType = enum(u8) {
    u8_type,
    i8_type,
    u16_type,
    i16_type,
    u32_type,
    i32_type,
    u64_type,
    i64_type,
    f32_type,
    f64_type,
    bool_type,
    string_type, // ptr + len pair
};

// Schema field descriptor
pub const FieldDescriptor = packed struct {
    field_type: FieldType,
    offset: u32,
    name_ptr: usize,
    name_len: usize,
};

// Generic schema generator
pub fn StructSchema(comptime T: type) type {
    return struct {
        pub var fields: []FieldDescriptor = undefined;
        pub fn init() void {
            const type_info = @typeInfo(T);
            if (type_info != .@"struct") {
                @compileError("StructSchema only works with struct types");
            }

            const struct_fields = type_info.@"struct".fields;
            fields = Vapor.arena(.persist).alloc(FieldDescriptor, struct_fields.len) catch unreachable;

            inline for (struct_fields, 0..) |field, i| {
                const field_type = mapZigTypeToFieldType(field.type);
                // Vapor.print("Field {s} type {d} {any} {any}\n", .{ field.name, field_type, @offsetOf(T, field.name), @intFromPtr(field.name.ptr) });
                fields[i] = FieldDescriptor{
                    .field_type = field_type,
                    .offset = @offsetOf(T, field.name),
                    .name_ptr = @intFromPtr(field.name.ptr),
                    .name_len = field.name.len,
                };
            }
        }

        pub fn getSchema() []FieldDescriptor {
            return fields;
        }

        pub fn getSchemaLength() usize {
            return fields.len;
        }
    };
}

fn mapZigTypeToFieldType(comptime T: type) FieldType {
    return switch (T) {
        u8 => .u8_type,
        i8 => .i8_type,
        u16 => .u16_type,
        i16 => .i16_type,
        u32 => .u32_type,
        i32 => .i32_type,
        u64 => .u64_type,
        i64 => .i64_type,
        f32 => .f32_type,
        f64 => .f64_type,
        bool => .bool_type,
        else => blk: {
            // Check if it's a string type (ptr + len)
            const type_info = @typeInfo(T);
            if (type_info == .Pointer) {
                break :blk .string_type;
            }
            @compileError("Unsupported type: " ++ @typeName(T));
        },
    };
}

/// Observer is a struct that allows you to observe the visibility of an element
/// and call a callback when the element becomes visible or invisible
/// # Parameters:
/// - `name`: []const u8,
/// - `callback`: anytype,
/// - `options`: ObserverOptions,
///
/// # Returns:
/// Observer
///
/// # Usage:
/// ```zig
/// const observer = Kit.Observer.new("my_observer", onObserver, .{ .threshold = 0.5 });
///
/// fn onObserver(target: Observer.Target) void {
///     const target: Observer.Target = target;
///     _ = target;
/// }
/// ``` NOTE: This function dellocates, after use, clone the fields if need them outsside the handler function
/// # Example:
/// ```zig
/// const observer = Kit.Observer.new("my_observer", onObserver, .{ .threshold = 0.5 });
///
/// var target_link: []const u8 = "";
/// fn onObserver(target: Observer.Target) void {
///     const target: Observer.Target = target;
///     target_link = Vapor.clone(target.url);
/// }
/// ```
pub const Observer = struct {
    pub const Target = struct {
        url: []const u8,
        is_in_view: bool,
        index: usize,
    };
    name: []const u8,
    callback: *const fn (Target) void,
    oberver_nodes: std.array_list.Managed(Vapor.ObserverNode),

    pub fn new(name: []const u8, callback: fn (Target) void, options: ObserverOptions) Observer {
        const Closure = struct {
            run_node: Vapor.Node = .{ .data = .{ .runFn = runFn, .deinitFn = deinitFn } },
            fn runFn(action: *Vapor.Action) void {
                const run_node: *Vapor.Node = @fieldParentPtr("data", action);
                const object = run_node.data.dynamic_object orelse {
                    Vapor.printlnSrcErr("Bridge: Observer callback called without object, this is a js side issue", .{}, @src());
                    Vapor.printlnSrcErr("No object found", .{}, @src());
                    return;
                };
                const target: Target = DynamicObject.convertFromDynamicToType(Target, object);
                @call(.auto, callback, .{target});
            }
            fn deinitFn(_: *Vapor.Node) void {}
        };

        const closure = Vapor.arena(.persist).create(Closure) catch |err| {
            Vapor.println("Error could not create closure {any}\n ", .{err});
            unreachable;
        };
        closure.* = .{};

        const hash = hashKey(name);
        Vapor.ctx_callback_registry.put(hash, &closure.run_node) catch |err| {
            Vapor.println("Button Function Registry {any}\n", .{err});
        };

        if (isWasi) {
            Wasm.createObserverWasm(hash, &options);
        }

        return Observer{
            .name = name,
            .callback = callback,
            .oberver_nodes = std.array_list.Managed(Vapor.ObserverNode).init(Vapor.arena(.persist)),
        };
    }

    pub fn disconnect(self: *Observer) void {
        if (!isWasi) return;
        const hash = hashKey(self.name);
        Wasm.reinitObserverWasm(hash);
    }

    pub fn destroy(name: []const u8) void {
        if (!isWasi) return;
        Wasm.destroyObserverWasm(name.ptr, name.len);
    }

    pub fn observe(self: *Observer, item: Vapor.ObserverNode, index: ?usize) void {
        if (!isWasi) return;
        self.oberver_nodes.append(item) catch unreachable;
        const hash = hashKey(self.name);
        switch (item) {
            .uuid => |uuid| {
                Wasm.observeWasm(hash, uuid.ptr, uuid.len, index orelse 0);
            },
            .type => |element_type| {
                const element_type_str = @tagName(element_type);
                Wasm.observeWasm(hash, element_type_str.ptr, element_type_str.len, index orelse 0);
            },
        }
    }
};

const ObserverExport = DynamicObject.exportStruct(ObserverOptions);

// --- THE EXPORTS ---
// Everything inside here gets auto-exported to JS
pub const API = struct {
    pub fn hookInstCallback(id: u32) callconv(.c) void {
        const hook_cb = Vapor.hooks_inst_callbacks.get(id).?;
        const params_str = Kit.getWindowParams() orelse "";
        const path = Kit.getWindowPath() orelse {
            Vapor.printlnSrcErr("Hooks ERROR: Could not get window path", .{}, @src());
            return;
        };
        var params = std.StringHashMap([]const u8).init(Vapor.arena(.frame));
        if (params_str.len != 0) {
            params = Kit.parseParams(params_str, Vapor.allocator_global) catch return orelse return;
        }
        const context = Vapor.HookContext{
            .from_path = "",
            .to_path = path,
            .params = params,
            .query = params,
        };
        Vapor.println("Hook {any}\n", .{context});
        @call(.auto, hook_cb, .{context});
    }

    pub fn resumeCallback(id: u32, resp_ptr: [*:0]u8) callconv(.c) void {
        const resp = std.mem.span(resp_ptr);

        // Look up the fetch node to find the associated entry
        const node = Vapor.fetch_registry.get(id) orelse return;

        // Walk from node back to the Closure to get the entry
        // const closure: *Fetch.Closure = @alignCast(@fieldParentPtr("fetch_node", node));
        // const entry = closure.entry_ptr;

        const allocator = @call(.auto, node.data.allocator, .{node});

        // Parse into the entry's arena — data lives until next fetch to same endpoint
        const parsed_value = std.json.parseFromSlice(
            Response,
            allocator,
            resp,
            .{ .ignore_unknown_fields = true },
        ) catch |err| {
            Vapor.printlnSrcErr("Error could not parse response {any} {s}\n", .{ err, resp }, @src());
            @call(.auto, node.data.runFn, .{ &node.data, Response{ .Err = .{
                .code = 0,
                .message = "",
                .type = "",
                .ok = false,
                .url = "",
                .redirected = false,
                .body = resp,
                .headers = null,
                .content_type = "",
                .content_length = 0,
                .elapsed_ms = 0,
                .error_kind = "",
                .error_name = "",
            } } });
            Vapor.cycle();
            return;
        };

        const json_resp: Response = parsed_value.value;

        if (json_resp.isErr()) {
            const e = json_resp.err().?;
            std.log.err(
                "\nFETCH ERROR [{s}] {s}\n  URL: {s}\n  Code: {d} - {s}\n  Time: {d}ms\n",
                .{ e.error_kind, e.error_name, e.url, e.code, e.message, e.elapsed_ms },
            );
        }

        @call(.auto, node.data.runFn, .{ &node.data, json_resp });
        Vapor.cycle();
    }

    // pub fn resumeCallback(id: u32, resp_ptr: [*:0]u8) callconv(.c) void {
    //     const resp = std.mem.span(resp_ptr);
    //     const parsed_value = std.json.parseFromSlice(Response, Vapor.arena(.frame), resp, .{
    //         .ignore_unknown_fields = true,
    //     }) catch |err| {
    //         Vapor.printlnSrcErr("Error could not parse response {any} {s}\n", .{ err, resp }, @src());
    //         const node = Vapor.fetch_registry.get(id) orelse return;
    //         @call(.auto, node.data.runFn, .{ &node.data, Response{ .Err = .{
    //             .code = 0,
    //             .message = "",
    //             .type = "",
    //             .ok = false,
    //             .url = "",
    //             .redirected = false,
    //             .body = resp,
    //             .headers = null,
    //             .content_type = "",
    //             .content_length = 0,
    //             .elapsed_ms = 0,
    //             .error_kind = "",
    //             .error_name = "",
    //         } } });
    //         Vapor.cycle();
    //         return;
    //     };
    //
    //     const json_resp: Response = parsed_value.value;
    //
    //     if (json_resp.isErr()) {
    //         const e = json_resp.err().?;
    //         std.log.err(
    //             "\nFETCH ERROR [{s}] {s}\n  URL: {s}\n  Code: {d} - {s}\n  Time: {d}ms\n",
    //             .{ e.error_kind, e.error_name, e.url, e.code, e.message, e.elapsed_ms },
    //         );
    //     }
    //
    //     const node = Vapor.fetch_registry.get(id) orelse return;
    //     @call(.auto, node.data.runFn, .{ &node.data, json_resp });
    //     Vapor.cycle();
    // }

    pub fn getObserverOptions(options: *ObserverOptions) callconv(.c) [*]const u8 {
        ObserverExport.init();
        ObserverExport.instance = options.*;
        return ObserverExport.getInstancePtr();
    }

    pub fn getObserverFieldCount() callconv(.c) u32 {
        return ObserverExport.getFieldCount();
    }

    pub fn getObserverFieldDescriptor(index: u32) callconv(.c) ?*const DynamicObject.FieldDescriptor() {
        return ObserverExport.getFieldDescriptor(index);
    }

    pub fn getObserverNodeCount(observer_name: [*:0]u8) callconv(.c) usize {
        const name = std.mem.span(observer_name);
        const nodes = Vapor.observer_nodes.get(name) orelse return 0;
        return nodes.items.len;
    }

    pub fn getObserverNode(observer_name: [*:0]u8, index: usize) callconv(.c) ?[*]const u8 {
        const name = std.mem.span(observer_name);
        const nodes = Vapor.observer_nodes.get(name) orelse return null;
        const node = nodes.items[index];
        return node.uuid.ptr;
    }

    pub fn getObserverNodeLength(observer_name: [*:0]u8, index: usize) callconv(.c) usize {
        const name = std.mem.span(observer_name);
        const nodes = Vapor.observer_nodes.get(name) orelse return 0;
        const node = nodes.items[index];
        return node.uuid.len;
    }
};

// 1. This variable will hold our list of names.
// It is calculated at compile-time but stored in the binary for runtime use.
const export_names = blk: {
    const decls = @typeInfo(API).@"struct".decls;

    // We need to count valid exports first to know the array size
    var count = 0;
    for (decls) |decl| {
        // if (std.ascii.startsWithIgnoreCase(decl.name, "export")) {
        const val = @field(API, decl.name);
        if (@typeInfo(@TypeOf(val)) == .@"fn") {
            count += 1;
        }
        // }
    }

    // Create the array with the exact size needed
    var names: [count][]const u8 = undefined;
    var i = 0;

    // Fill the array
    for (decls) |decl| {
        // if (std.ascii.startsWithIgnoreCase(decl.name, "export")) {
        const val = @field(API, decl.name);
        if (@typeInfo(@TypeOf(val)) == .@"fn") {
            names[i] = decl.name;
            i += 1;

            // Do the actual export here too!
            // @export(val, .{ .name = decl.name });
        }
        // }
    }

    // Return the final array to be stored in 'export_names'
    break :blk names;
};

// 2. Runtime logging function
pub fn log() void {
    Vapor.println("Exported functions: {d}\n", .{export_names.len});
    // We simply iterate over the const slice we created above
    for (export_names) |name| {
        Vapor.print("Exported: {s}\n", .{name});
        // Or: Vapor.print("{s}\n", .{name});
    }
}

const WssOptions = struct {
    key: []const u8,
    query: []const u8,
    port: u16 = 8080,
    on_connection: ?*const fn () void = undefined,
    on_message: ?*const fn (msg: []const u8) void = undefined,
    on_close: ?*const fn () void = undefined,
};

extern fn createWss(
    port: u16,
    id: u32,
    query: [*]const u8,
    query_len: u32,
) void;

extern fn sendWss(
    id: u32,
    msg: [*]const u8,
    msg_len: u32,
) void;

var wss_callbacks: ?std.AutoHashMap(u32, WssOptions) = null;

pub const Wss = struct {
    id: u32,
    pub fn send(wss: *const Wss, msg: []const u8) void {
        sendWss(wss.id, msg.ptr, msg.len);
    }
};

pub fn useWss(wss_options: WssOptions) !Wss {
    if (wss_callbacks == null) {
        wss_callbacks = std.AutoHashMap(u32, WssOptions).init(Vapor.arena(.persist));
        const key = utils.hash(wss_options.key);
        wss_callbacks.?.put(key, wss_options) catch |err| {
            std.log.err("Error adding wss options {any}\n", .{err});
            return error.CouldNotAddWssOptions;
        };
        createWss(wss_options.port, key, wss_options.query.ptr, wss_options.query.len);
        return Wss{
            .id = key,
        };
    } else if (wss_callbacks) |*callbacks| {
        const key = utils.hash(wss_options.key);
        callbacks.put(key, wss_options) catch |err| {
            std.log.err("Error adding wss options {any}\n", .{err});
            return error.CouldNotAddWssOptions;
        };
        createWss(wss_options.port, key, wss_options.query.ptr, wss_options.query.len);
        return Wss{
            .id = key,
        };
    }
    return error.CouldNotAddWssOptions;
}

export fn onWssConnection(id: u32) void {
    if (wss_callbacks) |callbacks| {
        const wss_ops = callbacks.get(id) orelse {
            std.log.err("Error getting wss options {any}\n", .{error.CouldNotGetWssCallbacks});
            return;
        };
        if (wss_ops.on_connection) |cb| {
            cb();
            if (Vapor.mode == .atomic) {
                Vapor.cycle();
            }
        }
    }
}
export fn onWssMessage(id: u32, msg_nullterm: [*:0]u8) void {
    const msg = std.mem.span(msg_nullterm);
    if (wss_callbacks) |callbacks| {
        const wss_ops = callbacks.get(id) orelse {
            std.log.err("Error getting wss options {any}\n", .{error.CouldNotGetWssCallbacks});
            return;
        };
        if (wss_ops.on_message) |cb| {
            cb(msg);
            if (Vapor.mode == .atomic) {
                Vapor.cycle();
            }
        }
    }
}

export fn onWssClose(id: u32) void {
    if (wss_callbacks) |callbacks| {
        const wss_ops = callbacks.get(id) orelse {
            std.log.err("Error getting wss options {any}\n", .{error.CouldNotGetWssCallbacks});
            return;
        };
        if (wss_ops.on_close) |cb| {
            cb();
        }
    }
}

// --- Auto-Export Magic ---
// This runs automatically when this file is imported
comptime {
    const decls = std.meta.declarations(API);

    for (decls) |decl| {
        const val = @field(API, decl.name);
        const Type = @TypeOf(val);
        if (@typeInfo(Type) == .@"fn") {
            // Export it with its own name
            @export(&val, .{ .name = decl.name });
        }
    }
}

// Split string into slice of slices
pub fn split(str: []const u8, delimiter: []const u8) std.mem.SplitIterator(u8, .sequence) {
    return std.mem.splitSequence(u8, str, delimiter);
}

pub fn contains(str: []const u8, needle: []const u8) bool {
    return utils.contains(str, needle);
}

pub fn startsWith(str: []const u8, prefix: []const u8) bool {
    return utils.startsWith(str, prefix);
}
