const std = @import("std");
const mem = std.mem;
const Types = @import("types.zig");
const Alignment = Types.Alignment;
const Direction = Types.Direction;
const PositionType = Types.PositionType;
const FloatType = Types.FloatType;
const UINode = @import("UITree.zig").UINode;
const Sizing = Types.Sizing;
const Transform = Types.Transform;
const TextDecoration = Types.TextDecoration;
const Appearance = Types.Appearance;
const WhiteSpace = Types.WhiteSpace;
const FlexWrap = Types.FlexWrap;
const BoxSizing = Types.BoxSizing;
const Pos = Types.Pos;
const FlexType = Types.FlexType;
const Animation = Fabric.Animation;
const AnimationType = Types.AnimationType;
const ListStyle = Types.ListStyle;
const Transition = Types.Transition;
const Outline = Types.Outline;
const Cursor = Types.Cursor;
const RenderCommand = Types.RenderCommand;
const Fabric = @import("Fabric.zig");
const println = @import("Fabric.zig").println;

// Global buffer to store the CSS string for returning to JavaScript
var css_buffer: [4096]u8 = undefined;

// Helper function to convert Direction enum to CSS flex-direction
fn directionToCSS(dir: Direction) []const u8 {
    return switch (dir) {
        .column => "column",
        .row => "row",
    };
}

// Helper function to convert Alignment to CSS values
fn alignmentToCSS(_align: Alignment) []const u8 {
    return switch (_align) {
        .center => "center",
        .top => "flex-start",
        .bottom => "flex-end",
        .start => "flex-start",
        .end => "flex-end",
        .between => "space-between",
        .even => "space-evenly",
    };
}

// Helper function to convert PositionType to CSS values
fn positionTypeToCSS(pos_type: PositionType) []const u8 {
    return switch (pos_type) {
        .relative => "relative",
        .absolute => "absolute",
        .fixed => "fixed",
        .sticky => "sticky",
    };
}

// Helper function to convert FloatType to CSS values
fn floatTypeToCSS(float_type: FloatType) []const u8 {
    return switch (float_type) {
        .top => "top",
        .bottom => "bottom",
        .left => "left",
        .right => "right",
    };
}

// Helper function to convert SizingType to CSS values
fn sizingTypeToCSS(sizing: Sizing, writer: anytype) !void {
    switch (sizing.type) {
        .fit => try writer.writeAll("fit-content"),
        .grow => try writer.writeAll("auto"),
        .percent => try writer.print("{d}%", .{sizing.size.minmax.min * 100}),
        .fixed => try writer.print("{d}px", .{sizing.size.minmax.min}),
        .elastic => try writer.writeAll("auto"), // Could also use min/max width/height in separate properties
        .elastic_percent => try writer.print("{d}%", .{sizing.size.percent.min * 100}),
        .none => {},
    }
}

fn posTypeToCSS(pos: Pos, writer: anytype) !void {
    switch (pos.type) {
        .fit => try writer.writeAll("fit-content"),
        .grow => try writer.writeAll("auto"),
        .percent => try writer.print("{d}%", .{pos.value * 100}),
        .fixed => try writer.print("{d}px", .{pos.value}),
    }
}

// Helper function to convert color array to CSS rgba
fn colorToCSS(color: [4]f32, writer: anytype) !void {
    try writer.print("rgba({d}, {d}, {d}, {d})", .{
        @as(u8, @intFromFloat(color[0])),
        @as(u8, @intFromFloat(color[1])),
        @as(u8, @intFromFloat(color[2])),
        color[3] / 255.0,
    });
}

// Function to convert TransformType to CSS
fn transformToCSS(transform: Transform, writer: anytype) !void {
    switch (transform.type) {
        .none => {},
        .scale => try writer.print("scale({d})", .{transform.scale_size}),
        .translateX => try writer.print("translateX({d})", .{transform.dist}),
        .translateY => try writer.print("translateY({d})", .{transform.dist}),
    }
}

fn textDecoToCSS(text_decoration: TextDecoration, writer: anytype) !void {
    switch (text_decoration) {
        .none => try writer.writeAll("none"), // Not implemented in your struct
        .inherit => try writer.writeAll("inherit"), // Not implemented in your struct
        .underline => try writer.writeAll("underline"), // Not implemented in your struct
        .initial => try writer.writeAll("initial"), // Not implemented in your struct
        .overline => try writer.writeAll("overline"), // Not implemented in your struct
        .unset => try writer.writeAll("unset"), // Not implemented in your struct
        .revert => try writer.writeAll("revert"), // Not implemented in your struct
    }
}
fn appearanceToCSS(appearance: Appearance, writer: anytype) !void {
    switch (appearance) {
        .none => try writer.writeAll("none"),
        .auto => try writer.writeAll("auto"),
        .button => try writer.writeAll("button"),
        .textfield => try writer.writeAll("textfield"),
        .menulist => try writer.writeAll("menulist"),
        .searchfield => try writer.writeAll("searchfield"),
        .textarea => try writer.writeAll("textarea"),
        .checkbox => try writer.writeAll("checkbox"),
        .radio => try writer.writeAll("radio"),
        .inherit => try writer.writeAll("inherit"),
        .initial => try writer.writeAll("initial"),
        .revert => try writer.writeAll("revert"),
        .unset => try writer.writeAll("unset"),
    }
}

