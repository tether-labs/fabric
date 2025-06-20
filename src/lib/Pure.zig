const std = @import("std");
const types = @import("types.zig");
const Fabric = @import("Fabric.zig");
const println = Fabric.println;
const UIContext = @import("UITree.zig");
const UINode = @import("UITree.zig").UINode;
const CommandsTree = UIContext.CommandsTree;
const Transition = @import("Transition.zig").Transition;
const TransitionState = @import("Transition.zig").TransitionState;
const Element = @import("Element.zig").Element;

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

const HeaderSize = enum(u32) {
    XXLarge = 12,
    XLarge = 8,
    Large = 4,
    Medium = 2,
    Small = 1,
};

pub inline fn Icon(icon_name: []const u8, style: Style) void {
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

    const elem_decl = ElementDecl{
        .href = icon_name,
        .elem_type = .Icon,
        .style = style,
        .dynamic = .pure,
    };

    // if (style.style_id == null) {
    //     elem_decl.style.style_id = icon_name;
    // }

    _ = Fabric.current_ctx.open(elem_decl) catch |err| {
        println("{any}\n", .{err});
    };
    _ = local.ConfigureElement(elem_decl);
    _ = local.CloseElement();
}

pub inline fn Header(text: []const u8, size: HeaderSize, style: Style) void {
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

    var elem_decl = ElementDecl{
        .style = style,
        .dynamic = .pure,
        .elem_type = .Header,
        .text = text,
    };
    // const dimensions = measureText(text, &elem_decl.style);
    // // Make sure this is the right order of ops
    // elem_decl.style.width = dimensions.width;
    // elem_decl.style.height = dimensions.height;
    elem_decl.style.width.type = .elastic;
    if (style.font_size == 0) {
        switch (size) {
            .XXLarge => elem_decl.style.font_size = 12 * 12,
            .XLarge => elem_decl.style.font_size = 12 * 8,
            .Large => elem_decl.style.font_size = 12 * 4,
            .Medium => elem_decl.style.font_size = 12 * 2,
            .Small => elem_decl.style.font_size = 12 * 1,
        }
    }
    _ = Fabric.current_ctx.open(elem_decl) catch |err| {
        println("{any}\n", .{err});
    };
    _ = local.ConfigureElement(elem_decl);
    _ = local.CloseElement();
    return;
}
pub inline fn Hooks(hooks: Fabric.HooksFuncs) fn (void) void {
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
        .elem_type = .Hooks,
    };

    if (hooks.mounted) |f| {
        const id = Fabric.mounted_funcs.count();
        elem_decl.hooks.mounted_id += id + 1;
        Fabric.mounted_funcs.put(elem_decl.hooks.mounted_id, f) catch |err| {
            println("Mount Function Registry {any}\n", .{err});
        };
    }
    if (hooks.created) |f| {
        const id = Fabric.created_funcs.count();
        elem_decl.hooks.created_id += id + 1;
        Fabric.created_funcs.put(elem_decl.hooks.created_id, f) catch |err| {
            println("Mount Function Registry {any}\n", .{err});
        };
    }
    if (hooks.updated) |f| {
        const id = Fabric.updated_funcs.count();
        elem_decl.hooks.updated_id += id + 1;
        Fabric.updated_funcs.put(elem_decl.hooks.updated_id, f) catch |err| {
            println("Mount Function Registry {any}\n", .{err});
        };
    }
    if (hooks.destroy) |f| {
        const id = Fabric.destroy_funcs.count();
        elem_decl.hooks.destroy_id += id + 1;
        Fabric.destroy_funcs.put(elem_decl.hooks.destroy_id, f) catch |err| {
            println("Mount Function Registry {any}\n", .{err});
        };
    }

    _ = Fabric.current_ctx.open(elem_decl) catch |err| {
        println("{any}\n", .{err});
    };
    _ = local.ConfigureElement(elem_decl);
    return local.CloseElement;
}

