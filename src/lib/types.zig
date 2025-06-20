const std = @import("std");
const UINode = @import("UITree.zig").UINode;
const Fabric = @import("Fabric.zig");
pub const Transition = @import("Transition.zig").Transition;
pub const TransitionProperty = @import("Transition.zig").TransitionProperty;
const print = std.debug.print;
const ColorTheme = @import("constants/Color.zig");
const Animation = @import("Animation.zig");
pub const color_theme: ColorTheme = ColorTheme{};

pub fn switchColorTheme() void {
    switch (color_theme.theme) {
        .dark => color_theme.theme = .light,
        .light => color_theme.theme = .dark,
    }
}

pub const Direction = enum(u8) {
    column = 0,
    row = 1,
};

pub const SizingType = enum(u8) {
    fit = 0,
    grow = 1,
    percent = 2,
    fixed = 3,
    elastic = 4,
    elastic_percent = 5,
    none = 6,
};

// const MinMax = struct {
//     min: f32 = 0,
//     max: f32 = 0,
// };
//
// pub const SizingConstraint = union {
//     minmax: MinMax,
//     percent: MinMax,
// };
//

const MinMax = struct {
    min: f32 = 0,
    max: f32 = 0,

    pub fn eql(self: MinMax, other: MinMax) bool {
        return self.min == other.min and self.max == other.max;
    }
};

// Make it a tagged union by adding an enum
pub const SizingConstraint = union(enum) {
    minmax: MinMax,
    percent: MinMax,

    pub fn eql(self: SizingConstraint, other: SizingConstraint) bool {
        if (std.meta.activeTag(self) != std.meta.activeTag(other)) return false;

        return switch (self) {
            .minmax => |mm| mm.eql(other.minmax),
            .percent => |mm| mm.eql(other.percent),
        };
    }
};

pub const Sizing = struct {
    size: SizingConstraint = .{ .minmax = .{} },
    type: SizingType = .none,

    pub const grow = Sizing{ .type = .grow, .size = .{ .minmax = .{ .min = 0, .max = 0 } } };
    pub const fit = Sizing{ .type = .fit, .size = .{ .minmax = .{ .min = 0, .max = 0 } } };

    pub fn fixed(size: f32) Sizing {
        return .{ .type = .fixed, .size = .{ .minmax = .{
            .min = size,
            .max = size,
        } } };
    }

    pub fn elastic(min: f32, max: f32) Sizing {
        return .{ .type = .elastic, .size = .{ .minmax = .{
            .min = min,
            .max = max,
        } } };
    }

    pub fn percent(size: f32) Sizing {
        return .{ .type = .percent, .size = .{ .minmax = .{
            .min = size,
            .max = size,
        } } };
    }

    pub fn elastic_percent(min: f32, max: f32) Sizing {
        return .{ .type = .elastic_percent, .size = .{ .percent = .{
            .min = min,
            .max = max,
        } } };
    }

    // Add custom equality function for Sizing
    pub fn eql(self: Sizing, other: Sizing) bool {
        return self.type == other.type and self.size.eql(other.size);
    }
};

// pub const Sizing = struct {
//     size: SizingConstraint = .{ .minmax = .{} },
//     type: SizingType = .none,
//
//     pub const grow = Sizing{ .type = .grow, .size = .{ .minmax = .{ .min = 0, .max = 0 } } };
//     pub const fit = Sizing{ .type = .fit, .size = .{ .minmax = .{ .min = 0, .max = 0 } } };
//
//     pub fn fixed(size: f32) Sizing {
//         return .{ .type = .fixed, .size = .{ .minmax = .{
//             .min = size,
//             .max = size,
//         } } };
//     }
//
//     pub fn elastic(min: f32, max: f32) Sizing {
//         return .{ .type = .elastic, .size = .{ .minmax = .{
//             .min = min,
//             .max = max,
//         } } };
//     }
//
//     pub fn percent(size: f32) Sizing {
//         return .{ .type = .percent, .size = .{ .minmax = .{
//             .min = size,
//             .max = size,
//         } } };
//     }
//     pub fn elastic_percent(min: f32, max: f32) Sizing {
//         return .{ .type = .elastic_percent, .size = .{ .percent = .{
//             .min = min,
//             .max = max,
//         } } };
//     }
// };

pub const PosType = enum(u8) {
    fit = 0,
    grow = 1,
    percent = 2,
    fixed = 3,
};

pub const Pos = struct {
    type: PosType = .fit,
    value: f32 = 0,

    pub const grow = Pos{ .type = .grow, .value = 0 };
    pub fn fixed(pos: f32) Pos {
        return .{ .type = .fixed, .value = pos };
    }

    pub fn percent(pos: f32) Pos {
        return .{ .type = .percent, .value = pos };
    }
};

