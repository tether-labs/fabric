const std = @import("std");
const builtin = @import("builtin");
const isWasi = true;
const types = @import("types.zig");
const UIContext = @import("UITree.zig");
const UINode = @import("UITree.zig").UINode;
const CommandsTree = UIContext.CommandsTree;
const Rune = @import("Rune.zig");
const GrainStruct = @import("Grain.zig");
const TransitionState = @import("Transition.zig").TransitionState;
const Router = @import("Router.zig");
pub const Element = @import("Element.zig").Element;
const KeyGenerator = @import("Key.zig").KeyGenerator;
const Reconciler = @import("Reconciler.zig");
const ColorTheme = @import("constants/Color.zig");
const TrackingAllocator = @import("TrackingAllocator.zig");
pub const KeyStone = @import("keystone/KeyStone.zig");
const getHoverStyle = @import("convertHover.zig").getHoverStyle;
const getFocusStyle = @import("convertFocus.zig").getFocusStyle;
const getFocusWithinStyle = @import("convertFocusWithin.zig").getFocusWithinStyle;
const getStyle = @import("convertStyle.zig").getStyle;
const generateInputHTML = @import("grabInputDetails.zig").generateInputHTML;
const grabInputDetails = @import("grabInputDetails.zig");
const utils = @import("utils.zig");
const createInput = grabInputDetails.createInput;
const getInputSize = grabInputDetails.getInputSize;
const getInputType = grabInputDetails.getInputType;
const getAriaLabel = utils.getAriaLabel;

pub const Component = fn (void) void;

const print = std.debug.print;
pub const stdout = std.io.getStdOut().writer();

const EventType = types.EventType;
const Active = types.Active;
const BoundingBox = types.BoundingBox;
const InputDetails = types.InputDetails;
const Dimensions = types.Dimensions;
const InputParams = types.InputParams;
pub const ElementDecl = types.ElementDeclaration;
pub const StateType = types.StateType;
const RenderCommand = types.RenderCommand;
pub const ElementType = types.ElementType;
const Hover = types.Hover;
const Focus = types.Focus;
const Transform = types.Transform;
const TransformType = types.TransformType;
pub var current_ctx: *UIContext = undefined;
pub var ctx_map: std.StringHashMap(*UIContext) = undefined;
pub var page_map: std.StringHashMap(*const fn () void) = undefined;
pub var layout_map: std.StringHashMap(*const fn (*const fn () void) void) = undefined;
pub var page_deinit_map: std.StringHashMap(*const fn () void) = undefined;
pub var global_rerender: bool = false;
pub var rerender_everything: bool = false;
pub var grain_rerender: bool = false;
pub var grain_element_uuid: []const u8 = "";
pub var current_depth_node_id: []const u8 = "";
pub var router: Router = undefined;
var serious_error: bool = false;

const Fabric = @This();
pub const Dynamic = @import("Dynamic.zig");
pub const Kit = @import("kit/Kit.zig");
pub const Static = @import("Static.zig");
pub const Binded = @import("Binded.zig");
pub const Pure = @import("Pure.zig");
pub const Forge = @import("Forge.zig");
// pub const Chart = @import("components/charts/Chart.zig");
pub const Style = types.Style;
pub const Signal = Rune.Signal;
pub const Grain = GrainStruct.Grain;
pub const Types = types;
pub const DateTime = @import("DateTime.zig");
pub const Animation = @import("Animation.zig");
pub const Transition = @import("Transition.zig");
// pub const Error = @import("routes/nightwatch/Error.zig");
pub var Theme: ColorTheme = ColorTheme{};

pub const Event = struct {
    id: u32,
    pub fn element_id(evt: *Event) []const u8 {
        const key_str: []const u8 = "target";
        const resp = getEventData(evt.id, key_str.ptr, key_str.len);
        return std.mem.span(resp);
    }

    pub fn key(evt: *Event) []const u8 {
        const key_str: []const u8 = "key";
        const resp = getEventData(evt.id, key_str.ptr, key_str.len);
        return std.mem.span(resp);
    }
    pub fn metaKey(evt: *Event) bool {
        const key_str: []const u8 = "metaKey";
        const resp = getEventData(evt.id, key_str.ptr, key_str.len);
        switch (resp[0]) {
            't' => return true,
            'f' => return false,
            else => return false,
        }
    }
    pub fn text(evt: *Event) []const u8 {
        const resp = getEventDataInput(evt.id);
        return std.mem.span(resp);
    }
    pub fn preventDefault(evt: *Event) void {
        eventPreventDefault(evt.id);
    }

    pub fn clientX(evt: *Event) f32 {
        const key_str: []const u8 = "clientX";
        return getEventDataNumber(evt.id, key_str.ptr, key_str.len);
    }

    pub fn clientY(evt: *Event) f32 {
        const key_str: []const u8 = "clientY";
        return getEventDataNumber(evt.id, key_str.ptr, key_str.len);
    }

    pub fn offsetX(evt: *Event) f32 {
        const key_str: []const u8 = "offsetX";
        return getEventDataNumber(evt.id, key_str.ptr, key_str.len);
    }

    pub fn offsetY(evt: *Event) f32 {
        const key_str: []const u8 = "offsetY";
        return getEventDataNumber(evt.id, key_str.ptr, key_str.len);
    }

    pub fn movementX(evt: *Event) f32 {
        const key_str: []const u8 = "movementX";
        return getEventDataNumber(evt.id, key_str.ptr, key_str.len);
    }

    pub fn movementY(evt: *Event) f32 {
        const key_str: []const u8 = "movementY";
        return getEventDataNumber(evt.id, key_str.ptr, key_str.len);
    }
};
pub extern fn getEventDataWasm(id: u32, ptr: [*]const u8, len: u32) [*:0]u8;
pub extern fn getEventDataInputWasm(id: u32) [*:0]u8;

pub extern fn getInputValueWasm(ptr: [*]const u8, len: u32) [*:0]u8;
pub extern fn setInputValueWasm(ptr: [*]const u8, len: u32, text_ptr: [*]const u8, text_len: u32) void;

pub extern fn clearLocalStorageWasm() void;

pub extern fn getEventDataNumberWasm(id: u32, ptr: [*]const u8, len: u32) f32;
pub extern fn getAttributeWasmNumber(ptr: [*]const u8, len: u32, attribute_ptr: [*]const u8, attribute_len: u32) u32;

extern fn getWindowInformationWasm() [*:0]u8;

pub fn getWindowPath() []const u8 {
    return std.mem.span(getWindowInformationWasm());
}

pub fn setLocalStorageString(key: []const u8, value: []const u8) void {
    setLocalStorageStringWasm(key.ptr, key.len, value.ptr, value.len);
}

pub fn getLocalStorageString(key: []const u8) ?[]const u8 {
    const value = getLocalStorageStringWasm(key.ptr, key.len);
    const value_string = std.mem.span(value);
    if (std.mem.eql(u8, value_string, "null")) {
        return null;
    } else {
        return value_string;
    }
}

pub fn removeLocalStorage(key: []const u8) void {
    removeLocalStorageWasm(key.ptr, key.len);
}

pub fn setLocalStorageNumber(key: []const u8, value: u32) void {
    setLocalStorageNumberWasm(key.ptr, key.len, value);
}

pub fn getLocalStorageNumber(key: []const u8) u32 {
    return getLocalStorageNumberWasm(key.ptr, key.len);
}

extern fn setLocalStorageStringWasm(ptr: [*]const u8, len: u32, value_ptr: [*]const u8, value_len: u32) void;
extern fn getLocalStorageStringWasm(ptr: [*]const u8, len: u32) [*:0]u8;
extern fn removeLocalStorageWasm(ptr: [*]const u8, len: u32) void;
extern fn setLocalStorageNumberWasm(ptr: [*]const u8, len: u32, value: u32) void;
extern fn getLocalStorageNumberWasm(ptr: [*]const u8, len: u32) u32;

pub extern fn getBoundingClientRectWasm(ptr: [*]const u8, len: u32) [*]f32;
pub extern fn getOffsetsWasm(ptr: [*]const u8, len: u32) [*]f32;

// Static buffers for the dummy returns
var dummy_string_buffer: [256:0]u8 = undefined;
var dummy_float_buffer: [8]f32 = undefined;
pub fn getEventData(id: u32, ptr: [*]const u8, len: u32) [*:0]u8 {
    if (isWasi) {
        return getEventDataWasm(id, ptr, len);
    } else {
        // Dummy implementation - return empty string
        @memset(dummy_string_buffer[0..dummy_string_buffer.len], 0);
        const dummy_value = "dummy_event_data";
        @memcpy(dummy_string_buffer[0..dummy_value.len], dummy_value);
        return &dummy_string_buffer;
    }
}

pub fn getEventDataInput(id: u32) [*:0]u8 {
    if (isWasi) {
        return getEventDataInputWasm(id);
    } else {
        // Dummy implementation - return empty string
        @memset(dummy_string_buffer[0..dummy_string_buffer.len], 0);
        const dummy_value = "dummy_input_value";
        @memcpy(dummy_string_buffer[0..dummy_value.len], dummy_value);
        return &dummy_string_buffer;
    }
}

pub fn setInputValue(ptr: [*]const u8, len: u32, text_ptr: [*]const u8, text_len: u32) void {
    if (isWasi) {
        return setInputValueWasm(ptr, len, text_ptr, text_len);
    } else {
        // Dummy implementation - return empty string
        return void;
    }
}

