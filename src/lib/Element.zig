const mutateDomElement = @import("Fabric.zig").mutateDomElement;
const mutateDomElementStyle = @import("Fabric.zig").mutateDomElementStyle;
const mutateDomElementStyleString = @import("Fabric.zig").mutateDomElementStyleString;
const showDialog = @import("Fabric.zig").showDialog;
const types = @import("types.zig");
const closeDialog = @import("Fabric.zig").closeDialog;
const Fabric = @import("Fabric.zig");
const UINode = @import("UITree.zig").UINode;
const ElementType = @import("types.zig").ElementType;
const std = @import("std");

const Rect = struct {
    top: f32,
    left: f32,
    right: f32,
    bottom: f32,
    width: f32,
    height: f32,
};

const Offsets = struct {
    offset_top: f32,
    offset_left: f32,
    offset_right: f32,
    offset_bottom: f32,
    offset_width: f32,
    offset_height: f32,
};

const AttributeType = union(enum) {
    string: []const u8,
    number: f32,
};

pub const Element = struct {

    // Size and position related
    client_height: f32 = 0,
    client_width: f32 = 0,
    client_left: f32 = 0,
    client_top: f32 = 0,
    offset_height: f32 = 0,
    offsetWidth: u32 = 0,
    offset_left: f32 = 0,
    offset_top: f32 = 0,
    scroll_height: f32 = 0,
    scroll_width: f32 = 0,
    scroll_left: u32 = 0,
    scroll_top: u32 = 0,

    // Element properties
    id: ?[]const u8 = null,
    attribute: ?[]const u8 = null,
    draggable: bool = false,
    element_type: ElementType = .Block,
    _node_ptr: ?*UINode = null,

    style: struct {
        top: f32 = 0,
        left: f32 = 0,
        right: f32 = 0,
        bottom: f32 = 0,
        background: []const u8 = "white",
    } = .{},

    // class_name: ?[]const u8 = null,
    // tag_name: []const u8 = "DIV",
    // inner_html: ?[]const u8 = null,
    // outer_html: ?[]const u8 = null,
    // inner_text: ?[]const u8 = null,
    // text_content: ?[]const u8 = null,
    pub fn _get_id(self: *Element) ?[]const u8 {
        if (self._node_ptr) |node| {
            return node.uuid;
        } else if (self.id) |id| {
            return id;
        } else {
            return null;
        }
    }
    pub fn scrollTop(self: *Element, value: u32) void {
        const id = self._get_id() orelse {
            Fabric.printlnSrc("Id is null", .{}, @src());
            return;
        };
        const attribute: []const u8 = "scrollTop";
        mutateDomElement(id.ptr, id.len, attribute.ptr, attribute.len, value);
        self.scroll_top = value;
    }

    pub fn toOffsetWidth(self: *Element, value: u32) void {
        const id = self._get_id() orelse {
            Fabric.printlnSrc("Id is null", .{}, @src());
            return;
        };
        const attribute: []const u8 = "offsetWidth";
        mutateDomElement(id.ptr, id.len, attribute.ptr, attribute.len, value);
        @field(self, attribute) = value;
    }

    pub fn getAttributeNumber(self: *Element, attribute: []const u8) u32 {
        const id = self._get_id() orelse {
            Fabric.printlnSrc("Id is null", .{}, @src());
            return 0;
        };
        return Fabric.getAttributeWasmNumber(id.ptr, id.len, attribute.ptr, attribute.len);
    }

    pub fn mutate(self: *Element, attribute: []const u8, value: u32) void {
        const id = self._get_id() orelse {
            Fabric.printlnSrc("Id is null", .{}, @src());
            return;
        };
        mutateDomElement(id.ptr, id.len, attribute.ptr, attribute.len, value);
        @field(self, attribute) = value;
    }

    pub fn addInstListener(
        self: *Element,
        event_type: types.EventType,
        construct: anytype,
        cb: anytype,
    ) ?usize {
        const id = self._get_id() orelse {
            Fabric.printlnSrc("Id is null", .{}, @src());
            return null;
        };
        return Fabric.elementInstEventListener(id, event_type, construct, cb);
    }

    pub fn addListener(
        self: *Element,
        event_type: types.EventType,
        cb: *const fn (event: *Fabric.Event) void
    ) ?usize {
        const id = self._get_id() orelse {
            Fabric.printlnSrc("Id is null", .{}, @src());
            return null;
        };
        return Fabric.elementEventListener(id, event_type, cb);
    }

    pub fn removeListener(
        self: *Element,
        event_type: types.EventType,
        cb_idx: usize,
    ) ?bool {
        const id = self._get_id() orelse {
            Fabric.printlnSrc("Id is null", .{}, @src());
            return null;
        };
        return Fabric.destroyElementEventListener(id, event_type, cb_idx);
    }

    pub fn removeInstListener(
        self: *Element,
        event_type: types.EventType,
        cb_idx: usize,
    ) ?bool {
        const id = self._get_id() orelse {
            Fabric.printlnSrc("Id is null", .{}, @src());
            return null;
        };
        return Fabric.destroyElementInstEventListener(id, event_type, cb_idx);
    }

    pub fn mutateStyle(self: *Element, comptime attribute: []const u8, value: AttributeType) void {
        const id = self._get_id() orelse {
            Fabric.printlnSrc("Id is null", .{}, @src());
            return;
        };
        switch (value) {
            .number => |v| {
                mutateDomElementStyle(id.ptr, id.len, attribute.ptr, attribute.len, v);
            },
            .string => |v| {
                mutateDomElementStyleString(
                    id.ptr,
                    id.len,
                    attribute.ptr,
                    attribute.len,
                    v.ptr,
                    v.len,
                );
            },
        }
    }

    pub fn scrollLeft(self: *Element, value: u32) void {
        const id = self._get_id() orelse {
            Fabric.printlnSrc("Id is null", .{}, @src());
            return;
        };
        const attribute: []const u8 = "scrollLeft";
        mutateDomElement(id.ptr, id.len, attribute.ptr, attribute.len, value);
        self.scroll_left = value;
    }

    pub fn showModal(self: *Element) void {
        const id = self._get_id() orelse {
            Fabric.printlnSrc("Id is null", .{}, @src());
            return;
        };
        if (self.element_type != .Dialog) {
            Fabric.println("Must be Dialog type", .{});
            return;
        }
        showDialog(id.ptr, id.len);
    }
    pub fn closeModal(self: *Element) void {
        const id = self._get_id() orelse {
            Fabric.printlnSrc("Id is null", .{}, @src());
            return;
        };
        if (self.element_type != .Dialog) {
            Fabric.println("Must be Dialog type", .{});
            return;
        }
        closeDialog(id.ptr, id.len);
    }

    pub fn getOffsets(self: *Element) ?Offsets {
        const id = self._get_id() orelse {
            Fabric.printlnSrc("Id is null", .{}, @src());
            return null;
        };
        const bounds_ptr = Fabric.getOffsets(id.ptr, @intCast(id.len));
        return Offsets{
            .offset_top = bounds_ptr[0],
            .offset_left = bounds_ptr[1],
            .offset_right = bounds_ptr[2],
            .offset_bottom = bounds_ptr[3],
            .offset_width = bounds_ptr[4],
            .offset_height = bounds_ptr[5],
        };
    }

    pub fn getBoundingClientRect(self: *Element) ?Rect {
        const id = self._get_id() orelse {
            Fabric.printlnSrc("Id is null", .{}, @src());
            return;
        };
        const bounds_ptr = Fabric.getBoundingClientRect(id.ptr, id.len);
        return Rect{
            .top = bounds_ptr[0],
            .left = bounds_ptr[1],
            .right = bounds_ptr[2],
            .bottom = bounds_ptr[3],
            .width = bounds_ptr[4],
            .height = bounds_ptr[5],
        };
    }

    pub fn removeFromParent(self: *Element) void {
        const id = self._get_id() orelse {
            Fabric.printlnSrc("Id is null", .{}, @src());
            return;
        };
        Fabric.removeFromParent(id.ptr, id.len);
    }

    pub fn clear(self: *Element) void {
        const id = self._get_id() orelse {
            Fabric.printlnSrc("Id is null", .{}, @src());
            return;
        };
        const text = "";
        Fabric.setInputValue(id.ptr, @intCast(id.len), text.ptr, text.len);
    }
    pub fn setInputValue(self: Element, text: []const u8) void {
        const id = self._get_id() orelse {
            Fabric.printlnSrc("Id is null", .{}, @src());
            return;
        };
        Fabric.setInputValue(id.ptr, @intCast(id.len), text.ptr, text.len);
    }

    pub fn getInputValue(self: *Element) ?[]const u8 {
        const id = self._get_id() orelse {
            Fabric.printlnSrc("Id is null", .{}, @src());
            return null;
        };
        const resp = Fabric.getInputValue(id.ptr, @intCast(id.len));
        return std.mem.span(resp);
    }

    pub fn addChild(self: *Element, childId: []const u8) void {
        const id = self._get_id() orelse {
            Fabric.printlnSrc("Id is null", .{}, @src());
            return;
        };
        Fabric.addChild(id.ptr, id.len, childId.ptr, childId.len);
    }

    pub fn focus(self: *Element) ?void {
        const id = self._get_id() orelse {
            Fabric.printlnSrc("Id is null", .{}, @src());
            return;
        };
        if (self.element_type != .Input) {
            Fabric.println("Can only focus on Input Element, add element Type Input\n", .{});
            return null;
        }
        // Fabric.addClass(id.ptr, id.len, classId.ptr, classId.len);
        Fabric.focus(id);
    }

    pub fn addClass(self: *Element, classId: []const u8) void {
        const id = self._get_id() orelse {
            Fabric.printlnSrc("Id is null", .{}, @src());
            return;
        }; // Fabric.addClass(id.ptr, id.len, classId.ptr, classId.len);
        Fabric.addToClassesList(id, classId);
    }

    pub fn removeClass(self: *Element, classId: []const u8) void {
        const id = self._get_id() orelse {
            Fabric.printlnSrc("Id is null", .{}, @src());
            return;
        }; // Fabric.removeClass(id.ptr, id.len, classId.ptr, classId.len);
        Fabric.addToRemoveClassesList(id, classId);
    }

    pub fn click(self: *Element) void {
        const id = self._get_id() orelse {
            Fabric.printlnSrc("Id is null", .{}, @src());
            return;
        };
        if (self.element_type != .Input) {
            Fabric.println("Must be Input type", .{});
            return;
        }
        Fabric.callClickWASM(id.ptr, id.len);
    }

    // // HTMLElement properties
    // title: ?[]const u8 = null,
    // lang: ?[]const u8 = null,
    // translate: bool = false,
    // dir: ?[]const u8 = null,
    // hidden: bool = false,
    // tab_index: i32 = 0,
    // access_key: ?[]const u8 = null,
    // spellcheck: bool = true,
    // autocapitalize: ?[]const u8 = null,
    // content_editable: bool = false,
    // is_content_editable: bool = false,
    //

    //
    // // Attributes map
    // attributes: std.StringHashMap([]const u8),
    //
    // // Child elements
    // children: std.ArrayList(*HTMLElement),
    // first_child: ?*HTMLElement = null,
    // last_child: ?*HTMLElement = null,
    // next_sibling: ?*HTMLElement = null,
    // previous_sibling: ?*HTMLElement = null,
    // parent_element: ?*HTMLElement = null,
    //
    // // Event handlers (represented as function pointers)
    // on_click: ?fn () void = null,
    // on_mouseover: ?fn () void = null,
    // on_mouseout: ?fn () void = null,
    // on_keydown: ?fn () void = null,
    // on_keyup: ?fn () void = null,
    //
    // pub fn init(allocator: std.mem.Allocator) !HTMLDivElement {
    //     return HTMLDivElement{
    //         .attributes = std.StringHashMap([]const u8).init(allocator),
    //         .children = std.ArrayList(*HTMLElement).init(allocator),
    //     };
    // }
    //
    // pub fn deinit(self: *HTMLDivElement) void {
    //     self.attributes.deinit();
    //     self.children.deinit();
    // }
    //
    // // Methods
    // pub fn get_attribute(self: *const HTMLDivElement, name: []const u8) ?[]const u8 {
    //     return self.attributes.get(name);
    // }
    //
    // pub fn set_attribute(self: *HTMLDivElement, name: []const u8, value: []const u8) !void {
    //     try self.attributes.put(name, value);
    // }
    //
    // pub fn remove_attribute(self: *HTMLDivElement, name: []const u8) void {
    //     _ = self.attributes.remove(name);
    // }
    //
    // pub fn has_attribute(self: *const HTMLDivElement, name: []const u8) bool {
    //     return self.attributes.contains(name);
    // }
    //
    // pub fn append_child(self: *HTMLDivElement, child: *HTMLElement) !void {
    //     try self.children.append(child);
    //     child.parent_element = @ptrCast(self);
    //
    //     // Update last child
    //     self.last_child = child;
    //
    //     // If this is the first child, update first_child too
    //     if (self.children.items.len == 1) {
    //         self.first_child = child;
    //     } else {
    //         // Update sibling relationships
    //         const previous_child = self.children.items[self.children.items.len - 2];
    //         previous_child.next_sibling = child;
    //         child.previous_sibling = previous_child;
    //     }
    // }
    //
    // pub fn remove_child(self: *HTMLDivElement, child: *HTMLElement) !void {
    //     // Find the child index
    //     for (self.children.items, 0..) |elem, i| {
    //         if (elem == child) {
    //             // Update sibling relationships
    //             if (child.previous_sibling) |prev| {
    //                 prev.next_sibling = child.next_sibling;
    //             }
    //             if (child.next_sibling) |next| {
    //                 next.previous_sibling = child.previous_sibling;
    //             }
    //
    //             // Update first/last child if needed
    //             if (self.first_child == child) {
    //                 self.first_child = child.next_sibling;
    //             }
    //             if (self.last_child == child) {
    //                 self.last_child = child.previous_sibling;
    //             }
    //
    //             // Remove from children array
    //             _ = self.children.orderedRemove(i);
    //             child.parent_element = null;
    //             child.previous_sibling = null;
    //             child.next_sibling = null;
    //             return;
    //         }
    //     }
    //
    //     return error.ChildNotFound;
    // }
};