pub const Dimensions = struct {
    width: Sizing = .{},
    height: Sizing = .{},
    pub const grow = Dimensions{ .height = .grow, .width = .grow };
    pub const fid = Dimensions{ .height = .fit, .width = .fit };
};

pub const Background = struct {
    r: u8 = 0,
    g: u8 = 0,
    b: u8 = 0,
    a: u8 = 0,
    pub fn hex(hex_str: []const u8) Background {
        const rgba_arr = Fabric.hexToRgba(hex_str);
        return Background{
            .r = rgba_arr[0],
            .g = rgba_arr[1],
            .b = rgba_arr[2],
            .a = rgba_arr[3],
        };
    }
    pub fn rgba(r: u8, g: u8, b: u8, a: u8) Background {
        return Background{
            .r = r,
            .g = g,
            .b = b,
            .a = a,
        };
    }
    pub fn rgb(r: u8, g: u8, b: u8) Background {
        return Background{
            .r = r,
            .g = g,
            .b = b,
            .a = 255,
        };
    }
    pub fn transparentizeHex(hex_str: []const u8, alpha: u8) Background {
        const rgba_arr = Fabric.transparentize(hex_str, alpha);
        return Background{
            .r = rgba_arr[0],
            .g = rgba_arr[1],
            .b = rgba_arr[2],
            .a = rgba_arr[3],
        };
    }
};

pub const Padding = struct {
    top: u32 = 0,
    bottom: u32 = 0,
    left: u32 = 0,
    right: u32 = 0,
    pub fn all(size: u32) Padding {
        return Padding{
            .top = size,
            .bottom = size,
            .left = size,
            .right = size,
        };
    }
    pub fn horizontal(size: u32) Padding {
        return Padding{
            .top = 0,
            .bottom = 0,
            .left = size,
            .right = size,
        };
    }
    pub fn vertical(size: u32) Padding {
        return Padding{
            .top = size,
            .bottom = size,
            .left = 0,
            .right = 0,
        };
    }
};

pub const Margin = struct {
    top: u32 = 0,
    bottom: u32 = 0,
    left: u32 = 0,
    right: u32 = 0,
    pub fn all(size: u32) Margin {
        return Margin{
            .top = size,
            .bottom = size,
            .left = size,
            .right = size,
        };
    }
};

pub const Overflow = enum(u8) {
    scroll = 0,
    hidden = 1,
};

pub const BorderRadius = struct {
    top_left: f32 = 0,
    top_right: f32 = 0,
    bottom_left: f32 = 0,
    bottom_right: f32 = 0,
    fn default() BorderRadius {
        return BorderRadius{
            .top_left = 0,
            .top_right = 0,
            .bottom_left = 0,
            .bottom_right = 0,
        };
    }
    pub fn all(radius: f32) BorderRadius {
        return BorderRadius{
            .top_left = radius,
            .top_right = radius,
            .bottom_left = radius,
            .bottom_right = radius,
        };
    }
    pub fn specific(top_left: f32, top_right: f32, bottom_left: f32, bottom_right: f32) BorderRadius {
        return BorderRadius{
            .top_left = top_left,
            .top_right = top_right,
            .bottom_left = bottom_left,
            .bottom_right = bottom_right,
        };
    }
};

pub const Shadow = struct {
    top: f32 = 0,
    left: f32 = 0,
    blur: f32 = 0,
    spread: f32 = 0,
    color: Background = .{},
};

// pub const Transform = struct {
//     x: f32,
//     y: f32,
//     width: f32,
//     height: f32,
//     pub fn scale(x: f32, y: f32, width: f32, height: f32) Transform {
//     }
//     pub fn scale_all(value: f32) Transform {
//     }
// };

pub const Border = struct {
    top: f32 = 0,
    bottom: f32 = 0,
    left: f32 = 0,
    right: f32 = 0,
    pub fn default() Border {
        return Border{
            .top = 0,
            .bottom = 0,
            .left = 0,
            .right = 0,
        };
    }
    pub fn all(thickness: f32) Border {
        return Border{
            .top = thickness,
            .bottom = thickness,
            .left = thickness,
            .right = thickness,
        };
    }
    pub fn specific(left: f32, top: f32, right: f32, bottom: f32) Border {
        return Border{
            .top = top,
            .bottom = bottom,
            .left = left,
            .right = right,
        };
    }
};

pub const Alignment = enum(u8) {
    center = 0,
    top = 1,
    bottom = 2,
    start = 3,
    end = 4,
    between = 5,
    even = 6,
};

pub const BoundingBox = struct {
    /// X coordinate of the top-left corner
    x: f32,
    /// Y coordinate of the top-left corner
    y: f32,
    /// Width of the bounding box
    width: f32,
    /// Height of the bounding box
    height: f32,
};

pub const FloatType = enum(u8) {
    right,
    left,
    top,
    bottom,
};

pub const PositionType = enum(u8) {
    relative = 0,
    absolute = 1,
    fixed = 2,
    sticky = 3,
};

