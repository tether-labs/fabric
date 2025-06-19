const std = @import("std");
const rl = @import("raylib");
const rg = @import("raygui");
const Fabric = @import("../../Fabric.zig");

var default_font: rl.Font = undefined;
fn loadFont(file_data: ?[]const u8, font_id: u16, font_size: i32) !void {
    raylib_fonts[font_id] = try rl.loadFontFromMemory(".ttf", file_data, font_size * 2, null);
    rl.setTextureFilter(raylib_fonts[font_id].?.texture, .bilinear);
}

fn initRl() void {
    rl.initWindow(config.screen_width, config.screen_height, "Hello");
    loadFont(@embedFile("Roboto-Regular.ttf"), 0, 24) catch unreachable;
    default_font = raylib_fonts[0].?;
    rg.guiSetFont(default_font);
}

pub var raylib_fonts: [10]?rl.Font = .{null} ** 10;
pub fn measureText(elem_text: []const u8, config: *Props) Dimensions {
    const font = default_font;
    // const font = raylib_fonts[config.font_id].?;
    const text: []const u8 = elem_text;
    const font_size: f32 = @floatFromInt(config.font_size);
    const letter_spacing: f32 = @floatFromInt(config.letter_spacing);
    const line_height = config.line_height;

    var temp_byte_counter: usize = 0;
    var byte_counter: usize = 0;
    var text_width: f32 = 0.0;
    var temp_text_width: f32 = 0.0;
    var text_height: f32 = font_size;
    const scale_factor: f32 = font_size / @as(f32, @floatFromInt(font.baseSize));

    var utf8 = std.unicode.Utf8View.initUnchecked(text).iterator();

    // var largest_length: f32 = 0;
    while (utf8.nextCodepoint()) |codepoint| {
        byte_counter += std.unicode.utf8CodepointSequenceLength(codepoint) catch 1;
        const index: usize = @intCast(
            rl.getGlyphIndex(font, @as(i32, @intCast(codepoint))),
        );

        if (codepoint != '\n') {
            if (font.glyphs[index].advanceX != 0) {
                const word_length: f32 = @floatFromInt(font.glyphs[index].advanceX);
                // largest_length = @max(largest_length, word_length);
                text_width += word_length;
            } else {
                text_width += font.recs[index].width + @as(f32, @floatFromInt(font.glyphs[index].offsetX));
            }
        } else {
            if (temp_text_width < text_width) temp_text_width = text_width;
            byte_counter = 0;
            text_width = 0;
            text_height += font_size + @as(f32, @floatFromInt(line_height));
        }

        if (temp_byte_counter < byte_counter) temp_byte_counter = byte_counter;
    }

    if (temp_text_width < text_width) temp_text_width = text_width;

    const calc_text_width = temp_text_width * scale_factor + (@as(f32, @floatFromInt(temp_byte_counter)) - 1) * letter_spacing;
    // const measured_text = std.heap.c_allocator.dupeZ(u8, text) catch {
    //     return Dimensions{
    //         .height = .{ .size = .{ .minmax = .{ .min = text_height, .max = text_height } } },
    //         .width = .{ .size = .{ .minmax = .{ .min = calc_text_width, .max = calc_text_width } } },
    //     };
    // };
    // calc_text_width = @floatFromInt(rl.measureText(measured_text, config.font_size));
    return Dimensions{
        .height = .{ .size = .{ .minmax = .{ .min = text_height, .max = text_height } } },
        .width = .{ .size = .{ .minmax = .{ .min = 20, .max = calc_text_width } } },
    };
}

fn getTextWidth(
    elem_text: []const u8,
    font_size: f32,
    letter_spacing: f32,
    line_height: i32,
) f32 {
    const font = default_font;
    // const font = raylib_fonts[config.font_id].?;
    const text: []const u8 = elem_text;

    var temp_byte_counter: usize = 0;
    var byte_counter: usize = 0;
    var text_width: f32 = 0.0;
    var temp_text_width: f32 = 0.0;
    var text_height: f32 = font_size;
    const scale_factor: f32 = font_size / @as(f32, @floatFromInt(font.baseSize));

    var utf8 = std.unicode.Utf8View.initUnchecked(text).iterator();

    // var largest_length: f32 = 0;
    while (utf8.nextCodepoint()) |codepoint| {
        byte_counter += std.unicode.utf8CodepointSequenceLength(codepoint) catch 1;
        const index: usize = @intCast(
            rl.getGlyphIndex(font, @as(i32, @intCast(codepoint))),
        );

        if (codepoint != '\n') {
            if (font.glyphs[index].advanceX != 0) {
                const word_length: f32 = @floatFromInt(font.glyphs[index].advanceX);
                // largest_length = @max(largest_length, word_length);
                text_width += word_length;
            } else {
                text_width += font.recs[index].width + @as(f32, @floatFromInt(font.glyphs[index].offsetX));
            }
        } else {
            if (temp_text_width < text_width) temp_text_width = text_width;
            byte_counter = 0;
            text_width = 0;
            text_height += font_size + @as(f32, @floatFromInt(line_height));
        }

        if (temp_byte_counter < byte_counter) temp_byte_counter = byte_counter;
    }

    if (temp_text_width < text_width) temp_text_width = text_width;

    const calc_text_width = temp_text_width * scale_factor + (@as(f32, @floatFromInt(temp_byte_counter)) - 1) * letter_spacing;
    return calc_text_width;
}

