const std = @import("std");
const mem = std.mem;
const Allocator = mem.Allocator;
const Arena = std.heap.ArenaAllocator;
const UINode = @import("UITree.zig").UINode;
const Item = @import("UITree.zig").Item;

// The FrameAllocator is a simple allocator that allocates memory per render cycle.
// It is used to allocate memory for the render commands and the UI tree, text, and styles, etc.
// It is also used to allocate memory for the persistent arena, which is used to store data that
// should persist across frames.

// For each render cycle, beginFrame() is called to reset the current frame arena and get ready to allocate memory, for
// the next frame. This means we can just deinit a single allocator and there is no need to recurse down the tree.

// This gets attached to each route in your radix tree
pub const RouteFrameArena = struct {
    frames: [NUMBER_OF_FRAMES]FrameData,
    view: FrameData,
    current_frame: usize = 0,

    pub fn init(backing_allocator: Allocator) RouteFrameArena {
        return .{
            .frames = .{
                .{ .arena = Arena.init(backing_allocator) },
                .{ .arena = Arena.init(backing_allocator) },
            },
            .view = .{ .arena = Arena.init(backing_allocator) },
        };
    }

    pub fn deinit(self: *RouteFrameArena) void {
        self.frames[0].arena.deinit();
        self.frames[1].arena.deinit();
        self.view.arena.deinit();
    }

    pub fn allocator(self: *RouteFrameArena) Allocator {
        return self.frames[self.current_frame].arena.allocator();
    }

    pub fn viewAllocator(self: *RouteFrameArena) Allocator {
        return self.view.arena.allocator();
    }

    pub fn beginView(self: *RouteFrameArena) void {
        _ = self.view.arena.reset(.retain_capacity);
    }

    pub fn beginFrame(self: *RouteFrameArena) void {
        const next = (self.current_frame + 1) % 2;
        _ = self.frames[next].arena.reset(.retain_capacity);
        self.frames[next].stats = .{};
        self.current_frame = next;
    }

    pub fn getStats(self: *RouteFrameArena) Stats {
        return self.frames[self.current_frame].stats;
    }

    pub fn incrementNodeCount(self: *RouteFrameArena) void {
        self.frames[self.current_frame].stats.nodes_memory += @sizeOf(UINode);
        self.frames[self.current_frame].stats.nodes_allocated += 1;
    }
    pub fn incrementItemCount(self: *RouteFrameArena) void {
        self.frames[self.current_frame].stats.item_memory += @sizeOf(Item);
        self.frames[self.current_frame].stats.items_allocated += 1;
    }

    pub fn addBytesUsed(self: *RouteFrameArena, bytes: usize) void {
        self.frames[self.current_frame].stats.bytes_used += bytes;
    }

    pub fn queryBytesUsed(self: *RouteFrameArena) usize {
        const current_frame = self.frames[self.current_frame];
        const current_total = current_frame.arena.queryCapacity();
        return current_total;
    }

    /// This is now just a simple, fast create() from the arena
    pub fn nodeAlloc(self: *RouteFrameArena) ?*UINode {
        // This is just a fast pointer bump
        // const node = self.persistentAllocator().create(UINode) catch {
        const node = self.frames[self.current_frame].arena.allocator().create(UINode) catch {
            // This will only fail if you run out of memory (OOM)
            // or the backing allocator fails.
            return null;
        };
        // You could even initialize the node here if needed
        return node;
    }
};

const FrameData = struct {
    arena: Arena,
    stats: Stats = .{},
};

const NUMBER_OF_FRAMES = 2;

pub const Stats = struct {
    nodes_allocated: usize = 0,
    tree_memory: usize = 0,
    command_memory: usize = 0,
    commands_allocated: usize = 0,
    bytes_used: usize = 0,
    nodes_memory: usize = 0,
    item_memory: usize = 0,
    items_allocated: usize = 0,
};