pub const Position = struct {
    x: f32 = 0,
    y: f32 = 0,
    right: Pos = Pos{},
    left: Pos = Pos{},
    top: Pos = Pos{},
    bottom: Pos = Pos{},
    type: PositionType = .relative,
};

pub const TransformType = enum {
    none,
    translateX,
    translateY,
    scale,
    scaleY,
    scaleX,
};

pub const Transform = struct {
    scale_size: f32 = 1,
    dist: f32 = 0,
    percent: f32 = 0,
    type: TransformType = .none,
    opacity: ?u32 = null,
    // pub fn scale(size: f32) Transform {
    //     return .{
    //         .scale_size = size,
    //         .type = .scale,
    //     };
    // }
    // pub fn translateX(dist: f32) Transform {
    //     return .{
    //         .type = .translateX,
    //         .dist = dist,
    //     };
    // }
    // pub fn translateY(dist: f32) Transform {
    //     return .{
    //         .type = .translateY,
    //         .dist = dist,
    //     };
    // }
};

pub const Hover = struct {
    position: ?Position = null,
    display: ?FlexType = null,
    direction: ?Direction = null,
    width: ?Sizing = null,
    height: ?Sizing = null,
    font_size: ?i32 = null,
    letter_spacing: ?i32 = null,
    line_height: ?i32 = null,
    font_weight: ?usize = null,
    border_radius: ?BorderRadius = null,
    border_thickness: ?Border = null,
    border_color: ?Background = null,
    text_color: ?Background = null,
    padding: ?Padding = null,
    child_alignment: ?struct { x: Alignment, y: Alignment } = null,
    child_gap: u16 = 0,
    background: ?Background = null,
    shadow: Shadow = .{},
    transform: Transform = .{},
    opacity: f32 = 1,
    child_style: ?ChildStyle = null,
};

pub const CheckMark = struct {
    position: ?Position = null,
    display: ?FlexType = null,
    direction: ?Direction = null,
    width: ?Sizing = null,
    height: ?Sizing = null,
    font_size: ?i32 = null,
    letter_spacing: ?i32 = null,
    line_height: ?i32 = null,
    font_weight: ?usize = null,
    border_radius: ?BorderRadius = null,
    border_thickness: ?Border = null,
    border_color: ?Background = .{},
    text_color: ?Background = null,
    padding: ?Padding = null,
    child_alignment: ?struct { x: Alignment, y: Alignment } = null,
    child_gap: u16 = 0,
    background: ?Background = null,
    shadow: Shadow = .{},
    transform: Transform = .{},
    opacity: f32 = 1,
    child_style: ?ChildStyle = null,
};

pub const Color: [4]u8 = .{ 255, 255, 255, 255 };
pub const TextColor: [4]u8 = .{ 0, 0, 0, 255 };

pub const Dim = struct {
    type: SizingType = .fit,
    pub const grow = Sizing{ .type = .grow, .size = .{ .minmax = .{ .min = 0, .max = 0 } } };
    pub const fit = Sizing{ .type = .fit, .size = .{ .minmax = .{ .min = 0, .max = 0 } } };
    pub fn fixed(size: f32) Sizing {
        return .{ .type = .fixed, .size = .{ .minmax = .{
            .min = size,
            .max = size,
        } } };
    }
    pub fn elastic(min: f32, max: f32) Sizing {
        return .{ .type = .elastic, .size = .{ .minmax = .{
            .min = min,
            .max = max,
        } } };
    }
};

pub const TextDecoration = enum(u8) {
    none = 0,
    overline = 1,
    underline = 2,
    inherit = 3,
    initial = 4,
    revert = 5,
    unset = 6,
};

pub const WhiteSpace = enum(u8) {
    normal = 0, // Collapses whitespace and breaks on necessary
    nowrap = 1, // Collapses whitespace but prevents breaking
    pre = 2, // Preserves whitespace and breaks on newlines
    pre_wrap = 3, // Preserves whitespace and breaks as needed
    pre_line = 4, // Collapses whitespace but preserves line breaks
    break_spaces = 5, // Like pre-wrap but also breaks at spaces
    inherit = 6, // Inherits from parent
    initial = 7, // Default value
    revert = 8, // Reverts to inherited value
    unset = 9, // Resets to inherited value or initial
};