// Function to convert OutlineStyle enum to a CSS string
fn outlineStyleToCSS(style: Outline, writer: anytype) !void {
    switch (style) {
        .none => try writer.writeAll("none"),
        .auto => try writer.writeAll("auto"),
        .dotted => try writer.writeAll("dotted"),
        .dashed => try writer.writeAll("dashed"),
        .solid => try writer.writeAll("solid"),
        .double => try writer.writeAll("double"),
        .groove => try writer.writeAll("groove"),
        .ridge => try writer.writeAll("ridge"),
        .inset => try writer.writeAll("inset"),
        .outset => try writer.writeAll("outset"),
        .inherit => try writer.writeAll("inherit"),
        .initial => try writer.writeAll("initial"),
        .revert => try writer.writeAll("revert"),
        .unset => try writer.writeAll("unset"),
    }
}

fn transitionStyleToCSS(style: Transition, writer: anytype) void {
    if (style.properties) |prop| {
        for (prop) |p| {
            switch (p) {
                .transform => {
                    writer.print("{s} ", .{@tagName(p)}) catch return;
                },
                else => {},
            }
        }
    } else {
        writer.print("{s} ", .{"all"}) catch return;
    }
    writer.print("{any}ms ", .{style.duration}) catch return;
    switch (style.timing) {
        .ease => writer.writeAll("ease") catch return,
        .linear => writer.writeAll("linear") catch return,
        .ease_in => writer.writeAll("ease-in") catch return,
        .ease_out => writer.writeAll("ease-out") catch return,
        .ease_in_out => writer.writeAll("ease-in-out") catch return,
        .bounce => writer.writeAll("bounce") catch return,
        .elastic => writer.writeAll("elastic") catch return,
    }
}

// Function to convert ListStyle enum to CSS string
fn cursorToCSS(cursor_type: Cursor, writer: anytype) !void {
    switch (cursor_type) {
        .pointer => try writer.writeAll("pointer"),
        .help => try writer.writeAll("help"),
        .grab => try writer.writeAll("grab"),
        .zoom_in => try writer.writeAll("zoom-in"),
        .zoom_out => try writer.writeAll("zoom-out"),
    }
}

// Function to convert BoxSizing enum to CSS string
fn boxSizingToCSS(box_sizing: BoxSizing, writer: anytype) !void {
    switch (box_sizing) {
        .content_box => try writer.writeAll("content-box"),
        .border_box => try writer.writeAll("border-box"),
        .padding_box => try writer.writeAll("padding-box"),
        .inherit => try writer.writeAll("inherit"),
        .initial => try writer.writeAll("initial"),
        .revert => try writer.writeAll("revert"),
        .unset => try writer.writeAll("unset"),
    }
}

// Function to convert ListStyle enum to CSS string
fn listStyleToCSS(list_style: ListStyle, writer: anytype) !void {
    switch (list_style) {
        .none => try writer.writeAll("none"),
        .disc => try writer.writeAll("disc"),
        .circle => try writer.writeAll("circle"),
        .square => try writer.writeAll("square"),
        .decimal => try writer.writeAll("decimal"),
        .decimal_leading_zero => try writer.writeAll("decimal-leading-zero"),
        .lower_roman => try writer.writeAll("lower-roman"),
        .upper_roman => try writer.writeAll("upper-roman"),
        .lower_alpha => try writer.writeAll("lower-alpha"),
        .upper_alpha => try writer.writeAll("upper-alpha"),
        .lower_greek => try writer.writeAll("lower-greek"),
        .armenian => try writer.writeAll("armenian"),
        .georgian => try writer.writeAll("georgian"),
        .inherit => try writer.writeAll("inherit"),
        .initial => try writer.writeAll("initial"),
        .revert => try writer.writeAll("revert"),
        .unset => try writer.writeAll("unset"),
    }
}

// Function to convert FlexWrap enum to CSS string
fn flexWrapToCSS(flex_wrap: FlexWrap, writer: anytype) !void {
    switch (flex_wrap) {
        .nowrap => try writer.writeAll("nowrap"),
        .wrap => try writer.writeAll("wrap"),
        .wrap_reverse => try writer.writeAll("wrap-reverse"),
        .inherit => try writer.writeAll("inherit"),
        .initial => try writer.writeAll("initial"),
        .revert => try writer.writeAll("revert"),
        .unset => try writer.writeAll("unset"),
    }
}
fn animationToCSS(animation: Animation.Specs, writer: anytype) !void {
    try writer.print("{s} {any}s ", .{ animation.tag, animation.duration_s });
    switch (animation.timing_function) {
        .linear => try writer.writeAll("linear "),
        .ease => try writer.writeAll("ease "),
        .ease_in => try writer.writeAll("ease_in "),
        .ease_in_out => try writer.writeAll("ease_in_out "),
        .ease_out => try writer.writeAll("ease_out "),
    }
    switch (animation.direction) {
        .normal => try writer.writeAll("normal "),
        .reverse => try writer.writeAll("reverse "),
        .forwards => try writer.writeAll("forwards "),
        .pingpong => try writer.writeAll("alternate "),
    }
    if (animation.iteration_count.iter_count == 0) {
        try writer.writeAll("infinite");
    } else {
        // try writer.print("{d}", .{animation.iteration_count.iter_count});
    }
}

