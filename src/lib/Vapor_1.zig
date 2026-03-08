const std = @import("std");
const builtin = @import("builtin");
pub var isGenerated = !isWasi;
pub const isWasi = builtin.target.cpu.arch == .wasm32;
pub const debug = builtin.mode == .Debug;
// We cant use bools since they get recompiled each time, hence we use the builtin target
const types = @import("types.zig");
const UIContext = @import("UITree.zig");
const PureTree = @import("PureTree.zig");
const UINode = @import("UITree.zig").UINode;
const CommandsTree = UIContext.CommandsTree;
const Rune = @import("Rune.zig");
const TransitionState = @import("Transition.zig").TransitionState;
const Router = @import("Router.zig");
pub const Element = @import("Element.zig").Element;
const KeyGenerator = @import("Key.zig").KeyGenerator;
const Reconciler = @import("Reconciler.zig");
const TrackingAllocator = @import("TrackingAllocator.zig");
pub const KeyStone = @import("keystone/KeyStone.zig");
pub const Wasm = @import("WASM.zig");
const getVisualStyle = @import("convertStyleCustomWriter.zig").getVisualStyle;
pub const Bridge = @import("Bridge.zig");
pub const Event = @import("Event.zig");
const CSSGenerator = @import("CSSGenerator.zig");
const hashKey = utils.hashKey;
const Pool = @import("Pool.zig");
const mutateDomElementStyleString = @import("Element.zig").mutateDomElementStyleString;
const HtmlGenerator = @import("HtmlGenerator.zig");
const mode_options = @import("build_options");
const Packer = @import("Packer.zig");
const ClassCache = @import("ClassCache.zig").ClassCache;
const DynamicObject = @import("Dynamic.zig").DynamicObject;
const StringTable = @import("StringTable.zig").StringTable;
const TextFieldTable = @import("TextFieldTable.zig").StringTable;
const Components = @import("NewComponent.zig");
const Accessibility = @import("Accessibility.zig");
const Polygons = @import("Polygon.zig").Polygons;
const StorageTable = @import("StorageTable.zig").StorageTable;
const Structures = @import("structures/Structures.zig");

const DebugLevel = enum(u8) { all = 0, debug = 1, info = 2, warn = 3, none = 4 };

pub var build_options = struct {
    enable_debug: bool = true,
    debug_level: DebugLevel = .none,
}{};

pub var Timer = struct {
    generation_time: f64 = 0,
    reconcile_time: f64 = 0,
    commit_time: f64 = 0,
    total_time: f64 = 0,
}{};
// const getFocusStyle = @import("convertFocus.zig").getFocusStyle;
// const getFocusWithinStyle = @import("convertFocusWithin.zig").getFocusWithinStyle;
const getStyle = @import("convertStyleCustomWriter.zig").getStyle;
const StyleCompiler = @import("convertStyleCustomWriter.zig");
const grabInputDetails = @import("grabInputDetails.zig");
const utils = @import("utils.zig");
// const createInput = grabInputDetails.createInput;
const getAriaLabel = utils.getAriaLabel;
pub const setGlobalStyleVariables = @import("convertStyleCustomWriter.zig").setGlobalStyleVariables;
const Debugger = @import("Debugger.zig");
const NodePool = @import("NodePool.zig");

pub const Component = fn (void) void;

pub const on_change_hash = "onChange";
pub const on_leave_hash = "onLeave";
pub const on_hover_hash = "onHover";
pub const on_submit_hash = "onSubmit";
pub const on_focus_hash = "onFocus";
pub const on_blur_hash = "onBlur";

const EventType = types.EventType;
const Active = types.Active;
pub const ElementDecl = types.ElementDeclaration;
const RenderCommand = types.RenderCommand;
pub const ElementType = types.ElementType;
const Hover = types.Hover;
const Focus = types.Focus;
pub var has_context: bool = false;
pub var current_ctx: *UIContext = undefined;
pub var pure_tree: PureTree = undefined;
pub var error_tree: PureTree = undefined;
pub var ctx_map: std.AutoHashMap(u32, *UIContext) = undefined;
pub var page_map: std.StringHashMap(void) = undefined;
const LayoutItem = struct {
    reset: bool = false,
    call_fn: *const fn (*const fn () void) void,
};
pub var layout_map: std.AutoHashMap(u32, LayoutItem) = undefined;
pub var page_deinit_map: std.AutoHashMap(u32, *const fn () void) = undefined;
pub var global_rerender: bool = false;
pub var has_dirty: bool = false;
pub var rerender_everything: bool = false;
pub var grain_rerender: bool = false;
pub var grain_element_uuid: []const u8 = "";
pub var current_depth_node_id: []const u8 = "";
pub var router: Router = undefined;

var serious_error: bool = false;

const Vapor = @This();
pub const Kit = @import("kit/Kit.zig");
// pub const Chart = @import("components/charts/Chart.zig");
pub const Style = types.Style;
pub const Signal = Rune.Signal;
pub const Types = types;
pub const DateTime = @import("DateTime.zig");
pub const Animation = @import("Animation.zig");
pub const Edges = @import("Edges.zig").Edges;
pub const Transition = @import("Transition.zig");
// pub const Error = @import("routes/nightwatch/Error.zig");

pub fn clearPersitantStorage() void {
    if (isWasi) {
        Wasm.clearLocalStorageWasm();
    } else {}
}

pub fn getWindowPath() []const u8 {
    if (isWasi) {
        return std.mem.span(Wasm.getWindowInformationWasm());
    } else {
        return "";
    }
}

pub fn store(key: []const u8, value: anytype) void {
    if (!isWasi) return;
    switch (@typeInfo(@TypeOf(value))) {
        .int, .float => Wasm.setLocalStorageNumberWasm(key.ptr, key.len, value),
        .pointer => |ptr| {
            switch (ptr.size) {
                .slice => {
                    Wasm.setLocalStorageStringWasm(key.ptr, key.len, value.ptr, value.len);
                },
                else => {
                    Wasm.setLocalStorageStringWasm(key.ptr, key.len, value.ptr, value.len);
                },
            }
        },
        .@"enum" => {
            const string = @tagName(value);
            Wasm.setLocalStorageStringWasm(key.ptr, key.len, string.ptr, string.len);
        },
        else => {
            Vapor.printlnErr("Cannot store non string or int float types TYPE: {any}", .{@TypeOf(value)});
        },
    }
}

pub fn getStore(comptime T: type, key: []const u8) ?T {
    if (!isWasi) return null;
    switch (T) {
        []const u8 => {
            const string = Wasm.getLocalStorageStringWasm(key.ptr, key.len) orelse return null;
            const value = std.mem.span(string);
            const handle = storage_table.replaceOrAddStr(key, value) catch unreachable;
            const stored_value = storage_table.getStr(handle) orelse unreachable;
            return stored_value;
        },
        usize => return @intCast(Wasm.getLocalStorageU32Wasm(key.ptr, key.len)),
        i32 => return Wasm.getLocalStorageI32Wasm(key.ptr, key.len),
        u32 => return Wasm.getLocalStorageU32Wasm(key.ptr, key.len),
        f32 => return Wasm.getLocalStorageF32Wasm(key.ptr, key.len),
        else => {
            if (@typeInfo(T) == .@"enum") {
                const string = Wasm.getLocalStorageStringWasm(key.ptr, key.len) orelse return null;
                const value = std.mem.span(string);
                const handle = storage_table.replaceOrAddStr(key, value) catch unreachable;
                const stored_value = storage_table.getStr(handle) orelse unreachable;
                return std.meta.stringToEnum(T, stored_value);
            } else {
                return null;
            }
        },
    }
}

pub const EventHandler = struct {
    type: EventType,
    ctx_aware: bool = false,
    cb_opaque: *const anyopaque,
};

pub const EventHandlers = struct {
    items: std.ArrayListUnmanaged(ErasedEventCallback),
};

pub const Action = struct {
    dynamic_object: ?*DynamicObject = null,
    runFn: ActionProto,
    deinitFn: NodeProto,
    argsFn: ?ArgsProto = null,
};

pub const Node = struct { data: Action };

pub const ActionProto = *const fn (*Action) void;
pub const NodeProto = *const fn (*Node) void;
pub const ArgsProto = *const fn (*Action) []const u8;

pub fn ArgsTuple(comptime Fn: type) type {
    const out = std.meta.ArgsTuple(Fn);
    return if (std.meta.fields(out).len == 0) @TypeOf(.{}) else out;
}

pub var callback_registry: std.AutoHashMap(u32, *const fn () void) = undefined;
pub var ctx_callback_registry: std.AutoHashMap(u32, *Node) = undefined;

pub var fetch_registry: std.AutoHashMap(u32, *Kit.FetchNode) = undefined;
pub const EventNode = struct { cb: *const fn (*Event) void, ui_node: ?*UINode = null, evt_type: EventType };
pub var events_callbacks: std.AutoHashMap(u32, EventNode) = undefined;
pub var nodes_with_events: std.AutoHashMap(u32, *UINode) = undefined;
pub var cached_event_handlers: std.AutoHashMap(u32, EventHandlers) = undefined;
pub var hooks_inst_callbacks: std.AutoHashMap(u32, *const fn (HookContext) void) = undefined;
pub var mounted_funcs: std.AutoHashMap(u32, *const fn () void) = undefined;
pub var on_end_funcs: std.array_list.Managed(*const fn () void) = undefined;
pub var on_end_ctx_funcs: std.array_list.Managed(*Node) = undefined;
pub var pop_state_funcs: std.array_list.Managed(*const fn () void) = undefined;
pub var push_state_funcs: std.array_list.Managed(*const fn () void) = undefined;
pub var on_commit_funcs: std.array_list.Managed(*const fn () void) = undefined;
pub var on_commit_ctx_funcs: std.array_list.Managed(*Node) = undefined;
pub var mounted_ctx_funcs: std.AutoHashMap(u32, *Node) = undefined;
pub var on_create_node_funcs: std.AutoHashMap(u32, *Node) = undefined;
pub var created_funcs: std.AutoHashMap(u32, *const fn () void) = undefined;
pub var updated_funcs: std.AutoHashMap(u32, *const fn () void) = undefined;
pub var destroy_funcs: std.AutoHashMap(u32, *const fn () void) = undefined;
pub var erased_registry: std.AutoHashMap(u32, ErasedCallback) = undefined;
pub var erased_event_registry: std.AutoHashMap(u32, ErasedEventCallback) = undefined;

pub var element_registry: std.AutoHashMap(u32, *Element) = undefined;

pub var string_table: StringTable = undefined;
pub var storage_table: StorageTable = undefined;
pub var text_field_table: TextFieldTable = undefined;
pub var shadows: std.AutoHashMap(u32, Vapor.Types.NewShadow) = undefined;
pub var packed_layers: std.AutoHashMap(u32, []Vapor.Types.PackedLayer) = undefined;
pub var packed_colors: std.AutoHashMap(u32, []Vapor.Types.PackedColor) = undefined;
pub var packed_transitions: std.AutoHashMap(u32, []Vapor.Types.TransitionProperty) = undefined;
pub var packed_transforms: std.AutoHashMap(u32, []Vapor.Types.TransformType) = undefined;

const RemovedNode = struct { uuid: []const u8, index: usize };
pub const ObserverNode = union(enum) {
    type: ElementType,
    uuid: []const u8,
};
pub var observer_nodes: std.StringHashMap(std.array_list.Managed(ObserverNode)) = undefined;
pub var added_nodes: std.array_list.Managed(*UINode) = undefined;
pub var dirty_nodes: std.array_list.Managed(*UINode) = undefined;
// Potential nodes is an set to chekc if the potential nodes that are either shifted or removed on in the dom currently
// instead of an active set, we only record the nodes that are different from the current tree
// pub var potential_nodes: std.StringHashMap(void) = undefined;
const Class = struct {
    element_id: []const u8,
    style_id: []const u8,
};
pub var animations: std.StringHashMap(Animation) = undefined;
pub var edges_table: std.StringHashMap(Edges) = undefined;
pub var polygons_table: std.StringHashMap(Polygons) = undefined;
// Define a type for continuation functions
var callback_count: u32 = 0;
const ContinuationFn = *const fn () void;

// Global array to store continuations

pub var allocator_global: std.mem.Allocator = undefined;
pub var browser_width: f32 = 0;
pub var browser_height: f32 = 0;
pub var page_node_count: u32 = 256;
const FrameAllocator = @import("FrameAllocator.zig");
pub var frame_arena: FrameAllocator = undefined;

pub fn getFrameAllocator() std.mem.Allocator {
    return arena(.frame);
}

pub const ArenaType = enum {
    frame,
    view,
    persist,
    scratch,
    request,
};

pub fn arena(arena_type: ArenaType) std.mem.Allocator {
    if (generating) return frame_arena.persistentAllocator();
    return switch (arena_type) {
        .frame => frame_arena.frameAllocator(),
        .view => frame_arena.viewAllocator(),
        .persist => frame_arena.persistentAllocator(),
        .request => frame_arena.requestAllocator(),
        .scratch => frame_arena.persistentAllocator(),
    };
}

pub fn array(comptime T: type, arena_type: ArenaType) Array(T) {
    var array_list: std.array_list.Managed(T) = undefined;
    const allocator = arena(arena_type);
    array_list = std.array_list.Managed(T).init(allocator);
    return array_list;
}

pub const Array = std.array_list.Managed;

pub const VaporConfig = struct {
    // screen_width: f32,
    // screen_height: f32,
    page_node_count: u32 = 256,
    mode: Mode = .atomic,
};

const Mode = enum {
    immediate,
    atomic,
    retained,
    static,
};

