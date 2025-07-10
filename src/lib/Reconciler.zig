const std = @import("std");
const UIContext = @import("UITree.zig");
const Fabric = @import("Fabric.zig");
const Style = @import("types.zig").Style;
const Background = @import("types.zig").Background;
const UINode = @import("UITree.zig").UINode;
const Self = @This();

var layout_path: []const u8 = "";
pub fn reconcile(old_ctx: *UIContext, new_ctx: *UIContext, _: []const u8) void {
    traverseNodes(old_ctx.root.?, new_ctx.root.?);
    Fabric.Theme.switched_theme = false;
}

/// Compares two Style instances shallowly (all top-level fields).
/// Returns true if every field is equal, false otherwise.
pub fn nodesEqual(old_node: *UINode, new_node: *UINode) bool {
    const a = old_node.style;
    const b = new_node.style;
    // Compare optional string fields
    if (!compareOptionalSlice(a.id, b.id)) return false;
    if (!compareOptionalSlice(old_node.text, new_node.text)) return false;
    if (!compareOptionalSlice(a.style_id, b.style_id)) return false;
    if (!std.mem.eql(u8, old_node.href, new_node.href)) return false;

    if (a.hover != null and b.hover != null) {
        const hovera = a.hover.?;
        const hoverb = b.hover.?;
        if (hovera.background != null) {
            if (!compareRgba(hovera.background.?, hoverb.background.?)) return false;
        }
    }

    if (a.display != b.display) return false;
    if (a.position != null and b.position != null) {
        if (a.position.?.x != b.position.?.x) return false;
        if (a.position.?.y != b.position.?.y) return false;
        if (a.position.?.type != b.position.?.type) return false;
        if (a.position.?.top.value != b.position.?.top.value) return false;
        if (a.position.?.bottom.value != b.position.?.bottom.value) return false;
        if (a.position.?.left.value != b.position.?.left.value) return false;
        if (a.position.?.right.value != b.position.?.right.value) return false;
    }

    if (a.direction != b.direction) return false;

    if (a.background != null and b.background != null) {
        if (!compareRgba(a.background.?, b.background.?)) return false;
    }

    if (a.width.size.minmax.min != b.width.size.minmax.min) return false;
    if (a.width.size.minmax.max != b.width.size.minmax.max) return false;
    if (a.height.size.minmax.min != b.height.size.minmax.min) return false;
    if (a.height.size.minmax.max != b.height.size.minmax.max) return false;
    if (a.font_size != b.font_size) return false;
    if (a.letter_spacing != b.letter_spacing) return false;
    if (a.line_height != b.line_height) return false;
    if (a.font_weight != b.font_weight) return false;
    if (a.border_radius != null and b.border_radius != null) {
        if (a.border_radius.?.top_left != b.border_radius.?.top_left) return false;
        if (a.border_radius.?.top_right != b.border_radius.?.top_right) return false;
        if (a.border_radius.?.bottom_left != b.border_radius.?.bottom_left) return false;
        if (a.border_radius.?.bottom_right != b.border_radius.?.bottom_right) return false;
    }
    if (a.border_thickness != null and b.border_thickness != null) {
        if (a.border_thickness.?.top != b.border_thickness.?.top) return false;
        if (a.border_thickness.?.left != b.border_thickness.?.left) return false;
        if (a.border_thickness.?.right != b.border_thickness.?.right) return false;
        if (a.border_thickness.?.bottom != b.border_thickness.?.bottom) return false;
    }
    if (a.border_color != null and b.border_color != null) {
        if (!compareRgba(a.border_color.?, b.border_color.?)) return false;
    }
    if (a.text_color != null and b.text_color != null) {
        if (!compareRgba(a.text_color.?, b.text_color.?)) return false;
    }
    if (a.padding != null and b.padding != null) {
        if (a.padding.?.top != b.padding.?.top) return false;
        if (a.padding.?.left != b.padding.?.left) return false;
        if (a.padding.?.bottom != b.padding.?.bottom) return false;
        if (a.padding.?.right != b.padding.?.right) return false;
    }
    if (a.margin != null and b.margin != null) {
        if (a.margin.?.top != b.margin.?.top) return false;
        if (a.margin.?.left != b.margin.?.left) return false;
        if (a.margin.?.bottom != b.margin.?.bottom) return false;
        if (a.margin.?.right != b.margin.?.right) return false;
    }
    // if (a.overflow != b.overflow) return false;

    if (a.overflow_x != b.overflow_x) return false;
    if (a.overflow_y != b.overflow_y) return false;
    if (a.child_alignment.x != b.child_alignment.x) return false;
    if (a.child_alignment.y != b.child_alignment.y) return false;
    if (a.child_gap != b.child_gap) return false;
    if (!compareOptionalSlice(a.dialog_id, b.dialog_id)) return false;
    if (a.opacity != b.opacity) return false;

    // // Compare non-optional slice fields
    // if (!std.mem.eql(u8, a.font_family_file, b.font_family_file)) return false;
    // if (!std.mem.eql(u8, a.font_family, b.font_family)) return false;
    // if (!std.mem.eql(f32, a.color[0..], b.color[0..])) return false;
    // if (a.text_decoration != b.text_decoration) return false;
    // if (a.shadow != b.shadow) return false;
    // if (a.white_space != b.white_space) return false;
    // if (a.flex_wrap != b.flex_wrap) return false;
    // if (a.key_frame != b.key_frame) return false;
    // if (a.animation != b.animation) return false;
    // if (a.z_index != b.z_index) return false;
    // if (a.list_style != b.list_style) return false;
    // if (a.blur != b.blur) return false;
    // if (a.outline != b.outline) return false;
    // if (a.transition != b.transition) return false;
    // if (a.show_scrollbar != b.show_scrollbar) return false;
    // if (a.hover != b.hover) return false;
    // if (a.btn_id != b.btn_id) return false;

    return true;
}