pub fn getInputValue(ptr: [*]const u8, len: u32) [*:0]u8 {
    if (isWasi) {
        return getInputValueWasm(ptr, len);
    } else {
        // Dummy implementation - return empty string
        @memset(dummy_string_buffer[0..dummy_string_buffer.len], 0);
        const dummy_value = "dummy_input_value";
        @memcpy(dummy_string_buffer[0..dummy_value.len], dummy_value);
        return &dummy_string_buffer;
    }
}

pub fn getEventDataNumber(id: u32, ptr: [*]const u8, len: u32) f32 {
    if (isWasi) {
        return getEventDataNumberWasm(id, ptr, len);
    } else {
        // Dummy implementation - return 0.0
        return 0.0;
    }
}

pub fn getBoundingClientRect(ptr: [*]const u8, len: u32) [*]f32 {
    if (isWasi) {
        return getBoundingClientRectWasm(ptr, len);
    } else {
        // Dummy implementation - return rectangle with fake values
        // Typically: [x, y, width, height, top, right, bottom, left]
        dummy_float_buffer[0] = 0.0; // x
        dummy_float_buffer[1] = 0.0; // y
        dummy_float_buffer[2] = 100.0; // width
        dummy_float_buffer[3] = 50.0; // height
        dummy_float_buffer[4] = 0.0; // top
        dummy_float_buffer[5] = 100.0; // right
        dummy_float_buffer[6] = 50.0; // bottom
        dummy_float_buffer[7] = 0.0; // left
        return &dummy_float_buffer;
    }
}

pub fn getOffsets(ptr: [*]const u8, len: u32) [*]f32 {
    if (isWasi) {
        return getOffsetsWasm(ptr, len);
    } else {
        // Dummy implementation - return offsets with fake values
        // Assuming offsets contain [offsetX, offsetY]
        dummy_float_buffer[0] = 0.0; // offsetX
        dummy_float_buffer[1] = 0.0; // offsetY
        return &dummy_float_buffer;
    }
}

pub extern fn eventPreventDefault(id: u32) void;

pub const Action = struct {
    runFn: ActionProto,
    deinitFn: NodeProto,
};

pub const ActionProto = *const fn (*Action) void;
pub const NodeProto = *const fn (*Node) void;

pub const Node = struct { data: Action };

pub var registry: std.StringHashMap(*const fn () void) = undefined;
pub var ctx_registry: std.StringHashMap(*Node) = undefined;
pub var time_out_ctx_registry: std.AutoHashMap(usize, *Node) = undefined;
pub var callback_registry: std.StringHashMap(*Node) = undefined;
pub var fetch_registry: std.AutoHashMap(u32, *Kit.FetchNode) = undefined;
pub var signal_registry: std.AutoHashMap(u32, *const fn (*Signal(type)) void) = undefined;
pub var events_callbacks: std.AutoHashMap(u32, *const fn (*Event) void) = undefined;
pub var events_inst_callbacks: std.AutoHashMap(u32, *EvtInstNode) = undefined;
pub var hooks_inst_callbacks: std.AutoHashMap(u32, *HookInstNode) = undefined;
pub var mounted_funcs: std.AutoHashMap(u32, *const fn () void) = undefined;
pub var mounted_ctx_funcs: std.AutoHashMap(u32, *Node) = undefined;
pub var created_funcs: std.AutoHashMap(u32, *const fn () void) = undefined;
pub var updated_funcs: std.AutoHashMap(u32, *const fn () void) = undefined;
pub var destroy_funcs: std.AutoHashMap(u32, *const fn () void) = undefined;
pub var removed_nodes: std.ArrayList([]const u8) = undefined;
const Class = struct {
    element_id: []const u8,
    style_id: []const u8,
};
pub var classes_to_add: std.ArrayList(Class) = undefined;
pub var classes_to_remove: std.ArrayList(Class) = undefined;
pub var component_subscribers: std.ArrayList(*Rune.ComponentNode) = undefined;
// pub var grain_subs: std.ArrayList(*GrainStruct.ComponentNode) = undefined;
pub var motions: std.ArrayList(Animation.Motion) = undefined;
// Define a type for continuation functions
var callback_count: u32 = 0;
var current_route: []const u8 = "/root";
const ContinuationFn = *const fn () void;

// Global array to store continuations
var continuations: [64]?ContinuationFn = undefined;

pub var allocator_global: std.mem.Allocator = undefined;
pub var key_depth_map: std.StringHashMap(usize) = undefined;
pub var browser_width: f32 = 0;
pub var browser_height: f32 = 0;

pub const FabricConfig = struct {
    screen_width: f32,
    screen_height: f32,
    allocator: *std.mem.Allocator,
};

sw: f32,
sh: f32,
allocator: *std.mem.Allocator,

pub fn init(target: *Fabric, config: FabricConfig) void {
    allocator_global = config.allocator.*;
    router.init(config.allocator) catch |err| {
        println("Could not init Router {any}\n", .{err});
    };

    target.* = .{
        .sw = config.screen_width,
        .sh = config.screen_height,
        .allocator = config.allocator,
    };
    registry = std.StringHashMap(*const fn () void).init(config.allocator.*);
    ctx_registry = std.StringHashMap(*Node).init(config.allocator.*);
    time_out_ctx_registry = std.AutoHashMap(usize, *Node).init(config.allocator.*);
    callback_registry = std.StringHashMap(*Node).init(config.allocator.*);
    fetch_registry = std.AutoHashMap(u32, *Kit.FetchNode).init(config.allocator.*);
    events_callbacks = std.AutoHashMap(u32, *const fn (*Event) void).init(config.allocator.*);
    events_inst_callbacks = std.AutoHashMap(u32, *EvtInstNode).init(config.allocator.*);
    hooks_inst_callbacks = std.AutoHashMap(u32, *HookInstNode).init(config.allocator.*);
    mounted_funcs = std.AutoHashMap(u32, *const fn () void).init(config.allocator.*);
    mounted_ctx_funcs = std.AutoHashMap(u32, *Node).init(config.allocator.*);
    destroy_funcs = std.AutoHashMap(u32, *const fn () void).init(config.allocator.*);
    updated_funcs = std.AutoHashMap(u32, *const fn () void).init(config.allocator.*);
    created_funcs = std.AutoHashMap(u32, *const fn () void).init(config.allocator.*);
    motions = std.ArrayList(Animation.Motion).init(config.allocator.*);
    component_subscribers = std.ArrayList(*Rune.ComponentNode).init(config.allocator.*);
    removed_nodes = std.ArrayList([]const u8).init(config.allocator.*);
    // grain_subs = std.ArrayList(*GrainStruct.ComponentNode).init(config.allocator.*);
    classes_to_add = std.ArrayList(Class).init(config.allocator.*);
    classes_to_remove = std.ArrayList(Class).init(config.allocator.*);
    browser_width = config.screen_width;
    browser_height = config.screen_height;
    ctx_map = std.StringHashMap(*UIContext).init(config.allocator.*);
    page_map = std.StringHashMap(*const fn () void).init(config.allocator.*);
    layout_map = std.StringHashMap(*const fn (*const fn () void) void).init(config.allocator.*);
    page_deinit_map = std.StringHashMap(*const fn () void).init(config.allocator.*);

    const theme = ColorTheme{};
    Theme = theme;

    for (0..continuations.len) |i| {
        continuations[i] = null;
    }

    Animation.FadeInOut.init();
    key_depth_map = std.StringHashMap(usize).init(allocator_global);
    // TrackingAllocator.printBytes();

    _ = getStyle(null);
    _ = getHoverStyle(null);
    _ = getFocusStyle(null);
    _ = getFocusWithinStyle(null);
    _ = createInput(null);
    _ = getInputType(null);
    _ = getInputSize(null);
    _ = getAriaLabel(null);
}

pub fn deinit(_: *Fabric) void {
    println("Deinitializeing\n", .{});
    // First we deinit the component subs for the signals
    for (component_subscribers.items) |node| {
        node.data.deinitFn(node);
    }
    // for (grain_subs.items) |node| {
    //     node.data.deinitFn(node);
    // }
    // then we deinit the router
    router.deinit();
    // then we deinit the button registry
    registry.deinit();

    // deinit all the mount functions
    mounted_funcs.deinit();
    mounted_ctx_funcs.deinit();
    destroy_funcs.deinit();
    updated_funcs.deinit();
    created_funcs.deinit();

    // dideint the button ctx_registry
    var ctx_itr = ctx_registry.iterator();
    while (ctx_itr.next()) |entry| {
        const node = entry.value_ptr.*;
        node.data.deinitFn(node);
    }
    ctx_registry.deinit();

    var callback_itr = callback_registry.iterator();
    while (callback_itr.next()) |entry| {
        const node = entry.value_ptr.*;
        node.data.deinitFn(node);
    }
    callback_registry.deinit();

    // dideint the button ctx_registry
    var fetch_itr = fetch_registry.iterator();
    while (fetch_itr.next()) |entry| {
        const node = entry.value_ptr.*;
        node.data.deinitFn(node);
    }
    fetch_registry.deinit();

    var evt_inst_itr = events_inst_callbacks.iterator();
    while (evt_inst_itr.next()) |entry| {
        const node = entry.value_ptr.*;
        node.data.deinit(node);
    }
    events_inst_callbacks.deinit();

    var hooks_inst_itr = hooks_inst_callbacks.iterator();
    while (hooks_inst_itr.next()) |entry| {
        const node = entry.value_ptr.*;
        node.data.deinit(node);
    }
    hooks_inst_callbacks.deinit();

    // we deinit the pages
    page_map.deinit();
    layout_map.deinit();

    // then we call all the component deinit functions for all the signals attached
    var deinit_itr = page_deinit_map.iterator();
    while (deinit_itr.next()) |entry| {
        const de = entry.value_ptr.*;
        @call(.auto, de, .{});
    }
    page_deinit_map.deinit();

    Fabric.motions.deinit();
    component_subscribers.deinit();
    // grain_subs.deinit();

    // then we iterate trhough the context maps
    var itr = ctx_map.iterator();
    while (itr.next()) |item| {
        // the ctx map recusrivley calls the deinit and destroy method for all ui nodes
        item.value_ptr.*.deinit();
        allocator_global.destroy(item.value_ptr.*);
    }
    ctx_map.deinit();
}

