const std = @import("std");
const types = @import("types.zig");
const UIContext = @import("UITree.zig");
const UINode = @import("UITree.zig").UINode;
const CommandsTree = UIContext.CommandsTree;
const Signal = @import("Rune.zig").Signal;
const Element = @import("Element.zig").Element;
const Fabric = @import("Fabric.zig");
const Grain = Fabric.Grain;
const LifeCycle = Fabric.LifeCycle;

const Style = types.Style;
const EventType = types.EventType;
const Active = types.Active;
const BoundingBox = types.BoundingBox;
const InputDetails = types.InputDetails;
const Dimensions = types.Dimensions;
const InputParams = types.InputParams;
const ElementDecl = types.ElementDeclaration;
const RenderCommand = types.RenderCommand;
const ElementType = types.ElementType;
const Hover = types.Hover;
const Transform = types.Transform;
const TransformType = types.TransformType;

pub inline fn List(comptime T: type, signal_ptr: *Signal([]T), style: Style) fn (void) void {
    Fabric.println("Has key field {any}\n", .{@hasField(T, "key")});
    std.debug.assert(@hasField(T, "key"));
    const local = struct {
        fn CloseElement(_: void) void {
            _ = Fabric.current_ctx.close();
            return;
        }
        fn ConfigureElement(elem_decl: ElementDecl) *const fn (void) void {
            _ = Fabric.current_ctx.configure(elem_decl);
            return CloseElement;
        }
    };
    const elem_decl = ElementDecl{
        .style = style,
        .elem_type = .List,
        .dynamic = .dynamic,
    };
    const ui_node = Fabric.current_ctx.open(elem_decl) catch |err| {
        Fabric.println("{any}\n", .{err});
        unreachable;
    };
    _ = local.ConfigureElement(elem_decl);
    signal_ptr.subscribe(ui_node);
    return local.CloseElement;
}

pub inline fn ListItem(key: []const u8, style: Style) fn (void) void {
    const local = struct {
        fn CloseElement(_: void) void {
            _ = Fabric.current_ctx.close();
            return;
        }
        fn ConfigureElement(elem_decl: ElementDecl) *const fn (void) void {
            _ = Fabric.current_ctx.configure(elem_decl);
            return CloseElement;
        }
    };

    var elem_decl = ElementDecl{
        .style = style,
        .elem_type = .ListItem,
        .dynamic = .dynamic,
    };
    elem_decl.style.id = key;
    const node = Fabric.current_ctx.open(elem_decl) catch |err| {
        Fabric.println("Could not open ListItem Element {any}\n", .{err});
        unreachable;
    };
    node.uuid = key;
    _ = local.ConfigureElement(elem_decl);
    return local.CloseElement;
}

const HeaderSize = enum(u32) {
    XXLarge = 12,
    XLarge = 8,
    Large = 4,
    Medium = 2,
    Small = 1,
};

pub inline fn Header(
    comptime T: type,
    signal_ptr: *Signal(T),
    size: HeaderSize,
    style: Style,
) fn (void) void {
    const local = struct {
        fn CloseElement(_: void) void {
            _ = Fabric.current_ctx.close();
            return;
        }
        fn ConfigureElement(elem_decl: ElementDecl) *const fn (void) void {
            _ = Fabric.current_ctx.configure(elem_decl);
            return CloseElement;
        }
    };

    var text: []const u8 = "";
    switch (T) {
        usize, u32, i32, f32 => {
            text = std.fmt.allocPrint(signal_ptr.allocator_ptr.*, "{any}", .{signal_ptr.get()}) catch unreachable;
        },
        []const u8 => {
            text = signal_ptr.get();
        },
        else => {},
    }

    var elem_decl = ElementDecl{
        .style = style,
        .elem_type = .Header,
        .text = text,
        .dynamic = .dynamic,
    };

    if (style.font_size == 0) {
        switch (size) {
            .XXLarge => elem_decl.style.font_size = 12 * 12,
            .XLarge => elem_decl.style.font_size = 12 * 8,
            .Large => elem_decl.style.font_size = 12 * 4,
            .Medium => elem_decl.style.font_size = 12 * 2,
            .Small => elem_decl.style.font_size = 12 * 1,
        }
    }

    const ui_node = Fabric.current_ctx.open(elem_decl) catch |err| {
        Fabric.println("{any}\n", .{err});
        unreachable;
    };
    signal_ptr.subscribe(ui_node);
    _ = local.ConfigureElement(elem_decl);
    return local.CloseElement;
}

