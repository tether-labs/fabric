const std = @import("std");
const UIContext = @import("UITree.zig");
const Vapor = @import("Vapor.zig");
const Style = @import("types.zig").Style;
const Color = @import("types.zig").Color;
const UINode = @import("UITree.zig").UINode;
const utils = @import("utils.zig");
const hashKey = utils.hashKey;
const Self = @This();

var layout_path: []const u8 = "";
var reconcile_debug: bool = false;

pub const Fingerprint = u32;
pub const FingerprintCount = usize;
pub const FingerprintMap = std.AutoHashMap(Fingerprint, FingerprintCount);
var fingerprints: [2]FingerprintMap = undefined;
var current_count: usize = 0;

pub fn switchFingerprintMaps() void {
    if (current_count == 0) {
        fingerprints[0] = fingerprints[1];
        fingerprints[1] = fingerprints[0];
    } else {}
}

pub fn reconcile(old_ctx: *UIContext, new_ctx: *UIContext) void {
    reconcile_debug = false;
    if (old_ctx.root == null or new_ctx.root == null) return;

    traverseNodes(old_ctx.root.?, new_ctx.root.?);
}

// --- Child Iteration Helpers ---

/// Count children in a linked list
fn countChildren(node: *UINode) usize {
    var count: usize = 0;
    var child = node.first_child;
    while (child) |c| {
        count += 1;
        child = c.next_sibling;
    }
    return count;
}

/// Get child at index (O(n))
fn childAt(node: *UINode, index: usize) ?*UINode {
    var i: usize = 0;
    var child = node.first_child;
    while (child) |c| {
        if (i == index) return c;
        i += 1;
        child = c.next_sibling;
    }
    return null;
}

// --- Child Reconciliation Helpers ---

/// Case: Old children exist, new children list is empty.
fn removeAllChildren(old_node: *UINode) void {
    var j: usize = 0;
    var child = old_node.first_child;
    while (child) |old_child| {
        // Vapor.removed_nodes.append(.{ .uuid = old_child.uuid, .index = j }) catch {};
        Vapor.Animation.removal_queue.enqueue(old_child, j) catch {};
        j += 1;
        child = old_child.next_sibling;
    }
}

/// Case: Old children list is empty, new children exist.
fn addAllChildren(new_node: *UINode) void {
    var child = new_node.first_child;
    while (child) |node| {
        Vapor.markChildrenDirty(node);
        child = node.next_sibling;
    }
    Vapor.has_dirty = true;
}

/// Case: Both lists have the same number of children.
fn reconcileSameLength(old_node: *UINode, new_node: *UINode) void {
    var old_child = old_node.first_child;
    var new_child = new_node.first_child;

    while (old_child != null and new_child != null) {
        traverseNodes(old_child.?, new_child.?);
        old_child = old_child.?.next_sibling;
        new_child = new_child.?.next_sibling;
    }
}

/// Build arrays from linked lists for keyed diffing
/// Returns allocated slices that should be used within the same frame
fn buildChildArray(node: *UINode, count: usize) ?[]*UINode {
    if (count == 0) return null;

    const items = Vapor.arena(.frame).alloc(*UINode, count) catch return null;
    var i: usize = 0;
    var child = node.first_child;
    while (child) |c| {
        if (i >= count) break;
        items[i] = c;
        i += 1;
        child = c.next_sibling;
    }
    return items;
}