/// The LifeCycle struct
/// allows control over ui node in the tree
/// exposes open, configure, and close, must be called in this order to attach the node to the tree
pub const LifeCycle = struct {
    /// open takes an element decl and return a *UINode
    /// this opens the element to allow for children
    /// within the dom tree, node this current opened node is the current top stack node, ie any children
    /// will reference this node as their parent
    pub fn open(elem_decl: ElementDecl) ?*UINode {
        const ui_node = current_ctx.open(elem_decl) catch |err| {
            println("{any}\n", .{err});
            return null;
        };
        return ui_node;
    }
    /// close, closes the current UINode
    pub fn close(_: void) void {
        _ = current_ctx.close();
        return;
    }
    /// configure is used internally to configure the UINode, used for adding text props, or hover props ect
    /// within configure, we check if the node has a id if so we use that, otherwise later we generate one
    /// we also set various props, such as text, style, is an SVG or not
    /// Any mainpulation of the node after this point is considered undefined behaviour be cautious;
    pub fn configure(elem_decl: ElementDecl) void {
        _ = current_ctx.configure(elem_decl);
    }
};

var last_time: i64 = 0;
pub fn throttle() bool {
    const current_time = std.time.milliTimestamp();
    if (current_time - last_time < 1000) {
        return true;
    }
    last_time = current_time;
    return false;
}

extern fn requestRerenderWasm() void;
/// Force rerender forces the entire dom tree to check props of all dynamic and pure components and rerender the ui
/// since Fabric is built with zig and wasm, checking all props of 10000s of nodes and ui components is cheap
/// feel free to abuse force, its essentially a global signal
pub fn cycle() void {
    Fabric.global_rerender = true;
    requestRerenderWasm();
}

/// Force rerender forces the entire dom tree to check props of all dynamic and pure components and rerender the ui
/// since Fabric is built with zig and wasm, checking all props of 10000s of nodes and ui components is cheap
/// feel free to abuse force, its essentially a global signal
pub fn cycleGrain() void {
    Fabric.grain_rerender = true;
    Fabric.println("Grain rerender", .{});
    // requestRerenderWasm();
}

/// Force rerender forces the entire dom tree to check props and rerender the entire ui
/// since Fabric is built with zig and wasm, checking all props of 10000s of nodes and ui components is cheap
/// feel free to abuse force, its essentially a global signal
pub fn forceEverything() void {
    Fabric.rerender_everything = true;
    Fabric.global_rerender = true;
}

pub fn initLayout(fabric: *Fabric, style: Style) !void {
    try current_ctx.initLayout(fabric.allocator, fabric.sw, fabric.sh);
    current_ctx.stack.?.ptr.?.style = style;
}

/// This function adds the route to the tether radix tree.
/// Deinitializes the tether instance recursively calls routes deinit routes from radix tree
/// # Parameters:
/// - `fabric`: *Fabric,
/// - `path`: []const u8,
/// - `page`: CommandTree
///
/// # Returns:
/// !void.
pub fn addRoute(
    path: []const u8,
    page: *CommandsTree,
) !void {
    println("Adding route {s}\n", .{path});
    try router.addRoute(path, page);
    return;
}

// I assume its casue when we create the pages we dont reset the root node?
pub export fn rerenderLayout() void {
    // Close tags fits all the widths
    // depth first insert when inserting nodes into the tree and onto the stack
    // then close function does breadth first post order
    // since we are going back up the tree
    // growing element breadth first insert when inserting nodes into the tree and onto the stack
    current_ctx.resetAllUiNode();
    current_ctx.createStack(current_ctx.root.?);
    current_ctx.traverseCmds();
}

const LayoutFn = *const fn (*const fn () void) void;
pub const PageFn = *const fn () void;

// Generic function to call nested layouts based on route segments
var current_path: []const u8 = "";
const NestedCall = struct {
    segments: []const []const u8,
    page: PageFn,
    call_fn: PageFn = @This().call,

    pub fn call() void {
        callNestedLayouts(@This().segments);
    }
};

// fn callLayout(layout: LayoutFn, nested_call: *NestedCall) void {
//     @call(.auto, layout, .{NestedCall.call});
// }

var render_page: *const fn () void = undefined;
var route_segments: [][]const u8 = undefined;
fn callNestedLayouts() void {
    const local_allocator = std.heap.wasm_allocator;
    if (route_segments.len == 0) {
        render_page();
        return;
    }

    // Get the current layout
    var layout_itr = layout_map.iterator();
    //Generate a path variable, ie starting with "" and root => /root then "/root" and docs => /root/docs;
    current_path = std.fmt.allocPrint(local_allocator, "{s}/{s}", .{ current_path, route_segments[0] }) catch return;
    while (layout_itr.next()) |entry| {
        const layout_path = entry.key_ptr.*; // "/root" or "/root/docs"
        const layout_fn = entry.value_ptr.*;
        // We check if the layout path and current path are the same
        if (std.mem.eql(u8, current_path, layout_path)) {
            route_segments = route_segments[1..];
            layout_fn(callNestedLayouts);
        }
    } else {
        if (route_segments.len == 0) {
            return;
        }
        // No layout found, continue with remaining segments
        route_segments = route_segments[1..];
        callNestedLayouts();
    }
}

var clean_up_ctx: *UIContext = undefined;
pub fn renderCycle(route: []const u8) void {
    key_depth_map.clearRetainingCapacity();
    Fabric.registry.clearRetainingCapacity();

    var ctx_itr = ctx_registry.iterator();
    while (ctx_itr.next()) |entry| {
        const node = entry.value_ptr.*;
        node.data.deinitFn(node);
    }
    ctx_registry.clearRetainingCapacity();

    var hooks_ctx_itr = mounted_ctx_funcs.iterator();
    while (hooks_ctx_itr.next()) |entry| {
        const node = entry.value_ptr.*;
        node.data.deinitFn(node);
    }
    mounted_ctx_funcs.clearRetainingCapacity();

    // Get the old context for current route
    const old_route = router.searchRoute(route) orelse {
        printlnWithColor("No Router found {s}\n", .{route}, "#FF3029", "ERROR");
        printlnWithColor("Loading Error Page\n", .{}, "#FF3029", "ERROR");
        renderErrorPage(route);
        return;
    };
    render_page = old_route.page;
    const old_ctx = current_ctx;
    // Create new context
    const new_ctx: *UIContext = allocator_global.create(UIContext) catch {
        println("Failed to allocate UIContext\n", .{});
        return;
    };

    UIContext.initLayout(new_ctx, &allocator_global, browser_width, browser_height) catch |err| {
        println("Allocator ran out of space {any}\n", .{err});
        new_ctx.deinit();
        allocator_global.destroy(new_ctx);
        return;
    };

    current_ctx = new_ctx;
    var route_itr = std.mem.tokenizeScalar(u8, route, '/');
    var count: usize = 0;
    while (route_itr.next()) |_| {
        count += 1;
    }
    route_segments = allocator_global.alloc([]const u8, count) catch return;
    count = 0;
    route_itr.reset();
    while (route_itr.next()) |route_token| {
        route_segments[count] = route_token;
        count += 1;
    }

    current_path = "";
    callNestedLayouts();
    // var layout_page: ?*const fn (*const fn () void) void = null;
    // while (layout_itr.next()) |entry| {
    //     const path = entry.key_ptr.*;
    //     if (std.ascii.startsWithIgnoreCase(route, path)) {
    //         layout_page = entry.value_ptr.*;
    //     }
    // }
    //
    // // Render the page with the new context
    // if (layout_page) |lp| {
    //     @call(.auto, lp, .{render_page});
    // } else {
    //     @call(.auto, render_page, .{});
    // }
    endPage(new_ctx);

    // Reconcile between old and new
    Reconciler.reconcile(old_ctx, new_ctx, route);

    // Replace old context with new context in the map
    clean_up_ctx = old_ctx;
    _ = router.addRoute(route, new_ctx, render_page) catch {
        printlnSrcErr("Failed to update context map\n", .{}, @src());
        new_ctx.deinit();
        allocator_global.destroy(new_ctx);
        return;
    };

    allocator_global.free(route); // return host‑allocated buffer
    // Clean up the old context
}