fn whiteSpaceToCSS(white_space: WhiteSpace, writer: anytype) !void {
    switch (white_space) {
        .normal => try writer.writeAll("normal"),
        .nowrap => try writer.writeAll("nowrap"),
        .pre => try writer.writeAll("pre"),
        .pre_wrap => try writer.writeAll("pre-wrap"),
        .pre_line => try writer.writeAll("pre-line"),
        .break_spaces => try writer.writeAll("break-spaces"),
        .inherit => try writer.writeAll("inherit"),
        .initial => try writer.writeAll("initial"),
        .revert => try writer.writeAll("revert"),
        .unset => try writer.writeAll("unset"),
    }
}

// Function to convert FlexType enum to a CSS string
fn flexTypeToCSS(flex_type: FlexType, writer: anytype) !void {
    switch (flex_type) {
        .flex => try writer.writeAll("flex"),
        .inline_flex => try writer.writeAll("inline-flex"),
        .inherit => try writer.writeAll("inherit"),
        .initial => try writer.writeAll("initial"),
        .revert => try writer.writeAll("revert"),
        .unset => try writer.writeAll("unset"),
        .none => try writer.writeAll("none"),
    }
}

// Export this function to be called from JavaScript to get the CSS representation
var style_style: []const u8 = "";
var global_len: usize = 0;
var show_scrollbar: bool = true;
pub export fn getStyle(node_ptr: ?*UINode) [*]const u8 {
    if (node_ptr == null) return style_style.ptr;
    const style = node_ptr.?.style;
    const ptr = node_ptr.?;
    // Create a default Hover style

    // Use a fixed buffer with a fbs to build the CSS string
    var fbs = std.io.fixedBufferStream(&css_buffer);
    var writer = fbs.writer();

    // Start CSS block
    // writer.writeAll("{\n") catch {};

    // Write position properties
    if (style.position) |p| {
        writer.print("  position: {s};\n", .{positionTypeToCSS(p.type)}) catch {};
        writer.writeAll("  left: ") catch {};
        posTypeToCSS(p.left, writer) catch {};
        writer.writeAll(";\n") catch {};

        writer.writeAll("  right: ") catch {};
        posTypeToCSS(p.right, writer) catch {};
        writer.writeAll(";\n") catch {};

        writer.writeAll("  top: ") catch {};
        posTypeToCSS(p.top, writer) catch {};
        writer.writeAll(";\n") catch {};

        writer.writeAll("  bottom: ") catch {};
        posTypeToCSS(p.bottom, writer) catch {};
        writer.writeAll(";\n") catch {};
    }

    // Write display and flex properties
    if (ptr.type == .FlexBox) {
        writer.writeAll("  display: flex;\n") catch {};
        writer.print("  flex-direction: {s};\n", .{directionToCSS(style.direction)}) catch {};
    } else if (style.display) |d| {
        writer.writeAll("  display: ") catch {};
        flexTypeToCSS(d, writer) catch {};
        writer.writeAll(";\n") catch {};
        writer.print("  flex-direction: {s};\n", .{directionToCSS(style.direction)}) catch {};
    }

    // Write width and height
    if (style.width.type != .none) {
        writer.writeAll("  width: ") catch {};
        sizingTypeToCSS(style.width, writer) catch {};
        writer.writeAll(";\n") catch {};
    }

    if (style.height.type != .none) {
        writer.writeAll("  height: ") catch {};
        sizingTypeToCSS(style.height, writer) catch {};
        writer.writeAll(";\n") catch {};
    }

    // Write font properties
    if (style.font_size) |fs| {
        writer.print("  font-size: {d}px;\n", .{fs}) catch {};
    }
    if (style.letter_spacing) |ls| {
        writer.print("  letter-spacing: {d}px;\n", .{@as(f32, @floatFromInt(ls)) / 1000.0}) catch {};
    }
    if (style.line_height) |lh| {
        writer.print("  line-height: {d}px;\n", .{lh}) catch {};
    }

    if (style.font_weight) |sf| {
        writer.print("  font-weight: {d};\n", .{sf}) catch {};
    }

    if (style.float_type) |ft| {
        writer.print("  float: {s};\n", .{floatTypeToCSS(ft)}) catch {};
    }

    if (style.font_family.len > 0) {
        writer.print("  font-family: {s};\n", .{style.font_family}) catch {};
    }
    // Border properties
    // if (style.border_thickness.top > 0 or
    //     style.border_thickness.right > 0 or
    //     style.border_thickness.bottom > 0 or
    //     style.border_thickness.left > 0)
    // {
    writer.print("  border-width: {d}px {d}px {d}px {d}px;\n", .{
        style.border_thickness.top,
        style.border_thickness.right,
        style.border_thickness.bottom,
        style.border_thickness.left,
    }) catch {};

    writer.writeAll("  border-style: solid;\n") catch {};

    writer.writeAll("  border-color: ") catch {};
    colorToCSS(style.border_color, writer) catch {};
    writer.writeAll(";\n") catch {};
    // }

    // Border radius
    if (style.border_radius.top_left > 0 or
        style.border_radius.top_right > 0 or
        style.border_radius.bottom_right > 0 or
        style.border_radius.bottom_left > 0)
    {
        writer.print("  border-radius: {d}px {d}px {d}px {d}px;\n", .{
            style.border_radius.top_left,
            style.border_radius.top_right,
            style.border_radius.bottom_right,
            style.border_radius.bottom_left,
        }) catch {};
    }

    // Text color
    writer.writeAll("  color: ") catch {};
    colorToCSS(style.text_color, writer) catch {};
    writer.writeAll(";\n") catch {};

    // Padding
    writer.print("  padding: {d}px {d}px {d}px {d}px;\n", .{
        style.padding.top,
        style.padding.right,
        style.padding.bottom,
        style.padding.left,
    }) catch {};
    writer.print("  margin: {d}px {d}px {d}px {d}px;\n", .{
        style.margin.top,
        style.margin.right,
        style.margin.bottom,
        style.margin.left,
    }) catch {};

    // Alignment
    writer.print("  justify-content: {s};\n", .{alignmentToCSS(style.child_alignment.x)}) catch {};
    writer.print("  align-items: {s};\n", .{alignmentToCSS(style.child_alignment.y)}) catch {};

    if (style.child_gap > 0) {
        writer.print("  gap: {d}px;\n", .{style.child_gap}) catch {};
    }

    // Background color
    writer.writeAll("  background-color: ") catch {};
    colorToCSS(style.background, writer) catch {};
    writer.writeAll(";\n") catch {};

    // Shadow
    if (style.shadow.blur > 0 or style.shadow.spread > 0 or
        style.shadow.top > 0 or style.shadow.left > 0)
    {
        writer.writeAll("  box-shadow: ") catch {};
        writer.print("{d}px {d}px {d}px {d}px ", .{
            style.shadow.left,
            style.shadow.top,
            style.shadow.blur,
            style.shadow.spread,
        }) catch {};

        colorToCSS(style.shadow.color, writer) catch {};
        writer.writeAll(";\n") catch {};
    }

    // Text-Deco
    if (style.text_decoration) |td| {
        writer.writeAll("  text-decoration: ") catch {};
        textDecoToCSS(td, writer) catch {};
        writer.writeAll(";\n") catch {};
    }

    if (style.white_space) |ws| {
        writer.writeAll("  white-space: ") catch {};
        whiteSpaceToCSS(ws, writer) catch {};
        writer.writeAll(";\n") catch {};
    }
    if (style.flex_wrap) |fw| {
        writer.writeAll("  flex-wrap: ") catch {};
        flexWrapToCSS(fw, writer) catch {};
        writer.writeAll(";\n") catch {};
    }
    if (style.box_sizing) |bs| {
        writer.writeAll("  box-sizing: ") catch {};
        boxSizingToCSS(bs, writer) catch {};
        writer.writeAll(";\n") catch {};
    }

    if (style.animation) |an| {
        writer.writeAll("  animation: ") catch {};
        animationToCSS(an, writer) catch {};
        writer.writeAll(";\n") catch {};
        writer.print("  animation-delay: {any}s", .{an.delay}) catch {};
        writer.writeAll(";\n") catch {};
    }

    if (style.z_index) |zi| {
        writer.print("  z-index: {d}", .{zi}) catch {};
        writer.writeAll(";\n") catch {};
    }

    if (style.blur) |bl| {
        writer.print("  backdrop-filter: blur({d}px)", .{bl}) catch {};
        writer.writeAll(";\n") catch {};
    }

    if (style.overflow) |ovf| {
        switch (ovf) {
            .scroll => writer.writeAll("  overflow: scroll;\n") catch {},
            .hidden => writer.writeAll("  overflow: hidden;\n") catch {},
        }
    }

    if (style.overflow_x) |ovf| {
        switch (ovf) {
            .scroll => writer.writeAll("  overflow-x: scroll;\n") catch {},
            .hidden => writer.writeAll("  overflow-x: hidden;\n") catch {},
        }
    }

    if (style.overflow_y) |ovf| {
        switch (ovf) {
            .scroll => writer.writeAll("  overflow-y: scroll;\n") catch {},
            .hidden => writer.writeAll("  overflow-y: hidden;\n") catch {},
        }
    }

    if (style.flex_shrink) |fs| {
        writer.print("  flex-shrink: {d};\n", .{fs}) catch {};
    }

    if (style.list_style) |ls| {
        writer.writeAll("  list-style: ") catch {};
        listStyleToCSS(ls, writer) catch {};
        writer.writeAll(";\n") catch {};
    }

    if (style.outline) |ol| {
        writer.writeAll("  outline: ") catch {};
        outlineStyleToCSS(ol, writer) catch {};
        writer.writeAll(";\n") catch {};
    }

    writer.print("  opacity: {d};\n", .{style.opacity}) catch {};

    if (style.transition) |tr| {
        writer.writeAll("  transition: ") catch {};
        transitionStyleToCSS(tr, writer);
        writer.writeAll(";\n") catch {};
    }

    if (!style.show_scrollbar) {
        writer.writeAll("  scrollbar-width: none;\n") catch {};
        show_scrollbar = false;
    }
    if (style.accent_color) |ac| {
        writer.writeAll("  accent-color: ") catch {};
        colorToCSS(ac, writer) catch {};
        writer.writeAll(";\n") catch {};
    }

    if (style.cursor) |c| {
        writer.writeAll("  cursor: ") catch {};
        cursorToCSS(c, writer) catch {};
        writer.writeAll(";\n") catch {};
    }

    if (style.web_kit_appearance) |ap| {
        writer.writeAll("  -webkit-appearance: ") catch {};
        appearanceToCSS(ap, writer) catch {};
        writer.writeAll(";\n") catch {};
    }

    if (style.appearance) |ap| {
        writer.writeAll("  appearance: ") catch {};
        appearanceToCSS(ap, writer) catch {};
        writer.writeAll(";\n") catch {};
    }

    if (style.will_change) |wc| {
        writer.writeAll("  will-change: ") catch {};
        switch (wc) {
            .transform => {
                writer.print("{s}", .{@tagName(wc)}) catch {};
            },
            else => {},
        }
        writer.writeAll(";\n") catch {};
    }

    if (style.backface_visibility) |bv| {
        writer.print("backface-visibility: {s}\n", .{bv}) catch {};
    }

    // // Transform
    // if (style.transform.type != .none) {
    //     writer.writeAll("  transform: ") catch {};
    //     transformToCSS(style.transform, writer) catch {};
    //     writer.writeAll(";\n") catch {};
    // }

    // Close CSS block
    // writer.writeAll("}\n") catch {};

    // Null-terminate the string
    const len: usize = @intCast(fbs.getPos() catch 0);
    css_buffer[len] = 0;
    style_style = css_buffer[0..len];

    if (style.transition) |_| {
        println("style {s}", .{style_style});
    }

    // Return a pointer to the CSS string
    return style_style.ptr;
}

