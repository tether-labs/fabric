const std = @import("std");
const Vapor = @import("Vapor.zig");
const KeyGenerator = @import("Key.zig").KeyGenerator;
const utils = @import("utils.zig");
const hashKey = utils.hashKey;
const Writer = @import("Writer.zig");
const Packer = @import("Packer.zig");
const ClassType = @import("ClassCache.zig").ClassType;
const Configuration = @import("Configuration.zig");
const Accessibility = @import("Accessibility.zig").Accessibility;
// const CompactStyle = @import("types.zig").CompactStyle;

const types = @import("types.zig");

pub const Item = struct {
    ptr: ?*UINode,
    next: ?*Item = null,
};

const Style = types.Style;
const EType = types.ElementType;
const RenderCommand = types.RenderCommand;
const ElemDecl = types.ElementDeclaration;
const Direction = types.Direction;
const HooksIds = types.HooksIds;
const InputParams = types.InputParams;

pub const StyleInfo = struct {
    packed_field_ptrs: PackedFieldPtrs,
    style_hashes: [8]u32,
    style_hash: u32,
    class: ?[]const u8 = null,
};

pub var style_info_map: std.AutoHashMap(u32, *StyleInfo) = undefined;
pub const PackedFieldPtrs = struct {
    visual_ptr: ?*const types.PackedVisual = null,
    layout_ptr: ?*const types.PackedLayout = null,
    position_ptr: ?*const types.PackedPosition = null,
    margins_paddings_ptr: ?*const types.PackedMarginsPaddings = null,
    animations_ptr: ?*const types.PackedAnimations = null,
    interactive_ptr: ?*const types.PackedInteractive = null,
    transforms_ptr: ?*const types.PackedTransforms = null,
};

pub var ui_nodes: []UINode = undefined;
pub const UIContext = @This();
root: ?*UINode = null,
current_parent: ?*UINode = null,
stack: ?*Item = null,
root_stack_ptr: ?*Item = null,
node_pool: std.heap.MemoryPool(UINode),
memory_pool: std.heap.MemoryPool(Item),
// render_cmd_memory_pool: std.heap.MemoryPool(RenderCommand),
// tree_memory_pool: std.heap.MemoryPool(CommandsTree),
current_offset: f32 = 0,
ui_tree: ?*CommandsTree = null,

pub const CommandsTree = struct {
    node: *RenderCommand,
    children: std.ArrayListUnmanaged(*CommandsTree) = undefined,
};

// pub fn debugPrintUINodeLayout() void {
//     inline for (@typeInfo(UINode).@"struct".fields) |field| {
//         const field_type = field.type;
//         const size = @sizeOf(field_type);
//         Vapor.println("{s:20} | size: {d:3} bytes |\n", .{ field.name, size });
//     }
//
//     Vapor.println("\nTotal struct size: {d} bytes\n", .{@sizeOf(UINode)});
// }

pub const UINode = struct {
    dirty: bool = false,
    parent: ?*UINode = null,
    type: EType = EType.FlexBox,
    text: ?[]const u8 = null,
    uuid: []const u8 = "",
    uuid_buf: [32]u8 = undefined,
    href: ?[]const u8 = null,
    index: usize = 0,
    hooks: HooksIds = .{},
    text_field_params: ?*types.TextFieldParams = null,
    event_type: ?types.EventType = null,
    state_type: types.StateType = .pure,
    aria_label: ?[]const u8 = null,
    alt: ?[]const u8 = null,
    class: ?[]const u8 = null,
    animation_exit: ?[]const u8 = null,
    packed_field_ptrs: ?PackedFieldPtrs = null, // TODO: This is 28 bytes
    children_count: usize = 0,
    finger_print: u32 = 0,
    style_hash: u32 = 0,
    style_changed: bool = false,
    props_hash: u32 = 0,
    props_changed: bool = false,
    hash: u32 = 0,
    prev_style_hash: u32 = 0,
    prev_style_hash_computed: u32 = 0,
    level: ?u8 = null,
    video: ?*const types.Video = null,
    event_handlers: ?*Vapor.EventHandlers = null,
    on_hover: bool = false,
    on_leave: bool = false,
    name: ?[]const u8 = null,
    accessibility: bool = false,
    direction: Direction = .row,

    first_child: ?*UINode = null, // "child" in React terms
    next_sibling: ?*UINode = null, // "sibling" in React terms
    last_child: ?*UINode = null, // +4 bytes, but O(1) append
    hover_style_fields: ?*[]const types.StyleFields = null,
    inlineStyle: ?[]const u8 = null,
    style_hashes: [8]u32 = .{ 0, 0, 0, 0, 0, 0, 0, 0 }, // Direct access, no hashmap

    // nodes_flat_index: usize = 0,
    // tooltip: ?types.Tooltip = null,

    /// Add a child to this node (prepends - O(1))
    /// Note: Children will be in reverse order of insertion
    pub fn addChild(parent: *UINode, child: *UINode) void {
        child.parent = parent;
        child.next_sibling = parent.first_child;
        parent.first_child = child;
        parent.children_count += 1;
    }

    pub fn appendChild(parent: *UINode, child: *UINode) void {
        child.parent = parent;
        child.next_sibling = null;
        parent.children_count += 1;

        if (parent.last_child) |last| {
            last.next_sibling = child;
        } else {
            parent.first_child = child;
        }
        parent.last_child = child;
    }

    /// Get the next child (for iteration)
    /// Usage:
    ///   var child = node.first_child;
    ///   while (child) |c| {
    ///       // process c
    ///       child = c.nextChild();
    ///   }
    pub fn nextChild(self: *UINode) ?*UINode {
        return self.next_sibling;
    }

    /// Get child by index - O(n)
    /// Returns null if index is out of bounds
    pub fn childAt(self: *UINode, target_index: usize) ?*UINode {
        var current = self.first_child;
        var i: usize = 0;

        while (current) |child| {
            if (i == target_index) {
                return child;
            }
            i += 1;
            current = child.next_sibling;
        }

        return null;
    }

    /// Iterator for convenient for-loop syntax
    /// Usage:
    ///   for (node.children()) |child| {
    ///       // process child
    ///   }
    pub fn children(self: *UINode) ChildIterator {
        return .{ .current = self.first_child };
    }

    pub const ChildIterator = struct {
        current: ?*UINode,

        pub fn next(self: *ChildIterator) ?*UINode {
            const node = self.current orelse return null;
            self.current = node.next_sibling;
            return node;
        }
    };
};

pub fn init(_: *UIContext, parent: ?*UINode, etype: EType) !*UINode {
    const node = Vapor.frame_arena.nodeAlloc() orelse return error.NodeAllocFailed;
    Vapor.frame_arena.incrementNodeCount();
    node.* = .{
        .parent = parent,
        .type = etype,
    };
    return node;
}

/// initContext initializes the UIContext and its associated memory pools
pub fn initContext(ui_ctx: *UIContext) !void {
    const allocator = Vapor.arena(.frame);
    ui_ctx.* = .{
        .node_pool = std.heap.MemoryPool(UINode).init(allocator),
        .memory_pool = std.heap.MemoryPool(Item).init(allocator),
        // .render_cmd_memory_pool = std.heap.MemoryPool(RenderCommand).init(allocator),
        // .tree_memory_pool = std.heap.MemoryPool(CommandsTree).init(allocator),
    };

    // Either change the init function to return a pointer directly
    const node_ptr = try ui_ctx.init(null, EType.Block);
    node_ptr.uuid = "fabric_root_id";
    node_ptr.dirty = false;
    ui_ctx.root = node_ptr;
    const item: *Item = try ui_ctx.memory_pool.create();
    item.* = .{
        .ptr = node_ptr,
    };
    ui_ctx.root_stack_ptr = item;
    ui_ctx.stack = item;

    // packed_position = std.mem.zeroes(types.PackedPosition);
    // packed_layout = std.mem.zeroes(types.PackedLayout);
    // packed_margins_paddings = std.mem.zeroes(types.PackedMarginsPaddings);
    // packed_visual = std.mem.zeroes(types.PackedVisual);
    // packed_animations = std.mem.zeroes(types.PackedAnimations);
    // packed_interactive = std.mem.zeroes(types.PackedInteractive);
    // packed_transforms = std.mem.zeroes(types.PackedTransforms);
    // debugPrintUINodeLayout();
}

pub fn deinit(_: *UIContext) void {
    // ui_ctx.root.?.children = undefined;
    // ui_ctx.root = null;
    // ui_ctx.ui_tree = null;
}