fn renderErrorPage(route: []const u8) void {
    const local_allocator = std.heap.wasm_allocator;
    // Get the old context for current route
    const error_specific_route = std.fmt.allocPrint(local_allocator, "{s}/error", .{route}) catch return;
    defer local_allocator.free(error_specific_route);
    const old_route = router.searchRoute(error_specific_route) orelse blk: {
        printlnWithColor("No Route Error Page Found\n", .{}, "#FF3029", "ERROR");
        const default_error = router.searchRoute("/error") orelse {
            printlnWithColor("No Default Error Page Found\n", .{}, "#FF3029", "ERROR");
            serious_error = true;
            return;
        };
        break :blk default_error;
    };
    render_page = old_route.page;
    const old_ctx = current_ctx;

    // Create new context
    const new_ctx: *UIContext = allocator_global.create(UIContext) catch {
        println("Failed to allocate UIContext\n", .{});
        return;
    };

    UIContext.initLayout(new_ctx, &allocator_global, browser_width, browser_height) catch |err| {
        println("Allocator ran out of space {any}\n", .{err});
        new_ctx.deinit();
        allocator_global.destroy(new_ctx);
        return;
    };
    // Render the page with the new context
    current_ctx = new_ctx;
    @call(.auto, render_page, .{});
    endPage(new_ctx);

    // Reconcile between old and new
    Reconciler.reconcile(old_ctx, new_ctx, route);

    // Replace old context with new context in the map
    clean_up_ctx = old_ctx;

    _ = router.addRoute(route, new_ctx, render_page) catch {
        printlnSrcErr("Failed to update context map\n", .{}, @src());
        new_ctx.deinit();
        allocator_global.destroy(new_ctx);
        return;
    };

    allocator_global.free(route); // return host‑allocated buffer
}

export fn cleanUp() void {
    clean_up_ctx.deinit();
    allocator_global.destroy(clean_up_ctx);
    clean_up_ctx = undefined;
}

pub fn createPage(style: Style, path: []const u8, page: fn () void, page_deinit: ?fn () void) !void {
    const path_ctx: *UIContext = try allocator_global.create(UIContext);
    // Initial render
    UIContext.initLayout(path_ctx, &allocator_global, browser_width, browser_height) catch |err| {
        println("Allocator ran out of space {any}\n", .{err});
        return;
    };

    current_ctx = path_ctx;
    path_ctx.stack.?.ptr.?.style = style;
    router.addRoute(path, path_ctx, page) catch |err| {
        println("Could not put route {any}\n", .{err});
    };
    if (page_deinit) |de| {
        page_deinit_map.put(path, de) catch |err| {
            println("Could not put route {any}\n", .{err});
        };
    }
    return;
}

pub fn endPage(path_ctx: *UIContext) void {
    path_ctx.endLayout();
    path_ctx.traverse();
}

pub fn endLayout(_: *Fabric) void {
    // Close tags fits all the widths
    // depth first insert when inserting nodes into the tree and onto the stack
    // then close function does breadth first post order
    // since we are going back up the tree
    // growing element breadth first insert when inserting nodes into the tree and onto the stack
    current_ctx.growElementsWidths();
    current_ctx.fitHeights();
    current_ctx.growElementsHeights();
    current_ctx.endLayout();
    current_ctx.traverse();
}

pub fn end(fabric: *Fabric) !void {
    const watch_paths: []const []const u8 = &.{"src/routes"};
    for (watch_paths) |watch_path| {
        var dir = try std.fs.cwd().openDir(watch_path, .{ .iterate = true });
        defer dir.close();

        var walker = try dir.walk(fabric.allocator.*);
        defer walker.deinit();

        while (try walker.next()) |entry| {
            const path = try std.fs.path.join(fabric.allocator.*, &.{ watch_path, entry.path });
            println("{s}\n", .{path});
        }
    }
}

// Okay so we need to change the node in the tree depending on the page route
// for example we add the commads tree to the router tree
pub inline fn DynamicPage(src: std.builtin.SourceLocation, page: fn () void, page_deinit: ?fn () void, style: Style) void {
    const allocator = std.heap.page_allocator;
    const full_route = src.file;
    var itr = std.mem.tokenizeScalar(u8, full_route[7..], '/');
    var buf = std.ArrayList(u8).init(allocator);
    blk: while (itr.next()) |sub| {
        if (itr.peek() == null) {
            break :blk;
        }
        buf.append('/') catch |err| {
            println("Allocator ran out of space {any}\n", .{err});
            return;
        };

        buf.appendSlice(sub) catch |err| {
            println("Allocator ran out of space {any}\n", .{err});
            return;
        };
    }

    if (buf.items.len == 0 and !std.mem.startsWith(u8, full_route, "Error")) {
        buf.appendSlice("/root") catch |err| {
            println("Allocator ran out of space {any}\n", .{err});
            return;
        };
    } else if (std.mem.startsWith(u8, full_route, "Error")) {
        buf.appendSlice("/error") catch |err| {
            println("Allocator ran out of space {any}\n", .{err});
            return;
        };
    }

    const route = buf.toOwnedSlice() catch |err| {
        println("Could not parse route {any}\n", .{err});
        return;
    };

    createPage(style, route, page, page_deinit) catch |err| {
        println("Could not add page {any}\n", .{err});
        return;
    };
}

// Okay so we need to change the node in the tree depending on the page route
// for example we add the commads tree to the router tree
pub inline fn Page(src: std.builtin.SourceLocation, page: fn () void, page_deinit: ?fn () void, style: Style) void {
    const allocator = std.heap.page_allocator;
    const full_route = src.file;
    var itr = std.mem.tokenizeScalar(u8, full_route[7..], '/');
    var buf = std.ArrayList(u8).init(allocator);
    var file_name: []const u8 = "";
    blk: while (itr.next()) |sub| {
        if (itr.peek() == null) {
            file_name = sub;
            break :blk;
        }
        buf.append('/') catch |err| {
            println("Allocator ran out of space {any}\n", .{err});
            return;
        };

        buf.appendSlice(sub) catch |err| {
            println("Allocator ran out of space {any}\n", .{err});
            return;
        };
    }

    if (buf.items.len == 0 and !std.mem.startsWith(u8, file_name, "Error")) {
        buf.appendSlice("/root") catch |err| {
            println("Allocator ran out of space {any}\n", .{err});
            return;
        };
    } else if (std.mem.startsWith(u8, file_name, "Error")) {
        buf.appendSlice("/error") catch |err| {
            println("Allocator ran out of space {any}\n", .{err});
            return;
        };
    }

    const route = buf.toOwnedSlice() catch |err| {
        println("Could not parse route {any}\n", .{err});
        return;
    };

    createPage(style, route, page, page_deinit) catch |err| {
        println("Could not add page {any}\n", .{err});
        return;
    };
}

pub inline fn Remember(src: std.builtin.SourceLocation) fn (void) void {
    const allocator = allocator_global;
    const full_route = src.file;
    var itr = std.mem.tokenizeScalar(u8, full_route[7..], '/');
    var buf = std.ArrayList(u8).init(allocator);

    const local = struct {
        fn CloseElement(_: void) void {
            _ = Fabric.current_ctx.close();
            return;
        }
        fn ConfigureElement(elem_decl: ElementDecl) *const fn (void) void {
            _ = Fabric.current_ctx.configure(elem_decl);
            return CloseElement;
        }
    };

    blk: while (itr.next()) |sub| {
        if (itr.peek() == null) {
            break :blk;
        }
        buf.appendSlice(sub) catch |err| {
            println("Allocator ran out of space {any}\n", .{err});
            unreachable;
        };
    }

    if (buf.items.len == 0 and !std.mem.startsWith(u8, full_route, "Error")) {
        buf.appendSlice("root") catch |err| {
            println("Allocator ran out of space {any}\n", .{err});
            unreachable;
        };
    } else if (std.mem.startsWith(u8, full_route, "Error")) {
        buf.appendSlice("/error") catch |err| {
            println("Allocator ran out of space {any}\n", .{err});
            unreachable;
        };
    }

    const route = buf.toOwnedSlice() catch |err| {
        println("Could not parse route {any}\n", .{err});
        unreachable;
    };

    const id = std.fmt.allocPrint(allocator, "layout-{s}", .{route}) catch |err| {
        Fabric.printlnSrcErr("{any}", .{err}, @src());
        unreachable;
    };

    var elem_decl = ElementDecl{
        .style = .{},
        .dynamic = .static,
        .elem_type = .Layout,
    };
    elem_decl.style.id = id;
    _ = Fabric.current_ctx.open(elem_decl) catch |err| {
        println("{any}\n", .{err});
    };
    _ = local.ConfigureElement(elem_decl);
    return local.CloseElement;
}

pub inline fn Layout(src: std.builtin.SourceLocation, style: Style) fn (void) void {
    const allocator = allocator_global;
    const full_route = src.file;
    var itr = std.mem.tokenizeScalar(u8, full_route[7..], '/');
    var buf = std.ArrayList(u8).init(allocator);

    const local = struct {
        fn CloseElement(_: void) void {
            _ = Fabric.current_ctx.close();
            return;
        }
        fn ConfigureElement(elem_decl: ElementDecl) *const fn (void) void {
            _ = Fabric.current_ctx.configure(elem_decl);
            return CloseElement;
        }
    };

    blk: while (itr.next()) |sub| {
        if (itr.peek() == null) {
            break :blk;
        }
        buf.appendSlice(sub) catch |err| {
            println("Allocator ran out of space {any}\n", .{err});
            unreachable;
        };
    }

    if (buf.items.len == 0 and !std.mem.startsWith(u8, full_route, "Error")) {
        buf.appendSlice("root") catch |err| {
            println("Allocator ran out of space {any}\n", .{err});
            unreachable;
        };
    } else if (std.mem.startsWith(u8, full_route, "Error")) {
        buf.appendSlice("/error") catch |err| {
            println("Allocator ran out of space {any}\n", .{err});
            unreachable;
        };
    }

    const route = buf.toOwnedSlice() catch |err| {
        println("Could not parse route {any}\n", .{err});
        unreachable;
    };

    const id = std.fmt.allocPrint(allocator, "layout-{s}", .{route}) catch |err| {
        Fabric.printlnSrcErr("{any}", .{err}, @src());
        unreachable;
    };

    var elem_decl = ElementDecl{
        .style = style,
        .dynamic = .static,
        .elem_type = .Layout,
    };
    elem_decl.style.id = id;
    _ = Fabric.current_ctx.open(elem_decl) catch |err| {
        println("{any}\n", .{err});
    };
    _ = local.ConfigureElement(elem_decl);
    return local.CloseElement;
}