pub inline fn Text(comptime T: type, grain: *Grain(T), style: Style) void {
    const local = struct {
        fn CloseElement() void {
            _ = Fabric.current_ctx.close();
            return;
        }
        fn ConfigureElement(elem_decl: ElementDecl) void {
            _ = Fabric.current_ctx.configure(elem_decl);
            return;
        }
    };

    var text: []const u8 = "";
    switch (T) {
        usize, u32, i32, f32 => {
            text = std.fmt.allocPrint(grain.allocator_ptr.*, "{any}", .{grain.get()}) catch unreachable;
        },
        []const u8 => {
            text = grain.get();
        },
        else => {},
    }

    const elem_decl = ElementDecl{
        .style = style,
        .elem_type = .Text,
        .text = text,
        .dynamic = .dynamic,
    };

    const ui_node = Fabric.current_ctx.open(elem_decl) catch |err| {
        Fabric.println("{any}\n", .{err});
        unreachable;
    };
    grain.subscribe(ui_node);
    _ = local.ConfigureElement(elem_decl);
    local.CloseElement();
    return;
}
pub inline fn If(signal_ptr: *Signal(bool)) fn (void) void {
    Fabric.println("INSTATIATION OF IFFFFF", .{});
    const local = struct {
        fn CloseElement(_: void) void {
            _ = Fabric.current_ctx.close();
            return;
        }
        fn ConfigureElement(elem_decl: ElementDecl) *const fn (void) void {
            _ = Fabric.current_ctx.configure(elem_decl);
            return CloseElement;
        }
    };

    const elem_decl = ElementDecl{
        .elem_type = ._If,
        .show = signal_ptr.get(),
    };

    const ui_node = Fabric.current_ctx.open(elem_decl) catch |err| {
        Fabric.println("{any}\n", .{err});
        unreachable;
    };
    ui_node.style.background = .{ 0, 0, 0, 255 };
    _ = local.ConfigureElement(elem_decl);
    signal_ptr.subscribe(ui_node);
    return local.CloseElement;
}

pub inline fn Input(
    comptime T: type,
    signal_ptr: *Signal(T),
    params: InputParams,
    style: Style,
) void {
    const local = struct {
        fn CloseElement() void {
            _ = Fabric.current_ctx.close();
            return;
        }
        fn ConfigureElement(elem_decl: ElementDecl) void {
            _ = Fabric.current_ctx.configure(elem_decl);
        }
    };

    var text: []const u8 = "";
    switch (T) {
        usize, u32, i32, f32 => {
            text = std.fmt.allocPrint(signal_ptr.allocator_ptr.*, "{any}", .{signal_ptr.get()}) catch unreachable;
        },
        []const u8 => {
            text = signal_ptr.get();
        },
        else => {},
    }
    Fabric.println("Dynamic Input Field text {s}\n", .{text});

    const elem_decl = ElementDecl{
        .style = style,
        .elem_type = .Input,
        .text = text,
        .dynamic = .dynamic,
        .input_params = params,
    };

    const ui_node = Fabric.current_ctx.open(elem_decl) catch |err| {
        Fabric.println("{any}\n", .{err});
        unreachable;
    };
    signal_ptr.subscribe(ui_node);
    local.ConfigureElement(elem_decl);

    local.CloseElement();
    return;
}


pub inline fn FlexBox(comptime T : type, signal: *Signal(T), style: Style) fn (void) void {
    const elem_decl = ElementDecl{
        .style = style,
        .dynamic = .static,
        .elem_type = .FlexBox,
    };

    const ui_node = LifeCycle.open(elem_decl);
    LifeCycle.configure(elem_decl);
    signal.subscribe(ui_node);
    return LifeCycle.close;
}
