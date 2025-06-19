const std = @import("std");
const UINode = @import("UITree.zig").UINode;
const println = @import("Fabric.zig").println;
// const print = std.debug.print;
const Fabric = @import("Fabric.zig");

// Set uses AutoHashMap underneath the hood
// this means that iterating through the set does not have consitent order
pub fn Set(comptime T: type) type {
    return struct {
        const Self = @This();
        map: std.AutoHashMap(T, void),

        pub fn init(allocator_ptr: *std.mem.Allocator) Set(T).Self {
            return .{
                .map = std.AutoHashMap(T, void).init(allocator_ptr.*),
            };
        }

        pub fn add(self: *Self, value: T) void {
            self.map.put(value, {}) catch |err| {
                std.log.err("{any}\n", .{err});
                return;
            };
        }
        pub fn get(self: *Self, value: T) ?void {
            return self.map.get(value);
        }
        pub fn deinit(self: *Self) void {
            self.map.deinit();
        }

        pub fn clearRetainingCapacity(self: *Self) void {
            self.map.clearRetainingCapacity();
        }

        pub fn count(self: *Self) usize {
            return self.map.count();
        }

        pub fn iterator(self: *Self) std.AutoHashMap(T, void).KeyIterator {
            return self.map.keyIterator();
        }
    };
}

const Action = struct {
    runFn: ActionProto,
    deinitFn: DeinitProto,
};

const ActionProto = *const fn (*Action) void;
const DeinitProto = *const fn (*std.mem.Allocator, *Node) void;

pub const Node = struct {
    data: Action,
};

const ComponentAction = struct {
    deinitFn: ComponentDeinitProto,
};
const ComponentDeinitProto = *const fn (*ComponentNode) void;

pub const ComponentNode = struct {
    data: ComponentAction,
};

/// Return a subslice of `data` containing only those elements
/// that also appear in `filterList`.
fn filterInPlace(comptime T: type, data: []*UINode, filterList: []T) void {

    // For each element in `data`, if it’s in `filterList`,
    // copy it down to `data[write_i++]`.
    for (data) |node| {
        if (contains(T, filterList, node.uuid)) {
            node.show = true;
        } else {
            node.show = false;
        }
    }

    // Now the first write_i elements are the “kept” ones.
}

fn contains(comptime T: type, arr: []T, needle: []const u8) bool {
    for (arr) |v| {
        if (std.mem.eql(u8, v.key, needle)) return true;
    }
    return false;
}

fn isSlice(comptime T: type) bool {
    return switch (@typeInfo(T)) {
        .pointer => true,
        else => false,
    };
}