// Enum definition for CSS list-style-type property
pub const ListStyle = enum(u8) {
    none = 0, // No bullet or marker
    disc = 1, // Filled circle (default for unordered lists)
    circle = 2, // Open circle
    square = 3, // Square marker
    decimal = 4, // Decimal numbers (default for ordered lists)
    decimal_leading_zero = 5, // Decimal numbers with a leading zero (e.g. 01, 02, 03, ...)
    lower_roman = 6, // Lowercase roman numerals (i, ii, iii, ...)
    upper_roman = 7, // Uppercase roman numerals (I, II, III, ...)
    lower_alpha = 8, // Lowercase alphabetic (a, b, c, ...)
    upper_alpha = 9, // Uppercase alphabetic (A, B, C, ...)
    lower_greek = 10, // Lowercase Greek letters (α, β, γ, ...)
    armenian = 11, // Armenian numbering
    georgian = 12, // Georgian numbering
    inherit = 13, // Inherits from parent element
    initial = 14, // Resets to the default value
    revert = 15, // Reverts to the inherited value if explicitly changed
    unset = 16, // Resets to inherited or initial value
};

pub const Outline = enum(u8) {
    none = 0, // No outline
    auto = 1, // Default outline (typically browser-specific)
    dotted = 2, // Dotted outline
    dashed = 3, // Dashed outline
    solid = 4, // Solid outline
    double = 5, // Two parallel solid lines
    groove = 6, // 3D grooved effect
    ridge = 7, // 3D ridged effect
    inset = 8, // 3D inset effect
    outset = 9, // 3D outset effect
    inherit = 10, // Inherits from the parent element
    initial = 11, // Resets to the default value
    revert = 12, // Reverts to the inherited value if explicitly changed
    unset = 13, // Resets to inherited or initial value
};

pub const FlexType = enum(u8) {
    flex = 0, // "flex"
    inline_flex = 1, // "inline-flex"
    inherit = 2, // "inherit"
    initial = 3, // "initial"
    revert = 4, // "revert"
    unset = 5, // "unset"
    none = 6,
    inline_block = 7, // "inline-block"
};

// Enum definition for flex-wrap property
pub const FlexWrap = enum(u8) {
    nowrap = 0, // Single-line, no wrapping
    wrap = 1, // Multi-line, wrapping if needed
    wrap_reverse = 2, // Multi-line, reverse wrapping direction
    inherit = 3, // Inherits from parent
    initial = 4, // Default value
    revert = 5, // Reverts to inherited value
    unset = 6, // Resets to inherited value or initial
};

pub const KeyFrame = struct {
    tag: []const u8,
    from: Transform = .{},
    to: Transform = .{},
};
const AnimDir = enum {
    normal,
    reverse,
    forwards,
};
const TimingFunction = enum {
    ease_in,
    ease,
    linear,
    ease_out,
    ease_in_out,
};

const Iteration = struct {
    iter_count: u32 = 1,
    pub fn infinite() Iteration {
        return .{
            .iter_count = 0,
        };
    }
    pub fn count(c: u32) Iteration {
        return .{
            .iter_count = c,
        };
    }
};

pub const AnimationType = struct {
    tag: []const u8,
    delay: f32 = 0,
    direction: AnimDir = .normal,
    duration: f32 = 0,
    iteration_count: Iteration = .count(1),
    timing_function: TimingFunction = .ease,
};

pub const ChildStyle = struct {
    style_id: []const u8,
    display: ?FlexType = null,
    position: ?Position = null,
    direction: Direction = .row,
    background: ?Background = null,
    width: ?Sizing = null,
    height: ?Sizing = null,
    font_size: ?i32 = null,
    letter_spacing: ?i32 = null,
    line_height: ?i32 = null,
    font_weight: ?usize = null,
    border_radius: ?BorderRadius = null,
    border_thickness: ?Border = null,
    border_color: ?Background = .{},
    text_color: ?Background = null,
    padding: ?Padding = null,
    margin: ?Margin = null,
    overflow: ?Overflow = null,
    overflow_x: ?Overflow = null,
    overflow_y: ?Overflow = null,
    child_alignment: ?struct { x: Alignment, y: Alignment } = null,
    child_gap: u32 = 0,
    flex_shrink: ?u32 = null,
    font_family_file: []const u8 = "",
    font_family: []const u8 = "",
    opacity: f32 = 1,
    text_decoration: ?TextDecoration = null,
    shadow: Shadow = .{},
    white_space: ?WhiteSpace = null,
    flex_wrap: ?FlexWrap = null,
    key_frame: ?KeyFrame = null,
    key_frames: ?[]const KeyFrame = null,
    animation: ?Animation.Specs = null,
    z_index: ?f32 = null,
    list_style: ?ListStyle = null,
    blur: ?u32 = null,
    outline: ?Outline = null,
    transition: ?Transition = null,
    show_scrollbar: bool = true,
    // active: ?Active = null,
    btn_id: u32 = 0,
    dialog_id: ?[]const u8 = null,
    accent_color: ?[4]u8 = null,
    // x: u32 = 0,
    // focused: Focused = .{},
    // pressed: Pressed = .{},
};

pub const Cursor = enum {
    pointer,
    help,
    grab,
    zoom_in,
    zoom_out,
};

