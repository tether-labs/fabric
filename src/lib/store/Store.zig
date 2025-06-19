const Fabric = @import("../Fabric.zig");
const std = @import("std");
const Allocator = std.mem.Allocator;
const Signal = Fabric.Signal;

const SampleStore = @This();
var global_counter: Signal(u32) = undefined;
local_allocator: *Allocator,

pub fn init(store: *SampleStore, allocator: *Allocator) void {
    store.* = .{
        .local_allocator = allocator,
    };
    global_counter = Signal(u32).init(0, store.local_allocator);
}