pub fn stackRegister(ui_ctx: *UIContext, ui_node: *UINode) !void {
    Vapor.frame_arena.incrementItemCount();
    const item: *Item = try ui_ctx.memory_pool.create();
    const current_stack = ui_ctx.stack;
    item.* = .{
        .ptr = ui_node,
    };

    if (current_stack) |stack| {
        item.next = stack;
    }

    ui_ctx.stack = item;
}

// These come from the pre-compiled .a file
extern fn vapor_hash_bytes(ptr: [*]const u8, len: usize) u32;

// Comptime stuff that uses runtime
pub fn structToBytes(struct_ptr: *anyopaque) u32 {
    const bytes = std.mem.asBytes(struct_ptr);
    return vapor_hash_bytes(bytes.ptr, bytes.len);
}

pub fn stackPop(ui_ctx: *UIContext) void {
    const current_stack = ui_ctx.stack orelse return;
    ui_ctx.stack = current_stack.next;
}

pub var uuid_depth: usize = 0;
var current_tree: usize = 0;
pub var indexes: std.AutoHashMap(u32, usize) = undefined;
fn setUUID(parent: *UINode, child: *UINode) void {
    uuid_depth += 1;
    // Set the keyGenerator count
    const index: usize = parent.children_count;
    KeyGenerator.setComponentCount(index);
    if (child.uuid.len > 0) {
        child.index = index - 1;
    } else {
        KeyGenerator.incrementComponentCount();
        const key = KeyGenerator.generateKey(
            &child.uuid_buf,
            child.type,
            parent.uuid,
            uuid_depth,
        );
        child.index = KeyGenerator.getComponentCount() - 1;
        // child.hash = KeyGenerator.generateKey64(child.type, parent.hash, uuid_depth);
        child.uuid = key;
        // child.uuid = Vapor.fmtln("child_{d}_{d}_{d}", .{ child.index, index, @intFromEnum(child.type) });
        // we add this so that animations are sepeate, we need to be careful though since
        // if a user does not specifc a id for a class, and the  rerender tree has the same id
        // and then previous one uses an animation then that transistion and animation will be
        // applied to the new parent since it has the same class name and styling
    }
}

pub var cache_count: u32 = 0;
pub var prev_style_hashes: std.AutoHashMap(u32, u32) = undefined;
pub fn captureHash(node: *UINode) void {
    prev_style_hashes.put(node.hash, node.prev_style_hash_computed) catch unreachable;
    if (node.packed_field_ptrs == null) return;
    if (style_info_map.get(node.prev_style_hash_computed) != null) return;
    const style_info = Vapor.arena(.persist).create(StyleInfo) catch unreachable;
    style_info.* = .{
        .packed_field_ptrs = node.packed_field_ptrs.?,
        .style_hashes = node.style_hashes,
        .style_hash = node.style_hash,
        .class = node.class,
    };
    style_info_map.put(node.prev_style_hash_computed, style_info) catch unreachable;
}

// Open takes a current stack and adds the elements depth first search
// Open and close get called in sequence
// depth first search
pub var open_time: f64 = 0;
pub fn open(ui_ctx: *UIContext, elem_decl: ElemDecl) !*UINode {
    const stack = ui_ctx.stack.?;
    // Parent node
    const current_open = stack.ptr orelse unreachable;
    var node = try ui_ctx.init(current_open, elem_decl.elem_type);
    node.level = elem_decl.level;

    current_open.appendChild(node);
    ui_ctx.stackRegister(node) catch |err| {
        Vapor.printlnSrcErr("Could not register node {any}", .{err}, @src());
        return err;
    };

    const style = elem_decl.style;
    if (style != null and style.?.id != null) {
        node.uuid = style.?.id.?;
    }

    setUUID(current_open, node);

    node.hash = hashKey(node.uuid);

    // Lookup previous hash
    if (prev_style_hashes.get(node.hash)) |old_hash| {
        node.prev_style_hash = old_hash;
    }

    return node;
}

pub fn openUnattached(ui_ctx: *UIContext, elem_decl: ElemDecl) !*UINode {
    const stack = ui_ctx.stack.?;
    // Parent node
    const current_open = stack.ptr orelse unreachable;
    var node = try ui_ctx.init(current_open, elem_decl.elem_type);
    node.level = elem_decl.level;

    current_open.appendChild(node);
    if (elem_decl.elem_type == .FlexBox) {
        ui_ctx.stackRegister(node) catch |err| {
            Vapor.printlnSrcErr("Could not register node {any}", .{err}, @src());
            return err;
        };
    }

    const style = elem_decl.style;
    if (style != null and style.?.id != null) {
        node.uuid = style.?.id.?;
    }

    setUUID(current_open, node);

    node.hash = hashKey(node.uuid);

    // Lookup previous hash
    if (prev_style_hashes.get(node.hash)) |old_hash| {
        node.prev_style_hash = old_hash;
    }

    return node;
}

// -----------------------------------------------------------------------------
// NEW HELPER FUNCTIONS
// -----------------------------------------------------------------------------

/// Helper to pack a color union (`.Literal` or `.Thematic`) into a PackedColor struct.
fn packColor(source_color: types.Color, packed_color: *types.PackedColor) void {
    switch (source_color) {
        .Literal => |color| {
            packed_color.* = .{ .has_color = true, .color = color };
        },
        .Thematic => |token| {
            packed_color.* = .{ .has_token = true, .token = token };
        },
    }
}

fn getOrPutAndUpdateHashLayout(
    hash: u32,
    data: types.PackedLayout,
) !*const @TypeOf(data) {
    if (Packer.layouts.get(hash)) |ptr| {
        return ptr;
    }

    const new_ptr = try Packer.layouts_pool.create();
    new_ptr.* = data;
    try Packer.layouts.put(hash, new_ptr);

    return new_ptr;
}

fn getOrPutAndUpdateHashPosition(
    hash: u32,
    data: types.PackedPosition,
) !*const @TypeOf(data) {
    if (Packer.positions.get(hash)) |ptr| {
        return ptr;
    }

    const new_ptr = try Packer.positions_pool.create();
    new_ptr.* = data;
    try Packer.positions.put(hash, new_ptr);

    return new_ptr;
}

fn getOrPutAndUpdateHashMarginsPadding(
    hash: u32,
    data: types.PackedMarginsPaddings,
) !*const @TypeOf(data) {
    if (Packer.margins_paddings.get(hash)) |ptr| {
        return ptr;
    }

    const new_ptr = try Packer.margins_paddings_pool.create();
    new_ptr.* = data;
    try Packer.margins_paddings.put(hash, new_ptr);

    return new_ptr;
}

fn getOrPutAndUpdateHashVisual(
    hash: u32,
    data: types.PackedVisual,
) !*const @TypeOf(data) {
    if (Packer.visuals.get(hash)) |ptr| {
        return ptr;
    }

    const new_ptr = try Packer.visuals_pool.create();
    new_ptr.* = data;
    try Packer.visuals.put(hash, new_ptr);

    return new_ptr;
}

fn getOrPutAndUpdateHashInteractive(
    hash: u32,
    data: types.PackedInteractive,
) !*const @TypeOf(data) {
    if (Packer.interactives.get(hash)) |ptr| {
        return ptr;
    }

    const new_ptr = try Packer.interactives_pool.create();
    new_ptr.* = data;
    try Packer.interactives.put(hash, new_ptr);

    return new_ptr;
}

fn getOrPutAndUpdateHashAnimation(
    hash: u32,
    data: types.PackedAnimations,
) !*const @TypeOf(data) {
    if (Packer.animations.get(hash)) |ptr| {
        return ptr;
    }

    const new_ptr = try Packer.animations_pool.create();
    new_ptr.* = data;
    try Packer.animations.put(hash, new_ptr);

    return new_ptr;
}

fn getOrPutAndUpdateHashTransform(
    hash: u32,
    data: types.PackedTransforms,
) !*const @TypeOf(data) {
    if (Packer.transforms.get(hash)) |ptr| {
        return ptr;
    }

    const new_ptr = try Packer.transforms_pool.create();
    new_ptr.* = data;
    try Packer.transforms.put(hash, new_ptr);

    return new_ptr;
}

// -----------------------------------------------------------------------------
// REFACTORED FUNCTIONS
// -----------------------------------------------------------------------------