/// Case: Keyed-diffing when old_items.len > new_items.len (Deletions)
fn reconcileDeletions(old_node: *UINode, new_node: *UINode, len_old: usize, len_new: usize) void {
    // Build temporary arrays for keyed diffing
    const old_items = buildChildArray(old_node, len_old) orelse return;
    const new_items = buildChildArray(new_node, len_new) orelse return;

    var node_map = std.StringHashMap(usize).init(Vapor.arena(.frame));
    defer node_map.deinit();

    // 1. Sync from start
    var i: usize = 0;
    while (i < len_new) : (i += 1) {
        if (std.mem.eql(u8, old_items[i].uuid, new_items[i].uuid)) {
            traverseNodes(old_items[i], new_items[i]);
        } else {
            break;
        }
    }

    // 2. Sync from end
    var back_i_old: usize = len_old;
    var back_i_new: usize = len_new;
    while (back_i_new > i and back_i_old > i) {
        const old_child = old_items[back_i_old - 1];
        const new_child = new_items[back_i_new - 1];

        if (std.mem.eql(u8, old_child.uuid, new_child.uuid)) {
            traverseNodes(old_child, new_child);
            back_i_old -= 1;
            back_i_new -= 1;
        } else {
            break;
        }
    }

    // 3. Process the middle "un-synced" section
    const start = i;
    const end_new = back_i_new;

    // Add all *old* nodes from the middle section to the map
    for (old_items[start..back_i_old], start..) |old_child, j| {
        node_map.put(old_child.uuid, j) catch {
            Vapor.printlnSrcErr("Could not put node into node_map {any}\n", .{old_child.uuid}, @src());
        };
    }

    // Iterate *new* nodes in the middle section
    if (end_new > start) {
        for (new_items[start..end_new]) |new_child| {
            if (node_map.fetchRemove(new_child.uuid)) |old_child_entry| {
                const old_child = old_items[old_child_entry.value];
                traverseNodes(old_child, new_child);
                Vapor.has_dirty = true;
            } else {
                new_child.dirty = true;
                Vapor.has_dirty = true;
                new_child.state_type = .added;
                Vapor.markChildrenDirty(new_child);
            }
        }
    }

    // 4. Any nodes left in the map are deletions
    var node_itr = node_map.iterator();
    while (node_itr.next()) |entry| {
        const j = entry.value_ptr.*;
        // const uuid = entry.key_ptr.*;
        const old_child = old_items[j];
        // Vapor.removed_nodes.append(.{ .uuid = uuid, .index = j }) catch {};
        Vapor.Animation.removal_queue.enqueue(old_child, j) catch {};
    }
}

fn reconcileSame(old_node: *UINode, new_node: *UINode, len: usize) void {
    // Build temporary arrays for keyed diffing
    const old_items = buildChildArray(old_node, len) orelse return;
    const new_items = buildChildArray(new_node, len) orelse return;

    var node_map = std.StringHashMap(usize).init(Vapor.arena(.frame));
    defer node_map.deinit();

    // 1. Sync from start
    var i: usize = 0;
    while (i < len) : (i += 1) {
        if (std.mem.eql(u8, old_items[i].uuid, new_items[i].uuid)) {
            traverseNodes(old_items[i], new_items[i]);
        } else {
            break;
        }
    }

    // 2. Sync from end
    var back_i: usize = len;
    while (back_i > i) {
        const old_child = old_items[back_i - 1];
        const new_child = new_items[back_i - 1];

        if (std.mem.eql(u8, old_child.uuid, new_child.uuid)) {
            traverseNodes(old_child, new_child);
            back_i -= 1;
        } else {
            break;
        }
    }

    // 3. Process the middle "un-synced" section
    const start = i;
    const end = back_i;

    // Add all *new* nodes from the middle section to the map
    for (new_items[start..end], start..) |new_child, j| {
        node_map.put(new_child.uuid, j) catch {
            Vapor.printlnSrcErr("Could not put node into node_map {any}\n", .{new_child.uuid}, @src());
        };
    }

    // Iterate *old* nodes in the middle section
    for (old_items[start..end], start..) |old_child, offset| {
        if (node_map.fetchRemove(old_child.uuid)) |new_child_entry| {
            const new_child = new_items[new_child_entry.value];
            traverseNodes(old_child, new_child);
            Vapor.has_dirty = true;
        } else {
            // Vapor.removed_nodes.append(.{ .uuid = old_child.uuid, .index = offset }) catch {};
            Vapor.Animation.removal_queue.enqueue(old_child, offset) catch {};
        }
    }

    // 4. Any nodes left in the map are additions
    var node_itr = node_map.iterator();
    while (node_itr.next()) |entry| {
        const new_child_index = entry.value_ptr.*;
        const new_child = new_items[new_child_index];
        new_child.state_type = .added;
        Vapor.markChildrenDirty(new_child);
    }
    Vapor.has_dirty = true;
}

