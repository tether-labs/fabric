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
const Shadow = @import("Shadow.zig");
const Accessibility = @import("Accessibility.zig").Accessibility;
const ComponentBuilder = @import("NewComponent.zig").ComponentBuilder;
const mergeStyles = @import("NewComponent.zig").mergeStyles;
const StyleMergeParams = @import("NewComponent.zig").StyleMergeParams;

// ============================================================
// InertBuilder — deferred component that does NOT register on
// the render stack at construction time.
//
// Same builder API as ComponentBuilder. The difference:
//   ComponentBuilder: createNode() in constructor → immediate stack registration
//   InertBuilder:     no createNode() → stored as pure data → materialized later
//
// Materialization (node creation + stack registration) happens when:
//   .end()         — commit leaf to render tree
//   .children({})  — commit container, run children block, close
//   .items(.{})    — commit container with tuple children, close
//   .materialize() — explicitly register and get back a live ComponentBuilder
//
// Usage:
//   // Store components as data
//   var list = Vapor.persist.Array(InertBuilder);
//   list.append(InertBuilder.Text("Hello").font(16, 500, .palette(.text_color)));
//   list.append(InertBuilder.Stack().spacing(8).background(.hex("#fff")));
//
//   // Render later
//   for (list.items) |item| {
//       item.end();  // node created HERE, not at append time
//   }
//
//   // Or materialize to get a live builder for UUID access etc
//   var live = item.materialize();
//   const uuid = live.getUUID();
// ============================================================