pub const Appearance = enum(u8) {
    none = 0, // Remove default styling completely
    auto = 1, // Default browser styling
    button = 2, // Style as a button
    textfield = 3, // Style as a text input field
    menulist = 4, // Style as a dropdown menu
    searchfield = 5, // Style as a search input
    textarea = 6, // Style as a multiline text area
    checkbox = 7, // Style as a checkbox
    radio = 8, // Style as a radio button
    inherit = 9, // Inherit from parent
    initial = 10, // Default value
    revert = 11, // Revert to inherited value
    unset = 12, // Reset to inherited value or initial
};

pub const BoxSizing = enum(u8) {
    content_box = 0, // Default CSS box model
    border_box = 1, // Alternative CSS box model (padding and border included in width/height)
    padding_box = 2, // Experimental value (width/height includes content and padding)
    inherit = 3, // Inherits from parent
    initial = 4, // Default value
    revert = 5, // Reverts to inherited value
    unset = 6, // Resets to inherited value or initial
};

pub const TransformOrigin = enum(u8) {
    top = 0,
    bottom = 1,
    right = 2,
    left = 3,
};

/// Global user-defined default style that overrides system defaults
var user_defaults: ?Style = null;

/// Comprehensive styling struct that provides CSS-like properties for UI components.
/// Supports layout, visual styling, typography, animations, and interactions.
/// Uses a three-tier inheritance system: system defaults -> user defaults -> component styles.
///
/// # Usage Example:
/// ```zig
/// const button_style = Style.with(.{
///     .background = .{ 70, 130, 180, 255 }, // Steel blue
///     .border_radius = .all(8),
///     .padding = .all(12),
///     .font_weight = 600,
/// });
/// ```
pub const Style = struct {
    /// Unique identifier for the styled element
    id: ?[]const u8 = null,

    /// CSS class-like identifier for grouping styles
    style_id: ?[]const u8 = null,

    /// Display type (block, flex, inline, etc.)
    display: ?FlexType = null,

    /// Positioning method (static, relative, absolute, fixed)
    position: ?Position = null,

    /// Flex direction for child elements (row, column, row-reverse, column-reverse)
    direction: Direction = .row,

    /// Background color as RGBA array [red, green, blue, alpha] (0-255 each)
    /// Default: transparent black
    background: ?Background = .{},

    /// Width sizing configuration (fixed, percentage, auto, etc.)
    width: Sizing = .{},

    /// Height sizing configuration (fixed, percentage, auto, etc.)
    height: Sizing = .{},

    /// Font size in pixels
    font_size: ?i32 = null,

    /// Letter spacing in pixels (can be negative for tighter spacing)
    letter_spacing: ?i32 = null,

    /// Line height in pixels for text content
    line_height: ?i32 = null,

    /// Font weight (100-900, where 400 is normal, 700 is bold)
    font_weight: ?usize = null,

    /// Border radius configuration for rounded corners
    border_radius: ?BorderRadius = null,

    /// Border thickness specification
    border_thickness: ?Border = .default(),

    /// Border color as RGBA array [red, green, blue, alpha]
    border_color: ?Background = .{},

    /// Text color as RGBA array [red, green, blue, alpha]
    /// Default: solid black
    text_color: ?Background = .{ .a = 255 },

    /// Internal spacing configuration
    padding: Padding = .{},

    /// External spacing configuration
    margin: Margin = .{},

    /// Content overflow behavior (visible, hidden, scroll, auto)
    overflow: ?Overflow = null,

    /// Horizontal overflow behavior
    overflow_x: ?Overflow = null,

    /// Vertical overflow behavior
    overflow_y: ?Overflow = null,

    /// Alignment configuration for child elements
    /// x: horizontal alignment, y: vertical alignment
    child_alignment: struct { x: Alignment, y: Alignment } = .{
        .x = .center,
        .y = .center,
    },

    /// Gap between child elements in pixels
    child_gap: u32 = 0,

    /// Font family name (e.g., "Arial", "Helvetica", "Montserrat")
    font_family: []const u8 = "",

    /// Element opacity (0.0 = fully transparent, 1.0 = fully opaque)
    opacity: f32 = 1,

    /// Text decoration (underline, strikethrough, etc.)
    text_decoration: ?TextDecoration = null,

    /// Shadow configuration for drop shadows
    shadow: Shadow = .{},

    /// White space handling (normal, nowrap, pre, pre-wrap)
    white_space: ?WhiteSpace = null,

    /// Flex wrap behavior (nowrap, wrap, wrap-reverse)
    flex_wrap: ?FlexWrap = null,

    /// Single keyframe for simple animations
    key_frame: ?KeyFrame = null,

    /// Array of keyframes for complex animations
    key_frames: ?[]const KeyFrame = null,

    /// Animation specifications (duration, timing, etc.)
    animation: ?Animation.Specs = null,

    /// Animation name for exit/removal animations
    exit_animation: ?[]const u8 = null,

    /// Z-index for layering control (higher values appear on top)
    z_index: ?f32 = null,

    /// List styling for ul/ol elements
    list_style: ?ListStyle = null,

    /// Blur effect intensity in pixels
    blur: ?u32 = null,

    /// Outline configuration (different from border)
    outline: ?Outline = null,

    /// Transition specifications for smooth property changes
    transition: ?Transition = null,

    /// Whether to show scrollbars when content overflows
    show_scrollbar: bool = true,

    /// Cursor type when hovering over element
    cursor: ?Cursor = null,

    /// Hover state styling
    hover: ?Hover = null,

    /// Button identifier for click handling
    btn_id: u32 = 0,

    /// Dialog identifier for modal/popup elements
    dialog_id: ?[]const u8 = null,

    /// Array of child-specific style overrides
    child_styles: ?[]const ChildStyle = null,

    /// Element appearance override
    appearance: ?Appearance = null,

    /// Custom checkmark styling for checkboxes
    checkmark_style: ?CheckMark = null,

    /// Hint to browser about which properties will change (optimization)
    will_change: ?TransitionProperty = null,

    /// 2D/3D transformation configuration
    transform: ?Transform = null,

    /// Origin point for transformations
    transform_origin: ?TransformOrigin = null,

    /// Backface visibility for 3D transforms
    backface_visibility: ?[]const u8 = null,

    /// System default style configuration with sensible defaults.
    /// Used as the base when no user defaults are set.
    pub const default: Style = Style{};

    /// Pre-configured opaque style with common visual properties.
    /// Useful as a starting point for solid, bordered elements.
    ///
    /// # Properties:
    /// - Font: Montserrat
    /// - Border radius: 4px on all corners
    /// - Border: 1px solid light gray (#DFDFDF)
    pub const Opaque: Style = .{
        .font_family = "Montserrat",
        .border_radius = .all(4),
        .border_color = .hex("#DFDFDF"),
        .border_thickness = .default(),
    };

    pub const Container: Style = .{
        .display = .flex,
        .direction = .row,
        .child_gap = 12,
        .child_alignment = .{ .x = .start, .y = .center },
        .flex_wrap = .wrap,
        .width = .percent(100),
    };

    pub const Button: Style = .{
        .padding = .{ .top = 8, .bottom = 8, .left = 12, .right = 12 },
        .border_radius = .all(6),
        .display = .inline_flex,
        .child_alignment = .{ .x = .center, .y = .center },
        .cursor = .pointer,
        .font_weight = 600,
    };

    pub const Card: Style = .{
        .background = .{ 255, 255, 255, 255 }, // White
        .padding = .all(16),
        .border_radius = .all(8),
        .shadow = .{ .blur = 8, .top = 2, .color = .{ 0, 0, 0, 25 } },
        .display = .block,
    };

    /// Gets the current base style to use for inheritance.
    /// Returns user-defined defaults if set, otherwise returns system defaults.
    ///
    /// # Returns:
    /// Style - The base style configuration
    ///
    /// # Usage:
    /// ```zig
    /// const base = Style.getDefault();
    /// const custom = Style{ .font_size = 16 }.merge(base);
    /// ```
    pub fn getDefault() Style {
        return user_defaults orelse Style.default;
    }

    /// Merges this style with a base style, creating a new style where
    /// non-default properties from this style override the base style.
    /// Only properties that differ from system defaults are applied.
    ///
    /// # Parameters:
    /// - `self`: Style - The style with override properties
    /// - `base`: Style - The base style to merge with
    ///
    /// # Returns:
    /// Style - New style with merged properties
    ///
    /// # Usage:
    /// ```zig
    /// const base_style = Style{ .font_size = 14, .padding = .all(8) };
    /// const override_style = Style{ .font_size = 18 }; // Only override font size
    /// const merged = override_style.merge(base_style);
    /// // Result: font_size = 18, padding = .all(8)
    /// ```
    pub fn merge(self: Style, base: Style) Style {
        var result = base;
        inline for (@typeInfo(Style).@"struct".fields) |field| {
            const field_value = @field(self, field.name);
            const default_value = @field(default, field.name);

            // Only override if the field is not the default value
            if (!std.meta.eql(field_value, default_value)) {
                @field(result, field.name) = field_value;
            }
        }
        return result;
    }

    /// Creates a new style by merging the provided overrides with the current default style.
    /// This is the primary way to create styled components with inheritance.
    ///
    /// # Parameters:
    /// - `overrides`: Style - Style properties to override defaults
    ///
    /// # Returns:
    /// Style - New style with default properties and specified overrides
    ///
    /// # Usage:
    /// ```zig
    /// // Create a button style with custom background and padding
    /// const button_style = Style.apply(.{
    ///     .background = .{ 70, 130, 180, 255 }, // Steel blue
    ///     .padding = .all(12),
    ///     .border_radius = .all(6),
    ///     .text_color = .{ 255, 255, 255, 255 }, // White text
    /// });
    ///
    /// // Create a card style with shadow and border
    /// const card_style = Style.apply(.{
    ///     .background = .{ 255, 255, 255, 255 }, // White background
    ///     .shadow = .{ .blur = 10, .color = .{ 0, 0, 0, 50 } },
    ///     .border_radius = .all(8),
    ///     .padding = .all(16),
    /// });
    /// ```
    pub fn apply(overrides: Style) Style {
        return overrides.merge(Style.getDefault());
    }

    /// Sets the global user defaults that will be used as the base for all future styles.
    /// This allows you to establish consistent theming across your application.
    ///
    /// # Parameters:
    /// - `new_default`: Style - The new default style configuration
    ///
    /// # Returns:
    /// void
    ///
    /// # Usage:
    /// ```zig
    /// // Set up application-wide defaults
    /// Style.setDefault(.{
    ///     .font_family = "Inter",
    ///     .font_size = 14,
    ///     .text_color = .{ 33, 37, 41, 255 }, // Dark gray
    ///     .background = .{ 248, 249, 250, 255 }, // Light gray
    /// });
    ///
    /// // All subsequent Style.apply() calls will inherit these defaults
    /// const button = Style.apply(.{ .padding = .all(8) });
    /// // button now has Inter font, 14px size, dark gray text, etc.
    /// ```
    pub fn setDefault(new_default: Style) void {
        user_defaults = new_default;
    }
};
pub const Config = struct {
    style: Style,
};

