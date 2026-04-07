const std = @import("std");

const Vapor = @import("Vapor.zig");

const UINode = @import("UITree.zig").UINode;

const utils = @import("utils.zig");

const hashKey = utils.hashKey;

const println = Vapor.println;

var writer: *std.Io.Writer = undefined;

const mode_options =
    struct {
        pub const static_mode = false;
        pub const enable_atomic = true;
    };

pub fn generate(root: *UINode, new_writer: *std.Io.Writer, style_path: []const u8) void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer if (gpa.deinit() != .ok) @panic("Failed to deinit gpa");
    var arena = std.heap.ArenaAllocator.init(gpa.allocator());
    const allocator = arena.allocator();
    defer arena.deinit();
    writer = new_writer;
    const html_template = std.fs.cwd().readFileAlloc(allocator, "template.html", 0x100000) catch unreachable;

    // Write everything before the head
    const head_target = "</head>";
    const start = std.mem.indexOf(u8, html_template, head_target) orelse unreachable;
    writer.writeAll(html_template[0..start]) catch unreachable;
    const style_link = std.fmt.allocPrint(allocator, "  <link rel=\"stylesheet\" href=\"/{s}\" />", .{style_path}) catch |err| {
        std.debug.print("Error: {any}\n", .{err});
        unreachable;
    };
    // Write the style link
    writer.writeAll(style_link) catch unreachable;
    writer.writeAll("\n<link rel=\"stylesheet\" href=\"/static/style_variables.css\" />") catch unreachable;
    // writer.writeAll("\n</head>") catch unreachable;

    // Find the contents div
    const target = "<div id=\"contents\" style=\"display: contents\">";
    var end = std.mem.indexOf(u8, html_template, target) orelse unreachable;
    end += target.len;

    // Write everything after the head
    writer.writeAll(html_template[start..end]) catch unreachable;
    var children = root.children();
    while (children.next()) |child| {
        createHtmlTree(child);
    }
    writer.writeAll("</div>\n</body>\n</html>") catch unreachable;
}

/// Writes an optional HTML attribute if the value is not null.
fn writeOptionalProp(name: []const u8, value: ?[]const u8) void {
    if (value) |v| {
        _ = writer.write(name) catch unreachable;
        _ = writer.write("=\"") catch unreachable;
        _ = writer.write(v) catch unreachable; // TODO: Escape attribute value
        _ = writer.write("\"") catch unreachable;
    }
}

/// Writes all common HTML attributes from the UINode.
fn writeAllProps(ui_node: *UINode) void {
    // Write mandatory ID
    _ = writer.write(" ") catch unreachable;
    _ = writer.write(" id=\"") catch unreachable;
    _ = writer.write(ui_node.uuid) catch unreachable;
    _ = writer.write("\"") catch unreachable;

    if (ui_node.inlineStyle) |inlineStyle| {
        writeOptionalProp(" style", inlineStyle);
    }

    // Write optional props
    if (ui_node.type == .Icon) {
        var buf: [256]u8 = undefined;
        const class = ui_node.class orelse "";
        const icon_class = std.fmt.bufPrint(&buf, "{s} {s}", .{ ui_node.href.?, class }) catch unreachable;
        writeOptionalProp(" class", icon_class);
    } else {
        writeOptionalProp(" class", ui_node.class);
    }

    writeOptionalProp(" aria-label", ui_node.aria_label);
    if (ui_node.type != .Graphic and ui_node.type != .Icon) {
        if (ui_node.type == .Image) {
            writeOptionalProp(" src", ui_node.href);
        } else {
            writeOptionalProp(" href", ui_node.href);
        }
    } else if (ui_node.type == .Graphic and mode_options.static_mode) {
        writeOptionalProp(" src", ui_node.href);
    }

    // TODO: Add other attributes as needed, e.g., 'src' for 'video'
}

pub fn createDivOpen(ui_node: *UINode) void {
    _ = writer.write("<div") catch unreachable;
    writeAllProps(ui_node);
    _ = writer.write(">") catch unreachable;
}

pub fn createDivClose() void {
    _ = writer.write("</div>") catch unreachable;
}

pub fn createButtonOpen(ui_node: *UINode) void {
    _ = writer.write("<button") catch unreachable;
    writeAllProps(ui_node);
    _ = writer.write(">") catch unreachable;
}

pub fn createButtonClose() void {
    _ = writer.write("</button>") catch unreachable;
}

pub fn createParagraph(ui_node: *UINode) void {
    _ = writer.write("<p") catch unreachable;
    writeAllProps(ui_node);
    _ = writer.write(">") catch unreachable;
    if (ui_node.text) |text| {
        _ = writer.write(text) catch unreachable; // TODO: Escape HTML content
    }
    _ = writer.write("</p>") catch unreachable;
}

pub fn createField(ui_node: *UINode) void {
    _ = writer.write("<p") catch unreachable;
    writeAllProps(ui_node);
    _ = writer.write(">") catch unreachable;
    if (ui_node.text) |text| {
        _ = writer.write(text) catch unreachable; // TODO: Escape HTML content
    }
    _ = writer.write("</p>") catch unreachable;
}