pub fn checkVisual(visual: *const types.Visual, packet_visual: *types.PackedVisual, _: types.ElementType) void {
    // Refactored to use the packColor helper
    if (visual.background) |background| {
        if (background.color) |color| {
            var background_color = packet_visual.background;
            packColor(color, &background_color);
            packet_visual.background = background_color;
        } else if (background.layer) |layer| {
            switch (layer) {
                .Image => {},
                else => {
                    Vapor.printlnSrcErr("Not implemented yet", .{}, @src());
                },
            }
        }
    }

    // if (visual.layer) |layer| {
    //     var packed_layers = Vapor.arena(.frame).alloc(types.PackedLayer, 1) catch unreachable;
    //     switch (layer) {
    //         .Grid => |grid| {
    //             var packed_layer: types.PackedLayer = .{ .Grid = .{} };
    //             packed_layer.Grid.size = grid.size;
    //             packed_layer.Grid.thickness = grid.thickness;
    //             var grid_color = packed_layer.Grid.packed_color;
    //             packColor(grid.color, &grid_color);
    //             packed_layer.Grid.packed_color = grid_color;
    //             packed_layers[0] = packed_layer;
    //         },
    //         // .Image => {},
    //         .Dot => |dots| {
    //             var packed_layer: types.PackedLayer = .{ .Dot = .{} };
    //             packed_layer.Dot.spacing = dots.spacing;
    //             packed_layer.Dot.radius = dots.radius;
    //             var dots_color = packed_layer.Dot.packed_color;
    //             packColor(dots.color, &dots_color);
    //             packed_layer.Dot.packed_color = dots_color;
    //             packed_layers[0] = packed_layer;
    //         },
    //         .Gradient => |gradient| {
    //             var packed_layer: types.PackedLayer = .{ .Gradient = .{} };
    //             packed_layer.Gradient.type = gradient.type;
    //             packed_layer.Gradient.direction = gradient.direction;
    //             var gradient_colors = Vapor.arena(.frame).alloc(types.PackedColor, gradient.colors.len) catch unreachable;
    //             for (gradient.colors, 0..) |color, j| {
    //                 packColor(color, &gradient_colors[j]);
    //             }
    //             packed_layer.Gradient.colors_ptr = gradient_colors.ptr;
    //             packed_layer.Gradient.colors_len = gradient_colors.len;
    //             packed_layers[0] = packed_layer;
    //         },
    //         else => {
    //             Vapor.printlnSrcErr("Not implemented yet {any}", .{layer}, @src());
    //             // @compileError("Not implemented yet");
    //         },
    //     }
    //     // packet_visual.packed_layers.items_ptr = packed_layers.ptr;
    //     // packet_visual.packed_layers.len = packed_layers.len;
    //     //
    //     // if (element_type == .Text) {
    //     //     packet_visual.is_text_gradient = true;
    //     // }
    // } else if (visual.layers) |_| {
    //     // var packed_layers = Vapor.arena(.frame).alloc(types.PackedLayer, layers.len) catch unreachable;
    //     // for (layers, 0..) |layer, i| {
    //     //     switch (layer) {
    //     //         .Grid => |grid| {
    //     //             var packed_layer: types.PackedLayer = .{ .Grid = .{} };
    //     //             packed_layer.Grid.size = grid.size;
    //     //             packed_layer.Grid.thickness = grid.thickness;
    //     //             var grid_color = packed_layer.Grid.packed_color;
    //     //             packColor(grid.color, &grid_color);
    //     //             packed_layer.Grid.packed_color = grid_color;
    //     //             packed_layers[i] = packed_layer;
    //     //         },
    //     //         // .Image => {},
    //     //         .Dot => |dots| {
    //     //             var packed_layer: types.PackedLayer = .{ .Dot = .{} };
    //     //             packed_layer.Dot.spacing = dots.spacing;
    //     //             packed_layer.Dot.radius = dots.radius;
    //     //             var dots_color = packed_layer.Dot.packed_color;
    //     //             packColor(dots.color, &dots_color);
    //     //             packed_layer.Dot.packed_color = dots_color;
    //     //             packed_layers[0] = packed_layer;
    //     //         },
    //     //         .Gradient => |gradient| {
    //     //             var packed_layer: types.PackedLayer = .{ .Gradient = .{} };
    //     //             packed_layer.Gradient.type = gradient.type;
    //     //             packed_layer.Gradient.direction = gradient.direction;
    //     //             var gradient_colors = Vapor.arena(.frame).alloc(types.PackedColor, gradient.colors.len) catch unreachable;
    //     //             for (gradient.colors, 0..) |color, j| {
    //     //                 packColor(color, &gradient_colors[j]);
    //     //             }
    //     //             packed_layer.Gradient.colors_ptr = gradient_colors.ptr;
    //     //             packed_layer.Gradient.colors_len = gradient_colors.len;
    //     //             packed_layers[i] = packed_layer;
    //     //         },
    //     //         else => {
    //     //             Vapor.printlnSrcErr("Not implemented yet {any}", .{layer}, @src());
    //     //             // @compileError("Not implemented yet");
    //     //         },
    //     //     }
    //     // }
    //     // packet_visual.packed_layers.items_ptr = packed_layers.ptr;
    //     // packet_visual.packed_layers.len = packed_layers.len;
    // }

    if (visual.fill) |fill| {
        var fill_color = packet_visual.fill;
        packColor(fill, &fill_color);
        packet_visual.fill = fill_color;
    }

    if (visual.stroke) |stroke| {
        var stroke_color = packet_visual.stroke;
        packColor(stroke, &stroke_color);
        packet_visual.stroke = stroke_color;
    }

    if (visual.border) |border| {
        packet_visual.border_thickness = border.thickness;
        packet_visual.has_border_thickeness = true;
        if (border.color) |color| {
            packet_visual.has_border_color = true;
            var border_color = packet_visual.border_color;
            packColor(color, &border_color);
            packet_visual.border_color = border_color;
        }
        if (border.radius) |radius| {
            packet_visual.has_border_radius = true;
            packet_visual.border_radius = radius;
        }
    }

    if (visual.font_size) |font_size| {
        packet_visual.font_size = font_size;
    }
    if (visual.font_weight) |font_weight| {
        packet_visual.font_weight = font_weight;
    }

    if (visual.outline) |outline| {
        packet_visual.outline = outline;
    }

    if (visual.font_style) |font_style| {
        packet_visual.font_style = font_style;
    }

    if (visual.text_color) |color| {
        var text_color = packet_visual.text_color;
        packColor(color, &text_color);
        packet_visual.text_color = text_color;
    }
    if (visual.opacity) |opacity| {
        packet_visual.has_opacity = true;
        packet_visual.opacity = opacity;
    }

    if (visual.ellipsis) |ellipsis| {
        packet_visual.ellipsis = ellipsis;
    }

    if (visual.shadow) |shadow| {
        packet_visual.shadow = .{
            .blur = shadow.blur,
            .spread = shadow.spread,
            .top = shadow.top,
            .left = shadow.left,
        };
        var shadow_color = packet_visual.text_color;
        packColor(shadow.color, &shadow_color);
        packet_visual.shadow.color = shadow_color;
    }

    if (visual.cursor) |cursor| {
        packet_visual.cursor = cursor;
    }

    if (visual.text_decoration) |text_decoration| {
        packet_visual.text_decoration = .{
            .type = text_decoration.type,
            .style = text_decoration.style,
        };

        if (text_decoration.color) |color| {
            var text_decoration_color = packet_visual.text_decoration.color;
            packColor(color, &text_decoration_color);
            packet_visual.text_decoration.color = text_decoration_color;
        }
    }

    if (visual.blur) |blur| {
        packet_visual.blur = blur;
    }

    if (visual.caret) |caret| {
        packet_visual.caret = .{
            .type = caret.type,
        };
        if (caret.color == null) return;
        var caret_color = packed_visual.caret.color;
        packColor(caret.color.?, &caret_color);
        packet_visual.caret.color = caret_color;
    }

    if (visual.white_space) |white_space| {
        packet_visual.has_white_space = true;
        packet_visual.white_space = white_space;
    }

    if (visual.resize) |resize| {
        packet_visual.resize = resize;
    }
}

pub var packed_layout: types.PackedLayout = .{};
pub var packed_position: types.PackedPosition = .{};
pub var packed_margins_paddings: types.PackedMarginsPaddings = .{};
pub var packed_visual: types.PackedVisual = .{};
pub var packed_animations: types.PackedAnimations = .{};
pub var packed_interactive: types.PackedInteractive = .{};
pub var packed_transition: types.PackedTransition = .{};
pub var packed_layer: types.PackedLayer = .{ .Grid = .{} };
pub var packed_transforms: types.PackedTransforms = .{};

pub var element_style_hash_map: std.AutoHashMap(u32, [8]u32) = undefined;
pub var class_string_cache: std.AutoHashMap(u32, []const u8) = undefined;
pub var global_classes: [8]u32 = .{ 0, 0, 0, 0, 0, 0, 0, 0 };
var buf: [128]u8 = undefined;

