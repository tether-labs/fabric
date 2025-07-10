const std = @import("std");
const UINode = @import("UITree.zig").UINode;
const Fabric = @import("Fabric.zig");
var current_label_len: usize = 0;
pub export fn getAriaLabel(node_ptr: ?*UINode) ?[*]const u8 {
    if (node_ptr == null) {
        return null;
    }
    if (node_ptr.?.aria_label) |label| {
        current_label_len = label.len;
        return label.ptr;
    }
    return null;
}
pub export fn getAriaLabelLen() usize {
    return current_label_len;
}

pub fn isMobile() bool {
    if (Fabric.browser_width < 786) {
        return true;
    } else {
        return false;
    }
}