/// Case: Keyed-diffing when new_items.len > old_items.len (Additions)
fn reconcileAdditions(old_node: *UINode, new_node: *UINode, len_old: usize, len_new: usize) void {
    // Build temporary arrays for keyed diffing
    const old_items = buildChildArray(old_node, len_old) orelse return;
    const new_items = buildChildArray(new_node, len_new) orelse return;

    var node_map = std.StringHashMap(usize).init(Vapor.arena(.frame));
    defer node_map.deinit();

    // 1. Sync from start
    var i: usize = 0;
    while (i < len_old) : (i += 1) {
        if (std.mem.eql(u8, old_items[i].uuid, new_items[i].uuid)) {
            traverseNodes(old_items[i], new_items[i]);
        } else {
            break;
        }
    }

    // 2. Sync from end
    var back_i_old: usize = len_old;
    var back_i_new: usize = len_new;
    while (back_i_old > i and back_i_new > i) {
        const old_child = old_items[back_i_old - 1];
        const new_child = new_items[back_i_new - 1];

        if (std.mem.eql(u8, old_child.uuid, new_child.uuid)) {
            traverseNodes(old_child, new_child);
            back_i_old -= 1;
            back_i_new -= 1;
        } else {
            break;
        }
    }

    // 3. Process the middle "un-synced" section
    const start = i;
    const end_old = back_i_old;
    const end_new = back_i_new;

    // Add all *new* nodes from the middle section to the map
    for (new_items[start..end_new], start..) |new_child, j| {
        node_map.put(new_child.uuid, j) catch {
            Vapor.printlnSrcErr("Could not put node into node_map {any}\n", .{new_child.uuid}, @src());
        };
    }

    // Iterate *old* nodes in the middle section
    for (old_items[start..end_old], start..) |old_child, offset| {
        if (node_map.fetchRemove(old_child.uuid)) |new_child_entry| {
            const new_child = new_items[new_child_entry.value];
            traverseNodes(old_child, new_child);
            Vapor.has_dirty = true;
        } else {
            // Vapor.removed_nodes.append(.{ .uuid = old_child.uuid, .index = offset }) catch {};
            Vapor.Animation.removal_queue.enqueue(old_child, offset) catch {};
        }
    }

    // 4. Any nodes left in the map are additions
    var node_itr = node_map.iterator();
    while (node_itr.next()) |entry| {
        const new_child_index = entry.value_ptr.*;
        const new_child = new_items[new_child_index];
        new_child.state_type = .added;
        Vapor.markChildrenDirty(new_child);
    }
    Vapor.has_dirty = true;
}

// Single unified reconciliation function
fn reconcileChildren(old_node: *UINode, new_node: *UINode) void {
    const old_count = old_node.children_count;
    const new_count = new_node.children_count;

    if (new_count == 0) {
        if (old_count > 0) removeAllChildren(old_node);
        return;
    }
    if (old_count == 0) {
        addAllChildren(new_node);
        return;
    }

    const old_items = buildChildArray(old_node, old_count) orelse return;
    const new_items = buildChildArray(new_node, new_count) orelse return;

    // 1. Sync from start
    var start: usize = 0;
    while (start < old_count and start < new_count) {
        if (std.mem.eql(u8, old_items[start].uuid, new_items[start].uuid)) {
            traverseNodes(old_items[start], new_items[start]);
            start += 1;
        } else break;
    }

    // 2. Sync from end
    var end_old = old_count;
    var end_new = new_count;
    while (end_old > start and end_new > start) {
        if (std.mem.eql(u8, old_items[end_old - 1].uuid, new_items[end_new - 1].uuid)) {
            traverseNodes(old_items[end_old - 1], new_items[end_new - 1]);
            end_old -= 1;
            end_new -= 1;
        } else break;
    }

    // 3. Middle section - build maps for both UUID and fingerprint
    var old_by_uuid = std.StringHashMap(*UINode).init(Vapor.arena(.frame));
    var old_by_fingerprint = std.AutoHashMap(u64, std.array_list.Managed(*UINode)).init(Vapor.arena(.frame));
    defer old_by_uuid.deinit();
    defer old_by_fingerprint.deinit();

    // Index old nodes by UUID and fingerprint
    for (old_items[start..end_old]) |old_child| {
        old_by_uuid.put(old_child.uuid, old_child) catch {};

        // Group by fingerprint for move detection
        const entry = old_by_fingerprint.getOrPut(old_child.finger_print) catch continue;
        if (!entry.found_existing) {
            entry.value_ptr.* = std.array_list.Managed(*UINode).init(Vapor.arena(.frame));
        }
        entry.value_ptr.append(old_child) catch {};
    }

    // 4. Process new nodes in middle section
    for (new_items[start..end_new]) |new_child| {
        // First: exact UUID match (same position identity)
        if (old_by_uuid.fetchRemove(new_child.uuid)) |kv| {
            const old_child = kv.value;
            traverseNodes(old_child, new_child);
            removeFromFingerprintMap(&old_by_fingerprint, old_child);
            continue;
        }

        // Second: fingerprint match (node moved)
        if (old_by_fingerprint.getPtr(new_child.finger_print)) |list| {
            if (list.items.len > 0) {
                const old_child = list.pop() orelse continue;
                _ = old_by_uuid.remove(old_child.uuid);

                new_child.state_type = .moved;
                new_child.dirty = true;
                traverseNodes(old_child, new_child);
                Vapor.has_dirty = true;
                continue;
            }
        }

        // No match: truly new node
        new_child.state_type = .added;
        new_child.dirty = true;
        Vapor.markChildrenDirty(new_child);
        Vapor.has_dirty = true;
    }

    // 5. Remaining old nodes are deletions
    var iter = old_by_uuid.iterator();
    while (iter.next()) |entry| {
        const old_child = entry.value_ptr.*;
        Vapor.Animation.removal_queue.enqueue(old_child, 0) catch {};
    }
}