/// Compares the old class hash with the new class hash and decrements the old class if it exists
fn compareClobber(old_optional: ?[8]u32, new_class_hash: u32, index: usize, class_type: ClassType) !void {
    if (old_optional) |old| {
        if (old[index] != new_class_hash and old[index] != 0) {
            try Vapor.class_cache.decrement(old[index]);
            try Vapor.class_cache.set(new_class_hash, class_type);
        }
        return;
    }

    // If the old class is null we need to create a new class
    try Vapor.class_cache.set(new_class_hash, class_type);
}

fn updateClassRefCounts(old: [8]u32, new: [8]u32) void {
    inline for (1..8) |i| {
        if (old[i] != new[i]) {
            if (old[i] != 0) Vapor.class_cache.decrement(old[i]) catch {};
            if (new[i] != 0) Vapor.class_cache.set(new[i], classTypeFromIndex(i)) catch {};
        }
    }
}

fn classTypeFromIndex(comptime i: usize) ClassType {
    return switch (i) {
        0 => .base,
        1 => .layout,
        2 => .position,
        3 => .margin_padding,
        4 => .visual,
        5 => .animation,
        6 => .interactive,
        7 => .transform,
        else => unreachable,
    };
}

pub fn buildClassString(
    field_ptrs: *const PackedFieldPtrs,
    current_open: *UINode,
    hash_l: u32,
    hash_p: u32,
    hash_m: u32,
    hash_v: u32,
    hash_a: u32,
    hash_i: u32,
    hash_t: u32,
    additonal_classes: ?[]const u8,
) !void {
    const hashes = [8]u32{ 0, hash_l, hash_p, hash_m, hash_v, hash_a, hash_i, hash_t };
    const old = current_open.style_hashes;
    if (std.mem.eql(u32, &old, &hashes)) return;

    // Compute combined hash for class string cache
    var combined: u32 = 0;
    inline for (hashes) |h| combined = combined *% 31 +% h;

    // Check class string cache
    if (class_string_cache.get(combined)) |cached| {
        current_open.class = cached;
        current_open.style_hashes = hashes;
        updateClassRefCounts(old, hashes);
        return;
    }

    var writer: Writer = undefined;
    var writer_buf: [512]u8 = undefined;
    writer.init(&writer_buf);
    // const old = element_style_hash_map.get(current_open.hash);

    // Then just:

    // var current_classes: ?[7][]const u8 = class_map.get(current_open.hash);

    if (current_open.class) |class| {
        writer.write(class) catch return error.CouldNotAllocate;
        writer.writeByte(' ') catch return error.CouldNotAllocate;
    }

    if (field_ptrs.layout_ptr != null and hash_l > 0) {
        const common = KeyGenerator.generateHashKey(&buf, hash_l, "lay");
        writer.write(common) catch return error.CouldNotAllocate;
        writer.writeByte(' ') catch return error.CouldNotAllocate;
        global_classes[1] = hash_l;
        try compareClobber(old, hash_l, 1, .layout);
    }

    if (field_ptrs.position_ptr != null and hash_p > 0) {
        const common = KeyGenerator.generateHashKey(&buf, hash_p, "pos");
        writer.write(common) catch return error.CouldNotAllocate;
        writer.writeByte(' ') catch return error.CouldNotAllocate;
        global_classes[2] = hash_p;
        try compareClobber(old, hash_p, 2, .position);
    }

    if (field_ptrs.margins_paddings_ptr != null and hash_m > 0) {
        const common = KeyGenerator.generateHashKey(&buf, hash_m, "mapa");
        writer.write(common) catch return error.CouldNotAllocate;
        writer.writeByte(' ') catch return error.CouldNotAllocate;
        global_classes[3] = hash_m;
        try compareClobber(old, hash_m, 3, .margin_padding);
    }

    if (field_ptrs.visual_ptr != null and hash_v > 0) {
        const common = KeyGenerator.generateHashKey(&buf, hash_v, "vis");
        writer.write(common) catch return error.CouldNotAllocate;
        writer.writeByte(' ') catch return error.CouldNotAllocate;
        global_classes[4] = hash_v;
        try compareClobber(old, hash_v, 4, .visual);
    }

    if (field_ptrs.animations_ptr != null and hash_a > 0) {
        const common = KeyGenerator.generateHashKey(&buf, hash_a, "anim");
        writer.write(common) catch return error.CouldNotAllocate;
        writer.writeByte(' ') catch return error.CouldNotAllocate;
        global_classes[5] = hash_a;
        try compareClobber(old, hash_a, 5, .animation);
    }

    if (field_ptrs.interactive_ptr != null and hash_i > 0) {
        const common = KeyGenerator.generateHashKey(&buf, hash_i, "intr");
        writer.write(common) catch return error.CouldNotAllocate;
        writer.writeByte(' ') catch return error.CouldNotAllocate;
        global_classes[6] = hash_i;
        try compareClobber(old, hash_i, 6, .interactive);
    }

    if (field_ptrs.transforms_ptr != null and hash_t > 0) {
        const common = KeyGenerator.generateHashKey(&buf, hash_t, "tran");
        writer.write(common) catch return error.CouldNotAllocate;
        writer.writeByte(' ') catch return error.CouldNotAllocate;
        global_classes[7] = hash_t;
        try compareClobber(old, hash_t, 7, .transform);
    }

    if (writer.buffer[0..writer.pos].len == 0) return;

    // We store the new class hash and list inside the element_style_hash_map
    // and clobber the old class if it exists this way we ensure each element has only one

    current_open.style_hashes = global_classes;
    // try element_style_hash_map.put(current_open.hash, .{
    //     global_classes[0],
    //     global_classes[1],
    //     global_classes[2],
    //     global_classes[3],
    //     global_classes[4],
    //     global_classes[5],
    //     global_classes[6],
    //     global_classes[7],
    // });

    const full_class = std.fmt.allocPrint(Vapor.arena(.persist), "{s}{s}", .{ writer.buffer[0..writer.pos], additonal_classes orelse "" }) catch |err| {
        Vapor.printlnErr("Could not create string {any} To many classes have been created\n", .{err});
        return err;
    };
    class_string_cache.put(combined, full_class) catch |err| {
        Vapor.printlnErr("Could not put class string {any}\n", .{err});
        unreachable;
    };
    current_open.class = full_class;
}