pub const InertBuilder = struct {
    const Self = @This();

    // --- All the same fields as ComponentBuilder, minus _ui_node ---
    _returns_close: bool = true,
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
    _id: ?[]const u8 = null,
    _style: ?*const Vapor.Style = null,
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

    // Deferred event registrations — stored and replayed at materialization
    _deferred_events: ?[]const DeferredEvent = null,

    const DeferredEvent = struct {
        event_type: types.EventType,
        // Opaque closure pointer — created at construction, replayed at materialize
        attach_fn: *const fn (node: *UINode) void,
    };

    // ============================================================
    // Internal helpers
    // ============================================================

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
            .state_type = .pure,
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
        };
    }

    /// Create a live node on the render stack from this inert builder.
    /// Returns the UINode so callers can access UUID, attach events, etc.
    fn registerNode(self: *const Self) *UINode {
        const can_have_children = self._returns_close;
        const ui_node = LifeCycle.open(.{
            .state_type = .pure,
            .elem_type = self._elem_type,
            .can_have_children = can_have_children,
            .text = self._text,
            .level = self._level,
            .href = self._href,
            .aria_label = self._aria_label,
        }) orelse {
            Vapor.printlnSrcErr("InertBuilder: Could not register node on lifecycle {any}\n", .{error.CouldNotAllocate}, @src());
            unreachable;
        };

        // Apply direction directly to node if set (mirrors Stack() behavior)
        if (self._direction) |d| {
            ui_node.direction = d;
        }

        // Apply spacing directly to node if set
        if (self._child_gap) |gap| {
            ui_node.spacing = gap;
        }

        // Apply column count if set
        if (self._column_count) |cc| {
            ui_node.column_count = cc;
        }

        // Replay deferred events
        if (self._deferred_events) |events| {
            for (events) |evt| {
                evt.attach_fn(ui_node);
            }
        }

        return ui_node;
    }

    // ============================================================
    // Constructors — NO createNode, NO LifeCycle.open
    // Just pure data capture.
    // ============================================================

    pub fn Text(value: anytype) Self {
        const text = blk: switch (@typeInfo(@TypeOf(value))) {
            .pointer => |ptr_info| {
                if (ptr_info.size == .one or ptr_info.size == .slice) {
                    return Self{
                        ._elem_type = .Text,
                        ._text = value,
                        ._persisted_text = true,
                        ._returns_close = false,
                    };
                }
                break :blk "";
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
                Vapor.printlnErr("InertBuilder.Text only accepts []const u8 or number types, NOT {any}", .{@TypeOf(value)});
                break :blk "";
            },
        };
        return Self{ ._elem_type = .Text, ._text = text, ._persisted_text = false, ._returns_close = false };
    }

    pub fn TextFmt(comptime fmt: []const u8, args: anytype) Self {
        const allocator = Vapor.arena(.frame);
        const text = std.fmt.allocPrint(allocator, fmt, args) catch {
            return Self{ ._elem_type = .TextFmt, ._text = "ERROR", ._returns_close = false };
        };
        Vapor.frame_arena.addBytesUsed(text.len);
        return Self{ ._elem_type = .TextFmt, ._text = text, ._returns_close = false };
    }

    pub fn Row() Self {
        return Self{ ._elem_type = .FlexBox, ._returns_close = true };
    }

    pub fn Stack() Self {
        return Self{ ._elem_type = .FlexBox, ._flex_type = .stack, ._direction = .column, ._returns_close = true };
    }

    pub fn Center() Self {
        return Self{ ._elem_type = .FlexBox, ._flex_type = .center, ._returns_close = true };
    }

    pub fn Box() Self {
        return Self{ ._elem_type = .FlexBox, ._returns_close = true };
    }

    pub fn Label(text: []const u8) Self {
        return Self{ ._elem_type = .Label, ._text = text, ._returns_close = false };
    }

    pub fn Code(value: anytype) Self {
        const text = blk: switch (@typeInfo(@TypeOf(value))) {
            .pointer => |_| break :blk value,
            .int => break :blk Vapor.fmtln("{any}", .{value}),
            else => {
                Vapor.printlnErr("InertBuilder.Code only accepts []const u8 or number types, NOT {any}", .{@TypeOf(value)});
                break :blk "";
            },
        };
        return Self{ ._elem_type = .Code, ._text = text, ._returns_close = false };
    }

    pub fn Spacer(val: f32) Self {
        return Self{ ._elem_type = .Spacer, ._size = .hw(.px(val), .expand), ._returns_close = false };
    }

    pub fn Icon(token: *const IconTokens) Self {
        return Self{ ._elem_type = .Icon, ._href = token.web orelse "", ._returns_close = false };
    }

    pub fn Image(options: struct { src: []const u8, alt: ?[]const u8 = null }) Self {
        return Self{ ._elem_type = .Image, ._href = options.src, ._alt = options.alt, ._returns_close = false };
    }

    pub fn Graphic(options: struct { src: []const u8 }) Self {
        return Self{ ._elem_type = .Graphic, ._href = options.src, ._returns_close = false };
    }

    pub fn Svg(options: struct { svg: []const u8, override: bool = false }) Self {
        if (options.svg.len > 2048 and Vapor.build_options.enable_debug and !options.override) {
            Vapor.printlnErr("Svg is too large inlining: {d}B, use Graphic;", .{options.svg.len});
            return Self{ ._elem_type = .Svg, ._svg = "", ._returns_close = false };
        }
        return Self{ ._elem_type = .Svg, ._svg = options.svg, ._returns_close = false };
    }

    pub fn Html(text: []const u8) Self {
        return Self{ ._elem_type = .HtmlText, ._text = text, ._returns_close = false };
    }

    pub fn Heading(level: u8, text: []const u8) Self {
        return Self{ ._elem_type = .Heading, ._text = text, ._level = level, ._returns_close = false };
    }

    pub fn Link(options: struct { url: []const u8, aria_label: ?[]const u8 = null }) Self {
        return Self{ ._elem_type = .Link, ._href = options.url, ._aria_label = options.aria_label, ._returns_close = true };
    }

    pub fn Section() Self {
        return Self{ ._elem_type = .Intersection, ._returns_close = true };
    }

    pub fn List() Self {
        return Self{ ._elem_type = .List, ._returns_close = true };
    }

    pub fn ListItem() Self {
        return Self{ ._elem_type = .ListItem, ._returns_close = true };
    }

    pub fn Table() Self {
        return Self{ ._elem_type = .Table, ._returns_close = true };
    }

    pub fn TableRow() Self {
        return Self{ ._elem_type = .TableRow, ._returns_close = true };
    }

    pub fn TableCell() Self {
        return Self{ ._elem_type = .TableCell, ._returns_close = true };
    }

    pub fn TableBody() Self {
        return Self{ ._elem_type = .TableBody, ._returns_close = true };
    }

    pub fn TableHeader() Self {
        return Self{ ._elem_type = .TableHeader, ._returns_close = true };
    }

    pub fn TableHead() Self {
        return Self{ ._elem_type = .TableHead, ._returns_close = true };
    }

    pub fn Anchor(name: []const u8) Self {
        return Self{ ._elem_type = .Anchor, ._anchor = name, ._returns_close = true };
    }

    // ============================================================
    // Chainable style methods — identical signatures to ComponentBuilder
    // All operate on pure data, no side effects.
    // ============================================================

    pub fn font(self: Self, font_size_val: u8, font_weight: ?u16, color: ?Color) Self {
        var n = self;
        var v = n._visual orelse types.Visual{};
        v.font_size = font_size_val;
        v.font_weight = font_weight;
        v.text_color = color;
        n._visual = v;
        return n;
    }

    pub fn fontSize(self: Self, font_size: u8) Self {
        var n = self;
        var v = n._visual orelse types.Visual{};
        v.font_size = font_size;
        n._visual = v;
        return n;
    }

    pub fn fontWeight(self: Self, value: u16) Self {
        var n = self;
        var v = n._visual orelse types.Visual{};
        v.font_weight = value;
        n._visual = v;
        return n;
    }

    pub fn bold(self: Self) Self {
        var n = self;
        var v = n._visual orelse types.Visual{};
        v.font_weight = 700;
        n._visual = v;
        return n;
    }

    pub fn fontFamily(self: Self, font_family: []const u8) Self {
        var n = self;
        n._font_family = font_family;
        return n;
    }

    pub fn textColor(self: Self, color: ?Color) Self {
        var n = self;
        var v = n._visual orelse types.Visual{};
        v.text_color = color;
        n._visual = v;
        return n;
    }

    pub fn fontColor(self: Self, color: ?Color) Self {
        return self.textColor(color);
    }

    pub fn background(self: Self, value: types.Color) Self {
        var n = self;
        var v = n._visual orelse types.Visual{};
        v.background = value;
        n._visual = v;
        return n;
    }

    pub fn opacity(self: Self, value: f16) Self {
        var n = self;
        var v = n._visual orelse types.Visual{};
        v.opacity = value;
        n._visual = v;
        return n;
    }

    pub fn border(self: Self, value: types.BorderGrouped) Self {
        var n = self;
        var v = n._visual orelse types.Visual{};
        v.border = value;
        n._visual = v;
        return n;
    }

    pub fn radius(self: Self, value: types.BorderRadius) Self {
        var n = self;
        var v = n._visual orelse types.Visual{};
        var b = v.border orelse types.BorderGrouped{ .color = null, .thickness = .all(0) };
        b.radius = value;
        v.border = b;
        n._visual = v;
        return n;
    }

    pub fn borderStyle(self: Self, value: types.BorderStyle) Self {
        var n = self;
        var v = n._visual orelse types.Visual{};
        var b = v.border orelse types.BorderGrouped{ .color = null, .thickness = .all(0) };
        b.style = value;
        v.border = b;
        n._visual = v;
        return n;
    }

    pub fn shadow(self: Self, value: ?types.Shadow) Self {
        if (value == null) return self;
        var n = self;
        var v = n._visual orelse types.Visual{};
        if (self._elem_type == .Text or self._elem_type == .TextFmt) {
            v.text_shadow = value;
        } else {
            v.shadow = value;
        }
        n._visual = v;
        return n;
    }

    pub fn newShadow(self: Self, value: ?Shadow) Self {
        if (value == null) return self;
        var n = self;
        var v = n._visual orelse types.Visual{};
        v.new_shadow = value.?;
        n._visual = v;
        return n;
    }

    pub fn layer(self: Self, value: ?types.BackgroundLayer) Self {
        if (value == null) return self;
        var n = self;
        var v = n._visual orelse types.Visual{};
        v.layer = value;
        n._visual = v;
        return n;
    }

    pub fn layers(self: Self, value: ?[]const types.BackgroundLayer) Self {
        if (value == null) return self;
        var n = self;
        var v = n._visual orelse types.Visual{};
        v.layers = value;
        n._visual = v;
        return n;
    }

    pub fn layout(self: Self, value: types.Layout) Self {
        var n = self;
        n._layout = value;
        return n;
    }

    pub fn center(self: Self) Self {
        var n = self;
        n._layout = .center;
        return n;
    }

    pub fn anchorPlacement(self: Self, value: types.AnchorPlacement) Self {
        var n = self;
        n._placement = value;
        return n;
    }

    pub fn placement(self: Self, value: types.AnchorPlacement) Self {
        var n = self;
        n._placement = value;
        return n;
    }

    pub fn spacing(self: Self, value: u8) Self {
        var n = self;
        n._child_gap = value;
        return n;
    }

    pub fn padding(self: Self, value: types.Padding) Self {
        var n = self;
        n._padding = value;
        return n;
    }

    pub fn pl(self: Self, value: u8) Self {
        var n = self;
        if (n._padding == null) n._padding = .{};
        n._padding.?._left = value;
        return n;
    }

    pub fn pr(self: Self, value: u8) Self {
        var n = self;
        if (n._padding == null) n._padding = .{};
        n._padding.?._right = value;
        return n;
    }

    pub fn pt(self: Self, value: u8) Self {
        var n = self;
        if (n._padding == null) n._padding = .{};
        n._padding.?._top = value;
        return n;
    }

    pub fn pb(self: Self, value: u8) Self {
        var n = self;
        if (n._padding == null) n._padding = .{};
        n._padding.?._bottom = value;
        return n;
    }

    pub fn py(self: Self, value: u8) Self {
        var n = self;
        if (n._padding == null) n._padding = .{};
        n._padding.?._top = value;
        n._padding.?._bottom = value;
        return n;
    }

    pub fn px(self: Self, value: u8) Self {
        var n = self;
        if (n._padding == null) n._padding = .{};
        n._padding.?._left = value;
        n._padding.?._right = value;
        return n;
    }

    pub fn margin(self: Self, value: types.Margin) Self {
        var n = self;
        n._margin = value;
        return n;
    }

    pub fn mt(self: Self, value: i16) Self {
        var n = self;
        if (n._margin == null) n._margin = .{};
        n._margin.?.top = value;
        return n;
    }

    pub fn mb(self: Self, value: i16) Self {
        var n = self;
        if (n._margin == null) n._margin = .{};
        n._margin.?.bottom = value;
        return n;
    }

    pub fn ml(self: Self, value: i16) Self {
        var n = self;
        if (n._margin == null) n._margin = .{};
        n._margin.?.left = value;
        return n;
    }

    pub fn mr(self: Self, value: i16) Self {
        var n = self;
        if (n._margin == null) n._margin = .{};
        n._margin.?.right = value;
        return n;
    }

    pub fn my(self: Self, value: i16) Self {
        var n = self;
        if (n._margin == null) n._margin = .{};
        n._margin.?.top = value;
        n._margin.?.bottom = value;
        return n;
    }

    pub fn mx(self: Self, value: i16) Self {
        var n = self;
        if (n._margin == null) n._margin = .{};
        n._margin.?.left = value;
        n._margin.?.right = value;
        return n;
    }

    pub fn size(self: Self, dim: types.Size) Self {
        var n = self;
        n._size = dim;
        return n;
    }

    pub fn hw(self: Self, height_value: types.Sizing, width_value: types.Sizing) Self {
        var n = self;
        if (n._size == null) {
            n._size = .{ .width = width_value, .height = height_value };
        } else {
            n._size.?.width = width_value;
            n._size.?.height = height_value;
        }
        return n;
    }

    pub fn width(self: Self, length: types.Sizing) Self {
        var n = self;
        if (n._size == null) {
            n._size = .{ .width = length };
        } else {
            n._size.?.width = length;
        }
        return n;
    }

    pub fn height(self: Self, length: types.Sizing) Self {
        var n = self;
        if (n._size == null) {
            n._size = .{ .height = length };
        } else {
            n._size.?.height = length;
        }
        return n;
    }

    pub fn minWidth(self: Self, min: types.Sizing) Self {
        var n = self;
        const sizing: types.Sizing = switch (min.type) {
            .percent => .{ .type = .min_percent, .size = min.size },
            .fixed => .{ .type = .min_px, .size = min.size },
            else => unreachable,
        };
        if (n._size == null) n._size = .{ .width = sizing } else n._size.?.width = sizing;
        return n;
    }

    pub fn maxWidth(self: Self, max: types.Sizing) Self {
        var n = self;
        const sizing: types.Sizing = switch (max.type) {
            .percent => .{ .type = .max_percent, .size = max.size },
            .fixed => .{ .type = .max_px, .size = max.size },
            else => unreachable,
        };
        if (n._size == null) n._size = .{ .width = sizing } else n._size.?.width = sizing;
        return n;
    }

    pub fn minHeight(self: Self, min: types.Sizing) Self {
        var n = self;
        const sizing: types.Sizing = switch (min.type) {
            .percent => .{ .type = .min_percent, .size = min.size },
            .fixed => .{ .type = .min_px, .size = min.size },
            else => unreachable,
        };
        if (n._size == null) n._size = .{ .height = sizing } else n._size.?.height = sizing;
        return n;
    }

    pub fn maxHeight(self: Self, max: types.Sizing) Self {
        var n = self;
        const sizing: types.Sizing = switch (max.type) {
            .percent => .{ .type = .max_percent, .size = max.size },
            .fixed => .{ .type = .max_px, .size = max.size },
            else => unreachable,
        };
        if (n._size == null) n._size = .{ .height = sizing } else n._size.?.height = sizing;
        return n;
    }

    pub fn pos(self: Self, position: types.Position) Self {
        var n = self;
        n._pos = position;
        return n;
    }

    pub fn zIndex(self: Self, z_index: ?i16) Self {
        var n = self;
        var p = n._pos orelse types.Position{};
        p.z_index = z_index;
        n._pos = p;
        return n;
    }

    pub fn scroll(self: Self, scroll_type: types.Scroll) Self {
        var n = self;
        n._scroll = scroll_type;
        return n;
    }

    pub fn wrap(self: Self, value: types.FlexWrap) Self {
        var n = self;
        n._flex_wrap = value;
        return n;
    }

    pub fn direction(self: Self, value: types.Direction) Self {
        var n = self;
        n._direction = value;
        return n;
    }

    pub fn transition(self: Self, _transition: types.Transition) Self {
        var n = self;
        n._transition = _transition;
        return n;
    }

    pub fn duration(self: Self, value: u32) Self {
        var n = self;
        n._transition = .{ .duration = value };
        return n;
    }

    pub fn hidden(self: Self, hide: bool) Self {
        var n = self;
        if (hide) n._flex_type = .hidden;
        return n;
    }

    pub fn pointer(self: Self) Self {
        var n = self;
        var v = n._visual orelse types.Visual{};
        v.cursor = .pointer;
        n._visual = v;
        return n;
    }

    pub fn cursor(self: Self, value: types.Cursor) Self {
        var n = self;
        var v = n._visual orelse types.Visual{};
        v.cursor = value;
        n._visual = v;
        return n;
    }

    pub fn textDecoration(self: Self, value: types.TextDecoration) Self {
        var n = self;
        var v = n._visual orelse types.Visual{};
        v.text_decoration = value;
        n._visual = v;
        return n;
    }

    pub fn noDecoration(self: Self) Self {
        var n = self;
        var v = n._visual orelse types.Visual{};
        v.text_decoration = .none;
        n._visual = v;
        return n;
    }

    pub fn ellipsis(self: Self, value: types.Ellipsis) Self {
        if (self._elem_type != .Text and self._elem_type != .TextArea and self._elem_type != .TextField and self._elem_type != .TextFmt) {
            std.log.warn("Ellipsis can only be used on Text, not {any}", .{self._elem_type});
            return self;
        }
        var n = self;
        var v = n._visual orelse types.Visual{};
        v.ellipsis = value;
        n._visual = v;
        return n;
    }

    pub fn whiteSpace(self: Self, value: types.WhiteSpace) Self {
        var n = self;
        var v = n._visual orelse types.Visual{};
        v.white_space = value;
        n._visual = v;
        return n;
    }

    pub fn fontStyle(self: Self, font_style: types.FontStyle) Self {
        var n = self;
        var v = n._visual orelse types.Visual{};
        v.font_style = font_style;
        n._visual = v;
        return n;
    }

    pub fn fill(self: Self, value: types.Color) Self {
        var n = self;
        var v = n._visual orelse types.Visual{};
        v.fill = value;
        n._visual = v;
        return n;
    }

    pub fn stroke(self: Self, value: types.Color) Self {
        var n = self;
        var v = n._visual orelse types.Visual{};
        v.stroke = value;
        n._visual = v;
        return n;
    }

    pub fn transform(self: Self, value: ?types.Transform) Self {
        var n = self;
        var v = n._visual orelse types.Visual{};
        v.transform = value;
        n._visual = v;
        return n;
    }

    pub fn scale(self: Self, value: f16) Self {
        var n = self;
        var v = n._visual orelse types.Visual{};
        v.transform = .scaleDecimal(value);
        n._visual = v;
        return n;
    }

    pub fn blur(self: Self, value: ?u8) Self {
        var n = self;
        var v = n._visual orelse types.Visual{};
        v.blur = value;
        n._visual = v;
        return n;
    }

    pub fn gradient(self: Self, value: types.Background) Self {
        var n = self;
        var v = n._visual orelse types.Visual{};
        v.background = value;
        n._visual = v;
        return n;
    }

    pub fn hover(self: Self, value: types.Visual) Self {
        var n = self;
        var i = n._interactive orelse types.Interactive{};
        i.hover = value;
        n._interactive = i;
        return n;
    }

    pub fn hoverBackground(self: Self, color: types.Color) Self {
        var n = self;
        var i = n._interactive orelse types.Interactive{};
        var h = i.hover orelse types.Visual{};
        h.background = color;
        i.hover = h;
        n._interactive = i;
        return n;
    }

    pub fn hoverText(self: Self, color: Color) Self {
        var n = self;
        var i = n._interactive orelse types.Interactive{};
        var h = i.hover orelse types.Visual{};
        h.text_color = color;
        i.hover = h;
        n._interactive = i;
        return n;
    }

    pub fn hoverScale(self: Self) Self {
        var n = self;
        var i = n._interactive orelse types.Interactive{};
        var h = i.hover orelse types.Visual{};
        h.transform = .scale();
        i.hover = h;
        n._interactive = i;
        return n;
    }

    pub fn interaction(self: Self, interactive: types.Interactive) Self {
        var n = self;
        n._interactive = interactive;
        return n;
    }

    pub fn animationEnter(self: Self, animation_tag: ?[]const u8) Self {
        if (animation_tag) |a| {
            var n = self;
            n._animation_enter = a;
            return n;
        }
        return self;
    }

    pub fn animation(self: Self, animation_tag: ?[]const u8) Self {
        if (animation_tag) |a| {
            var n = self;
            var v = n._visual orelse types.Visual{};
            v.animation = a;
            n._visual = v;
            return n;
        }
        return self;
    }

    pub fn animationExit(self: Self, animation_tag: ?[]const u8) Self {
        var n = self;
        n._animation_exit = animation_tag;
        return n;
    }

    pub fn style(self: Self, style_ptr: *const Vapor.Style) Self {
        var n = self;
        n._style = style_ptr;
        return n;
    }

    pub fn baseStyle(self: Self, style_ptr: *const Vapor.Style) Self {
        var n = self;
        n._style = style_ptr;
        return n;
    }

    pub fn class(self: Self, class_name: []const u8) Self {
        var n = self;
        n._class = class_name;
        return n;
    }

    pub fn id(self: Self, element_id: []const u8) Self {
        var n = self;
        n._id = element_id;
        return n;
    }

    pub fn fieldName(self: Self, name: []const u8) Self {
        var n = self;
        n._name = name;
        return n;
    }

    pub fn anchorSource(self: Self, name: []const u8) Self {
        var n = self;
        n._anchor = name;
        return n;
    }

    pub fn edges(self: Self, edges_tag: ?[]const u8) Self {
        if (edges_tag) |_edges| {
            var n = self;
            n._edges = _edges;
            return n;
        }
        return self;
    }

    pub fn aspectRatio(self: Self, ratio: types.AspectRatio) Self {
        var n = self;
        n._aspect_ratio = ratio;
        return n;
    }

    pub fn listStyle(self: Self, value: types.ListStyle) Self {
        var n = self;
        n._list_style = value;
        return n;
    }

    pub fn transformOrigin(self: Self, value: types.TransformOrigin) Self {
        var n = self;
        n._transform_origin = value;
        return n;
    }

    pub fn inherit(self: Self, fields: []const types.StyleFields) Self {
        var n = self;
        n._style_fields = fields;
        return n;
    }

    pub fn inheritHover(self: Self, fields: []const types.StyleFields) Self {
        var n = self;
        n._hover_style_fields = fields;
        return n;
    }

    pub fn inlineStyle(self: Self, comptime fmt: []const u8, args: anytype) Self {
        var n = self;
        const allocator = Vapor.arena(.frame);
        const text = std.fmt.allocPrint(allocator, fmt, args) catch return n;
        Vapor.frame_arena.addBytesUsed(text.len);
        n._inlineStyle = text;
        return n;
    }

    pub fn inlineStyleStr(self: Self, text: []const u8) Self {
        var n = self;
        n._inlineStyle = text;
        return n;
    }

    pub fn columns(self: Self, column_count: u8) Self {
        var n = self;
        n._column_count = column_count;
        return n;
    }

    pub fn unmanaged(self: Self) Self {
        var n = self;
        n._persisted_text = false;
        return n;
    }

    // Accessibility
    pub fn a11y(self: Self, accessibility: Accessibility) Self {
        var n = self;
        n._accessibility = accessibility;
        return n;
    }

    pub fn ariaLabel(self: Self, label_text: []const u8) Self {
        var n = self;
        var acc = n._accessibility orelse Accessibility{};
        acc.label = label_text;
        n._accessibility = acc;
        return n;
    }

    pub fn role(self: Self, r: Accessibility.Role) Self {
        var n = self;
        var acc = n._accessibility orelse Accessibility{};
        acc.role = r;
        n._accessibility = acc;
        return n;
    }

    pub fn ariaExpanded(self: Self, expanded: bool) Self {
        var n = self;
        var acc = n._accessibility orelse Accessibility{};
        acc.expanded = expanded;
        n._accessibility = acc;
        return n;
    }

    pub fn ariaSelected(self: Self, selected: bool) Self {
        var n = self;
        var acc = n._accessibility orelse Accessibility{};
        acc.selected = selected;
        n._accessibility = acc;
        return n;
    }

    pub fn ariaControls(self: Self, uuid: []const u8) Self {
        var n = self;
        var acc = n._accessibility orelse Accessibility{};
        acc.controls = uuid;
        n._accessibility = acc;
        return n;
    }

    pub fn ariaActiveDescendant(self: Self, uuid: ?[]const u8) Self {
        var n = self;
        var acc = n._accessibility orelse Accessibility{};
        acc.active_descendant = uuid;
        n._accessibility = acc;
        return n;
    }

    pub fn ariaHidden(self: Self, hidden_val: bool) Self {
        var n = self;
        var acc = n._accessibility orelse Accessibility{};
        acc.hidden = hidden_val;
        n._accessibility = acc;
        return n;
    }

    pub fn tabIndex(self: Self, index: i16) Self {
        var n = self;
        var acc = n._accessibility orelse Accessibility{};
        acc.tab_index = index;
        n._accessibility = acc;
        return n;
    }

    // ============================================================
    // Terminal methods — these MATERIALIZE the node
    // ============================================================

    /// Materialize this inert builder into a live ComponentBuilder.
    /// Registers the node on the render stack and returns a ComponentBuilder
    /// with the live UINode attached. Use this when you need the UUID
    /// or need to attach runtime events before committing.
    pub fn materialize(self: *const Self) ComponentBuilder {
        const ui_node = self.registerNode();

        const live = ComponentBuilder{
            ._elem_type = self._elem_type,
            ._returns_close = self._returns_close,
            ._level = self._level,
            ._video = self._video,
            ._font_family = self._font_family,
            ._value = self._value,
            ._flex_type = self._flex_type,
            ._text = self._text,
            ._href = self._href,
            ._alt = self._alt,
            ._svg = self._svg,
            ._aria_label = self._aria_label,
            ._ui_node = ui_node,
            ._id = self._id,
            ._style = self._style,
            ._animation_enter = self._animation_enter,
            ._animation_exit = self._animation_exit,
            ._name = self._name,
            ._used_style = self._used_style,
            ._pos = self._pos,
            ._padding = self._padding,
            ._layout = self._layout,
            ._placement = self._placement,
            ._margin = self._margin,
            ._size = self._size,
            ._child_gap = self._child_gap,
            ._visual = self._visual,
            ._text_decoration = self._text_decoration,
            ._flex_wrap = self._flex_wrap,
            ._interactive = self._interactive,
            ._transition = self._transition,
            ._direction = self._direction,
            ._list_style = self._list_style,
            ._class = self._class,
            ._scroll = self._scroll,
            ._transform_origin = self._transform_origin,
            ._inlineStyle = self._inlineStyle,
            ._style_fields = self._style_fields,
            ._hover_style_fields = self._hover_style_fields,
            ._anchor = self._anchor,
            ._aspect_ratio = self._aspect_ratio,
            ._persisted_text = self._persisted_text,
            ._accessibility = self._accessibility,
            ._column_count = self._column_count,
            ._edges = self._edges,
        };

        // Apply ID override to live node if set
        if (self._id) |element_id| {
            ui_node.uuid = element_id;
        }

        return live;
    }

    /// Commit this inert component to the render tree as a leaf.
    /// Equivalent to ComponentBuilder.end() but handles node creation first.
    pub fn end(self: *const Self) void {
        const ui_node = self.registerNode();

        var mutable_style = mergeStyles(self.getStyleMergeParams(false, true));

        var text: ?[]const u8 = self._text;
        if (self._elem_type == .Text and self._persisted_text) {
            text = @import("NewComponent.zig").persistText(ui_node, self._text);
        }

        const elem_decl = self.makeElemDecl(text, &mutable_style);
        _ = Vapor.current_ctx.configureByNode(ui_node, elem_decl);

        if (ui_node.can_have_children) LifeCycle.close({});
    }

    // /// Commit as a container, execute children block, then close.
    // /// Equivalent to ComponentBuilder.children() but handles node creation first.
    // /// MUST BE CALLLED AFTER MATERIALIZE
    // pub fn children(self: *const Self, _: void) void {
    //     // _ = self.registerNode();
    //
    //     var mutable_style = mergeStyles(self.getStyleMergeParams(true, false));
    //     const elem_decl = self.makeElemDecl(self._text, &mutable_style);
    //
    //     Vapor.LifeCycle.configure(elem_decl);
    //     return Vapor.LifeCycle.close({});
    // }

    /// Commit as a container with tuple children.
    /// Equivalent to ComponentBuilder.items() but handles node creation first.
    /// MUST BE CALLLED AFTER MATERIALIZE
    pub fn items(self: *const Self, nodes: anytype) void {
        _ = self.registerNode();

        // Materialize and end each child
        inline for (nodes) |kid| {
            std.log.info("InertBuilder.items {any}", .{@TypeOf(kid)});
            if (@TypeOf(kid) == InertBuilder) {
                kid.end();
            } else if (@TypeOf(kid) == ComponentBuilder) {
                var added_node: ComponentBuilder = kid;
                added_node._ui_node = kid._ui_node;
                added_node.end();
            }
        }

        var mutable_style = mergeStyles(self.getStyleMergeParams(true, false));
        const elem_decl = self.makeElemDecl(self._text, &mutable_style);

        Vapor.LifeCycle.configure(elem_decl);
        return Vapor.LifeCycle.close({});
    }

    // ============================================================
    // Conversion — create an inert copy from a live ComponentBuilder
    // ============================================================

    /// Capture a live ComponentBuilder's configuration as an inert builder.
    /// The live node is NOT referenced — this creates a clean, storable copy.
    pub fn fromLive(live: *const ComponentBuilder) Self {
        return Self{
            ._elem_type = live._elem_type,
            ._returns_close = live._returns_close,
            ._level = live._level,
            ._video = live._video,
            ._font_family = live._font_family,
            ._value = live._value,
            ._flex_type = live._flex_type,
            ._text = live._text,
            ._href = live._href,
            ._alt = live._alt,
            ._svg = live._svg,
            ._aria_label = live._aria_label,
            ._id = live._id,
            ._style = live._style,
            ._animation_enter = live._animation_enter,
            ._animation_exit = live._animation_exit,
            ._name = live._name,
            ._used_style = false,
            ._pos = live._pos,
            ._padding = live._padding,
            ._layout = live._layout,
            ._placement = live._placement,
            ._margin = live._margin,
            ._size = live._size,
            ._child_gap = live._child_gap,
            ._visual = live._visual,
            ._text_decoration = live._text_decoration,
            ._flex_wrap = live._flex_wrap,
            ._interactive = live._interactive,
            ._transition = live._transition,
            ._direction = live._direction,
            ._list_style = live._list_style,
            ._class = live._class,
            ._scroll = live._scroll,
            ._transform_origin = live._transform_origin,
            ._inlineStyle = live._inlineStyle,
            ._style_fields = live._style_fields,
            ._hover_style_fields = live._hover_style_fields,
            ._anchor = live._anchor,
            ._aspect_ratio = live._aspect_ratio,
            ._persisted_text = live._persisted_text,
            ._accessibility = live._accessibility,
            ._column_count = live._column_count,
            ._edges = live._edges,
        };
    }
};
