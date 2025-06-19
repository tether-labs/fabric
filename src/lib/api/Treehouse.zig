const std = @import("std");
const Fabric = @import("../Fabric.zig");
// const utils = @import("../utils/index.zig");

const ClientError = error{
    HeaderMalformed,
    RequestNotSupported,
    ProtoNotSupported,
    Success,
    ValueNotFound,
    FailedToSet,
    FailedToPing,
    FailedToGet,
    FailedToDel,
    FailedToEcho,
    IndexOutOfBounds,
    ConnectionRefused,
    ServerError,
};

const ReturnTypes = enum {
    Success,
};

pub const ValueType = union(enum) {
    string: []const u8,
    int: i32,
    float: f32,
    json: []const u8,
};

const mimeTypes = .{
    .{ ".html", "text/html; charset=utf8" },
    .{ ".js", "application/javascript" },
    .{ ".wasm", "application/wasm" },
    .{ ".css", "text/css" },
    .{ ".png", "image/png" },
    .{ ".jpg", "image/jpeg" },
    .{ ".gif", "image/gif" },
    .{ ".svg", "image/svg+xml" },
};

const MimeTypes = struct {
    string: []const u8 = "text/html; charset=utf8",
    int: []const u8 = "text/html; charset=utf8",
    float: []const u8 = "text/html; charset=utf8",
    json: []const u8 = "application/javascript",
}{};

pub fn mimeForPath(path: []const u8) []const u8 {
    const extension = std.fs.path.extension(path);
    inline for (mimeTypes) |kv| {
        if (std.mem.eql(u8, extension, kv[0])) {
            return kv[1];
        }
    }
    return "text/html; charset=utf8";
}

const Self = @This();
allocator: *std.mem.Allocator,

pub fn echo(self: Self, value: []const u8, construct: anytype, cb: anytype) void {
    const req = std.fmt.allocPrint(
        self.allocator.*,
        "*2\r\n$4\r\nECHO\r\n${d}\r\n{s}\r\n",
        .{ value.len, value },
    ) catch |err| {
        Fabric.println("Failed to create command {any}\n", .{err});
        return;
    };
    Fabric.Kit.fetchWithParams("http://localhost:8443/treehouse/cmd/echo", construct, cb, .{
        .method = "POST",
        .headers = .{
            .content_type = "text/html",
        },
        .body = req,
    });
}

pub fn get(self: Self, key: []const u8, construct: anytype, cb: anytype) ![]const u8 {
    if (key.len == 0) return error.KeyIsEmpty;
    const request = try std.fmt.allocPrint(
        self.allocator.*,
        "*2\r\n$3\r\nGET\r\n${d}\r\n{s}\r\n",
        .{ key.len, key },
    );

    const content_type: []const u8 = MimeTypes.string;

    Fabric.Kit.fetchWithParams("http://localhost:8443/treehouse/exec/cmd", construct, cb, .{
        .method = "POST",
        .headers = .{
            .content_type = content_type,
        },
        .body = request,
    });
    return request;
}

pub fn set(self: Self, key: []const u8, value_type: ValueType, construct: anytype, cb: anytype) ![]const u8 {
    if (key.len == 0) return error.KeyIsEmpty;
    var char: u8 = '$';
    var value: []const u8 = "";
    switch (value_type) {
        .string => |v| {
            value = v;
            char = '$';
        },
        .int => |v| {
            var buf: [32]u8 = undefined;
            const number = std.fmt.bufPrint(&buf, "{d}", .{v}) catch |err| return err;
            value = number;
            char = ':';
        },
        .float => |v| {
            var buf: [32]u8 = undefined;
            const number = std.fmt.bufPrint(&buf, "{d}", .{v}) catch |err| return err;
            value = number;
            char = ',';
        },
        .json => |v| {
            value = v;
            char = '@';
        },
    }

    const request = std.fmt.allocPrint(
        self.allocator.*,
        "*3\r\n$3\r\nSET\r\n${d}\r\n{s}\r\n{c}{d}\r\n{s}\r\n",
        .{ key.len, key, char, value.len, value },
    ) catch return "";

    var content_type: []const u8 = "";

    switch (value_type) {
        .string => content_type = MimeTypes.int,
        .int => content_type = MimeTypes.int,
        .float => content_type = MimeTypes.int,
        .json => content_type = MimeTypes.int,
    }

    Fabric.Kit.fetchWithParams("http://localhost:8443/treehouse/exec/cmd", construct, cb, .{
        .method = "POST",
        .headers = .{
            .content_type = content_type,
        },
        .body = request,
    });

    return request;
}

