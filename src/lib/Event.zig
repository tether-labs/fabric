const std = @import("std");
const UINode = @import("UITree.zig").UINode;
const Fabric = @import("Fabric.zig");
const types = @import("types.zig");

export fn getEventType(node_ptr: ?*UINode) types.EventType {
    if (node_ptr.?.event_type) |et| {
        return et;
    }
    return types.EventType.none;
}
