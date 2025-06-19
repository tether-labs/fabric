const std = @import("std");
const Fabric = @import("Fabric.zig");
const Static = Fabric.Static;
var fabric: Fabric = undefined;

var inital: bool = false;
var allocator: std.mem.Allocator = std.heap.page_allocator;

export fn deinit() void {
    fabric.deinit();
}

export fn renderCommands(_: i32, _: i32, route: [*:0]u8) i32 {
    if (inital) {
        Fabric.renderCycle(std.mem.span(route));
        return 0;
    } else {
        Fabric.Page(@src(), About, .{
            .display = .flex,
            .width = .percent(1),
            .height = .percent(1),
            .font_family = "Montserrat",
        });
        inital = true;
        Fabric.println("About page Root", .{});
        return 0;
    }
}

pub fn About() void {
    Static.FlexBox(.{
        .width = .fixed(400),
        .height = .fixed(400),
    })({
        Static.Text("About", .{
            .background = .{ 0, 0, 0, 255 },
            .font_size = 32,
        });
    });
}
pub fn main() !void {}