pub var pool: Pool = undefined;
pub var mode: Mode = .atomic;
pub var class_cache: ClassCache = undefined;
pub var trace_arena: std.heap.ArenaAllocator = undefined;

extern fn frame_arena_init(frame_arena: *FrameAllocator, backing_allocator: *std.mem.Allocator) void;

// 17kb is just the exports and externs

pub fn init(config: VaporConfig) void {
    switch (builtin.target.cpu.arch) {
        .wasm32 => {
            allocator_global = std.heap.wasm_allocator;
        },
        else => {
            allocator_global = std.heap.c_allocator;
        },
    }
    if (isWasi) {
        browser_width = Wasm.windowWidth();
        browser_height = Wasm.windowHeight();
    }
    page_node_count = config.page_node_count;
    mode = config.mode;

    // Init the frame allocator;
    frame_arena = FrameAllocator.init(allocator_global);
    trace_arena = std.heap.ArenaAllocator.init(allocator_global);
    // The persistent allocator is used for the Initialization of the registries as these persist over the lifetime of the program.
    const allocator = frame_arena.persistentAllocator();

    // Init Router // This adds 1kb
    router.init(allocator) catch |err| {
        println("Could not init Router {any}\n", .{err});
    };

    // >1kb
    Packer.init(allocator);
    // 20kb // This is the biggest chunk of code
    initRegistries(allocator);
    // >1kb
    initCalls(allocator);
    // >1kb
    initContextData(allocator);

    // Eveyrhtuing up to here is 35kb

    class_cache.init(allocator) catch |err| {
        printlnErr("Could not init ClassCache {any}\n", .{err});
        unreachable;
    };
    UIContext.element_style_hash_map = std.AutoHashMap(u32, [8]u32).init(allocator);
    UIContext.class_string_cache = std.AutoHashMap(u32, []const u8).init(allocator);
    UIContext.prev_style_hashes = std.AutoHashMap(u32, u32).init(allocator);
    UIContext.style_info_map = std.AutoHashMap(u32, *UIContext.StyleInfo).init(allocator);

    Components.text_string_table = std.AutoHashMap(u32, Components.StringEntry).init(allocator);
    Accessibility.a11y_map = std.AutoHashMap(u32, Accessibility.Accessibility).init(allocator);

    string_table = StringTable.init(allocator);
    storage_table = StorageTable.init(allocator);
    text_field_table = TextFieldTable.init(allocator);
    shadows = std.AutoHashMap(u32, Vapor.Types.NewShadow).init(allocator);
    packed_layers = std.AutoHashMap(u32, []Types.PackedLayer).init(allocator);
    packed_colors = std.AutoHashMap(u32, []Types.PackedColor).init(allocator);
    packed_transitions = std.AutoHashMap(u32, []Types.TransitionProperty).init(allocator);
    packed_transitions = std.AutoHashMap(u32, []Types.TransitionProperty).init(allocator);
    packed_transforms = std.AutoHashMap(u32, []Types.TransformType).init(allocator);
    Animation.RemovalQueue.init(allocator);
    KeyGenerator.initWriter();

    // All this below adds 3kb
    animations = std.StringHashMap(Animation).init(allocator);
    edges_table = std.StringHashMap(Edges).init(allocator);
    polygons_table = std.StringHashMap(Polygons).init(allocator);
    // removed_nodes = std.array_list.Managed(RemovedNode).init(allocator);
    observer_nodes = std.StringHashMap(std.array_list.Managed(ObserverNode)).init(allocator);
    added_nodes = std.array_list.Managed(*UINode).init(allocator);
    dirty_nodes = std.array_list.Managed(*UINode).init(allocator);

    // action_log = Structures.BoundedArray(ErrorReport, 512).init(512) catch unreachable;

    UIContext.indexes = std.AutoHashMap(u32, usize).init(allocator);
    if (build_options.enable_debug) {
        printlnColor("-----------Debug Mode----------", .{}, .hex("#F6820C"));
    }

    // Everything up to here is 42 kb
}

fn initRegistries(persistent_allocator: std.mem.Allocator) void {
    callback_registry = std.AutoHashMap(u32, *const fn () void).init(persistent_allocator);
    ctx_callback_registry = std.AutoHashMap(u32, *Node).init(persistent_allocator);
    animation_frame_callbacks = std.array_list.Managed(*Node).init(persistent_allocator);
}

fn initCalls(persistent_allocator: std.mem.Allocator) void {
    events_callbacks = std.AutoHashMap(u32, EventNode).init(persistent_allocator);
    nodes_with_events = std.AutoHashMap(u32, *UINode).init(persistent_allocator);
    cached_event_handlers = std.AutoHashMap(u32, EventHandlers).init(persistent_allocator);
    // node_events_callbacks = std.AutoHashMap(u32, *CtxAwareEventNode).init(persistent_allocator);
    // events_inst_callbacks = std.AutoHashMap(u32, *EvtInstNode).init(persistent_allocator);
    hooks_inst_callbacks = std.AutoHashMap(u32, *const fn (HookContext) void).init(persistent_allocator);
    mounted_funcs = std.AutoHashMap(u32, *const fn () void).init(persistent_allocator);
    on_end_funcs = std.array_list.Managed(*const fn () void).init(persistent_allocator);
    on_end_ctx_funcs = std.array_list.Managed(*Node).init(persistent_allocator);
    pop_state_funcs = std.array_list.Managed(*const fn () void).init(persistent_allocator);
    push_state_funcs = std.array_list.Managed(*const fn () void).init(persistent_allocator);
    on_commit_funcs = std.array_list.Managed(*const fn () void).init(persistent_allocator);
    on_commit_ctx_funcs = std.array_list.Managed(*Node).init(persistent_allocator);
    mounted_ctx_funcs = std.AutoHashMap(u32, *Node).init(persistent_allocator);
    on_create_node_funcs = std.AutoHashMap(u32, *Node).init(persistent_allocator);
    destroy_funcs = std.AutoHashMap(u32, *const fn () void).init(persistent_allocator);
    updated_funcs = std.AutoHashMap(u32, *const fn () void).init(persistent_allocator);
    created_funcs = std.AutoHashMap(u32, *const fn () void).init(persistent_allocator);
    erased_registry = std.AutoHashMap(u32, ErasedCallback).init(persistent_allocator);
    erased_event_registry = std.AutoHashMap(u32, ErasedEventCallback).init(persistent_allocator);
    element_registry = std.AutoHashMap(u32, *Element).init(persistent_allocator);
}

