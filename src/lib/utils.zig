const std = @import("std");
const UINode = @import("UITree.zig").UINode;
const Vapor = @import("Vapor.zig");
const Color = @import("types.zig").Color;
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

pub fn isDesktop() bool {
    return !isMobile();
}

pub fn isMobile() bool {
    if (!Vapor.isWasi) return false;
    if (Vapor.browser_width < 786) {
        return true;
    } else {
        return false;
    }
}

pub fn hashKey(key: []const u8) u32 {
    return std.hash.XxHash32.hash(0, key);
}

pub fn hash(value: []const u8) u32 {
    return std.hash.XxHash32.hash(0, value);
}

const base62_chars = "0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz";

pub fn hashToBufferBase62(hash_value: u32, out: []u8) usize {
    var h = hash_value;
    var i: usize = 0;
    if (h == 0) {
        out[0] = '0';
        return 1;
    }
    while (h > 0 and i < 6) : (i += 1) {
        out[i] = "0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz"[h % 62];
        h /= 62;
    }
    return i;
}

pub fn hashToBase62(hash_value: u32, buf: *[6]u8) []const u8 {
    var h = hash_value;
    var i: usize = 0;
    while (h > 0 and i < 6) : (i += 1) {
        buf[i] = base62_chars[@intCast(h % 62)];
        h /= 62;
    }
    return buf[0..@max(i, 1)];
}

