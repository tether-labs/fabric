const std = @import("std");
const Fabric = @import("Fabric.zig");
const print = std.debug.print;

pub fn main() !void {
    Fabric.FlexBox(.{
        .position = .{ .x = 0, .y = 0, .type = .absolute },
        .width = .fixed(300),
        .height = .fixed(300),
        .direction = .column,
        .child_alignment = .{ .x = .center, .y = .center },
        .background = .{ 72, 44, 254, 1 },
    })({
        Fabric.FlexBox(.{
            .position = .{ .x = 0, .y = 0, .type = .absolute },
            .width = .grow,
            .height = .fixed(200),
        })({
            for (0..10) |i| {
                print("{any}\n", .{i});
            }
        });
    });
}