pub fn Grain(comptime T: type) type {
    return struct {
        const Self = @This();
        const Subscriber = struct {
            cb: CallbackType,
            sig: ?*Grain(T).Self = null,
            func: ?*const fn (T) T = null,
        };
        const CallbackType = union(enum) {
            with_sig: *const fn (*Grain(T).Self, *const fn (T) T, T) void,
            no_sig: *const fn (T) void,
            // effect: Signature,
        };

        const Signature = struct {
            struct_type: type = void,
        };

        const Inner = struct {
            pub fn callback(sig: *Grain(T).Self, func: *const fn (T) T, new_value: T) void {
                const resp = func(new_value);
                sig.set(resp);
            }
        };

        const GrainClosure = struct {
            grain: *Grain(T).Self = undefined,
            node: ComponentNode = .{ .data = .{
                .deinitFn = deinitFn,
            } },

            pub fn deinitFn(node: *ComponentNode) void {
                const grain_node: *@This() = @alignCast(@fieldParentPtr("node", node));
                grain_node.grain.resetComponentSubs();
            }
        };

        _value: T,
        _parent: *UINode = undefined,
        _subscribers: Set(Subscriber) = undefined,
        _component_subscribers: std.ArrayList(*UINode) = undefined,
        allocator_ptr: *std.mem.Allocator,
        _is_batching: bool = false,
        _has_pending_update: bool = false,
        _pending_value: ?T = null,
        _closure: *GrainClosure = undefined,
        _sub_index: usize = 0,

        pub fn init(value: T, allocator_ptr: *std.mem.Allocator) *Grain(T).Self {
            const new_set = Set(Subscriber).init(allocator_ptr);
            const components_new_set = std.ArrayList(*UINode).init(allocator_ptr.*);

            const grain: *Grain(T).Self = allocator_ptr.create(Grain(T).Self) catch unreachable;
            const grain_closure = allocator_ptr.create(GrainClosure) catch unreachable;
            grain.* = Grain(T).Self{
                ._value = value,
                ._subscribers = new_set,
                ._component_subscribers = components_new_set,
                .allocator_ptr = allocator_ptr,
                ._is_batching = false,
                ._has_pending_update = false,
                ._pending_value = null,
                ._closure = grain_closure,
                ._sub_index = Fabric.grain_subs.items.len,
            };

            grain_closure.* = .{
                .grain = grain,
            };

            Fabric.grain_subs.append(
                &grain_closure.node,
            ) catch unreachable;

            return grain;
        }

        pub fn deinit(self: *Self) void {
            _ = Fabric.grain_subs.orderedRemove(self._sub_index);
            var iter = self._subscribers.iterator();
            while (iter.next()) |sub| {
                if (sub.sig) |sig| {
                    self.allocator_ptr.*.destroy(sig);
                }
            }
            self._subscribers.deinit();
            self.allocator_ptr.destroy(self);
        }

        pub fn icrement(self: *Self) void {
            if (@TypeOf(self._value) != u32 and @TypeOf(self._value) != i32 and @TypeOf(self._value) != f32) {
                return;
            }
            self._value = self._value + 1;
            self.notify();
            self.notifyComponents();
        }

        pub fn toggle(self: *Self) void {
            std.debug.assert(@TypeOf(self._value) == bool);
            self._value = !self._value;

            self.notify();
            self.notifyComponents();
        }

        pub fn set(self: *Self, new_value: T) void {
            self._value = new_value;

            self.notify();
            self.notifyComponents();
        }
        pub fn get(self: *Self) T {
            return self._value;
        }

        fn update(self: *Self, op: *const fn (T) void) void {
            @call(.auto, op, .{self._value});
        }

        /// Callback is run when the value changes
        pub fn tether(self: *Self, cb: *const fn (T) void) void {
            self._subscribers.add(.{
                .cb = .{ .no_sig = cb },
            });
        }

        pub fn subscribe(self: *Self, node_ptr: *UINode) void {
            self._component_subscribers.append(node_ptr) catch |err| {
                println("Err: {any}", .{err});
                unreachable;
            };
        }

        // is just a function that returns a new signal that depends on the current signal
        pub fn derived(
            self: *Self,
            cb: *const fn (T) T,
        ) !*Grain(T).Self {
            const new_sig = try self.allocator_ptr.create(Grain(T).Self);
            new_sig.* = Grain(T).init(self._value, self.allocator_ptr);

            self._subscribers.add(.{
                .cb = .{ .with_sig = Inner.callback },
                .func = cb,
                .sig = new_sig,
            });
            return new_sig;
        }

        fn notifyComponents(self: *Self) void {
            for (self._component_subscribers.items) |node| {
                if (node.type == ._If) {
                    if (@TypeOf(self._value) == bool) {
                        node.show = self._value;
                    }
                } else {
                    // while (iter.next()) |node| {
                    switch (T) {
                        usize, u32, i32, f32 => {
                            // node.*.text = std.fmt.allocPrint(self.allocator_ptr.*, "{any}", .{self._value}) catch |err| {
                            //     println("Error {any}\n", .{err});
                            //     unreachable;
                            // };
                            const string_value = std.fmt.allocPrint(std.heap.page_allocator, "{d}", .{self._value}) catch |err| {
                                println("Error {any}\n", .{err});
                                unreachable;
                            };

                            node.*.text = string_value;
                        },
                        []const u8 => {
                            node.*.text = self._value;
                        },
                        else => {},
                    }
                }

                self._parent = node;
                node.dirty = true;
                println("Node: {any} {any} {any}\n", .{ node.dirty, node.type, node.text });
            }

            Fabric.iterateTreeChildren(Fabric.current_ctx.ui_tree.?);
            Fabric.grain_rerender = true;
        }

        fn notify(self: *Self) void {
            var iter = self._subscribers.iterator();
            while (iter.next()) |sub| {
                switch (sub.cb) {
                    .no_sig => |cb| cb(self._value),
                    .with_sig => |cb| {
                        if (sub.sig != null and sub.func != null) {
                            cb(sub.sig.?, sub.func.?, self._value);
                        }
                    },
                }
            }
        }

        pub fn resetComponentSubs(self: *Self) void {
            self._component_subscribers.clearRetainingCapacity();
        }

        fn markChildrenDirty(self: *Self, node: *UINode) void {
            node.dirty = true;
            for (node.children.items) |child| {
                if (self._parent.type == ._If) {
                    // we set the values to the parent;
                    child.show = node.show;
                }
                self.markChildrenDirty(child);
            }
        }
    };
}