export fn showScrollBar() bool {
    return show_scrollbar;
}

export fn getStyleLen() usize {
    return style_style.len;
}

var check_mark_style: []const u8 = "";
var chmrk_css_buffer: [4096]u8 = undefined;
export fn getCheckMarkStylePtr(node_ptr: ?*UINode) [*]const u8 {
    if (node_ptr == null) return check_mark_style.ptr;
    const style = node_ptr.?.style.checkmark_style orelse return check_mark_style.ptr;
    // Create a default Hover style

    // Use a fixed buffer with a fbs to build the CSS string
    var fbs = std.io.fixedBufferStream(&chmrk_css_buffer);
    var writer = fbs.writer();

    // Start CSS block
    // writer.writeAll("{\n") catch {};

    // Write position properties
    if (style.position) |hp| {
        writer.print("  position: {s};\n", .{positionTypeToCSS(hp.type)}) catch {};
        writer.writeAll("  left: ") catch {};
        posTypeToCSS(hp.left, writer) catch {};
        writer.writeAll(";\n") catch {};

        writer.writeAll("  right: ") catch {};
        posTypeToCSS(hp.right, writer) catch {};
        writer.writeAll(";\n") catch {};

        writer.writeAll("  top: ") catch {};
        posTypeToCSS(hp.top, writer) catch {};
        writer.writeAll(";\n") catch {};

        writer.writeAll("  bottom: ") catch {};
        posTypeToCSS(hp.bottom, writer) catch {};
        writer.writeAll(";\n") catch {};
    }

    if (style.display) |d| {
        writer.writeAll("  display: ") catch {};
        flexTypeToCSS(d, writer) catch {};
        writer.writeAll(";\n") catch {};
    }

    // Write display and flex properties
    // writer.writeAll("  display: flex;\n") catch {};
    if (style.direction) |hd| {
        writer.print("  flex-direction: {s};\n", .{directionToCSS(hd)}) catch {};
    }

    // Write width and height
    if (style.width) |hw| {
        if (hw.type != .none) {
            writer.writeAll("  width: ") catch {};
            sizingTypeToCSS(hw, writer) catch {};
            writer.writeAll(";\n") catch {};
        }
    }

    if (style.height) |hh| {
        if (hh.type != .none) {
            writer.writeAll("  height: ") catch {};
            sizingTypeToCSS(hh, writer) catch {};
            writer.writeAll(";\n") catch {};
        }
    }

    // Write font properties
    if (style.font_size) |fs| {
        writer.print("  font-size: {d}px;\n", .{fs}) catch {};
    }
    if (style.letter_spacing) |ls| {
        writer.print("  letter-spacing: {d}px;\n", .{@as(f32, @floatFromInt(ls)) / 1000.0}) catch {};
    }
    if (style.line_height) |lh| {
        writer.print("  line-height: {d}px;\n", .{lh}) catch {};
    }

    if (style.font_weight) |hf| {
        if (hf > 0) {
            writer.print("  font-weight: {d};\n", .{hf}) catch {};
        }
    }

    // Border properties
    if (style.border_thickness) |hbt| {
        if (hbt.top > 0 or
            hbt.right > 0 or
            hbt.bottom > 0 or
            hbt.left > 0)
        {
            writer.print("  border-width: {d}px {d}px {d}px {d}px;\n", .{
                hbt.top,
                hbt.right,
                hbt.bottom,
                hbt.left,
            }) catch {};

            writer.writeAll("  border-style: solid;\n") catch {};

            writer.writeAll("  border-color: ") catch {};
            colorToCSS(style.border_color, writer) catch {};
            writer.writeAll(";\n") catch {};
        }
    }

    // Border radius
    if (style.border_radius) |hbr| {
        if (hbr.top_left > 0 or
            hbr.top_right > 0 or
            hbr.bottom_right > 0 or
            hbr.bottom_left > 0)
        {
            writer.print("  border-radius: {d}px {d}px {d}px {d}px;\n", .{
                hbr.top_left,
                hbr.top_right,
                hbr.bottom_right,
                hbr.bottom_left,
            }) catch {};
        }
    }

    // Text color
    if (style.text_color) |tc| {
        writer.writeAll("  color: ") catch {};
        colorToCSS(tc, writer) catch {};
        writer.writeAll(";\n") catch {};
    }

    // Padding
    if (style.padding) |tp| {
        if (tp.top > 0 or
            tp.right > 0 or
            tp.bottom > 0 or
            tp.left > 0)
        {
            writer.print("  padding: {d}px {d}px {d}px {d}px;\n", .{
                tp.top,
                tp.right,
                tp.bottom,
                tp.left,
            }) catch {};
        }
    }

    // Alignment
    if (style.child_alignment) |hca| {
        writer.print("  justify-content: {s};\n", .{alignmentToCSS(hca.x)}) catch {};
        writer.print("  align-items: {s};\n", .{alignmentToCSS(hca.y)}) catch {};
    }

    if (style.child_gap > 0) {
        writer.print("  gap: {d}px;\n", .{style.child_gap}) catch {};
    }

    // Background color
    if (style.background) |hb| {
        writer.writeAll("  background-color: ") catch {};
        colorToCSS(hb, writer) catch {};
        writer.writeAll(";\n") catch {};
    }

    // Shadow
    if (style.shadow.blur > 0 or style.shadow.spread > 0 or
        style.shadow.top > 0 or style.shadow.left > 0)
    {
        writer.writeAll("  box-shadow: ") catch {};
        writer.print("{d}px {d}px {d}px {d}px ", .{
            style.shadow.left,
            style.shadow.top,
            style.shadow.blur,
            style.shadow.spread,
        }) catch {};

        colorToCSS(style.shadow.color, writer) catch {};
        writer.writeAll(";\n") catch {};
    }

    // Transform
    if (style.transform.type != .none) {
        writer.writeAll("  transform: ") catch {};
        transformToCSS(style.transform, writer) catch {};
        writer.writeAll(";\n") catch {};
    }

    // writer.print("  opacity: {d};\n", .{style.opacity}) catch {};

    // Null-terminate the string
    const len: usize = @intCast(fbs.getPos() catch 0);
    chmrk_css_buffer[len] = 0;
    check_mark_style = chmrk_css_buffer[0..len];

    // Return a pointer to the CSS string
    return check_mark_style.ptr;
}

