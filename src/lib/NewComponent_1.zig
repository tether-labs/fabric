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
pub const IconTokens = @import("user_config").IconTokens;
const utils = @import("utils.zig");
const hashKey = utils.hashKey;
const Draggable = @import("Draggable.zig").Draggable;
const onCreateNode = @import("Hooks.zig").onCreateNode;
const Shadow = @import("Shadow.zig");
const Accessibility = @import("Accessibility.zig").Accessibility;

pub const StringEntry = struct {
    ptr: [*]const u8, // original source ptr (used as key)
    len: usize, // original len
    persisted: []const u8, // our copy
};

pub var text_string_table: std.AutoHashMap(u32, StringEntry) = undefined;

// ... keep HeaderSize, Header, Hooks, LinkOptions, FlexType, Position, Layout, Tooltip, createNode as-is ...

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
        .state_type = .static,
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

pub inline fn Hooks(hooks: Vapor.HooksFuncs) fn (void) void {
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

const Position = enum {
    top,
    bottom,
    left,
    right,
};

const Layout = enum {
    center,
    start,
    end,
};

fn createNode(elem_decl: ElementDecl) *UINode {
    const ui_node = LifeCycle.open(elem_decl) orelse {
        Vapor.printlnSrcErr("Could not add component Link to lifecycle {any}\n", .{error.CouldNotAllocate}, @src());
        unreachable;
    };
    return ui_node;
}

const AnchorSource = struct {
    id: []const u8,
};

const AnchorTarget = struct {
    id: []const u8,
    placement: types.Layout,
    position: types.Position,
};

/// Unified builder that can operate in two modes:
/// - `returns_close = true`: style()/children()/end() return the close function
/// - `returns_close = false`: style()/children()/end() call close directly and return void
pub fn GenericBuilder(comptime state_type: types.StateType, comptime returns_close: bool) type {
    return struct {
        const Self = @This();
        const _state_type: types.StateType = state_type;

        // Conditional return types
        const StyleReturnType = if (returns_close) *const fn (void) void else void;
        const EndReturnType = if (returns_close) *const fn (void) void else void;

        _level: ?u8 = null,
        _video: ?*const types.Video = null,
        _font_family: []const u8 = "",
        _value: ?*anyopaque = null,

        _elem_type: Vapor.ElementType,
        _flex_type: types.FlexType = .flex,
        _text: ?[]const u8 = null,
        _href: ?[]const u8 = null,
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

        // Style props
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
        _direction: types.Direction = .row,
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
        // In GenericBuilder struct, add field:
        _accessibility: ?Accessibility = null,
        _column_count: ?u8 = null,

        _edges: ?[]const u8 = null,

        pub fn edges(self: *const Self, edges_tag: ?[]const u8) Self {
            if (edges_tag) |_edges| {
                var new_self: Self = self.*;
                new_self._edges = _edges;
                return new_self;
            }
            return self.*;
        }

        // Helper to handle the close operation based on mode
        inline fn doClose() StyleReturnType {
            if (returns_close) {
                return LifeCycle.close;
            } else {
                LifeCycle.close({});
            }
        }

        // Extract to helper:
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

        // ============================================================
        // Constructor methods available in BOTH modes
        // ============================================================

        pub fn Null() void {
            _ = LifeCycle.open(.{
                .elem_type = .Noop,
                .state_type = _state_type,
            });
            LifeCycle.configure(.{
                .elem_type = .Noop,
                .state_type = _state_type,
            });
            LifeCycle.close({});
        }

        pub fn Null2(elem_type: Vapor.Types.ElementType) void {
            _ = LifeCycle.open(.{
                .elem_type = elem_type,
                .state_type = _state_type,
            });
            LifeCycle.configure(.{
                .elem_type = .Noop,
                .state_type = _state_type,
            });
            LifeCycle.close({});
        }

        pub fn Heading(level: u8, text: []const u8) Self {
            const elem_decl = ElementDecl{
                .state_type = _state_type,
                .elem_type = .Heading,
                .text = text,
                .level = level,
            };
            const ui_node = createNode(elem_decl);
            return Self{ ._elem_type = .Heading, ._text = text, ._level = level, ._ui_node = ui_node };
        }

        pub fn Video(options: *const types.Video) Self {
            const elem_decl = ElementDecl{
                .state_type = _state_type,
                .elem_type = .Video,
                .can_have_children = false,
            };
            const ui_node = Vapor.current_ctx.open(elem_decl) catch |err| {
                println("{any}\n", .{err});
                unreachable;
            };
            return Self{
                ._elem_type = .Video,
                ._video = options,
                ._ui_node = ui_node,
            };
        }

        pub fn aspectRatio(self: *const Self, ratio: types.AspectRatio) Self {
            var new_self: Self = self.*;
            new_self._aspect_ratio = ratio;
            return new_self;
        }

        // ============================================================
        // Constructor methods only for Builder (returns_close = true)
        // ============================================================

        pub inline fn Box() Self {
            const elem_decl = ElementDecl{ .state_type = _state_type, .elem_type = .FlexBox };
            const ui_node = createNode(elem_decl);
            return Self{ ._ui_node = ui_node, ._elem_type = .FlexBox };
        }

        pub fn Table() Self {
            const elem_decl = ElementDecl{ .state_type = _state_type, .elem_type = .Table };
            const ui_node = createNode(elem_decl);
            return Self{ ._ui_node = ui_node, ._elem_type = .Table };
        }

        pub fn TableRow() Self {
            const elem_decl = ElementDecl{ .state_type = _state_type, .elem_type = .TableRow };
            const ui_node = createNode(elem_decl);
            return Self{ ._ui_node = ui_node, ._elem_type = .TableRow };
        }

        pub fn TableCell() Self {
            const elem_decl = ElementDecl{ .state_type = _state_type, .elem_type = .TableCell };
            const ui_node = createNode(elem_decl);
            return Self{ ._ui_node = ui_node, ._elem_type = .TableCell };
        }

        pub fn TableBody() Self {
            const elem_decl = ElementDecl{ .state_type = _state_type, .elem_type = .TableBody };
            const ui_node = createNode(elem_decl);
            return Self{ ._ui_node = ui_node, ._elem_type = .TableBody };
        }

        pub fn TableHeader() Self {
            const elem_decl = ElementDecl{ .state_type = _state_type, .elem_type = .TableHeader };
            const ui_node = createNode(elem_decl);
            return Self{ ._ui_node = ui_node, ._elem_type = .TableHeader };
        }

        pub fn TableHead() Self {
            const elem_decl = ElementDecl{ .state_type = _state_type, .elem_type = .TableHead };
            const ui_node = createNode(elem_decl);
            return Self{ ._ui_node = ui_node, ._elem_type = .TableHead };
        }

        pub fn Form(submit: anytype, args: anytype) Self {
            const elem_decl = ElementDecl{ .state_type = _state_type, .elem_type = .Form };
            const ui_node = createNode(elem_decl);

            Vapor.attachEventCtxCallback(ui_node, .submit, submit, args) catch |err| {
                Vapor.println("ONSUBMIT: Could not attach event callback {any}\n", .{err});
                unreachable;
            };

            return Self{ ._ui_node = ui_node, ._elem_type = .Form };
        }

        pub fn Section() Self {
            const elem_decl = ElementDecl{
                .state_type = _state_type,
                .elem_type = .Intersection,
            };
            const ui_node = LifeCycle.open(elem_decl) orelse {
                Vapor.printlnSrcErr("Could not add component Link to lifecycle {any}\n", .{error.CouldNotAllocate}, @src());
                unreachable;
            };

            return Self{
                ._ui_node = ui_node,
                ._elem_type = .Intersection,
            };
        }

        pub fn List() Self {
            const elem_decl = ElementDecl{
                .state_type = _state_type,
                .elem_type = .List,
            };
            const ui_node = LifeCycle.open(elem_decl) orelse {
                Vapor.printlnSrcErr("Could not add component Link to lifecycle {any}\n", .{error.CouldNotAllocate}, @src());
                unreachable;
            };

            return Self{
                ._ui_node = ui_node,
                ._elem_type = .List,
            };
        }

        pub fn ListItem() Self {
            const elem_decl = ElementDecl{
                .state_type = _state_type,
                .elem_type = .ListItem,
            };
            const ui_node = LifeCycle.open(elem_decl) orelse {
                Vapor.printlnSrcErr("Could not add component Link to lifecycle {any}\n", .{error.CouldNotAllocate}, @src());
                unreachable;
            };

            return Self{
                ._ui_node = ui_node,
                ._elem_type = .ListItem,
            };
        }

        pub fn Center() Self {
            const elem_decl = ElementDecl{
                .state_type = _state_type,
                .elem_type = .FlexBox,
            };
            const ui_node = LifeCycle.open(elem_decl) orelse {
                Vapor.printlnSrcErr("Could not add component Link to lifecycle {any}\n", .{error.CouldNotAllocate}, @src());
                unreachable;
            };

            return Self{
                ._ui_node = ui_node,
                ._elem_type = .FlexBox,
                ._flex_type = .center,
            };
        }

        pub fn Stack() Self {
            const elem_decl = ElementDecl{
                .state_type = _state_type,
                .elem_type = .FlexBox,
            };
            const ui_node = LifeCycle.open(elem_decl) orelse {
                Vapor.printlnSrcErr("Could not add component Link to lifecycle {any}\n", .{error.CouldNotAllocate}, @src());
                unreachable;
            };

            ui_node.direction = .column;

            return Self{
                ._ui_node = ui_node,
                ._elem_type = .FlexBox,
                ._flex_type = .stack,
                ._direction = .column,
            };
        }

        pub fn Link(options: LinkOptions) Self {
            const elem_decl = ElementDecl{
                .state_type = _state_type,
                .elem_type = .Link,
                .href = options.url,
                .aria_label = options.aria_label,
            };
            const ui_node = LifeCycle.open(elem_decl) orelse {
                Vapor.printlnSrcErr("Could not add component Link to lifecycle {any}\n", .{error.CouldNotAllocate}, @src());
                unreachable;
            };

            return Self{
                ._ui_node = ui_node,
                ._elem_type = .Link,
                ._aria_label = options.aria_label,
                ._href = options.url,
            };
        }

        pub fn RedirectLink(options: LinkOptions) Self {
            const elem_decl = ElementDecl{
                .state_type = _state_type,
                .elem_type = .RedirectLink,
                .href = options.url,
                .aria_label = options.aria_label,
            };
            const ui_node = LifeCycle.open(elem_decl) orelse {
                Vapor.printlnSrcErr("Could not add component Link to lifecycle {any}\n", .{error.CouldNotAllocate}, @src());
                unreachable;
            };

            return Self{
                ._ui_node = ui_node,
                ._elem_type = .RedirectLink,
                ._aria_label = options.aria_label,
                ._href = options.url,
            };
        }

        // ============================================================
        // Constructor methods only for BuilderClose (returns_close = false)
        // ============================================================

        pub fn Label(text: []const u8) Self {
            const elem_decl = ElementDecl{
                .state_type = .static,
                .elem_type = .Label,
                .text = text,
                .can_have_children = false,
            };
            const ui_node = LifeCycle.open(elem_decl) orelse {
                Vapor.printlnSrcErr("Could not add component Link to lifecycle {any}\n", .{error.CouldNotAllocate}, @src());
                unreachable;
            };

            return Self{
                ._elem_type = .Label,
                ._text = text,
                ._ui_node = ui_node,
            };
        }

        pub fn Code(value: anytype) Self {
            const text = blk: switch (@typeInfo(@TypeOf(value))) {
                .pointer => |_| {
                    break :blk value;
                },
                .int => {
                    break :blk Vapor.fmtln("{any}", .{value});
                },
                else => {
                    Vapor.printlnErr("Text only accepts []const u8 or number types, NOT {any}", .{@TypeOf(value)});
                    return Self{ ._elem_type = .Code, ._text = "" };
                },
            };
            const elem_decl = ElementDecl{
                .state_type = _state_type,
                .elem_type = .Code,
                .can_have_children = false,
            };

            const ui_node = LifeCycle.open(elem_decl) orelse {
                Vapor.printlnSrcErr("Could not add component Link to lifecycle {any}\n", .{error.CouldNotAllocate}, @src());
                unreachable;
            };

            return Self{
                ._elem_type = .Code,
                ._text = text,
                ._ui_node = ui_node,
            };
        }

        pub fn Spacer(val: f32) Self {
            const elem_decl = ElementDecl{
                .state_type = _state_type,
                .elem_type = .Spacer,
                .can_have_children = false,
            };

            const ui_node = LifeCycle.open(elem_decl) orelse {
                Vapor.printlnSrcErr("Could not add component Link to lifecycle {any}\n", .{error.CouldNotAllocate}, @src());
                unreachable;
            };

            return Self{
                ._elem_type = .Spacer,
                ._ui_node = ui_node,
                ._size = .hw(.px(val), .percent(100)),
            };
        }

        /// Text does not allocate memory, since we are not using a pointer
        /// make sure the lifetime of the value is long enough
        pub fn Number(value: anytype) Self {
            const elem_decl = ElementDecl{
                .state_type = _state_type,
                .elem_type = .Text,
                .can_have_children = false,
            };

            const ui_node = LifeCycle.open(elem_decl) orelse {
                Vapor.printlnSrcErr("Could not add component Link to lifecycle {any}\n", .{error.CouldNotAllocate}, @src());
                unreachable;
            };

            const text = blk: switch (@typeInfo(@TypeOf(value))) {
                .int => {
                    const number = Vapor.fmtln("{any}", .{value});
                    Vapor.frame_arena.addBytesUsed(number.len);
                    break :blk number;
                },
                .float => {
                    const number = Vapor.fmtln("{any}", .{value});
                    Vapor.frame_arena.addBytesUsed(number.len);
                    break :blk number;
                },
                .@"enum" => {
                    const number = Vapor.fmtln("{s}", .{@tagName(value)});
                    Vapor.frame_arena.addBytesUsed(number.len);
                    break :blk number;
                },
                else => {
                    Vapor.printlnErr("Text only accepts []const u8 or number types, NOT {any}", .{@TypeOf(value)});
                    return Self{ ._elem_type = .Text, ._text = "", ._ui_node = ui_node };
                },
            };

            return Self{
                ._elem_type = .Text,
                ._text = text,
                ._ui_node = ui_node,
            };
        }

        /// Text does not allocate memory, since we are not using a pointer
        /// make sure the lifetime of the value is long enough
        pub fn Text(value: anytype) Self {
            const elem_decl = ElementDecl{
                .state_type = _state_type,
                .elem_type = .Text,
                .can_have_children = false,
            };

            // const ui_node = Vapor.current_ctx.openUnattached(elem_decl) catch unreachable;

            const ui_node = createNode(elem_decl);

            const text = blk: switch (@typeInfo(@TypeOf(value))) {
                .pointer => |ptr_info| {
                    if (ptr_info.size == .one) {
                        // String literal - use directly
                        break :blk value;
                    } else if (ptr_info.size == .slice) {
                        return Self{
                            ._elem_type = .Text,
                            ._text = value,
                            ._ui_node = ui_node,
                            ._persisted_text = true,
                        };
                    }
                },
                .int => {
                    const number = Vapor.fmtln("{any}", .{value});
                    Vapor.frame_arena.addBytesUsed(number.len);
                    break :blk number;
                },
                .float => {
                    const number = Vapor.fmtln("{any}", .{value});
                    Vapor.frame_arena.addBytesUsed(number.len);
                    break :blk number;
                },
                .@"enum" => {
                    const number = Vapor.fmtln("{s}", .{@tagName(value)});
                    Vapor.frame_arena.addBytesUsed(number.len);
                    break :blk number;
                },
                else => {
                    Vapor.printlnErr("Text only accepts []const u8 or number types, NOT {any}", .{@TypeOf(value)});
                    return Self{ ._elem_type = .Text, ._text = "", ._ui_node = ui_node };
                },
            };

            return Self{
                ._elem_type = .Text,
                ._text = text,
                ._ui_node = ui_node,
            };
        }

        pub fn unmanaged(self: *const Self) Self {
            var new_self: Self = self.*;
            new_self._persisted_text = false;
            return new_self;
        }

        pub fn hidden(self: *const Self, hide: bool) Self {
            var new_self: Self = self.*;
            if (!hide) return new_self;
            new_self._flex_type = .hidden;
            return new_self;
        }

        pub fn Html(text: []const u8) Self {
            const elem_decl = ElementDecl{
                .state_type = _state_type,
                .elem_type = .HtmlText,
                .can_have_children = false,
            };
            const ui_node = createNode(elem_decl);
            return Self{ ._elem_type = .HtmlText, ._text = text, ._ui_node = ui_node };
        }

        pub fn TextFmt(comptime fmt: []const u8, args: anytype) Self {
            const allocator = Vapor.arena(.frame);
            const text = std.fmt.allocPrint(allocator, fmt, args) catch |err| {
                Vapor.printlnColor(
                    \\Error formatting text: {any}\n"
                    \\FMT: {s}\n"
                    \\ARGS: {any}\n"
                , .{ err, fmt, args }, .hex("#FF3029"));
                return Self{ ._elem_type = .TextFmt, ._text = "ERROR" };
            };
            Vapor.frame_arena.addBytesUsed(text.len);

            const elem_decl = ElementDecl{
                .state_type = _state_type,
                .elem_type = .TextFmt,
                .can_have_children = false,
            };
            const ui_node = LifeCycle.open(elem_decl) orelse {
                Vapor.printlnSrcErr("Could not add component Link to lifecycle {any}\n", .{error.CouldNotAllocate}, @src());
                unreachable;
            };

            return Self{ ._elem_type = .TextFmt, ._text = text, ._ui_node = ui_node };
        }

        pub fn Graphic(options: struct { src: []const u8 }) Self {
            const elem_decl = ElementDecl{
                .state_type = _state_type,
                .elem_type = .Graphic,
                .can_have_children = false,
            };
            const ui_node = createNode(elem_decl);
            return Self{ ._elem_type = .Graphic, ._href = options.src, ._ui_node = ui_node };
        }

        pub fn Icon(token: *const IconTokens) Self {
            const elem_decl = ElementDecl{
                .state_type = _state_type,
                .elem_type = .Icon,
                .can_have_children = false,
            };
            const ui_node = createNode(elem_decl);
            return Self{ ._elem_type = .Icon, ._href = token.web orelse "", ._ui_node = ui_node };
        }

        pub fn Svg(options: struct { svg: []const u8, override: bool = false }) Self {
            const elem_decl = ElementDecl{
                .elem_type = .Svg,
                .can_have_children = false,
            };

            const ui_node = createNode(elem_decl);

            if (options.svg.len > 2048 and Vapor.build_options.enable_debug and !options.override) {
                Vapor.printlnErr("Svg is too large inlining: {d}B, use Graphic;\nSVG Content:\n{s}...", .{ options.svg.len, options.svg[0..100] });
                return Self{ ._elem_type = .Svg, ._svg = "" };
            }

            return Self{
                ._elem_type = .Svg,
                ._svg = options.svg,
                ._ui_node = ui_node,
            };
        }

        pub fn Image(options: struct { src: []const u8, alt: ?[]const u8 = null }) Self {
            const elem_decl = ElementDecl{
                .state_type = _state_type,
                .elem_type = .Image,
                .can_have_children = false,
            };
            const ui_node = createNode(elem_decl);
            return Self{ ._elem_type = .Image, ._href = options.src, ._alt = options.alt, ._ui_node = ui_node };
        }

        pub fn Anchor(name: []const u8) Self {
            const elem_decl = ElementDecl{ .state_type = _state_type, .elem_type = .Anchor };
            const ui_node = createNode(elem_decl);
            return Self{ ._elem_type = .Anchor, ._ui_node = ui_node, ._anchor = name };
        }

        // Add these methods:

        /// Set full accessibility config
        pub fn a11y(self: *const Self, accessibility: Accessibility) Self {
            var new_self: Self = self.*;
            new_self._accessibility = accessibility;
            return new_self;
        }

        /// Shorthand: just set aria-label
        pub fn ariaLabel(self: *const Self, label: []const u8) Self {
            var new_self: Self = self.*;
            var acc = new_self._accessibility orelse Accessibility{};
            acc.label = label;
            new_self._accessibility = acc;
            return new_self;
        }

        /// Shorthand: set role
        pub fn role(self: *const Self, r: Accessibility.Role) Self {
            var new_self: Self = self.*;
            var acc = new_self._accessibility orelse Accessibility{};
            acc.role = r;
            new_self._accessibility = acc;
            return new_self;
        }

        /// Shorthand: aria-expanded
        pub fn ariaExpanded(self: *const Self, expanded: bool) Self {
            var new_self: Self = self.*;
            var acc = new_self._accessibility orelse Accessibility{};
            acc.expanded = expanded;
            new_self._accessibility = acc;
            return new_self;
        }

        /// Shorthand: aria-selected
        pub fn ariaSelected(self: *const Self, selected: bool) Self {
            var new_self: Self = self.*;
            var acc = new_self._accessibility orelse Accessibility{};
            acc.selected = selected;
            new_self._accessibility = acc;
            return new_self;
        }

        /// Shorthand: aria-controls
        pub fn ariaControls(self: *const Self, uuid: []const u8) Self {
            var new_self: Self = self.*;
            var acc = new_self._accessibility orelse Accessibility{};
            acc.controls = uuid;
            new_self._accessibility = acc;
            return new_self;
        }

        /// Shorthand: aria-activedescendant
        pub fn ariaActiveDescendant(self: *const Self, uuid: ?[]const u8) Self {
            var new_self: Self = self.*;
            var acc = new_self._accessibility orelse Accessibility{};
            acc.active_descendant = uuid;
            new_self._accessibility = acc;
            return new_self;
        }

        /// Shorthand: aria-hidden
        pub fn ariaHidden(self: *const Self, hidden_val: bool) Self {
            var new_self: Self = self.*;
            var acc = new_self._accessibility orelse Accessibility{};
            acc.hidden = hidden_val;
            new_self._accessibility = acc;
            return new_self;
        }

        /// Shorthand: tabindex
        pub fn tabIndex(self: *const Self, index: i16) Self {
            var new_self: Self = self.*;
            var acc = new_self._accessibility orelse Accessibility{};
            acc.tab_index = index;
            new_self._accessibility = acc;
            return new_self;
        }

        pub fn fontStyle(self: *const Self, font_style: types.FontStyle) Self {
            var new_self: Self = self.*;
            var visual = new_self._visual orelse types.Visual{};
            visual.font_style = font_style;
            new_self._visual = visual;
            return new_self;
        }

        pub fn ellipsis(self: *const Self, value: types.Ellipsis) Self {
            if (self._elem_type != .Text and self._elem_type != .TextArea and self._elem_type != .TextField and self._elem_type != .TextFmt) {
                std.log.warn("Ellipsis can only be used on Text, not {any}", .{self._elem_type});
                return self.*;
            }
            var new_self: Self = self.*;
            var visual = new_self._visual orelse types.Visual{};
            visual.ellipsis = value;
            new_self._visual = visual;
            return new_self;
        }

        pub fn fill(self: *const Self, value: types.Color) Self {
            var new_self: Self = self.*;
            var visual = new_self._visual orelse types.Visual{};
            visual.fill = value;
            new_self._visual = visual;
            return new_self;
        }

        pub fn stroke(self: *const Self, value: types.Color) Self {
            var new_self: Self = self.*;
            var visual = new_self._visual orelse types.Visual{};
            visual.stroke = value;
            new_self._visual = visual;
            return new_self;
        }

        pub fn fieldName(self: *const Self, name: []const u8) Self {
            var new_self: Self = self.*;
            new_self._name = name;
            return new_self;
        }

        pub fn inherit(self: *const Self, fields: []const types.StyleFields) Self {
            var new_self: Self = self.*;
            new_self._style_fields = fields;
            return new_self;
        }

        pub fn inheritHover(self: *const Self, fields: []const types.StyleFields) Self {
            var new_self: Self = self.*;
            new_self._hover_style_fields = fields;
            return new_self;
        }

        pub fn bold(self: *const Self) Self {
            var new_self: Self = self.*;
            var visual = new_self._visual orelse types.Visual{};
            visual.font_weight = 700;
            new_self._visual = visual;
            return new_self;
        }

        pub fn whiteSpace(self: *const Self, value: types.WhiteSpace) Self {
            var new_self: Self = self.*;
            var visual = new_self._visual orelse types.Visual{};
            visual.white_space = value;
            new_self._visual = visual;
            return new_self;
        }

        // ============================================================
        // Shared instance methods (available in both modes)
        // ============================================================

        pub fn bind(self: *const Self, value: anytype) Self {
            var new_self: Self = self.*;
            if (self._elem_type != .TextField) {
                Vapor.printlnErr("bindValue only works on TextField", .{});
                return self.*;
            }
            if (@typeInfo(@TypeOf(value)) != .pointer) {
                Vapor.printlnErr("bindValue only works on pointer types", .{});
                return self.*;
            }
            new_self._value = @ptrCast(@alignCast(value));
            return new_self;
        }

        pub fn onFocus(self: *const Self, cb: fn (*Vapor.Event) void) Self {
            var new_self: Self = self.*;
            var element = self._element orelse {
                Vapor.printlnSrcErr("Element is null must bind() first, before setting onChange", .{}, @src());
                unreachable;
            };

            const ui_node = self.getOrCreateNode(&new_self);
            const uuid = ui_node.uuid;
            var onid = hashKey(uuid);
            onid +%= hashKey(Vapor.on_change_hash);
            element.on_focus = cb;
            Vapor.events_callbacks.put(onid, cb) catch |err| {
                Vapor.println("Event Callback Error: {any}\n", .{err});
            };
            return new_self;
        }

        pub fn onBlur(self: *const Self, cb: fn (*Vapor.Event) void) Self {
            var new_self: Self = self.*;
            var element = self._element orelse {
                Vapor.printlnSrcErr("Element is null must bind() first, before setting onChange", .{}, @src());
                unreachable;
            };

            const ui_node = self.getOrCreateNode(&new_self);
            const uuid = ui_node.uuid;
            var onid = hashKey(uuid);
            onid +%= hashKey(Vapor.on_blur_hash);
            element.on_blur = cb;
            Vapor.events_callbacks.put(onid, cb) catch |err| {
                Vapor.println("Event Callback Error: {any}\n", .{err});
            };
            return new_self;
        }

        pub fn onChange(self: *const Self, cb: fn (*Vapor.Event) void) Self {
            var new_self: Self = self.*;

            const ui_node = self.getOrCreateNode(&new_self);
            Vapor.attachEventCallback(ui_node, .input, cb) catch |err| {
                Vapor.println("ONLEAVE: Could not attach event callback {any}\n", .{err});
                unreachable;
            };

            return new_self;
        }

        pub fn inlineStyle(self: *const Self, comptime fmt: []const u8, args: anytype) Self {
            var new_self: Self = self.*;
            const allocator = Vapor.arena(.frame);
            const text = std.fmt.allocPrint(allocator, fmt, args) catch |err| {
                Vapor.printlnColor(
                    \\Error formatting text: {any}\n"
                    \\FMT: {s}\n"
                    \\ARGS: {any}\n"
                , .{ err, fmt, args }, .hex("#FF3029"));
                return new_self;
            };
            Vapor.frame_arena.addBytesUsed(text.len);
            new_self._inlineStyle = text;
            return new_self;
        }

        pub fn inlineStyleStr(self: *const Self, text: []const u8) Self {
            var new_self: Self = self.*;
            new_self._inlineStyle = text;
            return new_self;
        }

        pub fn fontSize(self: *const Self, font_size: u8) Self {
            var new_self: Self = self.*;
            var visual = new_self._visual orelse types.Visual{};
            visual.font_size = font_size;
            new_self._visual = visual;
            return new_self;
        }

        pub fn weight(self: *const Self, value: u16) Self {
            var new_self: Self = self.*;
            var visual: types.Visual = new_self._visual orelse types.Visual{};
            visual.font_weight = value;
            new_self._visual = visual;
            return new_self;
        }

        pub fn fontFamily(self: *const Self, font_family: []const u8) Self {
            var new_self: Self = self.*;
            new_self._font_family = font_family;
            return new_self;
        }

        pub fn onHover(self: *const Self, cb: fn (*Vapor.Event) void) Self {
            var new_self: Self = self.*;

            const ui_node = self.getOrCreateNode(&new_self);
            Vapor.attachEventCallback(ui_node, .pointerenter, cb) catch |err| {
                Vapor.println("ONLEAVE: Could not attach event callback {any}\n", .{err});
                unreachable;
            };

            return new_self;
        }

        pub fn onLeave(self: *const Self, cb: *const fn (*Vapor.Event) void) Self {
            var new_self: Self = self.*;

            const ui_node = self.getOrCreateNode(&new_self);
            Vapor.attachEventCallback(ui_node, .mouseleave, cb) catch |err| {
                Vapor.println("ONLEAVE: Could not attach event callback {any}\n", .{err});
                unreachable;
            };

            return new_self;
        }

        pub fn onEvent(self: *const Self, event: types.EventType, cb: *const fn (*Vapor.Event) void) Self {
            var new_self: Self = self.*;

            const ui_node = self.getOrCreateNode(&new_self);
            Vapor.attachEventCallback(ui_node, event, cb) catch |err| {
                Vapor.println("ONLEAVE: Could not attach event callback {any}\n", .{err});
                unreachable;
            };

            return new_self;
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
            var new_self: Self = self.*;

            const ui_node = self.getOrCreateNode(&new_self);
            const Args = @TypeOf(args);
            const Closure = struct {
                arguments: Args,
                run_node: Vapor.Node = .{ .data = .{ .runFn = runFn, .deinitFn = deinitFn } },
                //
                fn runFn(action: *Vapor.Action) void {
                    const run_node: *Vapor.Node = @fieldParentPtr("data", action);
                    const closure: *@This() = @alignCast(@fieldParentPtr("run_node", run_node));
                    @call(.auto, cb, closure.arguments);
                }
                //
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

            return new_self;
        }

        pub fn onHoverCtx(self: *const Self, cb: anytype, args: anytype) Self {
            var new_self: Self = self.*;

            const ui_node = self.getOrCreateNode(&new_self);
            Vapor.attachEventCtxCallback(ui_node, .mouseenter, cb, args) catch |err| {
                Vapor.println("ONLEAVE: Could not attach event callback {any}\n", .{err});
                unreachable;
            };

            return new_self;
        }

        pub fn onDragStart(self: *const Self, cb: fn (*Vapor.Event) void) Self {
            var new_self: Self = self.*;

            const ui_node = self.getOrCreateNode(&new_self);
            Vapor.attachEventCallback(ui_node, .pointerdown, cb) catch |err| {
                Vapor.println("ONDRAGSTART: Could not attach event callback {any}\n", .{err});
                unreachable;
            };

            return new_self;
        }

        pub fn scroll(self: *const Self, scroll_type: types.Scroll) Self {
            var new_self: Self = self.*;
            new_self._scroll = scroll_type;
            return new_self;
        }

        pub fn createDraggable(self: *const Self, draggable_ptr: *Draggable) *const Self {
            var element = draggable_ptr.element;

            var ui_node = self._ui_node orelse {
                Vapor.printlnSrcErr("Node is null must ref() first, before setting onChange", .{}, @src());
                unreachable;
            };

            ui_node.hooks.created_id = 1;
            element.element_type = self._elem_type;
            element._node_ptr = ui_node;
            draggable_ptr.element = element;

            Vapor.onEndCtx(struct {
                pub fn attachDraggable(draggable: *Draggable) void {
                    draggable.addStartListener();
                }
            }.attachDraggable, .{draggable_ptr});
            return self;
        }

        pub fn id(self: *const Self, element_id: []const u8) Self {
            var new_self: Self = self.*;
            new_self._id = element_id;
            new_self._ui_node.?.uuid = element_id;
            return new_self;
        }

        pub fn anchorSource(self: *const Self, name: []const u8) Self {
            var new_self: Self = self.*;
            new_self._anchor = name;
            return new_self;
        }

        pub fn animationEnter(self: *const Self, animation_tag: ?[]const u8) Self {
            if (animation_tag) |_animation| {
                var new_self: Self = self.*;
                new_self._animation_enter = _animation;
                return new_self;
            }
            return self.*;
        }

        pub fn animation(self: *const Self, animation_tag: ?[]const u8) Self {
            if (animation_tag) |_animation| {
                var new_self: Self = self.*;
                var visual = new_self._visual orelse types.Visual{};
                visual.animation = _animation;
                new_self._visual = visual;
                return new_self;
            }
            return self.*;
        }

        pub fn animationExit(self: *const Self, animation_tag: ?[]const u8) Self {
            var new_self: Self = self.*;
            new_self._animation_exit = animation_tag;
            return new_self;
        }

        pub fn class(self: *const Self, class_name: []const u8) Self {
            var new_self: Self = self.*;
            new_self._class = class_name;
            return new_self;
        }

        pub fn classFmt(self: *const Self, comptime fmt: []const u8, args: anytype) Self {
            var new_self: Self = self.*;
            const allocator = Vapor.arena(.frame);
            const text = std.fmt.allocPrint(allocator, fmt, args) catch |err| {
                Vapor.printlnColor(
                    \\Error formatting text: {any}\n"
                    \\FMT: {s}\n"
                    \\ARGS: {any}\n"
                , .{ err, fmt, args }, .hex("#FF3029"));
                return new_self;
            };
            Vapor.frame_arena.addBytesUsed(text.len);
            new_self._class = text;
            return new_self;
        }

        pub fn transition(self: *const Self, _transition: types.Transition) Self {
            var new_self: Self = self.*;
            new_self._transition = _transition;
            return new_self;
        }

        pub fn transform(self: *const Self, value: ?types.Transform) Self {
            var new_self: Self = self.*;
            var visual = new_self._visual orelse types.Visual{};
            visual.transform = value;
            new_self._visual = visual;
            return new_self;
        }

        pub fn scale(self: *const Self, value: f16) Self {
            var new_self: Self = self.*;
            var visual = new_self._visual orelse types.Visual{};
            visual.transform = .scaleDecimal(value);
            new_self._visual = visual;
            return new_self;
        }

        pub fn ref(self: *const Self, element: *Element) Self {
            var new_self: Self = self.*;

            const ui_node = self.getOrCreateNode(&new_self);
            element.element_type = self._elem_type;
            element._node_ptr = ui_node;
            new_self._element = element;

            const uuid = ui_node.uuid;
            Vapor.element_registry.put(hashKey(uuid), element) catch unreachable;
            return new_self;
        }

        pub fn baseStyle(self: *const Self, style_ptr: *const Vapor.Style) Self {
            var new_self: Self = self.*;
            new_self._style = style_ptr;
            return new_self;
        }

        pub fn interaction(self: *const Self, interactive: types.Interactive) Self {
            var new_self: Self = self.*;
            new_self._interactive = interactive;
            return new_self;
        }

        pub fn textColor(self: *const Self, color: ?Color) Self {
            var new_self: Self = self.*;
            var visual = new_self._visual orelse types.Visual{};
            visual.text_color = color;
            new_self._visual = visual;
            return new_self;
        }

        pub fn font(self: *const Self, font_size: u8, font_weight: ?u16, color: ?Color) Self {
            var new_self: Self = self.*;
            var visual = new_self._visual orelse types.Visual{};
            visual.font_size = font_size;
            visual.font_weight = font_weight;
            visual.text_color = color;
            new_self._visual = visual;
            return new_self;
        }

        pub fn pos(self: *const Self, position: types.Position) Self {
            var new_self: Self = self.*;
            var new_position = new_self._pos orelse types.Position{};
            new_position.top = position.top;
            new_position.right = position.right;
            new_position.bottom = position.bottom;
            new_position.left = position.left;
            new_position.type = position.type;
            new_self._pos = new_position;
            return new_self;
        }

        pub fn zIndex(self: *const Self, z_index: ?i16) Self {
            var new_self: Self = self.*;
            var position = new_self._pos orelse types.Position{};
            position.z_index = z_index;
            new_self._pos = position;
            return new_self;
        }

        pub fn blur(self: *const Self, value: ?u8) Self {
            var new_self: Self = self.*;
            var visual = new_self._visual orelse types.Visual{};
            visual.blur = value;
            new_self._visual = visual;
            return new_self;
        }

        pub fn layout(self: *const Self, value: types.Layout) Self {
            var new_self: Self = self.*;
            new_self._layout = value;
            return new_self;
        }

        pub fn anchorPlacement(self: *const Self, value: types.AnchorPlacement) Self {
            var new_self: Self = self.*;
            new_self._placement = value;
            return new_self;
        }

        pub fn placement(self: *const Self, value: types.AnchorPlacement) Self {
            var new_self: Self = self.*;
            new_self._placement = value;
            return new_self;
        }

        pub fn center(self: *const Self) Self {
            var new_self: Self = self.*;
            new_self._layout = .center;
            return new_self;
        }

        pub fn background(self: *const Self, value: types.Background) Self {
            var new_self: Self = self.*;
            var visual = new_self._visual orelse types.Visual{};
            visual.background = value;
            new_self._visual = visual;
            return new_self;
        }

        pub fn outline(self: *const Self, value: types.Outline) Self {
            var new_self: Self = self.*;
            var visual = new_self._visual orelse types.Visual{};
            visual.outline = value;
            new_self._visual = visual;
            return new_self;
        }

        pub fn shadow(self: *const Self, value: ?types.Shadow) Self {
            if (value == null) return self.*;
            var new_self: Self = self.*;
            var visual = new_self._visual orelse types.Visual{};
            visual.shadow = value;
            new_self._visual = visual;
            return new_self;
        }

        pub fn newShadow(self: *const Self, value: ?Shadow) Self {
            if (value == null) return self.*;
            var new_self: Self = self.*;
            var visual = new_self._visual orelse types.Visual{};
            visual.new_shadow = value.?;
            new_self._visual = visual;
            return new_self;
        }

        pub fn layer(self: *const Self, value: ?types.BackgroundLayer) Self {
            if (value == null) return self.*;
            var new_self: Self = self.*;
            var visual = new_self._visual orelse types.Visual{};
            visual.layer = value;
            new_self._visual = visual;
            return new_self;
        }

        pub fn layers(self: *const Self, value: ?[]const types.BackgroundLayer) Self {
            if (value == null) return self.*;
            var new_self: Self = self.*;
            var visual = new_self._visual orelse types.Visual{};
            visual.layers = value;
            new_self._visual = visual;
            return new_self;
        }

        pub fn gradient(self: *const Self, value: types.Background) Self {
            var new_self: Self = self.*;
            var visual = new_self._visual orelse types.Visual{};
            visual.background = value;
            new_self._visual = visual;
            return new_self;
        }

        pub fn wrap(self: *const Self, value: types.FlexWrap) Self {
            var new_self: Self = self.*;
            new_self._flex_wrap = value;
            return new_self;
        }

        pub fn textDecoration(self: *const Self, value: types.TextDecoration) Self {
            var new_self: Self = self.*;
            var visual = new_self._visual orelse types.Visual{};
            visual.text_decoration = value;
            new_self._visual = visual;
            return new_self;
        }

        pub fn hoverScale(self: *const Self) Self {
            var new_self: Self = self.*;
            var _interactive = new_self._interactive orelse types.Interactive{};
            var _hover = _interactive.hover orelse types.Visual{};
            _hover.transform = .scale();
            _interactive.hover = _hover;
            new_self._interactive = _interactive;
            return new_self;
        }

        pub fn hover(self: *const Self, value: types.Visual) Self {
            var new_self: Self = self.*;
            var _interactive = new_self._interactive orelse types.Interactive{};
            _interactive.hover = value;
            new_self._interactive = _interactive;
            return new_self;
        }

        pub fn hoverBackground(self: *const Self, color: types.Background) Self {
            var new_self: Self = self.*;
            var _interactive = new_self._interactive orelse types.Interactive{};
            var _hover = _interactive.hover orelse types.Visual{};
            _hover.background = color;
            _interactive.hover = _hover;
            new_self._interactive = _interactive;
            return new_self;
        }

        pub fn pointer(self: *const Self) Self {
            var new_self: Self = self.*;
            var visual = new_self._visual orelse types.Visual{};
            visual.cursor = .pointer;
            new_self._visual = visual;
            return new_self;
        }

        pub fn noDecoration(self: *const Self) Self {
            var new_self: Self = self.*;
            var visual = new_self._visual orelse types.Visual{};
            visual.text_decoration = .none;
            new_self._visual = visual;
            return new_self;
        }

        pub fn opacity(self: *const Self, value: f16) Self {
            var new_self: Self = self.*;
            var visual = new_self._visual orelse types.Visual{};
            visual.opacity = value;
            new_self._visual = visual;
            return new_self;
        }

        pub fn hoverText(self: *const Self, color: Color) Self {
            var new_self: Self = self.*;
            var _interactive = new_self._interactive orelse types.Interactive{};
            var _hover = _interactive.hover orelse types.Visual{};
            _hover.text_color = color;
            _interactive.hover = _hover;
            new_self._interactive = _interactive;
            return new_self;
        }

        pub fn spacing(self: *const Self, value: u8) Self {
            var new_self: Self = self.*;
            new_self._child_gap = value;
            const node = self._ui_node orelse {
                Vapor.printlnSrcErr("Node is null", .{}, @src());
                return self.*;
            };
            node.spacing = value;
            return new_self;
        }

        pub fn transformOrigin(self: *const Self, value: types.TransformOrigin) Self {
            var new_self: Self = self.*;
            new_self._transform_origin = value;
            return new_self;
        }

        pub fn padding(self: *const Self, value: types.Padding) Self {
            var new_self: Self = self.*;
            new_self._padding = value;
            return new_self;
        }

        pub fn pl(self: *const Self, value: u8) Self {
            var new_self: Self = self.*;
            if (new_self._padding == null) new_self._padding = .{};
            new_self._padding.?.left = value;
            return new_self;
        }

        pub fn pr(self: *const Self, value: u8) Self {
            var new_self: Self = self.*;
            if (new_self._padding == null) new_self._padding = .{};
            new_self._padding.?.right = value;
            return new_self;
        }

        pub fn pt(self: *const Self, value: u8) Self {
            var new_self: Self = self.*;
            if (new_self._padding == null) new_self._padding = .{};
            new_self._padding.?.top = value;
            return new_self;
        }

        pub fn pb(self: *const Self, value: u8) Self {
            var new_self: Self = self.*;
            if (new_self._padding == null) new_self._padding = .{};
            new_self._padding.?.bottom = value;
            return new_self;
        }

        pub fn mt(self: *const Self, value: i16) Self {
            var new_self: Self = self.*;
            if (new_self._margin == null) new_self._margin = .{};
            new_self._margin.?.top = value;
            return new_self;
        }

        pub fn mb(self: *const Self, value: i16) Self {
            var new_self: Self = self.*;
            if (new_self._margin == null) new_self._margin = .{};
            new_self._margin.?.bottom = value;
            return new_self;
        }

        pub fn ml(self: *const Self, value: i16) Self {
            var new_self: Self = self.*;
            if (new_self._margin == null) new_self._margin = .{};
            new_self._margin.?.left = value;
            return new_self;
        }

        pub fn mr(self: *const Self, value: i16) Self {
            var new_self: Self = self.*;
            if (new_self._margin == null) new_self._margin = .{};
            new_self._margin.?.right = value;
            return new_self;
        }

        pub fn cursor(self: *const Self, value: types.Cursor) Self {
            var new_self: Self = self.*;
            var visual = new_self._visual orelse types.Visual{};
            visual.cursor = value;
            new_self._visual = visual;
            return new_self;
        }

        pub fn margin(self: *const Self, value: types.Margin) Self {
            var new_self: Self = self.*;
            new_self._margin = value;
            return new_self;
        }

        pub fn size(self: *const Self, dim: types.Size) Self {
            var new_self: Self = self.*;
            new_self._size = dim;
            return new_self;
        }

        pub fn hw(self: *const Self, height_value: types.Sizing, width_value: types.Sizing) Self {
            var new_self: Self = self.*;
            if (new_self._size == null) {
                new_self._size = .{ .width = width_value, .height = height_value };
            } else {
                new_self._size.?.width = width_value;
                new_self._size.?.height = height_value;
            }
            return new_self;
        }

        pub fn width(self: *const Self, length: types.Sizing) Self {
            var new_self: Self = self.*;
            if (new_self._size == null) {
                new_self._size = .{ .width = length };
            } else {
                new_self._size.?.width = length;
            }
            return new_self;
        }

        pub fn minWidth(
            self: *const Self,
            min: types.Sizing,
        ) Self {
            var new_self: Self = self.*;

            const sizing: types.Sizing = switch (min.type) {
                .percent => types.Sizing{ .type = .min_percent, .size = min.size },
                .fixed => types.Sizing{ .type = .min_px, .size = min.size },
                else => unreachable,
            };

            if (new_self._size == null) {
                new_self._size = .{ .width = sizing };
            } else {
                new_self._size.?.width = sizing;
            }
            return new_self;
        }

        pub fn maxWidth(
            self: *const Self,
            max: types.Sizing,
        ) Self {
            var new_self: Self = self.*;

            const sizing: types.Sizing = switch (max.type) {
                .percent => types.Sizing{ .type = .max_percent, .size = max.size },
                .fixed => types.Sizing{ .type = .max_px, .size = max.size },
                else => unreachable,
            };

            if (new_self._size == null) {
                new_self._size = .{ .width = sizing };
            } else {
                new_self._size.?.width = sizing;
            }
            return new_self;
        }

        pub fn height(self: *const Self, length: types.Sizing) Self {
            var new_self: Self = self.*;
            if (new_self._size == null) {
                new_self._size = .{ .height = length };
            } else {
                new_self._size.?.height = length;
            }
            return new_self;
        }

        pub fn minHeight(
            self: *const Self,
            min: types.Sizing,
        ) Self {
            var new_self: Self = self.*;

            const sizing: types.Sizing = switch (min.type) {
                .percent => types.Sizing{ .type = .min_percent, .size = min.size },
                .fixed => types.Sizing{ .type = .min_px, .size = min.size },
                else => unreachable,
            };

            if (new_self._size == null) {
                new_self._size = .{ .height = sizing };
            } else {
                new_self._size.?.height = sizing;
            }
            return new_self;
        }

        pub fn maxHeight(
            self: *const Self,
            max: types.Sizing,
        ) Self {
            var new_self: Self = self.*;

            const sizing: types.Sizing = switch (max.type) {
                .percent => types.Sizing{ .type = .max_percent, .size = max.size },
                .fixed => types.Sizing{ .type = .max_px, .size = max.size },
                else => unreachable,
            };

            if (new_self._size == null) {
                new_self._size = .{ .height = sizing };
            } else {
                new_self._size.?.height = sizing;
            }
            return new_self;
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
            var new_self: Self = self.*;
            var visual = new_self._visual orelse types.Visual{};
            visual.border = value;
            new_self._visual = visual;
            return new_self;
        }

        pub fn borderStyle(self: *const Self, value: types.BorderStyle) Self {
            var new_self: Self = self.*;
            var visual = new_self._visual orelse types.Visual{};
            var old_border = visual.border orelse types.BorderGrouped{ .color = null, .thickness = .all(0) };
            old_border.style = value;
            visual.border = old_border;
            new_self._visual = visual;
            return new_self;
        }

        pub fn radius(self: *const Self, value: types.BorderRadius) Self {
            var new_self: Self = self.*;
            var visual = new_self._visual orelse types.Visual{};
            var old_border = visual.border orelse types.BorderGrouped{ .color = null, .thickness = .all(0) };
            old_border.radius = value;
            visual.border = old_border;
            new_self._visual = visual;
            return new_self;
        }

        pub fn duration(self: *const Self, value: u32) Self {
            var new_self: Self = self.*;
            new_self._transition = .{ .duration = value };
            return new_self;
        }

        pub fn direction(self: *const Self, value: types.Direction) Self {
            var new_self: Self = self.*;
            new_self._direction = value;
            self._ui_node.?.direction = value;
            return new_self;
        }

        pub fn listStyle(self: *const Self, value: types.ListStyle) Self {
            var new_self: Self = self.*;
            new_self._list_style = value;
            return new_self;
        }

        // ============================================================
        // Terminal methods with conditional return types
        // ============================================================

        pub fn style(self: *const Self, style_ptr: *const Vapor.Style) Self {
            var new_self: Self = self.*;
            var elem_decl = Vapor.ElementDecl{
                .state_type = _state_type,
                .elem_type = self._elem_type,
                .text = self._text,
                .style = style_ptr,
                .href = self._href,
                .svg = self._svg,
                .alt = self._alt,
                .aria_label = self._aria_label,
                .animation_enter = self._animation_enter,
                .animation_exit = self._animation_exit,
                .name = self._name,
                .inlineStyle = self._inlineStyle,
            };

            if (self._flex_type == .center) {
                var mutable_style = style_ptr.*;
                mutable_style.layout = .center;
                elem_decl.style = &mutable_style;
            } else if (self._flex_type == .stack) {
                var mutable_style = style_ptr.*;
                mutable_style.direction = .column;
                elem_decl.style = &mutable_style;
            }

            if (self._id) |_id| {
                var mutable_style = style_ptr.*;
                mutable_style.id = _id;
                elem_decl.style = &mutable_style;
            }

            if (self._class) |_class| {
                var mutable_style = style_ptr.*;
                mutable_style.style_id = _class;
                elem_decl.style = &mutable_style;
            }

            new_self._used_style = true;
            // Vapor.LifeCycle.configure(elem_decl);
            _ = Vapor.current_ctx.configureByNode(self._ui_node, elem_decl);

            return new_self;
        }

        pub fn styleOld(self: *const Self, style_ptr: *const Vapor.Style) StyleReturnType {
            var elem_decl = Vapor.ElementDecl{
                .state_type = _state_type,
                .elem_type = self._elem_type,
                .text = self._text,
                .style = style_ptr,
                .href = self._href,
                .svg = self._svg,
                .alt = self._alt,
                .aria_label = self._aria_label,
                .animation_enter = self._animation_enter,
                .animation_exit = self._animation_exit,
                .name = self._name,
                .inlineStyle = self._inlineStyle,
            };

            if (self._flex_type == .Center) {
                var mutable_style = style_ptr.*;
                mutable_style.layout = .center;
                elem_decl.style = &mutable_style;
            } else if (self._flex_type == .Stack) {
                var mutable_style = style_ptr.*;
                mutable_style.direction = .column;
                elem_decl.style = &mutable_style;
            }

            if (self._id) |_id| {
                var mutable_style = style_ptr.*;
                mutable_style.id = _id;
                elem_decl.style = &mutable_style;
            }

            if (self._class) |_class| {
                var mutable_style = style_ptr.*;
                mutable_style.style_id = _class;
                elem_decl.style = &mutable_style;
            }

            Vapor.LifeCycle.configure(elem_decl);
            return doClose();
        }

        // pub fn config(self: *const GenericBuilder(.pure, false)) void {}

        pub fn items(self: *const Self, nodes: anytype) void {
            inline for (nodes) |kid| {
                if (@TypeOf(kid) == GenericBuilder(.pure, false)) {
                    var added_node: GenericBuilder(.pure, false) = kid;
                    added_node._ui_node = kid._ui_node;
                    added_node.end();
                    // config(&added_node);
                }
            }

            var mutable_style = Style{};
            if (self._style) |style_ptr| {
                mutable_style = style_ptr.*;
            }
            if (mutable_style.position == null) mutable_style.position = self._pos;
            if (mutable_style.visual != null and self._visual != null) {
                var visual = mutable_style.visual.?;
                const _visual = self._visual.?;

                if (_visual.background != null) visual.background = _visual.background;
                if (_visual.fill != null) visual.fill = _visual.fill;
                if (_visual.stroke != null) visual.stroke = _visual.stroke;
                if (_visual.border != null) visual.border = _visual.border;
                if (_visual.border_radius != null) visual.border_radius = _visual.border_radius;
                if (_visual.border_thickness != null) visual.border_thickness = _visual.border_thickness;
                if (_visual.border_color != null) visual.border_color = _visual.border_color;
                if (_visual.text_color != null) visual.text_color = _visual.text_color;
                if (_visual.font_size != null) visual.font_size = _visual.font_size;
                if (_visual.font_weight != null) visual.font_weight = _visual.font_weight;
                if (_visual.letter_spacing != null) visual.letter_spacing = _visual.letter_spacing;
                if (_visual.line_height != null) visual.line_height = _visual.line_height;
                if (_visual.opacity != null) visual.opacity = _visual.opacity;
                if (_visual.ellipsis != null) visual.ellipsis = _visual.ellipsis;
                if (_visual.shadow != null) visual.shadow = _visual.shadow;
                if (_visual.cursor != null) visual.cursor = _visual.cursor;
                if (_visual.layer != null) visual.layer = _visual.layer;
                if (_visual.layers != null) visual.layers = _visual.layers;
                if (self._edges != null) visual.edges = self._edges;
                mutable_style.visual = visual;
            } else if (self._visual) |_visual| {
                mutable_style.visual = _visual;
                mutable_style.visual.?.edges = self._edges;
            }

            if (mutable_style.interactive != null and self._interactive != null) {
                const interactive = mutable_style.interactive.?;
                const _interactive = self._interactive.?;
                if (interactive.hover != null and _interactive.hover != null) {
                    var visual = interactive.hover.?;
                    const _visual = _interactive.hover.?;
                    if (_visual.background != null) visual.background = _visual.background;
                    if (_visual.fill != null) visual.fill = _visual.fill;
                    if (_visual.stroke != null) visual.stroke = _visual.stroke;
                    if (_visual.border != null) visual.border = _visual.border;
                    if (_visual.border_radius != null) visual.border_radius = _visual.border_radius;
                    if (_visual.border_thickness != null) visual.border_thickness = _visual.border_thickness;
                    if (_visual.border_color != null) visual.border_color = _visual.border_color;
                    if (_visual.text_color != null) visual.text_color = _visual.text_color;
                    if (_visual.font_size != null) visual.font_size = _visual.font_size;
                    if (_visual.font_weight != null) visual.font_weight = _visual.font_weight;
                    if (_visual.letter_spacing != null) visual.letter_spacing = _visual.letter_spacing;
                    if (_visual.line_height != null) visual.line_height = _visual.line_height;
                    if (_visual.opacity != null) visual.opacity = _visual.opacity;
                    if (_visual.ellipsis != null) visual.ellipsis = _visual.ellipsis;
                    if (_visual.shadow != null) visual.shadow = _visual.shadow;
                    if (_visual.cursor != null) visual.cursor = _visual.cursor;
                    if (_visual.layer != null) visual.layer = _visual.layer;
                    if (_visual.layers != null) visual.layers = _visual.layers;
                    if (_visual.animation != null) visual.animation = _visual.animation;
                    if (_visual.animation_name != null) visual.animation_name = _visual.animation_name;
                    mutable_style.interactive.?.hover = visual;
                }
            } else if (self._interactive) |_interactive| {
                mutable_style.interactive = _interactive;
            }

            if (mutable_style.child_gap == null) mutable_style.child_gap = self._child_gap;
            if (mutable_style.transform_origin == null) mutable_style.transform_origin = self._transform_origin;
            if (mutable_style.padding == null) mutable_style.padding = self._padding;
            if (mutable_style.layout != null) {
                if (self._layout) |_layout| {
                    mutable_style.layout = _layout;
                }
            } else {
                mutable_style.layout = self._layout;
            }
            if (mutable_style.placement != null) {
                if (self._placement) |_placement| {
                    mutable_style.placement = _placement;
                }
            } else {
                mutable_style.placement = self._placement;
            }
            if (mutable_style.margin == null) mutable_style.margin = self._margin;
            if (mutable_style.size == null) mutable_style.size = self._size;
            if (mutable_style.transition == null) {
                mutable_style.transition = self._transition;
            }
            if (mutable_style.flex_wrap == null) mutable_style.flex_wrap = self._flex_wrap;
            mutable_style.direction = self._direction;
            if (mutable_style.list_style == null) mutable_style.list_style = self._list_style;
            if (mutable_style.font_family == null) mutable_style.font_family = self._font_family;
            if (mutable_style.scroll == null) mutable_style.scroll = self._scroll;
            if (mutable_style.flex_type == .default) mutable_style.flex_type = self._flex_type;
            // if (mutable_style.layout == null) mutable_style.layout = self._layout;
            // if (mutable_style.direction == .row) mutable_style.direction = self._direction;

            if (self._flex_type == .center) {
                mutable_style.layout = .center;
            } else if (self._flex_type == .stack) {
                mutable_style.direction = .column;
            }

            if (self._id) |_id| {
                mutable_style.id = _id;
            }

            if (self._class) |_class| {
                mutable_style.style_id = _class;
            }

            if (self._anchor) |_anchor| {
                mutable_style.anchor = _anchor;
            }

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
            // return self;
            return Vapor.LifeCycle.close({});
        }

        // children() is only in Builder
        pub fn children(self: *const Self, _: void) void {
            if (self._used_style) return Vapor.LifeCycle.close({});

            var mutable_style = Style{};
            if (self._style) |style_ptr| {
                mutable_style = style_ptr.*;
            }
            if (mutable_style.position == null) mutable_style.position = self._pos;
            if (mutable_style.visual != null and self._visual != null) {
                var visual = mutable_style.visual.?;
                const _visual = self._visual.?;

                if (_visual.background != null) visual.background = _visual.background;
                if (_visual.fill != null) visual.fill = _visual.fill;
                if (_visual.stroke != null) visual.stroke = _visual.stroke;
                if (_visual.border != null) visual.border = _visual.border;
                if (_visual.border_radius != null) visual.border_radius = _visual.border_radius;
                if (_visual.border_thickness != null) visual.border_thickness = _visual.border_thickness;
                if (_visual.border_color != null) visual.border_color = _visual.border_color;
                if (_visual.text_color != null) visual.text_color = _visual.text_color;
                if (_visual.font_size != null) visual.font_size = _visual.font_size;
                if (_visual.font_weight != null) visual.font_weight = _visual.font_weight;
                if (_visual.letter_spacing != null) visual.letter_spacing = _visual.letter_spacing;
                if (_visual.line_height != null) visual.line_height = _visual.line_height;
                if (_visual.opacity != null) visual.opacity = _visual.opacity;
                if (_visual.ellipsis != null) visual.ellipsis = _visual.ellipsis;
                if (_visual.shadow != null) visual.shadow = _visual.shadow;
                if (_visual.cursor != null) visual.cursor = _visual.cursor;
                if (_visual.layer != null) visual.layer = _visual.layer;
                if (_visual.layers != null) visual.layers = _visual.layers;
                if (self._edges != null) visual.edges = self._edges;
                mutable_style.visual = visual;
            } else if (self._visual) |_visual| {
                mutable_style.visual = _visual;
                mutable_style.visual.?.edges = self._edges;
            }

            if (mutable_style.interactive != null and self._interactive != null) {
                const interactive = mutable_style.interactive.?;
                const _interactive = self._interactive.?;
                if (interactive.hover != null and _interactive.hover != null) {
                    var visual = interactive.hover.?;
                    const _visual = _interactive.hover.?;
                    if (_visual.background != null) visual.background = _visual.background;
                    if (_visual.fill != null) visual.fill = _visual.fill;
                    if (_visual.stroke != null) visual.stroke = _visual.stroke;
                    if (_visual.border != null) visual.border = _visual.border;
                    if (_visual.border_radius != null) visual.border_radius = _visual.border_radius;
                    if (_visual.border_thickness != null) visual.border_thickness = _visual.border_thickness;
                    if (_visual.border_color != null) visual.border_color = _visual.border_color;
                    if (_visual.text_color != null) visual.text_color = _visual.text_color;
                    if (_visual.font_size != null) visual.font_size = _visual.font_size;
                    if (_visual.font_weight != null) visual.font_weight = _visual.font_weight;
                    if (_visual.letter_spacing != null) visual.letter_spacing = _visual.letter_spacing;
                    if (_visual.line_height != null) visual.line_height = _visual.line_height;
                    if (_visual.opacity != null) visual.opacity = _visual.opacity;
                    if (_visual.ellipsis != null) visual.ellipsis = _visual.ellipsis;
                    if (_visual.shadow != null) visual.shadow = _visual.shadow;
                    if (_visual.cursor != null) visual.cursor = _visual.cursor;
                    if (_visual.layer != null) visual.layer = _visual.layer;
                    if (_visual.layers != null) visual.layers = _visual.layers;
                    if (_visual.animation != null) visual.animation = _visual.animation;
                    if (_visual.animation_name != null) visual.animation_name = _visual.animation_name;
                    mutable_style.interactive.?.hover = visual;
                }
            } else if (self._interactive) |_interactive| {
                mutable_style.interactive = _interactive;
            }

            if (mutable_style.child_gap == null) mutable_style.child_gap = self._child_gap;
            if (mutable_style.transform_origin == null) mutable_style.transform_origin = self._transform_origin;
            if (mutable_style.padding == null) mutable_style.padding = self._padding;
            if (mutable_style.layout != null) {
                if (self._layout) |_layout| {
                    mutable_style.layout = _layout;
                }
            } else {
                mutable_style.layout = self._layout;
            }
            if (mutable_style.placement != null) {
                if (self._placement) |_placement| {
                    mutable_style.placement = _placement;
                }
            } else {
                mutable_style.placement = self._placement;
            }
            if (mutable_style.margin == null) mutable_style.margin = self._margin;
            if (mutable_style.size == null) mutable_style.size = self._size;
            if (mutable_style.transition == null) {
                mutable_style.transition = self._transition;
            }
            if (mutable_style.flex_wrap == null) mutable_style.flex_wrap = self._flex_wrap;
            mutable_style.direction = self._direction;
            if (mutable_style.list_style == null) mutable_style.list_style = self._list_style;
            if (mutable_style.font_family == null) mutable_style.font_family = self._font_family;
            if (mutable_style.scroll == null) mutable_style.scroll = self._scroll;
            if (mutable_style.flex_type == .default) mutable_style.flex_type = self._flex_type;
            // if (mutable_style.layout == null) mutable_style.layout = self._layout;
            // if (mutable_style.direction == .row) mutable_style.direction = self._direction;

            if (self._flex_type == .center) {
                mutable_style.layout = .center;
            } else if (self._flex_type == .stack) {
                mutable_style.direction = .column;
            }

            if (self._id) |_id| {
                mutable_style.id = _id;
            }

            if (self._class) |_class| {
                mutable_style.style_id = _class;
            }

            if (self._anchor) |_anchor| {
                mutable_style.anchor = _anchor;
            }

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

        pub fn end(self: *const Self) EndReturnType {
            const ui_node = self._ui_node orelse unreachable;
            if (self._used_style) {
                if (ui_node.can_have_children) {
                    return doClose();
                }
                return;
            }

            var mutable_style = Style{};
            if (self._style) |style_ptr| {
                mutable_style = style_ptr.*;
            }
            if (mutable_style.position == null) mutable_style.position = self._pos;
            if (mutable_style.visual != null and self._visual != null) {
                var visual = mutable_style.visual.?;
                const _visual = self._visual.?;

                if (_visual.background != null) visual.background = _visual.background;
                if (_visual.fill != null) visual.fill = _visual.fill;
                if (_visual.stroke != null) visual.stroke = _visual.stroke;
                if (_visual.border != null) visual.border = _visual.border;
                if (_visual.border_radius != null) visual.border_radius = _visual.border_radius;
                if (_visual.border_thickness != null) visual.border_thickness = _visual.border_thickness;
                if (_visual.border_color != null) visual.border_color = _visual.border_color;
                if (_visual.text_color != null) visual.text_color = _visual.text_color;
                if (_visual.font_size != null) visual.font_size = _visual.font_size;
                if (_visual.font_weight != null) visual.font_weight = _visual.font_weight;
                if (_visual.letter_spacing != null) visual.letter_spacing = _visual.letter_spacing;
                if (_visual.line_height != null) visual.line_height = _visual.line_height;
                if (_visual.opacity != null) visual.opacity = _visual.opacity;
                if (_visual.ellipsis != null) visual.ellipsis = _visual.ellipsis;
                if (_visual.shadow != null) visual.shadow = _visual.shadow;
                if (_visual.cursor != null) visual.cursor = _visual.cursor;
                mutable_style.visual = visual;
            } else if (self._visual) |_visual| {
                mutable_style.visual = _visual;
            }

            if (mutable_style.interactive == null) mutable_style.interactive = self._interactive;
            if (mutable_style.child_gap == null) mutable_style.child_gap = self._child_gap;
            if (mutable_style.transform_origin == null) mutable_style.transform_origin = self._transform_origin;
            if (mutable_style.padding == null) mutable_style.padding = self._padding;
            if (mutable_style.flex_type == .default) mutable_style.flex_type = self._flex_type;

            if (mutable_style.layout != null) {
                if (self._layout) |_layout| {
                    mutable_style.layout = _layout;
                }
            } else {
                mutable_style.layout = self._layout;
            }
            if (mutable_style.placement != null) {
                if (self._placement) |_placement| {
                    mutable_style.placement = _placement;
                }
            } else {
                mutable_style.placement = self._placement;
            }
            if (mutable_style.margin == null) mutable_style.margin = self._margin;
            if (mutable_style.size == null) mutable_style.size = self._size;
            if (mutable_style.transition == null) {
                mutable_style.transition = self._transition;
            }
            if (mutable_style.flex_wrap == null) mutable_style.flex_wrap = self._flex_wrap;
            mutable_style.direction = self._direction;
            if (mutable_style.list_style == null) mutable_style.list_style = self._list_style;
            if (mutable_style.font_family == null) mutable_style.font_family = self._font_family;
            if (mutable_style.scroll == null) mutable_style.scroll = self._scroll;
            if (mutable_style.aspect_ratio == null) mutable_style.aspect_ratio = self._aspect_ratio;

            if (self._flex_type == .center) {
                mutable_style.layout = .center;
            } else if (self._flex_type == .stack) {
                mutable_style.direction = .column;
            }

            if (self._id) |_id| {
                mutable_style.id = _id;
            }

            if (self._class) |_class| {
                mutable_style.style_id = _class;
            }

            if (self._anchor) |_anchor| {
                mutable_style.anchor = _anchor;
            }

            var text: ?[]const u8 = self._text;
            if (self._elem_type == .Text and self._persisted_text) {
                const value = self._text.?;
                text = blk: {
                    const uuid = hashKey(self._ui_node.?.uuid);
                    // Runtime slice - persist it
                    const slice: []const u8 = value;

                    if (text_string_table.get(uuid)) |entry| {
                        const old_string = entry.persisted;
                        // Check if content changed (ptr or len different means new data)
                        if (entry.len == slice.len and entry.ptr == slice.ptr) {
                            // Same source, use persisted copy
                            break :blk entry.persisted;
                        }
                        // Content changed, update
                        const new_copy = Vapor.arena(.persist).dupe(u8, slice) catch unreachable;
                        text_string_table.put(uuid, .{
                            .ptr = slice.ptr,
                            .len = slice.len,
                            .persisted = new_copy,
                        }) catch unreachable;
                        defer Vapor.arena(.persist).free(old_string);
                        break :blk new_copy;
                    } else {
                        // New entry
                        const copy = Vapor.arena(.persist).dupe(u8, slice) catch unreachable;
                        text_string_table.put(uuid, .{
                            .ptr = slice.ptr,
                            .len = slice.len,
                            .persisted = copy,
                        }) catch unreachable;
                        break :blk copy;
                    }
                };
            }

            const elem_decl = Vapor.ElementDecl{
                .state_type = _state_type,
                .elem_type = self._elem_type,
                .text = text,
                .style = &mutable_style,
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
            };

            _ = Vapor.current_ctx.configureByNode(self._ui_node, elem_decl);

            if (ui_node.can_have_children) {
                return doClose();
            }
        }

        pub fn getUUID(self: *const Self) []const u8 {
            if (self._ui_node == null) {
                Vapor.printlnSrcErr("getUUID Failed: Node is null", .{}, @src());
                return "";
            }
            return self._ui_node.?.uuid;
        }
    };
}
// Public type aliases that preserve the original API
pub fn Builder(comptime state_type: types.StateType) type {
    return GenericBuilder(state_type, true);
}

pub fn BuilderClose(comptime state_type: types.StateType) type {
    return GenericBuilder(state_type, false);
}