pub inline fn Draggable(element: *Element, style: Style) fn (void) void {
    const local = struct {
        fn CloseElement(_: void) void {
            _ = Fabric.current_ctx.close();
            return;
        }
        fn ConfigureElement(elem_decl: ElementDecl) *UINode {
            return Fabric.current_ctx.configure(elem_decl);
        }
    };

    var elem_decl = ElementDecl{
        .style = style,
        .dynamic = .pure,
        .elem_type = .Draggable,
    };

    elem_decl.style.position.type = .absolute;

    _ = Fabric.current_ctx.open(elem_decl) catch |err| {
        println("{any}\n", .{err});
        unreachable;
    };
    const ui_node = local.ConfigureElement(elem_decl);
    element.uuid = ui_node.uuid;
    element.draggable = true;
    element.element_type = .Draggable;
    return local.CloseElement;
}

pub inline fn AllocText(fmt: []const u8, args: anytype, style: Style) void {
    const text = std.fmt.allocPrint(Fabric.allocator_global, fmt, args) catch |err| {
        println("Error Could not format argument alloc Error details: {any}\n", .{err});
        return;
    };
    const local = struct {
        fn CloseElement() void {
            _ = Fabric.current_ctx.close();
            return;
        }
        fn ConfigureElement(elem_decl: ElementDecl) void {
            _ = Fabric.current_ctx.configure(elem_decl);
            // CloseElement();
            return;
        }
    };

    const elem_decl = ElementDecl{
        .style = style,
        .dynamic = .pure,
        .elem_type = .AllocText,
        .text = text,
    };
    _ = Fabric.current_ctx.open(elem_decl) catch |err| {
        println("{any}\n", .{err});
    };
    _ = local.ConfigureElement(elem_decl);
    _ = local.CloseElement();
    return;
}

pub inline fn Text(text: []const u8, style: Style) void {
    const local = struct {
        fn CloseElement() void {
            _ = Fabric.current_ctx.close();
            return;
        }
        fn ConfigureElement(elem_decl: ElementDecl) void {
            _ = Fabric.current_ctx.configure(elem_decl);
            // CloseElement();
            return;
        }
    };

    var elem_decl = ElementDecl{
        .style = style,
        .dynamic = .pure,
        .elem_type = .Text,
        .text = text,
    };
    elem_decl.style.width.type = .elastic;
    _ = Fabric.current_ctx.open(elem_decl) catch |err| {
        println("{any}\n", .{err});
    };
    _ = local.ConfigureElement(elem_decl);
    _ = local.CloseElement();
    return;
}

pub inline fn TextArea(text: []const u8, style: Style) void {
    const local = struct {
        fn CloseElement() void {
            _ = Fabric.current_ctx.close();
            return;
        }
        fn ConfigureElement(elem_decl: ElementDecl) void {
            _ = Fabric.current_ctx.configure(elem_decl);
            // CloseElement();
            return;
        }
    };

    const elem_decl = ElementDecl{
        .style = style,
        .dynamic = .pure,
        .elem_type = .TextArea,
        .text = text,
    };
    // const dimensions = measureText(text, &elem_decl.style);
    // Make sure this is the right order of ops
    // elem_decl.style.width = dimensions.width;
    // elem_decl.style.height = dimensions.height;
    // println("Min: {}\n", .{elem_decl.style.width.size.minmax.min});
    // println("Max: {}\n", .{elem_decl.style.width.size.minmax.max});
    _ = Fabric.current_ctx.open(elem_decl) catch |err| {
        println("{any}\n", .{err});
    };
    _ = local.ConfigureElement(elem_decl);
    _ = local.CloseElement();
    return;
}
pub inline fn Box(style: Style) fn (void) void {
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
        .dynamic = .pure,
        .elem_type = .Box,
    };
    _ = Fabric.current_ctx.open(elem_decl) catch |err| {
        println("{any}\n", .{err});
    };
    _ = local.ConfigureElement(elem_decl);
    return local.CloseElement;
}

pub inline fn Svg(svg: []const u8, style: Style) fn (void) void {
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
        .svg = svg,
        .style = style,
        .dynamic = .pure,
        .elem_type = .Svg,
    };
    _ = Fabric.current_ctx.open(elem_decl) catch |err| {
        println("{any}\n", .{err});
    };
    _ = local.ConfigureElement(elem_decl);
    return local.CloseElement;
}

