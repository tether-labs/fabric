const std = @import("std");
const types = @import("types.zig");
const Fabric = @import("Fabric.zig");
const UINode = @import("UITree.zig").UINode;
const LifeCycle = @import("Fabric.zig").LifeCycle;
const println = Fabric.println;
const Style = types.Style;
const InputParams = types.InputParams;
const ElementDecl = types.ElementDeclaration;
const ElementType = types.Elements.ElementType;

const HeaderSize = enum(u32) {
    XXLarge = 12,
    XLarge = 8,
    Large = 4,
    Medium = 2,
    Small = 1,
};

pub inline fn Header(text: []const u8, size: HeaderSize, style: Style) void {
    var elem_decl = ElementDecl{
        .style = style,
        .dynamic = .static,
        .elem_type = .Header,
        .text = text,
    };
    // const dimensions = measureText(text, &elem_decl.style);
    // // Make sure this is the right order of ops
    if (style.font_size == null) {
        switch (size) {
            .XXLarge => elem_decl.style.font_size = 12 * 12,
            .XLarge => elem_decl.style.font_size = 12 * 8,
            .Large => elem_decl.style.font_size = 12 * 4,
            .Medium => elem_decl.style.font_size = 12 * 2,
            .Small => elem_decl.style.font_size = 12 * 1,
        }
    }
    _ = LifeCycle.open(elem_decl);
    LifeCycle.configure(elem_decl);
    LifeCycle.close({});
}

pub inline fn CtxHooks(hooks: Fabric.HooksCtxFuncs, func: anytype, args: anytype, style: Style) fn (void) void {
    var elem_decl = ElementDecl{
        .elem_type = .HooksCtx,
        .dynamic = .static,
        .style = style,
    };

    if (hooks == .mounted) {
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

        const id = Fabric.mounted_ctx_funcs.count();
        elem_decl.hooks.mounted_id += id + 1;
        Fabric.mounted_ctx_funcs.put(elem_decl.hooks.mounted_id, &closure.run_node) catch |err| {
            println("Button Function Registry {any}\n", .{err});
        };
    }
    // if (hooks.created) |f| {
    //     const id = Fabric.created_funcs.count();
    //     elem_decl.hooks.created_id += id + 1;
    //     Fabric.created_funcs.put(elem_decl.hooks.created_id, f) catch |err| {
    //         println("Mount Function Registry {any}\n", .{err});
    //     };
    // }
    // if (hooks.updated) |f| {
    //     const id = Fabric.updated_funcs.count();
    //     elem_decl.hooks.updated_id += id + 1;
    //     Fabric.updated_funcs.put(elem_decl.hooks.updated_id, f) catch |err| {
    //         println("Mount Function Registry {any}\n", .{err});
    //     };
    // }
    // if (hooks.destroy) |f| {
    //     const id = Fabric.destroy_funcs.count();
    //     elem_decl.hooks.destroy_id += id + 1;
    //     Fabric.destroy_funcs.put(elem_decl.hooks.destroy_id, f) catch |err| {
    //         println("Mount Function Registry {any}\n", .{err});
    //     };
    // }

    _ = LifeCycle.open(elem_decl);
    LifeCycle.configure(elem_decl);
    return LifeCycle.close;
}

pub inline fn Hooks(hooks: Fabric.HooksFuncs, style: Style) fn (void) void {
    var elem_decl = ElementDecl{
        .elem_type = .Hooks,
        .dynamic = .static,
        .style = style,
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

    _ = LifeCycle.open(elem_decl);
    LifeCycle.configure(elem_decl);
    return LifeCycle.close;
}

pub inline fn TextArea(text: []const u8, style: Style) void {
    const elem_decl = ElementDecl{
        .style = style,
        .dynamic = .static,
        .elem_type = .TextArea,
        .text = text,
    };
    _ = LifeCycle.open(elem_decl);
    LifeCycle.configure(elem_decl);
    LifeCycle.close({});
}

pub inline fn Text(text: []const u8, style: Style) void {
    const elem_decl = ElementDecl{
        .style = style,
        .dynamic = .static,
        .elem_type = .Text,
        .text = text,
    };
    _ = LifeCycle.open(elem_decl);
    LifeCycle.configure(elem_decl);
    LifeCycle.close({});
}

pub inline fn Svg(svg: []const u8, style: Style) void {
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
        .svg = svg,
        .style = style,
        .dynamic = .static,
        .elem_type = .Svg,
    };
    _ = Fabric.current_ctx.open(elem_decl) catch |err| {
        println("{any}\n", .{err});
        return;
    };

    _ = local.ConfigureElement(elem_decl);
    _ = local.CloseElement();
}

export fn ctxButtonCallback(id_ptr: [*:0]u8) void {
    const id = std.mem.span(id_ptr);
    defer Fabric.allocator_global.free(id);
    const node = Fabric.ctx_registry.get(id) orelse return;
    @call(.auto, node.data.runFn, .{&node.data});
}

