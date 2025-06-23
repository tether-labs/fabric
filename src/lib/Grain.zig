const std = @import("std");
const UINode = @import("UITree.zig").UINode;
const Signal = Fabric.Signal;
const LifeCycle = Fabric.LifeCycle;
const ElementDecl = Fabric.ElementDecl;
const Style = Fabric.Style;
const println = @import("Fabric.zig").println;
const Fabric = @import("Fabric.zig");

/// Grain FlexBox
/// Takes a signal, and attaches it to this node, ie only this node will update, none of its children
pub inline fn FlexBox(comptime T: type, signal: *Signal(T), style: Style) fn (void) void {
    const elem_decl = ElementDecl{
        .style = style,
        .dynamic = .grain,
        .elem_type = .FlexBox,
    };

    const ui_node = LifeCycle.open(elem_decl);
    LifeCycle.configure(elem_decl);
    signal.subscribe(ui_node);
    return LifeCycle.close;
}

/// Grain Text 
/// Takes a signal, and attaches it to this node, ie only this node will update, none of its children
pub inline fn Text(signal: *Signal([]const u8), style: Style) void {
    const elem_decl = ElementDecl{
        .style = style,
        .dynamic = .grain,
        .elem_type = .Text,
        .text = signal.get(),
    };

    const ui_node = LifeCycle.open(elem_decl) orelse return;
    LifeCycle.configure(elem_decl);
    signal.subscribe(ui_node);
    LifeCycle.close({});
}