const DialogType = enum {
    show,
    close,
};

pub inline fn DialogBtn(dialog_type: DialogType, func: *const fn () void, style: Style) fn (void) void {
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
        .dynamic = .pure,
    };

    switch (dialog_type) {
        .show => elem_decl.elem_type = .DialogBtnShow,
        .close => elem_decl.elem_type = .DialogBtnClose,
    }

    const ui_node = Fabric.current_ctx.open(elem_decl) catch |err| {
        println("{any}\n", .{err});
        unreachable;
    };

    Fabric.registry.put(ui_node.uuid, func) catch |err| {
        println("Button Function Registry {any}\n", .{err});
    };
    _ = local.ConfigureElement(elem_decl);
    return local.CloseElement;
}

pub inline fn CtxButton(func: anytype, args: anytype, style: Style) fn (void) void {
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
        .dynamic = .pure,
        .elem_type = .CtxButton,
    };

    const ui_node = Fabric.current_ctx.open(elem_decl) catch |err| {
        println("{any}\n", .{err});
        unreachable;
    };

    const Args = @TypeOf(args);
    const Closure = struct {
        arguments: Args,
        run_node: Fabric.Node = .{ .data = .{ .runFn = runFn, .deinitFn = deinitFn } },
        //
        fn runFn(action: *Fabric.Action) void {
            const run_node: *Fabric.Node = @fieldParentPtr("data", action);
            const closure: *@This() = @alignCast(@fieldParentPtr("run_node", run_node));
            @call(.auto, func, closure.arguments);
        }
        //
        fn deinitFn(node: *Fabric.Node) void {
            const closure: *@This() = @alignCast(@fieldParentPtr("run_node", node));
            Fabric.allocator_global.destroy(closure);
        }
    };

    const closure = Fabric.allocator_global.create(Closure) catch |err| {
        println("Error could not create closure {any}\n ", .{err});
        unreachable;
    };
    closure.* = .{
        .arguments = args,
    };

    Fabric.ctx_registry.put(ui_node.uuid, &closure.run_node) catch |err| {
        println("Button Function Registry {any}\n", .{err});
        unreachable;
    };

    _ = local.ConfigureElement(elem_decl);
    return local.CloseElement;
}

pub inline fn Button(
    func: *const fn () void,
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

    const elem_decl = ElementDecl{
        .style = style,
        .dynamic = .pure,
        .elem_type = .Button,
    };

    const ui_node = Fabric.current_ctx.open(elem_decl) catch |err| {
        println("{any}\n", .{err});
        unreachable;
    };

    Fabric.registry.put(ui_node.uuid, func) catch |err| {
        println("Button Function Registry {any}\n", .{err});
    };
    _ = local.ConfigureElement(elem_decl);
    return local.CloseElement;
}

pub inline fn Select(style: Style) fn (void) void {
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
        .dynamic = .pure,
        .elem_type = .Select,
    };
    _ = Fabric.current_ctx.open(elem_decl) catch {};
    _ = local.ConfigureElement(elem_decl);
    return local.CloseElement;
}

pub inline fn SelectItem(style: Style) fn (void) void {
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
        .dynamic = .pure,
        .elem_type = .SelectItem,
    };
    _ = Fabric.current_ctx.open(elem_decl) catch {};
    _ = local.ConfigureElement(elem_decl);
    return local.CloseElement;
}

pub inline fn List(style: Style) fn (void) void {
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
        .dynamic = .pure,
        .elem_type = .List,
    };
    _ = Fabric.current_ctx.open(elem_decl) catch {};
    _ = local.ConfigureElement(elem_decl);
    return local.CloseElement;
}

pub inline fn ListItem(style: Style) fn (void) void {
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
        .dynamic = .pure,
        .elem_type = .ListItem,
    };
    _ = Fabric.current_ctx.open(elem_decl) catch {};
    _ = local.ConfigureElement(elem_decl);
    return local.CloseElement;
}