// TODO: Hashing the value is slow, we need to create a better hashmap system
// running a comparison on each st.mem.bytes is expensive
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
/// NOTE: creating pointers to anyhting and then hashing will corrupt the memory, sicne the pointers are not static,
/// they will appear different during runtime, for  hashing it should always be a static pointer
pub fn configureByNode(_: *UIContext, node: ?*UINode, elem_decl: ElemDecl) *UINode {
    const ui_node = Configuration.configureByNode(node, elem_decl);
    captureHash(ui_node);
    return ui_node;
}
pub fn configure(ui_ctx: *UIContext, elem_decl: ElemDecl) *UINode {
    const ui_node = Configuration.configure(ui_ctx, elem_decl);
    captureHash(ui_node);
    return ui_node;
    // const stack = ui_ctx.stack orelse unreachable;
    // const current_open = stack.ptr orelse unreachable;
    // const parent = current_open.parent orelse unreachable;
    // const style = elem_decl.style;
    //
    // if (elem_decl.elem_type == .ListItem) {
    //     if (parent.type != .List) {
    //         Vapor.printlnErr("ListItem must be a child of a List, Otherwise reconciliation will fail\n", .{});
    //     }
    // }
    //
    // if (style != null and style.?.id != null) {
    //     current_open.uuid = style.?.id.?;
    // }
    // current_open.finger_print +%= parent.finger_print;
    // current_open.finger_print +%= @intFromEnum(current_open.type);
    // if (elem_decl.elem_type == .Svg) {
    //     current_open.text = elem_decl.svg;
    //     current_open.finger_print +%= hashKey(elem_decl.svg);
    // } else if (elem_decl.text) |text| {
    //     current_open.text = text;
    //     current_open.finger_print +%= hashKey(text);
    // }
    //
    // if (elem_decl.hover_style_fields) |fields| {
    //     const hover_style_fields = Vapor.arena(.frame).create([]const types.StyleFields) catch unreachable;
    //     hover_style_fields.* = fields;
    //     current_open.hover_style_fields = hover_style_fields;
    // }
    //
    // if (elem_decl.text_field_params) |params| {
    //     const text_field_params = Vapor.arena(.frame).create(types.TextFieldParams) catch unreachable;
    //     text_field_params.* = params;
    //     current_open.text_field_params = text_field_params;
    //     switch (params) {
    //         .string => |string| {
    //             var value: []const u8 = "";
    //             if (string.value_ptr) |ptr| {
    //                 value = ptr[0..string.value_len];
    //             }
    //             var default_value: []const u8 = "";
    //             if (string.default_ptr) |ptr| {
    //                 default_value = ptr[0..string.default_len];
    //             }
    //             current_open.finger_print +%= hashKey(value);
    //             current_open.finger_print +%= hashKey(default_value);
    //             // current_open.finger_print +%= hashKey(string.default orelse "");
    //             current_open.finger_print +%= @intFromEnum(string.type);
    //         },
    //         else => {},
    //     }
    // }
    //
    // current_open.href = elem_decl.href;
    // current_open.type = elem_decl.elem_type;
    // current_open.name = elem_decl.name;
    //
    // if (current_open.href) |href| {
    //     current_open.finger_print +%= hashKey(href);
    // }
    //
    // // if (elem_decl.video) |video| {
    // //     current_open.video = video.*;
    // //     if (video.src) |src| {
    // //         current_open.finger_print +%= hashKey(src);
    // //     }
    // //     current_open.finger_print +%= @intFromBool(video.autoplay);
    // //     current_open.finger_print +%= @intFromBool(video.muted);
    // //     current_open.finger_print +%= @intFromBool(video.loop);
    // //     current_open.finger_print +%= @intFromBool(video.controls);
    // // }
    //
    // current_open.hash = hashKey(current_open.uuid);
    // current_open.props_hash = current_open.finger_print;
    // // current_open.finger_print +%= hashKey(current_open.uuid);
    //
    // if (style) |s| {
    //     var hash_l: u32 = 0;
    //     var hash_p: u32 = 0;
    //     var hash_mp: u32 = 0;
    //     var hash_v: u32 = 0;
    //     var hash_a: u32 = 0;
    //     var hash_i: u32 = 0;
    //     var hash_t: u32 = 0;
    //
    //     packed_position = .{};
    //     packed_layout = .{};
    //     packed_margins_paddings = .{};
    //     packed_visual = .{};
    //     packed_animations = .{};
    //     packed_interactive = .{};
    //     packed_transition = .{};
    //     packed_layer = .{ .Grid = .{} };
    //     packed_transforms = .{};
    //
    //     current_open.packed_field_ptrs = PackedFieldPtrs{};
    //     var hash_id: bool = false;
    //     if (s.style_id != null) {
    //         hash_id = true;
    //         current_open.class = s.style_id.?;
    //     }
    //
    //     // ** Packed Layout **
    //     if (s.layout != null or s.size != null or s.child_gap != null or s.aspect_ratio != null) {
    //         // packed_layout = .{};
    //         if (s.layout) |layout| {
    //             if (layout.x == .in_line and layout.y == .in_line) {
    //                 packed_layout.flex = .flow;
    //                 packed_layout.layout = layout;
    //             } else if (current_open.text != null) {
    //                 packed_layout.text_align = layout;
    //             } else {
    //                 packed_layout.flex = .flex;
    //                 packed_layout.layout = layout;
    //             }
    //         } else if (current_open.type == .FlexBox) {
    //             packed_layout.flex = .flex;
    //         }
    //         if (s.size) |size| packed_layout.size = size;
    //         if (s.child_gap) |child_gap| packed_layout.child_gap = child_gap;
    //         packed_layout.direction = s.direction;
    //         if (s.flex_wrap) |flex_wrap| packed_layout.flex_wrap = flex_wrap;
    //         if (s.scroll) |scroll| packed_layout.scroll = scroll;
    //         if (s.aspect_ratio) |aspect_ratio| packed_layout.aspect_ratio = aspect_ratio;
    //
    //         hash_l = std.hash.XxHash32.hash(0, std.mem.asBytes(&packed_layout));
    //         if (!hash_id) {
    //
    //             // These add a 1.5ms for 10000 nodes
    //             current_open.packed_field_ptrs.?.layout_ptr = getOrPutAndUpdateHashLayout(
    //                 hash_l,
    //                 packed_layout,
    //             ) catch unreachable;
    //         } else {
    //             const packed_layout_ptr = Packer.layouts_pool.create() catch unreachable;
    //             packed_layout_ptr.* = packed_layout;
    //             current_open.packed_field_ptrs.?.layout_ptr = packed_layout_ptr;
    //         }
    //     }
    //
    //     // ** Packed Position **
    //     if (s.position != null) {
    //         // packed_position = .{};
    //         if (s.position) |position| {
    //             packed_position.position_type = position.type;
    //             if (position.top) |top| packed_position.top = .{ .type = top.type, .value = top.value };
    //             if (position.right) |right| packed_position.right = .{ .type = right.type, .value = right.value };
    //             if (position.bottom) |bottom| packed_position.bottom = .{ .type = bottom.type, .value = bottom.value };
    //             if (position.left) |left| packed_position.left = .{ .type = left.type, .value = left.value };
    //             if (position.z_index) |z_index| packed_position.z_index = z_index;
    //         }
    //
    //         hash_p = std.hash.XxHash32.hash(0, std.mem.asBytes(&packed_position));
    //
    //         if (!hash_id) {
    //             current_open.packed_field_ptrs.?.position_ptr = getOrPutAndUpdateHashPosition(
    //                 hash_p,
    //                 packed_position,
    //             ) catch unreachable;
    //         } else {
    //             const packed_position_ptr = Packer.positions_pool.create() catch unreachable;
    //             packed_position_ptr.* = packed_position;
    //             current_open.packed_field_ptrs.?.position_ptr = packed_position_ptr;
    //         }
    //     }
    //
    //     // ** Packed Margins and Paddings **
    //     if (s.padding != null or s.margin != null) {
    //         // packed_margins_paddings = .{};
    //         if (s.padding) |padding| packed_margins_paddings.padding = padding;
    //         if (s.margin) |margin| packed_margins_paddings.margin = margin;
    //
    //         // This is an expensive operation, since the the visual hash is quite large
    //         hash_mp = std.hash.XxHash32.hash(0, std.mem.asBytes(&packed_margins_paddings));
    //         if (!hash_id) {
    //             current_open.packed_field_ptrs.?.margins_paddings_ptr = getOrPutAndUpdateHashMarginsPadding(
    //                 hash_mp,
    //                 packed_margins_paddings,
    //             ) catch unreachable;
    //         } else {
    //             const packed_margin_paddings_ptr = Packer.margins_paddings_pool.create() catch unreachable;
    //             packed_margin_paddings_ptr.* = packed_margins_paddings;
    //             current_open.packed_field_ptrs.?.margins_paddings_ptr = packed_margin_paddings_ptr;
    //         }
    //     }
    //
    //     if (s.visual != null or s.transform_origin != null) {
    //         if (s.transform_origin) |transform_origin| {
    //             packed_transforms.transform_origin = transform_origin;
    //         }
    //         if (s.visual) |visual| {
    //             if (visual.transform) |transform| {
    //                 packed_transforms.has_transform = true;
    //                 packed_transforms.transform.size_type = transform.size_type;
    //                 packed_transforms.transform.scale_size = transform.scale_size;
    //                 packed_transforms.transform.trans_x = transform.trans_x;
    //                 packed_transforms.transform.trans_y = transform.trans_y;
    //                 packed_transforms.transform.deg = transform.deg;
    //                 packed_transforms.transform.x = transform.x;
    //                 packed_transforms.transform.y = transform.y;
    //                 packed_transforms.transform.z = transform.z;
    //                 packed_transforms.transform.opacity = transform.opacity;
    //                 packed_transforms.transform.type_ptr = null;
    //                 packed_transforms.transform.type_len = transform.type.len;
    //
    //                 for (transform.type) |property| {
    //                     hash_t +%= hashKey(@tagName(property));
    //                 }
    //             }
    //         }
    //         hash_t +%= std.hash.XxHash32.hash(0, std.mem.asBytes(&packed_transforms));
    //         if (!hash_id) {
    //             if (Packer.transforms.get(hash_t) == null) {
    //                 // We only create the transform if there is no previous version
    //                 if (s.visual) |visual| {
    //                     if (visual.transform) |transform| {
    //                         var packed_transform: types.PackedTransform = undefined;
    //                         packed_transform.set(&transform);
    //                         packed_transforms.transform = packed_transform;
    //                     }
    //                 }
    //             }
    //             if (packed_transforms.has_transform or s.transform_origin != null) {
    //                 current_open.packed_field_ptrs.?.transforms_ptr = getOrPutAndUpdateHashTransform(
    //                     hash_t,
    //                     packed_transforms,
    //                 ) catch unreachable;
    //             }
    //         } else {
    //             const packed_transforms_ptr = Packer.transforms_pool.create() catch unreachable;
    //             // set is persitnant
    //             if (s.visual) |visual| {
    //                 if (visual.transform) |transform| {
    //                     var packed_transform: types.PackedTransform = undefined;
    //                     packed_transform.set(&transform);
    //                     packed_transforms.transform = packed_transform;
    //                 }
    //             }
    //
    //             packed_transforms_ptr.* = packed_transforms;
    //             current_open.packed_field_ptrs.?.transforms_ptr = packed_transforms_ptr;
    //         }
    //     }
    //
    //     // ** Packed Visual **
    //     if (s.visual != null or s.list_style != null or s.transform_origin != null) {
    //         if (current_open.type == .Button or current_open.type == .ButtonCycle or current_open.type == .CtxButton) {
    //             if (!packed_visual.has_border_thickeness) {
    //                 packed_visual.has_border_thickeness = true;
    //                 packed_visual.border_thickness = .all(0);
    //                 packed_visual.background = .{ .color = .{ .a = 0, .r = 0, .g = 0, .b = 0 }, .has_color = true };
    //             }
    //         }
    //         // packed_visual = .{};
    //
    //         if (s.visual) |visual| {
    //             checkVisual(&visual, &packed_visual, current_open.type);
    //         }
    //
    //         if (s.list_style) |list_style| packed_visual.list_style = list_style;
    //
    //         hash_v = std.hash.XxHash32.hash(0, std.mem.asBytes(&packed_visual));
    //
    //         if (s.font_family) |font_family| {
    //             if (font_family.len > 0) {
    //                 hash_v +%= hashKey(font_family);
    //             }
    //         }
    //
    //         if (s.visual) |visual| {
    //             if (visual.layer) |layer| {
    //                 var packed_layers = Vapor.arena(.frame).alloc(types.PackedLayer, 1) catch unreachable;
    //                 switch (layer) {
    //                     .Grid => |grid| {
    //                         packed_layer = .{ .Grid = .{} };
    //                         packed_layer.Grid.size = grid.size;
    //                         packed_layer.Grid.thickness = grid.thickness;
    //                         var grid_color = packed_layer.Grid.packed_color;
    //                         packColor(grid.color, &grid_color);
    //                         packed_layer.Grid.packed_color = grid_color;
    //                         packed_layers[0] = packed_layer;
    //                         hash_v +%= std.hash.XxHash32.hash(0, std.mem.asBytes(&packed_layer));
    //                     },
    //                     .Lines => |lines| {
    //                         packed_layer = .{ .Lines = .{} };
    //                         packed_layer.Lines.spacing = lines.spacing;
    //                         packed_layer.Lines.thickness = lines.thickness;
    //                         packed_layer.Lines.direction = lines.direction;
    //                         var lines_color = packed_layer.Lines.color;
    //                         packColor(lines.color, &lines_color);
    //                         packed_layer.Lines.color = lines_color;
    //                         packed_layers[0] = packed_layer;
    //                         hash_v +%= std.hash.XxHash32.hash(0, std.mem.asBytes(&packed_layer));
    //                     },
    //                     // .Image => {},
    //                     .Dot => |dots| {
    //                         packed_layer = .{ .Dot = .{} };
    //                         packed_layer.Dot.spacing = dots.spacing;
    //                         packed_layer.Dot.radius = dots.radius;
    //                         var dots_color = packed_layer.Dot.packed_color;
    //                         packColor(dots.color, &dots_color);
    //                         packed_layer.Dot.packed_color = dots_color;
    //                         packed_layers[0] = packed_layer;
    //                         hash_v +%= std.hash.XxHash32.hash(0, std.mem.asBytes(&packed_layer));
    //                     },
    //                     .Gradient => |gradient| {
    //                         packed_layer = .{ .Gradient = .{} };
    //                         packed_layer.Gradient.type = gradient.type;
    //                         packed_layer.Gradient.direction = gradient.direction;
    //                         var gradient_colors = Vapor.arena(.frame).alloc(types.PackedColor, gradient.colors.len) catch unreachable;
    //                         for (gradient.colors, 0..) |color, j| {
    //                             packColor(color, &gradient_colors[j]);
    //                         }
    //                         packed_layer.Gradient.colors_ptr = gradient_colors.ptr;
    //                         packed_layer.Gradient.colors_len = gradient_colors.len;
    //                         packed_layers[0] = packed_layer;
    //                         hash_v +%= std.hash.XxHash32.hash(0, std.mem.asBytes(&packed_layer));
    //                     },
    //                     else => {
    //                         Vapor.printlnSrcErr("Not implemented yet {any}", .{layer}, @src());
    //                         // @compileError("Not implemented yet");
    //                     },
    //                 }
    //                 packed_visual.packed_layers.items_ptr = packed_layers.ptr;
    //                 packed_visual.packed_layers.len = packed_layers.len;
    //                 //
    //                 // if (element_type == .Text) {
    //                 //     packet_visual.is_text_gradient = true;
    //                 // }
    //             } else if (visual.layers) |layers| {
    //                 var packed_layers = Vapor.arena(.frame).alloc(types.PackedLayer, layers.len) catch unreachable;
    //                 for (layers, 0..) |layer, i| {
    //                     switch (layer) {
    //                         .Grid => |grid| {
    //                             packed_layer = .{ .Grid = .{} };
    //                             packed_layer.Grid.size = grid.size;
    //                             packed_layer.Grid.thickness = grid.thickness;
    //                             var grid_color = packed_layer.Grid.packed_color;
    //                             packColor(grid.color, &grid_color);
    //                             packed_layer.Grid.packed_color = grid_color;
    //                             packed_layers[i] = packed_layer;
    //                             hash_v +%= std.hash.XxHash32.hash(0, std.mem.asBytes(&packed_layer));
    //                         },
    //                         .Lines => |lines| {
    //                             packed_layer = .{ .Lines = .{} };
    //                             packed_layer.Lines.spacing = lines.spacing;
    //                             packed_layer.Lines.thickness = lines.thickness;
    //                             packed_layer.Lines.direction = lines.direction;
    //                             var lines_color = packed_layer.Lines.color;
    //                             packColor(lines.color, &lines_color);
    //                             packed_layer.Lines.color = lines_color;
    //                             packed_layers[i] = packed_layer;
    //                             hash_v +%= std.hash.XxHash32.hash(0, std.mem.asBytes(&packed_layer));
    //                         },
    //                         // .Image => {},
    //                         .Dot => |dots| {
    //                             packed_layer = .{ .Dot = .{} };
    //                             packed_layer.Dot.spacing = dots.spacing;
    //                             packed_layer.Dot.radius = dots.radius;
    //                             var dots_color = packed_layer.Dot.packed_color;
    //                             packColor(dots.color, &dots_color);
    //                             packed_layer.Dot.packed_color = dots_color;
    //                             packed_layers[i] = packed_layer;
    //                             hash_v +%= std.hash.XxHash32.hash(0, std.mem.asBytes(&packed_layer));
    //                         },
    //                         .Gradient => |gradient| {
    //                             packed_layer = .{ .Gradient = .{} };
    //                             packed_layer.Gradient.type = gradient.type;
    //                             packed_layer.Gradient.direction = gradient.direction;
    //                             var gradient_colors = Vapor.arena(.frame).alloc(types.PackedColor, gradient.colors.len) catch unreachable;
    //                             for (gradient.colors, 0..) |color, j| {
    //                                 packColor(color, &gradient_colors[j]);
    //                             }
    //                             packed_layer.Gradient.colors_ptr = gradient_colors.ptr;
    //                             packed_layer.Gradient.colors_len = gradient_colors.len;
    //                             packed_layers[i] = packed_layer;
    //                             hash_v +%= std.hash.XxHash32.hash(0, std.mem.asBytes(&packed_layer));
    //                         },
    //                         else => {
    //                             Vapor.printlnSrcErr("Not implemented yet {any}", .{layer}, @src());
    //                             // @compileError("Not implemented yet");
    //                         },
    //                     }
    //                 }
    //                 packed_visual.packed_layers.items_ptr = packed_layers.ptr;
    //                 packed_visual.packed_layers.len = packed_layers.len;
    //             }
    //         }
    //
    //         if (s.transition) |transition| {
    //             packed_visual.has_transitions = true;
    //             packed_transition.delay = transition.delay;
    //             packed_transition.duration = transition.duration;
    //             packed_transition.timing = transition.timing;
    //             packed_transition.properties_len = transition.properties.len;
    //             packed_transition.properties_ptr = null;
    //             packed_visual.transitions = packed_transition;
    //             for (transition.properties) |property| {
    //                 hash_v +%= hashKey(@tagName(property));
    //             }
    //         }
    //
    //         if (s.font_family) |font_family| {
    //             if (font_family.len > 0) {
    //                 const ff_slice = Vapor.arena(.frame).dupe(u8, font_family) catch |err| {
    //                     Vapor.printlnErr("Could not allocate font family {any}\n", .{err});
    //                     unreachable;
    //                 };
    //                 packed_visual.font_family_ptr = ff_slice.ptr;
    //                 packed_visual.font_family_len = ff_slice.len;
    //             }
    //         }
    //
    //         if (!hash_id) {
    //             if (Packer.visuals.get(hash_v) == null) {
    //                 // We only create the transition if there is no previous version
    //                 if (s.transition) |transition| {
    //                     // set is persitnant
    //                     packed_transition.set(&transition);
    //                     packed_visual.transitions = packed_transition;
    //                 }
    //             }
    //             current_open.packed_field_ptrs.?.visual_ptr = getOrPutAndUpdateHashVisual(
    //                 hash_v,
    //                 packed_visual,
    //             ) catch unreachable;
    //         } else {
    //             const packed_visual_ptr = Packer.visuals_pool.create() catch unreachable;
    //             if (s.transition) |transition| {
    //                 // set is persitnant
    //                 packed_transition.set(&transition);
    //                 packed_visual.transitions = packed_transition;
    //             }
    //
    //             packed_visual_ptr.* = packed_visual;
    //             current_open.packed_field_ptrs.?.visual_ptr = packed_visual_ptr;
    //         }
    //     }
    //
    //     // ** Packed Animations and Interactive **
    //     if (s.transition != null or s.interactive != null or elem_decl.animation_enter != null or elem_decl.animation_exit != null) {
    //         if (s.interactive) |interactive| {
    //             packed_interactive = .{};
    //             if (interactive.hover) |hover| {
    //                 if (hover.transform) |transform| {
    //                     packed_animations.has_transform = true;
    //                     packed_animations.transform.size_type = transform.size_type;
    //                     packed_animations.transform.scale_size = transform.scale_size;
    //                     packed_animations.transform.trans_x = transform.trans_x;
    //                     packed_animations.transform.trans_y = transform.trans_y;
    //                     packed_animations.transform.deg = transform.deg;
    //                     packed_animations.transform.x = transform.x;
    //                     packed_animations.transform.y = transform.y;
    //                     packed_animations.transform.z = transform.z;
    //                     packed_animations.transform.opacity = transform.opacity;
    //                     packed_animations.transform.type_ptr = null;
    //                     packed_animations.transform.type_len = transform.type.len;
    //
    //                     for (transform.type) |property| {
    //                         hash_i +%= hashKey(@tagName(property));
    //                     }
    //                 }
    //                 var packed_hover: types.PackedVisual = .{};
    //                 checkVisual(&hover, &packed_hover, current_open.type);
    //                 packed_interactive.has_hover = true;
    //                 packed_interactive.hover = packed_hover;
    //             }
    //
    //             if (interactive.hover_position) |hover_position| {
    //                 packed_interactive.has_hover_position = true;
    //                 packed_interactive.hover_position = .{};
    //                 packed_interactive.hover_position.position_type = hover_position.type;
    //                 if (hover_position.top) |top| packed_interactive.hover_position.top = .{ .type = top.type, .value = top.value };
    //                 if (hover_position.right) |right| packed_interactive.hover_position.right = .{ .type = right.type, .value = right.value };
    //                 if (hover_position.bottom) |bottom| packed_interactive.hover_position.bottom = .{ .type = bottom.type, .value = bottom.value };
    //                 if (hover_position.left) |left| packed_interactive.hover_position.left = .{ .type = left.type, .value = left.value };
    //                 if (hover_position.z_index) |z_index| packed_interactive.hover_position.z_index = z_index;
    //             }
    //
    //             if (interactive.focus) |focus| {
    //                 var packed_focus: types.PackedVisual = .{};
    //                 checkVisual(&focus, &packed_focus, current_open.type);
    //                 packed_interactive.has_focus = true;
    //                 packed_interactive.focus = packed_focus;
    //             }
    //
    //             hash_i = std.hash.XxHash32.hash(0, std.mem.asBytes(&packed_interactive));
    //
    //             if (!hash_id) {
    //                 current_open.packed_field_ptrs.?.interactive_ptr = getOrPutAndUpdateHashInteractive(
    //                     hash_i,
    //                     packed_interactive,
    //                 ) catch unreachable;
    //             } else {
    //                 const packed_interactive_ptr = Packer.interactives_pool.create() catch unreachable;
    //                 packed_interactive_ptr.* = packed_interactive;
    //                 current_open.packed_field_ptrs.?.interactive_ptr = packed_interactive_ptr;
    //             }
    //
    //             hash_a = std.hash.XxHash32.hash(0, std.mem.asBytes(&packed_animations));
    //
    //             if (!hash_id) {
    //                 if (Packer.animations.get(hash_a) == null) {
    //                     // We only create the transform if there is no previous version
    //                     if (interactive.hover) |hover| {
    //                         if (hover.transform) |transform| {
    //                             var packed_transform: types.PackedTransform = undefined;
    //                             packed_transform.set(&transform);
    //                             packed_animations.transform = packed_transform;
    //                         }
    //                     }
    //                 }
    //                 if (packed_animations.has_transform) {
    //                     current_open.packed_field_ptrs.?.animations_ptr = getOrPutAndUpdateHashAnimation(
    //                         hash_a,
    //                         packed_animations,
    //                     ) catch unreachable;
    //                 }
    //             }
    //         } else {
    //             if (elem_decl.animation_enter) |animation_enter| {
    //                 current_open.animation_enter = animation_enter;
    //                 packed_animations.has_animation_enter = true;
    //                 packed_animations.animation_enter = animation_enter;
    //             }
    //             if (elem_decl.animation_exit) |animation_exit| {
    //                 current_open.animation_exit = animation_exit;
    //                 packed_animations.has_animation_exit = true;
    //                 packed_animations.animation_exit = animation_exit;
    //             }
    //
    //             hash_a = std.hash.XxHash32.hash(0, std.mem.asBytes(&packed_animations));
    //
    //             if (!hash_id) {
    //                 if (packed_animations.has_animation_exit or packed_animations.has_animation_enter) {
    //                     current_open.packed_field_ptrs.?.animations_ptr = getOrPutAndUpdateHashAnimation(
    //                         hash_a,
    //                         packed_animations,
    //                     ) catch unreachable;
    //                 }
    //             }
    //         }
    //     }
    //
    //     current_open.finger_print +%= hash_l;
    //     current_open.finger_print +%= hash_p;
    //     current_open.finger_print +%= hash_mp;
    //     current_open.finger_print +%= hash_v;
    //     current_open.finger_print +%= hash_a;
    //     current_open.finger_print +%= hash_i;
    //     current_open.finger_print +%= hash_t;
    //
    //     current_open.style_hash +%= hash_l;
    //     current_open.style_hash +%= hash_p;
    //     current_open.style_hash +%= hash_mp;
    //     current_open.style_hash +%= hash_v;
    //     current_open.style_hash +%= hash_a;
    //     current_open.style_hash +%= hash_i;
    //     current_open.style_hash +%= hash_t;
    //
    //     if (s.style_id != null) {
    //         const class = current_open.class.?;
    //         const new_class_hash = hashKey(class);
    //         _ = Vapor.class_cache.get(new_class_hash) orelse {
    //             Vapor.class_cache.set(new_class_hash, .defined) catch unreachable;
    //             Vapor.generator.writeNodeStyle(current_open);
    //         };
    //     } else {
    //         // This adds 2ms for 10000 nodes
    //         buildClassString(
    //             &current_open.packed_field_ptrs.?,
    //             current_open,
    //             hash_l,
    //             hash_p,
    //             hash_mp,
    //             hash_v,
    //             hash_a,
    //             hash_i,
    //             hash_t,
    //         ) catch |err| {
    //             Vapor.printlnErr("Could not build class string {any}\n", .{err});
    //         };
    //     }
    // }
    //
    // if (current_open.type == .Hooks or current_open.type == .HooksCtx) {
    //     current_open.hooks = elem_decl.hooks;
    // }
    //
    // current_open.state_type = elem_decl.state_type;
    // current_open.aria_label = elem_decl.aria_label;
    // current_open.alt = elem_decl.alt;
    //
    // return current_open;
}