pub fn wrapText(elem_text: []const u8, width: f32, c_font_size: i32, c_letter_spacing: i32, line_height: i32, text_buffer: *[4096]u8) f32 {
    // const font = default_font;
    var count: usize = 0;
    const text: []const u8 = elem_text;
    var text_width: f32 = 0.0;
    var temp_text_width: f32 = 0.0;
    var start: usize = 0;
    var prev_space: usize = 0;
    const font_size: f32 = @floatFromInt(c_font_size);
    var text_height: f32 = font_size + @as(f32, @floatFromInt(line_height));
    const letter_spacing: f32 = @floatFromInt(c_letter_spacing);
    // const scale_factor: f32 = font_size / @as(f32, @floatFromInt(font.baseSize));
    @memcpy(text_buffer[0..text.len], text);
    print("Max Container width: {any}\n", .{width});
    while (count < text.len) {
        if (findIndex(text[count..], ' ')) |found| {
            print("Current Text {s}\n", .{text[start..]});
            count += found;
            // const measured_text = std.heap.c_allocator.dupeZ(u8, text[start..count]) catch return 0.0;
            text_width = getTextWidth(text[start..count], font_size, letter_spacing, line_height);
            print("Sentence {any}\n", .{text_width});
        } else {
            print("Current Text {s}\n", .{text[start..]});
            // const measured_text = std.heap.c_allocator.dupeZ(u8, text[start..]) catch return 0.0;
            // text_width = @floatFromInt(rl.measureText(measured_text, c_font_size));
            text_width = getTextWidth(text[start..], font_size, letter_spacing, line_height);
        }
        if (text_width > width) {
            print("Found {s}\n", .{text[start..prev_space]});
            text_buffer[prev_space] = '\n';
            text_width = 0.0;
            temp_text_width = 0.0;
            start = prev_space + 1;
            text_height += font_size + @as(f32, @floatFromInt(line_height));
        }
        prev_space = count;
        count += 1;
    }
    print("{s}\n", .{text_buffer[0..text.len]});
    return text_height;

    // const font = raylib_fonts[config.font_id].?;

    // var temp_byte_counter: usize = 0;
    // var byte_counter: usize = 0;
    // // var text_height: f32 = font_size;
    //
    // var utf8 = std.unicode.Utf8View.initUnchecked(text).iterator();
    //
    // // var largest_length: f32 = 0;
    // while (utf8.nextCodepoint()) |codepoint| {
    //     byte_counter += std.unicode.utf8CodepointSequenceLength(codepoint) catch 1;
    //     const index: usize = @intCast(
    //         rl.getGlyphIndex(font, @as(i32, @intCast(codepoint))),
    //     );
    //
    //     if (codepoint != '\n') {
    //         if (font.glyphs[index].advanceX != 0) {
    //             const word_length: f32 = @floatFromInt(font.glyphs[index].advanceX);
    //             // largest_length = @max(largest_length, word_length);
    //             text_width += word_length;
    //         } else {
    //             text_width += font.recs[index].width + @as(f32, @floatFromInt(font.glyphs[index].offsetX));
    //         }
    //     } else {
    //         if (temp_text_width < text_width) temp_text_width = text_width;
    //         byte_counter = 0;
    //         text_width = 0;
    //     }
    //
    //     if (temp_byte_counter < byte_counter) temp_byte_counter = byte_counter;
    //     if (temp_text_width < text_width) temp_text_width = text_width;
    //     const calc_text_width: f32 = temp_text_width * scale_factor + (@as(f32, @floatFromInt(temp_byte_counter)) - 1) * letter_spacing;
    //     if (calc_text_width >= end) {
    //         print("Lenght: {any} {any}\n", .{ calc_text_width, end });
    //         text_buffer[byte_counter] = '\n';
    //     }
    // }
}
fn createShadow(cmd: *types.RenderCommand) void {
    const bounding_box = cmd.bounding_box;
    const color: rl.Color = convertToRLColor(cmd.props.shadow.color);
    const offset_x = cmd.props.shadow.left;
    const offset_y = cmd.props.shadow.top;
    // const spread = cmd.props.shadow.spread;
    const h = cmd.props.shadow.height;
    const w = cmd.props.shadow.width;
    const posx = bounding_box.x - (w / 2);
    const posy = bounding_box.y - (h / 2);
    const border_color: rl.Color = convertToRLColor(cmd.border_color);

    // const rect = rl.Rectangle{
    //     .x = posx + offset_x,
    //     .y = posy + offset_y,
    //     .width = bounding_box.width + w,
    //     .height = bounding_box.height + h,
    // };
    drawRoundedBlock(BoundingBox{
        .x = posx + offset_x,
        .y = posy + offset_y,
        .width = bounding_box.width + w,
        .height = bounding_box.height + h,
    }, cmd.border_radius, color, types.Border.default(), border_color);
}