pub const HooksIds = struct {
    created_id: u32 = 0,
    mounted_id: u32 = 0,
    updated_id: u32 = 0,
    destroy_id: u32 = 0,
};

const InputType = enum(u8) {
    text = 0,
    number = 1,
    password = 2,
    radio = 3,
    checkbox = 4,
    email = 5,
    search = 6,
    telephone = 7,
};
const Callback = *const fn (*Fabric.Event) void;
pub const InputParamsStr = struct {
    default: ?[]const u8 = null,
    tag: ?[]const u8 = null,
    value: ?[]const u8 = null,
    min_len: ?u32 = null,
    max_len: ?u32 = null,
    required: ?bool = null,
    src: ?[]const u8 = null,
    alt: ?[]const u8 = null,
    disabled: ?bool = null,
    include_capital: ?u32 = null,
    onInput: ?Callback = null,
};

pub const InputParamsEmail = struct {
    default: ?[]const u8 = null,
    tag: ?[]const u8 = null,
    value: ?[]const u8 = null,
    min_len: ?u32 = null,
    max_len: ?u32 = null,
    required: ?bool = null,
    src: ?[]const u8 = null,
    alt: ?[]const u8 = null,
    disabled: ?bool = null,
    include_pattern: ?bool = null,
};

pub const InputParamsPassword = struct {
    default: ?[]const u8 = null,
    tag: ?[]const u8 = null,
    value: ?[]const u8 = null,
    min_len: ?u32 = null,
    max_len: ?u32 = null,
    required: ?bool = null,
    src: ?[]const u8 = null,
    alt: ?[]const u8 = null,
    disabled: ?bool = null,
    include_digit: ?u32 = null,
    include_capital: ?u32 = null,
    include_symbol: ?u32 = null,
};