pub inline fn Circle(style: Style) fn (void) void {
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
        .dynamic = .pure,
        .elem_type = .Block,
    };
    elem_decl.style.border_radius = .all(99);

    _ = Fabric.current_ctx.open(elem_decl) catch |err| {
        println("{any}\n", .{err});
        unreachable;
    };
    // if (style.active) |act| {
    //     act.signal_ptr.subscribe(ui_node);
    // }
    _ = local.ConfigureElement(elem_decl);
    return local.CloseElement;
}

pub inline fn Bind(element: *Element, style: Style) fn (void) void {
    const local = struct {
        fn CloseElement(_: void) void {
            _ = Fabric.current_ctx.close();
            return;
        }
        fn ConfigureElement(elem_decl: ElementDecl) *UINode {
            return Fabric.current_ctx.configure(elem_decl);
        }
    };

    const elem_decl = ElementDecl{
        .style = style,
        .dynamic = .pure,
        .elem_type = .Bind,
    };

    _ = Fabric.current_ctx.open(elem_decl) catch |err| {
        println("{any}\n", .{err});
        unreachable;
    };
    // ui_node.uuid = .{'1'} ** 36;
    // if (style.active) |act| {
    //     act.signal_ptr.subscribe(ui_node);
    // }
    const ui_node = local.ConfigureElement(elem_decl);
    element.uuid = ui_node.uuid;
    return local.CloseElement;
}

pub inline fn Input(params: InputParams, style: Style) void {
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
        .dynamic = .pure,
        .elem_type = .Input,
        .input_params = params,
    };

    _ = Fabric.current_ctx.open(elem_decl) catch |err| {
        println("{any}\n", .{err});
        unreachable;
    };
    // if (style.active) |act| {
    //     act.signal_ptr.subscribe(ui_node);
    // }
    local.ConfigureElement(elem_decl);
    local.CloseElement();
    return;
}

pub inline fn Block(style: Style) fn (void) void {
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
        .dynamic = .pure,
        .elem_type = .Block,
    };

    _ = Fabric.current_ctx.open(elem_decl) catch |err| {
        println("{any}\n", .{err});
        unreachable;
    };
    // if (style.active) |act| {
    //     act.signal_ptr.subscribe(ui_node);
    // }
    _ = local.ConfigureElement(elem_decl);
    return local.CloseElement;
}

pub inline fn FlexBox(style: Style) fn (void) void {
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
        .dynamic = .pure,
        .elem_type = .FlexBox,
    };
    _ = Fabric.current_ctx.open(elem_decl) catch |err| {
        println("{any}\n", .{err});
    };
    _ = local.ConfigureElement(elem_decl);
    return local.CloseElement;
}

pub inline fn EmbedLink(link: []const u8) fn (void) void {
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
        .href = link,
        .elem_type = .EmbedLink,
    };
    _ = Fabric.current_ctx.open(elem_decl) catch |err| {
        println("{any}\n", .{err});
    };
    _ = local.ConfigureElement(elem_decl);
    return local.CloseElement;
}

pub inline fn RedirectLink(url: []const u8, style: Style) fn (void) void {
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
        .href = url,
        .elem_type = .RedirectLink,
        .style = style,
        .dynamic = .pure,
    };
    _ = Fabric.current_ctx.open(elem_decl) catch |err| {
        println("{any}\n", .{err});
    };
    _ = local.ConfigureElement(elem_decl);
    return local.CloseElement;
}

pub inline fn Link(url: []const u8, style: Style) fn (void) void {
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
        .href = url,
        .elem_type = .Link,
        .style = style,
        .dynamic = .pure,
    };
    _ = Fabric.current_ctx.open(elem_decl) catch |err| {
        println("{any}\n", .{err});
    };
    _ = local.ConfigureElement(elem_decl);
    return local.CloseElement;
}

pub inline fn Dialog(style: Style) fn (void) void {
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
        .elem_type = .Dialog,
        .style = style,
        .dynamic = .pure,
    };
    _ = Fabric.current_ctx.open(elem_decl) catch |err| {
        println("{any}\n", .{err});
    };
    _ = local.ConfigureElement(elem_decl);
    return local.CloseElement;
}