fn convertToRLColor(color: [4]f32) rl.Color {
    const r: u8 = @intFromFloat(color[0]);
    const g: u8 = @intFromFloat(color[1]);
    const b: u8 = @intFromFloat(color[2]);
    const a: u8 = @intFromFloat(color[3]);
    return rl.Color.init(r, g, b, a);
}



fn drawRoundedBlock(
    bounding_box: types.BoundingBox,
    radius: types.BorderRadius,
    background_color: rl.Color,
    thickness: types.Border,
    border_color: rl.Color,
) void {
    {
        const max_left_radius = @max(radius.top_left, radius.bottom_left);
        const max_right_radius = @max(radius.top_right, radius.bottom_right);
        const max_top_radius = @max(radius.top_left, radius.top_right);
        const max_bottom_radius = @max(radius.bottom_left, radius.bottom_right);

        const center_rect = rl.Rectangle{
            .x = bounding_box.x + max_left_radius,
            .y = bounding_box.y,
            .width = bounding_box.width - max_left_radius - max_right_radius,
            .height = bounding_box.height,
        };
        rl.drawRectangleRec(center_rect, background_color);

        // Left rectangle (between corners)
        const left_rect = rl.Rectangle{
            .x = bounding_box.x,
            .y = bounding_box.y + max_top_radius,
            .width = max_left_radius,
            .height = bounding_box.height - max_top_radius - max_bottom_radius,
        };
        rl.drawRectangleRec(left_rect, background_color);

        // Right rectangle (between corners)
        const right_rect = rl.Rectangle{
            .x = bounding_box.x + bounding_box.width - max_right_radius,
            .y = bounding_box.y + max_top_radius,
            .width = max_right_radius,
            .height = bounding_box.height - max_top_radius - max_bottom_radius,
        };
        rl.drawRectangleRec(right_rect, background_color);

        // // Top rectangle (between corners, if needed)
        // if (max_top_radius > 0) {
        //     const top_rect = rl.Rectangle{
        //         .x = bounding_box.x + radius.top_left,
        //         .y = bounding_box.y,
        //         .width = bounding_box.width - radius.top_left - radius.top_right,
        //         .height = max_top_radius,
        //     };
        //     rl.drawRectangleRec(top_rect, background_color);
        // }
        //
        // // Bottom rectangle (between corners, if needed)
        // if (max_bottom_radius > 0) {
        //     const bottom_rect = rl.Rectangle{
        //         .x = bounding_box.x + radius.bottom_left,
        //         .y = bounding_box.y + bounding_box.height - max_bottom_radius,
        //         .width = bounding_box.width - radius.bottom_left - radius.bottom_right,
        //         .height = max_bottom_radius,
        //     };
        //     rl.drawRectangleRec(bottom_rect, background_color);
        // }
    }
    // rl.drawRectangleRounded(rect, cmd.border_radius / 100, 100000, background_color);

    // rl.drawRectangleRec(rect, background_color);

    if (radius.top_left > 0) {
        rl.drawCircleSector(
            rl.Vector2{
                .x = (bounding_box.x + radius.top_left),
                .y = (bounding_box.y + radius.top_left),
            },
            // @round(radius.top_left - thickness.top),
            radius.top_left,
            180,
            270,
            10,
            background_color,
        );
    }
    if (radius.top_right > 0) {
        rl.drawCircleSector(
            rl.Vector2{
                .x = (bounding_box.x + bounding_box.width - radius.top_right),
                .y = (bounding_box.y + radius.top_right),
            },
            // @round(radius.top_right - thickness.top),
            radius.top_right,
            270,
            360,
            10,
            background_color,
        );
    }
    if (radius.bottom_left > 0) {
        rl.drawCircleSector(
            rl.Vector2{
                .x = (bounding_box.x + radius.bottom_left),
                .y = (bounding_box.y + bounding_box.height - radius.bottom_left),
            },
            // @round(radius.bottom_left - thickness.bottom),
            radius.bottom_left,
            90,
            180,
            10,
            background_color,
        );
    }
    if (radius.bottom_right > 0) {
        rl.drawCircleSector(
            rl.Vector2{
                .x = (bounding_box.x + bounding_box.width - radius.bottom_right),
                .y = (bounding_box.y + bounding_box.height - radius.bottom_right),
            },
            // @round(radius.bottom_right - thickness.bottom),
            radius.bottom_right,
            0.1,
            90,
            10,
            background_color,
        );
    }

    if (radius.top_left > 0) {
        rl.drawRing(
            rl.Vector2{
                .x = @round(bounding_box.x + radius.top_left),
                .y = @round(bounding_box.y + radius.top_left),
            },
            @round(radius.top_left - thickness.top),
            radius.top_left,
            180,
            270,
            10,
            border_color,
        );
    }
    if (radius.top_right > 0) {
        rl.drawRing(
            rl.Vector2{
                .x = @round(bounding_box.x + bounding_box.width - radius.top_right),
                .y = @round(bounding_box.y + radius.top_right),
            },
            @round(radius.top_right - thickness.top),
            radius.top_right,
            270,
            360,
            10,
            border_color,
        );
    }
    if (radius.bottom_left > 0) {
        rl.drawRing(
            rl.Vector2{
                .x = @round(bounding_box.x + radius.bottom_left),
                .y = @round(bounding_box.y + bounding_box.height - radius.bottom_left),
            },
            @round(radius.bottom_left - thickness.bottom),
            radius.bottom_left,
            90,
            180,
            10,
            border_color,
        );
    }
    if (radius.bottom_right > 0) {
        rl.drawRing(
            rl.Vector2{
                .x = @round(bounding_box.x + bounding_box.width - radius.bottom_right),
                .y = @round(bounding_box.y + bounding_box.height - radius.bottom_right),
            },
            @round(radius.bottom_right - thickness.bottom),
            radius.bottom_right,
            0.1,
            90,
            10,
            border_color,
        );
    }

    if (thickness.top > 0) {
        const posx = bounding_box.x + radius.top_left;
        const posy = bounding_box.y;
        const border_rect = rl.Rectangle{
            .x = posx,
            .y = posy,
            .width = bounding_box.width - radius.top_left - radius.top_right,
            .height = thickness.top,
        };
        rl.drawRectangleRec(border_rect, border_color);
    }
    if (thickness.left > 0) {
        const posx = bounding_box.x;
        const posy = bounding_box.y + radius.top_left;
        const border_rect = rl.Rectangle{
            .x = posx,
            .y = posy,
            .width = thickness.left,
            .height = bounding_box.height - radius.top_left - radius.bottom_left,
        };
        rl.drawRectangleRec(border_rect, border_color);
    }
    if (thickness.bottom > 0) {
        const posx = bounding_box.x + radius.bottom_left;
        const posy = bounding_box.y + bounding_box.height - thickness.bottom;
        const border_rect = rl.Rectangle{
            .x = posx,
            .y = posy,
            .width = bounding_box.width - radius.bottom_left - radius.bottom_right,
            .height = thickness.bottom,
        };
        rl.drawRectangleRec(border_rect, border_color);
    }
    if (thickness.right > 0) {
        const posx = bounding_box.x + bounding_box.width - thickness.right;
        const posy = bounding_box.y + radius.top_right;
        const border_rect = rl.Rectangle{
            .x = posx,
            .y = posy,
            .width = thickness.right,
            .height = bounding_box.height - radius.top_right - radius.bottom_right,
        };
        rl.drawRectangleRec(border_rect, border_color);
    }
}