export fn getCheckMarkLen() usize {
    return check_mark_style.len;
}
export fn hasEctClasses(node_ptr: ?*UINode) usize {
    if (node_ptr == null) return 0;
    const style = node_ptr.?.style;
    if (style.child_styles) |_| {
        return 1;
    }
    return 0;
}

export fn addEctClasses(node_ptr: ?*UINode) void {
    if (node_ptr == null) return;
    const node_style = node_ptr.?.style;
    // const ptr = node_ptr.?;
    // Create a default Hover style

    for (node_style.child_styles.?) |style| {
        // Use a fixed buffer with a fbs to build the CSS string
        var fbs = std.io.fixedBufferStream(&css_buffer);
        var writer = fbs.writer();

        // Write position properties
        writer.print(".{s} ", .{style.style_id}) catch {};
        writer.writeAll("{\n") catch {};
        // Write position properties
        if (style.position) |p| {
            writer.print("  position: {s};\n", .{positionTypeToCSS(p.type)}) catch {};
            writer.writeAll("  left: ") catch {};
            posTypeToCSS(p.left, writer) catch {};
            writer.writeAll(";\n") catch {};

            writer.writeAll("  right: ") catch {};
            posTypeToCSS(p.right, writer) catch {};
            writer.writeAll(";\n") catch {};

            writer.writeAll("  top: ") catch {};
            posTypeToCSS(p.top, writer) catch {};
            writer.writeAll(";\n") catch {};

            writer.writeAll("  bottom: ") catch {};
            posTypeToCSS(p.bottom, writer) catch {};
            writer.writeAll(";\n") catch {};
        }
        // // Write display and flex properties
        // if (ptr.type == .FlexBox or ptr.type == .List or style.display != null) {
        //     writer.writeAll("  display: flex;\n") catch {};
        //     writer.print("  flex-direction: {s};\n", .{directionToCSS(style.direction)}) catch {};
        // }

        // Write width and height
        if (style.display) |d| {
            writer.writeAll("  display: ") catch {};
            flexTypeToCSS(d, writer) catch {};
            writer.writeAll(";\n") catch {};
        }

        // Write width and height
        if (style.width) |hw| {
            if (hw.type != .none) {
                writer.writeAll("  width: ") catch {};
                sizingTypeToCSS(hw, writer) catch {};
                writer.writeAll(";\n") catch {};
            }
        }

        if (style.height) |hh| {
            if (hh.type != .none) {
                writer.writeAll("  height: ") catch {};
                sizingTypeToCSS(hh, writer) catch {};
                writer.writeAll(";\n") catch {};
            }
        }

        // Border properties
        if (style.border_thickness) |hbt| {
            if (hbt.top > 0 or
                hbt.right > 0 or
                hbt.bottom > 0 or
                hbt.left > 0)
            {
                writer.print("  border-width: {d}px {d}px {d}px {d}px;\n", .{
                    hbt.top,
                    hbt.right,
                    hbt.bottom,
                    hbt.left,
                }) catch {};

                writer.writeAll("  border-style: solid;\n") catch {};

                if (style.border_color) |bc| {
                    writer.writeAll("  border-color: ") catch {};
                    colorToCSS(bc, writer) catch {};
                    writer.writeAll(";\n") catch {};
                }
            }
        }

        // Border radius
        if (style.border_radius) |hbr| {
            if (hbr.top_left > 0 or
                hbr.top_right > 0 or
                hbr.bottom_right > 0 or
                hbr.bottom_left > 0)
            {
                writer.print("  border-radius: {d}px {d}px {d}px {d}px;\n", .{
                    hbr.top_left,
                    hbr.top_right,
                    hbr.bottom_right,
                    hbr.bottom_left,
                }) catch {};
            }
        }

        // Text color
        if (style.text_color) |tc| {
            writer.writeAll("  color: ") catch {};
            colorToCSS(tc, writer) catch {};
            writer.writeAll(";\n") catch {};
        }

        // Padding
        if (style.padding) |tp| {
            if (tp.top > 0 or
                tp.right > 0 or
                tp.bottom > 0 or
                tp.left > 0)
            {
                writer.print("  padding: {d}px {d}px {d}px {d}px;\n", .{
                    tp.top,
                    tp.right,
                    tp.bottom,
                    tp.left,
                }) catch {};
            }
        }

        if (style.margin) |m| {
            writer.print("  margin: {d}px {d}px {d}px {d}px;\n", .{
                m.top,
                m.right,
                m.bottom,
                m.left,
            }) catch {};
        }

        // Alignment
        if (style.child_alignment) |ca| {
            writer.print("  justify-content: {s};\n", .{alignmentToCSS(ca.x)}) catch {};
            writer.print("  align-items: {s};\n", .{alignmentToCSS(ca.y)}) catch {};
        }

        if (style.child_gap > 0) {
            writer.print("  gap: {d}px;\n", .{style.child_gap}) catch {};
        }

        // Background color
        if (style.background) |b| {
            writer.writeAll("  background-color: ") catch {};
            colorToCSS(b, writer) catch {};
            writer.writeAll(";\n") catch {};
        }

        // Shadow
        if (style.shadow.blur > 0 or style.shadow.spread > 0 or
            style.shadow.top > 0 or style.shadow.left > 0)
        {
            writer.writeAll("  box-shadow: ") catch {};
            writer.print("{d}px {d}px {d}px {d}px ", .{
                style.shadow.left,
                style.shadow.top,
                style.shadow.blur,
                style.shadow.spread,
            }) catch {};

            colorToCSS(style.shadow.color, writer) catch {};
            writer.writeAll(";\n") catch {};
        }

        // Text-Deco
        if (style.text_decoration) |td| {
            writer.writeAll("  text-decoration: ") catch {};
            textDecoToCSS(td, writer) catch {};
            writer.writeAll(";\n") catch {};
        }

        if (style.white_space) |ws| {
            writer.writeAll("  white-space: ") catch {};
            whiteSpaceToCSS(ws, writer) catch {};
            writer.writeAll(";\n") catch {};
        }
        if (style.flex_wrap) |fw| {
            writer.writeAll("  flex-wrap: ") catch {};
            flexWrapToCSS(fw, writer) catch {};
            writer.writeAll(";\n") catch {};
        }

        if (style.animation) |an| {
            writer.writeAll("  animation: ") catch {};
            animationToCSS(an, writer) catch {};
            writer.writeAll(";\n") catch {};
            writer.print("  animation-delay: {any}s", .{an.delay}) catch {};
            writer.writeAll(";\n") catch {};
        }

        if (style.z_index) |zi| {
            writer.print("  z-index: {d}", .{zi}) catch {};
            writer.writeAll(";\n") catch {};
        }

        if (style.blur) |bl| {
            writer.print("  backdrop-filter: blur({d}px)", .{bl}) catch {};
            writer.writeAll(";\n") catch {};
        }

        if (style.overflow) |ovf| {
            switch (ovf) {
                .scroll => writer.writeAll("  overflow: scroll;\n") catch {},
                .hidden => writer.writeAll("  overflow: hidden;\n") catch {},
            }
        }

        if (style.overflow_x) |ovf| {
            switch (ovf) {
                .scroll => writer.writeAll("  overflow-x: scroll;\n") catch {},
                .hidden => writer.writeAll("  overflow-x: hidden;\n") catch {},
            }
        }

        if (style.overflow_y) |ovf| {
            switch (ovf) {
                .scroll => writer.writeAll("  overflow-y: scroll;\n") catch {},
                .hidden => writer.writeAll("  overflow-y: hidden;\n") catch {},
            }
        }

        if (style.flex_shrink) |fs| {
            writer.print("  flex-shrink: {d};\n", .{fs}) catch {};
        }

        if (style.list_style) |ls| {
            writer.writeAll("  list-style: ") catch {};
            listStyleToCSS(ls, writer) catch {};
            writer.writeAll(";\n") catch {};
        }

        if (style.outline) |ol| {
            writer.writeAll("  outline: ") catch {};
            outlineStyleToCSS(ol, writer) catch {};
            writer.writeAll(";\n") catch {};
        }

        writer.print("  opacity: {d};\n", .{style.opacity}) catch {};

        if (style.transition) |tr| {
            writer.writeAll("  transition: ") catch {};
            transitionStyleToCSS(tr, writer);
            writer.writeAll(";\n") catch {};
        }

        if (!style.show_scrollbar) {
            writer.writeAll("  scrollbar-width: none;\n") catch {};
            show_scrollbar = false;
        }
        if (style.accent_color) |ac| {
            writer.writeAll("  accent-color: ") catch {};
            colorToCSS(ac, writer) catch {};
            writer.writeAll(";\n") catch {};
        }

        // Close CSS block
        writer.writeAll("}\n") catch {};

        // Null-terminate the string
        const len: usize = @intCast(fbs.getPos() catch 0);
        css_buffer[len] = 0;
        style_style = css_buffer[0..len];
        Fabric.createClass(style_style.ptr, style_style.len);
    }
}

