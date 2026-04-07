const std = @import("std");
const types = @import("types.zig");
const Vapor = @import("Vapor.zig");
const UINode = @import("UITree.zig").UINode;
const LifeCycle = @import("Vapor.zig").LifeCycle;
const println = Vapor.println;
const Style = types.Style;
const ElementDecl = types.ElementDeclaration;
const Color = types.Color;
const Element = @import("Element.zig").Element;
pub const IconTokens = @import("config").IconTokens;
const utils = @import("utils.zig");
const hashKey = utils.hashKey;
const Draggable = @import("Draggable.zig").Draggable;
const onCreateNode = @import("Hooks.zig").onCreateNode;
const Shadow = @import("Shadow.zig");
const Accessibility = @import("Accessibility.zig").Accessibility;

pub const StringEntry = struct {
    ptr: [*]const u8,
    len: usize,
    persisted: []const u8,
};

pub var text_string_table: std.AutoHashMap(u32, StringEntry) = undefined;

const HeaderSize = enum(u32) {
    XXLarge = 12,
    XLarge = 8,
    Large = 4,
    Medium = 2,
    Small = 1,
};

pub fn Header(text: []const u8, size: HeaderSize, style: Style) void {
    var elem_decl = ElementDecl{
        .style = style,
        .state_type = .static,
        .elem_type = .Header,
        .text = text,
    };
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

pub fn Hooks(hooks: Vapor.HooksFuncs) fn (void) void {
    var elem_decl = ElementDecl{
        .state_type = .static,
        .elem_type = .Hooks,
    };
    const ui_node = LifeCycle.open(elem_decl) orelse unreachable;
    if (hooks.mounted) |f| {
        elem_decl.hooks.mounted_id = 1;
        Vapor.mounted_funcs.put(hashKey(ui_node.uuid), f) catch |err| {
            println("Mount Function Registry {any}\n", .{err});
        };
    }
    if (hooks.created) |f| {
        elem_decl.hooks.created_id += 1;
        Vapor.created_funcs.put(hashKey(ui_node.uuid), f) catch |err| {
            println("Mount Function Registry {any}\n", .{err});
        };
    }
    if (hooks.updated) |f| {
        elem_decl.hooks.updated_id += 1;
        Vapor.updated_funcs.put(hashKey(ui_node.uuid), f) catch |err| {
            println("Mount Function Registry {any}\n", .{err});
        };
    }
    if (hooks.destroy) |f| {
        elem_decl.hooks.destroy_id += 1;
        Vapor.destroy_funcs.put(hashKey(ui_node.uuid), f) catch |err| {
            println("Mount Function Registry {any}\n", .{err});
        };
    }
    LifeCycle.configure(elem_decl);
    return LifeCycle.close;
}

const LinkOptions = struct {
    url: []const u8,
    aria_label: ?[]const u8 = null,
};

const Position = enum { top, bottom, left, right };
const Layout = enum { center, start, end };

fn createNode(elem_decl: ElementDecl) *UINode {
    const ui_node = LifeCycle.open(elem_decl) orelse {
        Vapor.printlnSrcErr("Could not add component to lifecycle {any}\n", .{error.CouldNotAllocate}, @src());
        unreachable;
    };
    return ui_node;
}

const AnchorSource = struct { id: []const u8 };
const AnchorTarget = struct { id: []const u8, placement: types.Layout, position: types.Position };

// ============================================================
// Shared style-merge logic — compiled ONCE, not per generic instantiation
// ============================================================

fn mergeVisualFields(target: *types.Visual, source: types.Visual) void {
    if (source.background != null) target.background = source.background;
    if (source.fill != null) target.fill = source.fill;
    if (source.stroke != null) target.stroke = source.stroke;
    if (source.border != null) target.border = source.border;
    if (source.border_radius != null) target.border_radius = source.border_radius;
    if (source.border_thickness != null) target.border_thickness = source.border_thickness;
    if (source.border_color != null) target.border_color = source.border_color;
    if (source.text_color != null) target.text_color = source.text_color;
    if (source.font_size != null) target.font_size = source.font_size;
    if (source.font_weight != null) target.font_weight = source.font_weight;
    if (source.letter_spacing != null) target.letter_spacing = source.letter_spacing;
    if (source.line_height != null) target.line_height = source.line_height;
    if (source.opacity != null) target.opacity = source.opacity;
    if (source.ellipsis != null) target.ellipsis = source.ellipsis;
    if (source.shadow != null) target.shadow = source.shadow;
    if (source.cursor != null) target.cursor = source.cursor;
    if (source.layer != null) target.layer = source.layer;
    if (source.layers != null) target.layers = source.layers;
    if (source.text_shadow != null) target.text_shadow = source.text_shadow;
}

fn mergeHoverVisualFields(target: *types.Visual, source: types.Visual) void {
    mergeVisualFields(target, source);
    if (source.animation != null) target.animation = source.animation;
    if (source.animation_name != null) target.animation_name = source.animation_name;
}

pub const StyleMergeParams = struct {
    style_ptr: ?*const Vapor.Style,
    pos: ?types.Position,
    visual: ?types.Visual,
    interactive: ?types.Interactive,
    child_gap: ?u8,
    transform_origin: ?types.TransformOrigin,
    padding: ?types.Padding,
    layout: ?types.Layout,
    placement: ?types.AnchorPlacement,
    margin: ?types.Margin,
    size: ?types.Size,
    transition: ?types.Transition,
    flex_wrap: ?types.FlexWrap,
    direction: ?types.Direction,
    list_style: ?types.ListStyle,
    font_family: ?[]const u8,
    scroll: ?types.Scroll,
    flex_type: types.FlexType,
    id: ?[]const u8,
    class: ?[]const u8,
    anchor: ?[]const u8,
    edges: ?[]const u8,
    aspect_ratio: ?types.AspectRatio,
    include_extended: bool,
    include_aspect_ratio: bool,
};

pub fn mergeStyles(p: StyleMergeParams) Style {
    var s = if (p.style_ptr) |sp| sp.* else Style{};
    if (s.position == null) s.position = p.pos;

    if (s.visual != null and p.visual != null) {
        var visual = s.visual.?;
        mergeVisualFields(&visual, p.visual.?);
        if (p.include_extended and p.edges != null) visual.edges = p.edges;
        s.visual = visual;
    } else if (p.visual) |v| {
        s.visual = v;
        if (p.include_extended) s.visual.?.edges = p.edges;
    }

    if (p.include_extended) {
        if (s.interactive != null and p.interactive != null) {
            const interactive = s.interactive.?;
            const _interactive = p.interactive.?;
            if (interactive.hover != null and _interactive.hover != null) {
                var visual = interactive.hover.?;
                mergeHoverVisualFields(&visual, _interactive.hover.?);
                s.interactive.?.hover = visual;
            }
        } else if (p.interactive) |i| {
            s.interactive = i;
        }
    } else {
        if (s.interactive == null) s.interactive = p.interactive;
    }

    if (s.child_gap == null) s.child_gap = p.child_gap;
    if (s.transform_origin == null) s.transform_origin = p.transform_origin;
    if (s.padding == null) s.padding = p.padding;
    if (s.flex_type == .default) s.flex_type = p.flex_type;
    if (s.layout != null) {
        if (p.layout) |l| s.layout = l;
    } else s.layout = p.layout;
    if (s.placement != null) {
        if (p.placement) |pl| s.placement = pl;
    } else s.placement = p.placement;
    if (s.margin == null) s.margin = p.margin;
    if (s.size == null) s.size = p.size;
    if (s.transition == null) s.transition = p.transition;
    if (s.flex_wrap == null) s.flex_wrap = p.flex_wrap;
    if (p.direction) |d| s.direction = d;
    if (s.list_style == null) s.list_style = p.list_style;
    if (s.font_family == null) s.font_family = p.font_family;
    if (s.scroll == null) s.scroll = p.scroll;
    if (p.include_aspect_ratio) {
        if (s.aspect_ratio == null) s.aspect_ratio = p.aspect_ratio;
    }
    if (p.flex_type == .center) {
        s.layout = .center;
    } else if (p.flex_type == .stack) {
        s.direction = .column;
    }
    if (p.id) |_id| s.id = _id;
    if (p.class) |_class| s.style_id = _class;
    if (p.anchor) |_anchor| s.anchor = _anchor;
    return s;
}

pub fn persistText(ui_node: ?*UINode, text_value: ?[]const u8) ?[]const u8 {
    const value = text_value orelse return null;
    const uuid = hashKey(ui_node.?.uuid);
    const slice: []const u8 = value;
    if (text_string_table.get(uuid)) |entry| {
        const old_string = entry.persisted;
        if (entry.len == slice.len and entry.ptr == slice.ptr and std.mem.eql(u8, entry.persisted, slice)) return entry.persisted;
        const new_copy = Vapor.arena(.persist).dupe(u8, slice) catch unreachable;
        text_string_table.put(uuid, .{ .ptr = slice.ptr, .len = slice.len, .persisted = new_copy }) catch unreachable;
        defer Vapor.arena(.persist).free(old_string);
        return new_copy;
    } else {
        const copy = Vapor.arena(.persist).dupe(u8, slice) catch unreachable;
        text_string_table.put(uuid, .{ .ptr = slice.ptr, .len = slice.len, .persisted = copy }) catch unreachable;
        return copy;
    }
}

// ============================================================
// Single unified ComponentBuilder — NO comptime parameters
// ============================================================

pub const ComponentBuilder = struct {
    const Self = @This();
    const _state_type: types.StateType = .pure;

    _returns_close: bool = true,
    _level: ?u8 = null,
    _video: ?*const types.Video = null,
    _font_family: ?[]const u8 = null,
    _value: ?*anyopaque = null,
    _elem_type: Vapor.ElementType,
    _flex_type: types.FlexType = .flex,
    _text: ?[]const u8 = null,
    _href: ?[]const u8 = null,
    _src: ?[]const u8 = null,
    _alt: ?[]const u8 = null,
    _svg: []const u8 = "",
    _aria_label: ?[]const u8 = null,
    _ui_node: ?*UINode = null,
    _id: ?[]const u8 = null,
    _style: ?*const Vapor.Style = null,
    _draggable: ?*Draggable = null,
    _element: ?*Element = null,
    _animation_enter: ?[]const u8 = null,
    _animation_exit: ?[]const u8 = null,
    _name: ?[]const u8 = null,
    _used_style: bool = false,
    _pos: ?types.Position = null,
    _padding: ?types.Padding = null,
    _layout: ?types.Layout = null,
    _placement: ?types.AnchorPlacement = null,
    _margin: ?types.Margin = null,
    _size: ?types.Size = null,
    _child_gap: ?u8 = null,
    _visual: ?types.Visual = null,
    _text_decoration: ?types.TextDecoration = null,
    _flex_wrap: ?types.FlexWrap = null,
    _interactive: ?types.Interactive = null,
    _transition: ?types.Transition = null,
    _direction: ?types.Direction = null,
    _list_style: ?types.ListStyle = null,
    _class: ?[]const u8 = null,
    _scroll: ?types.Scroll = null,
    _transform_origin: ?types.TransformOrigin = null,
    _inlineStyle: ?[]const u8 = null,
    _style_fields: ?[]const types.StyleFields = &.{},
    _hover_style_fields: ?[]const types.StyleFields = &.{},
    _anchor: ?[]const u8 = null,
    _aspect_ratio: ?types.AspectRatio = null,
    _persisted_text: bool = false,
    _accessibility: ?Accessibility = null,
    _column_count: ?u8 = null,
    _edges: ?[]const u8 = null,

    // --- Internal helpers ---

    fn getOrCreateNode(self: *const Self, new_self: *Self) *UINode {
        if (self._ui_node) |node| return node;
        const node = LifeCycle.open(ElementDecl{
            .state_type = _state_type,
            .elem_type = self._elem_type,
        }) orelse {
            Vapor.printlnSrcErr("Node is null", .{}, @src());
            unreachable;
        };
        new_self._ui_node = node;
        return node;
    }

    fn getStyleMergeParams(self: *const Self, include_extended: bool, include_aspect_ratio: bool) StyleMergeParams {
        return .{
            .style_ptr = self._style,
            .pos = self._pos,
            .visual = self._visual,
            .interactive = self._interactive,
            .child_gap = self._child_gap,
            .transform_origin = self._transform_origin,
            .padding = self._padding,
            .layout = self._layout,
            .placement = self._placement,
            .margin = self._margin,
            .size = self._size,
            .transition = self._transition,
            .flex_wrap = self._flex_wrap,
            .direction = self._direction,
            .list_style = self._list_style,
            .font_family = self._font_family,
            .scroll = self._scroll,
            .flex_type = self._flex_type,
            .id = self._id,
            .class = self._class,
            .anchor = self._anchor,
            .edges = self._edges,
            .aspect_ratio = self._aspect_ratio,
            .include_extended = include_extended,
            .include_aspect_ratio = include_aspect_ratio,
        };
    }

    fn makeElemDecl(self: *const Self, text: ?[]const u8, mutable_style: *const Style) Vapor.ElementDecl {
        return .{
            .state_type = _state_type,
            .elem_type = self._elem_type,
            .text = text,
            .style = mutable_style,
            .href = self._href,
            .svg = self._svg,
            .alt = self._alt,
            .aria_label = self._aria_label,
            .animation_enter = self._animation_enter,
            .animation_exit = self._animation_exit,
            .name = self._name,
            .video = self._video,
            .style_fields = self._style_fields,
            .hover_style_fields = self._hover_style_fields,
            .inlineStyle = self._inlineStyle,
            .accessibility = self._accessibility,
            .src = self._src,
        };
    }

    // --- Constructors ---

    pub fn Null() void {
        _ = LifeCycle.open(.{ .elem_type = .Noop, .state_type = _state_type });
        LifeCycle.configure(.{ .elem_type = .Noop, .state_type = _state_type });
        LifeCycle.close({});
    }

    pub fn Null2(elem_type: Vapor.Types.ElementType) void {
        _ = LifeCycle.open(.{ .elem_type = elem_type, .state_type = _state_type });
        LifeCycle.configure(.{ .elem_type = .Noop, .state_type = _state_type });
        LifeCycle.close({});
    }

    pub fn Heading(level: u8, text: []const u8) Self {
        const ui_node = createNode(.{ .state_type = _state_type, .elem_type = .Heading, .text = text, .level = level });
        return Self{ ._elem_type = .Heading, ._text = text, ._level = level, ._ui_node = ui_node, ._returns_close = false };
    }

    pub fn Video(options: *const types.Video) Self {
        const ui_node = Vapor.current_ctx.open(.{ .state_type = _state_type, .elem_type = .Video, .can_have_children = false }) catch |err| {
            println("{any}\n", .{err});
            unreachable;
        };
        return Self{ ._elem_type = .Video, ._video = options, ._ui_node = ui_node, ._returns_close = false };
    }

    pub fn Box() Self {
        const ui_node = createNode(.{ .state_type = _state_type, .elem_type = .FlexBox });
        return Self{ ._ui_node = ui_node, ._elem_type = .FlexBox, ._returns_close = true };
    }

    pub fn Row() Self {
        const ui_node = createNode(.{ .state_type = _state_type, .elem_type = .FlexBox });
        return Self{ ._ui_node = ui_node, ._elem_type = .FlexBox, ._returns_close = true };
    }

    pub fn Table() Self {
        return Self{ ._ui_node = createNode(.{ .state_type = _state_type, .elem_type = .Table }), ._elem_type = .Table, ._returns_close = true };
    }

    pub fn TableRow() Self {
        return Self{ ._ui_node = createNode(.{ .state_type = _state_type, .elem_type = .TableRow }), ._elem_type = .TableRow, ._returns_close = true };
    }

    pub fn TableCell() Self {
        return Self{ ._ui_node = createNode(.{ .state_type = _state_type, .elem_type = .TableCell }), ._elem_type = .TableCell, ._returns_close = true };
    }

    pub fn TableBody() Self {
        return Self{ ._ui_node = createNode(.{ .state_type = _state_type, .elem_type = .TableBody }), ._elem_type = .TableBody, ._returns_close = true };
    }

    pub fn TableHeader() Self {
        return Self{ ._ui_node = createNode(.{ .state_type = _state_type, .elem_type = .TableHeader }), ._elem_type = .TableHeader, ._returns_close = true };
    }

    pub fn TableHead() Self {
        return Self{ ._ui_node = createNode(.{ .state_type = _state_type, .elem_type = .TableHead }), ._elem_type = .TableHead, ._returns_close = true };
    }

    pub fn Form(submit: anytype, args: anytype) Self {
        const ui_node = createNode(.{ .state_type = _state_type, .elem_type = .Form });
        Vapor.attachEventCtxCallback(ui_node, .submit, submit, args) catch |err| {
            Vapor.println("ONSUBMIT: Could not attach event callback {any}\n", .{err});
            unreachable;
        };
        return Self{ ._ui_node = ui_node, ._elem_type = .Form, ._returns_close = true };
    }

    pub fn Section() Self {
        const ui_node = LifeCycle.open(.{ .state_type = _state_type, .elem_type = .Intersection }) orelse {
            Vapor.printlnSrcErr("Could not add component to lifecycle {any}\n", .{error.CouldNotAllocate}, @src());
            unreachable;
        };
        return Self{ ._ui_node = ui_node, ._elem_type = .Intersection, ._returns_close = true };
    }

    pub fn List() Self {
        const ui_node = LifeCycle.open(.{ .state_type = _state_type, .elem_type = .List }) orelse {
            Vapor.printlnSrcErr("Could not add component to lifecycle {any}\n", .{error.CouldNotAllocate}, @src());
            unreachable;
        };
        return Self{ ._ui_node = ui_node, ._elem_type = .List, ._returns_close = true };
    }

    pub fn ListItem() Self {
        const ui_node = LifeCycle.open(.{ .state_type = _state_type, .elem_type = .ListItem }) orelse {
            Vapor.printlnSrcErr("Could not add component to lifecycle {any}\n", .{error.CouldNotAllocate}, @src());
            unreachable;
        };
        return Self{ ._ui_node = ui_node, ._elem_type = .ListItem, ._returns_close = true };
    }

    pub fn Center() *Self {
        const ui_node = LifeCycle.open(.{ .state_type = _state_type, .elem_type = .FlexBox }) orelse {
            Vapor.printlnSrcErr("Could not add component to lifecycle {any}\n", .{error.CouldNotAllocate}, @src());
            unreachable;
        };
        const self = Vapor.arena(.frame).create(Self) catch unreachable;
        self.* = .{
            ._ui_node = ui_node,
            ._elem_type = .FlexBox,
            ._flex_type = .center,
            ._returns_close = true,
        };
        return self;
        // return Self{ ._ui_node = ui_node, ._elem_type = .FlexBox, ._flex_type = .center, ._returns_close = true };
    }

    pub fn Button(cb: anytype, args: anytype) Self {
        const elem_decl = ElementDecl{
            .state_type = _state_type,
            .elem_type = .CtxButton,
        };

        const ui_node = LifeCycle.open(elem_decl) orelse {
            Vapor.printlnSrcErr("LifeCycle open could not allocate {any}\n", .{error.CouldNotAllocate}, @src());
            unreachable;
        };

        const erased = Vapor.ErasedCallback.make(Vapor.arena(.frame), cb, args) catch |err| {
            println("Error could not create closure {any}\n", .{err});
            unreachable;
        };

        const callback_id = hashKey(ui_node.uuid);
        // Store just the ErasedCallback instead of *Node
        Vapor.erased_registry.put(callback_id, erased) catch |err| {
            println("Registry error {any}\n", .{err});
            unreachable;
        };

        return Self{ ._elem_type = .CtxButton, ._ui_node = ui_node, ._returns_close = true };
    }

    pub fn Stack() Self {
        const ui_node = LifeCycle.open(.{ .state_type = _state_type, .elem_type = .FlexBox }) orelse {
            Vapor.printlnSrcErr("Could not add component to lifecycle {any}\n", .{error.CouldNotAllocate}, @src());
            unreachable;
        };
        ui_node.direction = .column;
        return Self{ ._ui_node = ui_node, ._elem_type = .FlexBox, ._flex_type = .stack, ._direction = .column, ._returns_close = true };
    }

    pub fn Link(options: LinkOptions) Self {
        const ui_node = LifeCycle.open(.{ .state_type = _state_type, .elem_type = .Link, .href = options.url, .aria_label = options.aria_label }) orelse {
            Vapor.printlnSrcErr("Could not add component Link to lifecycle {any}\n", .{error.CouldNotAllocate}, @src());
            unreachable;
        };
        return Self{ ._ui_node = ui_node, ._elem_type = .Link, ._aria_label = options.aria_label, ._href = options.url, ._returns_close = true };
    }

    pub fn RedirectLink(options: LinkOptions) Self {
        const ui_node = LifeCycle.open(.{ .state_type = _state_type, .elem_type = .RedirectLink, .href = options.url, .aria_label = options.aria_label }) orelse {
            Vapor.printlnSrcErr("Could not add component Link to lifecycle {any}\n", .{error.CouldNotAllocate}, @src());
            unreachable;
        };
        return Self{ ._ui_node = ui_node, ._elem_type = .RedirectLink, ._aria_label = options.aria_label, ._href = options.url, ._returns_close = true };
    }

    pub fn Label(text: []const u8) Self {
        const ui_node = LifeCycle.open(.{ .state_type = .static, .elem_type = .Label, .text = text, .can_have_children = false }) orelse {
            Vapor.printlnSrcErr("Could not add component to lifecycle {any}\n", .{error.CouldNotAllocate}, @src());
            unreachable;
        };
        return Self{ ._elem_type = .Label, ._text = text, ._ui_node = ui_node, ._returns_close = false };
    }

    pub fn Code(value: anytype) Self {
        const text = blk: switch (@typeInfo(@TypeOf(value))) {
            .pointer => |_| break :blk value,
            .int => break :blk Vapor.fmtln("{any}", .{value}),
            else => {
                Vapor.printlnErr("Text only accepts []const u8 or number types, NOT {any}", .{@TypeOf(value)});
                return Self{ ._elem_type = .Code, ._text = "", ._returns_close = false };
            },
        };
        const ui_node = LifeCycle.open(.{ .state_type = _state_type, .elem_type = .Code, .can_have_children = false }) orelse {
            Vapor.printlnSrcErr("Could not add component to lifecycle {any}\n", .{error.CouldNotAllocate}, @src());
            unreachable;
        };
        return Self{ ._elem_type = .Code, ._text = text, ._ui_node = ui_node, ._returns_close = false };
    }

    pub fn Spacer(val: f32) Self {
        const ui_node = LifeCycle.open(.{ .state_type = _state_type, .elem_type = .Spacer, .can_have_children = false }) orelse {
            Vapor.printlnSrcErr("Could not add component to lifecycle {any}\n", .{error.CouldNotAllocate}, @src());
            unreachable;
        };
        return Self{ ._elem_type = .Spacer, ._ui_node = ui_node, ._size = .hw(.px(val), .expand), ._returns_close = false };
    }

    pub fn Divider(w: f32) Self {
        const ui_node = LifeCycle.open(.{ .state_type = _state_type, .elem_type = .FlexBox, .can_have_children = false }) orelse {
            Vapor.printlnSrcErr("Could not add component to lifecycle {any}\n", .{error.CouldNotAllocate}, @src());
            unreachable;
        };
        return Self{ ._elem_type = .FlexBox, ._ui_node = ui_node, ._size = .hw(.expand, .px(w)), ._returns_close = false };
    }

    pub fn Iframe(src: ?[]const u8) Self {
        const ui_node = LifeCycle.open(.{ .state_type = _state_type, .elem_type = .Iframe, .can_have_children = false }) orelse {
            Vapor.printlnSrcErr("Could not add component to lifecycle {any}\n", .{error.CouldNotAllocate}, @src());
            unreachable;
        };
        return Self{ ._elem_type = .Iframe, ._ui_node = ui_node, ._returns_close = false, ._href = src };
    }

    pub fn Number(value: anytype) Self {
        const ui_node = LifeCycle.open(.{ .state_type = _state_type, .elem_type = .Text, .can_have_children = false }) orelse {
            Vapor.printlnSrcErr("Could not add component to lifecycle {any}\n", .{error.CouldNotAllocate}, @src());
            unreachable;
        };
        const text = blk: switch (@typeInfo(@TypeOf(value))) {
            .int => {
                const n = Vapor.fmtln("{any}", .{value});
                Vapor.frame_arena.addBytesUsed(n.len);
                break :blk n;
            },
            .float => {
                const n = Vapor.fmtln("{any}", .{value});
                Vapor.frame_arena.addBytesUsed(n.len);
                break :blk n;
            },
            .@"enum" => {
                const n = Vapor.fmtln("{s}", .{@tagName(value)});
                Vapor.frame_arena.addBytesUsed(n.len);
                break :blk n;
            },
            else => {
                Vapor.printlnErr("Text only accepts []const u8 or number types, NOT {any}", .{@TypeOf(value)});
                return Self{ ._elem_type = .Text, ._text = "", ._ui_node = ui_node, ._returns_close = false };
            },
        };
        return Self{ ._elem_type = .Text, ._text = text, ._ui_node = ui_node, ._returns_close = false };
    }

    pub fn Text(value: anytype) *Self {
        const ui_node = createNode(.{ .state_type = _state_type, .elem_type = .Text, .can_have_children = false });
        const self = Vapor.arena(.frame).create(Self) catch unreachable;
        const text = blk: switch (@typeInfo(@TypeOf(value))) {
            .pointer => |ptr_info| {
                if (ptr_info.size == .one) return {
                    self.* = .{ ._elem_type = .Text, ._text = value, ._ui_node = ui_node, ._persisted_text = true, ._returns_close = false };
                    return self;
                };

                if (ptr_info.size == .slice or ptr_info.size == .one) return {
                    self.* = .{ ._elem_type = .Text, ._text = value, ._ui_node = ui_node, ._persisted_text = true, ._returns_close = false };
                    return self;
                };
            },
            .int => {
                const n = Vapor.fmtln("{any}", .{value});
                Vapor.frame_arena.addBytesUsed(n.len);
                break :blk n;
            },
            .float => {
                const n = Vapor.fmtln("{any}", .{value});
                Vapor.frame_arena.addBytesUsed(n.len);
                break :blk n;
            },
            .@"enum" => {
                const n = Vapor.fmtln("{s}", .{@tagName(value)});
                Vapor.frame_arena.addBytesUsed(n.len);
                break :blk n;
            },
            else => {
                Vapor.printlnErr("Text only accepts []const u8 or number types, NOT {any}", .{@TypeOf(value)});
                return Self{ ._elem_type = .Text, ._text = "", ._ui_node = ui_node, ._returns_close = false };
            },
        };

        self.* = .{ ._elem_type = .Text, ._text = text, ._ui_node = ui_node, ._returns_close = false };
        return self;
    }

    pub fn Html(text: []const u8) Self {
        const ui_node = createNode(.{ .state_type = _state_type, .elem_type = .HtmlText, .can_have_children = false });
        return Self{ ._elem_type = .HtmlText, ._text = text, ._ui_node = ui_node, ._returns_close = false };
    }

    pub fn TextFmt(comptime fmt: []const u8, args: anytype) Self {
        const allocator = Vapor.arena(.frame);
        const text = std.fmt.allocPrint(allocator, fmt, args) catch {
            // Vapor.printlnColor(\\Error formatting text: {any}\n"\\FMT: {s}\n"\\ARGS: {any}\n", .{ err, fmt, args }, .hex("#FF3029"));
            return Self{ ._elem_type = .TextFmt, ._text = "ERROR", ._returns_close = false };
        };
        Vapor.frame_arena.addBytesUsed(text.len);
        const ui_node = LifeCycle.open(.{ .state_type = _state_type, .elem_type = .TextFmt, .can_have_children = false }) orelse {
            Vapor.printlnSrcErr("Could not add component to lifecycle {any}\n", .{error.CouldNotAllocate}, @src());
            unreachable;
        };
        return Self{ ._elem_type = .TextFmt, ._text = text, ._ui_node = ui_node, ._returns_close = false };
    }

    pub fn Graphic(options: struct { src: []const u8 }) Self {
        const ui_node = createNode(.{ .state_type = _state_type, .elem_type = .Graphic, .can_have_children = false });
        return Self{ ._elem_type = .Graphic, ._href = options.src, ._ui_node = ui_node, ._returns_close = false };
    }

    pub fn Icon(token: *const IconTokens) Self {
        const ui_node = createNode(.{ .state_type = _state_type, .elem_type = .Icon, .can_have_children = false });
        return Self{ ._elem_type = .Icon, ._href = token.web orelse "", ._ui_node = ui_node, ._returns_close = false };
    }

    pub fn Svg(options: struct { svg: []const u8, override: bool = false }) Self {
        const ui_node = createNode(.{ .elem_type = .Svg, .can_have_children = false });
        if (options.svg.len > 2048 and Vapor.build_options.enable_debug and !options.override) {
            Vapor.printlnErr("Svg is too large inlining: {d}B, use Graphic;\nSVG Content:\n{s}...", .{ options.svg.len, options.svg[0..100] });
            return Self{ ._elem_type = .Svg, ._svg = "", ._returns_close = false };
        }
        return Self{ ._elem_type = .Svg, ._svg = options.svg, ._ui_node = ui_node, ._returns_close = false };
    }

    pub fn Image(options: struct { src: []const u8, alt: ?[]const u8 = null }) Self {
        const ui_node = createNode(.{ .state_type = _state_type, .elem_type = .Image, .can_have_children = false });
        return Self{ ._elem_type = .Image, ._href = options.src, ._alt = options.alt, ._ui_node = ui_node, ._returns_close = false };
    }

    pub fn Anchor(name: []const u8) Self {
        const ui_node = createNode(.{ .state_type = _state_type, .elem_type = .Anchor });
        return Self{ ._elem_type = .Anchor, ._ui_node = ui_node, ._anchor = name, ._returns_close = true };
    }

    // --- Chainable instance methods ---

    pub fn edges(self: *const Self, edges_tag: ?[]const u8) Self {
        if (edges_tag) |_edges| {
            var n = self.*;
            n._edges = _edges;
            return n;
        }
        return self.*;
    }

    pub fn aspectRatio(self: *const Self, ratio: types.AspectRatio) Self {
        var n = self.*;
        n._aspect_ratio = ratio;
        return n;
    }

    pub fn a11y(self: *const Self, accessibility: Accessibility) Self {
        var n = self.*;
        n._accessibility = accessibility;
        return n;
    }

    pub fn ariaLabel(self: *const Self, label: []const u8) Self {
        var n = self.*;
        var acc = n._accessibility orelse Accessibility{};
        acc.label = label;
        n._accessibility = acc;
        return n;
    }

    pub fn role(self: *const Self, r: Accessibility.Role) Self {
        var n = self.*;
        var acc = n._accessibility orelse Accessibility{};
        acc.role = r;
        n._accessibility = acc;
        return n;
    }

    pub fn ariaExpanded(self: *const Self, expanded: bool) Self {
        var n = self.*;
        var acc = n._accessibility orelse Accessibility{};
        acc.expanded = expanded;
        n._accessibility = acc;
        return n;
    }

    pub fn ariaSelected(self: *const Self, selected: bool) Self {
        var n = self.*;
        var acc = n._accessibility orelse Accessibility{};
        acc.selected = selected;
        n._accessibility = acc;
        return n;
    }

    pub fn ariaControls(self: *const Self, uuid: []const u8) Self {
        var n = self.*;
        var acc = n._accessibility orelse Accessibility{};
        acc.controls = uuid;
        n._accessibility = acc;
        return n;
    }

    pub fn ariaActiveDescendant(self: *const Self, uuid: ?[]const u8) Self {
        var n = self.*;
        var acc = n._accessibility orelse Accessibility{};
        acc.active_descendant = uuid;
        n._accessibility = acc;
        return n;
    }

    pub fn ariaHidden(self: *const Self, hidden_val: bool) Self {
        var n = self.*;
        var acc = n._accessibility orelse Accessibility{};
        acc.hidden = hidden_val;
        n._accessibility = acc;
        return n;
    }

    pub fn tabIndex(self: *const Self, index: i16) Self {
        var n = self.*;
        var acc = n._accessibility orelse Accessibility{};
        acc.tab_index = index;
        n._accessibility = acc;
        return n;
    }

    pub fn fontStyle(self: *const Self, font_style: types.FontStyle) Self {
        var n = self.*;
        var v = n._visual orelse types.Visual{};
        v.font_style = font_style;
        n._visual = v;
        return n;
    }

    pub fn ellipsis(self: *const Self, value: types.Ellipsis) Self {
        if (self._elem_type != .Text and self._elem_type != .TextArea and self._elem_type != .TextField and self._elem_type != .TextFmt) {
            std.log.warn("Ellipsis can only be used on Text, not {any}", .{self._elem_type});
            return self.*;
        }
        var n = self.*;
        var v = n._visual orelse types.Visual{};
        v.ellipsis = value;
        n._visual = v;
        return n;
    }

    pub fn fill(self: *const Self, value: types.Color) Self {
        var n = self.*;
        var v = n._visual orelse types.Visual{};
        v.fill = value;
        n._visual = v;
        return n;
    }

    pub fn stroke(self: *const Self, value: types.Color) Self {
        var n = self.*;
        var v = n._visual orelse types.Visual{};
        v.stroke = value;
        n._visual = v;
        return n;
    }

    pub fn fieldName(self: *const Self, name: []const u8) Self {
        var n = self.*;
        n._name = name;
        return n;
    }

    pub fn inherit(self: *const Self, fields: []const types.StyleFields) Self {
        var n = self.*;
        n._style_fields = fields;
        return n;
    }

    pub fn inheritHover(self: *const Self, fields: []const types.StyleFields) Self {
        var n = self.*;
        n._hover_style_fields = fields;
        return n;
    }

    pub fn bold(self: *const Self) Self {
        var n = self.*;
        var v = n._visual orelse types.Visual{};
        v.font_weight = 700;
        n._visual = v;
        return n;
    }

    pub fn whiteSpace(self: *const Self, value: types.WhiteSpace) Self {
        var n = self.*;
        var v = n._visual orelse types.Visual{};
        v.white_space = value;
        n._visual = v;
        return n;
    }

    pub fn unmanaged(self: *const Self) Self {
        var n = self.*;
        n._persisted_text = false;
        return n;
    }

    pub fn hidden(self: *const Self, hide: bool) Self {
        var n = self.*;
        if (!hide) return n;
        n._flex_type = .hidden;
        return n;
    }

    pub fn bind(self: *const Self, value: anytype) Self {
        var n = self.*;
        if (self._elem_type != .TextField) {
            Vapor.printlnErr("bindValue only works on TextField", .{});
            return self.*;
        }
        if (@typeInfo(@TypeOf(value)) != .pointer) {
            Vapor.printlnErr("bindValue only works on pointer types", .{});
            return self.*;
        }
        n._value = @ptrCast(@alignCast(value));
        return n;
    }

    pub fn onFocus(self: *const Self, cb: fn (*Vapor.Event) void) Self {
        var n = self.*;
        var element = self._element orelse {
            Vapor.printlnSrcErr("Element is null must bind() first, before setting onChange", .{}, @src());
            unreachable;
        };
        const ui_node = self.getOrCreateNode(&n);
        var onid = hashKey(ui_node.uuid);
        onid +%= hashKey(Vapor.on_change_hash);
        element.on_focus = cb;
        Vapor.events_callbacks.put(onid, cb) catch |err| {
            Vapor.println("Event Callback Error: {any}\n", .{err});
        };
        return n;
    }

    pub fn onBlur(self: *const Self, cb: fn (*Vapor.Event) void) Self {
        var n = self.*;
        var element = self._element orelse {
            Vapor.printlnSrcErr("Element is null must bind() first, before setting onChange", .{}, @src());
            unreachable;
        };
        const ui_node = self.getOrCreateNode(&n);
        var onid = hashKey(ui_node.uuid);
        onid +%= hashKey(Vapor.on_blur_hash);
        element.on_blur = cb;
        Vapor.events_callbacks.put(onid, cb) catch |err| {
            Vapor.println("Event Callback Error: {any}\n", .{err});
        };
        return n;
    }

    pub fn onChange(self: *const Self, func: anytype, args: anytype) *const Self {
        const ui_node = self._ui_node orelse {
            Vapor.printlnSrcErr("Node is null", .{}, @src());
            unreachable;
        };

        Vapor.attachEventCallbackCtx(ui_node, .input, func, args) catch |err| {
            Vapor.println("ONCHANGE: Could not attach event callback {any}\n", .{err});
            unreachable;
        };
        return self;
    }

    pub fn onMount(self: *const Self, callback: anytype, args: anytype) *const Self {
        const ui_node = self._ui_node orelse {
            Vapor.printlnSrcErr("Node is null", .{}, @src());
            unreachable;
        };

        const erased = Vapor.ErasedCallback.make(Vapor.arena(.frame), callback, args) catch |err| {
            Vapor.println("Error could not create closure {any}\n", .{err});
            return self;
        };

        var mount_node_key = hashKey(ui_node.uuid);
        mount_node_key +%= hashKey(Vapor.on_mount_hash);

        Vapor.erased_registry.put(mount_node_key, erased) catch |err| {
            Vapor.printlnErr("Could Not add mount callback {any}", .{err});
            return self;
        };
        ui_node.on_callbacks[0] = mount_node_key;

        return self;
    }

    pub fn onUpdate(self: *const Self, callback: anytype, args: anytype) *const Self {
        const ui_node = self._ui_node orelse {
            Vapor.printlnSrcErr("Node is null", .{}, @src());
            unreachable;
        };

        const erased = Vapor.ErasedCallback.make(Vapor.arena(.frame), callback, args) catch |err| {
            Vapor.println("Error could not create closure {any}\n", .{err});
            return self;
        };

        var update_node_key = hashKey(ui_node.uuid);
        update_node_key +%= hashKey(Vapor.on_update_hash);

        Vapor.erased_registry.put(update_node_key, erased) catch |err| {
            Vapor.printlnErr("Could Not add update callback {any}", .{err});
            return self;
        };
        ui_node.on_callbacks[1] = update_node_key;

        return self;
    }

    pub fn onDestroy(self: *const Self, callback: anytype, args: anytype) *const Self {
        const ui_node = self._ui_node orelse {
            Vapor.printlnSrcErr("Node is null", .{}, @src());
            unreachable;
        };

        const erased = Vapor.ErasedCallback.make(Vapor.arena(.frame), callback, args) catch |err| {
            Vapor.println("Error could not create closure {any}\n", .{err});
            return self;
        };

        var destroy_node_key = hashKey(ui_node.uuid);
        destroy_node_key +%= hashKey(Vapor.on_destroy_hash);

        Vapor.erased_registry.put(destroy_node_key, erased) catch |err| {
            Vapor.printlnErr("Could Not add destroy callback {any}", .{err});
            return self;
        };
        ui_node.on_callbacks[2] = destroy_node_key;

        return self;
    }

    pub fn inlineStyle(self: *const Self, comptime fmt: []const u8, args: anytype) Self {
        var n = self.*;
        const allocator = Vapor.arena(.frame);
        const text = std.fmt.allocPrint(allocator, fmt, args) catch {
            // Vapor.printlnColor(\\Error formatting text: {any}\n"\\FMT: {s}\n"\\ARGS: {any}\n", .{ err, fmt, args }, .hex("#FF3029"));
            return n;
        };
        Vapor.frame_arena.addBytesUsed(text.len);
        n._inlineStyle = text;
        return n;
    }

    pub fn inlineStyleStr(self: *const Self, text: []const u8) Self {
        var n = self.*;
        n._inlineStyle = text;
        return n;
    }

    pub fn fontSize(self: *const Self, font_size: u8) Self {
        var n = self.*;
        var v = n._visual orelse types.Visual{};
        v.font_size = font_size;
        n._visual = v;
        return n;
    }

    pub fn fontWeight(self: *const Self, value: u16) Self {
        var n = self.*;
        var v = n._visual orelse types.Visual{};
        v.font_weight = value;
        n._visual = v;
        return n;
    }

    pub fn weight(self: *const Self, value: u16) Self {
        var n = self.*;
        var v = n._visual orelse types.Visual{};
        v.font_weight = value;
        n._visual = v;
        return n;
    }

    pub fn fontFamily(self: *const Self, font_family: []const u8) Self {
        var n = self.*;
        n._font_family = font_family;
        return n;
    }

    pub fn onHover(self: *const Self, func: anytype, args: anytype) *const Self {
        const ui_node = self._ui_node orelse {
            Vapor.printlnSrcErr("Node is null", .{}, @src());
            unreachable;
        };
        Vapor.attachEventCtxCallback(ui_node, .pointerenter, func, args) catch |err| {
            Vapor.println("OnEventCtx: Could not attach event callback {any}\n", .{err});
            unreachable;
        };
        return self;
    }

    pub fn onLeave(self: *const Self, func: anytype, args: anytype) *const Self {
        const ui_node = self._ui_node orelse {
            Vapor.printlnSrcErr("Node is null", .{}, @src());
            unreachable;
        };
        Vapor.attachEventCtxCallback(ui_node, .mouseleave, func, args) catch |err| {
            Vapor.println("ONLEAVE: Could not attach event callback {any}\n", .{err});
            unreachable;
        };
        return self;
    }

    pub fn onEvent(self: *const Self, event: types.EventType, func: anytype, args: anytype) Self {
        const ui_node = self._ui_node orelse {
            Vapor.printlnSrcErr("Node is null", .{}, @src());
            unreachable;
        };
        Vapor.attachEventCtxCallback(ui_node, event, func, args) catch |err| {
            Vapor.println("OnEventCtx: Could not attach event callback {any}\n", .{err});
            unreachable;
        };
        return self.*;
    }

    pub fn onEventCtx(self: *const Self, event: types.EventType, func: anytype, args: anytype) *const Self {
        const ui_node = self._ui_node orelse {
            Vapor.printlnSrcErr("Node is null", .{}, @src());
            unreachable;
        };
        Vapor.attachEventCtxCallback(ui_node, event, func, args) catch |err| {
            Vapor.println("OnEventCtx: Could not attach event callback {any}\n", .{err});
            unreachable;
        };
        return self;
    }

    pub fn onMountCtx(self: *const Self, cb: anytype, args: anytype) Self {
        var n = self.*;
        const ui_node = self.getOrCreateNode(&n);
        const Args = @TypeOf(args);
        const Closure = struct {
            arguments: Args,
            run_node: Vapor.Node = .{ .data = .{ .runFn = runFn, .deinitFn = deinitFn } },
            fn runFn(action: *Vapor.Action) void {
                const run_node: *Vapor.Node = @fieldParentPtr("data", action);
                const closure: *@This() = @alignCast(@fieldParentPtr("run_node", run_node));
                @call(.auto, cb, closure.arguments);
            }
            fn deinitFn(node: *Vapor.Node) void {
                const closure: *@This() = @alignCast(@fieldParentPtr("run_node", node));
                Vapor.allocator_global.destroy(closure);
            }
        };
        const closure = Vapor.arena(.frame).create(Closure) catch |err| {
            println("Error could not create closure {any}\n ", .{err});
            unreachable;
        };
        closure.* = .{ .arguments = args };
        Vapor.mounted_ctx_funcs.put(hashKey(ui_node.uuid), &closure.run_node) catch |err| {
            println("Hooks Function Registry {any}\n", .{err});
        };
        return n;
    }

    pub fn onHoverCtx(self: *const Self, cb: anytype, args: anytype) Self {
        var n = self.*;
        const ui_node = self.getOrCreateNode(&n);
        Vapor.attachEventCtxCallback(ui_node, .mouseenter, cb, args) catch |err| {
            Vapor.println("ONHOVERCTX: Could not attach event callback {any}\n", .{err});
            unreachable;
        };
        return n;
    }

    pub fn onDragStart(self: *const Self, cb: fn (*Vapor.Event) void) Self {
        var n = self.*;
        const ui_node = self.getOrCreateNode(&n);
        Vapor.attachEventCallback(ui_node, .pointerdown, cb) catch |err| {
            Vapor.println("ONDRAGSTART: Could not attach event callback {any}\n", .{err});
            unreachable;
        };
        return n;
    }

    pub fn scroll(self: *const Self, scroll_type: types.Scroll) Self {
        var n = self.*;
        n._scroll = scroll_type;
        return n;
    }

    pub fn createDraggable(self: *const Self, draggable_ptr: *Draggable) *const Self {
        var element = draggable_ptr.element;
        var ui_node = self._ui_node orelse {
            Vapor.printlnSrcErr("Node is null must ref() first", .{}, @src());
            unreachable;
        };
        ui_node.hooks.created_id = 1;
        element.element_type = self._elem_type;
        element._node_ptr = ui_node;
        draggable_ptr.element = element;
        Vapor.attachEventCtxCallback(
            ui_node,
            .pointerdown,
            Draggable.handlePointerDown,
            .{draggable_ptr},
        ) catch |err| {
            Vapor.println("ONDRAGSTART: Could not attach event callback {any}\n", .{err});
            unreachable;
        };

        // Vapor.onEndCtx(struct {
        //     pub fn attachDraggable(draggable: *Draggable) void {
        //         draggable.addStartListener();
        //     }
        // }.attachDraggable, .{draggable_ptr});
        return self;
    }

    pub fn id(self: *const Self, element_id: []const u8) Self {
        var n = self.*;
        n._id = element_id;
        n._ui_node.?.uuid = element_id;
        return n;
    }

    pub fn anchorSource(self: *const Self, name: []const u8) Self {
        var n = self.*;
        n._anchor = name;
        return n;
    }

    pub fn animationEnter(self: *const Self, animation_tag: ?[]const u8) Self {
        if (animation_tag) |a| {
            var n = self.*;
            n._animation_enter = a;
            return n;
        }
        return self.*;
    }

    pub fn animation(self: *const Self, animation_tag: ?[]const u8) Self {
        if (animation_tag) |a| {
            var n = self.*;
            var v = n._visual orelse types.Visual{};
            v.animation = a;
            n._visual = v;
            return n;
        }
        return self.*;
    }

    pub fn animationExit(self: *const Self, animation_tag: ?[]const u8) Self {
        var n = self.*;
        n._animation_exit = animation_tag;
        return n;
    }

    pub fn class(self: *const Self, class_name: []const u8) Self {
        var n = self.*;
        n._class = class_name;
        return n;
    }

    pub fn classFmt(self: *const Self, comptime fmt: []const u8, args: anytype) Self {
        var n = self.*;
        const allocator = Vapor.arena(.frame);
        const text = std.fmt.allocPrint(allocator, fmt, args) catch {
            // Vapor.printlnColor(\\Error formatting text: {any}\n"\\FMT: {s}\n"\\ARGS: {any}\n", .{ err, fmt, args }, .hex("#FF3029"));
            return n;
        };
        Vapor.frame_arena.addBytesUsed(text.len);
        n._class = text;
        return n;
    }

    pub fn transition(self: *const Self, _transition: types.Transition) Self {
        var n = self.*;
        n._transition = _transition;
        return n;
    }

    pub fn transform(self: *const Self, value: ?types.Transform) Self {
        var n = self.*;
        var v = n._visual orelse types.Visual{};
        v.transform = value;
        n._visual = v;
        return n;
    }

    pub fn scale(self: *const Self, value: f16) Self {
        var n = self.*;
        var v = n._visual orelse types.Visual{};
        v.transform = .scaleDecimal(value);
        n._visual = v;
        return n;
    }

    pub fn ref(self: *const Self, element: *Element) Self {
        var n = self.*;
        const ui_node = self.getOrCreateNode(&n);
        element.element_type = self._elem_type;
        element._node_ptr = ui_node;
        n._element = element;
        Vapor.element_registry.put(hashKey(ui_node.uuid), element) catch unreachable;
        return n;
    }

    pub fn baseStyle(self: *const Self, style_ptr: *const Vapor.Style) Self {
        var n = self.*;
        n._style = style_ptr;
        return n;
    }

    pub fn interaction(self: *const Self, interactive: types.Interactive) Self {
        var n = self.*;
        n._interactive = interactive;
        return n;
    }

    pub fn textColor(self: *const Self, color: ?Color) Self {
        var n = self.*;
        var v = n._visual orelse types.Visual{};
        v.text_color = color;
        n._visual = v;
        return n;
    }

    pub fn fontColor(self: *const Self, color: ?Color) Self {
        var n = self.*;
        var v = n._visual orelse types.Visual{};
        v.text_color = color;
        n._visual = v;
        return n;
    }

    pub fn font(self: *const Self, font_size_val: u8, font_weight: ?u16, color: ?Color) Self {
        var n = self.*;
        var v = n._visual orelse types.Visual{};
        v.font_size = font_size_val;
        v.font_weight = font_weight;
        v.text_color = color;
        n._visual = v;
        return n;
    }

    pub fn pos(self: *const Self, position: types.Position) Self {
        var n = self.*;
        var p = n._pos orelse types.Position{};
        p.top = position.top;
        p.right = position.right;
        p.bottom = position.bottom;
        p.left = position.left;
        p.type = position.type;
        n._pos = p;
        return n;
    }

    pub fn zIndex(self: *const Self, z_index: ?i16) Self {
        var n = self.*;
        var p = n._pos orelse types.Position{};
        p.z_index = z_index;
        n._pos = p;
        return n;
    }

    pub fn blur(self: *const Self, value: ?u8) Self {
        var n = self.*;
        var v = n._visual orelse types.Visual{};
        v.blur = value;
        n._visual = v;
        return n;
    }

    pub fn layout(self: *const Self, value: types.Layout) Self {
        var n = self.*;
        n._layout = value;
        return n;
    }

    pub fn anchorPlacement(self: *const Self, value: types.AnchorPlacement) Self {
        var n = self.*;
        n._placement = value;
        return n;
    }

    pub fn placement(self: *const Self, value: types.AnchorPlacement) Self {
        var n = self.*;
        n._placement = value;
        return n;
    }

    pub fn center(self: *const Self) Self {
        var n = self.*;
        n._layout = .center;
        return n;
    }

    pub fn background(self: *const Self, value: types.Color) Self {
        var n = self.*;
        var v = n._visual orelse types.Visual{};
        v.background = value;
        n._visual = v;
        return n;
    }

    pub fn outline(self: *const Self, value: types.Outline, color: ?Color) Self {
        var new_self: Self = self.*;
        var visual = new_self._visual orelse types.Visual{};
        visual.outline = value;
        visual.outline_color = color;
        new_self._visual = visual;
        return new_self;
    }

    pub fn shadow(self: *const Self, value: ?types.Shadow) Self {
        if (value == null) return self.*;
        var n = self.*;
        var v = n._visual orelse types.Visual{};
        if (self._elem_type == .Text or self._elem_type == .TextFmt) {
            v.text_shadow = value;
        } else {
            v.shadow = value;
        }
        n._visual = v;
        return n;
    }

    pub fn newShadow(self: *const Self, value: ?Shadow) Self {
        if (value == null) return self.*;
        var n = self.*;
        var v = n._visual orelse types.Visual{};
        v.new_shadow = value.?;
        n._visual = v;
        return n;
    }

    pub fn layer(self: *const Self, value: ?types.BackgroundLayer) Self {
        if (value == null) return self.*;
        var n = self.*;
        var v = n._visual orelse types.Visual{};
        v.layer = value;
        n._visual = v;
        return n;
    }

    pub fn layers(self: *const Self, value: ?[]const types.BackgroundLayer) Self {
        if (value == null) return self.*;
        var n = self.*;
        var v = n._visual orelse types.Visual{};
        v.layers = value;
        n._visual = v;
        return n;
    }

    pub fn gradient(self: *const Self, value: types.Background) Self {
        var n = self.*;
        var v = n._visual orelse types.Visual{};
        v.background = value;
        n._visual = v;
        return n;
    }

    pub fn wrap(self: *const Self, value: types.FlexWrap) Self {
        var n = self.*;
        n._flex_wrap = value;
        return n;
    }

    pub fn textDecoration(self: *const Self, value: types.TextDecoration) Self {
        var n = self.*;
        var v = n._visual orelse types.Visual{};
        v.text_decoration = value;
        n._visual = v;
        return n;
    }

    pub fn hoverScale(self: *const Self) Self {
        var n = self.*;
        var i = n._interactive orelse types.Interactive{};
        var h = i.hover orelse types.Visual{};
        h.transform = .scale();
        i.hover = h;
        n._interactive = i;
        return n;
    }

    pub fn hover(self: *const Self, value: types.Visual) Self {
        var n = self.*;
        var i = n._interactive orelse types.Interactive{};
        i.hover = value;
        n._interactive = i;
        return n;
    }

    pub fn hoverBackground(self: *const Self, color: types.Color) Self {
        var n = self.*;
        var i = n._interactive orelse types.Interactive{};
        var h = i.hover orelse types.Visual{};
        h.background = color;
        i.hover = h;
        n._interactive = i;
        return n;
    }

    pub fn pointer(self: *const Self) Self {
        var n = self.*;
        var v = n._visual orelse types.Visual{};
        v.cursor = .pointer;
        n._visual = v;
        return n;
    }

    pub fn noDecoration(self: *const Self) Self {
        var n = self.*;
        var v = n._visual orelse types.Visual{};
        v.text_decoration = .none;
        n._visual = v;
        return n;
    }

    pub fn opacity(self: *const Self, value: f16) Self {
        var n = self.*;
        var v = n._visual orelse types.Visual{};
        v.opacity = value;
        n._visual = v;
        return n;
    }

    pub fn hoverText(self: *const Self, color: Color) Self {
        var n = self.*;
        var i = n._interactive orelse types.Interactive{};
        var h = i.hover orelse types.Visual{};
        h.text_color = color;
        i.hover = h;
        n._interactive = i;
        return n;
    }

    pub fn spacing(self: *const Self, value: u8) Self {
        var n = self.*;
        n._child_gap = value;
        const node = self._ui_node orelse {
            Vapor.printlnSrcErr("Node is null", .{}, @src());
            return self.*;
        };
        node.spacing = value;
        return n;
    }

    pub fn transformOrigin(self: *const Self, value: types.TransformOrigin) Self {
        var n = self.*;
        n._transform_origin = value;
        return n;
    }

    pub fn padding(self: *const Self, value: types.Padding) Self {
        var n = self.*;
        n._padding = value;
        return n;
    }

    pub fn pl(self: *const Self, value: u8) Self {
        var n = self.*;
        if (n._padding == null) n._padding = .{};
        n._padding.?._left = value;
        return n;
    }
    pub fn pr(self: *const Self, value: u8) Self {
        var n = self.*;
        if (n._padding == null) n._padding = .{};
        n._padding.?._right = value;
        return n;
    }
    pub fn pt(self: *const Self, value: u8) Self {
        var n = self.*;
        if (n._padding == null) n._padding = .{};
        n._padding.?._top = value;
        return n;
    }
    pub fn pb(self: *const Self, value: u8) Self {
        var n = self.*;
        if (n._padding == null) n._padding = .{};
        n._padding.?._bottom = value;
        return n;
    }
    pub fn mt(self: *const Self, value: i16) Self {
        var n = self.*;
        if (n._margin == null) n._margin = .{};
        n._margin.?.top = value;
        return n;
    }
    pub fn mb(self: *const Self, value: i16) Self {
        var n = self.*;
        if (n._margin == null) n._margin = .{};
        n._margin.?.bottom = value;
        return n;
    }
    pub fn ml(self: *const Self, value: i16) Self {
        var n = self.*;
        if (n._margin == null) n._margin = .{};
        n._margin.?.left = value;
        return n;
    }
    pub fn mr(self: *const Self, value: i16) Self {
        var n = self.*;
        if (n._margin == null) n._margin = .{};
        n._margin.?.right = value;
        return n;
    }
    pub fn my(self: *const Self, value: i16) Self {
        var n = self.*;
        if (n._margin == null) n._margin = .{};
        n._margin.?.top = value;
        n._margin.?.bottom = value;
        return n;
    }
    pub fn mx(self: *const Self, value: i16) Self {
        var n = self.*;
        if (n._margin == null) n._margin = .{};
        n._margin.?.left = value;
        n._margin.?.right = value;
        return n;
    }

    pub fn cursor(self: *const Self, value: types.Cursor) Self {
        var n = self.*;
        var v = n._visual orelse types.Visual{};
        v.cursor = value;
        n._visual = v;
        return n;
    }

    pub fn margin(self: *const Self, value: types.Margin) Self {
        var n = self.*;
        n._margin = value;
        return n;
    }

    pub fn size(self: *const Self, dim: types.Size) Self {
        var n = self.*;
        n._size = dim;
        return n;
    }

    pub fn hw(self: *const Self, height_value: types.Sizing, width_value: types.Sizing) Self {
        var n = self.*;
        if (n._size == null) {
            n._size = .{ .width = width_value, .height = height_value };
        } else {
            n._size.?.width = width_value;
            n._size.?.height = height_value;
        }
        return n;
    }

    pub fn width(self: *const Self, length: types.Sizing) Self {
        var n = self.*;
        if (n._size == null) {
            n._size = .{ .width = length };
        } else {
            n._size.?.width = length;
        }
        return n;
    }

    pub fn minWidth(self: *const Self, min: types.Sizing) Self {
        var n = self.*;
        const sizing: types.Sizing = switch (min.type) {
            .percent => .{ .type = .min_percent, .size = min.size },
            .fixed => .{ .type = .min_px, .size = min.size },
            else => unreachable,
        };
        if (n._size == null) {
            n._size = .{ .width = sizing };
        } else {
            n._size.?.width = sizing;
        }
        return n;
    }

    pub fn maxWidth(self: *const Self, max: types.Sizing) Self {
        var n = self.*;
        const sizing: types.Sizing = switch (max.type) {
            .percent => .{ .type = .max_percent, .size = max.size },
            .fixed => .{ .type = .max_px, .size = max.size },
            else => unreachable,
        };
        if (n._size == null) {
            n._size = .{ .width = sizing };
        } else {
            n._size.?.width = sizing;
        }
        return n;
    }

    pub fn height(self: *const Self, length: types.Sizing) Self {
        var n = self.*;
        if (n._size == null) {
            n._size = .{ .height = length };
        } else {
            n._size.?.height = length;
        }
        return n;
    }

    pub fn minHeight(self: *const Self, min: types.Sizing) Self {
        var n = self.*;
        const sizing: types.Sizing = switch (min.type) {
            .percent => .{ .type = .min_percent, .size = min.size },
            .fixed => .{ .type = .min_px, .size = min.size },
            else => unreachable,
        };
        if (n._size == null) {
            n._size = .{ .height = sizing };
        } else {
            n._size.?.height = sizing;
        }
        return n;
    }

    pub fn maxHeight(self: *const Self, max: types.Sizing) Self {
        var n = self.*;
        const sizing: types.Sizing = switch (max.type) {
            .percent => .{ .type = .max_percent, .size = max.size },
            .fixed => .{ .type = .max_px, .size = max.size },
            else => unreachable,
        };
        if (n._size == null) {
            n._size = .{ .height = sizing };
        } else {
            n._size.?.height = sizing;
        }
        return n;
    }

    pub fn columns(self: *const Self, column_count: u8) *const Self {
        const node = self._ui_node orelse {
            Vapor.printlnSrcErr("Node is null", .{}, @src());
            return self;
        };
        node.column_count = column_count;
        return self;
    }

    pub fn border(self: *const Self, value: types.BorderGrouped) Self {
        var n = self.*;
        var v = n._visual orelse types.Visual{};
        v.border = value;
        n._visual = v;
        return n;
    }

    pub fn borderStyle(self: *const Self, value: types.BorderStyle) Self {
        var n = self.*;
        var v = n._visual orelse types.Visual{};
        var b = v.border orelse types.BorderGrouped{ .color = null, .thickness = .all(0) };
        b.style = value;
        v.border = b;
        n._visual = v;
        return n;
    }

    pub fn radius(self: *const Self, value: types.BorderRadius) Self {
        var n = self.*;
        var v = n._visual orelse types.Visual{};
        var b = v.border orelse types.BorderGrouped{ .color = null, .thickness = .all(0) };
        b.radius = value;
        v.border = b;
        n._visual = v;
        return n;
    }

    pub fn colorMix(self: *const Self, value: types.ColorMix) Self {
        var n = self.*;
        var v = n._visual orelse types.Visual{};
        v.color_mix = value;
        n._visual = v;
        return n;
    }

    pub fn duration(self: *const Self, value: u32) Self {
        var n = self.*;
        n._transition = .{ .duration = value };
        return n;
    }

    pub fn direction(self: *const Self, value: types.Direction) Self {
        var n = self.*;
        n._direction = value;
        self._ui_node.?.direction = value;
        return n;
    }

    pub fn listStyle(self: *const Self, value: types.ListStyle) Self {
        var n = self.*;
        n._list_style = value;
        return n;
    }

    // --- Terminal methods ---

    pub fn style(self: *const Self, style_ptr: *const Vapor.Style) Self {
        var n = self.*;
        n._style = style_ptr;
        return n;

        // var n = self.*;
        // var elem_decl = Vapor.ElementDecl{
        //     .state_type = _state_type,
        //     .elem_type = self._elem_type,
        //     .text = self._text,
        //     .style = style_ptr,
        //     .href = self._href,
        //     .svg = self._svg,
        //     .alt = self._alt,
        //     .aria_label = self._aria_label,
        //     .animation_enter = self._animation_enter,
        //     .animation_exit = self._animation_exit,
        //     .name = self._name,
        //     .inlineStyle = self._inlineStyle,
        // };
        // if (self._flex_type == .center) {
        //     var ms = style_ptr.*;
        //     ms.layout = .center;
        //     elem_decl.style = &ms;
        // } else if (self._flex_type == .stack) {
        //     var ms = style_ptr.*;
        //     ms.direction = .column;
        //     elem_decl.style = &ms;
        // }
        // if (self._id) |_id| {
        //     var ms = style_ptr.*;
        //     ms.id = _id;
        //     elem_decl.style = &ms;
        // }
        // if (self._class) |_class| {
        //     var ms = style_ptr.*;
        //     ms.style_id = _class;
        //     elem_decl.style = &ms;
        // }
        // n._used_style = true;
        // _ = Vapor.current_ctx.configureByNode(self._ui_node, elem_decl);
        // return n;
    }

    pub fn child(self: *const Self, item: anytype) void {
        if (@TypeOf(item) == Builder(.pure)) {
            var added_node: Builder(.pure) = item;
            added_node._ui_node = item._ui_node;
            added_node.end();
        }

        var mutable_style = mergeStyles(self.getStyleMergeParams(true, false));
        const elem_decl = Vapor.ElementDecl{
            .state_type = _state_type,
            .elem_type = self._elem_type,
            .text = self._text,
            .style = &mutable_style,
            .href = self._href,
            .svg = self._svg,
            .aria_label = self._aria_label,
            .animation_enter = self._animation_enter,
            .animation_exit = self._animation_exit,
            .inlineStyle = self._inlineStyle,
            .accessibility = self._accessibility,
        };

        Vapor.LifeCycle.configure(elem_decl);
        return Vapor.LifeCycle.close({});
    }

    pub fn items(self: *const Self, nodes: anytype) void {
        inline for (nodes) |kid| {
            if (@TypeOf(kid) == ComponentBuilder) {
                var added_node: ComponentBuilder = kid;
                added_node._ui_node = kid._ui_node;
                added_node.end();
            }
        }
        var mutable_style = mergeStyles(self.getStyleMergeParams(true, false));
        const elem_decl = Vapor.ElementDecl{
            .state_type = _state_type,
            .elem_type = self._elem_type,
            .text = self._text,
            .style = &mutable_style,
            .href = self._href,
            .svg = self._svg,
            .aria_label = self._aria_label,
            .animation_enter = self._animation_enter,
            .animation_exit = self._animation_exit,
            .inlineStyle = self._inlineStyle,
            .accessibility = self._accessibility,
        };
        Vapor.LifeCycle.configure(elem_decl);
        return Vapor.LifeCycle.close({});
    }

    pub fn children(self: *const Self, _: void) void {
        if (self._used_style) return Vapor.LifeCycle.close({});
        var mutable_style = mergeStyles(self.getStyleMergeParams(true, false));
        const elem_decl = Vapor.ElementDecl{
            .state_type = _state_type,
            .elem_type = self._elem_type,
            .text = self._text,
            .style = &mutable_style,
            .href = self._href,
            .svg = self._svg,
            .aria_label = self._aria_label,
            .animation_enter = self._animation_enter,
            .animation_exit = self._animation_exit,
            .inlineStyle = self._inlineStyle,
            .accessibility = self._accessibility,
        };
        Vapor.LifeCycle.configure(elem_decl);
        return Vapor.LifeCycle.close({});
    }

    pub fn end(self: *const Self) void {
        const ui_node = self._ui_node orelse unreachable;
        if (self._used_style) {
            if (ui_node.can_have_children) LifeCycle.close({});
            return;
        }
        var mutable_style = mergeStyles(self.getStyleMergeParams(false, true));
        var text: ?[]const u8 = self._text;
        if (self._elem_type == .Text and self._persisted_text) text = persistText(self._ui_node, self._text);
        const elem_decl = self.makeElemDecl(text, &mutable_style);
        _ = Vapor.current_ctx.configureByNode(self._ui_node, elem_decl);
        if (ui_node.can_have_children) LifeCycle.close({});
    }

    pub fn getUUID(self: *const Self) []const u8 {
        if (self._ui_node == null) {
            Vapor.printlnSrcErr("getUUID Failed: Node is null", .{}, @src());
            return "";
        }
        return self._ui_node.?.uuid;
    }
};

// ============================================================
// Backward-compatible aliases
// ============================================================

const InertBuilder = @import("Inert.zig").InertBuilder;
pub fn Builder(comptime state_type: types.StateType) type {
    _ = state_type;
    return ComponentBuilder;
    // switch (state_type) {
    //     .inert => {
    //         return InertBuilder;
    //     },
    //     .pure => {
    //         return ComponentBuilder;
    //     },
    //     else => {
    //         return ComponentBuilder;
    //     },
    // }
}

pub fn BuilderClose(comptime state_type: types.StateType) type {
    _ = state_type;
    return ComponentBuilder;
}
