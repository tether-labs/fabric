const std = @import("std");
const Fabric = @import("../Fabric.zig");
const Signal = Fabric.Signal;
const Static = Fabric.Static;
const Pure = Fabric.Pure;
const Dynamic = Fabric.Dynamic;
const Style = Fabric.Style;
const Animation = Fabric.Animation;
const DateTime = Fabric.DateTime;

var date_time: DateTime = DateTime.now();

fn closeNotification(sig: *Signal(bool)) void {
    sig.set(false);
}

pub fn render(show_signal: *Signal(bool), text: []const u8) void {
    const show = show_signal.get();
    if (show) {
        Fabric.registerCtxTimeout(2000, closeNotification, .{show_signal});
        // Here we attach an id
        Animation.FlexBox(
            .{
                .position = .{
                    .type = .absolute,
                    .bottom = .fixed(20),
                    .right = .fixed(20),
                },
                .border_radius = .all(8),
                .border_thickness = .all(1),
                .border_color = Fabric.Theme.getAttribute("border_color"),
                .height = .fixed(60),
                .width = .fixed(240),
                .background = Fabric.Theme.getAttribute("primary"),
                .z_index = 1002,
                .padding = .{ .left = 8, .right = 8, .bottom = 0, .top = 0 },
                .child_gap = 16,
                .child_alignment = .{ .x = .start, .y = .center },
            },
            .fadeInOutY,
        )({
            Static.Icon("bi bi-check-circle-fill", .{
                .text_color = Fabric.Theme.getAttribute("secondary"),
                .font_size = 20,
                .background = .{ 0, 0, 0, 0 },
            });
            Static.Block(.{
                .display = .flex,
                .direction = .column,
                .child_alignment = .{ .y = .start, .x = .center },
                .child_gap = 4,
            })({
                Static.Text(text, .{
                    .font_family = "Montserrat",
                    .font_weight = 500,
                    .font_size = 14,
                    .text_color = Fabric.Theme.getAttribute("secondary"),
                });
                Pure.Text(DateTime.format(DateTime.now(), Fabric.allocator_global) catch "", .{
                    .font_family = "Montserrat",
                    .font_weight = 300,
                    .font_size = 12,
                    .text_color = Fabric.hexToRgba("#888888"),
                });
            });
        });
    }
}
