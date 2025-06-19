const std = @import("std");
const Fabric = @import("../Fabric.zig");
const Element = @import("../Element.zig").Element;
const JsonColorCoder = @import("../routes/components/JsonColorCoder.zig");
const helpers = @import("../helpers.zig");
const Kit = Fabric.Kit;
const Signal = Fabric.Signal;
const Static = Fabric.Static;
const Binded = Fabric.Binded;
const Pure = Fabric.Pure;
const Dynamic = Fabric.Dynamic;
const Style = Fabric.Style;
const Treehouse = @import("Treehouse.zig");
const Btn = @import("../routes/components/button/Btn.zig").Button;
const Notification = @import("Notification.zig");
const Datatable = @import("../routes/components/datatable/DataTable1.zig");
const DT = Datatable.DataTable;
const Row = Datatable.Row;
const Col = Datatable.Column;
const Action = Datatable.Action;

var primary: [4]f32 = undefined;
var secondary: [4]f32 = undefined;
var btn_color: [4]f32 = undefined;
var border_color: [4]f32 = undefined;
var text_color: [4]f32 = undefined;

const ServerLogs = @This();
var treehouse: Treehouse = undefined;
var default_text: []const u8 = "";

const Item = struct {
    element: usize,
    th_value: Treehouse.ValueType,
};

fn Card(row: Row(Item)) void {
    const fields = @typeInfo(Item).@"struct".fields;
    inline for (fields) |field| {
        const field_value: field.type = @field(row.value, field.name);
        Static.TableCell(.{
            .padding = .{ .left = 64, .right = 64, .top = 16, .bottom = 16 },
        })({
            switch (field.type) {
                usize => {
                    Pure.AllocText("{any}", .{field_value}, .{
                        .font_size = 16,
                    });
                },
                Treehouse.ValueType => {
                    switch (field_value) {
                        .int => {
                            Pure.AllocText("{any}", .{field_value.int}, .{
                                .font_size = 16,
                            });
                        },
                        .float => {
                            Pure.AllocText("{any}", .{field_value.float}, .{
                                .font_size = 16,
                            });
                        },
                        .json => {
                            Pure.Text(field_value.json, .{
                                .font_size = 16,
                            });
                        },
                        .string => {
                            Pure.Text(field_value.string, .{
                                .font_size = 16,
                            });
                        },
                    }
                },
                else => {},
            }
        });
    }
}

btn_echo: Btn(echo, *ServerLogs) = undefined,
btn_get: Btn(get, *ServerLogs) = undefined,
btn_set: Btn(set, *ServerLogs) = undefined,
btn_push: Btn(lpush, *ServerLogs) = undefined,
btn_add: Btn(addItem, *ServerLogs) = undefined,
btn_del: Btn(delete, *ServerLogs) = undefined,
btn_update: Btn(update, *ServerLogs) = undefined,
btn_save: Btn(save, *ServerLogs) = undefined,

datatable: DT(Item, Card) = undefined,

text_area: Element = undefined,
json_editor: Element = undefined,
input_element: Element = undefined,
code__editor: JsonColorCoder = undefined,
json_changed: *Signal(u32) = undefined,
notify: *Signal(void) = undefined,
key: []const u8 = undefined,
value: Treehouse.ValueType = undefined,
submitted: *Signal(bool) = undefined,
command: []const u8 = "",

const Effect = struct {
    const Self = @This();
    count: usize = 0,
    pub fn effect_callback(self: *Self) void {
        self.count += 1;
        Fabric.printlnSrc("Count {any}", .{self.count}, @src());
    }
};

pub fn init(sl: *ServerLogs) void {
    treehouse.allocator = &Fabric.allocator_global;

    // Btns init
    sl.btn_echo.init(sl, .{ .text = "Echo", .type = .outline });
    sl.btn_get.init(sl, .{ .text = "Get", .type = .outline });
    sl.btn_set.init(sl, .{ .text = "Set", .type = .outline });
    sl.btn_push.init(sl, .{ .text = "Push", .type = .outline });
    sl.btn_add.init(sl, .{ .text = "Add Item", .type = .outline, .width = .percent(1) });
    sl.btn_del.init(sl, .{ .text = "Delete", .type = .outline });
    sl.btn_update.init(sl, .{ .text = "Update", .type = .outline });
    sl.btn_save.init(sl, .{ .text = "Save", .type = .tint, .width = .percent(1) });

    var cols = [_]Col{
        Col{ .title = "Element", .selector = "element" },
        Col{ .title = "Value", .selector = "value" },
    };

    var rows = [_]Row(Item){
        Row(Item){
            .id = "e6c81b79-d2fc-4518-b240-a8b3e88c2a85",
            .value = .{ .element = 0, .th_value = Treehouse.ValueType{ .string = "content-1" } },
        },
    };

    var actions = [_]Action(Item){
        Action(Item){ .label = "copy", .cb = copy },
        // Action(Item){ .label = "view", .cb = openModal },
    };

    sl.datatable.init(&Fabric.allocator_global, &cols, &rows, &actions);

    // Element init
    sl.text_area = Element{ .id = "d7cce548-66e0-4f96-b3ea-8496db54ca3f" };
    sl.json_editor = Element{ .id = "034d4b4d-bc14-46ff-ba84-618da7b0b817" };
    sl.input_element = Element{ .id = "cc8c01b1-b4cc-4f5d-8777-9c6f935f860c" };

    // Create Signals;
    sl.json_changed = Signal(u32).init(0, &Fabric.allocator_global);
    sl.notify = Signal(void).init({}, &Fabric.allocator_global);
    sl.submitted = Signal(bool).init(false, &Fabric.allocator_global);

    sl.notify.effect(Effect);

    // Fabric.clearLocalStorageWasm();
    _ = Fabric.getWindowPath();

    // Get local storage values
    const key = Fabric.getLocalStorageString("default_key");
    if (key) |k| {
        sl.key = k;
    }

    // Get local storage values
    const value = Fabric.getLocalStorageString("default_value");
    if (value) |v| {
        default_text = v;
    }
    sl.json_editor.id = sl.code__editor.init(&Fabric.allocator_global, default_text);

    primary = Fabric.Theme.getAttribute("primary");
    secondary = Fabric.Theme.getAttribute("secondary");
    btn_color = Fabric.Theme.getAttribute("btn_color");
    border_color = Fabric.Theme.getAttribute("border_color");
    text_color = Fabric.Theme.getAttribute("text_color");
}