pub export fn nextMotion() bool {
    if (Fabric.motions.items.len == 0) return false;
    return true;
}

var key_frames_buffer: [4096]u8 = undefined;
var key_frame_style: []const u8 = "";
pub export fn getKeyFrames(_: *Fabric.Animation.Motion) ?[*]const u8 {
    const motion = Fabric.motions.pop() orelse return null;
    // Create a default Hover style

    // Use a fixed buffer with a fbs to build the CSS string
    var fbs = std.io.fixedBufferStream(&key_frames_buffer);
    var writer = fbs.writer();

    writer.print("@keyframes {s} ", .{motion.tag}) catch {};
    writer.writeAll("{\n") catch {};
    // FROM
    writer.writeAll("  from {\n") catch {};
    writer.writeAll("    transform: ") catch {};
    switch (motion.from.type) {
        .none => {},
        .scale => writer.print("scale({d})", .{motion.from.scale_size}) catch {},
        .translateX => writer.print("translateX({d}px)", .{motion.from.dist}) catch {},
        .translateY => writer.print("translateY({d}px)", .{motion.from.dist}) catch {},
    }
    writer.writeAll(";\n") catch {};
    if (motion.from.opacity) |from_op| {
        writer.print("    opacity: {d};\n", .{from_op}) catch {};
    }
    if (motion.from.height) |from_h| {
        writer.writeAll("  height: ") catch {};
        sizingTypeToCSS(from_h, writer) catch {};
        writer.writeAll(";\n") catch {};
    }

    writer.writeAll("  }\n") catch {};

    // TO
    writer.writeAll("  to {\n") catch {};
    writer.writeAll("    transform: ") catch {};
    switch (motion.to.type) {
        .none => {},
        .scale => writer.print("scale({d})", .{motion.to.scale_size}) catch {},
        .translateX => writer.print("translateX({d}px)", .{motion.to.dist}) catch {},
        .translateY => writer.print("translateY({d}px)", .{motion.to.dist}) catch {},
    }
    writer.writeAll(";\n") catch {};
    if (motion.to.opacity) |to_op| {
        writer.print("    opacity: {d};\n", .{to_op}) catch {};
    }
    if (motion.to.height) |to_h| {
        writer.writeAll("  height: ") catch {};
        sizingTypeToCSS(to_h, writer) catch {};
        writer.writeAll(";\n") catch {};
    }

    writer.writeAll("  }\n") catch {};
    writer.writeAll("  }\n") catch {};

    const len: usize = @intCast(fbs.getPos() catch 0);
    key_frames_buffer[len] = 0;
    key_frame_style = key_frames_buffer[0..len];

    // Return a pointer to the CSS string
    return key_frame_style.ptr;
}
export fn getKeyFramesLen() usize {
    return key_frame_style.len;
}