pub fn registerLayout(path: []const u8, layout: fn (*const fn () void) void) void {
    layout_map.put(path, layout) catch |err| {
        printlnSrcErr("Could not add layout to registry {}", .{err}, @src());
    };
}

export fn eventCallback(id: u32) void {
    const func = events_callbacks.get(id).?;
    var event = Event{
        .id = id,
    };
    @call(.auto, func, .{&event});
}

export fn eventInstCallback(id: u32) void {
    const evt_node = events_inst_callbacks.get(id).?;
    var event = Event{
        .id = id,
    };
    @call(.auto, evt_node.data.evt_cb, .{ &evt_node.data, &event });
}

export fn hookInstCallback(id: u32) void {
    const hook_node = hooks_inst_callbacks.get(id).?;
    @call(.auto, hook_node.data.hook_cb, .{&hook_node.data});
}

pub const HooksFuncs = struct {
    created: ?*const fn () void = null,
    mounted: ?*const fn () void = null,
    destroy: ?*const fn () void = null,
    updated: ?*const fn () void = null,
};

pub const HooksCtxFuncs = enum { mounted };

extern fn createEventListener(event_ptr: [*]const u8, event_type_len: usize, cb_id: u32) void;
extern fn createElementEventListener(element_ptr: [*]const u8, element_len: usize, event_ptr: [*]const u8, event_type_len: usize, cb_id: u32) void;
extern fn createElementEventInstListener(element_ptr: [*]const u8, element_len: usize, event_ptr: [*]const u8, event_type_len: usize, cb_id: u32) void;
extern fn removeElementEventListener(element_ptr: [*]const u8, element_len: usize, event_ptr: [*]const u8, event_type_len: usize, cb_id: u32) void;
extern fn elementFocus(element_ptr: [*]const u8, element_len: usize) void;

/// This function creates an eventListener on the element.
/// Takes a callback function to be called when an event is received;
/// # Parameters:
/// - `element_id`: []const u8,
/// - `event_type`: *EventType,
/// - `cb`: *const fn (event: *Event) void,
///
/// # Returns:
/// !void
pub inline fn destroyElementEventListener(
    element_uuid: []const u8,
    event_type: types.EventType,
    cb_id: usize,
) ?bool {
    const event_type_str = std.enums.tagName(types.EventType, event_type) orelse return null;
    removeElementEventListener(element_uuid.ptr, element_uuid.len, event_type_str.ptr, event_type_str.len, cb_id);
    Fabric.printlnSrc("Callback id {}", .{cb_id}, @src());
    if (events_callbacks.remove(cb_id)) {
        return true;
    }
    return false;
}

/// This function creates an eventListener on the element.
/// Takes a callback function to be called when an event is received;
/// # Parameters:
/// - `element_id`: []const u8,
/// - `event_type`: *EventType,
/// - `cb`: *const fn (event: *Event) void,
///
/// # Returns:
/// !void
pub inline fn destroyElementInstEventListener(
    element_uuid: []const u8,
    event_type: types.EventType,
    cb_id: usize,
) ?bool {
    const event_type_str = std.enums.tagName(types.EventType, event_type) orelse return null;
    removeElementEventListener(element_uuid.ptr, element_uuid.len, event_type_str.ptr, event_type_str.len, cb_id);
    if (events_inst_callbacks.remove(cb_id)) {
        return true;
    }
    return false;
}

/// This function creates an focuses on the element.
/// # Parameters:
/// - `element_id`: []const u8,
///
/// # Returns:
/// void
pub inline fn focus(element_uuid: []const u8) void {
    elementFocus(element_uuid.ptr, element_uuid.len);
}

/// This function creates an eventListener on the element.
/// Takes a callback function to be called when an event is received;
/// # Parameters:
/// - `element_id`: []const u8,
/// - `event_type`: *EventType,
/// - `cb`: *const fn (event: *Event) void,
///
/// # Returns:
/// !void
pub inline fn elementEventListener(
    element_uuid: []const u8,
    event_type: types.EventType,
    cb: *const fn (event: *Event) void,
) ?usize {
    const id = events_callbacks.count() + 1;
    events_callbacks.put(id, cb) catch |err| {
        println("Event Callback Error: {any}\n", .{err});
    };

    const event_type_str = std.enums.tagName(types.EventType, event_type) orelse return null;
    createElementEventListener(element_uuid.ptr, element_uuid.len, event_type_str.ptr, event_type_str.len, id);
    return id;
}

pub const EvtInst = struct {
    evt_cb: EvtInstProto,
    deinit: EvtInstNodeProto,
};

pub const EvtInstProto = *const fn (*EvtInst, *Event) void;
pub const EvtInstNodeProto = *const fn (*EvtInstNode) void;

pub const EvtInstNode = struct { data: EvtInst };

/// cb(Self, *Fabric.Event)
pub inline fn elementInstEventListener(
    element_uuid: []const u8,
    event_type: types.EventType,
    self: anytype,
    cb: anytype,
) ?usize {
    const Self = @TypeOf(self);
    const EvtClosure = struct {
        self: Self,
        evt_node: EvtInstNode = .{ .data = .{ .evt_cb = runFn, .deinit = deinitFn } },

        fn runFn(evt_inst: *EvtInst, evt: *Event) void {
            const evt_node: *EvtInstNode = @fieldParentPtr("data", evt_inst);
            const closure: *@This() = @alignCast(@fieldParentPtr("evt_node", evt_node));
            @call(.auto, cb, .{ closure.self, evt });
        }
        fn deinitFn(evt_node: *EvtInstNode) void {
            const closure: *@This() = @alignCast(@fieldParentPtr("evt_node", evt_node));
            Fabric.allocator_global.destroy(closure);
        }
    };

    const evt_closure = Fabric.allocator_global.create(EvtClosure) catch |err| {
        println("Error could not create closure {any}\n ", .{err});
        unreachable;
    };
    evt_closure.* = .{
        .self = self,
    };

    const id = events_inst_callbacks.count();
    events_inst_callbacks.put(id, &evt_closure.evt_node) catch |err| {
        println("Event Callback Error: {any}\n", .{err});
    };

    const event_type_str = std.enums.tagName(types.EventType, event_type) orelse return null;
    createElementEventInstListener(element_uuid.ptr, element_uuid.len, event_type_str.ptr, event_type_str.len, id);
    return id;
}

pub const HookInst = struct {
    hook_cb: HookInstProto,
    deinit: HookInstNodeProto,
};

pub const HookInstProto = *const fn (*HookInst) void;
pub const HookInstNodeProto = *const fn (*HookInstNode) void;

pub const HookInstNode = struct { data: HookInst };

extern fn createHookWASM(urlPtr: [*]const u8, urlLen: usize, cb_id: u32) void;
/// cb(Self)
pub inline fn createHook(
    self: anytype,
    cb: anytype,
    url: []const u8,
) ?usize {
    const Self = @TypeOf(self);
    const HookClosure = struct {
        self: Self,
        hook_node: HookInstNode = .{ .data = .{ .hook_cb = runFn, .deinit = deinitFn } },

        fn runFn(hook_inst: *HookInst) void {
            const hook_node: *HookInstNode = @fieldParentPtr("data", hook_inst);
            const closure: *@This() = @alignCast(@fieldParentPtr("hook_node", hook_node));
            @call(.auto, cb, .{closure.self});
        }
        fn deinitFn(hook_node: *HookInstNode) void {
            const closure: *@This() = @alignCast(@fieldParentPtr("hook_node", hook_node));
            Fabric.allocator_global.destroy(closure);
        }
    };

    const hook_closure = Fabric.allocator_global.create(HookClosure) catch |err| {
        println("Error could not create closure {any}\n ", .{err});
        unreachable;
    };
    hook_closure.* = .{
        .self = self,
    };

    const id = hooks_inst_callbacks.count();
    hooks_inst_callbacks.put(id, &hook_closure.hook_node) catch |err| {
        println("Event Callback Error: {any}\n", .{err});
    };

    createHookWASM(url.ptr, url.len, id);
    return id;
}

/// This function creates an eventListener on the document.
/// Takes a callback function to be called when an event is received;
/// # Parameters:
/// - `event_type`: *EventType,
/// - `cb`: *const fn (event: *Event) void,
///
/// # Returns:
/// !void
pub inline fn eventListener(
    event_type: types.EventType,
    cb: *const fn (event: *Event) void,
) void {
    const id = events_callbacks.count() + 1;
    events_callbacks.put(id, cb) catch |err| {
        println("Event Callback Error: {any}\n", .{err});
    };

    const event_type_str: []const u8 = std.enums.tagName(types.EventType, event_type) orelse return;
    createEventListener(event_type_str.ptr, event_type_str.len, id);
    return;
}

pub export fn getRenderTreePtr() ?*UIContext.CommandsTree {
    if (serious_error) {
        serious_error = false;
        return null;
    }
    const tree_op = current_ctx.ui_tree;

    if (tree_op != null) {
        // iterateTreeChildren(current_ctx.ui_tree.?);
        return current_ctx.ui_tree.?;
    }
    return null;
}

pub export fn getRenderCommandPtr(tree: *CommandsTree) [*]u8 {
    return @ptrCast(tree.node);
}