fn addItem(sl: *ServerLogs) void {
    const count = sl.datatable.len();
    sl.datatable.append(Row(Item){
        .id = helpers.generateUUID(Fabric.allocator_global) catch "",
        .value = .{ .element = count, .th_value = sl.value },
    });
}

fn copy(item: Item) void {
    Fabric.printlnSrc("{any}", .{item.th_value}, @src());
}

fn echo(sl: *ServerLogs) void {
    treehouse.echo("ECHO", sl, handleResponse);
}

fn get(sl: *ServerLogs) void {
    const key = sl.grabKey() orelse return;
    sl.command = treehouse.get(key, sl, handleResponse) catch |err| {
        std.log.err("{any}", .{err});
        return;
    };
    sl.notify.force();
}

fn set(sl: *ServerLogs) void {
    const key = sl.grabKey() orelse return;
    const value = sl.grabData() orelse @panic("Could not grab data");
    sl.command = treehouse.set(key, value, sl, handleResponse) catch |err| {
        Fabric.printlnSrcErr("{any}", .{err}, @src());
        return;
    };
    sl.notify.force();
}

fn lpush(sl: *ServerLogs) void {
    const key = sl.grabKey() orelse return;
    const data = sl.grabData() orelse {
        Fabric.printlnSrcErr("Data is null", .{}, @src());
        return;
    };
    sl.command = treehouse.lpush(key, data, sl, handleResponse) catch |err| {
        std.log.err("{any}", .{err});
        return;
    };
    sl.notify.force();
}

fn lpushmany(sl: *ServerLogs) void {
    sl.command = treehouse.lpushmany("mylist", &.{
        .{ .string = "content-1" },
        .{ .string = "content-2" },
    }, sl, handleResponse) catch |err| {
        std.log.err("{any}", .{err});
        return;
    };
    sl.notify.force();
}

fn update(sl: *ServerLogs) void {
    treehouse.set("user:123", .{ .string = "content-1" }, sl, handleResponse) catch |err| {
        std.log.err("{any}", .{err});
    };
}

fn delete(sl: *ServerLogs) void {
    const key = sl.grabKey() orelse return;
    sl.command = treehouse.del(key, sl, handleResponse) catch |err| {
        std.log.err("{any}", .{err});
        return;
    };
    sl.notify.force();
}

fn save(sl: *ServerLogs) void {
    const key = sl.grabKey() orelse return;
    const value = sl.grabData() orelse return;
    Fabric.setLocalStorageString("default_key", key);
    switch (value) {
        .json => {
            Fabric.setLocalStorageString("default_value", sl.value.json);
        },
        .string => {
            Fabric.setLocalStorageString("default_value", sl.value.string);
        },
        .int => {
            Fabric.setLocalStorageNumber("default_value", @intCast(sl.value.int));
        },
        else => {},
        // .float => {
        //     Fabric.setLocalStorageString(sl.key, sl.value);
        // },
    }
    sl.submitted.set(true);
}

fn handleResponse(_: *ServerLogs, resp: Kit.Response) void {
    Fabric.println("{s}\n", .{resp.body});
}

const JsonData = struct {
    key: []const u8,
    value: []const u8,
};

fn grabKey(sl: *ServerLogs) ?[]const u8 {
    const key = sl.input_element.getInputValue() orelse return null;
    sl.key = key;
    return key;
}

fn grabData(sl: *ServerLogs) ?Treehouse.ValueType {
    const json = sl.text_area.getInputValue() orelse return null;
    const value = determineType(json) orelse @panic("Could not grab data");
    sl.value = value;
    return value;
}