// close is breadth post order first
pub fn close(ui_ctx: *UIContext) void {
    // const time = Vapor.nowMs();
    // if (uuid_depth > 0) {
    //     uuid_depth -= 1;
    // } else {
    //     Vapor.printlnSrcErr("Depth is negative {}", .{uuid_depth}, @src());
    // }
    ui_ctx.stackPop();
}

pub fn endContext(ui_ctx: *UIContext) void {
    const root = ui_ctx.root.?;
    const render_cmd: *RenderCommand = ui_ctx.render_cmd_memory_pool.create() catch unreachable;
    Vapor.frame_arena.incrementCommandCount();
    render_cmd.* = .{
        .elem_type = root.type,
        .href = "",
        // .style = root.style,
        .hooks = root.hooks,
        .node_ptr = root,
        .id = root.uuid,
        .index = 0,
        .has_children = true,
    };
    root.dirty = false;

    const tree: *CommandsTree = ui_ctx.tree_memory_pool.create() catch unreachable;
    tree.* = .{
        .node = render_cmd,
        .children = std.ArrayListUnmanaged(*CommandsTree).initCapacity(Vapor.arena(.frame), 4) catch |err| {
            Vapor.printlnSrcErr("Could not ensure capacity {any}\n", .{err}, @src());
            unreachable;
        },
    };
    ui_ctx.ui_tree = tree;
}

