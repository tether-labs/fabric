const std = @import("std");
const types = @import("types.zig");
const Fabric = @import("Fabric.zig");
const LifeCycle = Fabric.LifeCycle;
const println = Fabric.println;
const Element = @import("Element.zig").Element;

const Style = types.Style;
const InputDetails = types.InputDetails;
const InputParams = types.InputParams;
const ElementDecl = types.ElementDeclaration;

pub inline fn Center(element: *Element, style: Style) fn (void) void {
    var elem_decl = ElementDecl{
        .style = style,
        .dynamic = .static,
        .elem_type = .FlexBox,
    };
    elem_decl.style.child_alignment.x = .center;
    elem_decl.style.child_alignment.y = .center;

    const ui_node = LifeCycle.open(elem_decl);
    LifeCycle.configure(elem_decl);
    element._node_ptr = ui_node;
    return LifeCycle.close;
}

pub inline fn Box(element: *Element, style: Style) fn (void) void {
    const elem_decl = ElementDecl{
        .style = style,
        .dynamic = .dynamic,
        .elem_type = .FlexBox,
    };
    const ui_node = LifeCycle.open(elem_decl) orelse unreachable;
    _ = LifeCycle.configure(elem_decl);
    element._node_ptr = ui_node;
    return LifeCycle.close;
}

pub inline fn FlexBox(element: *Element, style: Style) fn (void) void {
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
        .dynamic = .dynamic,
        .elem_type = .FlexBox,
    };
    const ui_node = Fabric.current_ctx.open(elem_decl) catch |err| {
        println("{any}\n", .{err});
        unreachable;
    };
    _ = local.ConfigureElement(elem_decl);
    element._node_ptr = ui_node;
    return local.CloseElement;
}

pub inline fn JsonEditor(element: *Element, text: []const u8, style: Style) void {
    const local = struct {
        fn CloseElement() void {
            _ = Fabric.current_ctx.close();
            return;
        }
        fn ConfigureElement(elem_decl: ElementDecl) void {
            _ = Fabric.current_ctx.configure(elem_decl);
        }
    };

    var elem_decl = ElementDecl{
        .style = style,
        .dynamic = .dynamic,
        .elem_type = .JsonEditor,
        .text = text,
    };
    elem_decl.style.id = element.id.?;

    const ui_node = Fabric.current_ctx.open(elem_decl) catch |err| {
        println("{any}\n", .{err});
        unreachable;
    };
    local.ConfigureElement(elem_decl);
    element._node_ptr = ui_node;
    local.CloseElement();
    return;
}

pub inline fn InputV2(element: *Element, params: InputParams, style: Style) void {
    const local = struct {
        fn CloseElement() void {
            _ = Fabric.current_ctx.close();
            return;
        }
        fn ConfigureElement(elem_decl: ElementDecl) void {
            _ = Fabric.current_ctx.configure(elem_decl);
        }
    };

    const elem_decl = ElementDecl{
        .style = style,
        .dynamic = .dynamic,
        .elem_type = .Input,
        .input_params = params,
    };

    const ui_node = Fabric.current_ctx.open(elem_decl) catch |err| {
        println("{any}\n", .{err});
        unreachable;
    };
    local.ConfigureElement(elem_decl);
    element._node_ptr = ui_node;
    element.element_type = elem_decl.elem_type;

    // if (params == .string) {
    //     if (params.string.onInput) |func| {
    //         const id = Fabric.events_callbacks.count();
    //         Fabric.events_callbacks.put(id, func) catch |err| {
    //             println("Event Callback Error: {any}\n", .{err});
    //         };
    //     }
    // }

    local.CloseElement();
    return;
}

pub inline fn Input(element: *Element, params: InputParams, style: Style) void {
    const local = struct {
        fn CloseElement() void {
            _ = Fabric.current_ctx.close();
            return;
        }
        fn ConfigureElement(elem_decl: ElementDecl) void {
            _ = Fabric.current_ctx.configure(elem_decl);
        }
    };

    const elem_decl = ElementDecl{
        .style = style,
        .dynamic = .dynamic,
        .elem_type = .Input,
        .input_params = params,
    };
    element.element_type = .Input;

    const ui_node = Fabric.current_ctx.open(elem_decl) catch |err| {
        println("{any}\n", .{err});
        unreachable;
    };
    local.ConfigureElement(elem_decl);
    element._node_ptr = ui_node;
    local.CloseElement();
    return;
}

pub inline fn Dialog(element: *Element, style: Style) fn (void) void {
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
        .dynamic = .dynamic,
        .elem_type = .Dialog,
    };

    const ui_node = Fabric.current_ctx.open(elem_decl) catch |err| {
        println("{any}\n", .{err});
        unreachable;
    };
    _ = local.ConfigureElement(elem_decl);
    element._node_ptr = ui_node;
    element.element_type = .Dialog;
    return local.CloseElement;
}
