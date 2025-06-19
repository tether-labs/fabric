const std = @import("std");
const Fabric = @import("Fabric.zig");
const println = @import("Fabric.zig").println;
const getHoverStyle = @import("convertHover.zig").getHoverStyle;
const getStyle = @import("convertStyle.zig").getStyle;
const grabInputDetails = @import("grabInputDetails.zig");
const createInput = grabInputDetails.createInput;
const getInputSize = grabInputDetails.getInputSize;
const getInputType = grabInputDetails.getInputType;
const TrackingAllocator = @import("TrackingAllocator.zig").TrackingAllocator;
var fabric: Fabric = undefined;

var initial: bool = true;
var allocator: std.mem.Allocator = undefined;
pub var ta: TrackingAllocator = undefined;

export fn deinit() void {
    fabric.deinit();
}

export fn instantiate(window_width: i32, window_height: i32) void {
    fabric.init(.{
        .screen_width = window_width,
        .screen_height = window_height,
        .allocator = &allocator,
    });
    return 0;
}

export fn renderCommands(_: i32, _: i32, route_ptr: [*:0]u8) i32 {
    const route = std.mem.span(route_ptr);
    Fabric.renderCycle(route);
    Fabric.allocator_global.free(route);
    ta._is_runtime = true;
    return 0;
}

pub fn create() !void {
    allocator = ta.init(std.heap.wasm_allocator);
    _ = getStyle(null);
    _ = getHoverStyle(null);
    _ = createInput(null);
    _ = getInputType(null);
    _ = getInputSize(null);
}