export fn getTreeNodeChildrenCount(tree: *CommandsTree) usize {
    return tree.children.items.len;
}

export fn getUiNodeChildrenCount(tree: *CommandsTree) usize {
    return tree.node.node_ptr.children.items.len;
}

export fn getTreeNodeChild(tree: *CommandsTree, index: usize) *CommandsTree {
    const child = tree.children.items[index];
    return child;
}

export fn getCtxNodeChild(tree: *CommandsTree, index: usize) ?*CommandsTree {
    const ui_node = tree.node.node_ptr.children.items[index];
    for (tree.children.items, 0..) |item, i| {
        if (std.mem.eql(u8, ui_node.uuid, item.node.id)) {
            return tree.children.items[i];
        }
    }
    return null;
}

export fn getTreeNodeChildCommand(tree: *CommandsTree) *RenderCommand {
    return tree.node;
}

export fn setDirtyToFalse(node: *UINode) void {
    node.dirty = false;
}

export fn getDirtyValue(node: *UINode) bool {
    return node.dirty;
}

// The first node needs to be marked as false always
pub fn markChildrenDirty(node: *UINode) void {
    if (node.parent != null) {
        node.dirty = true;
    }
    for (node.children.items) |child| {
        markChildrenDirty(child);
    }
}
// The first node needs to be marked as false always
export fn markCurrentTreeDirty() void {
    markChildrenDirty(current_ctx.root.?);
}

export fn markUINodeTreeDirty(node: *UINode) void {
    markChildrenDirty(node);
}

// The first node needs to be marked as false always
export fn markCurrentTreeNotDirty() void {
    markChildrenNotDirty(current_ctx.root.?);
}

// The first node needs to be marked as false always
pub fn markChildrenNotDirty(node: *UINode) void {
    if (node.parent != null) {
        node.dirty = false;
    }
    for (node.children.items) |child| {
        markChildrenNotDirty(child);
    }
}

// The first node needs to be marked as false always
fn markNonLayoutChildrenDirtyAndAddToRemoveList(node: *UINode, layout_path: []const u8) usize {
    if (node.type == .Layout and std.ascii.startsWithIgnoreCase(layout_path, node.uuid)) {
        node.dirty = false;
        markChildrenNotDirty(node);
        return 0;
    } else {
        if (node.parent != null) {
            removed_nodes.append(node.uuid) catch {};
        }
        // node.dirty = true;
        node.dirty = false;
        for (node.children.items) |child| {
            _ = markNonLayoutChildrenDirtyAndAddToRemoveList(child, layout_path);
        }
    }
    return removed_nodes.items.len;
}

// The first node needs to be marked as false always
fn markNonLayoutChildrenDirty(node: *UINode, layout_path: []const u8) void {
    if (node.type == .Layout and std.ascii.startsWithIgnoreCase(node.uuid, layout_path)) {
        node.dirty = false;
        markChildrenNotDirty(node);
        return;
    } else {
        node.dirty = true;
        for (node.children.items) |child| {
            _ = markNonLayoutChildrenDirty(child, layout_path);
        }
    }
}

export fn getRemovedNode(index: usize) [*]const u8 {
    return removed_nodes.items[index].ptr;
}

export fn getRemovedNodeLength(index: usize) usize {
    return removed_nodes.items[index].len;
}

export fn markAllNonLayoutNodesDirty() void {
    const route = Fabric.getWindowPath();
    var itr = std.mem.tokenizeScalar(u8, route, '/');
    var buf = std.ArrayList(u8).init(Fabric.allocator_global);
    blk: while (itr.next()) |sub| {
        if (itr.peek() == null) {
            break :blk;
        }

        buf.appendSlice(sub) catch |err| {
            Fabric.printlnSrcErr("Allocator ran out of space {any}\n", .{err}, @src());
            return;
        };
    }
    if (buf.items.len == 0) {
        buf.appendSlice("root") catch |err| {
            println("Allocator ran out of space {any}\n", .{err});
            unreachable;
        };
    }

    const parent_path = buf.toOwnedSlice() catch return;
    const layout_path = std.fmt.allocPrint(Fabric.allocator_global, "layout-{s}", .{parent_path}) catch return;
    markNonLayoutChildrenDirty(current_ctx.root.?, layout_path);
}

export fn markAllNonLayoutNodesDirtyRemoveList() usize {
    const route = Fabric.getWindowPath();
    var itr = std.mem.tokenizeScalar(u8, route, '/');
    var buf = std.ArrayList(u8).init(Fabric.allocator_global);
    blk: while (itr.next()) |sub| {
        if (itr.peek() == null) {
            break :blk;
        }

        buf.appendSlice(sub) catch |err| {
            Fabric.printlnSrcErr("Allocator ran out of space {any}\n", .{err}, @src());
            return 0;
        };
    }
    if (buf.items.len == 0) {
        buf.appendSlice("root") catch |err| {
            println("Allocator ran out of space {any}\n", .{err});
            unreachable;
        };
    }

    const parent_path = buf.toOwnedSlice() catch return 0;
    const layout_path = std.fmt.allocPrint(Fabric.allocator_global, "layout-{s}", .{parent_path}) catch return 0;
    removed_nodes.clearRetainingCapacity();
    return markNonLayoutChildrenDirtyAndAddToRemoveList(current_ctx.root.?, layout_path);
}

fn iterateChildren(node: *UINode) void {
    if (node.dirty) {
        println("{any}\n", .{node.dirty});
    } else {
        println("Layout: node {any}\n", .{node.dirty});
    }
    for (node.children.items) |child| {
        iterateChildren(child);
    }
}

pub fn iterateTreeChildren(tree: *CommandsTree) void {
    for (tree.children.items) |child| {
        iterateTreeChildren(child);
    }
}

var depth: usize = 0;
fn createUUIDS(node: *UINode) void {
    depth += 1;
    KeyGenerator.resetCounter();
    for (node.children.items) |child| {
        const index: usize = depth;
        if (child.uuid.len > 0) continue;
        const key = KeyGenerator.generateKey(
            child.type,
            node.uuid,
            node.style,
            index,
            node,
            &allocator_global,
        );
        child.uuid = key;
        // we add this so that animations are sepeate, we need to be careful though since
        // if a user does not specifc a id for a class, and the  rerender tree has the same id
        // and then previous one uses an animation then that transistion and animation will be
        // applied to the new node since it has the same class name and styling
    }
    for (node.children.items) |child| {
        createUUIDS(child);
    }
    depth -= 1;
}

/// Calling route renderCycle will mark eveything as dirty
export fn callRouteRenderCycle(ptr: [*:0]u8) void {
    const route: []const u8 = std.mem.span(ptr);
    renderCycle(route);
    markChildrenDirty(current_ctx.root.?);
    return;
}
export fn setRouteRenderTree(ptr: [*:0]u8) void {
    const route: []const u8 = std.mem.span(ptr);
    defer allocator_global.free(route);
    renderCycle(route);
    return;
}

export fn allocUint8(length: u32) [*]const u8 {
    const slice = allocator_global.alloc(u8, length) catch
        @panic("failed to allocate memory");
    return slice.ptr;
}

pub fn findNodeByUUID(ui_node: *UINode, uuid: []const u8) ?*UINode {
    for (ui_node.children.items) |node| {
        if (std.mem.eql(u8, node.uuid, uuid)) {
            return node;
        }
        return findNodeByUUID(ui_node, uuid);
    }
    return null;
}

// Export memory layout information for JavaScript to correctly read the struct
// Export function to get a pointer to the memory layout information
var layout_info = struct {
    render_command_size: u32,
    bounding_box_offset: u32,
    elem_type_offset: u32,
    text_ptr_offset: u32,
    text_len_offset: u32,
    href_ptr_offset: u32,
    href_len_offset: u32,
    style_offset: u32,
    style_size: u32,
    p__btn_id_offset: u32,
    p__dialog_id_offset: u32,
    p__dialog_len_offset: u32,
    id_ptr_offset: u32,
    id_len_offset: u32,
    show: u32,
    hooks: u32,
    node_ptr_offset: u32,
    p__hover_offset: u32,
    p__hover_size: u32,
    exit_animation: u32,
    exit_animation_len: u32,
    classname: u32,
    classname_len: u32,
    p__focus_offset: u32,
    p__focus_size: u32,
    p__focus_within_offset: u32,
    p__focus_within_size: u32,
}{
    .render_command_size = @sizeOf(RenderCommand),
    .bounding_box_offset = @offsetOf(RenderCommand, "bounding_box"),
    .elem_type_offset = @offsetOf(RenderCommand, "elem_type"),
    .text_ptr_offset = @offsetOf(RenderCommand, "text"),
    .text_len_offset = @offsetOf(RenderCommand, "text") + @sizeOf(usize),
    .href_ptr_offset = @offsetOf(RenderCommand, "href"),
    .href_len_offset = @offsetOf(RenderCommand, "href") + @sizeOf(usize),
    .style_offset = @offsetOf(RenderCommand, "style"),
    .style_size = @sizeOf(Style),
    .p__btn_id_offset = @offsetOf(Style, "btn_id"),
    .p__dialog_id_offset = @offsetOf(Style, "dialog_id"),
    .p__dialog_len_offset = @offsetOf(Style, "dialog_id") + @sizeOf(usize),
    .id_ptr_offset = @offsetOf(RenderCommand, "id"),
    .id_len_offset = @offsetOf(RenderCommand, "id") + @sizeOf(usize),
    .show = @offsetOf(RenderCommand, "show"),
    .hooks = @offsetOf(RenderCommand, "hooks"),
    .node_ptr_offset = @offsetOf(RenderCommand, "node_ptr"),
    .p__hover_offset = @offsetOf(RenderCommand, "hover"),
    .p__hover_size = @sizeOf(Hover),
    .exit_animation = @offsetOf(Style, "exit_animation"),
    .exit_animation_len = @offsetOf(Style, "exit_animation") + @sizeOf(usize),
    .classname = @offsetOf(Style, "style_id"),
    .classname_len = @offsetOf(Style, "style_id") + @sizeOf(usize),
    .p__focus_offset = @offsetOf(RenderCommand, "focus"),
    .p__focus_size = @sizeOf(Focus),
    .p__focus_within_offset = @offsetOf(RenderCommand, "focus_within"),
    .p__focus_within_size = @sizeOf(Focus),
};
pub export fn allocateLayoutInfo() *u8 {
    const info_ptr: *u8 = @ptrCast(&layout_info);
    return info_ptr;
}