const InputParamsFloat = struct {
    default: ?f32 = null,
    tag: ?[]const u8 = null,
    value: ?f32 = null,
    min_len: ?u32 = null,
    max_len: ?u32 = null,
    required: ?bool = null,
    src: ?[]const u8 = null,
    alt: ?[]const u8 = null,
    disabled: ?bool = null,
};
const InputParamsInt = struct {
    default: ?i32 = null,
    tag: ?[]const u8 = null,
    value: ?i32 = null,
    min_len: ?u32 = null,
    max_len: ?u32 = null,
    required: ?bool = null,
    src: ?[]const u8 = null,
    alt: ?[]const u8 = null,
    disabled: ?bool = null,
};

const InputParamsRadio = struct {
    tag: []const u8,
    value: []const u8,
    required: ?bool = null,
    checked: ?bool = null,
    src: ?[]const u8 = null,
    alt: ?[]const u8 = null,
    disabled: ?bool = null,
};

const InputParamsCheckBox = struct {
    tag: ?[]const u8 = null,
    checked: bool = false,
    required: ?bool = null,
    alt: ?[]const u8 = null,
    disabled: ?bool = null,
    checkmark: ?Style = null,
};

const InputParamsFile = struct {
    tag: ?[]const u8 = null,
    required: ?bool = null,
    disabled: ?bool = null,
};

pub const InputParams = union(enum) {
    int: InputParamsInt,
    float: InputParamsFloat,
    string: InputParamsStr,
    checkbox: InputParamsCheckBox,
    radio: InputParamsRadio,
    password: InputParamsPassword,
    email: InputParamsEmail,
    file: InputParamsFile,
};