pub fn del(self: Self, key: []const u8, construct: anytype, cb: anytype) ![]const u8 {
    if (key.len == 0) return error.KeyIsEmpty;
    const request = try std.fmt.allocPrint(
        self.allocator.*,
        "*2\r\n$3\r\nDEL\r\n${d}\r\n{s}\r\n",
        .{ key.len, key },
    );

    const content_type: []const u8 = MimeTypes.string;

    Fabric.Kit.fetchWithParams("http://localhost:8443/treehouse/exec/cmd", construct, cb, .{
        .method = "POST",
        .headers = .{
            .content_type = content_type,
        },
        .body = request,
    });

    return request;
}

pub fn lpushmany(self: Self, llname: []const u8, items: []const ValueType, construct: anytype, cb: anytype) ![]const u8 {
    if (llname.len == 0) return error.ListNameIsEmpty;
    const allocator = self.allocator.*;
    const precursor = try std.fmt.allocPrint(
        allocator,
        "*{d}\r\n$9\r\nLPUSHMANY\r\n${d}\r\n{s}\r\n",
        .{ items.len + 2, llname.len, llname },
    );
    defer allocator.free(precursor);
    var input: []u8 = undefined;
    var str_arr_v = try allocator.alloc([]const u8, items.len);
    defer {
        for (str_arr_v) |v| {
            allocator.free(v);
        }
    }
    defer allocator.free(str_arr_v);

    for (items, 0..) |item, i| {
        switch (item) {
            .string => |v| {
                const response = try std.fmt.allocPrint(
                    allocator,
                    "${d}\r\n{s}\r\n",
                    .{ v.len, v },
                );

                str_arr_v[i] = response;
            },
            .int => |v| {
                const response = try std.fmt.allocPrint(
                    allocator,
                    ":{d}\r\n",
                    .{v},
                );

                str_arr_v[i] = response;
            },
            .float => |v| {
                const response = try std.fmt.allocPrint(
                    allocator,
                    ",{d}\r\n",
                    .{v},
                );

                str_arr_v[i] = response;
            },
            .json => |v| {
                const response = try std.fmt.allocPrint(
                    allocator,
                    "@{d}\r\n{s}\r\n",
                    .{ v.len, v },
                );

                str_arr_v[i] = response;
            },
        }
    }

    input = try std.mem.join(allocator, "", str_arr_v);
    const request = try std.fmt.allocPrint(
        allocator,
        "{s}{s}",
        .{ precursor, input },
    );
    // defer allocator.free(request);
    std.debug.print("{s}", .{request});

    const content_type: []const u8 = MimeTypes.string;

    Fabric.Kit.fetchWithParams("http://localhost:8443/treehouse/exec/cmd", construct, cb, .{
        .method = "POST",
        .headers = .{
            .content_type = content_type,
        },
        .body = request,
    });

    return request;
}