pub fn createInput(ui_node: *UINode) void {
    _ = writer.write("<input") catch unreachable;
    writeAllProps(ui_node);
    writeOptionalProp("name", ui_node.name);
    const params = ui_node.text_field_params.?;
    switch (params.*) {
        // .string => |string| {
        //     var value: []const u8 = "";
        //     if (string.value_ptr) |ptr| {
        //         value = ptr[0..string.value_len];
        //     }
        //     var default_value: []const u8 = "";
        //     if (string.default_ptr) |ptr| {
        //         default_value = ptr[0..string.default_len];
        //     }
        //     // writeOptionalProp("value", value);
        //     writeOptionalProp("placeholder", default_value);
        // },
        // .int => |int| {
        //     // writeOptionalProp("value", Vapor.fmtln("{d}", int.value));
        //     writeOptionalProp("placeholder", Vapor.fmtln("{d}", int.value));
        // },
        // .password => |password| {
        //     writeOptionalProp("value", password.value);
        //     writeOptionalProp("placeholder", password.default);
        // },
        .email => |email| {
            // var value: []const u8 = "";
            // if (email.value_ptr) |ptr| {
            //     value = ptr[0..email.value_len];
            // }
            var default_value: []const u8 = "";
            if (email.default_ptr) |ptr| {
                default_value = ptr[0..email.default_len];
            }
            writeOptionalProp("type", "email");
            writeOptionalProp("placeholder", default_value);
        },
        // .telephone => |telephone| {
        //     writeOptionalProp("value", telephone.value);
        //     writeOptionalProp("placeholder", telephone.default);
        // },
        .file => |file| {
            _ = file;
            writeOptionalProp("type", "file");
        },
        // .float => |float| {
        //     writeOptionalProp("value", float.value);
        //     writeOptionalProp("placeholder", float.default);
        // },
        else => {},
    }
    _ = writer.write("/>") catch unreachable;
    // _ = writer.write("</input>") catch unreachable;
}

pub fn createTextArea(ui_node: *UINode) void {
    _ = writer.write("<textarea") catch unreachable;
    writeAllProps(ui_node);
    writeOptionalProp("name", ui_node.name);
    const params = ui_node.text_field_params.?;
    var default_value: []const u8 = "";
    const string = params.string;
    if (string.default_ptr) |ptr| {
        default_value = ptr[0..string.default_len];
    }
    writeOptionalProp("type", "email");
    writeOptionalProp("placeholder", default_value);
    _ = writer.write(">") catch unreachable;
    _ = writer.write("</textarea>") catch unreachable;
}

pub fn createLabel(ui_node: *UINode) void {
    _ = writer.write("<label ") catch unreachable;
    writeOptionalProp("for", ui_node.name);
    writeAllProps(ui_node);
    _ = writer.write(">") catch unreachable;
    if (ui_node.text) |text| {
        _ = writer.write(text) catch unreachable; // TODO: Escape HTML content
    }
    _ = writer.write("</label>") catch unreachable;
}

pub fn createLinkOpen(ui_node: *UINode) void {
    _ = writer.write("<a") catch unreachable;
    writeAllProps(ui_node);
    _ = writer.write(">") catch unreachable;
}
pub fn createLinkClose() void {
    _ = writer.write("</a>") catch unreachable;
}

pub fn createIconOpen(ui_node: *UINode) void {
    _ = writer.write("<i") catch unreachable;
    writeAllProps(ui_node);
    _ = writer.write(">") catch unreachable;
}
pub fn createIconClose() void {
    _ = writer.write("</i>") catch unreachable;
}

pub fn createImageOpen(ui_node: *UINode) void {
    _ = writer.write("<img") catch unreachable;
    writeAllProps(ui_node);
    _ = writer.write(">") catch unreachable;
}
pub fn createImageClose() void {
    _ = writer.write("</img>") catch unreachable;
}

pub fn createGraphicOpen(ui_node: *UINode) void {
    if (mode_options.static_mode) {
        _ = writer.write("<div") catch unreachable;
        writeAllProps(ui_node);
        _ = writer.write(">") catch unreachable;
    } else {
        _ = writer.write("<div") catch unreachable;
        writeAllProps(ui_node);
        _ = writer.write(">") catch unreachable;
    }
}
pub fn createGraphicClose() void {
    if (mode_options.static_mode) {
        _ = writer.write("</div>") catch unreachable;
    } else {
        _ = writer.write("</div>") catch unreachable;
    }
}

pub fn createListOpen(ui_node: *UINode) void {
    _ = writer.write("<ul") catch unreachable;
    writeAllProps(ui_node);
    _ = writer.write(">") catch unreachable;
}

pub fn createListItemClose() void {
    _ = writer.write("</li>") catch unreachable;
}