pub fn renderLoop(fabric: *Fabric) void {
    // rl.setConfigFlags(.{ .window_resizable = true });
    defer rl.closeWindow(); // Close window and OpenGL context

    rl.setTargetFPS(60); // Set our game to run at 60 frames-per-second
    //--------------------------------------------------------------------------------------

    // Main game loop
    while (!rl.windowShouldClose()) { // Detect window close button or ESC key
        // Update
        //----------------------------------------------------------------------------------
        // TODO: Update your variables here
        //----------------------------------------------------------------------------------

        // Draw
        //----------------------------------------------------------------------------------
        rl.beginDrawing();
        defer rl.endDrawing();
        rl.clearBackground(rl.Color.white);
        fabric.render();
        // rl.drawRectangle(screenWidth / 4 * 2 - 60, 100, 120, 60, rl.Color.red);

        //----------------------------------------------------------------------------------
    }
}

pub fn render() void {
    for (Fabric.ui_ctx.render_cmds.items) |cmd| {
        // const bounding_box = BoundingBox{
        //     .x = cmd.elem.calculated_x,
        //     .y = cmd.elem.calculated_y,
        //     .width = cmd.elem.calculated_width,
        //     .height = cmd.elem.calculated_height,
        // };
        const bounding_box = cmd.bounding_box;
        const cmd_type = cmd.elem_type;
        var background_color: rl.Color = convertToRLColor(cmd.background);
        const color: rl.Color = convertToRLColor(cmd.color);
        const border_color: rl.Color = convertToRLColor(cmd.border_color);

        switch (cmd_type) {
            .FlexBox => {
                // posX: i32, posY: i32, width: i32, height: i32, background_color: Color
                const rect = rl.Rectangle{
                    .x = bounding_box.x,
                    .y = bounding_box.y,
                    .width = bounding_box.width,
                    .height = bounding_box.height,
                };
                rl.drawRectangleRec(rect, background_color);
            },
            .Block => {
                // const rect = rl.Rectangle{
                //     .x = bounding_box.x,
                //     .y = bounding_box.y,
                //     .width = bounding_box.width,
                //     .height = bounding_box.height,
                // };
                const radius = cmd.border_radius;
                // Draw the central rectangle
                {
                    const max_left_radius = @max(radius.top_left, radius.bottom_left);
                    const max_right_radius = @max(radius.top_right, radius.bottom_right);
                    const max_top_radius = @max(radius.top_left, radius.top_right);
                    const max_bottom_radius = @max(radius.bottom_left, radius.bottom_right);

                    const center_rect = rl.Rectangle{
                        .x = bounding_box.x + max_left_radius,
                        .y = bounding_box.y,
                        .width = bounding_box.width - max_left_radius - max_right_radius,
                        .height = bounding_box.height,
                    };
                    rl.drawRectangleRec(center_rect, background_color);

                    // Left rectangle (between corners)
                    const left_rect = rl.Rectangle{
                        .x = bounding_box.x,
                        .y = bounding_box.y + max_top_radius,
                        .width = max_left_radius,
                        .height = bounding_box.height - max_top_radius - max_bottom_radius,
                    };
                    rl.drawRectangleRec(left_rect, background_color);

                    // Right rectangle (between corners)
                    const right_rect = rl.Rectangle{
                        .x = bounding_box.x + bounding_box.width - max_right_radius,
                        .y = bounding_box.y + max_top_radius,
                        .width = max_right_radius,
                        .height = bounding_box.height - max_top_radius - max_bottom_radius,
                    };
                    rl.drawRectangleRec(right_rect, background_color);

                    // Top rectangle (between corners, if needed)
                    if (max_top_radius > 0) {
                        const top_rect = rl.Rectangle{
                            .x = bounding_box.x + radius.top_left,
                            .y = bounding_box.y,
                            .width = bounding_box.width - radius.top_left - radius.top_right,
                            .height = max_top_radius,
                        };
                        rl.drawRectangleRec(top_rect, background_color);
                    }

                    // Bottom rectangle (between corners, if needed)
                    if (max_bottom_radius > 0) {
                        const bottom_rect = rl.Rectangle{
                            .x = bounding_box.x + radius.bottom_left,
                            .y = bounding_box.y + bounding_box.height - max_bottom_radius,
                            .width = bounding_box.width - radius.bottom_left - radius.bottom_right,
                            .height = max_bottom_radius,
                        };
                        rl.drawRectangleRec(bottom_rect, background_color);
                    }
                }
                // rl.drawRectangleRounded(rect, cmd.border_radius / 100, 100000, background_color);

                // rl.drawRectangleRec(rect, background_color);

                if (cmd.border_radius.top_left > 0) {
                    rl.drawCircleSector(
                        rl.Vector2{
                            .x = @round(bounding_box.x + cmd.border_radius.top_left),
                            .y = @round(bounding_box.y + cmd.border_radius.top_left),
                        },
                        // @round(cmd.border_radius.top_left - cmd.border_thickness.top),
                        cmd.border_radius.top_left,
                        180,
                        270,
                        10,
                        background_color,
                    );
                }
                if (cmd.border_radius.top_right > 0) {
                    rl.drawCircleSector(
                        rl.Vector2{
                            .x = @round(bounding_box.x + bounding_box.width - cmd.border_radius.top_right),
                            .y = @round(bounding_box.y + cmd.border_radius.top_right),
                        },
                        // @round(cmd.border_radius.top_right - cmd.border_thickness.top),
                        cmd.border_radius.top_right,
                        270,
                        360,
                        10,
                        background_color,
                    );
                }
                if (cmd.border_radius.bottom_left > 0) {
                    rl.drawCircleSector(
                        rl.Vector2{
                            .x = @round(bounding_box.x + cmd.border_radius.bottom_left),
                            .y = @round(bounding_box.y + bounding_box.height - cmd.border_radius.bottom_left),
                        },
                        // @round(cmd.border_radius.bottom_left - cmd.border_thickness.bottom),
                        cmd.border_radius.bottom_left,
                        90,
                        180,
                        10,
                        background_color,
                    );
                }
                if (cmd.border_radius.bottom_right > 0) {
                    rl.drawCircleSector(
                        rl.Vector2{
                            .x = @round(bounding_box.x + bounding_box.width - cmd.border_radius.bottom_right),
                            .y = @round(bounding_box.y + bounding_box.height - cmd.border_radius.bottom_right),
                        },
                        // @round(cmd.border_radius.bottom_right - cmd.border_thickness.bottom),
                        cmd.border_radius.bottom_right,
                        0.1,
                        90,
                        10,
                        background_color,
                    );
                }

                if (cmd.border_radius.top_left > 0) {
                    rl.drawRing(
                        rl.Vector2{
                            .x = @round(bounding_box.x + cmd.border_radius.top_left),
                            .y = @round(bounding_box.y + cmd.border_radius.top_left),
                        },
                        @round(cmd.border_radius.top_left - cmd.border_thickness.top),
                        cmd.border_radius.top_left,
                        180,
                        270,
                        10,
                        border_color,
                    );
                }
                if (cmd.border_radius.top_right > 0) {
                    rl.drawRing(
                        rl.Vector2{
                            .x = @round(bounding_box.x + bounding_box.width - cmd.border_radius.top_right),
                            .y = @round(bounding_box.y + cmd.border_radius.top_right),
                        },
                        @round(cmd.border_radius.top_right - cmd.border_thickness.top),
                        cmd.border_radius.top_right,
                        270,
                        360,
                        10,
                        border_color,
                    );
                }
                if (cmd.border_radius.bottom_left > 0) {
                    rl.drawRing(
                        rl.Vector2{
                            .x = @round(bounding_box.x + cmd.border_radius.bottom_left),
                            .y = @round(bounding_box.y + bounding_box.height - cmd.border_radius.bottom_left),
                        },
                        @round(cmd.border_radius.bottom_left - cmd.border_thickness.bottom),
                        cmd.border_radius.bottom_left,
                        90,
                        180,
                        10,
                        border_color,
                    );
                }
                if (cmd.border_radius.bottom_right > 0) {
                    rl.drawRing(
                        rl.Vector2{
                            .x = @round(bounding_box.x + bounding_box.width - cmd.border_radius.bottom_right),
                            .y = @round(bounding_box.y + bounding_box.height - cmd.border_radius.bottom_right),
                        },
                        @round(cmd.border_radius.bottom_right - cmd.border_thickness.bottom),
                        cmd.border_radius.bottom_right,
                        0.1,
                        90,
                        10,
                        border_color,
                    );
                }

                if (cmd.border_thickness.top > 0) {
                    const posx = bounding_box.x + cmd.border_radius.top_left;
                    const posy = bounding_box.y;
                    const border_rect = rl.Rectangle{
                        .x = posx,
                        .y = posy,
                        .width = bounding_box.width - cmd.border_radius.top_left - cmd.border_radius.top_right,
                        .height = cmd.border_thickness.top,
                    };
                    rl.drawRectangleRec(border_rect, border_color);
                }
                if (cmd.border_thickness.left > 0) {
                    const posx = bounding_box.x;
                    const posy = bounding_box.y + cmd.border_radius.top_left;
                    const border_rect = rl.Rectangle{
                        .x = posx,
                        .y = posy,
                        .width = cmd.border_thickness.left,
                        .height = bounding_box.height - cmd.border_radius.top_left - cmd.border_radius.bottom_left,
                    };
                    rl.drawRectangleRec(border_rect, border_color);
                }
                if (cmd.border_thickness.bottom > 0) {
                    const posx = bounding_box.x + cmd.border_radius.bottom_left;
                    const posy = bounding_box.y + bounding_box.height - cmd.border_thickness.bottom;
                    const border_rect = rl.Rectangle{
                        .x = posx,
                        .y = posy,
                        .width = bounding_box.width - cmd.border_radius.bottom_left - cmd.border_radius.bottom_right,
                        .height = cmd.border_thickness.bottom,
                    };
                    rl.drawRectangleRec(border_rect, border_color);
                }
                if (cmd.border_thickness.right > 0) {
                    const posx = bounding_box.x + bounding_box.width - cmd.border_thickness.right;
                    const posy = bounding_box.y + cmd.border_radius.top_right;
                    const border_rect = rl.Rectangle{
                        .x = posx,
                        .y = posy,
                        .width = cmd.border_thickness.right,
                        .height = bounding_box.width - cmd.border_radius.top_right - cmd.border_radius.bottom_right,
                    };
                    rl.drawRectangleRec(border_rect, border_color);
                }
            },
            .Box => {
                // posX: i32, posY: i32, width: i32, height: i32, background_color: Color
                const rect = rl.Rectangle{
                    .x = bounding_box.x,
                    .y = bounding_box.y,
                    .width = bounding_box.width,
                    .height = bounding_box.height,
                };
                // rl.drawRectangleRounded(rect, cmd.border_radius / 100, 100000, background_color);
                rl.drawRectangleRec(rect, background_color);
            },
            .Text => {
                const text = std.heap.c_allocator.dupeZ(u8, cmd.text) catch return;
                // const rect = rl.Rectangle{
                //     .x = bounding_box.x,
                //     .y = bounding_box.y,
                //     .width = bounding_box.width,
                //     .height = bounding_box.height,
                // };
                // rl.drawRectangleRec(rect, rl.Color.black);
                rl.setTextLineSpacing(cmd.line_height);
                rl.drawTextEx(
                    default_font,
                    text,
                    rl.Vector2{ .x = bounding_box.x, .y = bounding_box.y },
                    @floatFromInt(cmd.font_size),
                    @floatFromInt(cmd.letter_spacing),
                    color,
                );
            },
            .Button => {
                const radius = cmd.border_radius;

                createShadow(cmd);

                const orginal_rect = rl.Rectangle{
                    .x = bounding_box.x,
                    .y = bounding_box.y,
                    .width = bounding_box.width,
                    .height = bounding_box.height,
                };

                const pos = rl.getMousePosition();
                const mouse_hover = rl.checkCollisionPointRec(pos, orginal_rect);
                // const mouse_down = mouse_hover and rl.isMouseButtonDown(.left);
                // var pressed: bool = false;

                if (mouse_hover) {
                    background_color = convertToRLColor(cmd.props.focused.color);
                    // print("We are hovering\n", .{});
                }

                drawRoundedBlock(
                    bounding_box,
                    radius,
                    convertToRLColor(cmd.props.background),
                    cmd.border_thickness,
                    border_color,
                );

                // Draw the central rectangle
                {
                    const max_left_radius = @max(radius.top_left, radius.bottom_left);
                    const max_right_radius = @max(radius.top_right, radius.bottom_right);
                    const max_top_radius = @max(radius.top_left, radius.top_right);
                    const max_bottom_radius = @max(radius.bottom_left, radius.bottom_right);

                    const center_rect = rl.Rectangle{
                        .x = bounding_box.x + max_left_radius,
                        .y = bounding_box.y,
                        .width = bounding_box.width - max_left_radius - max_right_radius,
                        .height = bounding_box.height,
                    };
                    rl.drawRectangleRec(center_rect, background_color);

                    // Left rectangle (between corners)
                    const left_rect = rl.Rectangle{
                        .x = bounding_box.x,
                        .y = bounding_box.y + max_top_radius,
                        .width = max_left_radius,
                        .height = bounding_box.height - max_top_radius - max_bottom_radius,
                    };
                    rl.drawRectangleRec(left_rect, background_color);

                    // Right rectangle (between corners)
                    const right_rect = rl.Rectangle{
                        .x = bounding_box.x + bounding_box.width - max_right_radius,
                        .y = bounding_box.y + max_top_radius,
                        .width = max_right_radius,
                        .height = bounding_box.height - max_top_radius - max_bottom_radius,
                    };
                    rl.drawRectangleRec(right_rect, background_color);

                    // // Top rectangle (between corners, if needed)
                    // if (max_top_radius > 0) {
                    //     const top_rect = rl.Rectangle{
                    //         .x = bounding_box.x + radius.top_left,
                    //         .y = bounding_box.y,
                    //         .width = bounding_box.width - radius.top_left - radius.top_right,
                    //         .height = max_top_radius,
                    //     };
                    //     rl.drawRectangleRec(top_rect, background_color);
                    // }
                    //
                    // // Bottom rectangle (between corners, if needed)
                    // if (max_bottom_radius > 0) {
                    //     const bottom_rect = rl.Rectangle{
                    //         .x = bounding_box.x + radius.bottom_left,
                    //         .y = bounding_box.y + bounding_box.height - max_bottom_radius,
                    //         .width = bounding_box.width - radius.bottom_left - radius.bottom_right,
                    //         .height = max_bottom_radius,
                    //     };
                    //     rl.drawRectangleRec(bottom_rect, background_color);
                    // }
                }
                // rl.drawRectangleRounded(rect, cmd.border_radius / 100, 100000, background_color);

                // rl.drawRectangleRec(rect, background_color);

                if (cmd.border_radius.top_left > 0) {
                    rl.drawCircleSector(
                        rl.Vector2{
                            .x = @round(bounding_box.x + cmd.border_radius.top_left),
                            .y = @round(bounding_box.y + cmd.border_radius.top_left),
                        },
                        // @round(cmd.border_radius.top_left - cmd.border_thickness.top),
                        cmd.border_radius.top_left,
                        180,
                        270,
                        10,
                        background_color,
                    );
                }
                if (cmd.border_radius.top_right > 0) {
                    rl.drawCircleSector(
                        rl.Vector2{
                            .x = @round(bounding_box.x + bounding_box.width - cmd.border_radius.top_right),
                            .y = @round(bounding_box.y + cmd.border_radius.top_right),
                        },
                        // @round(cmd.border_radius.top_right - cmd.border_thickness.top),
                        cmd.border_radius.top_right,
                        270,
                        360,
                        10,
                        background_color,
                    );
                }
                if (cmd.border_radius.bottom_left > 0) {
                    rl.drawCircleSector(
                        rl.Vector2{
                            .x = @round(bounding_box.x + cmd.border_radius.bottom_left),
                            .y = @round(bounding_box.y + bounding_box.height - cmd.border_radius.bottom_left),
                        },
                        // @round(cmd.border_radius.bottom_left - cmd.border_thickness.bottom),
                        cmd.border_radius.bottom_left,
                        90,
                        180,
                        10,
                        background_color,
                    );
                }
                if (cmd.border_radius.bottom_right > 0) {
                    rl.drawCircleSector(
                        rl.Vector2{
                            .x = @round(bounding_box.x + bounding_box.width - cmd.border_radius.bottom_right),
                            .y = @round(bounding_box.y + bounding_box.height - cmd.border_radius.bottom_right),
                        },
                        // @round(cmd.border_radius.bottom_right - cmd.border_thickness.bottom),
                        cmd.border_radius.bottom_right,
                        0.1,
                        90,
                        10,
                        background_color,
                    );
                }

                if (cmd.border_radius.top_left > 0) {
                    rl.drawRing(
                        rl.Vector2{
                            .x = @round(bounding_box.x + cmd.border_radius.top_left),
                            .y = @round(bounding_box.y + cmd.border_radius.top_left),
                        },
                        @round(cmd.border_radius.top_left - cmd.border_thickness.top),
                        cmd.border_radius.top_left,
                        180,
                        270,
                        10,
                        border_color,
                    );
                }
                if (cmd.border_radius.top_right > 0) {
                    rl.drawRing(
                        rl.Vector2{
                            .x = @round(bounding_box.x + bounding_box.width - cmd.border_radius.top_right),
                            .y = @round(bounding_box.y + cmd.border_radius.top_right),
                        },
                        @round(cmd.border_radius.top_right - cmd.border_thickness.top),
                        cmd.border_radius.top_right,
                        270,
                        360,
                        10,
                        border_color,
                    );
                }
                if (cmd.border_radius.bottom_left > 0) {
                    rl.drawRing(
                        rl.Vector2{
                            .x = @round(bounding_box.x + cmd.border_radius.bottom_left),
                            .y = @round(bounding_box.y + bounding_box.height - cmd.border_radius.bottom_left),
                        },
                        @round(cmd.border_radius.bottom_left - cmd.border_thickness.bottom),
                        cmd.border_radius.bottom_left,
                        90,
                        180,
                        10,
                        border_color,
                    );
                }
                if (cmd.border_radius.bottom_right > 0) {
                    rl.drawRing(
                        rl.Vector2{
                            .x = @round(bounding_box.x + bounding_box.width - cmd.border_radius.bottom_right),
                            .y = @round(bounding_box.y + bounding_box.height - cmd.border_radius.bottom_right),
                        },
                        @round(cmd.border_radius.bottom_right - cmd.border_thickness.bottom),
                        cmd.border_radius.bottom_right,
                        0.1,
                        90,
                        10,
                        border_color,
                    );
                }

                if (cmd.border_thickness.top > 0) {
                    const posx = bounding_box.x + cmd.border_radius.top_left;
                    const posy = bounding_box.y;
                    const border_rect = rl.Rectangle{
                        .x = posx,
                        .y = posy,
                        .width = bounding_box.width - cmd.border_radius.top_left - cmd.border_radius.top_right,
                        .height = cmd.border_thickness.top,
                    };
                    rl.drawRectangleRec(border_rect, border_color);
                }
                if (cmd.border_thickness.left > 0) {
                    const posx = bounding_box.x;
                    const posy = bounding_box.y + cmd.border_radius.top_left;
                    const border_rect = rl.Rectangle{
                        .x = posx,
                        .y = posy,
                        .width = cmd.border_thickness.left,
                        .height = bounding_box.height - cmd.border_radius.top_left - cmd.border_radius.bottom_left,
                    };
                    rl.drawRectangleRec(border_rect, border_color);
                }
                if (cmd.border_thickness.bottom > 0) {
                    const posx = bounding_box.x + cmd.border_radius.bottom_left;
                    const posy = bounding_box.y + bounding_box.height - cmd.border_thickness.bottom;
                    const border_rect = rl.Rectangle{
                        .x = posx,
                        .y = posy,
                        .width = bounding_box.width - cmd.border_radius.bottom_left - cmd.border_radius.bottom_right,
                        .height = cmd.border_thickness.bottom,
                    };
                    rl.drawRectangleRec(border_rect, border_color);
                }
                if (cmd.border_thickness.right > 0) {
                    const posx = bounding_box.x + bounding_box.width - cmd.border_thickness.right;
                    const posy = bounding_box.y + cmd.border_radius.top_right;
                    const border_rect = rl.Rectangle{
                        .x = posx,
                        .y = posy,
                        .width = cmd.border_thickness.right,
                        .height = bounding_box.height - cmd.border_radius.top_right - cmd.border_radius.bottom_right,
                    };
                    rl.drawRectangleRec(border_rect, border_color);
                }

                // if (mouse_hover and rl.isMouseButtonReleased(.left)) {
                //     print("We got clicked\n", .{});
                //     pressed = true;
                // }

                const transparent_rect = rl.Rectangle{
                    .x = bounding_box.x,
                    .y = bounding_box.y,
                    .width = bounding_box.width,
                    .height = bounding_box.height,
                };

                rl.drawRectangleRec(transparent_rect, rl.Color.init(0, 0, 0, 0));
                rg.guiSetStyle(.button, rg.GuiControlProperty.border_width, 0);
                rg.guiSetStyle(.button, rg.GuiControlProperty.base_color_normal, 0);
                rg.guiSetStyle(.button, rg.GuiControlProperty.border_color_focused, 0);
                rg.guiSetStyle(.button, rg.GuiControlProperty.base_color_focused, 0);
                rg.guiSetStyle(.default, rg.GuiDefaultProperty.text_size, cmd.font_size);
                rg.guiSetStyle(.button, rg.GuiControlProperty.base_color_pressed, 0);
                rg.guiSetStyle(.button, rg.GuiControlProperty.border_color_pressed, 0);
                rg.guiSetStyle(
                    .button,
                    rg.GuiControlProperty.text_color_focused,
                    rl.colorToInt(convertToRLColor(cmd.props.hover.text_color)),
                );
                rg.guiSetStyle(
                    .button,
                    rg.GuiControlProperty.text_color_pressed,
                    rl.colorToInt(convertToRLColor(cmd.props.pressed.text_color)),
                );
                rg.guiSetStyle(
                    .button,
                    rg.GuiControlProperty.text_color_normal,
                    rl.colorToInt(convertToRLColor(cmd.props.text_color)),
                );
                if (rg.guiButton(transparent_rect, "Click me") > 0) {
                    print("We have been Click\n", .{});
                }
            },
            else => {},
        }
    }
}