// // Function to get just the style direction CSS value
// export fn getHoverDirection() [*:0]const u8 {
//     const style = Hover{};
//     const dir_str = directionToCSS(style.direction);
//
//     // Copy to buffer and null-terminate
//     @memcpy(&css_buffer, dir_str);
//     css_buffer[dir_str.len] = 0;
//
//     return &css_buffer;
// }
//
// // Function to debug the memory layout of the Hover struct
// export fn debugHoverLayout() void {
//     std.debug.print("Size of Hover: {}\n", .{@sizeOf(Hover)});
//
//     inline for (std.meta.fields(Hover)) |field| {
//         std.debug.print("Field {s}: offset={}, size={}\n", .{ field.name, @offsetOf(Hover, field.name), @sizeOf(field.type) });
//     }
//
//     // Specifically for direction
//     std.debug.print("Direction offset: {}\n", .{@offsetOf(Hover, "direction")});
//     std.debug.print("Direction size: {}\n", .{@sizeOf(Direction)});
// }

// // Function to retrieve the offset of a specific field
// export fn getFieldOffset(comptime field_name: []const u8) usize {
//     return @offsetOf(Hover, field_name);
// }
//
// // Function specifically for direction field
// export fn getDirectionOffset() usize {
//     return @offsetOf(Hover, "direction");
// }
//
// // Function to get the size of the Direction enum
// export fn getDirectionSize() usize {
//     return @sizeOf(Direction);
// }
//
// // Function to get the actual direction value
// export fn getDirectionValue() u8 {
//     const style = Hover{};
//     return @intFromEnum(style.direction);
// }