fn initContextData(persistent_allocator: std.mem.Allocator) void {
    ctx_map = std.AutoHashMap(u32, *UIContext).init(persistent_allocator);
    page_map = std.StringHashMap(void).init(persistent_allocator);
    layout_map = std.AutoHashMap(u32, LayoutItem).init(persistent_allocator);
    page_deinit_map = std.AutoHashMap(u32, *const fn () void).init(persistent_allocator);
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

/// Force rerender forces the entire dom tree to check props of all dynamic and pure components and rerender the ui
/// since Vapor is built with zig and wasm, checking all props of 10000s of nodes and ui components is cheap
/// feel free to abuse force, its essentially a global signal
pub fn cycle() void {
    if (isWasi) {
        Vapor.global_rerender = true;
        // render_phase = .generating;
        Wasm.requestRerenderWasm();
    }
}

pub fn batch() void {
    if (isWasi) {
        Vapor.global_rerender = true;
        // render_phase = .generating;
        Wasm.requestRerenderWasm();
    }
}

// /// Force rerender forces the entire dom tree to check props of all dynamic and pure components and rerender the ui
// /// since Vapor is built with zig and wasm, checking all props of 10000s of nodes and ui components is cheap
// /// feel free to abuse force, its essentially a global signal
// pub fn cycleGrain() void {
//     Vapor.grain_rerender = true;
//     Vapor.println("Grain rerender", .{});
//     Wasm.requestRerenderWasm();
// }

/// Force rerender forces the entire dom tree to check props and rerender the entire ui
/// since Vapor is built with zig and wasm, checking all props of 10000s of nodes and ui components is cheap
/// feel free to abuse force, its essentially a global signal
pub fn forceEverything() void {
    if (isWasi) {
        Vapor.rerender_everything = true;
        Vapor.global_rerender = true;
        Wasm.requestRerenderWasm();
    }
}

/// This function adds the route to the tether radix tree.
/// Deinitializes the tether instance recursively calls routes deinit routes from radix tree
/// # Parameters:
/// - `vapor`: *Vapor,
/// - `path`: []const u8,
/// - `page`: CommandTree
///
/// # Returns:
/// !void.
pub fn addRoute(
    path: []const u8,
    page: *CommandsTree,
) !void {
    try router.addRoute(path, page);
    return;
}

var route_segments: [][]const u8 = undefined;
var deepest_reset_layout: ?LayoutItem = null;
var deepest_reset_layout_path: []const u8 = "";
var target_min_layout_path: []const u8 = "";

fn findResetLayout() void {
    var potential_path: []const u8 = "";
    for (route_segments, 0..) |segment, i| {
        potential_path = std.fmt.allocPrint(Vapor.arena(.frame), "{s}/{s}", .{ potential_path, segment }) catch return;
        const target_layout = layout_map.get(hashKey(potential_path)) orelse continue;
        if (target_layout.reset) {
            deepest_reset_layout = target_layout;
            deepest_reset_layout_path = potential_path;
            route_segments = route_segments[i + 1 ..];
        }
    }
    if (deepest_reset_layout) |_| {
        target_min_layout_path = deepest_reset_layout_path;
    } else {
        target_min_layout_path = current_route;
    }
}

var next_layout_path_to_check: []const u8 = "";
fn callNestedLayouts() void {
    if (route_segments.len == 0) {
        if (deepest_reset_layout) |layout| {
            const layout_fn = layout.call_fn;
            deepest_reset_layout = null;
            deepest_reset_layout_path = "";
            layout_fn(render_page);
        } else {
            // TODO: This is taking a lot of time we need to create a better hashmap system, currently the hashmap compare
            // with the node is long and slow
            // const time = nowMs();
            render_page();
            // Vapor.println("Render time {any}", .{nowMs() - time});
        }
        return;
    }

    // Get the current layout
    next_layout_path_to_check = fmtln("{s}/{s}", .{ next_layout_path_to_check, route_segments[0] });
    if (layout_map.get(hashKey(next_layout_path_to_check))) |entry| {
        const layout_path = next_layout_path_to_check; // "/root" or "/root/docs"
        const layout_fn = entry.call_fn;
        // We check if the layout path and current path are the same
        // Here we need to check if the layout_path starts with the target_min_layout_path
        // if the target path is /root/docs and the layout_path is /root
        if (std.mem.startsWith(u8, target_min_layout_path, layout_path)) {
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

pub var clean_up_ctx: *UIContext = undefined;
var current_route: []const u8 = "";
var previous_route: []const u8 = "";
var render_page: *const fn () void = undefined;
pub var generator: CSSGenerator = undefined;

const RenderPhase = enum {
    generating, // Building VDOM
    committing, // Running commit hooks
    applying, // Applying to real DOM
    idle, // Done
};

const Status = struct {
    render_cycle: bool = true,
    valid_url: bool = true,
};

var status: Status = .{};

pub fn getStatus() Status {
    return status;
}

pub fn resetStatus() void {
    status = .{};
}

fn DefaultPage() void {}

pub var old_ctx_op: ?*UIContext = null;

// pub var render_phase: RenderPhase = .idle;
var changed_route: bool = false;
pub fn renderCycle(route_ptr: [*:0]u8) !void {
    const start = nowMs();
    UIContext.cache_count = 0;
    status = .{};

    const route = std.mem.span(route_ptr);

    // Get the old context for current route
    const old_route_op = router.searchRoute(route) orelse blk: {
        printlnSrcErr("No Route found", .{}, @src());
        break :blk router.searchRoute("/root/error") orelse {
            printlnSrcErr("No Error Route found", .{}, @src());
            status.valid_url = false;
            break :blk null;
        };
    };

    if (old_route_op) |old_route| {
        render_page = old_route.page;
        frame_arena.setCurrentRoute(old_route.route_arena);
    } else {
        render_page = DefaultPage;
    }

    frame_arena.beginFrame(); // For double-buffered approach
    frame_arena.resetScratchArena();

    if (!std.mem.eql(u8, current_route, route)) {
        changed_route = true;
        // We need to start a new route allocator
        // otherwise we are on the same route
        frame_arena.beginView();
    }

    current_route = route;
    // removed_nodes.clearRetainingCapacity();
    added_nodes.clearRetainingCapacity();
    dirty_nodes.clearRetainingCapacity();
    // potential_nodes.clearRetainingCapacity();
    // node_events_callbacks.clearRetainingCapacity();
    // events_callbacks.clearRetainingCapacity();
    nodes_with_events.clearRetainingCapacity();
    // erased_event_registry.clearRetainingCapacity();
    erased_registry.clearRetainingCapacity();
    UIContext.indexes.clearRetainingCapacity();

    packed_layers.clearRetainingCapacity();
    packed_colors.clearRetainingCapacity();
    packed_transitions.clearRetainingCapacity();
    packed_transforms.clearRetainingCapacity();
    shadows.clearRetainingCapacity();
    // string_table.clear();

    // on_end_funcs.clearRetainingCapacity();

    // var ctx_itr = ctx_callback_registry.iterator();
    // while (ctx_itr.next()) |entry| {
    //     _ = entry.value_ptr.*;
    // }
    // ctx_callback_registry.clearRetainingCapacity();

    // for (mounted_ctx_funcs.items) |node| {
    //     node.data.deinitFn(node);
    // }
    // mounted_ctx_funcs.clearRetainingCapacity();

    const old_ctx = current_ctx;
    old_ctx_op = old_ctx;
    // Create new context
    const new_ctx: *UIContext = arena(.frame).create(UIContext) catch {
        status.render_cycle = false;
        println("Failed to allocate UIContext\n", .{});
        return;
    };

    UIContext.initContext(new_ctx) catch |err| {
        status.render_cycle = false;
        println("Allocator ran out of space {any}\n", .{err});
        new_ctx.deinit();
        allocator_global.destroy(new_ctx);
        return;
    };

    new_ctx.root.?.uuid = old_ctx.root.?.uuid;

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

    // Init the generator
    generator.init();
    next_layout_path_to_check = "";

    UIContext.open_time = 0;
    const generation_start = nowMs();
    findResetLayout();
    // This calls the render tree, with render_page as the root function call
    // First it traverses the layouts calling them in order, and then it calls the render_page
    callNestedLayouts(); // 4.5ms
    // Vapor.println("Total {d}", .{frame_arena.queryBytesUsed()});
    Timer.generation_time = nowMs() - generation_start;
    // Debugger.render();

    onCommitCtxCallback();

    on_commit_funcs.clearRetainingCapacity();
    on_commit_ctx_funcs.clearRetainingCapacity();

    const reconcile_start = nowMs();
    Reconciler.reconcile(old_ctx, new_ctx); // 3kb
    Timer.reconcile_time = nowMs() - reconcile_start;
    // Vapor.println("Reconcile Time: {d}ms", .{Timer.reconcile_time});
    // We generate the render commands tree
    const commit_start = nowMs();
    endPage(new_ctx);
    Timer.commit_time = nowMs() - commit_start;
    // Vapor.println("Commit Time: {d}ms", .{Timer.commit_time});
    if (!std.mem.eql(u8, previous_route, current_route)) {
        Vapor.has_dirty = true;
    }

    if (build_options.enable_debug and build_options.debug_level == .all) {
        frame_arena.printStats();
    }

    // Replace old context with new context in the map
    clean_up_ctx = old_ctx;
    Timer.total_time = nowMs() - start;
    changed_route = false;
    // _ = frame_arena.queryNodes();
    class_cache.batchRemove();
    if (old_route_op != null and router.updateRouteTree(old_route_op.?.path, new_ctx)) {
        return;
    }

    allocator_global.free(route); // return host‑allocated buffer
    previous_route = current_route;
}

// fn renderErrorPage(_: []const u8) void {
//     // if (mode_options.static_mode) return;
//     frame_arena.beginFrame(); // For double-buffered approach
//     const start = nowMs();
//     const route = "/root/error";
//
//     if (!std.mem.eql(u8, current_route, route)) {
//         changed_route = true;
//         // We need to start a new route allocator
//         // otherwise we are on the same route
//         frame_arena.beginView();
//     }
//
//     current_route = route;
//     removed_nodes.clearRetainingCapacity();
//     added_nodes.clearRetainingCapacity();
//     dirty_nodes.clearRetainingCapacity();
//     // potential_nodes.clearRetainingCapacity();
//     node_events_callbacks.clearRetainingCapacity();
//     events_callbacks.clearRetainingCapacity();
//     nodes_with_events.clearRetainingCapacity();
//     UIContext.indexes.clearRetainingCapacity();
//
//     var ctx_itr = ctx_callback_registry.iterator();
//     while (ctx_itr.next()) |entry| {
//         _ = entry.value_ptr.*;
//     }
//     ctx_callback_registry.clearRetainingCapacity();
//
//     // for (mounted_ctx_funcs.items) |node| {
//     //     node.data.deinitFn(node);
//     // }
//     mounted_ctx_funcs.clearRetainingCapacity();
//
//     // Get the old context for current route
//     const old_route = router.searchRoute(route) orelse {
//         printlnSrcErr("No Route found", .{}, @src());
//         return;
//     };
//     render_page = old_route.page;
//     const old_ctx = current_ctx;
//     // Create new context
//     const new_ctx: *UIContext = arena(.frame).create(UIContext) catch {
//         println("Failed to allocate UIContext\n", .{});
//         return;
//     };
//
//     UIContext.initContext(new_ctx) catch |err| {
//         println("Allocator ran out of space {any}\n", .{err});
//         new_ctx.deinit();
//         allocator_global.destroy(new_ctx);
//         return;
//     };
//
//     const old_root = old_ctx.root orelse return;
//     const new_root = new_ctx.root orelse return;
//     new_ctx.root.?.uuid = old_root.uuid;
//
//     current_ctx = new_ctx;
//     var route_itr = std.mem.tokenizeScalar(u8, route, '/');
//     var count: usize = 0;
//     while (route_itr.next()) |_| {
//         count += 1;
//     }
//     route_segments = allocator_global.alloc([]const u8, count) catch return;
//     count = 0;
//     route_itr.reset();
//     while (route_itr.next()) |route_token| {
//         route_segments[count] = route_token;
//         count += 1;
//     }
//
//     // Init the generator
//     generator.init();
//     next_layout_path_to_check = "";
//
//     const generation_start = nowMs();
//     findResetLayout();
//     // This calls the render tree, with render_page as the root function call
//     // First it traverses the layouts calling them in order, and then it calls the render_page
//     callNestedLayouts(); // 4.5ms
//     Timer.generation_time = nowMs() - generation_start;
//     // Debugger.render();
//
//     on_commit_funcs.clearRetainingCapacity();
//
//     const reconcile_start = nowMs();
//     Reconciler.reconcile(old_ctx, new_ctx); // 3kb
//     Timer.reconcile_time = nowMs() - reconcile_start;
//     // We generate the render commands tree
//     const commit_start = nowMs();
//     endPage(new_ctx);
//     Timer.commit_time = nowMs() - commit_start;
//     // Vapor.println("Total {d}", .{frame_arena.queryBytesUsed()});
//     if (!std.mem.eql(u8, previous_route, current_route)) {
//         Vapor.has_dirty = true;
//     }
//
//     // Replace old context with new context in the map
//     clean_up_ctx = old_ctx;
//     Timer.total_time = nowMs() - start;
//     changed_route = false;
//     // _ = frame_arena.queryNodes();
//     if (router.updateRouteTree(old_route.path, new_ctx)) {
//         return;
//     }
//
//     allocator_global.free(route); // return host‑allocated buffer
//     if (build_options.enable_debug and build_options.debug_level == .all) {
//         frame_arena.printStats();
//     }
//     previous_route = current_route;
// }

pub fn createPage(path: []const u8, page: fn () void, page_deinit: ?fn () void) !void {
    if (isWasi) {
        has_context = true;
    }

    const route_arena = frame_arena.createRouteArena();
    frame_arena.setCurrentRoute(route_arena);

    const path_ctx: *UIContext = try allocator_global.create(UIContext);
    // Initial render
    UIContext.initContext(path_ctx) catch |err| {
        println("Allocator ran out of space {any}\n", .{err});
        return;
    };

    current_ctx = path_ctx;

    router.addRoute(path, path_ctx, page, route_arena) catch |err| {
        println("Could not put route {any}\n", .{err});
    };
    page_map.put(path, {}) catch |err| {
        println("Could not put route {any}\n", .{err});
    };

    if (page_deinit) |de| {
        page_deinit_map.put(path, de) catch |err| {
            println("Could not put route {any}\n", .{err});
        };
    }
    return;
}
extern fn performance_now() f64; // imported from JS, for example

var animation_frame_callbacks: std.array_list.Managed(*Node) = undefined;
var animation_frame_callback: ?*Node = null;
pub fn runOnAnimationFrame(callback: anytype, args: anytype) void {
    const Args = @TypeOf(args);
    const Closure = struct {
        arguments: Args,
        run_node: Node = .{ .data = .{ .runFn = runFn, .deinitFn = deinitFn } },
        //
        fn runFn(action: *Action) void {
            const run_node: *Node = @fieldParentPtr("data", action);
            const closure: *@This() = @alignCast(@fieldParentPtr("run_node", run_node));
            @call(.auto, callback, closure.arguments);
        }
        //
        fn deinitFn(node: *Node) void {
            const closure: *@This() = @alignCast(@fieldParentPtr("run_node", node));
            allocator_global.destroy(closure);
        }
    };

    const closure = Vapor.arena(.frame).create(Closure) catch |err| {
        println("Error could not create closure {any}\n ", .{err});
        unreachable;
    };
    closure.* = .{
        .arguments = args,
    };

    animation_frame_callback = &closure.run_node;

    if (isWasi) {
        Wasm.runOnAnimationFrameWasm(@intFromPtr(animation_frame_callback));
    }
}

export fn callAnimationFrameCallback(onid: u32) void {
    const node: *Node = @ptrFromInt(onid);
    @call(.auto, node.data.runFn, .{&node.data});
}

export fn callAnimationFrameCallbacks() void {
    for (animation_frame_callbacks.items) |item| {
        @call(.auto, item.data.runFn, .{&item.data});
    }
}

pub fn nowMs() f64 {
    if (isWasi) {
        return performance_now();
    } else {
        return 0;
    }
}
pub fn endPage(_: *UIContext) void {
    if (changed_route) {
        ////// BE CAREFUL WITH THIS the configuration system does not run if the value has been created already i think?
        ///// uncommenting the above and then usign the search fucntion casues errors on the layers style fucntionality
        generator.writeAllStyles();
    }
}

pub fn end(vapor: *Vapor) !void {
    const watch_paths: []const []const u8 = &.{"src/routes"};
    for (watch_paths) |watch_path| {
        var dir = try std.fs.cwd().openDir(watch_path, .{ .iterate = true });
        defer dir.close();

        var walker = try dir.walk(vapor.allocator.*);
        defer walker.deinit();

        while (try walker.next()) |entry| {
            const path = try std.fs.path.join(vapor.allocator.*, &.{ watch_path, entry.path });
            println("{s}\n", .{path});
        }
    }
}

// Okay so we need to change the node in the tree depending on the page route
// for example we add the commads tree to the router tree
const Path = union(enum) {
    route: []const u8,
    src: std.builtin.SourceLocation,
};
pub fn Page(path: Path, page: fn () void, page_deinit: ?fn () void) void {
    const allocator = Vapor.frame_arena.persistentAllocator();
    var full_route: []const u8 = "";
    var itr: std.mem.TokenIterator(u8, std.mem.DelimiterType.scalar) = undefined;
    if (path == .src) {
        full_route = path.src.file[0..path.src.file.len];
        itr = std.mem.tokenizeScalar(u8, full_route[7..], '/');
    } else {
        full_route = path.route;
        itr = std.mem.tokenizeScalar(u8, full_route, '/');
    }
    var buf = std.array_list.Managed(u8).init(allocator);

    buf.appendSlice("/root") catch |err| {
        println("Allocator ran out of space {any}\n", .{err});
        return;
    };

    var file_name: []const u8 = "";
    blk: while (itr.next()) |sub| {
        if (itr.peek() == null and path == .src) {
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

    // else
    if (std.mem.startsWith(u8, file_name, "Error")) {
        buf.appendSlice("/error") catch |err| {
            println("Allocator ran out of space {any}\n", .{err});
            return;
        };
    }

    const route = buf.toOwnedSlice() catch |err| {
        println("Could not parse route {any}\n", .{err});
        return;
    };

    createPage(route, page, page_deinit) catch |err| {
        println("Could not add page {any}\n", .{err});
        return;
    };
}
const LayoutOptions = struct {
    reset: bool = false,
};

pub fn registerLayout(path: []const u8, layout: fn (*const fn () void) void, options: LayoutOptions) !void {
    if (std.mem.eql(u8, path, "/root")) return error.CannotRegisterRootPath;
    if (std.mem.eql(u8, path, "/")) {
        layout_map.put(hashKey("/root"), .{ .call_fn = layout, .reset = options.reset }) catch |err| {
            printlnSrcErr("Could not add layout to registry {}", .{err}, @src());
        };
    } else {
        const layout_route = std.fmt.allocPrint(Vapor.arena(.persist), "/root{s}", .{path}) catch return;
        layout_map.put(hashKey(layout_route), .{ .call_fn = layout, .reset = options.reset }) catch |err| {
            printlnSrcErr("Could not add layout to registry {}", .{err}, @src());
        };
    }
}
pub const HooksFuncs = struct {
    created: ?*const fn () void = null,
    mounted: ?*const fn () void = null,
    destroy: ?*const fn () void = null,
    updated: ?*const fn () void = null,
};

pub const HooksCtxFuncs = enum(u8) { mounted, destroy };

pub fn toggleTheme() void {
    if (isWasi) {
        Wasm.toggleThemeWasm();
    }
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
pub inline fn destroyElementEventListener(
    element_uuid: []const u8,
    event_type: types.EventType,
    cb_id: usize,
) ?bool {
    const event_type_str = std.enums.tagName(types.EventType, event_type) orelse return null;
    Wasm.removeElementEventListener(element_uuid.ptr, element_uuid.len, event_type_str.ptr, event_type_str.len, cb_id);
    Vapor.printlnSrc("Callback id {}", .{cb_id}, @src());
    // if (events_callbacks.remove(cb_id)) {
    //     return true;
    // }
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
    Wasm.removeElementEventListener(element_uuid.ptr, element_uuid.len, event_type_str.ptr, event_type_str.len, cb_id);
    // if (events_inst_callbacks.remove(cb_id)) {
    //     return true;
    // }
    return false;
}

/// This function creates an focuses on the element.
/// # Parameters:
/// - `element_id`: []const u8,
///
/// # Returns:
/// void
pub inline fn focus(element_uuid: []const u8) void {
    if (Vapor.isWasi) {
        Wasm.elementFocusWasm(element_uuid.ptr, element_uuid.len);
    }
}

/// This function creates an focuses on the element.
/// # Parameters:
/// - `element_id`: []const u8,
///
/// # Returns:
/// void
pub inline fn focused(element_uuid: []const u8) bool {
    if (Vapor.isWasi) {
        return Wasm.elementFocusedWasm(element_uuid.ptr, element_uuid.len);
    }
}

const serializeArgs = utils.serializeArgs;

pub fn attachEventCtxCallback(ui_node: *UINode, event_type: EventType, cb: anytype, args: anytype) !void {
    if (!isWasi) return;

    // Check for duplicates
    if (ui_node.event_handlers) |handlers| {
        for (handlers.items.items) |handler| {
            if (handler.event_type == event_type) {
                return error.EventCtxCallbackError;
            }
        }
    }

    const erased = try ErasedEventCallback.make(arena(.frame), event_type, cb, args);

    // Ensure handlers list exists
    if (ui_node.event_handlers == null) {
        const handlers = try arena(.frame).create(EventHandlers);
        handlers.* = .{ .items = .{} };
        ui_node.event_handlers = handlers;
    }

    try ui_node.event_handlers.?.items.append(arena(.frame), erased);

    const onid = hashKey(ui_node.uuid);
    try nodes_with_events.put(onid, ui_node);
}

export fn dispatchNodeEvent(node_ptr: *UINode, event_type_int: u32, callback_id: u32) void {
    const handlers = node_ptr.event_handlers orelse return;
    const event_type: EventType = @enumFromInt(event_type_int);

    var event = Event{
        .id = callback_id,
        .type = event_type,
    };

    for (handlers.items.items) |*handler| {
        if (handler.event_type == event_type) {
            handler.call(&event);
            if (Vapor.mode == .atomic and event_type != .pointermove) {
                if (node_ptr.type != .Form) {
                    Vapor.cycle();
                }
            }
            return;
        }
    }
}

export fn dispatchEvent(event_type_int: u32, callback_id: u32) void {
    const event_type: EventType = @enumFromInt(event_type_int);

    var event = Event{
        .id = callback_id,
        .type = event_type,
    };

    const erased = erased_event_registry.get(callback_id) orelse {
        std.log.err("Event Callback not found {s}\n", .{@tagName(event_type)});
        Vapor.printlnSrcErr("Event Callback not found\n", .{}, @src());
        return;
    };

    erased.call(&event);

    if (Vapor.mode == .atomic and event_type != .pointermove) {
        Vapor.cycle();
    }
}

pub fn attachEventCallback(ui_node: *UINode, event_type: EventType, cb: fn (event: *Event) void) !void {
    if (!isWasi) return;

    // Check for duplicates
    if (ui_node.event_handlers) |handlers| {
        for (handlers.items.items) |handler| {
            if (handler.event_type == event_type) {
                return error.EventCtxCallbackError;
            }
        }
    }

    const erased = try ErasedEventCallback.make(arena(.frame), event_type, cb, .{});

    // Ensure handlers list exists
    if (ui_node.event_handlers == null) {
        const handlers = try arena(.frame).create(EventHandlers);
        handlers.* = .{ .items = .{} };
        ui_node.event_handlers = handlers;
    }

    try ui_node.event_handlers.?.items.append(arena(.frame), erased);

    const onid = hashKey(ui_node.uuid);
    try nodes_with_events.put(onid, ui_node);
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
    ui_node: *UINode,
    event_type: types.EventType,
    cb: *const fn (event: *Event) void,
) ?usize {
    if (isWasi) {
        var onid = hashKey(ui_node.uuid);
        onid +%= @intFromEnum(event_type);
        events_callbacks.put(onid, .{ .cb = cb, .ui_node = ui_node, .evt_type = event_type }) catch |err| {
            println("Event Callback Error: {any}\n", .{err});
        };

        const event_type_str = std.enums.tagName(types.EventType, event_type) orelse return null;
        Wasm.createElementEventListener(ui_node.uuid.ptr, ui_node.uuid.len, event_type_str.ptr, event_type_str.len, onid);
        return onid;
    }
    return null;
}

pub inline fn removeElementEventListener(
    ui_node: *UINode,
    event_type: types.EventType,
) ?usize {
    if (isWasi) {
        var onid = hashKey(ui_node.uuid);
        onid +%= @intFromEnum(event_type);
        const event_type_str = std.enums.tagName(types.EventType, event_type) orelse return null;
        Wasm.removeElementEventListener(ui_node.uuid.ptr, ui_node.uuid.len, event_type_str.ptr, event_type_str.len, onid);
        return onid;
    }
    return null;
}

pub fn addGlobalListener(event_type: EventType, cb: fn (*Event) void) ?usize {
    if (!isWasi) return;

    const erased = ErasedEventCallback.make(arena(.persist), event_type, cb, .{}) catch unreachable;

    const id = erased_event_registry.count() + 1;
    erased_event_registry.put(id, erased) catch |err| {
        println("Button Function Registry {any}\n", .{err});
        unreachable;
    };

    const event_type_str: []const u8 = std.enums.tagName(types.EventType, event_type) orelse unreachable;
    if (isWasi) {
        Wasm.createEventListenerGlobal(event_type_str.ptr, event_type_str.len, id);
    }
    return @intCast(id);
}

pub fn removeGlobalListener(event_type: EventType, cb_idx: u32) ?bool {
    const event_type_str = std.enums.tagName(types.EventType, event_type) orelse return null;
    Wasm.removeEventListener(event_type_str.ptr, event_type_str.len, cb_idx);
    return true;
}

/// USes persist under the hood
pub fn addGlobalListenerCtx(event_type: EventType, cb: anytype, args: anytype) ?u32 {
    if (!isWasi) return;

    const erased = try ErasedEventCallback.make(arena(.persist), event_type, cb, args);

    const id = erased_event_registry.count() + 1;
    erased_event_registry.put(id, erased) catch |err| {
        println("Button Function Registry {any}\n", .{err});
        unreachable;
    };

    const event_type_str: []const u8 = std.enums.tagName(types.EventType, event_type) orelse unreachable;
    if (isWasi) {
        Wasm.createEventListenerGlobal(event_type_str.ptr, event_type_str.len, id);
    }
    return @intCast(id);
}

pub const HookInst = struct {
    hook_cb: HookInstProto,
};

pub const HookInstProto = *const fn (*HookInst) void;
pub const HookInstNodeProto = *const fn (*HookInstNode) void;

pub const HookInstNode = struct { data: HookInst };

pub const HookContext = struct {
    from_path: []const u8,
    to_path: []const u8,
    params: std.StringHashMap([]const u8),
    query: std.StringHashMap([]const u8),
};

pub const HookType = enum(u8) {
    before = 0,
    after = 1,
};

/// cb(Self)
pub inline fn registerHook(
    url: []const u8,
    cb: anytype,
    hook_type: HookType,
) ?usize {
    if (!isWasi) return null;
    const id = hooks_inst_callbacks.count();
    hooks_inst_callbacks.put(id, cb) catch |err| {
        println("Event Callback Error: {any}\n", .{err});
    };

    Wasm.createHookWASM(url.ptr, url.len, id, @intFromEnum(hook_type));
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
) ?u32 {
    var id: u32 = events_callbacks.count() + 1;
    id +%= @intFromEnum(event_type);
    events_callbacks.put(id, .{ .cb = cb, .ui_node = null, .evt_type = event_type }) catch |err| {
        println("Event Callback Error: {any}\n", .{err});
        return null;
    };

    const event_type_str: []const u8 = std.enums.tagName(types.EventType, event_type) orelse return null;
    if (isWasi) {
        Wasm.createEventListener(event_type_str.ptr, event_type_str.len, id);
    }
    return id;
}

// The first node needs to be marked as false always
pub fn markChildrenDirty(node: *UINode) void {
    if (node.parent != null) {
        node.dirty = true;
    }
    var children = node.children();
    while (children.next()) |child| {
        markChildrenDirty(child);
    }
}
// The first node needs to be marked as false always
pub fn markChildrenNotDirty(node: *UINode) void {
    if (node.parent != null) {
        node.dirty = false;
    }
    var children = node.children();
    while (children.next()) |child| {
        markChildrenNotDirty(child);
    }
}

var buffer: [5_000_000]u8 = undefined;
var writer: std.Io.Writer = undefined;
var generated_file: std.fs.File = undefined;
var generating: bool = false;
pub fn generate() void {
    Vapor.println("Generating... {any}\n", .{mode_options.static_mode});
    generating = true;
    std.fs.cwd().makeDir("static") catch |err| {
        switch (err) {
            error.PathAlreadyExists => {},
            else => unreachable,
        }
    };

    var css_variables = std.fs.cwd().createFile("static/style_variables.css", .{}) catch unreachable;
    css_variables.writeAll(StyleCompiler.global_style) catch unreachable;
    // // _ = frame_arena.queryNodes();
    var page_itr = page_map.iterator();
    while (page_itr.next()) |entry| {
        writer = std.io.Writer.fixed(&buffer);
        const route = entry.key_ptr.*;
        // Create the directory
        const dir = std.fmt.allocPrint(allocator_global, "static{s}", .{route[5..]}) catch unreachable;
        defer allocator_global.free(dir);

        // Create directories
        var sub_dirs = std.mem.tokenizeAny(u8, route[5..], "/");
        var current_dir: []const u8 = "";
        while (sub_dirs.next()) |sub_dir| {
            current_dir = std.fmt.allocPrint(allocator_global, "{s}/{s}", .{ current_dir, sub_dir }) catch |err| {
                std.debug.print("Error: {any}\n", .{err});
                unreachable;
            };
            const total_dir = std.fmt.allocPrint(allocator_global, "static{s}", .{current_dir}) catch |err| {
                std.debug.print("Error: {any}\n", .{err});
                unreachable;
            };
            // Make sure the directory exists
            std.fs.cwd().makeDir(total_dir) catch |err| {
                switch (err) {
                    error.PathAlreadyExists => {},
                    else => unreachable,
                }
            };
        }
        // Create the path
        const path = std.fmt.allocPrint(allocator_global, "{s}/index.html", .{dir}) catch |err| {
            std.debug.print("Error: {any}\n", .{err});
            unreachable;
        };
        defer allocator_global.free(path);

        // Create the static file
        generated_file = std.fs.cwd().createFile(path, .{}) catch |err| {
            std.debug.print("Create Error: {any} {s}\n", .{ err, path });
            unreachable;
        };
        defer generated_file.close();

        // Write the HTML
        generateHtml(route, dir);
        // Write to the file
        _ = generated_file.write(writer.buffer[0..writer.end]) catch unreachable;
    }
    generating = false;
    // writer.flush() catch unreachable;
    // isGenerated = true;
}

pub fn generateHtml(route: []const u8, dir: []const u8) void {
    status = .{};
    frame_arena.beginFrame(); // For double-buffered approach
    frame_arena.resetScratchArena();

    if (!std.mem.eql(u8, current_route, route)) {
        changed_route = true;
        // We need to start a new route allocator
        // otherwise we are on the same route
        frame_arena.beginView();
    }

    current_route = route;
    // removed_nodes.clearRetainingCapacity();
    added_nodes.clearRetainingCapacity();
    dirty_nodes.clearRetainingCapacity();
    // potential_nodes.clearRetainingCapacity();
    // node_events_callbacks.clearRetainingCapacity();
    // events_callbacks.clearRetainingCapacity();
    nodes_with_events.clearRetainingCapacity();
    // erased_event_registry.clearRetainingCapacity();
    erased_registry.clearRetainingCapacity();
    UIContext.indexes.clearRetainingCapacity();
    // on_end_funcs.clearRetainingCapacity();

    // var ctx_itr = ctx_callback_registry.iterator();
    // while (ctx_itr.next()) |entry| {
    //     _ = entry.value_ptr.*;
    // }
    // ctx_callback_registry.clearRetainingCapacity();

    // for (mounted_ctx_funcs.items) |node| {
    //     node.data.deinitFn(node);
    // }
    // mounted_ctx_funcs.clearRetainingCapacity();

    // Get the old context for current route
    const old_route_op = router.searchRoute(route) orelse blk: {
        printlnSrcErr("No Route found", .{}, @src());
        break :blk router.searchRoute("/root/error") orelse {
            printlnSrcErr("No Error Route found", .{}, @src());
            status.valid_url = false;
            break :blk null;
        };
    };
    if (old_route_op) |old_route| {
        render_page = old_route.page;
    } else {
        render_page = DefaultPage;
    }

    const old_ctx = current_ctx;
    // Create new context
    const new_ctx: *UIContext = arena(.frame).create(UIContext) catch {
        status.render_cycle = false;
        println("Failed to allocate UIContext\n", .{});
        return;
    };

    UIContext.initContext(new_ctx) catch |err| {
        status.render_cycle = false;
        println("Allocator ran out of space {any}\n", .{err});
        new_ctx.deinit();
        allocator_global.destroy(new_ctx);
        return;
    };

    new_ctx.root.?.uuid = old_ctx.root.?.uuid;

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

    // Init the generator
    generator.init();
    next_layout_path_to_check = "";

    UIContext.open_time = 0;
    findResetLayout();
    // This calls the render tree, with render_page as the root function call
    // First it traverses the layouts calling them in order, and then it calls the render_page
    callNestedLayouts(); // 4.5ms
    changed_route = false;
    generator.writeAllStyles();
    const css = generator.getCSS();
    const style_path = std.fmt.allocPrint(allocator_global, "{s}/style.css", .{dir}) catch |err| {
        std.debug.print("Error: {any}\n", .{err});
        unreachable;
    };
    defer allocator_global.free(style_path);

    var generated_css = std.fs.cwd().createFile(style_path, .{}) catch unreachable;
    defer generated_css.close();
    generated_css.writeAll(css) catch unreachable;

    HtmlGenerator.generate(new_ctx.root.?, &writer, style_path);
}

pub fn printUIRouteTree(route: u32) void {
    frame_arena.beginFrame(); // For double-buffered approach
    current_route = route;
    // Vapor.btn_registry.clearRetainingCapacity();
    // Vapor.mounted_funcs.clearRetainingCapacity();

    // ctx_callback_registry.clearRetainingCapacity();

    // mounted_ctx_funcs.clearRetainingCapacity();

    // Get the old context for current route
    const old_route = router.searchRoute(route) orelse {
        printlnWithColor("No Router found {s}\n", .{route}, "#FF3029", "ERROR");
        printlnWithColor("Loading Error Page\n", .{}, "#FF3029", "ERROR");
        return;
    };
    render_page = old_route.page;
    const old_ctx = current_ctx;
    // Create new context
    const new_ctx: *UIContext = allocator_global.create(UIContext) catch {
        println("Failed to allocate UIContext\n", .{});
        return;
    };

    UIContext.initContext(new_ctx) catch |err| {
        println("Allocator ran out of space {any}\n", .{err});
        new_ctx.deinit();
        allocator_global.destroy(new_ctx);
        return;
    };

    new_ctx.root.?.style = old_ctx.root.?.style;
    new_ctx.root.?.uuid = old_ctx.root.?.uuid;

    // Pure tree is attached to the traversal algo, ie itll be updated when the traversal algo is updated
    // pure_tree.init(new_ctx.root.?, &allocator_global) catch {};
    // error_tree.init(new_ctx.root.?, &allocator_global) catch {};
    // Here we set the current_ctx to the new_ctx
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

    next_layout_path_to_check = "";
    // We call the routes and nested layuts
    // This finds the reset layout, if it exists
    findResetLayout();
    // This calls the render tree, with render_page as the root function call
    // First it traverses the layouts calling them in order, and then it calls the render_page
    callNestedLayouts(); // 4.5ms

    // We reconcile the new dom
    // the reason the vapor-debugger gets remvoed is the new ui tree does not include it;

    // const valid_route = replace_dash(current_route) catch unreachable;
    // defer allocator_global.free(valid_route);

    // writer.print("\"{s}\":", .{current_route}) catch unreachable;
    // writer.writeAll("{\n") catch unreachable;
    printStaticTextNode(new_ctx.root.?);
    // writer.writeAll("}\n") catch unreachable;
}

pub fn printUITree(node: *UINode) void {
    // if (node.dirty) {
    println("UI: {s}\n", .{node.uuid});
    // }
    if (node.children) |children| {
        for (children.items) |child| {
            printUITree(child);
        }
    }
}

pub fn escapeForJson(input: []const u8) ![]u8 {
    var list = std.array_list.Managed(u8).init(allocator_global);

    for (input) |c| {
        switch (c) {
            '"' => {
                // Add backslash before quote: → \"
                try list.append('\\');
                try list.append('"');
            },
            '\\' => {
                // Optional: also escape existing backslashes → \\
                try list.append('\\');
                try list.append('\\');
            },
            '\n' => {
                // Optional: also escape existing backslashes → \\
                continue;
            },
            else => {
                try list.append(c);
            },
        }
    }

    return list.toOwnedSlice();
}

pub fn replace_dash(input: []const u8) ![]u8 {
    var list = std.array_list.Managed(u8).init(allocator_global);

    for (input) |c| {
        switch (c) {
            '/' => {
                // Add backslash before quote: → \"
                try list.append('-');
            },
            else => {
                try list.append(c);
            },
        }
    }

    return list.toOwnedSlice();
}

fn printStaticTextNode(node: *UINode) void {
    if (node.state_type == .static) blk: {
        var valid_text: []const u8 = "";
        if (node.text) |text| {
            valid_text = escapeForJson(text) catch unreachable;
        } else if (node.href) |href| {
            valid_text = escapeForJson(href) catch unreachable;
        } else break :blk;
        defer allocator_global.free(valid_text);
        if (writer.end > current_route.len + 10) {
            _ = writer.write(",\n") catch unreachable;
        }
        writer.print("\"{s}\":\"{s}\"", .{ node.uuid, valid_text }) catch unreachable;
    }
    for (node.children.items) |child| {
        printStaticTextNode(child);
    }
}

fn collectComponentIds(node: *UINode, selected_type: ElementType, component_ids: *std.array_list.Managed([]const u8)) void {
    if (node.type == selected_type) {
        component_ids.append(node.uuid) catch unreachable;
    }
    var children = node.children();
    while (children.next()) |child| {
        collectComponentIds(child, selected_type, component_ids);
    }
}

pub fn queryComponentIds(target_type: ElementType) ![][]const u8 {
    const root = current_ctx.root orelse return error.NoTree;
    var component_ids = std.array_list.Managed([]const u8).init(allocator_global);
    collectComponentIds(root, target_type, &component_ids);
    return try component_ids.toOwnedSlice();
}

fn findNodeByUUID(node: *UINode, uuid: []const u8) ?*UINode {
    // 1. Check the current node
    if (std.mem.eql(u8, node.uuid, uuid)) {
        return node;
    }

    // 2. Iterate through children
    var children = node.children();
    while (children.next()) |child| {
        // Only return if we actually found something!
        if (findNodeByUUID(child, uuid)) |found| {
            return found;
        }
    }

    // 3. No match found in this branch
    return null;
}

pub fn queryByUUID(uuid: []const u8) !*UINode {
    const root = current_ctx.root orelse return error.NoTree;
    const node = findNodeByUUID(root, uuid) orelse return error.NodeNotFound;
    return node;
}

pub fn mutateById(uuid: []const u8, attribute: []const u8, value: []const u8) void {
    if (isWasi) {
        Wasm.mutateDomElementStringWasm(uuid.ptr, uuid.len, attribute.ptr, attribute.len, value.ptr, value.len);
    }
}

const MutationType = union(enum) {
    string: []const u8,
    int: i32,
    float: f32,
};

pub fn mutateElementById(uuid: []const u8, attribute: []const u8, value: MutationType) void {
    switch (value) {
        .string => |string| {
            Wasm.mutateDomElementStringWasm(uuid.ptr, uuid.len, attribute.ptr, attribute.len, string.ptr, string.len);
        },
        .int => |int| {
            Wasm.mutateDomElementI32Wasm(uuid.ptr, uuid.len, attribute.ptr, attribute.len, int);
        },
        .float => |float| {
            Wasm.mutateDomElementF32Wasm(uuid.ptr, uuid.len, attribute.ptr, attribute.len, float);
        },
    }
}

pub const Bounds = struct {
    top: f32 = 0,
    left: f32 = 0,
    right: f32 = 0,
    bottom: f32 = 0,
    width: f32 = 0,
    height: f32 = 0,
};

pub const Offsets = struct {
    top: f32 = 0,
    left: f32 = 0,
    right: f32 = 0,
    bottom: f32 = 0,
    width: f32 = 0,
    height: f32 = 0,
};

pub fn getComponentOffsets(uuid: []const u8) ?Offsets {
    const bounds_ptr = if (isWasi) blk: {
        break :blk Wasm.getOffsetsWasm(uuid.ptr, uuid.len);
    } else {
        return null;
    };

    return Offsets{
        .top = bounds_ptr[0],
        .left = bounds_ptr[1],
        .right = bounds_ptr[2],
        .bottom = bounds_ptr[3],
        .width = bounds_ptr[4],
        .height = bounds_ptr[5],
    };
}

pub fn getComponentBounds(uuid: []const u8) ?Bounds {
    const bounds_ptr = if (isWasi) blk: {
        break :blk Wasm.getBoundingClientRectWasm(uuid.ptr, uuid.len);
    } else {
        return null;
    };

    return Bounds{
        .top = bounds_ptr[0],
        .left = bounds_ptr[1],
        .right = bounds_ptr[2],
        .bottom = bounds_ptr[3],
        .width = bounds_ptr[4],
        .height = bounds_ptr[5],
    };
}

fn iterateChildren(node: *UINode) void {
    if (node.state_type == .pure) {
        const pure_node = pure_tree.createNode(node) catch return;
        Vapor.pure_tree.openNode(pure_node) catch return;
    }

    if (node.state_type == .err) {
        const error_node = error_tree.createNode(node) catch return;
        Vapor.error_tree.openNode(error_node) catch return;
    }

    for (node.children.items) |child| {
        iterateChildren(child);
    }
    if (node.state_type == .pure and node.parent != null) {
        _ = pure_tree.popStack();
    }
    if (node.state_type == .err and node.parent != null) {
        _ = error_tree.popStack();
    }
}

pub fn iterateTreeChildren(tree: *CommandsTree) void {
    for (tree.children.items) |child| {
        iterateTreeChildren(child);
    }
}
pub var ui_node_layout_info = packed struct {
    ui_node_size: u32,

    // Offsets within UINode
    elem_type_offset: u32,
    text_ptr_offset: u32,
    href_ptr_offset: u32,
    id_ptr_offset: u32,
    index_offset: u32,
    classname_ptr_offset: u32,

    hash_offset: u32,
    style_changed_offset: u32,
    props_changed_offset: u32,
    dirty_offset: u32,
    hooks_offset: u32,
    style_hash_offset: u32,
    accessibility_offset: u32,
}{
    .ui_node_size = @sizeOf(UINode),

    // --- Direct fields of RenderCommand ---
    .elem_type_offset = @offsetOf(UINode, "type"),
    .text_ptr_offset = @offsetOf(UINode, "text"),
    .href_ptr_offset = @offsetOf(UINode, "href"),
    .id_ptr_offset = @offsetOf(UINode, "uuid"),
    .index_offset = @offsetOf(UINode, "index"),
    .classname_ptr_offset = @offsetOf(UINode, "class"),

    // --- Nested struct sizes and offsets ---
    .hash_offset = @offsetOf(UINode, "hash"),
    .style_changed_offset = @offsetOf(UINode, "style_changed"),
    .props_changed_offset = @offsetOf(UINode, "props_changed"),
    .dirty_offset = @offsetOf(UINode, "dirty"),
    .hooks_offset = @offsetOf(UINode, "hooks"),
    .style_hash_offset = @offsetOf(UINode, "style_hash"),
    .accessibility_offset = @offsetOf(UINode, "accessibility"),
};

// Export memory layout information for JavaScript to correctly read the struct
// Export function to get a pointer to the memory layout information
// Corrected layout information
pub var layout_info = packed struct {
    render_command_size: u32,

    // Offsets within RenderCommand
    elem_type_offset: u32,
    text_ptr_offset: u32,
    href_ptr_offset: u32,
    id_ptr_offset: u32,
    index_offset: u32,
    hooks_offset: u32,
    node_ptr_offset: u32,
    classname_ptr_offset: u32,

    // Offsets for fields inside the nested 'style' struct
    style_btn_id_offset: u32,
    style_dialog_id_offset: u32,
    style_exit_animation_ptr_offset: u32,

    // Offsets for fields inside the nested 'hover' struct
    hover_size: u32,
    hover_offset: u32,

    // Offsets for fields inside the nested 'focus' struct
    focus_size: u32,
    focus_offset: u32,

    // Offsets for fields inside the nested 'focus_within' struct
    focus_within_size: u32,
    focus_within_offset: u32,
    render_type_offset: u32,
    tooltip_size: u32,
    tooltip_offset: u32,
    has_children_offset: u32,
    hash_offset: u32,
    style_changed_offset: u32,
    props_changed_offset: u32,
}{
    .render_command_size = @sizeOf(RenderCommand),

    // --- Direct fields of RenderCommand ---
    .elem_type_offset = @offsetOf(RenderCommand, "elem_type"),
    .text_ptr_offset = @offsetOf(RenderCommand, "text"),
    .href_ptr_offset = @offsetOf(RenderCommand, "href"),
    .id_ptr_offset = @offsetOf(RenderCommand, "id"),
    .index_offset = @offsetOf(RenderCommand, "index"),
    .hooks_offset = @offsetOf(RenderCommand, "hooks"),
    .node_ptr_offset = @offsetOf(RenderCommand, "node_ptr"),
    .classname_ptr_offset = @offsetOf(RenderCommand, "class"),

    // --- Absolute offsets for fields within the nested 'style' struct ---
    .style_btn_id_offset = @offsetOf(RenderCommand, "style") + @offsetOf(Style, "btn_id"),
    .style_dialog_id_offset = @offsetOf(RenderCommand, "style") + @offsetOf(Style, "dialog_id"),
    .style_exit_animation_ptr_offset = @offsetOf(RenderCommand, "style") + @offsetOf(Style, "exit_animation"),

    // --- Nested struct sizes and offsets ---
    .hover_offset = @offsetOf(RenderCommand, "hover"),
    .hover_size = @sizeOf(Hover),
    .focus_offset = @offsetOf(RenderCommand, "focus"),
    .focus_size = @sizeOf(Focus),
    .focus_within_offset = @offsetOf(RenderCommand, "focus_within"),
    .focus_within_size = @sizeOf(Focus),
    .render_type_offset = @offsetOf(RenderCommand, "render_type"),
    .tooltip_size = @sizeOf(types.Tooltip),
    .tooltip_offset = @offsetOf(RenderCommand, "tooltip"),
    .has_children_offset = @offsetOf(RenderCommand, "has_children"),
    .hash_offset = @offsetOf(RenderCommand, "hash"),
    .style_changed_offset = @offsetOf(RenderCommand, "style_changed"),
    .props_changed_offset = @offsetOf(RenderCommand, "props_changed"),
};

// Make sure this function is not evaluated at compile time
pub fn hexToRgba(hex_str: []const u8) [4]f32 {
    if (hex_str.len < 7 or hex_str[0] != '#') return .{ 0, 0, 0, 1 };

    // Parse at runtime instead of compile-time
    var r: f32 = 0;
    var g: f32 = 0;
    var b: f32 = 0;

    // Manual hex parsing to avoid compile-time evaluation issues
    r = @floatFromInt(parseHexByte(hex_str[1..3]) catch 0);
    g = @floatFromInt(parseHexByte(hex_str[3..5]) catch 0);
    b = @floatFromInt(parseHexByte(hex_str[5..7]) catch 0);

    return .{ r, g, b, 1 };
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

/// fmtln is a wrapper around std.fmt.allocPrint that allocates memory from the frame allocator
/// this means that this slice is deallocated on each frame
/// this is useful for formatting ids passed into the style struct
pub fn fmtln(
    comptime fmt: []const u8,
    args: anytype,
) []const u8 {
    const allocator = arena(.frame);
    const buf = std.fmt.allocPrint(allocator, fmt, args) catch |err| {
        println("Formatting, Error Could not format argument alloc Error details: {any}\n", .{err});
        return "";
    };
    return buf;
}

pub fn fmtArena(
    comptime fmt: []const u8,
    args: anytype,
    arena_type: ArenaType,
) []const u8 {
    const allocator = arena(arena_type);
    const buf = std.fmt.allocPrint(allocator, fmt, args) catch |err| {
        println("Formatting, Error Could not format argument alloc Error details: {any}\n", .{err});
        return "";
    };
    return buf;
}

pub fn dupe(
    args: []const u8,
    allocator_type: ArenaType,
) []const u8 {
    const allocator = arena(allocator_type);
    const buf = allocator.dupe(u8, args) catch |err| {
        println("Formatting, Error Could not format argument alloc Error details: {any}\n", .{err});
        return "";
    };
    return buf;
}

pub fn pin(value: []const u8) void {
    _ = string_table.intern(value) catch unreachable;
}

pub fn unpin(value: []const u8) void {
    _ = string_table.remove(value) catch unreachable;
}

pub fn compact() void {
    _ = string_table.compact() catch unreachable;
}

pub fn cloneFrame(
    value: anytype,
) []const u8 {
    const T = @TypeOf(value);
    if (T == []const u8) return fmtln("{s}", .{value});
    const allocator = arena(.frame);
    const memory: *@TypeOf(value) = allocator.create(T) catch unreachable;
    memory.* = value;
    return memory.*;
}

pub fn printlnErr(
    comptime fmt: []const u8,
    args: anytype,
) void {
    if (isWasi and build_options.enable_debug) {
        const buf = std.fmt.allocPrint(allocator_global, fmt, args) catch return;
        const buf_with_src = std.fmt.allocPrint(allocator_global, "[%cERROR%c] {s}", .{buf[0..]}) catch return;
        const style_1 = "color: #FF3029;";
        const style_2 = "";
        _ = Wasm.consoleLogColoredWasm(buf_with_src.ptr, buf_with_src.len, style_1[0..].ptr, style_1.len, style_2[0..].ptr, style_2.len);
        allocator_global.free(buf_with_src);
        allocator_global.free(buf);
    }
}

pub fn printErr(
    comptime fmt: []const u8,
    args: anytype,
) void {
    if (isWasi and build_options.enable_debug) {
        const buf = std.fmt.allocPrint(allocator_global, fmt, args) catch return;
        const buf_with_src = std.fmt.allocPrint(allocator_global, "[%cERROR%c] {s}", .{buf[0..]}) catch return;
        const style_1 = "color: #FF3029;";
        const style_2 = "";
        _ = Wasm.consoleLogColoredErrorWasm(buf_with_src.ptr, buf_with_src.len, style_1[0..].ptr, style_1.len, style_2[0..].ptr, style_2.len);
        allocator_global.free(buf_with_src);
        allocator_global.free(buf);
    }
}

pub fn printWarn(
    comptime fmt: []const u8,
    args: anytype,
) void {
    if (isWasi and build_options.enable_debug) {
        const buf = std.fmt.allocPrint(allocator_global, fmt, args) catch return;
        const buf_with_src = std.fmt.allocPrint(allocator_global, "[%cWARN%c] {s}", .{buf[0..]}) catch return;
        const style_1 = "color: #FFA629;";
        const style_2 = "";
        _ = Wasm.consoleLogColoredWarnWasm(buf_with_src.ptr, buf_with_src.len, style_1[0..].ptr, style_1.len, style_2[0..].ptr, style_2.len);
        allocator_global.free(buf_with_src);
        allocator_global.free(buf);
    }
}

pub fn printInfo(
    comptime fmt: []const u8,
    args: anytype,
) void {
    if (isWasi and build_options.enable_debug) {
        const buf = std.fmt.allocPrint(allocator_global, fmt, args) catch return;
        const buf_with_src = std.fmt.allocPrint(allocator_global, "[%cINFO%c] {s}", .{buf[0..]}) catch return;
        const style_1 = "color: #4229FF;";
        const style_2 = "";
        _ = Wasm.consoleLogColoredWasm(buf_with_src.ptr, buf_with_src.len, style_1[0..].ptr, style_1.len, style_2[0..].ptr, style_2.len);
        allocator_global.free(buf_with_src);
        allocator_global.free(buf);
    }
}

pub fn printDebug(
    comptime fmt: []const u8,
    args: anytype,
) void {
    if (isWasi and build_options.enable_debug) {
        const buf = std.fmt.allocPrint(allocator_global, fmt, args) catch return;
        const buf_with_src = std.fmt.allocPrint(allocator_global, "[%cDEBUG%c] {s}", .{buf[0..]}) catch return;
        const style_1 = "color: #FF29F4;";
        const style_2 = "";
        _ = Wasm.consoleLogColoredWasm(buf_with_src.ptr, buf_with_src.len, style_1[0..].ptr, style_1.len, style_2[0..].ptr, style_2.len);
        allocator_global.free(buf_with_src);
        allocator_global.free(buf);
    }
}

pub fn printlnSrcErr(
    comptime fmt: []const u8,
    args: anytype,
    src: std.builtin.SourceLocation,
) void {
    if (isWasi and build_options.enable_debug) {
        const buf = std.fmt.allocPrint(allocator_global, fmt, args) catch return;
        const buf_with_src = std.fmt.allocPrint(allocator_global, "[Vapor] [%cERROR:{s}:{d}%c]\n{s}", .{ src.file, src.line, buf[0..] }) catch return;
        const style_1 = "color: #FF3029;";
        const style_2 = "";
        _ = Wasm.consoleLogColoredWasm(buf_with_src.ptr, buf_with_src.len, style_1[0..].ptr, style_1.len, style_2[0..].ptr, style_2.len);
        allocator_global.free(buf_with_src);
        allocator_global.free(buf);
    }
}

pub fn printlnWithColor(
    comptime fmt: []const u8,
    args: anytype,
    color: []const u8,
    title: []const u8,
) void {
    const buf = std.fmt.allocPrint(allocator_global, fmt, args) catch return;
    const color_buf = std.fmt.allocPrint(allocator_global, "color: {s};", .{color}) catch return;
    const buf_with_src = std.fmt.allocPrint(allocator_global, "[Vapor] [%c{s}%c] {s}", .{ title, buf[0..] }) catch return;
    // const style_2 = "";
    // _ = consoleLogColoredWasm(buf_with_src.ptr, buf_with_src.len, color_buf[0..].ptr, color_buf.len, style_2[0..].ptr, style_2.len);
    allocator_global.free(buf_with_src);
    allocator_global.free(color_buf);
    allocator_global.free(buf);
}

fn convertColorToString(color: Types.Color) []const u8 {
    return switch (color) {
        .Literal => |rgba| rgbaToString(rgba),
        else => "",
    };
}

fn rgbaToString(rgba: Types.Rgba) []const u8 {
    return std.fmt.allocPrint(allocator_global, "rgba({d},{d},{d},{d})", .{
        rgba.r,
        rgba.g,
        rgba.b,
        rgba.a,
    }) catch return "";
}

pub fn printlnColor(
    comptime fmt: []const u8,
    args: anytype,
    color: Types.Color,
) void {
    if (isWasi and build_options.enable_debug) {
        const buf = std.fmt.allocPrint(allocator_global, fmt, args) catch return;
        const color_buf = std.fmt.allocPrint(allocator_global, "color: {s};", .{convertColorToString(color)}) catch return;
        const buf_with_src = std.fmt.allocPrint(allocator_global, "%c{s}%c", .{buf[0..]}) catch return;
        const style_2 = "";
        _ = Wasm.consoleLogColoredWasm(buf_with_src.ptr, buf_with_src.len, color_buf[0..].ptr, color_buf.len, style_2[0..].ptr, style_2.len);
        allocator_global.free(buf_with_src);
        allocator_global.free(color_buf);
        allocator_global.free(buf);
    }
}

pub fn printlnAllocation(
    comptime fmt: []const u8,
    args: anytype,
) void {
    const buf = std.fmt.allocPrint(allocator_global, fmt, args) catch return;
    const buf_with_src = std.fmt.allocPrint(allocator_global, "[Vapor] [%cALLOC%c] {s}", .{buf[0..]}) catch return;
    // const style_1 = "color: #744EFF;";
    // const style_2 = "";
    // _ = consoleLogColoredWasm(buf_with_src.ptr, buf_with_src.len, style_1[0..].ptr, style_1.len, style_2[0..].ptr, style_2.len);
    allocator_global.free(buf_with_src);
    allocator_global.free(buf);
}

pub fn printlnSrc(
    comptime fmt: []const u8,
    args: anytype,
    src: std.builtin.SourceLocation,
) void {
    if (isWasi and build_options.enable_debug) {
        const buf = std.fmt.allocPrint(allocator_global, fmt, args) catch return;
        const buf_with_src = std.fmt.allocPrint(allocator_global, "[%c{s}:{d}%c]\n[MSG] {s}", .{ src.file, src.line, buf[0..] }) catch return;
        const style_1 = "color: #3CE98A;";
        const style_2 = "";
        _ = Wasm.consoleLogColoredWasm(buf_with_src.ptr, buf_with_src.len, style_1[0..].ptr, style_1.len, style_2[0..].ptr, style_2.len);
        allocator_global.free(buf_with_src);
        allocator_global.free(buf);
    }
}

pub fn print(
    comptime fmt: []const u8,
    args: anytype,
) void {
    if (isWasi and build_options.enable_debug) {
        const buf = std.fmt.allocPrint(allocator_global, fmt, args) catch return;
        _ = Wasm.consoleLogWasm(buf.ptr, buf.len);
        allocator_global.free(buf);
    } else if (!isWasi) {
        std.debug.print(fmt, args);
    }
}

pub fn println(
    comptime fmt: []const u8,
    args: anytype,
) void {
    if (isWasi and build_options.enable_debug) {
        const buf = std.fmt.allocPrint(allocator_global, fmt, args) catch return;
        _ = Wasm.consoleLogWasm(buf.ptr, buf.len);
        allocator_global.free(buf);
    } else if (!isWasi) {
        std.debug.print(fmt, args);
    }
}

pub const ErasedEventCallback = struct {
    ctx: *anyopaque,
    callFn: *const fn (*anyopaque, *Event) void,
    event_type: EventType,
    dynamic_object: ?*DynamicObject = null,

    pub fn call(self: *const ErasedEventCallback, evt: *Event) void {
        self.callFn(self.ctx, evt);
    }

    pub fn make(allocator: std.mem.Allocator, event_type: EventType, cb: anytype, args: anytype) !ErasedEventCallback {
        const Args = @TypeOf(args);

        const Closure = struct {
            arguments: Args,

            fn run(ptr: *anyopaque, evt: *Event) void {
                const self: *@This() = @ptrCast(@alignCast(ptr));
                // cb is comptime-captured, append evt to the args
                @call(.auto, cb, self.arguments ++ .{evt});
            }
        };

        const closure = try allocator.create(Closure);
        closure.* = .{ .arguments = args };

        return .{
            .ctx = @ptrCast(closure),
            .callFn = Closure.run,
            .event_type = event_type,
        };
    }
};

pub const ErasedCallback = struct {
    ctx: *anyopaque,
    callFn: *const fn (*anyopaque) void,
    deinitFn: *const fn (*anyopaque) void,

    pub fn call(self: *ErasedCallback) void {
        self.callFn(self.ctx);
    }

    pub fn deinit(self: *ErasedCallback) void {
        self.deinitFn(self.ctx);
    }

    pub fn make(allocator: std.mem.Allocator, cb: anytype, args: anytype) !ErasedCallback {
        const Args = @TypeOf(args);

        // cb is captured by the comptime closure below — not stored in the struct
        const Closure = struct {
            arguments: Args,

            fn run(ptr: *anyopaque) void {
                const self: *@This() = @ptrCast(@alignCast(ptr));
                @call(.auto, cb, self.arguments);
            }

            fn destroy(_: *anyopaque) void {
                // const self: *@This() = @ptrCast(@alignCast(ptr));
                // allocator.destroy(self);
            }
        };

        const closure = try allocator.create(Closure);
        closure.* = .{
            .arguments = args,
        };

        return .{
            .ctx = @ptrCast(closure),
            .callFn = Closure.run,
            .deinitFn = Closure.destroy,
        };
    }
};

pub fn loopInterval(name: []const u8, delay_ms: u32, cb: anytype, args: anytype) void {
    const erased = ErasedCallback.make(allocator_global, cb, args) catch |err| {
        println("Error could not create closure {any}\n", .{err});
        return;
    };

    const callback_id = hashKey(name);
    // Store just the ErasedCallback instead of *Node
    erased_registry.put(callback_id, erased) catch |err| {
        println("Registry error {any}\n", .{err});
        return;
    };

    if (isWasi) {
        Wasm.createInterval(callback_id, delay_ms);
    }
}

// The JS/WASM side calls back with the id:
export fn invokeErasedCallback(id: u32) void {
    var erased = erased_registry.get(id) orelse return;
    erased.call();
    if (Vapor.mode == .atomic) {
        Vapor.cycle();
    }
}

// /// name: name of the interval
// /// cb: callback function
// /// args: arguments to pass to the callback function
// /// delay: delay in ms
// pub fn loopInterval(name: []const u8, delay_ms: u32, cb: anytype, args: anytype) void {
//     const Args = @TypeOf(args);
//     const Closure = struct {
//         arguments: Args,
//         run_node: Node = .{ .data = .{ .runFn = runFn, .deinitFn = deinitFn } },
//         //
//         fn runFn(action: *Action) void {
//             const run_node: *Node = @fieldParentPtr("data", action);
//             const closure: *@This() = @alignCast(@fieldParentPtr("run_node", run_node));
//             @call(.auto, cb, closure.arguments);
//         }
//         //
//         fn deinitFn(node: *Node) void {
//             const closure: *@This() = @alignCast(@fieldParentPtr("run_node", node));
//             allocator_global.destroy(closure);
//         }
//     };
//
//     const closure = allocator_global.create(Closure) catch |err| {
//         println("Error could not create closure {any}\n ", .{err});
//         unreachable;
//     };
//     closure.* = .{
//         .arguments = args,
//     };
//
//     const callback_id = hashKey(name);
//     ctx_callback_registry.put(callback_id, &closure.run_node) catch |err| {
//         println("Button Function Registry {any}\n", .{err});
//     };
//
//     if (isWasi) {
//         Wasm.createInterval(callback_id, delay_ms);
//     } else {
//         return;
//     }
// }

pub fn registerCtxTimeout(callback_name: []const u8, ms: u32, cb: anytype, args: anytype) void {
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

    const callback_id = hashKey(callback_name);
    ctx_callback_registry.put(callback_id, &closure.run_node) catch |err| {
        println("Button Function Registry {any}\n", .{err});
    };

    if (isWasi) {
        Wasm.timeoutCtx(ms, callback_id);
    } else {
        return;
    }
}

pub fn cancelTimeout(callback_name: []const u8) void {
    const callback_id = hashKey(callback_name);
    if (isWasi) {
        Wasm.cancelTimeoutWasm(callback_id);
    }
}

pub fn registerTimeout(ms: u32, cb: *const fn () void) void {
    const id = callback_registry.count() + 1;
    callback_registry.put(id, cb) catch |err| {
        println("Button Function Registry {any}\n", .{err});
    };
    if (isWasi) {
        Wasm.timeout(ms, id);
    } else {
        return;
    }
}

pub fn setCookie(cookie: []const u8) void {
    if (!isWasi) return;
    Wasm.setCookieWasm(cookie.ptr, cookie.len);
}

pub fn getCookies() []const u8 {
    const cookie = Wasm.getCookiesWasm();
    return std.mem.span(cookie);
}

pub fn getCookie(name: []const u8) ?[]const u8 {
    if (!isWasi) return null;
    const cookie = Wasm.getCookieWasm(name.ptr, name.len);
    if (cookie == null) return null;
    return std.mem.span(cookie);
}

pub const Clipboard = struct {
    pub fn copy(text: []const u8) void {
        if (isWasi) {
            Wasm.copyTextWasm(text.ptr, text.len);
        }
    }
    fn paste(_: []const u8) void {}
};

pub fn onEnd(callback: *const fn () void) void {
    on_end_funcs.append(callback) catch |err| {
        printlnErr("Button Function Registry {any}\n", .{err});
    };
}

pub fn onPopState(callback: *const fn () void) void {
    pop_state_funcs.append(callback) catch |err| {
        printlnErr("Button Function Registry {any}\n", .{err});
    };
}

pub fn onPushState(callback: *const fn () void) void {
    push_state_funcs.append(callback) catch |err| {
        printlnErr("Button Function Registry {any}\n", .{err});
    };
}

pub const Binded = Element;

pub fn onEndCtx(callback: anytype, args: anytype) void {
    const Args = @TypeOf(args);
    const Closure = struct {
        arguments: Args,
        run_node: Vapor.Node = .{ .data = .{ .runFn = runFn, .deinitFn = deinitFn } },
        //
        fn runFn(action: *Vapor.Action) void {
            const run_node: *Vapor.Node = @fieldParentPtr("data", action);
            const closure: *@This() = @alignCast(@fieldParentPtr("run_node", run_node));
            @call(.auto, callback, closure.arguments);
        }
        //
        fn deinitFn(node: *Vapor.Node) void {
            const closure: *@This() = @alignCast(@fieldParentPtr("run_node", node));
            Vapor.allocator_global.destroy(closure);
        }
    };

    const closure = Vapor.allocator_global.create(Closure) catch |err| {
        println("Error could not create closure {any}\n ", .{err});
        unreachable;
    };
    closure.* = .{
        .arguments = args,
    };

    Vapor.on_end_ctx_funcs.append(&closure.run_node) catch |err| {
        println("Hooks Function Registry {any}\n", .{err});
    };
}

/// This hook takes a function callback and calls it after the virtual dom has been created
/// WARNING: This is a dangerous hook, and can cause infinite loops
pub fn onCommit(callback: *const fn () void) void {
    on_commit_funcs.append(callback) catch |err| {
        printlnErr("Button Function Registry {any}\n", .{err});
    };
}

pub fn onCommitCtx(callback: anytype, args: anytype) void {
    const Args = @TypeOf(args);
    const Closure = struct {
        arguments: Args,
        run_node: Vapor.Node = .{ .data = .{ .runFn = runFn, .deinitFn = deinitFn } },
        //
        fn runFn(action: *Vapor.Action) void {
            const run_node: *Vapor.Node = @fieldParentPtr("data", action);
            const closure: *@This() = @alignCast(@fieldParentPtr("run_node", run_node));
            @call(.auto, callback, closure.arguments);
        }
        //
        fn deinitFn(node: *Vapor.Node) void {
            const closure: *@This() = @alignCast(@fieldParentPtr("run_node", node));
            Vapor.allocator_global.destroy(closure);
        }
    };

    const closure = Vapor.arena(.frame).create(Closure) catch |err| {
        println("Error could not create closure {any}\n ", .{err});
        unreachable;
    };
    closure.* = .{
        .arguments = args,
    };

    Vapor.on_commit_ctx_funcs.append(&closure.run_node) catch |err| {
        println("Hooks Function Registry {any}\n", .{err});
    };
}

pub fn onCommitCtxCallback() void {
    const length = Vapor.on_commit_ctx_funcs.items.len;
    if (length == 0) return;
    var i: usize = length - 1;
    while (i >= 0) : (i -= 1) {
        const node = Vapor.on_commit_ctx_funcs.orderedRemove(i);
        @call(.auto, node.data.runFn, .{&node.data});
        if (i == 0) return;
    }
}

pub fn alert(comptime fmt: []const u8, args: anytype) void {
    if (isWasi) {
        const message = Vapor.fmtln(fmt, args);
        Wasm.alertWasm(message.ptr, message.len);
    }
}

pub fn checkWasmMemory() void {
    Wasm.checkMemoryGrowthWasm();
}

// pub const API = struct {
// --- Context & Callbacks ---

pub export fn onEndCtxCallback() callconv(.c) void {
    const length = Vapor.on_end_ctx_funcs.items.len;
    if (length == 0) return;
    var i: usize = length - 1;
    while (i >= 0) : (i -= 1) {
        const node = Vapor.on_end_ctx_funcs.orderedRemove(i);
        @call(.auto, node.data.runFn, .{&node.data});
        if (i == 0) return;
    }
}

pub export fn getVideo(uinode: *UINode) callconv(.c) ?*const types.Video {
    if (uinode.video) |video| {
        return video;
    }
    return null;
}

export fn hooksMountedCallbackCtx(id: u32) void {
    const kv = Vapor.mounted_ctx_funcs.fetchRemove(id) orelse {
        printlnSrcErr("Mounted Function {d} not found\n", .{id}, @src());
        return;
    };
    const node = kv.value;
    @call(.auto, node.data.runFn, .{&node.data});
}

// pub export fn clearOnEnd() callconv(.c) void {
//     on_end_funcs.clearRetainingCapacity();
// }

pub export fn onEndCallback() callconv(.c) void {
    const length = Vapor.on_end_funcs.items.len;
    if (length == 0) return;
    var i: usize = length - 1;
    while (i >= 0) : (i -= 1) {
        const call = Vapor.on_end_funcs.orderedRemove(i);
        @call(.auto, call, .{});
        if (i == 0) return;
    }
}

pub export fn onPopStateCallback() callconv(.c) void {
    const length = Vapor.pop_state_funcs.items.len;
    if (length == 0) return;
    var i: usize = length - 1;
    while (i >= 0) : (i -= 1) {
        const call = Vapor.pop_state_funcs.items[i];
        @call(.auto, call, .{});
        if (i == 0) return;
    }
}

pub export fn onPushStateCallback() callconv(.c) void {
    const length = Vapor.push_state_funcs.items.len;
    if (length == 0) return;
    var i: usize = length - 1;
    while (i >= 0) : (i -= 1) {
        const call = Vapor.push_state_funcs.orderedRemove(i);
        @call(.auto, call, .{});
        if (i == 0) return;
    }
}

pub export fn callbackCtx(callback_ptr: u32, object_ptr: ?*DynamicObject) callconv(.c) void {
    const node = Vapor.ctx_callback_registry.get(callback_ptr) orelse {
        Vapor.printlnSrcErr("Callback not found\n", .{}, @src());
        return;
    };
    node.data.dynamic_object = object_ptr;
    @call(.auto, node.data.runFn, .{&node.data});
    if (Vapor.mode == .atomic) {
        Vapor.cycle();
    }
}

// --- Rendering & Tree Management ---

pub export fn renderUI(route: [*:0]u8) callconv(.c) u32 {
    Vapor.renderCycle(route) catch |err| {
        printlnSrcErr("Error while rendering", .{}, @src());
        switch (err) {
            error.NoRouteFound => {
                printlnSrcErr("No Route found", .{}, @src());
            },
        }
        return 0;
    };
    return 1;
}

pub export fn getRenderTreePtr() callconv(.c) ?*UIContext.CommandsTree {
    const tree_op = Vapor.current_ctx.ui_tree;
    if (tree_op != null) {
        return Vapor.current_ctx.ui_tree.?;
    }
    return null;
}

pub export fn getRenderUINodeRootPtr() callconv(.c) ?*UINode {
    if (Vapor.current_ctx.root == null) return null;
    return Vapor.current_ctx.root.?;
}

pub export fn getUINodeChildrenCount(node_ptr: ?*UINode) callconv(.c) usize {
    const node = node_ptr orelse return 0;
    return node.children_count;
}

pub export fn getUINodeChild(node_ptr: ?*UINode, index: u32) callconv(.c) ?*UINode {
    const node = node_ptr orelse return null;
    return node.childAt(index);
}

// Zig side - export first child and next sibling
pub export fn getUINodeFirstChild(node_ptr: ?*UINode) callconv(.c) ?*UINode {
    const node = node_ptr orelse return null;
    return node.first_child;
}

pub export fn getUINodeNextSibling(node_ptr: ?*UINode) callconv(.c) ?*UINode {
    const node = node_ptr orelse return null;
    return node.next_sibling;
}

pub export fn getDirtyNodeCount() callconv(.c) usize {
    return Vapor.dirty_nodes.items.len;
}

pub export fn markCurrentTreeNotDirty() callconv(.c) void {
    if (!Vapor.has_context) return;
    const root = Vapor.current_ctx.root orelse return;
    Vapor.markChildrenNotDirty(root);
}

// --- Layout & Allocation ---

pub export fn allocateLayoutInfo() callconv(.c) *u8 {
    const info_ptr: *u8 = @ptrCast(&Vapor.layout_info);
    return info_ptr;
}

pub export fn allocateUINodeLayoutInfo() callconv(.c) *u8 {
    const ui_info_ptr: *u8 = @ptrCast(&Vapor.ui_node_layout_info);
    return ui_info_ptr;
}

pub export fn allocUint8(length: u32) callconv(.c) [*]const u8 {
    const slice = Vapor.allocator_global.alloc(u8, length) catch
        @panic("failed to allocate memory");
    return slice.ptr;
}

pub export fn allocUint8Frame(length: u32) callconv(.c) [*]const u8 {
    const slice = Vapor.getFrameAllocator().alloc(u8, length) catch
        @panic("failed to allocate memory");
    return slice.ptr;
}

pub export fn allocate(size: usize) callconv(.c) ?[*]f32 {
    const buf = Vapor.allocator_global.alloc(f32, size) catch |err| {
        Vapor.println("{any}\n", .{err});
        return null;
    };
    return buf.ptr;
}

pub export fn allocateU32(size: usize) callconv(.c) ?[*]u32 {
    const buf = Vapor.arena(.persist).alloc(u32, size) catch |err| {
        Vapor.println("{any}\n", .{err});
        return null;
    };
    return buf.ptr;
}

// --- CSS & Commands ---

pub export fn getCSS() callconv(.c) ?[*]const u8 {
    return Vapor.generator.buffer[0..Vapor.generator.end].ptr;
}

pub export fn getCSSLen() callconv(.c) usize {
    return Vapor.generator.end;
}

pub export fn getRenderCommandPtr(tree: *CommandsTree) callconv(.c) [*]u8 {
    if (std.mem.eql(u8, tree.node.id, "global-style")) {
        Vapor.println("getRenderCommandPtr {any}\n", .{tree.node.node_ptr.dirty});
    }
    return @ptrCast(tree.node);
}

pub export fn getTreeNodeChildrenCount(tree: *CommandsTree) callconv(.c) usize {
    return tree.children.items.len;
}

pub export fn getTreeNodeChild(tree: *CommandsTree, index: usize) callconv(.c) *CommandsTree {
    const child = tree.children.items[index];
    return child;
}

pub export fn getRenderCommandSize() callconv(.c) usize {
    return @sizeOf(RenderCommand);
}

// --- Removal Handling ---

pub export fn shouldRerender() callconv(.c) bool {
    return Vapor.global_rerender;
}

pub export fn rerenderEverything() callconv(.c) bool {
    return Vapor.rerender_everything;
}

pub export fn hasDirty() callconv(.c) bool {
    return Vapor.has_dirty;
}

pub export fn resetRerender() callconv(.c) void {
    Vapor.global_rerender = false;
    Vapor.rerender_everything = false;
    Vapor.has_dirty = false;
    Vapor.status = .{};
}

pub export fn callRouteRenderCycle(ptr: [*:0]u8) callconv(.c) u32 {
    Packer.animations.clearRetainingCapacity();
    Packer.layouts.clearRetainingCapacity();
    Packer.positions.clearRetainingCapacity();
    Packer.margins_paddings.clearRetainingCapacity();
    Packer.visuals.clearRetainingCapacity();
    Packer.interactives.clearRetainingCapacity();
    Packer.transforms.clearRetainingCapacity();
    UIContext.element_style_hash_map.clearRetainingCapacity();
    Vapor.renderCycle(ptr) catch |err| {
        printlnSrcErr("Error while rendering", .{}, @src());
        switch (err) {
            error.NoRouteFound => {
                printlnSrcErr("No Route found", .{}, @src());
            },
        }
        return 0;
    };
    Vapor.markChildrenDirty(Vapor.current_ctx.root.?);
    return 1;
}

pub export fn setRouteRenderTree(ptr: [*:0]u8) callconv(.c) u32 {
    Vapor.renderCycle(ptr) catch |err| {
        printlnSrcErr("Error while rendering", .{}, @src());
        switch (err) {
            error.NoRouteFound => {
                printlnSrcErr("No Route found", .{}, @src());
            },
        }
        return 0;
    };
    return 1;
}

pub export fn setRerenderTrue() callconv(.c) void {
    Vapor.cycle();
}

pub export fn getDirtyValue(node: *UINode) callconv(.c) bool {
    return node.dirty;
}
// };

// // --- Auto-Export Magic ---
// comptime {
//     const decls = std.meta.declarations(API);
//     for (decls) |decl| {
//         // We only care about public functions inside the API struct
//         const val = @field(API, decl.name);
//         const Type = @TypeOf(val);
//
//         // Check if it is a function
//         if (@typeInfo(Type) == .@"fn") {
//             // Export it using its declared name
//             @export(&val, .{ .name = decl.name });
//         }
//     }
// }

pub const std_options = std.Options{
    // Set the log level (optional, defaults to .info in safe modes)
    .log_level = .debug,

    // Override the log function
    .logFn = log,
};

pub fn log(
    comptime level: std.log.Level,
    comptime scope: @Type(.enum_literal),
    comptime format: []const u8,
    args: anytype,
) void {
    _ = scope;
    if (isWasi and build_options.enable_debug) {
        switch (level) {
            .err => _ = printErr(format, args),
            .warn => _ = printWarn(format, args),
            .info => _ = printInfo(format, args),
            .debug => _ = printDebug(format, args),
        }
        // const allocator = Vapor.arena(.persist);
        // const buf = std.fmt.allocPrint(allocator, format, args) catch return;
        // const buf_with_src = std.fmt.allocPrint(allocator, "[{any}] [{any}] {s}", .{ level, scope, buf[0..] }) catch return;
        // _ = Vapor.Wasm.consoleLogWasm(buf_with_src.ptr, buf_with_src.len);
        // Vapor.arena(.persist).free(buf_with_src);
        // Vapor.arena(.persist).free(buf);
    } else if (!isWasi) {
        std.debug.print(format, args);
    }
    // Implementation that calls a 'jsLog' extern function
    // similar to the panic handler above.
}

// pub const StackFrameType = enum {
//     wasm,
//     js,
//     unknown,
// };
//
// pub const StackFrame = struct {
//     function: ?[]const u8 = null,
//     wasm_function_index: ?u32 = null,
//     wasm_offset: ?[]const u8 = null,
//     file: ?[]const u8 = null,
//     line: ?u32 = null,
//     column: ?u32 = null,
//     frame_type: StackFrameType = .unknown,
//     raw: ?[]const u8 = null,
// };
//
// pub const WasmError = struct {
//     type: []const u8,
//     message: []const u8,
//     is_wasm_trap: bool,
//     crash_site: ?StackFrame = null,
//     user_stack: []const StackFrame,
//
//     pub fn deinit(self: *WasmError, allocator: std.mem.Allocator) void {
//         allocator.free(self.user_stack);
//         allocator.free(self.full_stack);
//     }
// };
//
// pub fn parseWasmError(allocator: std.mem.Allocator, json_str: []const u8) !WasmError {
//     const parsed = try std.json.parseFromSlice(std.json.Value, allocator, json_str, .{});
//     defer parsed.deinit();
//
//     const root = parsed.value.object;
//
//     const err_type = if (root.get("type")) |v| v.string else "RuntimeError";
//     const message = if (root.get("message")) |v| v.string else "unknown";
//     const is_wasm_trap = if (root.get("isWasmTrap")) |v| v.bool else false;
//
//     const crash_site = if (root.get("crashSite")) |v| blk: {
//         if (v == .null) break :blk null;
//         break :blk try parseStackFrame(v.object);
//     } else null;
//
//     const user_stack = if (root.get("userStack")) |v|
//         try parseStackArray(allocator, v.array)
//     else
//         try allocator.alloc(StackFrame, 0);
//
//     return WasmError{
//         .type = err_type,
//         .message = message,
//         .is_wasm_trap = is_wasm_trap,
//         .crash_site = crash_site,
//         .user_stack = user_stack,
//     };
// }
//
// fn parseStackFrame(obj: std.json.ObjectMap) !StackFrame {
//     const frame_type: StackFrameType = if (obj.get("type")) |v| blk: {
//         const s = v.string;
//         if (std.mem.eql(u8, s, "wasm")) break :blk .wasm;
//         if (std.mem.eql(u8, s, "js")) break :blk .js;
//         break :blk .unknown;
//     } else .unknown;
//
//     return StackFrame{
//         .function = if (obj.get("function")) |v| switch (v) {
//             .string => |s| s,
//             else => null,
//         } else null,
//         .wasm_function_index = if (obj.get("wasmFunctionIndex")) |v| switch (v) {
//             .integer => |i| @intCast(i),
//             else => null,
//         } else null,
//         .wasm_offset = if (obj.get("wasmOffset")) |v| switch (v) {
//             .string => |s| s,
//             else => null,
//         } else null,
//         .file = if (obj.get("file")) |v| switch (v) {
//             .string => |s| s,
//             else => null,
//         } else null,
//         .line = if (obj.get("line")) |v| switch (v) {
//             .integer => |i| @intCast(i),
//             else => null,
//         } else null,
//         .column = if (obj.get("column")) |v| switch (v) {
//             .integer => |i| @intCast(i),
//             else => null,
//         } else null,
//         .raw = if (obj.get("raw")) |v| switch (v) {
//             .string => |s| s,
//             else => null,
//         } else null,
//         .frame_type = frame_type,
//     };
// }
//
// fn parseStackArray(allocator: std.mem.Allocator, stack_array: std.json.Array) ![]const StackFrame {
//     var frames = try allocator.alloc(StackFrame, stack_array.items.len);
//     for (stack_array.items, 0..) |item, i| {
//         frames[i] = try parseStackFrame(item.object);
//     }
//     return frames;
// }
//
// const EventData = struct {
//     id: []const u8,
// };
//
// pub var trace_buffer: Structures.RingBuffer(TraceEvent, 128) = .{};
//
// pub const RequestContext = struct {
//     method: []const u8 = "GET",
//     url: []const u8 = "",
//     status_code: ?u32 = null,
//     body: ?[]const u8 = null,
//     elapsed_ms: ?i64 = null,
// };
//
// pub const TraceEvent = struct {
//     timestamp: i64,
//     event_type: enum { click, dblclick, hover, mousemove, input, scroll, state_change },
//     element_id: ?[]const u8,
//     serialized_args: []const u8,
// };
//
// // ============================================================================
// // Error Report (inbound payload from the client)
// // ============================================================================
//
// pub const ErrorReport = struct {
//     element_id: ?[]const u8 = null,
//     args: ?[]const u8 = null,
//     wasmError: WasmError,
//     events: []const TraceEvent,
//     timestamp: i64,
//
//     // New context fields
//     route: ?[]const u8 = null,
//     url: ?[]const u8 = null,
//     session_id: ?[]const u8 = null,
//     user_agent: ?[]const u8 = null,
//     environment: ?[]const u8 = null,
//     release: ?[]const u8 = null,
//     user_id: ?[]const u8 = null,
//
//     // Optional: the fetch call that triggered the error (if any)
//     request_context: ?RequestContext = null,
// };
//
// // Append list for important events (flush periodically)
// var action_log: Structures.BoundedArray(ErrorReport, 512) = .{};
//
// export fn recordState(err_str: [*:0]u8, event_str: ?[*:0]u8) void {
//     if (isWasi) {
//         const json_err = std.mem.span(err_str);
//         const parsed = parseWasmError(Vapor.arena(.frame), json_err) catch |err| {
//             std.log.err("Error could not parse json {any}\n", .{err});
//             return;
//         };
//         var ids: [][]const u8 = &.{};
//         var ui_node: ?*UINode = null;
//         var event_data: ?EventData = null;
//
//         if (event_str) |event| {
//             const json_event = std.mem.span(event);
//             event_data = Vapor.Kit.Json.parse(EventData, json_event, .frame) catch |err| {
//                 std.log.err("Error could not parse json {any}\n", .{err});
//                 return;
//             };
//             ids = queryComponentIds(.CtxButton) catch |err| {
//                 std.log.err("Error could not query component {any}\n", .{err});
//                 return;
//             };
//             for (ids) |id| {
//                 if (!std.mem.eql(u8, id, event_data.?.id)) continue;
//                 ui_node = queryByUUID(id) catch |err| {
//                     std.log.err("Error could not query component {any}\n", .{err});
//                     return;
//                 };
//             }
//         }
//
//         const events = trace_buffer.snapshotAlloc(Vapor.arena(.frame)) catch return;
//         defer {
//             for (events) |event| {
//                 if (event.element_id) |element_id| {
//                     allocator_global.free(element_id);
//                 }
//             }
//         }
//
//         if (ui_node) |node| {
//             switch (node.type) {
//                 .CtxButton => {
//                     const ctx_callback = ctx_callback_registry.get(hashKey(ui_node.?.uuid)) orelse return;
//                     const argsFn = ctx_callback.data.argsFn orelse return;
//                     const json = @call(.auto, argsFn, .{&ctx_callback.data});
//                     const event = event_data orelse return;
//                     const record = ErrorReport{
//                         .element_id = event.id,
//                         .args = json,
//                         .wasmError = parsed,
//                         .events = events,
//                         .timestamp = std.time.microTimestamp(),
//                         .environment = "dev",
//                         .route = Vapor.Kit.getWindowPath(),
//                         .url = Vapor.Kit.getWindowPath(),
//                     };
//                     const json_record = std.json.Stringify.valueAlloc(Vapor.arena(.frame), record, .{}) catch unreachable;
//                     Vapor.Kit.Fetch.fetch("http://localhost:8080/recordError", .{
//                         .method = .POST,
//                         .body = json_record,
//                     }).handle(handleRecordError);
//                 },
//                 else => {},
//             }
//         } else {
//             const record = ErrorReport{
//                 .element_id = null,
//                 .args = null,
//                 .wasmError = parsed,
//                 .events = events,
//                 .timestamp = std.time.microTimestamp(),
//                 .environment = "dev",
//                 .route = Vapor.Kit.getWindowPath(),
//                 .url = Vapor.Kit.getWindowPath(),
//             };
//
//             // const json =
//             //     \\{"element_id":"test","args":"{}","wasmError":{"type":"RuntimeError","message":"unreachable","is_wasm_trap":true,"crash_site":null,"user_stack":[]},"events":[],"timestamp":1771446261518000}
//             // ;
//             const json_record = std.json.Stringify.valueAlloc(Vapor.arena(.frame), record, .{}) catch unreachable;
//             Vapor.Kit.Fetch.fetch("http://localhost:8080/recordError", .{
//                 .method = .POST,
//                 .body = json_record,
//             }).handle(handleRecordError);
//         }
//     }
// }
//
// fn handleRecordError(response: Vapor.Kit.Response) void {
//     switch (response) {
//         .Ok => |ok| {
//             _ = ok;
//             std.log.err("Recorded Error\n", .{});
//         },
//         .Err => |err| {
//             std.log.err("Error: {s}\n", .{err.message});
//         },
//     }
// }

export fn recordState(err_str: [*:0]u8, event_str: ?[*:0]u8) void {
    _ = err_str;
    _ = event_str;
}