export fn zigPrint() void {
    println("Zig Printing\n", .{});
}

// Export the size of a single RenderCommand for proper memory reading
export fn getRenderCommandSize() usize {
    return @sizeOf(types.RenderCommand);
}

pub fn printToConsoleTest(
    _: *Fabric,
    buf: []const u8,
) void {
    println(buf.ptr, buf.len);
}

pub fn transparentizeRGBA(rgba: [4]u8, alpha: u8) [4]u8 {
    var cmp_rgba: [4]u8 = undefined;
    cmp_rgba[0] = rgba[0];
    cmp_rgba[1] = rgba[1];
    cmp_rgba[2] = rgba[2];
    // Set alpha to 1.0
    cmp_rgba[3] = alpha;

    return cmp_rgba;
}

pub fn darkenRGBA(rgba: [4]u8, factor: u8) [4]u8 {
    var darkened_rgba: [4]u8 = undefined;
    // Multiply RGB components by factor (0.0 = black, 1.0 = original)
    darkened_rgba[0] = rgba[0] * factor;
    darkened_rgba[1] = rgba[1] * factor;
    darkened_rgba[2] = rgba[2] * factor;
    // Keep original alpha
    darkened_rgba[3] = rgba[3];
    return darkened_rgba;
}

pub fn transparentize(hex_str: []const u8, alpha: u8) [4]u8 {
    var rgba: [4]u8 = undefined;
    // rgba = allocator.alloc(u8, 4) catch return .{ 0, 0, 0, 255 };

    // Parse red component
    const r = std.fmt.parseInt(u8, hex_str[1..3], 16) catch return .{ 0, 0, 0, 255 };
    rgba[0] = r;

    // Parse green component
    const g = std.fmt.parseInt(u8, hex_str[3..5], 16) catch return .{ 0, 0, 0, 255 };
    rgba[1] = g;

    // Parse blue component
    const b = std.fmt.parseInt(u8, hex_str[5..7], 16) catch return .{ 0, 0, 0, 255 };
    rgba[2] = b;

    // Set alpha to 1.0
    rgba[3] = alpha;

    return rgba;
}
// Make sure this function is not evaluated at compile time
pub fn hexToRgba(hex_str: []const u8) [4]u8 {
    if (hex_str.len < 7 or hex_str[0] != '#') return .{ 0, 0, 0, 255 };

    // Parse at runtime instead of compile-time
    var r: u8 = 0;
    var g: u8 = 0;
    var b: u8 = 0;

    // Manual hex parsing to avoid compile-time evaluation issues
    r = parseHexByte(hex_str[1..3]) catch 0;
    g = parseHexByte(hex_str[3..5]) catch 0;
    b = parseHexByte(hex_str[5..7]) catch 0;

    return .{ r, g, b, 255 };
}

fn parseHexByte(hex: []const u8) !u8 {
    if (hex.len != 2) return error.InvalidLength;

    const high = try charToHex(hex[0]);
    const low = try charToHex(hex[1]);

    return (high << 4) | low;
}

fn charToHex(c: u8) !u8 {
    return switch (c) {
        '0'...'9' => c - '0',
        'a'...'f' => c - 'a' + 10,
        'A'...'F' => c - 'A' + 10,
        else => error.InvalidCharacter,
    };
}

pub fn fmtln(
    comptime fmt: []const u8,
    args: anytype,
) []const u8 {
    const buf = std.fmt.allocPrint(allocator_global, fmt, args) catch |err| {
        println("Formatting, Error Could not format argument alloc Error details: {any}\n", .{err});
        return "";
    };
    return buf;
}

pub fn printlnSrcErr(
    comptime fmt: []const u8,
    args: anytype,
    src: std.builtin.SourceLocation,
) void {
    const buf = std.fmt.allocPrint(allocator_global, fmt, args) catch return;
    const buf_with_src = std.fmt.allocPrint(allocator_global, "[Fabric] [%c{s}:{d}%c]\n[Fabric] [ERROR] {s}", .{ src.file, src.line, buf[0..] }) catch return;
    const style_1 = "color: #FF3029;";
    const style_2 = "";
    _ = consoleLogColored(buf_with_src.ptr, buf_with_src.len, style_1[0..].ptr, style_1.len, style_2[0..].ptr, style_2.len);
    allocator_global.free(buf_with_src);
    allocator_global.free(buf);
}

pub extern fn trackAlloc() void;

pub fn printlnWithColor(
    comptime fmt: []const u8,
    args: anytype,
    color: []const u8,
    title: []const u8,
) void {
    const buf = std.fmt.allocPrint(allocator_global, fmt, args) catch return;
    const color_buf = std.fmt.allocPrint(allocator_global, "color: {s};", .{color}) catch return;
    const buf_with_src = std.fmt.allocPrint(allocator_global, "[Fabric] [%c{s}%c] {s}", .{ title, buf[0..] }) catch return;
    const style_2 = "";
    _ = consoleLogColored(buf_with_src.ptr, buf_with_src.len, color_buf[0..].ptr, color_buf.len, style_2[0..].ptr, style_2.len);
    allocator_global.free(buf_with_src);
    allocator_global.free(buf);
}

pub fn printlnAllocation(
    comptime fmt: []const u8,
    args: anytype,
) void {
    const buf = std.fmt.allocPrint(allocator_global, fmt, args) catch return;
    const buf_with_src = std.fmt.allocPrint(allocator_global, "[Fabric] [%cALLOC%c] {s}", .{buf[0..]}) catch return;
    const style_1 = "color: #744EFF;";
    const style_2 = "";
    _ = consoleLogColored(buf_with_src.ptr, buf_with_src.len, style_1[0..].ptr, style_1.len, style_2[0..].ptr, style_2.len);
    allocator_global.free(buf_with_src);
    allocator_global.free(buf);
}

pub fn printlnSrc(
    comptime fmt: []const u8,
    args: anytype,
    src: std.builtin.SourceLocation,
) void {
    const buf = std.fmt.allocPrint(allocator_global, fmt, args) catch return;
    const buf_with_src = std.fmt.allocPrint(allocator_global, "[Fabric] [%c{s}:{d}%c]\n[Fabric] [MSG] {s}", .{ src.file, src.line, buf[0..] }) catch return;
    const style_1 = "color: #3CE98A;";
    const style_2 = "";
    _ = consoleLogColored(buf_with_src.ptr, buf_with_src.len, style_1[0..].ptr, style_1.len, style_2[0..].ptr, style_2.len);
    allocator_global.free(buf_with_src);
    allocator_global.free(buf);
}

pub fn println(
    comptime fmt: []const u8,
    args: anytype,
) void {
    const buf = std.fmt.allocPrint(allocator_global, fmt, args) catch return;
    _ = consoleLog(buf.ptr, buf.len);
    allocator_global.free(buf);
}

extern fn consoleLog(ptr: [*]const u8, len: usize) i32;
extern fn consoleLogColored(ptr: [*]const u8, len: usize, style_ptr_1: [*]const u8, style_len_1: u32, style_ptr_2: [*]const u8, style_len_2: u32) i32;

export fn grainRerender() bool {
    return grain_rerender;
}

export fn resetGrainRerender() void {
    grain_rerender = false;
}

export fn shouldRerender() bool {
    return global_rerender;
}

export fn resetRerender() void {
    global_rerender = false;
    rerender_everything = false;
}

export fn setRerenderTrue() void {
    cycle();
}

pub extern fn mutateDomElementWasm(
    id_ptr: [*]const u8,
    id_len: usize,
    attribute: [*]const u8,
    attribute_len: usize,
    value: u32,
) void;

pub extern fn mutateDomElementStyleWasm(
    id_ptr: [*]const u8,
    id_len: usize,
    attribute: [*]const u8,
    attribute_len: usize,
    value: f32,
) void;

pub extern fn mutateDomElementStyleStringWasm(
    id_ptr: [*]const u8,
    id_len: usize,
    attribute: [*]const u8,
    attribute_len: usize,
    value_ptr: [*]const u8,
    value_len: usize,
) void;

// Wrapper functions with dummy implementations for non-WASM targets

pub fn mutateDomElement(
    id_ptr: [*]const u8,
    id_len: usize,
    attribute: [*]const u8,
    attribute_len: usize,
    value: u32,
) void {
    if (isWasi) {
        mutateDomElementWasm(id_ptr, id_len, attribute, attribute_len, value);
    } else {
        // Dummy implementation - log the action if needed
        if (comptime std.debug.runtime_safety) {
            const id = id_ptr[0..id_len];
            const attr = attribute[0..attribute_len];
            std.debug.print("DOM: Would set element '{s}' attribute '{s}' to {d}\n", .{ id, attr, value });
        }
        // No-op in non-WASM environments
    }
}

