const std = @import("std");
const Fabric = @import("Fabric.zig");
const print = std.debug.print;
const wrapText = @import("Fabric.zig").wrapText;
const stdout = @import("Fabric.zig").stdout;
const helpers = @import("helpers.zig");
const println = @import("Fabric.zig").println;
const createElement = @import("Fabric.zig").createElement;
const KeyGenerator = @import("Key.zig").KeyGenerator;

const types = @import("types.zig");

const Item = struct {
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

pub const UIContext = @This();
allocator: *std.mem.Allocator = undefined,
root: ?*UINode = null,
current_parent: ?*UINode = null,
stack: ?*Item = null,
root_stack_ptr: ?*Item = null,
memory_pool: std.heap.MemoryPool(Item),
render_cmd_memory_pool: std.heap.MemoryPool(RenderCommand),
tree_memory_pool: std.heap.MemoryPool(CommandsTree),
text_elements: std.ArrayList(*UINode),
percents: std.ArrayList(*UINode),
shrinkable: std.ArrayList(*UINode),
current_padding_top: f32 = 0,
current_padding_left: f32 = 0,
current_offset: f32 = 0,
sw: f32 = 0,
sh: f32 = 0,
ui_tree: ?*CommandsTree = null,
uuids: std.StringHashMap(*UINode),

pub const CommandsTree = struct {
    node: *RenderCommand,
    children: std.ArrayList(*CommandsTree),
};

pub const UINode = struct {
    dirty: bool = true,
    parent: ?*UINode = null,
    type: EType = EType.FlexBox,
    style: Style = undefined,
    children: std.ArrayList(*UINode) = undefined,
    calculated_x: f32 = 0,
    calculated_y: f32 = 0,
    calculated_width: f32 = 0,
    calculated_height: f32 = 0,
    min_width: f32 = 0,
    min_height: f32 = 0,
    text: []const u8 = "",
    uuid: []const u8 = "",
    href: []const u8 = "",
    show: bool = true,
    hooks: HooksIds = .{},
    input_params: ?InputParams = null,
    event_type: ?types.EventType = null,
    dynamic: types.StateType = .pure,

    pub fn init(parent: ?*UINode, etype: EType, allocator: *std.mem.Allocator) !*UINode {
        const node = try allocator.create(UINode);
        node.* = .{
            .parent = parent,
            .type = etype,
            .children = std.ArrayList(*UINode).init(allocator.*),
        };
        return node;
    }

    pub fn deinit(ui_node: *UINode) void {
        ui_node.children.deinit();
    }

    pub fn addChild(parent: *UINode, child: *UINode) !void {
        parent.children.append(child) catch {
            return error.ChildArrayOutOfMemory;
        };
    }
};

pub fn initLayout(ui_ctx: *UIContext, allocator: *std.mem.Allocator, width: f32, height: f32) !void {
    ui_ctx.* = .{
        .allocator = allocator,
        .memory_pool = std.heap.MemoryPool(Item).init(allocator.*),
        .render_cmd_memory_pool = std.heap.MemoryPool(RenderCommand).init(allocator.*),
        .tree_memory_pool = std.heap.MemoryPool(CommandsTree).init(allocator.*),
        .text_elements = std.ArrayList(*UINode).init(allocator.*),
        .percents = std.ArrayList(*UINode).init(allocator.*),
        .uuids = std.StringHashMap(*UINode).init(allocator.*),
        .shrinkable = std.ArrayList(*UINode).init(allocator.*),
        .sw = width,
        .sh = height,
    };

    // Either change the init function to return a pointer directly
    const node_ptr = try UINode.init(null, EType.Block, allocator);
    node_ptr.uuid = "fabric_root_id";
    node_ptr.min_width = width;
    node_ptr.min_height = height;
    node_ptr.calculated_width = width;
    node_ptr.calculated_height = height;
    node_ptr.dirty = false;
    ui_ctx.root = node_ptr;
    ui_ctx.root.?.style.width.type = .percent;
    ui_ctx.root.?.style.height.type = .percent;
    ui_ctx.root.?.style.width.size.minmax.min = 1;
    ui_ctx.root.?.style.height.size.minmax.min = 1;
    ui_ctx.root.?.style.width.size.minmax.max = 1;
    ui_ctx.root.?.style.height.size.minmax.max = 1;

    const item: *Item = try ui_ctx.allocator.create(Item);
    item.* = .{
        .ptr = node_ptr,
    };
    ui_ctx.root_stack_ptr = item;
    ui_ctx.stack = item;
    // try ui_ctx.stackRegister(node_ptr);
    // ui_ctx.uuids.put(node_ptr.uuid, node_ptr) catch |err| {
    //     println("Error out of Memory, {any}\n", .{err});
    //     return;
    // };
}

fn recurseDestroyItems(ui_ctx: *UIContext) void {
    const current_stack = ui_ctx.stack;
    if (current_stack) |stack| {
        ui_ctx.stackPop();
        ui_ctx.recurseDestroyItems();
        if (stack.ptr) |ptr| {
            if (ptr.type == .AllocText) {
                Fabric.allocator_global.free(ptr.text);
            }
            ui_ctx.allocator.destroy(ptr);
        }
        // ui_ctx.memory_pool.destroy(stack);
    }
}

pub fn deinit(ui_ctx: *UIContext) void {
    ui_ctx.recurseDestroy(ui_ctx.root.?);
    // ui_ctx.memory_pool.destroy(ui_ctx.root_stack_ptr.?);
    ui_ctx.memory_pool.deinit();

    ui_ctx.recurseDestroyTree(ui_ctx.ui_tree.?);
    ui_ctx.render_cmd_memory_pool.deinit();

    // now clear the pointers and lists
    ui_ctx.root.?.children = undefined;
    ui_ctx.root = null;
    ui_ctx.ui_tree = null;
}

fn recurseDestroyTree(ui_ctx: *UIContext, tree: *CommandsTree) void {
    for (tree.children.items) |child| {
        ui_ctx.recurseDestroyTree(child);
    }
    tree.children.deinit();
    ui_ctx.allocator.destroy(tree.node);
    ui_ctx.allocator.destroy(tree);
    tree.children = undefined;
    tree.node = undefined;
}

fn recurseDestroy(ui_ctx: *UIContext, ui_node: *UINode) void {
    for (ui_node.children.items) |child| {
        ui_ctx.recurseDestroy(child);
    }
    if (ui_node.type == .AllocText) {
        Fabric.allocator_global.free(ui_node.text);
    }
    if (std.mem.eql(u8, ui_node.uuid[ui_node.uuid.len - 4 ..], "genk")) {
        Fabric.allocator_global.free(ui_node.uuid);
    }
    ui_node.deinit();
    ui_ctx.allocator.destroy(ui_node);
    ui_node.children = undefined;
}

// pub fn createRoot(ui_ctx: *UIContext, elem_decl: ElemDecl) !*UINode {
//     const node_ptr = try UINode.init(null, elem_decl.elem_type, ui_ctx.allocator);
//     node_ptr.uuid = "fabric_root_id";
//
//     const item: *Item = try ui_ctx.memory_pool.create();
//     item.* = .{
//         .ptr = node_ptr,
//     };
//     ui_ctx.root_stack_ptr = item;
//     ui_ctx.stack = item;
//     try ui_ctx.stackRegister(node_ptr);
//
//     ui_ctx.root = node_ptr;
//     return node_ptr;
// }

pub fn stackRegister(ui_ctx: *UIContext, ui_node: *UINode) !void {
    const item: *Item = try ui_ctx.allocator.create(Item);
    const current_stack = ui_ctx.stack;
    item.* = .{
        .ptr = ui_node,
    };

    if (current_stack) |stack| {
        item.next = stack;
    }

    ui_ctx.stack = item;
}

pub fn stackPop(ui_ctx: *UIContext) void {
    const current_stack = ui_ctx.stack orelse return;
    ui_ctx.stack = current_stack.next;
    ui_ctx.allocator.destroy(current_stack);
}

var uuid_depth: usize = 0;
var current_tree: usize = 0;
fn setUUID(parent: *UINode, child: *UINode) void {
    uuid_depth += 1;
    const count = Fabric.key_depth_map.get(parent.uuid) orelse blk: {
        break :blk 0;
    };
    // Set the keyGenerator count
    KeyGenerator.setCount(count);
    // KeyGenerator.resetCounter();
    const index: usize = uuid_depth;
    if (child.uuid.len > 0) {
        // index += i;
    } else {
        const key = KeyGenerator.generateKey(
            child.type,
            parent.uuid,
            parent.style,
            index,
            parent,
            &Fabric.allocator_global,
        );
        child.uuid = key;
        // Fabric.println("{s}", .{child.uuid});
        // we add this so that animations are sepeate, we need to be careful though since
        // if a user does not specifc a id for a class, and the  rerender tree has the same id
        // and then previous one uses an animation then that transistion and animation will be
        // applied to the new parent since it has the same class name and styling
    }
    // Put the new keygenerator count in to the key_dpeht_map;
    Fabric.key_depth_map.put(parent.uuid, KeyGenerator.getCount()) catch |err| {
        Fabric.printlnSrcErr("{any}", .{err}, @src());
    };
    // Fabric.printlnSrcErr("Hellllll", .{}, @src());
}

// Open takes a current stack and adds the elements depth first search
// Open and close get called in sequence
// depth first search
// open pluse close create a depth first search algo
// and breadth first post order
pub fn open(ui_ctx: *UIContext, elem_decl: ElemDecl) !*UINode {
    const stack = ui_ctx.stack.?;
    // Parent node
    const current_open = stack.ptr orelse unreachable;
    // const style = elem_decl.style;

    // var node_uuid: []const u8 = "";
    // if (style.id == null) {
    //     const parent_uuid = current_open.uuid;
    //     const key = KeyGenerator.generateKey(elem_decl.elem_type, parent_uuid, elem_decl.style, null);
    //     node_uuid = key;
    // } else {
    //     node_uuid = style.id.?;
    // }

    // const node = ui_ctx.uuids.get(node_uuid) orelse {
    const node = try UINode.init(current_open, elem_decl.elem_type, ui_ctx.allocator);

    node.dynamic = elem_decl.dynamic;
    // node.uuid = node_uuid;

    // Here we register the node to be open
    if (!current_open.show) {
        node.show = current_open.show;
    } else {
        node.show = elem_decl.show;
    }

    // node.show = true;
    try current_open.addChild(node);
    try ui_ctx.stackRegister(node);

    // uuid_depth += 1;
    node.uuid = elem_decl.style.id orelse "";
    setUUID(current_open, node);
    // ui_ctx.uuids.put(node_uuid, node) catch |err| {
    //     println("Error out of Memory, {any}\n", .{err});
    //     return current_open;
    // };
    return node;
    // };
    // Here we register the node to be open
    // if (!current_open.show) {
    //     node.show = current_open.show;
    // } else {
    //     node.show = elem_decl.show;
    // }
    // try ui_ctx.stackRegister(node);
    // return node;
}

fn reset(_: *UIContext, ui_node: *UINode) void {
    const style = ui_node.style;
    ui_node.calculated_width = style.width.size.minmax.max;
    ui_node.calculated_height = style.height.size.minmax.max;
    ui_node.min_width = style.width.size.minmax.min;
    ui_node.min_height = style.height.size.minmax.min;
    if (style.position != null) {
        ui_node.calculated_x = style.position.?.x;
        ui_node.calculated_y = style.position.?.y;
    }
    ui_node.style = style;
    ui_node.type = ui_node.type;
    ui_node.style = style;
    // }
}

pub fn configure(ui_ctx: *UIContext, elem_decl: ElemDecl) *UINode {
    const stack = ui_ctx.stack orelse unreachable;
    const current_open = stack.ptr orelse unreachable;
    const style = elem_decl.style;
    //
    // if (style.id == null) {
    //     const parent = current_open.parent orelse {
    //         println("PARENT UUID IS NULL\n", .{});
    //         return current_open;
    //     };
    //     const parent_uuid = parent.uuid;
    //     const key = KeyGenerator.generateKey(elem_decl.elem_type, parent_uuid, elem_decl.style, null);
    //     current_open.uuid = key;
    // } else {
    if (style.id != null) {
        current_open.uuid = style.id.?;
    }
    // }

    if (elem_decl.elem_type == .Svg) {
        current_open.text = elem_decl.svg;
    } else if (elem_decl.elem_type == .Input) {
        current_open.input_params = elem_decl.input_params.?;
        current_open.text = elem_decl.text;
    } else if (elem_decl.text.len > 0) {
        current_open.text = elem_decl.text;
    }

    current_open.calculated_width = style.width.size.minmax.max;
    current_open.calculated_height = style.height.size.minmax.max;
    current_open.min_width = style.width.size.minmax.min;
    current_open.min_height = style.height.size.minmax.min;
    if (style.position != null) {
        current_open.calculated_x = style.position.?.x;
        current_open.calculated_y = style.position.?.y;
    }
    current_open.href = elem_decl.href;

    current_open.type = elem_decl.elem_type;
    current_open.style = style;
    current_open.hooks = elem_decl.hooks;
    current_open.dynamic = elem_decl.dynamic;

    return current_open;
    // createElement(
    //     current_open.uuid[0..].ptr,
    //     36,
    //     @intFromEnum(current_open.type),
    //     current_open.style.btn_id,
    //     currentruet_open.text.ptr,
    //     current_open.text.len,
    // );
}

// close is breadth post order first
pub fn fitWidths(ui_ctx: *UIContext) void {
    while (ui_ctx.stack) |stack| {
        const ui_node = stack.ptr orelse unreachable;

        // if (!ui_node.show) {
        //     ui_ctx.stackPop();
        //     return;
        // }

        const parent_op = ui_node.parent;
        const padding = ui_node.style.padding;
        const margin = ui_node.style.margin;
        const element = ui_node;
        // print("Config Node Width{any}{any}\n", .{ ui_node.style.width.size.minmax.max, ui_node.type });
        // element.calculated_width = ui_node.style.width.size.minmax.max;
        const padding_w: f32 = @floatFromInt(padding.left + padding.right);
        const padding_w_m: f32 = @floatFromInt(padding.left + padding.right);
        const margin_w: f32 = @floatFromInt(margin.left + margin.right);

        if (ui_node.style.width.type != .fixed and ui_node.style.width.type != .grow and ui_node.style.width.type != .elastic and ui_node.style.width.type != .percent) {
            element.calculated_width += padding_w;
            element.min_width += padding_w_m;
        }

        if (parent_op) |parent| {
            const child_gap: f32 = @floatFromInt((parent.children.items.len - 1) * parent.style.child_gap);
            // Here we lay out the width and heights or the parent based on the child elements
            if (parent.style.width.type != .fixed and parent.style.width.type != .grow and parent.style.width.type != .percent) {
                if (parent.style.direction == .row) {
                    parent.calculated_width += child_gap;
                    parent.calculated_width += margin_w;
                    parent.calculated_width += element.calculated_width;
                    parent.min_width += element.min_width;
                } else {
                    parent.min_width = @max(element.min_width, parent.min_width);
                    parent.calculated_width = @max(element.calculated_width, parent.calculated_width);
                }
            }
        }

        ui_ctx.stackPop();
    }
}

// close is breadth post order first
pub fn close(ui_ctx: *UIContext) void {
    if (uuid_depth > 0) {
        uuid_depth -= 1;
    } else {
        Fabric.printlnSrcErr("Depth is negative {}", .{uuid_depth}, @src());
    }
    const stack = ui_ctx.stack orelse unreachable;
    const ui_node = stack.ptr orelse unreachable;

    // if (!ui_node.show) {
    //     ui_ctx.stackPop();
    //     return;
    // }

    const parent_op = ui_node.parent;
    const padding = ui_node.style.padding;
    const margin = ui_node.style.margin;
    const element = ui_node;
    // element.calculated_width = ui_node.style.width.size.minmax.max;
    const padding_w: f32 = @floatFromInt(padding.left + padding.right);
    const padding_w_m: f32 = @floatFromInt(padding.left + padding.right);
    const margin_w: f32 = @floatFromInt(margin.left + margin.right);

    if (ui_node.style.width.type != .fixed and ui_node.style.width.type != .grow and ui_node.style.width.type != .elastic and ui_node.style.width.type != .percent) {
        element.calculated_width += padding_w;
        element.min_width += padding_w_m;
    }

    if (parent_op) |parent| {
        const child_gap: f32 = @floatFromInt((parent.children.items.len - 1) * parent.style.child_gap);
        // Here we lay out the width and heights or the parent based on the child elements
        if (parent.style.width.type != .fixed and parent.style.width.type != .grow and parent.style.width.type != .percent) {
            if (parent.style.direction == .row) {
                parent.calculated_width += child_gap;
                parent.calculated_width += margin_w;
                parent.calculated_width += element.calculated_width;
                parent.min_width += element.min_width;
            } else {
                parent.min_width = @max(element.min_width, parent.min_width);
                parent.calculated_width = @max(element.calculated_width, parent.calculated_width);
            }
        }
    }

    ui_ctx.stackPop();
}

pub fn wrapTextElements(ui_ctx: *UIContext) void {
    for (ui_ctx.text_elements.items) |text| {
        const line_height = text.style.line_height;
        const letter_spacing = text.style.letter_spacing;
        const font_size = text.style.font_size;
        const width = text.calculated_width;
        const elem_text = text.text;
        var text_buffer: [4096]u8 = undefined;
        @memcpy(text_buffer[0..elem_text.len], elem_text);
        const text_height = wrapText(elem_text, width, font_size, letter_spacing, line_height, &text_buffer);
        text.style.height.size.minmax.min = text_height;
        text.style.height.size.minmax.max = text_height;
        text.calculated_height = text_height;
        text.min_height = text_height;
        // @memcpy(text.new_text[0..elem_text.len], text_buffer[0..elem_text.len]);
    }
}

pub fn fitHeights(ui_ctx: *UIContext) void {
    while (ui_ctx.stack) |stack| {
        const ui_node = stack.ptr orelse unreachable;

        // if (!ui_node.show) {
        //     ui_ctx.stackPop();
        //     return;
        // }

        const parent_op = ui_node.parent;
        const padding = ui_node.style.padding;
        const element = ui_node;
        const padding_h: f32 = @floatFromInt(padding.top + padding.bottom);
        const padding_h_m: f32 = @floatFromInt(padding.top + padding.bottom);

        if (ui_node.style.height.type != .fixed and ui_node.style.height.type != .grow and ui_node.style.height.type != .percent) {
            element.calculated_height += padding_h;
            element.min_height += padding_h_m;
        }

        if (parent_op) |parent| {
            // const parent_padding = parent.style.padding;
            // const parent_padding_h: f32 = @floatFromInt(parent_padding.left + parent_padding.right);
            // const parent_padding_h_m: f32 = @floatFromInt(parent_padding.left + parent_padding.right);

            const child_gap: f32 = @floatFromInt((parent.children.items.len - 1) * parent.style.child_gap);
            // Here we lay out the width and heights or the parent based on the child elements
            if (parent.style.height.type != .fixed and parent.style.height.type != .grow and parent.style.height.type != .percent) {
                if (parent.style.direction == .row) {
                    parent.calculated_height = @max(element.calculated_height, parent.calculated_height);
                    parent.min_height = @max(element.min_height, parent.min_height);
                } else {
                    parent.calculated_height += child_gap;
                    parent.calculated_height += element.calculated_height;
                    parent.min_height += element.min_height;
                }
            }
        }

        ui_ctx.stackPop();
    }
}

pub fn endLayoutWidths(ui_ctx: *UIContext) void {
    const stack = ui_ctx.stack orelse unreachable;
    const ui_node = stack.ptr orelse unreachable;
    var width: f32 = 0;
    var height: f32 = 0;
    for (ui_node.children.items) |child| {
        if (ui_node.style.direction == .row) {
            width += child.calculated_width;
            height = @max(child.calculated_height, height);
        } else {
            height += child.calculated_height;
            width = @max(child.calculated_width, width);
        }
    }
    ui_node.calculated_width = width;
    ui_node.calculated_height = height;
    ui_ctx.stackPop();
}

pub fn endLayout(ui_ctx: *UIContext) void {
    const root = ui_ctx.root.?;
    var width: f32 = 0;
    var height: f32 = 0;
    for (root.children.items) |child| {
        if (root.style.direction == .row) {
            width += child.calculated_width;
            height = @max(child.calculated_height, height);
        } else {
            height += child.calculated_height;
            width = @max(child.calculated_width, width);
        }
    }
    root.calculated_width = width;
    root.calculated_height = height;

    const render_cmd: *RenderCommand = ui_ctx.allocator.create(RenderCommand) catch unreachable;
    render_cmd.* = .{
        .elem_type = root.type,
        .bounding_box = .{
            .x = root.calculated_x,
            .y = root.calculated_y,
            .width = root.calculated_width,
            .height = root.calculated_height,
        },
        .href = "",
        .style = root.style,
        .hooks = root.hooks,
        .node_ptr = root,
        .id = root.uuid,
    };
    render_cmd.style.direction = .column;
    render_cmd.style.width.type = .percent;
    render_cmd.style.height.type = .percent;
    root.dirty = false;
    render_cmd.show = false;
    // render_cmd.style.height.size.percent.min = 1;
    // render_cmd.style.width.size.percent.min = 1;
    // render_cmd.style.width.size.percent.max = 1;
    // render_cmd.style.height.size.percent.max = 1;

    // const tree = ui_ctx.allocator.create(CommandsTree) catch return;
    const tree: *CommandsTree = ui_ctx.allocator.create(CommandsTree) catch unreachable;
    tree.* = .{
        .node = render_cmd,
        .children = std.ArrayList(*CommandsTree).init(ui_ctx.allocator.*),
    };
    ui_ctx.ui_tree = tree;
}

pub fn createStack(ui_ctx: *UIContext, parent: *UINode) void {
    if (parent.children.items.len == 0) return;

    for (parent.children.items) |child| {
        ui_ctx.stackRegister(child) catch {
            println("Could not stack register\n", .{});
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
pub fn traverseChildren(ui_ctx: *UIContext, parent_op: ?*UINode, ui_tree_parent: *CommandsTree) void {
    var local_offset: f32 = ui_ctx.current_offset;
    if (parent_op) |parent| {
        if (parent.children.items.len > 0) {
            ui_tree_parent.children = std.ArrayList(*CommandsTree).init(ui_ctx.allocator.*);
            const padding_left: f32 = @floatFromInt(parent.style.padding.left);
            const padding_right: f32 = @floatFromInt(parent.style.padding.right);
            const padding_top: f32 = @floatFromInt(parent.style.padding.top);
            const padding_bottom: f32 = @floatFromInt(parent.style.padding.bottom);
            var center_x_offset: f32 = 0.0;
            var center_y_offset: f32 = 0.0;
            const effective_width: f32 = parent.calculated_width - padding_left - padding_right;
            const effective_height: f32 = parent.calculated_height - padding_bottom - padding_top;
            var accumalated_child_width: f32 = 0.0;
            var accumalated_child_height: f32 = 0.0;
            for (parent.children.items) |child| {
                const margin_left: f32 = @floatFromInt(child.style.margin.left);
                const margin_right: f32 = @floatFromInt(child.style.margin.right);
                const margin_top: f32 = @floatFromInt(child.style.margin.top);
                const margin_bottom: f32 = @floatFromInt(child.style.margin.bottom);

                accumalated_child_width += child.calculated_width + margin_left + margin_right;
                accumalated_child_height += child.calculated_height + margin_top + margin_bottom;
            }
            if (parent.style.child_alignment.x == .center or parent.style.child_alignment.y == .center) {
                if (parent.style.child_alignment.x == .center) {
                    if (parent.style.direction == .row) {
                        center_x_offset = (effective_width - accumalated_child_width) / 2;
                    }
                }
                if (parent.style.child_alignment.y == .center) {
                    center_y_offset = (effective_height - accumalated_child_height) / 2;
                }
            } else if (parent.style.child_alignment.x == .end) {
                for (parent.children.items) |child| {
                    accumalated_child_width += child.calculated_width;
                }
                center_x_offset = effective_width - accumalated_child_width;
            }

            depth += 1;
            // const nbr_children: f32 = @floatFromInt(parent.children.items.len);
            for (parent.children.items, 0..) |child, i| {
                if (parent.style.child_alignment.y == .bottom) {
                    center_y_offset = effective_height - child.calculated_height;
                }

                if (parent.style.direction == .column) {
                    center_x_offset = (effective_width - child.calculated_width) / 2;
                }

                if (parent.style.direction == .row) {
                    center_y_offset = (effective_height - child.calculated_height) / 2;
                    if (parent.style.child_alignment.x == .between) {
                        // const first_elem_width = parent.children.items[0].calculated_width;
                        // const last_elem_width = parent.children.items[parent.children.items.len - 1].calculated_width;
                        // const space = effective_width - first_elem_width - last_elem_width;
                        const gap = (effective_width - accumalated_child_width) / @as(f32, @floatFromInt(parent.children.items.len - 1));
                        center_x_offset = gap * @as(f32, @floatFromInt(i));
                    }
                }

                if (parent.style.child_alignment.x == .start) {
                    center_x_offset = 0;
                }
                if (parent.style.child_alignment.y == .top) {
                    center_y_offset = 0;
                }

                const margin_left: f32 = @floatFromInt(child.style.margin.left);
                const margin_right: f32 = @floatFromInt(child.style.margin.right);
                const margin_top: f32 = @floatFromInt(child.style.margin.top);
                const margin_bottom: f32 = @floatFromInt(child.style.margin.bottom);

                child.calculated_x += padding_left + parent.calculated_x + center_x_offset + margin_left;
                child.calculated_y += padding_top + parent.calculated_y + center_y_offset + margin_top;

                if (parent.style.direction == .row) {
                    child.calculated_x += local_offset;
                } else {
                    child.calculated_y += local_offset;
                }

                const render_cmd: *RenderCommand = ui_ctx.allocator.create(RenderCommand) catch unreachable;
                if (child.style.position != null and child.style.position.?.type == .absolute) {
                    child.calculated_x = child.style.position.?.x;
                    child.calculated_y = child.style.position.?.y;
                }

                render_cmd.* = .{
                    .elem_type = child.type,
                    .bounding_box = .{
                        .x = child.calculated_x,
                        .y = child.calculated_y,
                        .width = child.calculated_width,
                        .height = child.calculated_height,
                    },
                    .text = child.text,
                    .href = child.href,
                    .style = child.style,
                    .id = child.uuid,
                    .show = child.show,
                    .hooks = child.hooks,
                    .node_ptr = child,
                };

                if (child.style.hover) |_| {
                    render_cmd.hover = true;
                }

                const tree: *CommandsTree = ui_ctx.allocator.create(CommandsTree) catch unreachable;
                tree.* = .{
                    .node = render_cmd,
                    .children = std.ArrayList(*CommandsTree).init(ui_ctx.allocator.*),
                };
                // if (parent.show) {
                //     println("Show command {any}\n", .{child.type});
                ui_tree_parent.children.append(tree) catch unreachable;
                if (child.dynamic == .animation) {
                    const class_name = child.style.child_styles.?[0].style_id;
                    Fabric.addToClassesList(child.uuid, class_name);
                }
                // }

                if (child.style.position != null and child.style.position.?.type == .absolute) {
                    const child_gap: f32 = @floatFromInt(parent.style.child_gap);
                    if (parent.style.direction == .row) {
                        local_offset += child.calculated_width + child_gap + margin_right;
                    } else {
                        local_offset += child.calculated_height + child_gap + margin_bottom;
                    }
                }
            }
            // ui_ctx.current_offset = local_offset;
            // if (parent.show) {
            for (parent.children.items, 0..) |child, j| {
                ui_ctx.traverseChildren(child, ui_tree_parent.children.items[j]);
            }
            // }
            // ui_ctx.current_offset -= local_offset;
            depth -= 1;
        }
    }
}

pub fn traverseCmdsChildren(ui_ctx: *UIContext, parent_op: ?*UINode, ui_tree_parent: *CommandsTree) void {
    var local_offset: f32 = ui_ctx.current_offset;

    if (parent_op) |parent| {
        if (parent.children.items.len > 0) {
            const padding_left: f32 = @floatFromInt(parent.style.padding.left);
            const padding_right: f32 = @floatFromInt(parent.style.padding.right);
            const padding_top: f32 = @floatFromInt(parent.style.padding.top);
            const padding_bottom: f32 = @floatFromInt(parent.style.padding.bottom);
            var center_x_offset: f32 = 0.0;
            var center_y_offset: f32 = 0.0;
            const effective_width: f32 = parent.calculated_width - padding_left - padding_right;
            const effective_height: f32 = parent.calculated_height - padding_bottom - padding_top;
            var accumalated_child_width: f32 = 0.0;
            var accumalated_child_height: f32 = 0.0;
            for (parent.children.items) |child| {
                const margin_left: f32 = @floatFromInt(child.style.margin.left);
                const margin_right: f32 = @floatFromInt(child.style.margin.right);
                const margin_top: f32 = @floatFromInt(child.style.margin.top);
                const margin_bottom: f32 = @floatFromInt(child.style.margin.bottom);

                accumalated_child_width += child.calculated_width + margin_left + margin_right;
                accumalated_child_height += child.calculated_height + margin_top + margin_bottom;
            }
            if (parent.style.child_alignment.x == .center or parent.style.child_alignment.y == .center) {
                if (parent.style.child_alignment.x == .center) {
                    if (parent.style.direction == .row) {
                        center_x_offset = (effective_width - accumalated_child_width) / 2;
                    }
                }
                if (parent.style.child_alignment.y == .center) {
                    center_y_offset = (effective_height - accumalated_child_height) / 2;
                }
            } else if (parent.style.child_alignment.x == .end) {
                for (parent.children.items) |child| {
                    accumalated_child_width += child.calculated_width;
                }
                center_x_offset = effective_width - accumalated_child_width;
            }

            depth += 1;
            // const nbr_children: f32 = @floatFromInt(parent.children.items.len);
            for (parent.children.items, 0..) |child, i| {
                if (parent.style.child_alignment.y == .bottom) {
                    center_y_offset = effective_height - child.calculated_height;
                }

                if (parent.style.direction == .column) {
                    center_x_offset = (effective_width - child.calculated_width) / 2;
                }

                if (parent.style.direction == .row) {
                    center_y_offset = (effective_height - child.calculated_height) / 2;
                    if (parent.style.child_alignment.x == .between) {
                        // const first_elem_width = parent.children.items[0].calculated_width;
                        // const last_elem_width = parent.children.items[parent.children.items.len - 1].calculated_width;
                        // const space = effective_width - first_elem_width - last_elem_width;
                        const gap = (effective_width - accumalated_child_width) / @as(f32, @floatFromInt(parent.children.items.len - 1));
                        center_x_offset = gap * @as(f32, @floatFromInt(i));
                    }
                }

                if (parent.style.child_alignment.x == .start) {
                    center_x_offset = 0;
                }
                if (parent.style.child_alignment.y == .top) {
                    center_y_offset = 0;
                }

                const margin_left: f32 = @floatFromInt(child.style.margin.left);
                const margin_right: f32 = @floatFromInt(child.style.margin.right);
                const margin_top: f32 = @floatFromInt(child.style.margin.top);
                const margin_bottom: f32 = @floatFromInt(child.style.margin.bottom);

                child.calculated_x += padding_left + parent.calculated_x + center_x_offset + margin_left;
                child.calculated_y += padding_top + parent.calculated_y + center_y_offset + margin_top;

                if (parent.style.direction == .row) {
                    child.calculated_x += local_offset;
                } else {
                    child.calculated_y += local_offset;
                }

                if (child.style.position != null and child.style.position.?.type == .absolute) {
                    child.calculated_x = child.style.position.?.x;
                    child.calculated_y = child.style.position.?.y;
                }

                const render_cmd = ui_tree_parent.children.items[i].node;

                render_cmd.show = child.show;
                render_cmd.bounding_box = .{
                    .x = child.calculated_x,
                    .y = child.calculated_y,
                    .width = child.calculated_width,
                    .height = child.calculated_height,
                };
                // const render_cmd: *RenderCommand = ui_ctx.render_cmd_memory_pool.create() catch unreachable;
                // render_cmd.* = .{
                //     .elem_type = child.type,

                // render_cmd.background = child.style.background;
                // render_cmd.color = child.style.color;
                render_cmd.text = child.text;
                // render_cmd.font_size = child.style.font_size;
                // render_cmd.letter_spacing = child.style.letter_spacing;
                // render_cmd.border_radius = child.style.border_radius;
                // render_cmd.line_height = child.style.line_height;
                // render_cmd.border_thickness = child.style.border_thickness;
                // render_cmd.border_color = child.style.border_color;
                // render_cmd.href = child.href;
                // render_cmd.style = child.style;
                // render_cmd.id = &child.uuid;
                // render_cmd.node_ptr = child;
                // };

                // const commands_tree_node: *CommandsTree = ui_ctx.allocator.create(CommandsTree) catch unreachable;
                // commands_tree_node.children = std.ArrayList(*CommandsTree).init(ui_ctx.allocator.*);
                // commands_tree_node.*.node = render_cmd;
                // if (parent.show) {
                //     println("Show command {any}\n", .{child.type});
                //     ui_tree_parent.children.append(commands_tree_node) catch unreachable;
                // }

                if (child.style.position != null and child.style.position.?.type != .absolute) {
                    const child_gap: f32 = @floatFromInt(parent.style.child_gap);
                    if (parent.style.direction == .row) {
                        local_offset += child.calculated_width + child_gap + margin_right;
                    } else {
                        local_offset += child.calculated_height + child_gap + margin_bottom;
                    }
                }
            }
            // if (parent.show) {
            for (parent.children.items, 0..) |child, j| {
                ui_ctx.traverseCmdsChildren(child, ui_tree_parent.children.items[j]);
            }
            // }
        } else {
            const render_cmd = ui_tree_parent.node;
            render_cmd.show = parent.show;
            render_cmd.bounding_box = .{
                .x = parent.calculated_x,
                .y = parent.calculated_y,
                .width = parent.calculated_width,
                .height = parent.calculated_height,
            };
        }
    }
}

pub fn traverseCmds(ui_ctx: *UIContext) void {
    ui_ctx.traverseCmdsChildren(ui_ctx.root, ui_ctx.ui_tree.?);
}

pub fn traverse(ui_ctx: *UIContext) void {
    ui_ctx.traverseChildren(ui_ctx.root, ui_ctx.ui_tree.?);
}

pub fn resetAll(ui_ctx: *UIContext, parent_op: ?*UINode) void {
    if (parent_op) |parent| {
        if (parent.parent == null) {
            // is root
            ui_ctx.reset(parent);
            parent.calculated_width = ui_ctx.sw;
            parent.calculated_height = ui_ctx.sh;
        } else {
            ui_ctx.reset(parent);
        }
        for (parent.children.items) |child| {
            ui_ctx.resetAll(child);
        }
    }
}

pub fn resetAllUiNode(ui_ctx: *UIContext) void {
    ui_ctx.current_offset = 0;
    ui_ctx.current_padding_top = 0;
    ui_ctx.current_padding_left = 0;
    ui_ctx.resetAll(ui_ctx.root);
    ui_ctx.stack = null;
    ui_ctx.stackRegister(ui_ctx.root.?) catch {
        println("Could not stack register\n", .{});
        unreachable;
    };
}

pub fn growChildElementHeight(ui_ctx: *UIContext, parent: *UINode) void {
    if (parent.children.items.len == 0) return;
    var remaining_height = parent.calculated_height;
    const padding_top: f32 = @floatFromInt(parent.style.padding.top);
    const padding_bottom: f32 = @floatFromInt(parent.style.padding.bottom);
    remaining_height -= padding_top + padding_bottom;
    for (parent.children.items) |child| {
        if (parent.style.direction == .column) {
            remaining_height -= child.calculated_height;
        }
    }
    const child_gap: f32 = @floatFromInt((parent.children.items.len - 1) * parent.style.child_gap);
    if (parent.style.direction == .column) {
        remaining_height -= child_gap;
    }
    if (remaining_height < 0) {
        var schrinkable_count_height: f32 = 0;
        for (parent.children.items) |child| {
            if (!child.show) continue;
            if (parent.style.direction == .row) {
                schrinkable_count_height = 1;
            }
            if (parent.style.direction == .column) {
                if (child.style.height.type == .elastic) {
                    schrinkable_count_height += 1;
                }
            }
        }
        const schrinkable_height = remaining_height / schrinkable_count_height;
        // We grow every schrinkable element by the smallest element
        for (parent.children.items) |child| {
            if (!child.show) continue;
            if (child.style.height.type == .elastic) {
                const can_shrink = child.min_height < child.calculated_height + schrinkable_height;
                if (can_shrink) {
                    child.calculated_height += schrinkable_height;
                }
            }
        }
    }

    // Percent section
    if (remaining_height > 0) {
        for (parent.children.items) |child| {
            if (!child.show) continue;
            if (child.style.height.type == .percent) {
                ui_ctx.percents.append(child) catch return;
            }
        }
    }
    while (remaining_height > 0) {
        if (ui_ctx.percents.items.len == 0) break;
        var smallest: f32 = ui_ctx.percents.items[0].calculated_height * remaining_height;
        var second_smallest: f32 = 0;
        var smallest_index: usize = 0;
        // var height_to_subtract: f32 = remaining_height;
        // here the largest is 1000, and second is 300
        for (ui_ctx.percents.items, 0..) |child, i| {
            if (!child.show) continue;
            const child_percent_height = child.calculated_height * remaining_height;
            if (child_percent_height < smallest) {
                second_smallest = smallest;
                smallest = child_percent_height;
                smallest_index = i;
            }
        }
        for (ui_ctx.percents.items) |child| {
            if (!child.show) continue;
            if (child.calculated_height * remaining_height == smallest) {
                child.calculated_height = smallest;
                if (parent.style.direction == .column) {
                    remaining_height -= smallest;
                }
                _ = ui_ctx.percents.swapRemove(smallest_index);
            }
        }
    }

    // Growing sections
    // We grow every growable element by the smallest element
    if (remaining_height >= 0) {
        var growable_count_height: f32 = 0;
        for (parent.children.items) |child| {
            if (!child.show) continue;
            if (parent.style.direction == .row) {
                growable_count_height = 1;
            }
            if (parent.style.direction == .column) {
                if (child.style.height.type == .grow) {
                    growable_count_height += 1;
                }
            }
        }
        const growable_height = remaining_height / growable_count_height;
        // We grow every growable element by the smallest element
        for (parent.children.items) |child| {
            if (child.style.height.type == .grow) {
                child.calculated_height = growable_height;
            }
        }
    }

    // shrinking section
    if (parent.show) {
        for (parent.children.items) |child| {
            ui_ctx.growChildElementHeight(child);
        }
    }
}

// Breadth first search
// Calcualte the widths and heights
// Direction row
pub fn growChildElementWidth(ui_ctx: *UIContext, parent: *UINode) void {
    ui_ctx.stackRegister(parent) catch {
        println("Could not stack register\n", .{});
        unreachable;
    };
    if (parent.children.items.len == 0) return;
    var remaining_width = parent.calculated_width;
    const padding_left: f32 = @floatFromInt(parent.style.padding.left);
    const padding_right: f32 = @floatFromInt(parent.style.padding.right);
    remaining_width -= padding_left + padding_right;
    for (parent.children.items) |child| {
        if (parent.style.direction == .row and child.style.width.type != .percent) {
            remaining_width -= child.calculated_width;
        }
    }
    const child_gap: f32 = @floatFromInt((parent.children.items.len - 1) * parent.style.child_gap);
    if (parent.style.direction == .row) {
        remaining_width -= child_gap;
    }

    for (parent.children.items) |child| {
        if (child.style.width.type == .elastic) {
            ui_ctx.shrinkable.append(child) catch {
                println("Could not stack appened\n", .{});
                unreachable;
            };
        }
    }

    // Need to reduce by 720
    while (remaining_width < 0) {
        if (ui_ctx.shrinkable.items.len == 0) break;

        var largest: f32 = ui_ctx.shrinkable.items[0].calculated_width;
        var second_largest: f32 = 0;
        var largest_index: usize = 0;
        var width_to_add: f32 = remaining_width;
        // here the largest is 1000, and second is 300
        for (ui_ctx.shrinkable.items, 0..) |child, i| {
            if (child.calculated_width > largest) {
                second_largest = largest;
                largest = child.calculated_width;
                largest_index = i;
            }

            // if (child.calculated_width < largest) {
            //     second_largest = @max(child.calculated_width, second_largest);
            width_to_add = largest - second_largest;
            // }
        }

        width_to_add = @max(width_to_add, @as(f32, @abs(remaining_width)) / @as(f32, @floatFromInt(ui_ctx.shrinkable.items.len)));

        for (ui_ctx.shrinkable.items) |child| {
            if (child.calculated_width == largest and child.min_width < second_largest) {
                child.calculated_width = second_largest;
                remaining_width += width_to_add;
            } else if (child.calculated_width == largest) {
                remaining_width += largest - child.min_width;
                child.calculated_width = child.min_width;
                _ = ui_ctx.shrinkable.swapRemove(largest_index);
            }
        }
    }

    // Percent section
    if (remaining_width > 0) {
        for (parent.children.items) |child| {
            if (child.style.width.type == .percent) {
                ui_ctx.percents.append(child) catch |err| {
                    println("Could not percents append {any}\n", .{err});
                    unreachable;
                };
            }
        }
    }
    while (remaining_width > 0) {
        if (ui_ctx.percents.items.len == 0) break;
        var smallest: f32 = ui_ctx.percents.items[0].calculated_width * remaining_width;
        var second_smallest: f32 = 0;
        var smallest_index: usize = 0;
        // var width_to_subtract: f32 = remaining_width;
        // here the largest is 1000, and second is 300
        for (ui_ctx.percents.items, 0..) |child, i| {
            const child_percent_width = child.calculated_width * remaining_width;
            if (child_percent_width < smallest) {
                second_smallest = smallest;
                smallest = child_percent_width;
                smallest_index = i;
            }
        }
        for (ui_ctx.percents.items) |child| {
            if (child.calculated_width * remaining_width == smallest) {
                child.calculated_width = smallest;
                remaining_width -= smallest;
                _ = ui_ctx.percents.swapRemove(smallest_index);
            }
        }
    }

    // Growing sections
    // We grow every growable element by the smallest element
    if (remaining_width > 0) {
        var growable_count_width: f32 = 0;
        for (parent.children.items) |child| {
            if (parent.style.direction == .row) {
                if (child.style.width.type == .grow) {
                    // i removed this since when we have elstic and grow width then it doesnt work
                    // the problem is elastic is accounted for so then the reminaing width is divided by the inclusion
                    // of elastic
                    // if (child.style.width.type == .grow or child.style.width.type == .elastic) {
                    growable_count_width += 1;
                }
            }
            if (parent.style.direction == .column) {
                growable_count_width = 1;
            }
        }
        if (growable_count_width == 0) growable_count_width = 1;
        const growable_width = remaining_width / growable_count_width;
        // We grow every growable element by the smallest element
        for (parent.children.items) |child| {
            if (child.style.width.type == .grow) {
                child.calculated_width += growable_width;
            } else if (child.style.width.type == .elastic) {
                if (child.calculated_width + growable_width <= child.style.width.size.minmax.max) {
                    child.calculated_width += growable_width;
                }
            }
        }
    }

    // shrinking section
    if (parent.show) {
        for (parent.children.items) |child| {
            ui_ctx.growChildElementWidth(child);
        }
    }
}

pub fn growElementsWidths(ui_ctx: *UIContext) void {
    ui_ctx.growChildElementWidth(ui_ctx.root.?);
    // ui_ctx.percents.clearRetainingCapacity();
    // ui_ctx.text_elements.clearRetainingCapacity();
    // ui_ctx.percents.deinit();
    // ui_ctx.text_elements.deinit();
}

pub fn growElementsHeights(ui_ctx: *UIContext) void {
    ui_ctx.growChildElementHeight(ui_ctx.root.?);
    // ui_ctx.percents.clearRetainingCapacity();
    // ui_ctx.text_elements.clearRetainingCapacity();
    ui_ctx.percents.deinit();
    ui_ctx.text_elements.deinit();
    ui_ctx.shrinkable.deinit();
}
