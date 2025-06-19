const Fabric = @import("Fabric.zig");
const Static = Fabric.Static;
const desc =
    \\ Error page could not be found please contact the developer team or customer service. 
;
pub fn render() void {
    Fabric.printlnSrc("Rerender Error page\n", .{}, @src());
    // Navbar.render();
    Static.FlexBox(.{
        .width = .percent(1),
        .height = .percent(1),
        .font_family = "Montserrat",
        .direction = .column,
        .child_alignment = .{ .y = .center, .x = .start },
    })({
        Static.Block(.{
            .margin = .{ .top = 100 },
            .width = .percent(0.7),
            .height = .percent(1),
            .child_alignment = .{ .y = .center, .x = .start },
            .direction = .column,
        })({
            Static.Header("Error Page could not be found", .Medium, .{
                .font_weight = 900,
                .font_size = 50,
                .margin = .all(10),
                .padding = .all(0),
            })({});
            Static.Text(desc, .{
                .font_size = 16,
                .margin = .all(10),
                .padding = .all(0),
            });
        });
    });
}

pub fn Page() void {
    // dialog_element = element;
    Fabric.Page(@src(), render, null, .{
        .width = .percent(1),
        .height = .percent(1),
        .font_family = "Montserrat",
        .direction = .column,
        .child_alignment = .{ .y = .center, .x = .start },
    });
}
