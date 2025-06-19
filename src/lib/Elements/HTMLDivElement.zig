const std = @import("std");

/// HTMLDivElement emulates the JavaScript HTMLDivElement interface
/// using snake_case naming convention instead of camelCase
pub const HTMLDivElement = struct {
    // Element properties
    id: ?[]const u8 = null,
    class_name: ?[]const u8 = null,
    tag_name: []const u8 = "DIV",
    inner_html: ?[]const u8 = null,
    outer_html: ?[]const u8 = null,
    inner_text: ?[]const u8 = null,
    text_content: ?[]const u8 = null,

    // HTMLElement properties
    title: ?[]const u8 = null,
    lang: ?[]const u8 = null,
    translate: bool = false,
    dir: ?[]const u8 = null,
    hidden: bool = false,
    tab_index: i32 = 0,
    access_key: ?[]const u8 = null,
    draggable: bool = false,
    spellcheck: bool = true,
    autocapitalize: ?[]const u8 = null,
    content_editable: bool = false,
    is_content_editable: bool = false,

    // Style related
    style: Style = Style{},

    // Size and position related
    client_height: f32 = 0,
    client_width: f32 = 0,
    client_left: f32 = 0,
    client_top: f32 = 0,
    offset_height: f32 = 0,
    offset_width: f32 = 0,
    offset_left: f32 = 0,
    offset_top: f32 = 0,
    scroll_height: f32 = 0,
    scroll_width: f32 = 0,
    scroll_left: f32 = 0,
    scroll_top: f32 = 0,

    // Attributes map
    attributes: std.StringHashMap([]const u8),

    // Child elements
    children: std.ArrayList(*HTMLElement),
    first_child: ?*HTMLElement = null,
    last_child: ?*HTMLElement = null,
    next_sibling: ?*HTMLElement = null,
    previous_sibling: ?*HTMLElement = null,
    parent_element: ?*HTMLElement = null,

    // Event handlers (represented as function pointers)
    on_click: ?fn () void = null,
    on_mouseover: ?fn () void = null,
    on_mouseout: ?fn () void = null,
    on_keydown: ?fn () void = null,
    on_keyup: ?fn () void = null,

    pub fn init(allocator: std.mem.Allocator) !HTMLDivElement {
        return HTMLDivElement{
            .attributes = std.StringHashMap([]const u8).init(allocator),
            .children = std.ArrayList(*HTMLElement).init(allocator),
        };
    }

    pub fn deinit(self: *HTMLDivElement) void {
        self.attributes.deinit();
        self.children.deinit();
    }

    // Methods
    pub fn get_attribute(self: *const HTMLDivElement, name: []const u8) ?[]const u8 {
        return self.attributes.get(name);
    }

    pub fn set_attribute(self: *HTMLDivElement, name: []const u8, value: []const u8) !void {
        try self.attributes.put(name, value);
    }

    pub fn remove_attribute(self: *HTMLDivElement, name: []const u8) void {
        _ = self.attributes.remove(name);
    }

    pub fn has_attribute(self: *const HTMLDivElement, name: []const u8) bool {
        return self.attributes.contains(name);
    }

    pub fn append_child(self: *HTMLDivElement, child: *HTMLElement) !void {
        try self.children.append(child);
        child.parent_element = @ptrCast(self);

        // Update last child
        self.last_child = child;

        // If this is the first child, update first_child too
        if (self.children.items.len == 1) {
            self.first_child = child;
        } else {
            // Update sibling relationships
            const previous_child = self.children.items[self.children.items.len - 2];
            previous_child.next_sibling = child;
            child.previous_sibling = previous_child;
        }
    }

    pub fn remove_child(self: *HTMLDivElement, child: *HTMLElement) !void {
        // Find the child index
        for (self.children.items, 0..) |elem, i| {
            if (elem == child) {
                // Update sibling relationships
                if (child.previous_sibling) |prev| {
                    prev.next_sibling = child.next_sibling;
                }
                if (child.next_sibling) |next| {
                    next.previous_sibling = child.previous_sibling;
                }

                // Update first/last child if needed
                if (self.first_child == child) {
                    self.first_child = child.next_sibling;
                }
                if (self.last_child == child) {
                    self.last_child = child.previous_sibling;
                }

                // Remove from children array
                _ = self.children.orderedRemove(i);
                child.parent_element = null;
                child.previous_sibling = null;
                child.next_sibling = null;
                return;
            }
        }

        return error.ChildNotFound;
    }
};

// Base HTMLElement type (simplified for this example)
pub const HTMLElement = struct {
    tag_name: []const u8,
    id: ?[]const u8 = null,
    class_name: ?[]const u8 = null,
    parent_element: ?*HTMLElement = null,
    next_sibling: ?*HTMLElement = null,
    previous_sibling: ?*HTMLElement = null,
};

// Style struct to represent CSS properties
pub const Style = struct {
    width: ?[]const u8 = null,
    height: ?[]const u8 = null,
    background_color: ?[]const u8 = null,
    color: ?[]const u8 = null,
    font_size: ?[]const u8 = null,
    font_family: ?[]const u8 = null,
    margin: ?[]const u8 = null,
    margin_top: ?[]const u8 = null,
    margin_right: ?[]const u8 = null,
    margin_bottom: ?[]const u8 = null,
    margin_left: ?[]const u8 = null,
    padding: ?[]const u8 = null,
    padding_top: ?[]const u8 = null,
    padding_right: ?[]const u8 = null,
    padding_bottom: ?[]const u8 = null,
    padding_left: ?[]const u8 = null,
    border: ?[]const u8 = null,
    border_radius: ?[]const u8 = null,
    display: ?[]const u8 = null,
    position: ?[]const u8 = null,
    top: ?[]const u8 = null,
    right: ?[]const u8 = null,
    bottom: ?[]const u8 = null,
    left: ?[]const u8 = null,
    flex_direction: ?[]const u8 = null,
    justify_content: ?[]const u8 = null,
    align_items: ?[]const u8 = null,
    z_index: ?i32 = null,
    overflow: ?[]const u8 = null,
    opacity: ?f32 = null,
    visibility: ?[]const u8 = null,
    text_align: ?[]const u8 = null,
    line_height: ?[]const u8 = null,
};