pub fn createListItemOpen(ui_node: *UINode) void {
    _ = writer.write("<li") catch unreachable;
    writeAllProps(ui_node);
    _ = writer.write("\">") catch unreachable;
}
pub fn createListClose() void {
    _ = writer.write("</ul>") catch unreachable;
}

pub fn createSectionOpen(ui_node: *UINode) void {
    _ = writer.write("<section") catch unreachable;
    writeAllProps(ui_node);
    _ = writer.write(">") catch unreachable;
}
pub fn createSectionClose() void {
    _ = writer.write("</section>") catch unreachable;
}

pub fn createCodeOpen(ui_node: *UINode) void {
    _ = writer.write("<code") catch unreachable;
    writeAllProps(ui_node);
    _ = writer.write(">") catch unreachable;
    if (ui_node.text) |text| {
        _ = writer.write(text) catch unreachable; // TODO: Escape HTML content
    }
}
pub fn createCodeClose() void {
    _ = writer.write("</code>") catch unreachable;
}

pub fn createHeadingOpen(ui_node: *UINode) void {
    _ = writer.write("<h") catch unreachable;
    if (ui_node.level) |level| {
        // Write the slice to the file
        _ = writer.print("{any}", .{level}) catch unreachable;
    }
    writeAllProps(ui_node);
    _ = writer.write(">") catch unreachable;
    if (ui_node.text) |text| {
        _ = writer.write(text) catch unreachable; // TODO: Escape HTML content
    }
}
pub fn createHeadingClose() void {
    _ = writer.write("</h>") catch unreachable;
}

pub fn createSvgOpen(ui_node: *UINode) void {
    // _ = writer.write("<svg") catch unreachable;
    // writeAllProps(ui_node);
    // _ = writer.write(">\n") catch unreachable;
    _ = writer.write(ui_node.text.?) catch unreachable;
}

pub fn createSvgClose() void {
    _ = writer.write("</svg>") catch unreachable;
}

pub fn createElementOpen(ui_node: *UINode) void {
    switch (ui_node.type) {
        .FlexBox => {
            createDivOpen(ui_node);
        },

        .Text => {
            createParagraph(ui_node);
        },
        .Icon => {
            createIconOpen(ui_node);
        },
        .TextFmt => {
            createField(ui_node);
        },
        .TextField => {
            createInput(ui_node);
        },
        .TextArea => {
            createTextArea(ui_node);
        },
        .Label => {
            createLabel(ui_node);
        },

        .Button, .CtxButton, .ButtonCycle => {
            createButtonOpen(ui_node);
        },
        // Assuming EType.Link exists for nodes with 'href'
        .Link, .RedirectLink => {
            createLinkOpen(ui_node);
        },

        .Image => {
            createImageOpen(ui_node);
        },

        .HtmlText => {
            createParagraph(ui_node);
        },

        .List => {
            createListOpen(ui_node);
        },

        .ListItem => {
            createListItemOpen(ui_node);
        },

        .Graphic => {
            createGraphicOpen(ui_node);
        },

        .Intersection => {
            createSectionOpen(ui_node);
        },

        .Code => {
            createCodeOpen(ui_node);
        },
        .Heading => {
            createHeadingOpen(ui_node);
        },

        .Svg => {
            // createSvgOpen(ui_node);
        },

        .Hooks, .HooksCtx => {
            createDivOpen(ui_node);
        },

        .Spacer => {
            createDivOpen(ui_node);
        },

        else => {
            // createDivOpen(ui_node);
        },
    }
}

pub fn createElementClose(ui_node: *UINode) void {
    switch (ui_node.type) {
        .FlexBox => {
            createDivClose();
        },

        .Button, .CtxButton, .ButtonCycle => {
            createButtonClose();
        },
        // Assuming EType.Link exists
        .Link, .RedirectLink => {
            createLinkClose();
        },

        .Icon => {
            createIconClose();
        },

        .Image => {
            createImageClose();
        },

        .Graphic => {
            createGraphicClose();
        },

        .List => {
            createListClose();
        },

        .ListItem => {
            createListItemClose();
        },

        .Intersection => {
            createSectionClose();
        },

        .Code => {
            createCodeClose();
        },

        .Heading => {
            createHeadingClose();
        },

        .Svg => {
            // createSvgClose();
        },

        .Hooks, .HooksCtx => {
            createDivClose();
        },

        .Spacer => {
            createDivClose();
        },

        else => {
            // createDivClose();
        },
    }
}

pub fn createHtmlTree(node: *UINode) void {
    // println("UI: {s}\n", .{node.uuid});
    createElementOpen(node);

    // If node type is NOT .Text (which handles its own text)
    // and it HAS text, write it as content.
    // This is for <button>Text</button> or <a>Text</a>
    _ = writer.write("\n") catch unreachable;
    var children = node.children();
    while (children.next()) |child| {
        createHtmlTree(child);
    }

    // Only call close for non-atomic elements
    if (node.type != .Text) {
        createElementClose(node);
        _ = writer.write("\n") catch unreachable;
    }
}