pub fn compareStyles(a: *const Vapor.Style, b: *const Vapor.Style) bool {
    if (a.blur != null and b.blur != null) {
        if (a.blur.? != b.blur.?) return false;
    }

    if (a.cursor != null and b.cursor != null) {
        if (a.cursor.? != b.cursor.?) return false;
    }

    if (a.list_style != null and b.list_style != null) {
        if (a.list_style.? != b.list_style.?) return false;
    }

    if (a.position != null and b.position != null) {
        if (a.position.?.type != b.position.?.type) return false;
        if (a.position.?.top != null and b.position.?.top != null) {
            if (a.position.?.top.?.value != b.position.?.top.?.value) return false;
        }
        if (a.position.?.bottom != null and b.position.?.bottom != null) {
            if (a.position.?.bottom.?.value != b.position.?.bottom.?.value) return false;
        }
        if (a.position.?.left != null and b.position.?.left != null) {
            if (a.position.?.left.?.value != b.position.?.left.?.value) return false;
        }
        if (a.position.?.right != null and b.position.?.right != null) {
            if (a.position.?.right.?.value != b.position.?.right.?.value) return false;
        }
    }

    if (a.direction != b.direction) return false;

    if (a.size) |a_size| {
        if (b.size) |b_size| {
            if (a_size.width.size.minmax.min != b_size.width.size.minmax.min) return false;
            if (a_size.width.size.minmax.max != b_size.width.size.minmax.max) return false;
            if (a_size.height.size.minmax.min != b_size.height.size.minmax.min) return false;
            if (a_size.height.size.minmax.max != b_size.height.size.minmax.max) return false;
        }
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

    if (a.visual != null and b.visual != null) {
        const a_visual = a.visual.?;
        const b_visual = b.visual.?;
        if (a_visual.background != null and b_visual.background != null) {
            if (a_visual.background.?.color != null and b_visual.background.?.color != null) {
                if (!compareRgba(a_visual.background.?.color.?, b_visual.background.?.color.?)) return false;
            }
        }

        if (a_visual.font_size != b_visual.font_size) return false;
        if (a_visual.letter_spacing != b_visual.letter_spacing) return false;
        if (a_visual.line_height != b_visual.line_height) return false;
        if (a_visual.font_weight != b_visual.font_weight) return false;
        // if (a_visual.border_radius != null and b_visual.border_radius != null) {
        //     if (a_visual.border_radius.?.top_left != b_visual.border_radius.?.top_left) return false;
        //     if (a_visual.border_radius.?.top_right != b_visual.border_radius.?.top_right) return false;
        //     if (a_visual.border_radius.?.bottom_left != b_visual.border_radius.?.bottom_left) return false;
        //     if (a_visual.border_radius.?.bottom_right != b_visual.border_radius.?.bottom_right) return false;
        // }
        // if (a_visual.border_thickness != null and b_visual.border_thickness != null) {
        //     if (a_visual.border_thickness.?.top != b_visual.border_thickness.?.top) return false;
        //     if (a_visual.border_thickness.?.left != b_visual.border_thickness.?.left) return false;
        //     if (a_visual.border_thickness.?.right != b_visual.border_thickness.?.right) return false;
        //     if (a_visual.border_thickness.?.bottom != b_visual.border_thickness.?.bottom) return false;
        // }
        // if (a_visual.border_color != null and b_visual.border_color != null) {
        //     if (!compareRgba(a_visual.border_color.?, b_visual.border_color.?)) return false;
        // }
        if (a_visual.border != null and b_visual.border != null) {
            const border_a = a_visual.border.?;
            const border_b = b_visual.border.?;
            if (border_a.color != null and border_b.color != null) {
                if (!compareRgba(border_a.color.?, border_b.color.?)) return false;
            }
            if (border_a.radius != null and border_b.radius != null) {
                if (border_a.radius.?.top_left != border_b.radius.?.top_left) return false;
                if (border_a.radius.?.top_right != border_b.radius.?.top_right) return false;
                if (border_a.radius.?.bottom_left != border_b.radius.?.bottom_left) return false;
                if (border_a.radius.?.bottom_right != border_b.radius.?.bottom_right) return false;
            }
            // if (border_a.thickness != null and border_b.thickness != null) {
            if (border_a.thickness.top != border_b.thickness.top) return false;
            if (border_a.thickness.left != border_b.thickness.left) return false;
            if (border_a.thickness.right != border_b.thickness.right) return false;
            if (border_a.thickness.bottom != border_b.thickness.bottom) return false;
            // }
        }
        if (a_visual.text_color != null and b_visual.text_color != null) {
            if (!compareRgba(a_visual.text_color.?, b_visual.text_color.?)) return false;
        }

        if (a_visual.opacity != null and b_visual.opacity != null) {
            if (a_visual.opacity.? != b_visual.opacity.?) return false;
        }
    }

    // if (a.overflow != b.overflow) return false;

    // if (a.overflow_x != b.overflow_x) return false;
    // if (a.overflow_y != b.overflow_y) return false;
    if (a.layout != null and b.layout != null) {
        if (a.layout.?.y != b.layout.?.y) return false;
        if (a.layout.?.x != b.layout.?.x) return false;
    }

    if (a.child_gap != null and b.child_gap != null) {
        if (a.child_gap.? != b.child_gap.?) return false;
    }

    // return false;
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

fn compareRgba(a: Color, b: Color) bool {
    switch (a) {
        .Literal => {
            const c_a = a.Literal;
            const c_b = b.Literal;
            if (c_a.r == c_b.r and c_a.g == c_b.g and c_a.b == c_b.b and c_a.a == c_b.a) {
                return true;
            } else {
                return false;
            }
        },
        else => return false,
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

const any = *anyopaque;
pub fn cast(comptime T: type, opaque_ptr: any) T {
    return @ptrCast(@alignCast(opaque_ptr));
}

pub fn getUnderlyingType(comptime T: type) type {
    return switch (@typeInfo(T)) {
        .optional => std.meta.Child(T),
        else => T,
    };
}

pub fn getUnderlyingValue(comptime T: type, comptime OT: type, v: OT) T {
    return switch (@typeInfo(OT)) {
        .optional => v.?,
        else => v,
    };
}

// Trim whitespace
pub fn trim(str: []const u8) []const u8 {
    return std.mem.trim(u8, str, " \t\n\r");
}

// Check contains / startsWith / endsWith
pub fn contains(haystack: []const u8, needle: []const u8) bool {
    return std.mem.indexOf(u8, haystack, needle) != null;
}

pub fn startsWith(str: []const u8, prefix: []const u8) bool {
    return std.mem.startsWith(u8, str, prefix);
}

// Clamp a number
pub fn clamp(val: anytype, min_val: anytype, max_val: anytype) @TypeOf(val) {
    return @max(min_val, @min(max_val, val));
}

// Linear interpolation — great for animations
pub fn lerp(a: f64, b: f64, t: f64) f64 {
    return a + (b - a) * clamp(t, 0.0, 1.0);
}

pub fn toLowerCase(str: []const u8, arena_type: Vapor.ArenaType) []const u8 {
    return std.ascii.allocLowerString(Vapor.arena(arena_type), str) catch unreachable;
}

pub fn toUpperCase(str: []const u8, arena_type: Vapor.ArenaType) []const u8 {
    return std.ascii.allocUpperString(Vapor.arena(arena_type), str) catch unreachable;
}

pub fn firstLetterToUpper(str: []const u8, arena_type: Vapor.ArenaType) []const u8 {
    const capital = std.ascii.allocUpperString(Vapor.allocator_global, str[0..1]) catch unreachable;
    defer Vapor.allocator_global.free(capital);
    return std.fmt.allocPrint(Vapor.arena(arena_type), "{s}{s}", .{ capital, str[1..] }) catch unreachable;
}

pub fn stringReplace(str: []const u8, needle: []const u8, replacement: []const u8, arena_type: Vapor.ArenaType) []const u8 {
    const size = std.mem.replacementSize(u8, str, needle, replacement);
    const buf = Vapor.arena(arena_type).alloc(u8, size) catch unreachable;
    _ = std.mem.replace(u8, str, needle, replacement, buf);
    return buf;
}

pub fn stringify(value: anytype, arena_type: Vapor.ArenaType) ![]const u8 {
    var writer = std.Io.Writer.Allocating.init(Vapor.arena(arena_type));
    try std.json.Stringify.value(value, .{ .emit_null_optional_fields = true, .escape_unicode = true }, &writer.writer);
    const payload = writer.written();
    return payload;
}

pub fn formatJson(input: []const u8) []const u8 {
    var result = std.array_list.Managed(u8).init(Vapor.arena(.persist));
    var indent_level: usize = 0;
    const indent_str = "  ";
    var in_string = false;
    var escape = false;
    var i: usize = 0;

    while (i < input.len) : (i += 1) {
        const c = input[i];

        if (escape) {
            result.append(c) catch unreachable;
            escape = false;
            continue;
        }

        if (c == '\\' and in_string) {
            result.append(c) catch unreachable;
            escape = true;
            continue;
        }

        if (c == '"') {
            in_string = !in_string;
            result.append(c) catch unreachable;
            continue;
        }

        if (in_string) {
            result.append(c) catch unreachable;
            continue;
        }

        // Skip existing whitespace outside strings
        if (c == ' ' or c == '\t' or c == '\n' or c == '\r') continue;

        switch (c) {
            '{', '[' => {
                result.append(c) catch unreachable;
                // Peek ahead: if the matching close is next (empty object/array), keep compact
                const next = skipWhitespace(input, i + 1);
                const close: u8 = if (c == '{') '}' else ']';
                if (next < input.len and input[next] == close) {
                    result.append(close) catch unreachable;
                    i = next;
                } else {
                    indent_level += 1;
                    result.append('\n') catch unreachable;
                    appendIndent(&result, indent_level, indent_str);
                }
            },
            '}', ']' => {
                indent_level -|= 1;
                result.append('\n') catch unreachable;
                appendIndent(&result, indent_level, indent_str);
                result.append(c) catch unreachable;
            },
            ':' => {
                result.appendSlice(": ") catch unreachable;
            },
            ',' => {
                result.append(',') catch unreachable;
                result.append('\n') catch unreachable;
                appendIndent(&result, indent_level, indent_str);
            },
            else => {
                result.append(c) catch unreachable;
            },
        }
    }

    return result.toOwnedSlice() catch unreachable;
}

fn skipWhitespace(input: []const u8, start: usize) usize {
    var pos = start;
    while (pos < input.len and (input[pos] == ' ' or input[pos] == '\t' or input[pos] == '\n' or input[pos] == '\r')) : (pos += 1) {}
    return pos;
}

fn appendIndent(result: *std.array_list.Managed(u8), level: usize, indent_str: []const u8) void {
    for (0..level) |_| {
        result.appendSlice(indent_str) catch unreachable;
    }
}

// /// The idea is to get parent ptr recursively
// pub fn getParent(comptime TargetType: type, comptime field: []const u8, field_ptr: *FT) type {
//     @fieldParentPtr(field, field_ptr: *T)
// }

fn isJsonSerializable(comptime T: type) bool {
    return comptime isJsonSerializableImpl(T, 0);
}

fn isJsonSerializableImpl(comptime T: type, comptime depth: usize) bool {
    if (depth > 32) return false;

    const info = @typeInfo(T);

    return switch (info) {
        .bool, .int, .float, .comptime_int, .comptime_float, .null => true,
        .void => true,

        .pointer => |ptr| {
            if (ptr.size == .slice and ptr.child == u8) return true;
            return false;
        },

        .array => |arr| isJsonSerializableImpl(arr.child, depth + 1),

        .optional => |opt| isJsonSerializableImpl(opt.child, depth + 1),

        .@"enum" => true,

        .@"union" => |u| {
            if (u.tag_type == null) return false;
            inline for (u.fields) |field| {
                if (field.type != void and !isJsonSerializableImpl(field.type, depth + 1)) {
                    return false;
                }
            }
            return true;
        },

        .@"struct" => |s| {
            inline for (s.fields) |field| {
                if (!isJsonSerializableImpl(field.type, depth + 1)) {
                    return false;
                }
            }
            return true;
        },

        else => false,
    };
}

const SerializeConfig = struct {
    max_array_len: usize = 16,
    max_string_len: usize = 256,
    max_depth: usize = 8,
};

pub fn serializeArgs(allocator: std.mem.Allocator, value: anytype, config: SerializeConfig) ![]const u8 {
    var buf = Vapor.Array(u8).init(allocator);
    errdefer buf.deinit();
    try serializeValue(buf.writer(), value, config, 0);
    return buf.toOwnedSlice();
}

fn serializeValue(writer: anytype, value: anytype, config: SerializeConfig, depth: usize) !void {
    if (depth > config.max_depth) {
        try writer.writeAll("\"<max depth>\"");
        return;
    }

    const T = @TypeOf(value);
    const info = @typeInfo(T);

    switch (info) {
        .bool => try writer.writeAll(if (value) "true" else "false"),

        .int, .comptime_int, .float, .comptime_float => try writer.print("{d}", .{value}),

        .null => try writer.writeAll("null"),

        .void => try writer.writeAll("null"),

        .pointer => |ptr| {
            if (ptr.size == .slice and ptr.child == u8) {
                // String - truncate if needed
                try writer.writeByte('"');
                const len = @min(value.len, config.max_string_len);
                for (value[0..len]) |c| {
                    switch (c) {
                        '"' => try writer.writeAll("\\\""),
                        '\\' => try writer.writeAll("\\\\"),
                        '\n' => try writer.writeAll("\\n"),
                        '\r' => try writer.writeAll("\\r"),
                        '\t' => try writer.writeAll("\\t"),
                        else => {
                            if (c < 0x20) {
                                try std.fmt.format(writer, "\\u{x:0>4}", .{c});
                            } else {
                                try writer.writeByte(c);
                            }
                        },
                    }
                }
                if (value.len > config.max_string_len) {
                    try std.fmt.format(writer, "...<truncated {d} chars>", .{value.len - config.max_string_len});
                }
                try writer.writeByte('"');
            } else if (@typeInfo(ptr.child) == .int or @typeInfo(ptr.child) == .float) {
                try writer.print("{d}", .{value.*});
            } else {
                try writer.writeAll("\"<pointer>\"");
            }
        },

        .array => |arr| {
            try writer.writeByte('[');
            const len = @min(arr.len, config.max_array_len);
            for (0..len) |i| {
                if (i > 0) try writer.writeByte(',');
                try serializeValue(writer, value[i], config, depth + 1);
            }
            if (arr.len > config.max_array_len) {
                try std.fmt.format(writer, ",\"...<{d} more>\"", .{arr.len - config.max_array_len});
            }
            try writer.writeByte(']');
        },

        .optional => {
            if (value) |v| {
                try serializeValue(writer, v, config, depth + 1);
            } else {
                try writer.writeAll("null");
            }
        },

        .@"enum" => {
            try writer.writeByte('"');
            try writer.writeAll(@tagName(value));
            try writer.writeByte('"');
        },

        .@"union" => |u| {
            if (u.tag_type == null) {
                try writer.writeAll("\"<untagged union>\"");
                return;
            }
            try writer.writeAll("{\"");
            try writer.writeAll(@tagName(value));
            try writer.writeAll("\":");
            inline for (u.fields) |field| {
                if (std.mem.eql(u8, @tagName(value), field.name)) {
                    if (field.type == void) {
                        try writer.writeAll("null");
                    } else {
                        try serializeValue(writer, @field(value, field.name), config, depth + 1);
                    }
                }
            }
            try writer.writeByte('}');
        },

        .@"struct" => |s| {
            if (s.is_tuple) {
                try writer.writeByte('[');
                inline for (s.fields, 0..) |field, i| {
                    if (i > 0) try writer.writeByte(',');
                    try serializeValue(writer, @field(value, field.name), config, depth + 1);
                }
                try writer.writeByte(']');
            } else {
                try writer.writeByte('{');
                var first = true;
                inline for (s.fields) |field| {
                    if (!first) try writer.writeByte(',');
                    first = false;
                    try writer.writeByte('"');
                    try writer.writeAll(field.name);
                    try writer.writeAll("\":");
                    try serializeValue(writer, @field(value, field.name), config, depth + 1);
                }
                try writer.writeByte('}');
            }
        },

        else => try writer.writeAll("\"<unsupported>\""),
    }
}