pub fn createStack(ui_ctx: *UIContext, parent: *UINode) void {
    if (parent.children.items.len == 0) return;

    for (parent.children.items) |child| {
        ui_ctx.stackRegister(child) catch {
            Vapor.println("Could not stack register\n", .{});
            unreachable;
        };
    }
    var i = parent.children.items.len - 1;
    while (true) {
        const child = parent.children.items[i];
        if (i == 0) {
            ui_ctx.createStack(child);
            break;
        } else {
            ui_ctx.createStack(child);
        }
        i -= 1;
    }
}

// Breadth first search
// This calcualtes the positions;
var depth: usize = 0;
pub fn traverseChildren(ui_ctx: *UIContext, parent_op: ?*UINode, ui_tree_parent: *CommandsTree) !void {
    if (parent_op) |parent| {
        const parent_children = parent.children orelse return;
        if (parent_children.items.len > 0) {
            ui_tree_parent.children = std.ArrayListUnmanaged(*CommandsTree).initCapacity(Vapor.frame_arena.scratch_arena.allocator(), 4) catch |err| {
                Vapor.printlnSrcErr("Could not ensure capacity {any}\n", .{err}, @src());
                unreachable;
            };
            depth += 1;
            for (parent_children.items) |child| {
                const render_cmd: *RenderCommand = Vapor.frame_arena.commandAlloc() orelse return error.CommandAllocFailed;
                Vapor.frame_arena.incrementCommandCount();
                render_cmd.* = .{
                    .elem_type = child.type,
                    .text = child.text orelse "",
                    .href = child.href orelse "",
                    .id = child.uuid,
                    .index = child.index,
                    .hooks = child.hooks,
                    .node_ptr = child,
                    .render_type = child.state_type,
                    .has_children = child.children != null,
                    .hash = child.hash,
                    .style_changed = child.style_changed,
                    .props_changed = child.props_changed,
                    // .tooltip = child.tooltip,
                };

                if (child.packed_field_ptrs) |ptrs| {
                    if (ptrs.interactive_ptr) |interactive| {
                        render_cmd.hover = interactive.has_hover;
                        render_cmd.focus = interactive.has_focus;
                        render_cmd.focus_within = interactive.has_focus_within;
                    }
                    if (child.class) |id| {
                        render_cmd.class = id;
                    }
                }

                if (child.state_type == .added) {
                    // These are added nodes, in the order of the tree traversal, the top most nodes, is the last
                    Vapor.added_nodes.append(render_cmd.*) catch |err| {
                        Vapor.printlnSrcErr("Could not append dirty node {any}\n", .{err}, @src());
                        unreachable;
                    };
                } else if (child.dirty) {
                    Vapor.dirty_nodes.append(render_cmd.*) catch |err| {
                        Vapor.printlnSrcErr("Could not append dirty node {any}\n", .{err}, @src());
                        unreachable;
                    };
                }

                const tree: *CommandsTree = Vapor.frame_arena.treeNodeAlloc() orelse return error.TreeNodeAllocFailed;
                tree.* = .{
                    .node = render_cmd,
                    .children = std.ArrayListUnmanaged(*CommandsTree).initCapacity(Vapor.arena(.frame), 4) catch |err| {
                        Vapor.printlnSrcErr("Could not ensure capacity {any}\n", .{err}, @src());
                        unreachable;
                    },
                };
                ui_tree_parent.children.ensureUnusedCapacity(Vapor.frame_arena.scratch_arena.allocator(), 4) catch |err| {
                    Vapor.printlnSrcErr("Could not ensure capacity {any}\n", .{err}, @src());
                    unreachable;
                };
                ui_tree_parent.children.appendBounded(tree) catch unreachable;
                // if (child.state_type == .animation) {
                //     const class_name = child.style.?.child_styles.?[0].style_id;
                //     Vapor.addToClassesList(child.uuid, class_name);
                // }
            }
            for (parent_children.items, 0..) |child, j| {
                try ui_ctx.traverseChildren(child, ui_tree_parent.children.items[j]);
            }
            depth -= 1;
        }
    }
}
pub fn traverse(ui_ctx: *UIContext) void {
    ui_ctx.traverseChildren(ui_ctx.root, ui_ctx.ui_tree.?) catch |err| {
        Vapor.printlnSrcErr("Could not traverse children {any}", .{err}, @src());
    };
}