export fn ctxHooksMountedCallback(id: u32) void {
    const node = Fabric.mounted_ctx_funcs.get(id) orelse return;
    @call(.auto, node.data.runFn, .{&node.data});
}

export fn buttonCallback(id_ptr: [*:0]u8) void {
    const id = std.mem.span(id_ptr);
    defer Fabric.allocator_global.free(id);
    Fabric.current_depth_node_id = std.mem.Allocator.dupe(Fabric.allocator_global, u8, id) catch return;
    const func = Fabric.registry.get(id) orelse return;
    @call(.auto, func, .{});
}
export fn hooksMountedCallback(id: u32) void {
    const func = Fabric.mounted_funcs.get(id).?;
    @call(.auto, func, .{});
}
export fn hooksCreatedCallback(id: u32) void {
    const func = Fabric.created_funcs.get(id).?;
    @call(.auto, func, .{});
}
export fn hooksUpdatedCallback(id: u32) void {
    const func = Fabric.updated_funcs.get(id).?;
    @call(.auto, func, .{});
}
export fn hooksDestroyCallback(id: u32) void {
    const func = Fabric.destroy_funcs.get(id).?;
    @call(.auto, func, .{});
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

    var elem_decl = ElementDecl{
        .style = style,
        .dynamic = .static,
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

pub inline fn SubmitCtxButton(style: Style) fn (void) void {
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
        .dynamic = .static,
        .elem_type = .SubmitCtxButton,
    };

    _ = Fabric.current_ctx.open(elem_decl) catch |err| {
        println("{any}\n", .{err});
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
        .dynamic = .static,
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
            if (Args == @TypeOf(.{{}})) {
                @call(.auto, func, .{});
            } else {
                @call(.auto, func, closure.arguments);
            }
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
    };

    _ = local.ConfigureElement(elem_decl);
    return local.CloseElement;
}

fn callsiteId() u64 {
    const loc = @src().line;
    return loc;
}

pub const BtnProps = struct {
    onPress: ?*const fn () void = null,
    onRelease: ?*const fn () void = null,
    aria_label: ?[]const u8 = null,
};

const _local = struct {
    fn CloseElement(_: void) void {
        _ = Fabric.current_ctx.close();
        return;
    }
    fn ConfigureElement(elem_decl: ElementDecl) *const fn (void) void {
        _ = Fabric.current_ctx.configure(elem_decl);
        return CloseElement;
    }
};

pub inline fn Button(
    btnProps: BtnProps,
    style: Style,
) fn (void) void {
    const elem_decl = ElementDecl{
        .style = style,
        .dynamic = .static,
        .elem_type = .Button,
        .aria_label = btnProps.aria_label,
    };
    const ui_node = LifeCycle.open(elem_decl) orelse {
        unreachable;
    };

    if (btnProps.onPress) |onPress| {
        Fabric.registry.put(ui_node.uuid, onPress) catch |err| {
            println("Button Function Registry {any}\n", .{err});
        };
    }

    LifeCycle.configure(elem_decl);
    return LifeCycle.close;
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
        .dynamic = .static,
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
        .dynamic = .static,
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
        .dynamic = .static,
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
        .dynamic = .static,
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
        .dynamic = .static,
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
        .dynamic = .static,
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
        .dynamic = .static,
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

const StyleProp = struct {
    cmp_id: ?[]const u8 = null,
    style: Style = .{},
};

/// Label Component
/// The text is the content which is displayed in the label
/// tag: the tag of the component it is tagged to
/// Input tag="sample-input"
/// Label tag="sample-input"
pub inline fn Label(text: []const u8, tag: []const u8, style: Style) void {
    const local = struct {
        fn CloseElement() void {
            _ = Fabric.current_ctx.close();
            return;
        }
        fn ConfigureElement(elem_decl: ElementDecl) void {
            _ = Fabric.current_ctx.configure(elem_decl);
            CloseElement();
            return;
        }
    };

    const elem_decl = ElementDecl{
        .style = style,
        .dynamic = .static,
        .elem_type = .Label,
        .text = text,
        .href = tag,
    };
    _ = Fabric.current_ctx.open(elem_decl) catch |err| {
        println("{any}\n", .{err});
    };
    _ = local.ConfigureElement(elem_decl);
    _ = local.CloseElement;
    return;
}

pub inline fn Form(style: Style) fn (void) void {
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
        .dynamic = .static,
        .elem_type = .Form,
    };
    _ = Fabric.current_ctx.open(elem_decl) catch |err| {
        println("{any}\n", .{err});
    };
    _ = local.ConfigureElement(elem_decl);
    return local.CloseElement;
}

pub inline fn Center(style: Style) fn (void) void {
    var elem_decl = ElementDecl{
        .style = style,
        .dynamic = .static,
        .elem_type = .FlexBox,
    };
    elem_decl.style.child_alignment.x = .center;
    elem_decl.style.child_alignment.y = .center;

    _ = LifeCycle.open(elem_decl);
    LifeCycle.configure(elem_decl);
    return LifeCycle.close;
}

pub inline fn Column(style: Style) fn (void) void {
    var elem_decl = ElementDecl{
        .style = style,
        .dynamic = .static,
        .elem_type = .FlexBox,
    };
    elem_decl.style.direction = .column;

    _ = LifeCycle.open(elem_decl);
    LifeCycle.configure(elem_decl);
    return LifeCycle.close;
}

pub inline fn Box(style: Style) fn (void) void {
    const elem_decl = ElementDecl{
        .style = style,
        .dynamic = .static,
        .elem_type = .FlexBox,
    };

    _ = LifeCycle.open(elem_decl);
    LifeCycle.configure(elem_decl);
    return LifeCycle.close;
}

pub inline fn FlexBox(style: Style) fn (void) void {
    const elem_decl = ElementDecl{
        .style = style,
        .dynamic = .static,
        .elem_type = .FlexBox,
    };

    _ = LifeCycle.open(elem_decl);
    LifeCycle.configure(elem_decl);
    return LifeCycle.close;
}

pub inline fn EmbedIcon(link: []const u8) fn (void) void {
    const elem_decl = ElementDecl{
        .href = link,
        .elem_type = .EmbedIcon,
    };

    _ = LifeCycle.open(elem_decl);
    LifeCycle.configure(elem_decl);
    return LifeCycle.close;
}

pub inline fn Icon(icon_name: []const u8, style: Style) void {
    const elem_decl = ElementDecl{
        .href = icon_name,
        .elem_type = .Icon,
        .style = style,
        .dynamic = .static,
    };
    _ = LifeCycle.open(elem_decl);
    LifeCycle.configure(elem_decl);
    LifeCycle.close({});
}

pub inline fn Image(link: []const u8, style: Style) void {
    const elem_decl = ElementDecl{
        .href = link,
        .elem_type = .Image,
        .style = style,
    };
    _ = LifeCycle.open(elem_decl);
    LifeCycle.configure(elem_decl);
    LifeCycle.close({});
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

pub inline fn RedirectLink(link_props: LinkProps, style: Style) fn (void) void {
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
        .href = link_props.url,
        .elem_type = .RedirectLink,
        .style = style,
        .dynamic = .static,
        .aria_label = link_props.aria_label,
    };
    _ = Fabric.current_ctx.open(elem_decl) catch |err| {
        println("{any}\n", .{err});
    };
    _ = local.ConfigureElement(elem_decl);
    return local.CloseElement;
}

const LinkProps = struct {
    url: []const u8,
    aria_label: ?[]const u8 = null,
};

pub inline fn Link(link_props: LinkProps, style: Style) fn (void) void {
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
        .href = link_props.url,
        .elem_type = .Link,
        .style = style,
        .dynamic = .static,
        .aria_label = link_props.aria_label,
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
        .dynamic = .static,
    };
    _ = Fabric.current_ctx.open(elem_decl) catch |err| {
        println("{any}\n", .{err});
    };
    _ = local.ConfigureElement(elem_decl);
    return local.CloseElement;
}

