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
const Edges = @import("Edges.zig").Edges;
const GenericBuilder = @import("NewComponent.zig").GenericBuilder;
const serializeArgs = utils.serializeArgs;

pub fn Builder(comptime state_type: types.StateType) type {
    return struct {
        const Self = @This();
        const _state_type: types.StateType = state_type;

        _level: ?u8 = null,

        _elem_type: Vapor.ElementType,
        _aria_label: ?[]const u8 = null,
        _on_press: ?*const fn () void = null,
        _ui_node: ?*UINode = null,
        _id: ?[]const u8 = null,
        _style: ?*const Vapor.Style = null,
        _element: ?*Element = null,

        _animation_enter: ?[]const u8 = null,
        _animation_exit: ?[]const u8 = null,

        // Style props
        _pos: ?types.Position = null,
        _padding: ?types.Padding = null,
        _layout: ?types.Layout = null,
        _margin: ?types.Margin = null,
        _size: ?types.Size = null,
        _child_gap: ?u8 = null,
        _visual: ?types.Visual = null,
        _text_decoration: ?types.TextDecoration = null,
        _flex_wrap: ?types.FlexWrap = null,
        _interactive: ?types.Interactive = null,
        _transition: ?types.Transition = null,
        _direction: types.Direction = .row,
        _class: ?[]const u8 = null,
        _scroll: ?types.Scroll = null,
        _transform_origin: ?types.TransformOrigin = null,
        _inlineStyle: ?[]const u8 = null,
        _accessibility: ?Accessibility = null,
        _used_style: bool = false,
        _flex_type: types.FlexType = .flex,

        // In your component builder (e.g., ButtonBuilder.zig or Div builder)

        _edges: ?[]const u8 = null,

        pub fn edges(self: *const Self, edges_tag: ?[]const u8) Self {
            if (edges_tag) |_edges| {
                var new_self: Self = self.*;
                new_self._edges = _edges;
                return new_self;
            }
            return self.*;
        }

        pub fn Button(click_fn: ?*const fn () void) Self {
            const elem_decl = ElementDecl{
                .elem_type = .Button,
            };
            const ui_node = LifeCycle.open(elem_decl) orelse {
                Vapor.printlnSrcErr("Could not add component Link to lifecycle {any}\n", .{error.CouldNotAllocate}, @src());
                unreachable;
            };

            return Self{
                ._elem_type = .Button,
                ._ui_node = ui_node,
                ._on_press = click_fn,
            };
        }

        pub fn SubmitButton() Self {
            const elem_decl = ElementDecl{
                .elem_type = .SubmitButton,
            };
            const ui_node = LifeCycle.open(elem_decl) orelse {
                Vapor.printlnSrcErr("Could not add component Link to lifecycle {any}\n", .{error.CouldNotAllocate}, @src());
                unreachable;
            };

            return Self{
                ._elem_type = .SubmitButton,
                ._ui_node = ui_node,
            };
        }

        const TapType = enum(u8) {
            onPress,
            onRelease,
            onClick,
            doubleClick,
        };

        // pub fn Tap(func: anytype, args: anytype, tap_type: TapType) Self {
        //     const elem_decl = ElementDecl{
        //         .state_type = _state_type,
        //         .elem_type = .Tap,
        //     };
        //
        //     const ui_node = LifeCycle.open(elem_decl) orelse {
        //         Vapor.printlnSrcErr("LifeCycle open could not allocate {any}\n", .{error.CouldNotAllocate}, @src());
        //         unreachable;
        //     };
        //
        //     Vapor.attachEventCtxCallback(ui_node, , func, ctx) catch |err| {
        //         Vapor.println("OnEventCtx: Could not attach event callback {any}\n", .{err});
        //         unreachable;
        //     };
        //     return self;
        //
        //     const Args = @TypeOf(args);
        //     const Closure = struct {
        //         arguments: Args,
        //         run_node: Vapor.Node = .{ .data = .{ .runFn = runFn, .deinitFn = deinitFn } },
        //         fn runFn(action: *Vapor.Action) void {
        //             const run_node: *Vapor.Node = @fieldParentPtr("data", action);
        //             const closure: *@This() = @alignCast(@fieldParentPtr("run_node", run_node));
        //             @call(.auto, func, closure.arguments);
        //         }
        //         fn deinitFn(_: *Vapor.Node) void {
        //             // _ = @alignCast(@fieldParentPtr("run_node", node));
        //             // Vapor.allocator_global.destroy(closure);
        //         }
        //     };
        //
        //     const closure = Vapor.arena(.frame).create(Closure) catch |err| {
        //         println("Error could not create closure {any}\n ", .{err});
        //         unreachable;
        //     };
        //     closure.* = .{
        //         .arguments = args,
        //     };
        //
        //     Vapor.ctx_callback_registry.put(hashKey(ui_node.uuid), &closure.run_node) catch |err| {
        //         println("Button Function Registry {any}\n", .{err});
        //         unreachable;
        //     };
        //
        //     return Self{ ._elem_type = .CtxButton, ._ui_node = ui_node };
        // }

        pub fn CtxButton(func: anytype, args: anytype) Self {
            const elem_decl = ElementDecl{
                .state_type = _state_type,
                .elem_type = .CtxButton,
            };

            const ui_node = LifeCycle.open(elem_decl) orelse {
                Vapor.printlnSrcErr("LifeCycle open could not allocate {any}\n", .{error.CouldNotAllocate}, @src());
                unreachable;
            };

            const Args = @TypeOf(args);
            const Closure = struct {
                id: []const u8,
                arguments: Args,
                run_node: Vapor.Node = .{ .data = .{ .runFn = runFn, .deinitFn = deinitFn, .argsFn = argsFn } },
                fn runFn(action: *Vapor.Action) void {
                    const run_node: *Vapor.Node = @fieldParentPtr("data", action);
                    const closure: *@This() = @alignCast(@fieldParentPtr("run_node", run_node));
                    @call(.auto, func, closure.arguments);

                    Vapor.trace_buffer.push(.{
                        .timestamp = std.time.microTimestamp(),
                        .event_type = .click,
                        .element_id = Vapor.allocator_global.dupe(u8, closure.id) catch "<failed>",
                        .serialized_args = serializeArgs(Vapor.arena(.persist), closure.arguments, .{}) catch "<failed>",
                    });
                }
                fn argsFn(action: *Vapor.Action) []const u8 {
                    const run_node: *Vapor.Node = @fieldParentPtr("data", action);
                    const closure: *@This() = @alignCast(@fieldParentPtr("run_node", run_node));
                    return serializeArgs(Vapor.arena(.frame), closure.arguments, .{}) catch
                        "\"<serialization failed>\"";
                }
                fn deinitFn(_: *Vapor.Node) void {}
            };

            const closure = Vapor.arena(.frame).create(Closure) catch |err| {
                println("Error could not create closure {any}\n ", .{err});
                unreachable;
            };
            closure.* = .{
                .id = ui_node.uuid,
                .arguments = args,
            };

            Vapor.ctx_callback_registry.put(hashKey(ui_node.uuid), &closure.run_node) catch |err| {
                println("Button Function Registry {any}\n", .{err});
                unreachable;
            };

            return Self{ ._elem_type = .CtxButton, ._ui_node = ui_node };
        }

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

            const ui_node = self._ui_node orelse {
                Vapor.printlnSrcErr("Node is null must ref() first, before setting onChange", .{}, @src());
                unreachable;
            };

            switch (self._text_field_type) {
                .string => {
                    if (@TypeOf(value.*) != []const u8) {
                        Vapor.printlnErr("bindValue and TextField type mismatch", .{});
                        return self.*;
                    }
                    Vapor.attachEventCtxCallback(ui_node, .input, struct {
                        pub fn updateText(value_opaque: *anyopaque, evt: *Vapor.Event) void {
                            const value_type: *[]const u8 = @ptrCast(@alignCast(value_opaque));
                            value_type.* = evt.text();
                            Vapor.print("No onChange updateText: {s}\n", .{value_type.*});
                        }
                    }.updateText, value) catch |err| {
                        Vapor.println("bindValue: Could not attach event callback {any}\n", .{err});
                        unreachable;
                    };
                },
                .int => {
                    if (@TypeOf(value.*) != i32) {
                        Vapor.printlnErr("bindValue and TextField type mismatch", .{});
                        return self.*;
                    }
                },
                .float => {
                    if (@TypeOf(value.*) != f32) {
                        Vapor.printlnErr("bindValue and TextField type mismatch", .{});
                        return self.*;
                    }
                },
                else => {
                    Vapor.printlnErr("NOT IMPLEMENTED", .{});
                    return self.*;
                },
            }
            new_self._value = @ptrCast(@alignCast(value));

            return new_self;
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

        pub fn onFocus(self: *const Self, cb: fn (*Vapor.Event) void) Self {
            var new_self: Self = self.*;
            var element = self._element orelse {
                Vapor.printlnSrcErr("Element is null must bind() first, before setting onChange", .{}, @src());
                unreachable;
            };

            const ui_node = self._ui_node orelse blk: {
                const ui_node = LifeCycle.open(ElementDecl{
                    .state_type = _state_type,
                    ._elem_type = self._elem_type,
                }) orelse {
                    Vapor.printlnSrcErr("Node is null", .{}, @src());
                    unreachable;
                };
                new_self._ui_node = ui_node;

                break :blk ui_node;
            };

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

            const ui_node = self._ui_node orelse blk: {
                const ui_node = LifeCycle.open(ElementDecl{
                    .state_type = _state_type,
                    ._elem_type = self._elem_type,
                }) orelse {
                    Vapor.printlnSrcErr("Node is null", .{}, @src());
                    unreachable;
                };
                new_self._ui_node = ui_node;

                break :blk ui_node;
            };

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

            const ui_node = self._ui_node orelse blk: {
                const ui_node = LifeCycle.open(ElementDecl{
                    .state_type = _state_type,
                    .elem_type = self._elem_type,
                }) orelse {
                    Vapor.printlnSrcErr("Node is null", .{}, @src());
                    unreachable;
                };
                new_self._ui_node = ui_node;

                break :blk ui_node;
            };

            // If we have a binded value we instead create a wrapper ctx around the cb passed in
            // this way we can update the binded values from the callback and call the developer's
            // cb with the updated value
            if (self._value) |value| {
                switch (self._text_field_type) {
                    .string => {
                        Vapor.attachEventCtxCallback(ui_node, .input, struct {
                            pub fn updateText(value_opaque: *anyopaque, evt: *Vapor.Event) void {
                                const value_type: *[]const u8 = @ptrCast(@alignCast(value_opaque));
                                value_type.* = evt.text();
                                Vapor.print("updateText: {s}\n", .{value_type.*});
                                @call(.auto, cb, .{evt});
                            }
                        }.updateText, value) catch |err| {
                            Vapor.println("bindValue: Could not attach event callback {any}\n", .{err});
                            unreachable;
                        };
                    },
                    else => return self.*,
                }
            } else {
                Vapor.attachEventCallback(ui_node, .input, cb) catch |err| {
                    Vapor.println("ONLEAVE: Could not attach event callback {any}\n", .{err});
                    unreachable;
                };
            }

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

        pub fn fontSize(self: *const Self, font_size: u8) Self {
            var new_self: Self = self.*;
            var visual = new_self._visual orelse types.Visual{};
            visual.font_size = font_size;
            new_self._visual = visual;
            return new_self;
        }

        pub fn textColor(self: *const Self, text_color: Vapor.Types.Color) Self {
            var new_self: Self = self.*;
            var visual = new_self._visual orelse types.Visual{};
            visual.text_color = text_color;
            new_self._visual = visual;
            return new_self;
        }

        pub fn onHover(self: *const Self, cb: fn (*Vapor.Event) void) Self {
            var new_self: Self = self.*;

            const ui_node = self._ui_node orelse blk: {
                const ui_node = LifeCycle.open(ElementDecl{
                    .state_type = _state_type,
                    .elem_type = self._elem_type,
                }) orelse {
                    Vapor.printlnSrcErr("Node is null", .{}, @src());
                    unreachable;
                };
                new_self._ui_node = ui_node;

                break :blk ui_node;
            };

            Vapor.attachEventCallback(ui_node, .pointerenter, cb) catch |err| {
                Vapor.println("ONLEAVE: Could not attach event callback {any}\n", .{err});
                unreachable;
            };

            return new_self;
        }

        pub fn onLeave(self: *const Self, cb: fn (*Vapor.Event) void) Self {
            var new_self: Self = self.*;

            const ui_node = self._ui_node orelse blk: {
                const ui_node = LifeCycle.open(ElementDecl{
                    .state_type = _state_type,
                    .elem_type = self._elem_type,
                }) orelse {
                    Vapor.printlnSrcErr("Node is null", .{}, @src());
                    unreachable;
                };
                new_self._ui_node = ui_node;

                break :blk ui_node;
            };
            Vapor.attachEventCallback(ui_node, .mouseleave, cb) catch |err| {
                Vapor.println("ONLEAVE: Could not attach event callback {any}\n", .{err});
                unreachable;
            };

            return new_self;
        }

        pub fn onEventCtx(self: *const Self, event: types.EventType, func: anytype, ctx: anytype) *const Self {
            const ui_node = self._ui_node orelse {
                Vapor.printlnSrcErr("Node is null", .{}, @src());
                unreachable;
            };

            Vapor.attachEventCtxCallback(ui_node, event, func, ctx) catch |err| {
                Vapor.println("OnEventCtx: Could not attach event callback {any}\n", .{err});
                unreachable;
            };
            return self;
        }

        pub fn onHoverCtx(self: *const Self, cb: anytype, args: anytype) Self {
            var new_self: Self = self.*;

            const ui_node = self._ui_node orelse blk: {
                const ui_node = LifeCycle.open(ElementDecl{
                    .state_type = _state_type,
                    .elem_type = self._elem_type,
                }) orelse {
                    Vapor.printlnSrcErr("Node is null", .{}, @src());
                    unreachable;
                };
                new_self._ui_node = ui_node;

                break :blk ui_node;
            };

            Vapor.attachEventCtxCallback(ui_node, .mouseenter, cb, args) catch |err| {
                Vapor.println("ONLEAVE: Could not attach event callback {any}\n", .{err});
                unreachable;
            };

            return new_self;
        }

        pub fn onDragStart(self: *const Self, cb: fn (*Vapor.Event) void) Self {
            var new_self: Self = self.*;

            const ui_node = self._ui_node orelse blk: {
                const ui_node = LifeCycle.open(ElementDecl{
                    .state_type = _state_type,
                    .elem_type = self._elem_type,
                }) orelse {
                    Vapor.printlnSrcErr("Node is null", .{}, @src());
                    unreachable;
                };
                new_self._ui_node = ui_node;

                break :blk ui_node;
            };
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
            var new_self: Self = self.*;
            var element = draggable_ptr.element;

            var ui_node = self._ui_node orelse {
                Vapor.printlnSrcErr("Node is null must ref() first, before setting onChange", .{}, @src());
                unreachable;
            };

            ui_node.hooks.created_id = 1;
            element.element_type = self._elem_type;
            element._node_ptr = ui_node;
            new_self._element = &element;
            draggable_ptr.element = element;

            onCreateNode(ui_node, struct {
                pub fn attachDraggable(draggable: *Draggable) void {
                    draggable.addStartListener();
                }
            }.attachDraggable, .{draggable_ptr});
            return self;
        }

        pub fn id(self: *const Self, element_id: []const u8) Self {
            var new_self: Self = self.*;
            new_self._id = element_id;
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
        pub fn transition(self: *const Self, _transition: types.Transition) Self {
            var new_self: Self = self.*;
            new_self._transition = _transition;
            return new_self;
        }

        pub fn transform(self: *const Self, value: types.Transform) Self {
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

            const ui_node = self._ui_node orelse blk: {
                const ui_node = LifeCycle.open(ElementDecl{
                    .state_type = _state_type,
                    .elem_type = self._elem_type,
                }) orelse {
                    Vapor.printlnSrcErr("Node is null", .{}, @src());
                    unreachable;
                };
                new_self._ui_node = ui_node;

                break :blk ui_node;
            };

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

        pub fn hidden(self: *const Self, hide: bool) Self {
            var new_self: Self = self.*;
            if (!hide) return new_self;
            new_self._flex_type = .hidden;
            return new_self;
        }

        pub fn style(self: *const Self, style_ptr: *const Vapor.Style) Self {
            var new_self: Self = self.*;
            new_self._used_style = true;
            var elem_decl = Vapor.ElementDecl{
                .state_type = _state_type,
                .elem_type = self._elem_type,
                .style = style_ptr,
                .aria_label = self._aria_label,
                .animation_enter = self._animation_enter,
                .animation_exit = self._animation_exit,
                .accessibility = self._accessibility,
            };

            // if (self._tooltip) |_tooltip| {
            //     elem_decl.tooltip = &_tooltip;
            // }

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

            if (self._ui_node == null) {
                const ui_node = Vapor.LifeCycle.open(elem_decl) orelse unreachable;
                if (self._elem_type == .Button or self._elem_type == .ButtonCycle) {
                    if (self._on_press) |on_press| {
                        Vapor.callback_registry.put(hashKey(ui_node.uuid), on_press) catch |err| {
                            println("Button Function Registry {any}\n", .{err});
                        };
                    }
                }
            } else if (self._elem_type == .CtxButton) {
                // const ui_node = self._ui_node orelse unreachable;
                // if (style_ptr.id) |element_id| {
                //     const kv = Vapor.ctx_callback_registry.fetchRemove(hashKey(ui_node.uuid)) orelse unreachable;
                //     Vapor.ctx_callback_registry.put(hashKey(element_id), kv.value) catch |err| {
                //         println("Button Function Registry {any}\n", .{err});
                //         unreachable;
                //     };
                // }
            } else if (self._elem_type == .Button or self._elem_type == .ButtonCycle) {
                const ui_node = self._ui_node orelse unreachable;
                if (self._on_press) |on_press| {
                    Vapor.callback_registry.put(hashKey(ui_node.uuid), on_press) catch |err| {
                        println("Button Function Registry {any}\n", .{err});
                    };
                }
            }

            Vapor.LifeCycle.configure(elem_decl);
            return new_self;
        }

        /// This function takes a const pointer to a Style Struct, and returns the body function callback
        /// This function is static, so any styles added via chaining methods will not be applied
        /// Use baseStyle to keep all chained additions
        pub fn styleOld(self: *const Self, style_ptr: *const Vapor.Style) *const fn (void) void {
            var elem_decl = Vapor.ElementDecl{
                .state_type = _state_type,
                .elem_type = self._elem_type,
                .style = style_ptr,
                .aria_label = self._aria_label,
                .animation_enter = self._animation_enter,
                .animation_exit = self._animation_exit,
                .accessibility = self._accessibility,
            };

            // if (self._tooltip) |_tooltip| {
            //     elem_decl.tooltip = &_tooltip;
            // }

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

            if (self._ui_node == null) {
                const ui_node = Vapor.LifeCycle.open(elem_decl) orelse unreachable;
                if (self._elem_type == .Button or self._elem_type == .ButtonCycle) {
                    if (self._on_press) |on_press| {
                        Vapor.callback_registry.put(hashKey(ui_node.uuid), on_press) catch |err| {
                            println("Button Function Registry {any}\n", .{err});
                        };
                    }
                }
            } else if (self._elem_type == .CtxButton) {
                // const ui_node = self._ui_node orelse unreachable;
                // if (style_ptr.id) |element_id| {
                //     const kv = Vapor.ctx_callback_registry.fetchRemove(hashKey(ui_node.uuid)) orelse unreachable;
                //     Vapor.ctx_callback_registry.put(hashKey(element_id), kv.value) catch |err| {
                //         println("Button Function Registry {any}\n", .{err});
                //         unreachable;
                //     };
                // }
            } else if (self._elem_type == .Button or self._elem_type == .ButtonCycle) {
                const ui_node = self._ui_node orelse unreachable;
                if (self._on_press) |on_press| {
                    Vapor.callback_registry.put(hashKey(ui_node.uuid), on_press) catch |err| {
                        println("Button Function Registry {any}\n", .{err});
                    };
                }
            }

            Vapor.LifeCycle.configure(elem_decl);
            return Vapor.LifeCycle.close;
        }

        pub fn font(self: *const Self, font_size: u8, weight: ?u16, color: ?Color) Self {
            var new_self: Self = self.*;
            var visual = new_self._visual orelse types.Visual{};
            visual.font_size = font_size;
            visual.font_weight = weight;
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

        pub fn outline(self: *const Self, value: types.Outline, color: ?Color) Self {
            var new_self: Self = self.*;
            var visual = new_self._visual orelse types.Visual{};
            visual.outline = value;
            visual.outline_color = color;
            new_self._visual = visual;
            return new_self;
        }

        pub fn shadow(self: *const Self, value: types.Shadow) Self {
            var new_self: Self = self.*;
            var visual = new_self._visual orelse types.Visual{};
            visual.shadow = value;
            new_self._visual = visual;
            return new_self;
        }

        pub fn newShadow(self: *const Self, value: ?Shadow) Self {
            var new_self: Self = self.*;
            var visual = new_self._visual orelse types.Visual{};
            visual.new_shadow = value;
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

        pub fn layer(self: *const Self, value: ?types.BackgroundLayer) Self {
            if (value == null) return self.*;
            var new_self: Self = self.*;
            var visual = new_self._visual orelse types.Visual{};
            visual.layer = value;
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

        pub fn hoverText(self: *const Self, color: Color) Self {
            var new_self: Self = self.*;
            new_self._interactive = .hover_text(color);
            return new_self;
        }

        pub fn spacing(self: *const Self, value: u8) Self {
            var new_self: Self = self.*;
            new_self._child_gap = value;
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
            if (new_self._padding == null) {
                new_self._padding = .{};
            }
            new_self._padding.?.left = value;
            return new_self;
        }

        pub fn pr(self: *const Self, value: u8) Self {
            var new_self: Self = self.*;
            if (new_self._padding == null) {
                new_self._padding = .{};
            }
            new_self._padding.?.right = value;
            return new_self;
        }

        pub fn pt(self: *const Self, value: u8) Self {
            var new_self: Self = self.*;
            if (new_self._padding == null) {
                new_self._padding = .{};
            }
            new_self._padding.?.top = value;
            return new_self;
        }

        pub fn pb(self: *const Self, value: u8) Self {
            var new_self: Self = self.*;
            if (new_self._padding == null) {
                new_self._padding = .{};
            }
            new_self._padding.?.bottom = value;
            return new_self;
        }

        pub fn mt(self: *const Self, value: i16) Self {
            var new_self: Self = self.*;
            if (new_self._margin == null) {
                new_self._margin = .{};
            }
            new_self._margin.?.top = value;
            return new_self;
        }

        pub fn mb(self: *const Self, value: i16) Self {
            var new_self: Self = self.*;
            if (new_self._margin == null) {
                new_self._margin = .{};
            }
            new_self._margin.?.bottom = value;
            return new_self;
        }

        pub fn ml(self: *const Self, value: i16) Self {
            var new_self: Self = self.*;
            if (new_self._margin == null) {
                new_self._margin = .{};
            }
            new_self._margin.?.left = value;
            return new_self;
        }

        pub fn mr(self: *const Self, value: i16) Self {
            var new_self: Self = self.*;
            if (new_self._margin == null) {
                new_self._margin = .{};
            }
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

        pub fn height(self: *const Self, length: types.Sizing) Self {
            var new_self: Self = self.*;
            if (new_self._size == null) {
                new_self._size = .{ .height = length };
            } else {
                new_self._size.?.height = length;
            }
            return new_self;
        }

        pub fn border(self: *const Self, value: types.BorderGrouped) Self {
            var new_self: Self = self.*;
            var visual = new_self._visual orelse types.Visual{};
            visual.border = value;
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
            return new_self;
        }

        pub fn end(self: *const Self) void {
            var mutable_style = Style{};
            if (self._style) |style_ptr| {
                mutable_style = style_ptr.*;
            }
            if (mutable_style.position == null) mutable_style.position = self._pos;
            if (mutable_style.visual == null) mutable_style.visual = self._visual;
            if (mutable_style.interactive == null) mutable_style.interactive = self._interactive;
            if (mutable_style.child_gap == null) mutable_style.child_gap = self._child_gap;
            if (mutable_style.transform_origin == null) mutable_style.transform_origin = self._transform_origin;
            if (mutable_style.padding == null) mutable_style.padding = self._padding;
            if (mutable_style.layout == null) mutable_style.layout = self._layout;
            if (mutable_style.margin == null) mutable_style.margin = self._margin;
            if (mutable_style.size == null) mutable_style.size = self._size;
            if (mutable_style.transition == null) mutable_style.transition = self._transition;
            if (mutable_style.flex_wrap == null) mutable_style.flex_wrap = self._flex_wrap;
            mutable_style.direction = self._direction;

            // if (self._tooltip) |_tooltip| {
            //     elem_decl.tooltip = &_tooltip;
            // }

            if (self._id) |_id| {
                mutable_style.id = _id;
            }

            const elem_decl = Vapor.ElementDecl{
                .state_type = _state_type,
                .elem_type = self._elem_type,
                .style = &mutable_style,
                .aria_label = self._aria_label,
                .animation_enter = self._animation_enter,
                .animation_exit = self._animation_exit,
                .accessibility = self._accessibility,
            };

            if (self._ui_node == null) {
                const ui_node = Vapor.LifeCycle.open(elem_decl) orelse unreachable;
                if (self._elem_type == .Button or self._elem_type == .ButtonCycle) {
                    if (self._on_press) |on_press| {
                        Vapor.callback_registry.put(hashKey(ui_node.uuid), on_press) catch |err| {
                            println("Button Function Registry {any}\n", .{err});
                        };
                    }
                }
            } else if (self._elem_type == .CtxButton) {
                // const ui_node = self._ui_node orelse unreachable;
                // if (elem_decl.style.?.style_id) |element_id| {
                //     const kv = Vapor.ctx_callback_registry.fetchRemove(hashKey(ui_node.uuid)) orelse unreachable;
                //     Vapor.ctx_callback_registry.put(hashKey(element_id), kv.value) catch |err| {
                //         println("Button Function Registry {any}\n", .{err});
                //         unreachable;
                //     };
                // }
            } else if (self._elem_type == .Button or self._elem_type == .ButtonCycle) {
                const ui_node = self._ui_node orelse unreachable;
                if (self._on_press) |on_press| {
                    Vapor.callback_registry.put(hashKey(ui_node.uuid), on_press) catch |err| {
                        println("Button Function Registry {any}\n", .{err});
                    };
                }
            }

            // Vapor.LifeCycle.configure(elem_decl);
            _ = Vapor.current_ctx.configureByNode(self._ui_node, elem_decl);
            return Vapor.LifeCycle.close({});
        }

        pub fn child(self: *const Self, item: anytype) void {
            if (@TypeOf(item) == GenericBuilder(.pure, false)) {
                var added_node: GenericBuilder(.pure, false) = item;
                added_node._ui_node = item._ui_node;
                added_node.end();
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
                if (_visual.font_size != null) visual.font_size = _visual.font_size;
                if (_visual.opacity != null) visual.opacity = _visual.opacity;
                if (_visual.ellipsis != null) visual.ellipsis = _visual.ellipsis;
                if (_visual.shadow != null) visual.shadow = _visual.shadow;
                if (_visual.cursor != null) visual.cursor = _visual.cursor;
                if (self._edges != null) visual.edges = self._edges;

                mutable_style.visual = visual;
            } else if (self._visual) |_visual| {
                mutable_style.visual = _visual;
                mutable_style.visual.?.edges = self._edges;
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
            if (mutable_style.margin == null) mutable_style.margin = self._margin;
            if (mutable_style.size == null) mutable_style.size = self._size;
            if (mutable_style.transition == null) {
                mutable_style.transition = self._transition;
            }
            if (mutable_style.flex_wrap == null) mutable_style.flex_wrap = self._flex_wrap;
            mutable_style.direction = self._direction;
            if (mutable_style.scroll == null) mutable_style.scroll = self._scroll;

            if (self._id) |_id| {
                mutable_style.id = _id;

                const ui_node = self._ui_node orelse unreachable;
                const kv = Vapor.ctx_callback_registry.fetchRemove(hashKey(ui_node.uuid)) orelse unreachable;
                Vapor.ctx_callback_registry.put(hashKey(_id), kv.value) catch |err| {
                    println("Button Function Registry {any}\n", .{err});
                    unreachable;
                };
            }

            if (self._class) |_class| {
                mutable_style.style_id = _class;
            }

            const elem_decl = Vapor.ElementDecl{
                .state_type = _state_type,
                .elem_type = self._elem_type,
                .style = &mutable_style,
                .aria_label = self._aria_label,
                .animation_enter = self._animation_enter,
                .animation_exit = self._animation_exit,
                .inlineStyle = self._inlineStyle,
                .accessibility = self._accessibility,
            };

            if (self._ui_node == null) {
                const ui_node = Vapor.LifeCycle.open(elem_decl) orelse unreachable;
                if (self._elem_type == .Button or self._elem_type == .ButtonCycle) {
                    if (self._on_press) |on_press| {
                        Vapor.callback_registry.put(hashKey(ui_node.uuid), on_press) catch |err| {
                            println("Button Function Registry {any}\n", .{err});
                        };
                    }
                }
            } else if (self._elem_type == .CtxButton) {
                // Vapor.ctx_callback_registry.put(hashKey(ui_node.uuid), &closure.run_node) catch |err| {
                //     println("Button Function Registry {any}\n", .{err});
                //     unreachable;
                // };

            } else if (self._elem_type == .Button or self._elem_type == .ButtonCycle) {
                const ui_node = self._ui_node orelse unreachable;
                if (self._on_press) |on_press| {
                    Vapor.callback_registry.put(hashKey(ui_node.uuid), on_press) catch |err| {
                        println("Button Function Registry {any}\n", .{err});
                    };
                }
            }

            Vapor.LifeCycle.configure(elem_decl);
            // return self;
            return Vapor.LifeCycle.close({});
        }

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
                if (_visual.font_size != null) visual.font_size = _visual.font_size;
                if (_visual.opacity != null) visual.opacity = _visual.opacity;
                if (_visual.ellipsis != null) visual.ellipsis = _visual.ellipsis;
                if (_visual.shadow != null) visual.shadow = _visual.shadow;
                if (_visual.cursor != null) visual.cursor = _visual.cursor;
                if (self._edges != null) visual.edges = self._edges;

                mutable_style.visual = visual;
            } else if (self._visual) |_visual| {
                mutable_style.visual = _visual;
                mutable_style.visual.?.edges = self._edges;
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
            if (mutable_style.margin == null) mutable_style.margin = self._margin;
            if (mutable_style.size == null) mutable_style.size = self._size;
            if (mutable_style.transition == null) {
                mutable_style.transition = self._transition;
            }
            if (mutable_style.flex_wrap == null) mutable_style.flex_wrap = self._flex_wrap;
            mutable_style.direction = self._direction;
            if (mutable_style.scroll == null) mutable_style.scroll = self._scroll;

            if (self._id) |_id| {
                mutable_style.id = _id;

                const ui_node = self._ui_node orelse unreachable;
                const kv = Vapor.ctx_callback_registry.fetchRemove(hashKey(ui_node.uuid)) orelse unreachable;
                Vapor.ctx_callback_registry.put(hashKey(_id), kv.value) catch |err| {
                    println("Button Function Registry {any}\n", .{err});
                    unreachable;
                };
            }

            if (self._class) |_class| {
                mutable_style.style_id = _class;
            }

            const elem_decl = Vapor.ElementDecl{
                .state_type = _state_type,
                .elem_type = self._elem_type,
                .style = &mutable_style,
                .aria_label = self._aria_label,
                .animation_enter = self._animation_enter,
                .animation_exit = self._animation_exit,
                .inlineStyle = self._inlineStyle,
                .accessibility = self._accessibility,
            };

            if (self._ui_node == null) {
                const ui_node = Vapor.LifeCycle.open(elem_decl) orelse unreachable;
                if (self._elem_type == .Button or self._elem_type == .ButtonCycle) {
                    if (self._on_press) |on_press| {
                        Vapor.callback_registry.put(hashKey(ui_node.uuid), on_press) catch |err| {
                            println("Button Function Registry {any}\n", .{err});
                        };
                    }
                }
            } else if (self._elem_type == .CtxButton) {
                // Vapor.ctx_callback_registry.put(hashKey(ui_node.uuid), &closure.run_node) catch |err| {
                //     println("Button Function Registry {any}\n", .{err});
                //     unreachable;
                // };

            } else if (self._elem_type == .Button or self._elem_type == .ButtonCycle) {
                const ui_node = self._ui_node orelse unreachable;
                if (self._on_press) |on_press| {
                    Vapor.callback_registry.put(hashKey(ui_node.uuid), on_press) catch |err| {
                        println("Button Function Registry {any}\n", .{err});
                    };
                }
            }

            Vapor.LifeCycle.configure(elem_decl);
            // return self;
            return Vapor.LifeCycle.close({});
        }

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
                if (_visual.font_size != null) visual.font_size = _visual.font_size;
                if (_visual.opacity != null) visual.opacity = _visual.opacity;
                if (_visual.ellipsis != null) visual.ellipsis = _visual.ellipsis;
                if (_visual.shadow != null) visual.shadow = _visual.shadow;
                if (_visual.cursor != null) visual.cursor = _visual.cursor;
                if (self._edges != null) visual.edges = self._edges;

                mutable_style.visual = visual;
            } else if (self._visual) |_visual| {
                mutable_style.visual = _visual;
                mutable_style.visual.?.edges = self._edges;
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
            if (mutable_style.margin == null) mutable_style.margin = self._margin;
            if (mutable_style.size == null) mutable_style.size = self._size;
            if (mutable_style.transition == null) {
                mutable_style.transition = self._transition;
            }
            if (mutable_style.flex_wrap == null) mutable_style.flex_wrap = self._flex_wrap;
            mutable_style.direction = self._direction;
            if (mutable_style.scroll == null) mutable_style.scroll = self._scroll;

            if (self._id) |_id| {
                mutable_style.id = _id;

                const ui_node = self._ui_node orelse unreachable;
                const kv = Vapor.ctx_callback_registry.fetchRemove(hashKey(ui_node.uuid)) orelse unreachable;
                Vapor.ctx_callback_registry.put(hashKey(_id), kv.value) catch |err| {
                    println("Button Function Registry {any}\n", .{err});
                    unreachable;
                };
            }

            if (self._class) |_class| {
                mutable_style.style_id = _class;
            }

            const elem_decl = Vapor.ElementDecl{
                .state_type = _state_type,
                .elem_type = self._elem_type,
                .style = &mutable_style,
                .aria_label = self._aria_label,
                .animation_enter = self._animation_enter,
                .animation_exit = self._animation_exit,
                .inlineStyle = self._inlineStyle,
                .accessibility = self._accessibility,
            };

            if (self._ui_node == null) {
                const ui_node = Vapor.LifeCycle.open(elem_decl) orelse unreachable;
                if (self._elem_type == .Button or self._elem_type == .ButtonCycle) {
                    if (self._on_press) |on_press| {
                        Vapor.callback_registry.put(hashKey(ui_node.uuid), on_press) catch |err| {
                            println("Button Function Registry {any}\n", .{err});
                        };
                    }
                }
            } else if (self._elem_type == .CtxButton) {
                // Vapor.ctx_callback_registry.put(hashKey(ui_node.uuid), &closure.run_node) catch |err| {
                //     println("Button Function Registry {any}\n", .{err});
                //     unreachable;
                // };

            } else if (self._elem_type == .Button or self._elem_type == .ButtonCycle) {
                const ui_node = self._ui_node orelse unreachable;
                if (self._on_press) |on_press| {
                    Vapor.callback_registry.put(hashKey(ui_node.uuid), on_press) catch |err| {
                        println("Button Function Registry {any}\n", .{err});
                    };
                }
            }

            _ = Vapor.current_ctx.configureByNode(self._ui_node, elem_decl);
            return Vapor.LifeCycle.close({});
        }

        pub fn plain(self: *const Self) void {
            const elem_decl = Vapor.ElementDecl{
                .state_type = _state_type,
                .elem_type = self._elem_type,
            };
            _ = Vapor.LifeCycle.open(elem_decl);
            Vapor.LifeCycle.configure(elem_decl);
            Vapor.LifeCycle.close({});
        }
    };
}

var alt_len: usize = 0;
const API = struct {
    pub fn buttonCallback(id_ptr: [*:0]u8) callconv(.c) void {
        const id = std.mem.span(id_ptr);
        defer Vapor.allocator_global.free(id);
        const func = Vapor.callback_registry.get(hashKey(id)) orelse return;
        @call(.auto, func, .{});
        if (Vapor.mode == .atomic) {
            Vapor.cycle();
        }
    }

    pub fn ctxButtonCallback(id_ptr: [*:0]u8) callconv(.c) void {
        const id = std.mem.span(id_ptr);
        defer Vapor.allocator_global.free(id);
        const node = Vapor.ctx_callback_registry.get(hashKey(id)) orelse return;
        @call(.auto, node.data.runFn, .{&node.data});
        if (Vapor.mode == .atomic) {
            Vapor.cycle();
        }
    }

    pub fn getHeadingLevel(ptr: ?*UINode) callconv(.c) u8 {
        const node_ptr = ptr orelse return 0;
        const heading = node_ptr.type == .Heading;
        if (heading) {
            return node_ptr.level orelse return 0;
        }
        return 0;
    }

    pub fn getAlt(node_ptr: ?*UINode) callconv(.c) ?[*]const u8 {
        if (node_ptr) |node| {
            const alt = node.alt orelse return null;
            alt_len = alt.len;
            return alt.ptr;
        }
        return null;
    }
    pub fn getAltLen() callconv(.c) usize {
        return alt_len;
    }
};

// --- Auto-Export Magic ---
// This runs automatically when this file is imported
comptime {
    const decls = std.meta.declarations(API);

    for (decls) |decl| {
        const val = @field(API, decl.name);
        const Type = @TypeOf(val);
        if (@typeInfo(Type) == .@"fn") {
            // Export it with its own name
            @export(&val, .{ .name = decl.name });
        }
    }
}