/// Finds the first index of a `needle` within a `haystack` using SIMD acceleration.
/// Returns the starting byte index of the `needle` if found, otherwise `null`.
pub fn indexOf(haystack: []const u8, needle: []const u8) ?usize {
    // Basic edge cases
    if (needle.len == 0) return 0;
    if (haystack.len < needle.len) return null;

    const first_char = needle[0];
    const last_possible_start = haystack.len - needle.len;

    // SIMD setup for 16-byte vectors (128-bit)
    const vec_len = 16;
    const Vec16 = @Vector(vec_len, u8);

    // Create a vector where every element is the first character of the needle.
    // This will be used to compare against 16 bytes of the haystack at once.
    const first_char_vec: Vec16 = @splat(first_char);

    var i: usize = 0;

    // Main SIMD loop. It processes the haystack in 16-byte chunks.
    // The loop condition ensures we don't read past the end of the haystack.
    while (i + vec_len <= haystack.len) : (i += vec_len) {
        // Load a 16-byte chunk from the haystack into a vector.
        const chunk = haystack[i..][0..vec_len].*;
        const haystack_vec: Vec16 = @bitCast(chunk);

        // Perform 16 parallel comparisons. The result is a mask vector.
        const eq_mask = haystack_vec == first_char_vec;

        // Convert the mask vector into a single u16 integer. Each bit in this
        // integer corresponds to a match for the first character in the chunk.
        var bits: u16 = @bitCast(eq_mask);

        // If bits is 0, no potential matches were found in this chunk, so we continue.
        if (bits == 0) continue;

        // If there are potential matches, iterate through each of them.
        while (bits != 0) {
            // `@ctz` (count trailing zeros) finds the index of the first match in our 16-byte chunk.uituint
            const offset = @ctz(bits);
            const potential_idx = i + offset;

            // Ensure the potential match is not too close to the end of the haystack
            // for the full needle to fit.
            if (potential_idx > last_possible_start) {
                // Since offsets are processed in increasing order, no further
                // matches in this chunk can be valid.
                break;
            }

            // Now, verify if the full substring matches at this position.
            if (std.mem.eql(u8, haystack[potential_idx..][0..needle.len], needle)) {
                // We found it!
                return potential_idx;
            }

            // Clear the bit we just checked so we can find the next one.
            // This is a common trick to iterate over set bits.
            bits &= (bits - 1);
        }
    }

    // Scalar fallback loop for the remaining part of the haystack that didn't
    // fit into a full 16-byte chunk.
    while (i <= last_possible_start) : (i += 1) {
        // A simple check is sufficient here.
        if (haystack[i] == first_char and std.mem.eql(u8, haystack[i..][0..needle.len], needle)) {
            return i;
        }
    }

    return null;
}
