const std = @import("std");
const Fabric = @import("Fabric.zig");
const UINode = @import("UITree.zig").UINode;
const ElementType = @import("types.zig").ElementType;

pub const KeyGenerator = struct {
    // Thread-local call counter that resets each render cycle
    threadlocal var call_counter: usize = 0;

    // Call this at the beginning of each render cycle
    pub fn resetCounter() void {
        call_counter = 0;
    }

    // Call this at the beginning of each render cycle
    pub fn getCount() usize {
        return call_counter;
    }

    // Call this at the beginning of each render cycle
    pub fn setCount(count: usize) void {
        call_counter = count;
    }

    pub fn generateKey(
        elem_type: ElementType,
        parent_key: []const u8,
        props: anytype,
        index: ?usize,
        node: *UINode,
        allocator: *std.mem.Allocator,
    ) []const u8 {
        // Increment call counter for each component creation
        const current_count = call_counter;
        call_counter += 1;

        var hasher = std.hash.Wyhash.init(0);

        // Include the type name in the hash
        const tag_name = @tagName(elem_type);
        hasher.update(tag_name);

        // Include parent key in the hash for hierarchical stability
        hasher.update(parent_key);

        // Include the call counter position for this render cycle
        var count_buf: [16]u8 = undefined;
        const count_str = std.fmt.bufPrint(&count_buf, "{d}", .{current_count}) catch &count_buf;
        hasher.update(count_str);

        // If we have an index (for lists), include it
        if (index) |idx| {
            var buf: [16]u8 = undefined;
            const idx_str = std.fmt.bufPrint(&buf, "{d}", .{idx}) catch &buf;
            hasher.update(idx_str);
        }

        // Hash important prop values if available
        if (@hasField(@TypeOf(props), "uuid")) {
            if (@TypeOf(props.uuid) == []const u8) {
                hasher.update(props.key);
            } else {
                // For numeric or other key types, convert to string first
                var buf: [32]u8 = undefined;
                const key_str = std.fmt.bufPrint(&buf, "{any}", .{props.uuid}) catch &buf;
                hasher.update(key_str);
            }
        }

        // Generate the final hash
        const hash = hasher.final();

        // Convert hash to a readable string
        var buf: [48]u8 = undefined;
        const key = std.fmt.bufPrint(&buf, "{x}_{s}_{d}", .{ hash, tag_name[0..@min(4, tag_name.len)], current_count }) catch &buf;

        // Allocate permanent storage for the key
        if (node.dynamic == .animation and node.style.animation != null) {
            const result = std.fmt.allocPrint(allocator.*, "animation-{s}-genk", .{key}) catch |err| {
                Fabric.println("Could not alloc new key {any}", .{err});
                unreachable;
            };
            return result;
        } else {
            const result = std.fmt.allocPrint(allocator.*, "{s}-genk", .{key}) catch |err| {
                Fabric.println("Could not alloc new key {any}", .{err});
                unreachable;
            };
            return result;
        }
        // const result = allocator.alloc(u8, key.len) catch return "fallback_key";
        // @memcpy(result, key);

    }

    // Similar update for generateListItemKey
    pub fn generateListItemKey(
        parent_key: []const u8,
        item_key: anytype,
        index: usize,
    ) []const u8 {
        // Increment call counter for each component creation
        const current_count = call_counter;
        call_counter += 1;

        var hasher = std.hash.Wyhash.init(0);

        // Include parent key in the hash
        hasher.update(parent_key);

        // Include the call counter
        var count_buf: [16]u8 = undefined;
        const count_str = std.fmt.bufPrint(&count_buf, "{d}", .{current_count}) catch &count_buf;
        hasher.update(count_str);

        // Include index for stability even if order changes
        var idx_buf: [16]u8 = undefined;
        const idx_str = std.fmt.bufPrint(&idx_buf, "{d}", .{index}) catch &idx_buf;
        hasher.update(idx_str);

        // Include the item key if it's a string
        if (@TypeOf(item_key) == []const u8) {
            hasher.update(item_key);
        } else {
            // Convert non-string keys to string
            var key_buf: [32]u8 = undefined;
            const key_str = std.fmt.bufPrint(&key_buf, "{any}", .{item_key}) catch &key_buf;
            hasher.update(key_str);
        }

        // Generate the final hash
        const hash = hasher.final();

        // Convert hash to a readable string
        var buf: [64]u8 = undefined;
        const key = std.fmt.bufPrint(&buf, "li_{x}_{d}_{d}", .{ hash, index, current_count }) catch &buf;

        // Allocate permanent storage for the key
        var allocator = std.heap.page_allocator;
        const result = allocator.alloc(u8, key.len) catch return "fallback_key";
        std.mem.copy(u8, result, key);

        return result;
    }
};
