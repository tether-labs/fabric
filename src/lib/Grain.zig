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

const GrainProps = struct {
    signal: *Signal([]const u8),
    id: []const u8,
};

pub inline fn Icon(grain_props: GrainProps, style: Style) void {
    const elem_decl = ElementDecl{
        .href = grain_props.signal.get(),
        .elem_type = .Icon,
        .style = style,
        .dynamic = .grain,
    };
    const ui_node = LifeCycle.open(elem_decl) orelse return;
    LifeCycle.configure(elem_decl);
    grain_props.signal.subscribe(ui_node);
    LifeCycle.close({});
}
