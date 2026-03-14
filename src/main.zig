//! By convention, main.zig is where your main function lives in the case that
//! you are building an executable. If you are making a library, the convention
//! is to delete this file and start with root.zig instead.

const std = @import("std");
pub fn main() !void {
    // const route = std.mem.Allocator.dupeZ(std.heap.page_allocator, u8, "/root/index.html") catch unreachable;
    // _ = Vapor.lib.renderCycle(route);
}