/// Helper to compare optional slices of u8
fn compareFloat32Slice(
    a: [4]u8,
    b: [4]u8,
) bool {
    if (a[0] == b[0] and a[1] == b[1] and a[2] == b[2] and a[3] == b[3]) {
        return true;
    } else {
        return false;
    }
}

fn compareRgba(a: Background, b: Background) bool {
    if (a.r == b.r and a.g == b.g and a.b == b.b and a.a == b.a) {
        return true;
    } else {
        return false;
    }
}

fn compareOptionalUint32(
    a: ?u32,
    b: ?u32,
) bool {
    if (a == null and b == null) {
        return true;
    } else if (a != null and b != null) {
        return a.? == b.?;
    } else {
        return false;
    }
}

fn compareOptionalFloat32(
    a: ?f32,
    b: ?f32,
) bool {
    if (a == null and b == null) {
        return true;
    } else if (a != null and b != null) {
        return a.? == b.?;
    } else {
        return false;
    }
}
/// Helper to compare optional slices of u8
fn compareOptionalFloat32Slice(
    a: ?[4]u8,
    b: ?[4]u8,
) bool {
    if (a == null and b == null) {
        return true;
    } else if (a != null and b != null) {
        if (a.?[0] == b.?[0] and a.?[1] == b.?[1] and a.?[2] == b.?[2] and a.?[3] == b.?[3]) {
            return true;
        } else {
            return false;
        }
    } else {
        return false;
    }
}

/// Helper to compare optional slices of u8
fn compareOptionalSlice(
    a: ?[]const u8,
    b: ?[]const u8,
) bool {
    if (a == null and b == null) {
        return true;
    } else if (a != null and b != null) {
        return std.mem.eql(u8, a.?, b.?);
    } else {
        return false;
    }
}

fn traverseNodes(old_node: *UINode, new_node: *UINode) void {
    if (old_node.dirty) {
        new_node.dirty = true;
    } else if (Fabric.rerender_everything) {
        new_node.dirty = true;
    } else if (!std.mem.eql(u8, old_node.uuid, new_node.uuid)) {
        // Fabric.printlnSrc("Dirty node: {any} {s}", .{ new_node.type, new_node.uuid }, @src());
        new_node.dirty = true;
    } else {
        if (old_node.dynamic == .dynamic) {
            if (old_node.dirty) {
                new_node.dirty = true;
            } else {
                if (!nodesEqual(old_node, new_node)) {
                    new_node.dirty = true;
                } else {
                    new_node.dirty = false;
                }
            }
        } else if (old_node.dynamic == .pure) {
            // Static
            if (!nodesEqual(old_node, new_node)) {
                new_node.dirty = true;
            } else {
                new_node.dirty = false;
            }
        } else if (new_node.dynamic == .animation or old_node.dynamic == .animation) {
            Fabric.println("Animation {any}\n", .{new_node.uuid});
        } else {
            new_node.dirty = false;
        }
    }

    if (old_node.children.items.len != new_node.children.items.len) {
        // Here we remove items, since old_node
        if (old_node.children.items.len > new_node.children.items.len) {
            var end: usize = 0;
            for (new_node.children.items, 0..) |new_child, i| {
                traverseNodes(old_node.children.items[i], new_child);
                end = i;
            }
            for (old_node.children.items[end..]) |node| {
                if (node.dynamic == .animation) {
                    const class_name_enter = node.style.child_styles.?[0].style_id;
                    const class_name_exit = node.style.child_styles.?[1].style_id;
                    const enter = std.mem.Allocator.dupe(Fabric.allocator_global, u8, class_name_enter) catch return;
                    const exit = std.mem.Allocator.dupe(Fabric.allocator_global, u8, class_name_exit) catch return;
                    const uuid = std.mem.Allocator.dupe(Fabric.allocator_global, u8, node.uuid) catch return;

                    // Use the duplicated uuid for BOTH calls
                    Fabric.addToRemoveClassesList(uuid, enter); // Changed from node.uuid to uuid
                    Fabric.addToClassesList(uuid, exit);
                }
            }
        } else {
            // Here old node has less then new_node, which means we added nodes
            var end: usize = 0;
            for (old_node.children.items, 0..) |old_child, i| {
                traverseNodes(old_child, new_node.children.items[i]);
                end = i;
            }
            for (new_node.children.items[end..]) |node| {
                // node.dirty = true;
                Fabric.markChildrenDirty(node);
            }
        }
    } else {
        for (old_node.children.items, 0..) |old_child, i| {
            traverseNodes(old_child, new_node.children.items[i]);
        }
    }
}