pub inline fn Table(style: Style) fn (void) void {
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
        .elem_type = .Table,
        .style = style,
        .dynamic = .static,
    };
    _ = Fabric.current_ctx.open(elem_decl) catch |err| {
        println("{any}\n", .{err});
    };
    _ = local.ConfigureElement(elem_decl);
    return local.CloseElement;
}

pub inline fn TableHeader(style: Style) fn (void) void {
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
        .elem_type = .TableHeader,
        .style = style,
        .dynamic = .static,
    };
    _ = Fabric.current_ctx.open(elem_decl) catch |err| {
        println("{any}\n", .{err});
    };
    _ = local.ConfigureElement(elem_decl);
    return local.CloseElement;
}

pub inline fn TableCell(style: Style) fn (void) void {
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
        .elem_type = .TableCell,
        .style = style,
        .dynamic = .static,
    };
    _ = Fabric.current_ctx.open(elem_decl) catch |err| {
        println("{any}\n", .{err});
    };
    _ = local.ConfigureElement(elem_decl);
    return local.CloseElement;
}

pub inline fn TableBody(style: Style) fn (void) void {
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
        .elem_type = .TableBody,
        .style = style,
        .dynamic = .static,
    };
    _ = Fabric.current_ctx.open(elem_decl) catch |err| {
        println("{any}\n", .{err});
    };
    _ = local.ConfigureElement(elem_decl);
    return local.CloseElement;
}

pub inline fn TableRow(style: Style) fn (void) void {
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
        .elem_type = .TableRow,
        .style = style,
        .dynamic = .static,
    };
    _ = Fabric.current_ctx.open(elem_decl) catch |err| {
        println("{any}\n", .{err});
    };
    _ = local.ConfigureElement(elem_decl);
    return local.CloseElement;
}

pub inline fn Canvas(id: []const u8) void {
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
        .dynamic = .static,
        .elem_type = .Canvas,
    };
    elem_decl.style.id = id;

    _ = Fabric.current_ctx.open(elem_decl) catch |err| {
        println("{any}\n", .{err});
    };
    _ = local.ConfigureElement(elem_decl);
    _ = local.CloseElement();
    return;
}