const FrameAllocator = @This();
persistent_arena: Arena,
// frames: [NUMBER_OF_FRAMES]FrameData,
// current_frame: usize = 0,
view: [NUMBER_OF_FRAMES]FrameData,
current_route: usize = 0,
request_arena: Arena,
scratch_arena: Arena,
// Pointer to current route's frame arena
current_route_arena: ?*RouteFrameArena = null,
backing_allocator: Allocator,

pub fn init(backing_allocator: Allocator) FrameAllocator {
    var views: [NUMBER_OF_FRAMES]FrameData = undefined;
    for (0..NUMBER_OF_FRAMES) |i| {
        views[i] = .{ .arena = Arena.init(backing_allocator) };
    }

    return .{
        .persistent_arena = Arena.init(backing_allocator),
        .request_arena = Arena.init(backing_allocator),
        .scratch_arena = Arena.init(backing_allocator),
        .backing_allocator = backing_allocator,
        .view = views,
    };
}

pub fn deinit(self: *FrameAllocator) void {
    self.persistent_arena.deinit();
    self.request_arena.deinit();
    self.scratch_arena.deinit();
    // Note: route arenas are owned by the radix tree, not us
}

// Call this to create a new RouteFrameArena for a route
pub fn createRouteArena(self: *FrameAllocator) *RouteFrameArena {
    const route_arena = self.backing_allocator.create(RouteFrameArena) catch unreachable;
    route_arena.* = RouteFrameArena.init(self.backing_allocator);
    return route_arena;
}

// Call this when switching routes
pub fn setCurrentRoute(self: *FrameAllocator, route_arena: *RouteFrameArena) void {
    self.current_route_arena = route_arena;
}

// Get the current route's frame allocator
pub fn frameAllocator(self: *FrameAllocator) Allocator {
    if (self.current_route_arena) |route| {
        return route.allocator();
    }
    std.log.err("Cannot access the frame allocator, first create the Route via Page() then proceed with initliazation", .{});
    return self.persistentAllocator();
    // @panic("No route set - call setCurrentRoute first");
}

// Begin frame on the current route
pub fn beginFrame(self: *FrameAllocator) void {
    if (self.current_route_arena) |route| {
        route.beginFrame();
    }
}

pub fn beginView(self: *FrameAllocator) void {
    if (self.current_route_arena) |route| {
        route.beginView();
    }
    // // Move to next frame
    // const next_route = (self.current_route + 1) % NUMBER_OF_FRAMES;
    //
    // // Clear the route we're about to use
    // _ = self.view[next_route].arena.reset(.retain_capacity);
    // self.view[next_route].stats = .{};
    //
    // self.current_route = next_route;
}

pub fn persistentAllocator(self: *FrameAllocator) Allocator {
    return self.backing_allocator;
}

pub fn requestAllocator(self: *FrameAllocator) Allocator {
    return self.request_arena.allocator();
}

pub fn resetScratchArena(self: *FrameAllocator) void {
    _ = self.scratch_arena.reset(.free_all);
}

pub fn viewAllocator(self: *FrameAllocator) Allocator {
    return self.view[self.current_route].arena.allocator();
}

// pub fn deinit(self: *FrameAllocator) void {
//     self.frames[0].arena.deinit();
//     self.frames[1].arena.deinit();
//     self.persistent_arena.deinit();
// }
//
// pub fn frameAllocator(self: *FrameAllocator) std.mem.Allocator {
//     return self.frames[self.current_frame].arena.allocator();
// }
//
// pub fn requestAllocator(self: *FrameAllocator) std.mem.Allocator {
//     return self.request_arena.allocator();
// }

// pub fn viewAllocator(self: *FrameAllocator) std.mem.Allocator {
//     return self.view[self.current_route].arena.allocator();
// }

pub fn incrementNodeCount(self: *FrameAllocator) void {
    if (self.current_route_arena) |route| {
        route.incrementNodeCount();
    }
}

pub fn incrementItemCount(self: *FrameAllocator) void {
    if (self.current_route_arena) |route| {
        route.incrementItemCount();
    }
}

pub fn addBytesUsed(self: *FrameAllocator, bytes: usize) void {
    if (self.current_route_arena) |route| {
        route.addBytesUsed(bytes);
    }
}