pub fn mutateDomElementStyle(
    id_ptr: [*]const u8,
    id_len: usize,
    attribute: [*]const u8,
    attribute_len: usize,
    value: f32,
) void {
    if (isWasi) {
        mutateDomElementStyleWasm(id_ptr, id_len, attribute, attribute_len, value);
    } else {
        // Dummy implementation - log the action if needed
        if (comptime std.debug.runtime_safety) {
            const id = id_ptr[0..id_len];
            const attr = attribute[0..attribute_len];
            std.debug.print("DOM: Would set element '{s}' style '{s}' to {d:.2}\n", .{ id, attr, value });
        }
        // No-op in non-WASM environments
    }
}

pub fn mutateDomElementStyleString(
    id_ptr: [*]const u8,
    id_len: usize,
    attribute: [*]const u8,
    attribute_len: usize,
    value_ptr: [*]const u8,
    value_len: usize,
) void {
    if (isWasi) {
        mutateDomElementStyleStringWasm(id_ptr, id_len, attribute, attribute_len, value_ptr, value_len);
    } else {
        // Dummy implementation - log the action if needed
        if (comptime std.debug.runtime_safety) {
            const id = id_ptr[0..id_len];
            const attr = attribute[0..attribute_len];
            const value = value_ptr[0..value_len];
            std.debug.print("DOM: Would set element '{s}' style '{s}' to '{s}'\n", .{ id, attr, value });
        }
        // No-op in non-WASM environments
    }
}

// pub extern fn removeFromParent(
//     id_ptr: [*]const u8,
//     id_len: usize,
// ) void;
//
// pub extern fn addChild(
//     id_ptr: [*]const u8,
//     id_len: usize,
//     child_id_ptr: [*]const u8,
//     child_id_len: usize,
// ) void;

pub extern fn createClass(
    class_ptr: [*]const u8,
    class_len: usize,
) void;

pub fn addToClassesList(id: []const u8, style_id: []const u8) void {
    const clta = Class{ .element_id = id, .style_id = style_id };
    classes_to_add.append(clta) catch |err| {
        println("Could not add to class_list: {any}\n", .{err});
        return;
    };
}
//
pub fn addToRemoveClassesList(id: []const u8, style_id: []const u8) void {
    const cltr = Class{ .element_id = id, .style_id = style_id };
    classes_to_remove.append(cltr) catch |err| {
        println("Could not add to class_list: {any}\n", .{err});
        return;
    };
}

pub export fn pendingClassesToAdd() void {
    for (classes_to_add.items) |clta| {
        addClass(clta.element_id.ptr, clta.element_id.len, clta.style_id.ptr, clta.style_id.len);
    }
    classes_to_add.clearAndFree();
}
pub export fn pendingClassesToRemove() void {
    for (classes_to_remove.items) |cltr| {
        removeClass(cltr.element_id.ptr, cltr.element_id.len, cltr.style_id.ptr, cltr.style_id.len);
    }
    classes_to_remove.clearAndFree();
}

pub extern fn addClass(
    id_ptr: [*]const u8,
    id_len: usize,
    class_id_ptr: [*]const u8,
    class_id_len: usize,
) void;

pub extern fn removeClass(
    id_ptr: [*]const u8,
    id_len: usize,
    class_id_ptr: [*]const u8,
    class_id_len: usize,
) void;

pub extern fn closeDialog(
    id_ptr: [*]const u8,
    id_len: usize,
) void;

pub extern fn showDialog(
    id_ptr: [*]const u8,
    id_len: usize,
) void;

pub extern fn createElement(
    id_ptr: [*]const u8,
    id_len: usize,
    elem_type: u8,
    btn_id: u32,
    text_ptr: [*]const u8,
    text_len: usize,
) void;

pub extern fn callClickWASM(
    id_ptr: [*]const u8,
    id_len: usize,
) void;

pub fn loopInterval(name: []const u8, cb: anytype, args: anytype, delay: u32) void {
    const Args = @TypeOf(args);
    const Closure = struct {
        arguments: Args,
        run_node: Node = .{ .data = .{ .runFn = runFn, .deinitFn = deinitFn } },
        //
        fn runFn(action: *Action) void {
            const run_node: *Node = @fieldParentPtr("data", action);
            const closure: *@This() = @alignCast(@fieldParentPtr("run_node", run_node));
            @call(.auto, cb, closure.arguments);
        }
        //
        fn deinitFn(node: *Node) void {
            const closure: *@This() = @alignCast(@fieldParentPtr("run_node", node));
            allocator_global.destroy(closure);
        }
    };

    const closure = allocator_global.create(Closure) catch |err| {
        println("Error could not create closure {any}\n ", .{err});
        unreachable;
    };
    closure.* = .{
        .arguments = args,
    };

    callback_registry.put(name, &closure.run_node) catch |err| {
        println("Button Function Registry {any}\n", .{err});
    };

    if (isWasi) {
        createInterval(name.ptr, name.len, delay);
    } else {
        return;
    }
}

export fn timeOutCtxCallback(id_ptr: [*:0]u8) void {
    const id = std.mem.span(id_ptr);
    defer Fabric.allocator_global.free(id);
    const node = Fabric.callback_registry.get(id) orelse return;
    @call(.auto, node.data.runFn, .{&node.data});
}

export fn timeoutCtxCallBackId(id: usize) void {
    const node = Fabric.time_out_ctx_registry.get(id) orelse return;
    defer _ = Fabric.time_out_ctx_registry.remove(id);
    @call(.auto, node.data.runFn, .{&node.data});
}

// External JavaScript functions
extern "env" fn checkFutureResolved(futureId: u32) u32;
extern "env" fn getFutureValue(futureId: u32) bool;
extern "env" fn timeout(ms: u32, callbackId: u32) void;
extern "env" fn timeoutCtx(ms: u32, callbackId: u32) void;
// Zig side
extern "env" fn createPromise() u32;
extern "env" fn promiseTimeout(promiseId: u32, ms: u32) void;
extern "env" fn createInterval(name_ptr: [*]const u8, name_len: usize, delay: u32) void;

// Define our future state
const FutureState = enum(u8) {
    Pending,
    Resolved,
    Error,
};

// Structure to track async operations
const Future = struct {
    id: u32,
    state: FutureState,
    result: i32,
};

pub fn registerCtxTimeout(ms: u32, cb: anytype, args: anytype) void {
    const Args = @TypeOf(args);
    const Closure = struct {
        arguments: Args,
        run_node: Node = .{ .data = .{ .runFn = runFn, .deinitFn = deinitFn } },
        //
        fn runFn(action: *Action) void {
            const run_node: *Node = @fieldParentPtr("data", action);
            const closure: *@This() = @alignCast(@fieldParentPtr("run_node", run_node));
            @call(.auto, cb, closure.arguments);
        }
        //
        fn deinitFn(node: *Node) void {
            const closure: *@This() = @alignCast(@fieldParentPtr("run_node", node));
            allocator_global.destroy(closure);
        }
    };

    const closure = allocator_global.create(Closure) catch |err| {
        println("Error could not create closure {any}\n ", .{err});
        unreachable;
    };
    closure.* = .{
        .arguments = args,
    };

    const id = time_out_ctx_registry.count() + 1;
    time_out_ctx_registry.put(id, &closure.run_node) catch |err| {
        println("Button Function Registry {any}\n", .{err});
    };

    if (isWasi) {
        timeoutCtx(ms, id);
    } else {
        return;
    }
}

pub fn registerTimeout(ms: u32, cb: *const fn () void) void {
    const id = registry.count() + 1;
    registry.put(id, cb) catch |err| {
        println("Button Function Registry {any}\n", .{err});
    };
    if (isWasi) {
        timeout(ms, id);
    } else {
        return;
    }
}

extern fn setCookieWASM(cookie_ptr: [*]const u8, cookie_len: usize) void;

pub fn setCookie(cookie: []const u8) void {
    setCookieWASM(cookie.ptr, cookie.len);
}

pub fn getCookies() []const u8 {
    const cookie = getCookiesWASM();
    return std.mem.span(cookie);
}

pub fn getCookie(name: []const u8) ?[]const u8 {
    const cookie = getCookieWASM(name.ptr, name.len);
    if (cookie == null) return null;
    return std.mem.span(cookie);
}

extern fn getCookieWASM(name_ptr: [*]const u8, name_len: usize) ?[*:0]u8;
extern fn getCookiesWASM() [*:0]u8;

// This function gets called from JavaScript when a timeout completes
export fn resumeExecution(callbackId: u32) void {
    const continuation = continuations[callbackId];
    if (continuation) |func| {
        // Clear the slot
        continuations[callbackId] = null;
        // Call the continuation function
        func();
    }
}

pub fn createCallback(cb: *const fn () void) void {
    continuations[callback_count] = cb;
}

export fn callback(callbackId: u32) void {
    const continuation = continuations[callbackId];
    if (continuation) |cb| {
        @call(.auto, cb, .{});
    }
}

export fn allocate(size: usize) ?[*]f32 {
    const buf = allocator_global.alloc(f32, size) catch |err| {
        println("{any}\n", .{err});
        return null;
    };
    return buf.ptr;
}
//
extern fn copyText(ptr: [*]const u8, len: usize) void;

pub const Clipboard = struct {
    pub fn copy(text: []const u8) void {
        copyText(text.ptr, text.len);
    }
    fn paste(_: []const u8) void {}
};