fn determineType(data: []const u8) ?Treehouse.ValueType {
    switch (data[0]) {
        '{' => {
            return Treehouse.ValueType{
                .json = data,
            };
        },
        '"' => {
            return Treehouse.ValueType{
                .string = data,
            };
        },
        '\'' => {
            return null;
        },
        else => {
            const is_float = std.mem.count(u8, data, ".");
            if (is_float > 0) {
                const value = std.fmt.parseFloat(f32, data) catch @panic("Could not parse int");
                return Treehouse.ValueType{
                    .float = value,
                };
            }
            const value = std.fmt.parseInt(i32, data, 10) catch @panic("Could not parse int");
            return Treehouse.ValueType{
                .int = value,
            };
        },
    }
}

fn logParseText(sl: *ServerLogs, _: *Fabric.Event) void {
    const json = sl.text_area.getInputValue() orelse return;
    sl.code__editor.reinit(json) catch return;
    default_text = json;
    sl.json_changed.increment();
}

fn autoScroll(sl: *ServerLogs, _: *Fabric.Event) void {
    if (Kit.throttle()) return;
    const scrollTop = sl.text_area.getAttributeNumber("scrollTop");
    sl.json_editor.scrollTop(scrollTop);
}

fn mount(sl: *ServerLogs) void {
    _ = Fabric.elementInstEventListener(sl.text_area.id.?, .input, sl, logParseText);
    _ = Fabric.elementInstEventListener(sl.text_area.id.?, .scroll, sl, autoScroll);
}
pub fn render(sl: *ServerLogs) void {
    Static.FlexBox(.{
        .width = .percent(1),
        .direction = .column,
        .background = primary,
        .child_gap = 12,
        .overflow_y = .scroll,
        .padding = .{ .top = 100 },
    })({
        Static.Block(.{
            .width = .percent(0.4),
            .border_thickness = .{ .bottom = 1 },
            .border_color = border_color,
            .padding = .{ .bottom = 4 },
        })({
            Static.Text("Key", .{
                .text_color = text_color,
                .font_size = 16,
            });
        });
        Binded.Input(&sl.input_element, .{ .string = .{
            .default = "...",
            .required = true,
            .value = sl.key,
        } }, .{
            .background = primary,
            .text_color = text_color,
            .outline = .none,
            .font_size = 16,
            .border_color = border_color,
            .border_radius = .all(8),
            .height = .fixed(42),
            .border_thickness = .all(1),
            .width = .percent(0.4),
            .padding = .{ .left = 12, .right = 12, .bottom = 10, .top = 10 },
            .box_sizing = .border_box,
        });

        Static.FlexBox(.{
            .width = .percent(0.4),
            .child_alignment = .{ .x = .between, .y = .center },
            .child_gap = 12,
        })({
            sl.btn_echo.render();
            sl.btn_get.render();
            sl.btn_set.render();
            sl.btn_push.render();
            sl.btn_del.render();
        });

        Pure.TextArea(sl.command, .{
            .padding = .all(12),
            .background = primary,
            .text_color = text_color,
            .border_radius = .all(8),
            .border_color = border_color,
            .border_thickness = .all(1),
            .font_size = 12,
            .outline = .none,
            .width = .percent(0.4),
            .height = .fixed(160),
            .box_sizing = .border_box,
        });

        Static.FlexBox(.{
            .width = .percent(0.4),
            .position = .{ .type = .relative },
            .direction = .column,
            .child_gap = 60,
        })({
            Static.Block(.{
                .position = .{ .type = .absolute, .top = .fixed(0) },
                .width = .percent(1),
                .height = .fixed(360),
                .margin = .all(12),
                .background = Fabric.hexToRgba("#121212"),
                .border_radius = .all(10),
                .box_sizing = .border_box,
                .padding = .all(12),
            })({
                sl.code__editor.render(0);
            });
            Static.CtxHooks(.mounted, mount, .{sl}, .{
                .position = .{ .type = .relative, .top = .fixed(0) },
                .width = .percent(1),
                // .height = .fixed(360),
                .height = .percent(1),
                .direction = .column,
                .margin = .all(12),
                .z_index = 1000,
                .box_sizing = .border_box,
            })({
                Static.FlexBox(.{
                    .display = .flex,
                    .width = .percent(1),
                    .direction = .row,
                    .box_sizing = .border_box,
                })({
                    Static.Block(.{ .height = .fixed(360), .width = .fixed(24) })({});
                    Binded.JsonEditor(&sl.text_area, default_text, .{
                        .width = .percent(1),
                        .height = .fixed(360),
                        .display = .flex,
                        .direction = .column,
                        .child_alignment = .{ .x = .start, .y = .center },
                        .border_radius = .all(10),
                        .text_color = .{ 255, 255, 255, 0 },
                        .outline = .none,
                        .padding = .all(12),
                        .box_sizing = .border_box,
                        .font_size = 14,
                    });
                });
            });
            sl.btn_save.render();
            sl.btn_add.render();
        });
        Static.FlexBox(.{})({
            sl.datatable.render();
        });
    });
    Notification.render(sl.submitted, "Saved");
}