pub fn queryBytesUsed(self: *FrameAllocator) usize {
    if (self.current_route_arena) |route| {
        return route.queryBytesUsed();
    }
}

pub fn queryNodes(self: *FrameAllocator) usize {
    const total = self.frames[self.current_frame].stats.nodes_allocated;
    // Vapor.println("-------------Nodes Allocated {d}", .{self.frames[self.current_frame].stats.nodes_allocated});
    return total;
}

/// This is now just a simple, fast create() from the arena
pub fn nodeAlloc(self: *FrameAllocator) ?*UINode {
    if (self.current_route_arena) |route| {
        return route.nodeAlloc();
    }
    return null;
}

/// Get stats for current frame
pub fn getStats(self: *FrameAllocator) ?Stats {
    if (self.current_route_arena) |route| {
        return route.getStats();
    }
    return null;
}

pub fn printPrevStats(_: *FrameAllocator) void {
    // var buffer: [4096]u8 = undefined;
    // var writer = std.io.Writer.fixed(&buffer);
    //
    // const stats = self.getStats();
    //
    // const color_buf = std.fmt.allocPrint(Vapor.allocator_global, "color: {s};", .{convertColorToString(.hex("#4800FF"))}) catch return;
    // writer.print("%c", .{}) catch return;
    // writer.print("╔══════════════════════════════╗\n", .{}) catch return;
    // writer.print("║       Prev Frame Stats       ║\n", .{}) catch return;
    // writer.print("╠══════════════════════════════╣\n", .{}) catch return;
    // writer.print("║ Nodes allocated    : {d: >7} ║\n", .{stats.nodes_allocated}) catch return;
    // writer.print("║ Commands allocated : {d: >7} ║\n", .{stats.commands_allocated}) catch return;
    // writer.print("║ Bytes used         : {d: >7} ║\n", .{stats.bytes_used}) catch return;
    // writer.print("╚══════════════════════════════╝\n", .{}) catch return;
    // writer.print("%c", .{}) catch return;
    // const style_2 = "";
    // if (isWasi) {
    //     _ = Wasm.consoleLogColoredWasm(buffer[0..writer.end].ptr, buffer[0..writer.end].len, color_buf[0..].ptr, color_buf.len, style_2[0..].ptr, style_2.len);
    // } else {
    //     // std.debug.print("{s}\n", .{buffer[0..writer.end]});
    // }
}

pub fn printStats(_: *FrameAllocator) void {
    // var buffer: [4096]u8 = undefined;
    // var writer = std.io.Writer.fixed(&buffer);
    //
    // const stats = self.getStats();
    //
    // const color_buf = std.fmt.allocPrint(Vapor.allocator_global, "color: {s};", .{convertColorToString(.hex("#4800FF"))}) catch return;
    // writer.print("%c", .{}) catch return;
    // writer.print("╔══════════════════════════════╗\n", .{}) catch return;
    // writer.print("║    Frame Allocator Stats     ║\n", .{}) catch return;
    // writer.print("╠══════════════════════════════╣\n", .{}) catch return;
    // writer.print("║ Max Node count     : {d: >7} ║\n", .{Vapor.page_node_count}) catch return;
    // writer.print("║ Nodes allocated    : {d: >7} ║\n", .{stats.nodes_allocated}) catch return;
    // writer.print("║ Commands allocated : {d: >7} ║\n", .{stats.commands_allocated}) catch return;
    // writer.print("║ Bytes used         : {d: >7} ║\n", .{stats.bytes_used}) catch return;
    // writer.print("╚══════════════════════════════╝\n", .{}) catch return;
    // writer.print("%c", .{}) catch return;
    // const style_2 = "";
    // if (isWasi) {
    //     _ = Wasm.consoleLogColoredWasm(buffer[0..writer.end].ptr, buffer[0..writer.end].len, color_buf[0..].ptr, color_buf.len, style_2[0..].ptr, style_2.len);
    // } else {
    //     // std.debug.print("{s}\n", .{buffer[0..writer.end]});
    // }
}