pub const StateType = enum {
    pure,
    static,
    dynamic,
    animation,
};

pub const ButtonType = enum {
    submit,
    button,
};

pub const ElementDeclaration = struct {
    hooks: HooksIds = .{},
    style: Style = .{},
    elem_type: ElementType = .FlexBox,
    text: []const u8 = "",
    svg: []const u8 = "",
    href: []const u8 = "",
    show: bool = true,
    input_params: ?InputParams = null,
    event_type: ?EventType = null,
    dynamic: StateType = .pure,
};
pub const Element = fn (Style) fn (void) void;

pub const ElementType = enum {
    Rectangle,
    Text,
    Image,
    FlexBox,
    Input,
    Button,
    Block,
    Box,
    Header,
    Svg,
    Link,
    EmbedLink,
    List,
    ListItem,
    _If,
    Hooks,
    Layout,
    Page,
    Bind,
    Dialog,
    DialogBtnShow,
    DialogBtnClose,
    Draggable,
    RedirectLink,
    Select,
    SelectItem,
    CtxButton,
    EmbedIcon,
    Icon,
    Label,
    Form,
    AllocText,
    Table,
    TableRow,
    TableCell,
    TableHeader,
    TableBody,
    TextArea,
    Canvas,
    SubmitCtxButton,
    HooksCtx,
    JsonEditor,
};

pub const RenderCommand = struct {
    /// Rectangular box that fully encloses this UI element
    bounding_box: BoundingBox,
    elem_type: ElementType,
    text: []const u8 = "",
    href: []const u8 = "",
    style: Style = undefined,
    id: []const u8 = "",
    show: bool = true,
    hooks: HooksIds,
    node_ptr: *UINode,
    hover: bool = false,
};

pub const EventType = enum(u8) {
    // Mouse events
    none = 0,
    click, // Fired when a pointing device button is clicked.
    dblclick, // Fired when a pointing device button is double-clicked.
    mousedown, // Fired when a pointing device button is pressed.
    mouseup, // Fired when a pointing device button is released.
    mousemove, // Fired when a pointing device is moved.
    mouseover, // Fired when a pointing device is moved onto an element.
    mouseout, // Fired when a pointing device is moved off an element.
    mouseenter, // Similar to mouseover but does not bubble.
    mouseleave, // Similar to mouseout but does not bubble.
    contextmenu, // Fired when the right mouse button is clicked.

    // Keyboard events
    keydown, // Fired when a key is pressed.
    keyup, // Fired when a key is released.
    keypress, // Fired when a key that produces a character value is pressed.

    // Focus events
    focus, // Fired when an element gains focus.
    blur, // Fired when an element loses focus.
    focusin, // Fired when an element is about to receive focus.
    focusout, // Fired when an element is about to lose focus.

    // Form events
    change, // Fired when the value of an element changes.
    input, // Fired every time the value of an element changes.
    submit, // Fired when a form is submitted.
    reset, // Fired when a form is reset.

    // Window events
    resize, // Fired when the window is resized.
    scroll, // Fired when the document view is scrolled.
    wheel, // Fired when the mouse wheel is rotated.

    // Drag & Drop events
    drag, // Fired continuously while an element or text selection is being dragged.
    dragstart, // Fired at the start of a drag operation.
    dragend, // Fired at the end of a drag operation.
    dragover, // Fired when an element is being dragged over a valid drop target.
    dragenter, // Fired when a dragged element enters a valid drop target.
    dragleave, // Fired when a dragged element leaves a valid drop target.
    drop, // Fired when a dragged element is dropped on a valid drop target.

    // Clipboard events
    copy, // Fired when the user initiates a copy action.
    cut, // Fired when the user initiates a cut action.
    paste, // Fired when the user initiates a paste action.

    // Touch events
    touchstart, // Fired when one or more touch points are placed on the touch surface.
    touchmove, // Fired when one or more touch points are moved along the touch surface.
    touchend, // Fired when one or more touch points are removed from the touch surface.
    touchcancel, // Fired when a touch point is disrupted (e.g., by a modal interruption).

    // Pointer events (unify mouse, touch, and pen input)
    pointerover, // Fired when a pointer enters the hit test boundaries of an element.
    pointerenter, // Similar to pointerover but does not bubble.
    pointerdown, // Fired when a pointer becomes active.
    pointermove, // Fired when a pointer changes coordinates.
    pointerup, // Fired when a pointer is no longer active.
    pointercancel, // Fired when a pointer is canceled.
    pointerout, // Fired when a pointer moves out of an element.
    pointerleave, // Similar to pointerout but does not bubble.

    // Document / Media / Error events
    load, // Fired when a resource and its dependent resources have finished loading.
    unload, // Fired when the document is being unloaded.
    abort, // Fired when the loading of a resource is aborted.
    show,
    close,
    cancel,
};