fn removeFromFingerprintMap(map: *std.AutoHashMap(u64, std.array_list.Managed(*UINode)), node: *UINode) void {
    if (map.getPtr(node.finger_print)) |list| {
        for (list.items, 0..) |item, i| {
            if (item == node) {
                _ = list.swapRemove(i);
                break;
            }
        }
    }
}

// --- Main Reconciler Function ---
pub fn traverseNodes(old_node: *UINode, new_node: *UINode) void {

    // --- 1. Reconcile current node properties ---
    const changed = (new_node.finger_print != old_node.finger_print);
    new_node.style_changed = (new_node.style_hash != old_node.style_hash);
    new_node.props_changed = (new_node.props_hash != old_node.props_hash);

    if (new_node.props_changed) {
        const old_handlers = old_node.event_handlers;
        const new_handlers = new_node.event_handlers;
        if (old_handlers) |old_h| {
            if (new_handlers) |new_h| {
                // Remove old handlers whose type isn't in the new set
                for (old_h.items.items) |old_handler| {
                    const still_exists = for (new_h.items.items) |new_handler| {
                        if (old_handler.event_type == new_handler.event_type) break true;
                    } else false;
                    if (!still_exists) {
                        _ = Vapor.removeElementEventListener(old_node, old_handler.event_type);
                    }
                }
            } else {
                // No new handlers at all, remove everything
                for (old_h.items.items) |old_handler| {
                    _ = Vapor.removeElementEventListener(old_node, old_handler.event_type);
                }
            }
        }
    }

    var is_dirty = changed or
        Vapor.rerender_everything or
        old_node.dirty;

    if (!std.mem.eql(u8, old_node.uuid, new_node.uuid)) {
        is_dirty = true;
    }

    new_node.dirty = is_dirty;
    if (is_dirty) {
        Vapor.has_dirty = true;
    }

    // --- 2. Reconcile children ---
    const old_count = old_node.children_count;
    const new_count = new_node.children_count;

    if (new_count == 0) {
        if (old_count > 0) {
            // Case: New is empty, Old had items -> Remove all old
            removeAllChildren(old_node);
        }
        // Else: Both empty -> Do nothing
    } else if (old_count == 0) {
        // Case: New has items, Old was empty -> Add all new
        addAllChildren(new_node);
    } else if (old_count == new_count) {
        // Case: Same length -> Try simple 1:1 traversal first, fall back to keyed
        reconcileSame(old_node, new_node, old_count); // TODO: This is working but the one below is not, for the form it duplicates the button on switch toggle
        // reconcileChildren(old_node, new_node);
    } else {
        // Case: Different lengths -> Keyed diff
        if (old_count > new_count) {
            reconcileDeletions(old_node, new_node, old_count, new_count);
        } else {
            reconcileAdditions(old_node, new_node, old_count, new_count);
        }
    }
}
