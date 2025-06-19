const std = @import("std");
const Fabric = @import("../Fabric.zig");
const Kit = Fabric.Kit;
const DummyData = @import("dummy_data.zig");
const Response = Kit.Response;
const NightWatch = @This();
const BASE_URL: []const u8 = "http://localhost:8443";

const Route = struct {
    path: []const u8,
    full_url: []const u8,
};

// Define all routes with their paths
pub const ROUTES = struct {
    pub const metrics_allroutes = blk: {
        const path = "/metrics/allroutes";
        const full = BASE_URL ++ path;
        break :blk Route{ .path = path, .full_url = full };
    };

    pub const user_profile = blk: {
        const path = "/user/profile";
        const full = BASE_URL ++ path;
        break :blk Route{ .path = path, .full_url = full };
    };

    pub const test_tether_json = blk: {
        const path = "/api/test/json";
        const full = BASE_URL ++ path;
        break :blk Route{ .path = path, .full_url = full };
    };

    // Add more routes as needed

    // Generate an array of all routes at compile time
    pub const all = [_]Route{
        metrics_allroutes,
        user_profile,
        // Add more routes to this array
    };

    // Function to get a slice of all route paths
    pub fn getAllPaths() []const []const u8 {
        comptime {
            var paths: [all.len][]const u8 = undefined;
            for (all, 0..) |route, i| {
                paths[i] = route.path;
            }
            return &paths;
        }
    }

    // Function to get a slice of all full URLs
    pub fn getAllUrls() []const []const u8 {
        comptime {
            var urls: [all.len][]const u8 = undefined;
            for (all, 0..) |route, i| {
                urls[i] = route.full_url;
            }
            return &urls;
        }
    }
};

pub fn init() void {}

pub fn getAllRoutes(self: anytype, cb: anytype) void {
    Kit.fetchWithParams(ROUTES.metrics_allroutes.full_url, self, cb, .{
        .method = "GET",
        .headers = .{ .content_type = "application/json" },
    });
}

pub fn testTetherJSON(self: anytype, cb: anytype) void {
    const data = DummyData.user_data;
    // var writer = Kit.String.new();
    // Kit.fastJson(DummyData.UserData, data, &writer) catch return;
    const payload = std.json.stringifyAlloc(Fabric.allocator_global, data, .{}) catch return;
    Kit.fetchWithParams(ROUTES.test_tether_json.full_url, self, cb, .{
        .method = "POST",
        .headers = .{ .content_type = "application/json" },
        .body = payload[0..],
    });
}
