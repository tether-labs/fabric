const std = @import("std");
const Fabric = @import("Fabric.zig");
const Static = Fabric.Static;

const getHoverStyle = @import("convertHover.zig").getHoverStyle;
const getStyle = @import("convertStyle.zig").getStyle;
const generateInputHTML = @import("grabInputDetails.zig").generateInputHTML;
const grabInputDetails = @import("grabInputDetails.zig");
const createInput = grabInputDetails.createInput;
const getInputSize = grabInputDetails.getInputSize;
const getInputType = grabInputDetails.getInputType;
var fabric: Fabric = undefined;

var inital: bool = false;
var allocator: std.mem.Allocator = std.heap.page_allocator;

export fn deinit() void {
    fabric.deinit();
}

export fn renderCommands(window_width: i32, window_height: i32, route: [*:0]u8) i32 {
    if (inital) {
        Fabric.renderCycle(std.mem.span(route));
        return 0;
    } else {
        fabric.init(.{
            .screen_width = window_width,
            .screen_height = window_height,
            .allocator = &allocator,
        });

        Fabric.Page(@src(), Docs, .{
            .display = .flex,
            .width = .percent(1),
            .height = .percent(1),
            .font_family = "Montserrat",
        });
        inital = true;

        Fabric.println("Docs page Root", .{});
        return 0;
    }
}

pub fn Docs() void {
    Static.FlexBox(.{
        .width = .fixed(400),
        .height = .fixed(400),
    })({
        Static.Text("Docs", .{
            .background = .{ 0, 0, 0, 255 },
            .font_size = 32,
        });
    });
}

pub fn main() !void {}