// pub fn set(self: Self, key: []const u8, value_type: ValueType) ![]const u8 {
//     const client_fd = try self.createConn();
//
//     var char: u8 = '$';
//     var value: []const u8 = "";
//     switch (value_type) {
//         .string => |v| {
//             value = v;
//             char = '$';
//         },
//         .int => |v| {
//             var buf: [32]u8 = undefined;
//             const number = try std.fmt.bufPrint(&buf, "{s}", .{v});
//             value = number;
//             char = ':';
//         },
//         .float => |v| {
//             var buf: [32]u8 = undefined;
//             const number = try std.fmt.bufPrint(&buf, "{s}", .{v});
//             value = number;
//             char = ',';
//         },
//     }
//
//     const response = try std.fmt.allocPrint(
//         std.heap.c_allocator,
//         "*3\r\n$3\r\nSET\r\n${d}\r\n{s}\r\n{c}{d}\r\n{s}\r\n",
//         .{ key.len, key, char, value.len, value },
//     );
//
//     const nw = try posix.write(client_fd, response);
//     if (nw < 0) {
//         return;
//     }
//     var rbuf: [65535]u8 = undefined;
//     const nr = try posix.read(client_fd, &rbuf);
//
//     const resp = rbuf[0..nr];
//     if (std.mem.eql(u8, resp, "-ERROR")) {
//         return ClientError.FailedToSet;
//     }
//
//     const s = try std.heap.c_allocator.alloc(u8, nr);
//     std.mem.copyForwards(u8, s, rbuf[0..nr]);
//     return s;
//     // return ClientError.Success;
// }
//
// const ErrorType = struct {
//     err: ClientError,
//     err_msg: []const u8,
// };
//
// const CommandResult = union(enum) {
//     Ok: type,
//     Err: anyerror,
//
//     fn unwrap(self: CommandResult) !@TypeOf(self.Ok) {
//         return switch (self) {
//             .Ok => |value| value,
//             .Err => |err| return err,
//         };
//     }
// };
//
// const ErrorContext = struct {
//     err: anyerror,
//     context: []const u8,
//
//     fn create(err: anyerror, context: []const u8) ErrorContext {
//         return .{ .err = err, .context = context };
//     }
// };
//
// pub fn sendCommand(self: Self, req: []const u8) ![]const u8 {
//     const client_fd = try self.createConn();
//     const nw = try posix.write(client_fd, req);
//     if (nw < 0) {
//         return;
//     }
//     var rbuf: [65535]u8 = undefined;
//     const nr = try posix.read(client_fd, &rbuf);
//
//     const resp = rbuf[0..nr];
//     // if (std.mem.startsWith(u8, resp, "-ERROR")) {
//     //     return ErrorContext.create(error.FailedToSet, resp);
//     // }
//
//     const s = try std.heap.c_allocator.alloc(u8, nr);
//     std.mem.copyForwards(u8, s, resp);
//     return s;
// }
//
// pub fn json_set(self: Self, key: []const u8, value: []const u8) ![]const u8 {
//     const client_fd = try self.createConn();
//     const response = try std.fmt.allocPrint(
//         std.heap.c_allocator,
//         "*3\r\n$7\r\nJSONSET\r\n${d}\r\n{s}\r\n@{d}\r\n{s}\r\n",
//         .{ key.len, key, value.len, value },
//     );
//
//     const nw = try posix.write(client_fd, response);
//     if (nw < 0) {
//         return;
//     }
//     var rbuf: [65535]u8 = undefined;
//     const nr = try posix.read(client_fd, &rbuf);
//
//     const resp = rbuf[0..nr];
//     if (std.mem.eql(u8, resp, "-ERROR")) {
//         return ClientError.FailedToSet;
//     }
//
//     const s = try std.heap.c_allocator.alloc(u8, nr);
//     std.mem.copyForwards(u8, s, rbuf[0..nr]);
//     return s;
// }
//
// const vec_len = 32;
// const V = @Vector(vec_len, u8);
// fn findIndex(haystack: []const u8, needle: u8) ?usize {
//     const splt: V = @splat(@as(u8, needle));
//     if (haystack.len >= vec_len) {
//         var i: usize = 0;
//         while (i + vec_len <= haystack.len) : (i += vec_len) {
//             const v = haystack[i..][0..vec_len].*;
//             const vec: V = @bitCast(v);
//             const mask = vec == splt;
//             const bits: u32 = @bitCast(mask);
//             if (bits != 0) {
//                 return i + @ctz(bits);
//             }
//         }
//     }
//     var i: usize = 0;
//     while (i < haystack.len) : (i += 1) {
//         if (haystack[i] == needle) return i;
//     }
//     return null;
// }
//
// pub fn json_get(self: Self, key: []const u8) ![]const u8 {
//     const client_fd = try self.createConn();
//     const response = try std.fmt.allocPrint(
//         std.heap.c_allocator,
//         "*2\r\n$7\r\nJSONGET\r\n${d}\r\n{s}\r\n",
//         .{ key.len, key },
//     );
//
//     const nw = try posix.write(client_fd, response);
//     if (nw < 0) {
//         return;
//     }
//     var rbuf: [65535]u8 = undefined;
//     const nr = try posix.read(client_fd, &rbuf);
//     const resp = rbuf[0..nr];
//
//     if (std.mem.eql(u8, resp, "-ERROR")) {
//         return ClientError.FailedToGet;
//     }
//
//     const start = findIndex(&rbuf, '{').?;
//     const s = try std.heap.c_allocator.alloc(u8, nr - start);
//     std.mem.copyForwards(u8, s, rbuf[start..nr]);
//     return s;
// }
//
// pub fn get(self: Self, key: []const u8) ![]const u8 {
//     const client_fd = try self.createConn();
//     const response = try std.fmt.allocPrint(
//         std.heap.c_allocator,
//         "*2\r\n$3\r\nGET\r\n${d}\r\n{s}\r\n",
//         .{ key.len, key },
//     );
//
//     const nw = try posix.write(client_fd, response);
//     if (nw < 0) {
//         return;
//     }
//     var rbuf: [65535]u8 = undefined;
//     const nr = try posix.read(client_fd, &rbuf);
//     const resp = rbuf[0..nr];
//
//     if (std.mem.eql(u8, resp, "-ERROR")) {
//         return ClientError.FailedToGet;
//     }
//
//     const s = try std.heap.c_allocator.alloc(u8, nr);
//     std.mem.copyForwards(u8, s, rbuf[0..nr]);
//     return s;
// }
//
// pub fn getAllKeys(self: Self) ![]const u8 {
//     const client_fd = try self.createConn();
//     const nw = try posix.write(client_fd, "$10\r\nGETALLKEYS\r\n");
//     if (nw < 0) {
//         return;
//     }
//     var rbuf: [65535]u8 = undefined;
//     const nr = try posix.read(client_fd, &rbuf);
//     const resp = rbuf[0..nr];
//
//     if (std.mem.eql(u8, resp, "-ERROR")) {
//         return ClientError.FailedToGet;
//     }
//
//     const s = try std.heap.c_allocator.alloc(u8, nr);
//     std.mem.copyForwards(u8, s, rbuf[0..nr]);
//     return s;
// }
//
// pub fn del(self: Self, key: []const u8) ![]const u8 {
//     const client_fd = try self.createConn();
//     const response = try std.fmt.allocPrint(
//         std.heap.c_allocator,
//         "*2\r\n$3\r\nDEL\r\n${d}\r\n{s}\r\n",
//         .{ key.len, key },
//     );
//
//     const nw = try posix.write(client_fd, response);
//     if (nw < 0) {
//         return;
//     }
//     var rbuf: [65535]u8 = undefined;
//     const nr = try posix.read(client_fd, &rbuf);
//     const resp = rbuf[0..nr];
//
//     if (std.mem.eql(u8, resp, "-ERROR")) {
//         return ClientError.FailedToDel;
//     }
//
//     const s = try std.heap.c_allocator.alloc(u8, nr);
//     std.mem.copyForwards(u8, s, rbuf[0..nr]);
//     return s;
// }
//
// // "*3\r\n$5\r\nLPUSH\r\n$6\r\nmylist\r\n$3\r\none\r\n";
// // *4\r\n$5\r\nLPUSH\r\n$6\r\nmylist\r\n$4\r\nfive\r\n$3\r\nsix\r\n
pub fn lpush(self: Self, llname: []const u8, item_type: ValueType, construct: anytype, cb: anytype) ![]const u8 {
    var char: u8 = '$';
    var item: []const u8 = "";
    switch (item_type) {
        .string => |v| {
            item = v;
            char = '$';
        },
        .int => |v| {
            var buf: [32]u8 = undefined;
            const number = try std.fmt.bufPrint(&buf, "{d}", .{v});
            item = number;
            char = ':';
        },
        .float => |v| {
            var buf: [32]u8 = undefined;
            const number = try std.fmt.bufPrint(&buf, "{d}", .{v});
            item = number;
            char = ',';
        },
        .json => |v| {
            item = v;
            char = '@';
        },
    }

    const request = try std.fmt.allocPrint(
        self.allocator.*,
        "*3\r\n$5\r\nLPUSH\r\n${d}\r\n{s}\r\n{c}{d}\r\n{s}\r\n",
        .{ llname.len, llname, char, item.len, item },
    );

    const content_type: []const u8 = MimeTypes.string;

    Fabric.Kit.fetchWithParams("http://localhost:8443/treehouse/exec/cmd", construct, cb, .{
        .method = "POST",
        .headers = .{
            .content_type = content_type,
        },
        .body = request,
    });

    return request;
}
//
// // "*3\r\n$5\r\nLPUSH\r\n$6\r\nmylist\r\n$3\r\none\r\n";
// // *4\r\n$5\r\nLPUSH\r\n$6\r\nmylist\r\n$4\r\nfive\r\n$3\r\nsix\r\n
// pub fn lpushmany(self: Self, llname: []const u8, items: []const []const u8) ![]const u8 {
//     const client_fd = try self.createConn();
//     // defer posix.close(client_fd);
//     const precursor = try std.fmt.allocPrint(
//         std.heap.c_allocator,
//         "*{d}\r\n$9\r\nLPUSHMANY\r\n${d}\r\n{s}\r\n",
//         .{ items.len + 2, llname.len, llname },
//     );
//     const str_arr = items;
//     var input: []u8 = undefined;
//     var str_arr_v = try std.heap.c_allocator.alloc([]const u8, items.len);
//     for (str_arr, 0..) |v, i| {
//         const response = try std.fmt.allocPrint(
//             std.heap.c_allocator,
//             "${d}\r\n{s}\r\n",
//             .{ v.len, v },
//         );
//
//         str_arr_v[i] = response;
//     }
//     input = try std.mem.join(std.heap.c_allocator, "", str_arr_v);
//     const final = try std.fmt.allocPrint(
//         std.heap.c_allocator,
//         "{s}{s}",
//         .{ precursor, input },
//     );
//
//     // _ = try posix.write(self.client_fd, "*5\r\n$5\r\nLPUSH\r\n$6\r\nmylist\r\n$4\r\nfive\r\n$3\r\nsix\r\n$4\r\nfour\r\n");
//     const nw = try posix.write(client_fd, final);
//     if (nw < 0) {
//         return;
//     }
//     var rbuf: [65535]u8 = undefined;
//     const nr = try posix.read(client_fd, &rbuf);
//     const resp = rbuf[0..nr];
//
//     if (std.mem.eql(u8, resp, "-ERROR")) {
//         return ClientError.ValueNotFound;
//     }
//
//     const s = try std.heap.c_allocator.alloc(u8, nr - 1);
//     std.mem.copyForwards(u8, s, rbuf[1..nr]);
//     return s;
// }
//
// // "*4\r\n$6\r\nLRANGE\r\n$6\r\nmylist\r\n$1\r\n0\r\n$2\r\n-1\r\n"
// pub fn lrange(self: Self, ll_name: []const u8, start: []const u8, end: []const u8) ![]const u8 {
//     const client_fd = try self.createConn();
//     // defer posix.close(client_fd);
//     const req = try std.fmt.allocPrint(
//         std.heap.c_allocator,
//         "*4\r\n$6\r\nLRANGE\r\n${d}\r\n{s}\r\n${d}\r\n{s}\r\n${d}\r\n{s}\r\n",
//         .{ ll_name.len, ll_name, start.len, start, end.len, end },
//     );
//     const nw = try posix.write(client_fd, req);
//     if (nw < 0) {
//         return;
//     }
//     var rbuf: [65535]u8 = undefined;
//     const nr = try posix.read(client_fd, &rbuf);
//     const resp = rbuf[0..nr];
//
//     if (std.mem.eql(u8, resp, "-ERROR INDEX RANGE")) {
//         return ClientError.IndexOutOfBounds;
//     }
//
//     if (std.mem.eql(u8, resp, "-ERROR")) {
//         return ClientError.ValueNotFound;
//     }
//
//     const s = try std.heap.c_allocator.alloc(u8, nr);
//     std.mem.copyForwards(u8, s, rbuf[0..nr]);
//     return s;
// }
//
// pub fn delElem(self: Self, ll_name: []const u8, index: []const u8) ![]const u8 {
//     const client_fd = try self.createConn();
//     const req = try std.fmt.allocPrint(
//         std.heap.c_allocator,
//         "*3\r\n$7\r\nDELELEM\r\n${d}\r\n{s}\r\n${d}\r\n{s}\r\n",
//         .{ ll_name.len, ll_name, index.len, index },
//     );
//     const nw = try posix.write(client_fd, req);
//     if (nw < 0) {
//         return;
//     }
//     var rbuf: [65535]u8 = undefined;
//     const nr = try posix.read(client_fd, &rbuf);
//     const resp = rbuf[0..nr];
//
//     if (std.mem.eql(u8, resp, "-ERROR INDEX RANGE")) {
//         return ClientError.IndexOutOfBounds;
//     }
//
//     if (std.mem.eql(u8, resp, "-ERROR")) {
//         return ClientError.ValueNotFound;
//     }
//
//     const s = try std.heap.c_allocator.alloc(u8, nr);
//     std.mem.copyForwards(u8, s, rbuf[0..nr]);
//     return s;
// }
//
// const Atomic = std.atomic.Value;
// var counter: Atomic(u32) = Atomic(u32).init(0);
// var start_time: i128 = 0; // Use the standard system clock
// pub fn ping(self: Self, wait_group: *std.Thread.WaitGroup) void {
//     wait_group.start();
//     defer wait_group.finish();
//     const client_fd = self.createConn() catch {
//         return;
//     };
//     // defer posix.close(client_fd);
//
//     var count_v: usize = 0;
//     while (counter.load(.seq_cst) <= 99999) {
//         std.debug.print("Count {any}\n", .{count_v});
//         if (counter.load(.seq_cst) == 99999) {
//             const end = std.time.milliTimestamp();
//             const duration = end - start_time;
//             std.debug.print("Function ran for {any} {any} miliseconds\n", .{ duration, count_v });
//             break;
//         }
//         const nw = posix.write(client_fd, "$4\r\nPING\r\n") catch {
//             continue;
//         };
//         if (nw < 0) {
//             return;
//         }
//         var rbuf: [65535]u8 = undefined;
//         const nr = posix.read(client_fd, &rbuf) catch {
//             return;
//         };
//         if (nr > 0) {
//             count_v = counter.fetchAdd(1, .seq_cst);
//         }
//         // std.debug.print("\n{s}", .{rbuf[0..nr]});
//     }
// }
//
// pub fn pingv2(self: Self) void {
//     const client_fd = self.createConn() catch |err| {
//         std.debug.print("{any}\n", .{err});
//         return;
//     };
//     defer posix.close(client_fd);
//
//     const nw = posix.write(client_fd, "$4\r\nPING\r\n") catch {
//         return;
//     };
//     if (nw < 0) {
//         return;
//     }
//     var rbuf: [65535]u8 = undefined;
//     const nr = posix.read(client_fd, &rbuf) catch {
//         return;
//     };
//     std.debug.print("\n{s}", .{rbuf[0..nr]});
// }
