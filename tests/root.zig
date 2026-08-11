const std = @import("std");
const Vapor = @import("vapor");

const Fetch = Vapor.Fetch.Fetch;


fn noop() void {}

test "public API surface used by docs examples compiles" {
    comptime {
        _ = Vapor.init;
        _ = Vapor.Page;
        _ = Vapor.PageFn;
        _ = Vapor.registerLayout;
        _ = Vapor.onMount;
        _ = Vapor.onLayout;
        _ = Vapor.onCommit;
        _ = Vapor.persist;
        _ = Vapor.view;
        _ = Vapor.frame;
        _ = Vapor.arena;
        _ = Vapor.Fetch.Fetch;
        _ = Vapor.Kit.HttpReq;
        _ = Vapor.TextField;
        _ = Vapor.TextArea;
        _ = Vapor.Style;
        _ = Vapor.Types.ElementType;
        _ = Vapor.IconTokens;

        _ = @TypeOf(Vapor.Text("hello"));
        _ = @TypeOf(Vapor.TextFmt("value: {}", .{42}));
        _ = @TypeOf(Vapor.Button(noop, .{}));
        _ = @TypeOf(Vapor.SubmitButton());
        _ = @TypeOf(Vapor.Stack());
        _ = @TypeOf(Vapor.Row());
        _ = @TypeOf(Vapor.Box());
        _ = @TypeOf(Vapor.Image(.{ .src = "/logo.png", .alt = "Logo" }));
    }
}

fn withFetchRuntime(backing_allocator: std.mem.Allocator) void {
    Vapor.lib.allocator_global = backing_allocator;
    Vapor.lib.frame_arena = @TypeOf(Vapor.lib.frame_arena).init(backing_allocator);
    Fetch.init();
}

test "fetch coalesces shared requests and separates keyless mutations" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    withFetchRuntime(arena.allocator());
    defer Vapor.lib.frame_arena.deinit();

    const get_a = Fetch.fetch("/api/accounts", .{ .method = .GET });
    const get_b = Fetch.fetch("/api/accounts", .{ .method = .GET });
    try std.testing.expectEqual(@intFromPtr(get_a), @intFromPtr(get_b));
    try std.testing.expectEqual(@as(?u16, null), get_a.pool_slot);

    const post_a = Fetch.fetch("/api/accounts", .{ .method = .POST });
    const post_b = Fetch.fetch("/api/accounts", .{ .method = .POST });
    try std.testing.expect(@intFromPtr(post_a) != @intFromPtr(post_b));
    try std.testing.expect(post_a.pool_slot != null);
    try std.testing.expect(post_b.pool_slot != null);
}

test "fetch coalesces keyed mutations by explicit key" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    withFetchRuntime(arena.allocator());
    defer Vapor.lib.frame_arena.deinit();

    const keyed_a = Fetch.fetch("/api/sync", .{ .method = .POST, .key = "account-sync" });
    const keyed_b = Fetch.fetch("/api/sync", .{ .method = .POST, .key = "account-sync" });
    const keyed_c = Fetch.fetch("/api/sync", .{ .method = .POST, .key = "other-sync" });

    try std.testing.expectEqual(@intFromPtr(keyed_a), @intFromPtr(keyed_b));
    try std.testing.expect(@intFromPtr(keyed_a) != @intFromPtr(keyed_c));
    try std.testing.expectEqual(@as(?u16, null), keyed_a.pool_slot);
}

const CallbackState = struct {
    calls: usize = 0,
    last_result: ?Vapor.Fetch.Result = null,
};

fn captureFetchResult(result: Vapor.Fetch.Result, state: *CallbackState) void {
    state.calls += 1;
    state.last_result = result;
}

test "fetch mock ok response stores result and invokes callback" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    withFetchRuntime(arena.allocator());
    defer Vapor.lib.frame_arena.deinit();

    const fetch = Fetch.fetch("/api/health", .{ .method = .GET });
    fetch.mock = .{ .ok_response = .{
        .status = 200,
        .body = "{\"ok\":true}",
        .headers = null,
        .url = "/api/health",
        .content_type = "application/json",
        .content_length = 11,
        .elapsed_ms = 3,
        .redirected = false,
    } };

    var state = CallbackState{};
    fetch.handle(captureFetchResult, .{&state});

    try std.testing.expectEqual(@as(usize, 1), state.calls);
    try std.testing.expectEqual(Vapor.Fetch.State.ok, fetch.state());
    try std.testing.expect(fetch.response().?.isOk());
    try std.testing.expectEqualStrings("{\"ok\":true}", state.last_result.?.body().?);
}

test "fetch async callback stores parsed response and clears registry" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    withFetchRuntime(arena.allocator());
    defer Vapor.lib.frame_arena.deinit();

    const fetch = Fetch.fetch("/api/profile", .{ .method = .GET });
    var state = CallbackState{};
    fetch.handle(captureFetchResult, .{&state});

    const callback_id = fetch.entry.in_flight_id.?;
    try std.testing.expectEqual(Vapor.Fetch.State.loading, fetch.state());
    try std.testing.expectEqual(@as(u32, 1), Vapor.Fetch.fetch_callback_registry.count());

    var wire = "{\"ok\":true,\"status\":200,\"body\":\"profile\",\"url\":\"/api/profile\",\"content_type\":\"text/plain\",\"content_length\":7,\"elapsed_ms\":12,\"redirected\":false}".*;
    Vapor.Fetch.resumecallback(callback_id, &wire);

    try std.testing.expectEqual(@as(usize, 1), state.calls);
    try std.testing.expectEqual(Vapor.Fetch.State.ok, fetch.state());
    try std.testing.expectEqual(@as(u32, 0), Vapor.Fetch.fetch_callback_registry.count());
    try std.testing.expectEqualStrings("profile", state.last_result.?.body().?);
}

test "frame allocator reports empty state before route selection" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();

    var frame_allocator = @TypeOf(Vapor.lib.frame_arena).init(arena.allocator());
    defer frame_allocator.deinit();

    try std.testing.expectEqual(@as(usize, 0), frame_allocator.queryBytesUsed());
    try std.testing.expectEqual(@as(usize, 0), frame_allocator.queryNodes());
    try std.testing.expect(frame_allocator.getStats() == null);
    try std.testing.expect(frame_allocator.nodeAlloc() == null);
}

test "frame allocator tracks current route frame stats" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();

    var frame_allocator = @TypeOf(Vapor.lib.frame_arena).init(arena.allocator());
    defer frame_allocator.deinit();

    const route_arena = frame_allocator.createRouteArena();
    defer {
        route_arena.deinit();
        arena.allocator().destroy(route_arena);
    }

    frame_allocator.setCurrentRoute(route_arena);
    frame_allocator.incrementNodeCount();
    frame_allocator.incrementItemCount();
    frame_allocator.addBytesUsed(128);

    const stats = frame_allocator.getStats().?;
    try std.testing.expectEqual(@as(usize, 1), stats.nodes_allocated);
    try std.testing.expectEqual(@as(usize, 1), stats.items_allocated);
    try std.testing.expectEqual(@as(usize, 128), stats.bytes_used);
    try std.testing.expectEqual(@as(usize, 1), frame_allocator.queryNodes());

    frame_allocator.beginFrame();
    const next_stats = frame_allocator.getStats().?;
    try std.testing.expectEqual(@as(usize, 0), next_stats.nodes_allocated);
    try std.testing.expectEqual(@as(usize, 0), next_stats.items_allocated);
    try std.testing.expectEqual(@as(usize, 0), next_stats.bytes_used);
}

const Reconciler = Vapor.Testing.Reconciler;
const UIContext = Vapor.Testing.UIContext;
const UINode = UIContext.UINode;
const FrameAllocator = Vapor.Testing.FrameAllocator;
const RouteFrameArena = FrameAllocator.RouteFrameArena;

const NodeSpec = struct {
    uuid: []const u8,
    index: usize,
    finger_print: u32,
    props_hash: u32 = 0,
    style_hash: u32 = 0,
    hooks_hash: u32 = 0,
    text: ?[]const u8 = null,
    elem_type: Vapor.Types.ElementType = .Text,
};

fn initReconcilerRuntime(allocator: std.mem.Allocator) *RouteFrameArena {
    Vapor.lib.allocator_global = allocator;
    Vapor.lib.frame_arena = FrameAllocator.init(allocator);
    const route_arena = Vapor.lib.frame_arena.createRouteArena();
    Vapor.lib.frame_arena.setCurrentRoute(route_arena);
    Vapor.lib.has_dirty = false;
    Vapor.lib.rerender_everything = false;
    Vapor.Animation.new();
    Vapor.Animation.removal_queue.clearRetainingCapacity();
    return route_arena;
}

fn deinitReconcilerRuntime(allocator: std.mem.Allocator, route_arena: *RouteFrameArena) void {
    route_arena.deinit();
    allocator.destroy(route_arena);
    Vapor.lib.frame_arena.deinit();
}

fn makeNode(allocator: std.mem.Allocator, spec: NodeSpec) !*UINode {
    const node = try allocator.create(UINode);
    node.* = .{
        .uuid = spec.uuid,
        .index = spec.index,
        .finger_print = spec.finger_print,
        .props_hash = spec.props_hash,
        .style_hash = spec.style_hash,
        .hooks_hash = spec.hooks_hash,
        .text = spec.text,
        .type = spec.elem_type,
    };
    return node;
}

fn makeTree(allocator: std.mem.Allocator, specs: []const NodeSpec) !*UINode {
    const root = try makeNode(allocator, .{
        .uuid = "root",
        .index = 0,
        .finger_print = 1,
        .elem_type = .Block,
    });

    for (specs) |spec| {
        const child_node = try makeNode(allocator, spec);
        root.appendChild(child_node);
    }

    return root;
}

fn child(root: *UINode, index: usize) *UINode {
    return root.childAt(index) orelse unreachable;
}

fn expectRemovalId(handle: u32, expected: []const u8) !void {
    const ptr = Vapor.Animation.getRemovalIdPtr(handle) orelse return error.MissingRemoval;
    const len = Vapor.Animation.getRemovalIdLen(handle);
    try std.testing.expectEqualStrings(expected, ptr[0..len]);
}

test "reconciler leaves unchanged same-length children clean" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const route_arena = initReconcilerRuntime(arena.allocator());
    defer deinitReconcilerRuntime(arena.allocator(), route_arena);

    const old_root = try makeTree(arena.allocator(), &.{
        .{ .uuid = "a", .index = 0, .finger_print = 10, .props_hash = 10, .text = "A" },
        .{ .uuid = "b", .index = 1, .finger_print = 20, .props_hash = 20, .text = "B" },
    });
    const new_root = try makeTree(arena.allocator(), &.{
        .{ .uuid = "a", .index = 0, .finger_print = 10, .props_hash = 10, .text = "A" },
        .{ .uuid = "b", .index = 1, .finger_print = 20, .props_hash = 20, .text = "B" },
    });

    Reconciler.traverseNodes(old_root, new_root);

    try std.testing.expect(!Vapor.lib.has_dirty);
    try std.testing.expect(!new_root.dirty);
    try std.testing.expect(!child(new_root, 0).dirty);
    try std.testing.expect(!child(new_root, 1).dirty);
    try std.testing.expectEqual(@as(usize, 0), Vapor.Animation.removalCount());
}

test "reconciler marks text and prop updates dirty without removals" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const route_arena = initReconcilerRuntime(arena.allocator());
    defer deinitReconcilerRuntime(arena.allocator(), route_arena);

    const old_root = try makeTree(arena.allocator(), &.{
        .{ .uuid = "slot-0", .index = 0, .finger_print = 10, .props_hash = 10, .text = "old" },
    });
    const new_root = try makeTree(arena.allocator(), &.{
        .{ .uuid = "slot-0", .index = 0, .finger_print = 11, .props_hash = 11, .text = "new" },
    });

    Reconciler.traverseNodes(old_root, new_root);

    const updated = child(new_root, 0);
    try std.testing.expect(Vapor.lib.has_dirty);
    try std.testing.expect(updated.dirty);
    try std.testing.expect(updated.props_changed);
    try std.testing.expectEqual(@as(usize, 0), Vapor.Animation.removalCount());
}

test "reconciler marks hook updates dirty without structural removals" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const route_arena = initReconcilerRuntime(arena.allocator());
    defer deinitReconcilerRuntime(arena.allocator(), route_arena);

    const old_root = try makeTree(arena.allocator(), &.{
        .{ .uuid = "hooked", .index = 0, .finger_print = 30, .hooks_hash = 1 },
    });
    const new_root = try makeTree(arena.allocator(), &.{
        .{ .uuid = "hooked", .index = 0, .finger_print = 31, .hooks_hash = 2 },
    });

    Reconciler.traverseNodes(old_root, new_root);

    const updated = child(new_root, 0);
    try std.testing.expect(Vapor.lib.has_dirty);
    try std.testing.expect(updated.dirty);
    try std.testing.expect(updated.hooks_changed);
    try std.testing.expectEqual(@as(usize, 0), Vapor.Animation.removalCount());
}

test "reconciler handles keyed same-length reorder without removals" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const route_arena = initReconcilerRuntime(arena.allocator());
    defer deinitReconcilerRuntime(arena.allocator(), route_arena);

    const old_root = try makeTree(arena.allocator(), &.{
        .{ .uuid = "a", .index = 0, .finger_print = 10 },
        .{ .uuid = "b", .index = 1, .finger_print = 20 },
        .{ .uuid = "c", .index = 2, .finger_print = 30 },
    });
    const new_root = try makeTree(arena.allocator(), &.{
        .{ .uuid = "b", .index = 0, .finger_print = 20 },
        .{ .uuid = "a", .index = 1, .finger_print = 10 },
        .{ .uuid = "c", .index = 2, .finger_print = 30 },
    });

    Reconciler.traverseNodes(old_root, new_root);

    try std.testing.expect(Vapor.lib.has_dirty);
    try std.testing.expect(child(new_root, 0).dirty);
    try std.testing.expect(child(new_root, 1).dirty);
    try std.testing.expect(!child(new_root, 2).dirty);
    try std.testing.expectEqual(@as(usize, 0), Vapor.Animation.removalCount());
}

test "reconciler marks keyed tail additions as added" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const route_arena = initReconcilerRuntime(arena.allocator());
    defer deinitReconcilerRuntime(arena.allocator(), route_arena);

    const old_root = try makeTree(arena.allocator(), &.{
        .{ .uuid = "a", .index = 0, .finger_print = 10 },
        .{ .uuid = "b", .index = 1, .finger_print = 20 },
    });
    const new_root = try makeTree(arena.allocator(), &.{
        .{ .uuid = "a", .index = 0, .finger_print = 10 },
        .{ .uuid = "b", .index = 1, .finger_print = 20 },
        .{ .uuid = "c", .index = 2, .finger_print = 30 },
    });

    Reconciler.traverseNodes(old_root, new_root);

    const added = child(new_root, 2);
    try std.testing.expect(Vapor.lib.has_dirty);
    try std.testing.expect(added.dirty);
    try std.testing.expectEqual(Vapor.Types.StateType.added, added.state_type);
    try std.testing.expectEqual(@as(usize, 0), Vapor.Animation.removalCount());
}

test "reconciler queues keyed tail deletions and marks dirty" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const route_arena = initReconcilerRuntime(arena.allocator());
    defer deinitReconcilerRuntime(arena.allocator(), route_arena);

    const old_root = try makeTree(arena.allocator(), &.{
        .{ .uuid = "a", .index = 0, .finger_print = 10 },
        .{ .uuid = "b", .index = 1, .finger_print = 20 },
        .{ .uuid = "c", .index = 2, .finger_print = 30 },
    });
    const new_root = try makeTree(arena.allocator(), &.{
        .{ .uuid = "a", .index = 0, .finger_print = 10 },
        .{ .uuid = "b", .index = 1, .finger_print = 20 },
    });

    Reconciler.traverseNodes(old_root, new_root);

    try std.testing.expect(Vapor.lib.has_dirty);
    try std.testing.expectEqual(@as(usize, 1), Vapor.Animation.removalCount());
    try expectRemovalId(0, "c");
}

test "reconciler replaces same-length keyed children with removal and addition" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const route_arena = initReconcilerRuntime(arena.allocator());
    defer deinitReconcilerRuntime(arena.allocator(), route_arena);

    const old_root = try makeTree(arena.allocator(), &.{
        .{ .uuid = "a", .index = 0, .finger_print = 10 },
        .{ .uuid = "b", .index = 1, .finger_print = 20 },
        .{ .uuid = "c", .index = 2, .finger_print = 30 },
    });
    const new_root = try makeTree(arena.allocator(), &.{
        .{ .uuid = "a", .index = 0, .finger_print = 10 },
        .{ .uuid = "d", .index = 1, .finger_print = 40 },
        .{ .uuid = "c", .index = 2, .finger_print = 30 },
    });

    Reconciler.traverseNodes(old_root, new_root);

    const replacement = child(new_root, 1);
    try std.testing.expect(Vapor.lib.has_dirty);
    try std.testing.expect(replacement.dirty);
    try std.testing.expectEqual(Vapor.Types.StateType.added, replacement.state_type);
    try std.testing.expectEqual(@as(usize, 1), Vapor.Animation.removalCount());
    try expectRemovalId(0, "b");
}

test "reconciler queues all old children when new child list is empty" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const route_arena = initReconcilerRuntime(arena.allocator());
    defer deinitReconcilerRuntime(arena.allocator(), route_arena);

    const old_root = try makeTree(arena.allocator(), &.{
        .{ .uuid = "a", .index = 0, .finger_print = 10 },
        .{ .uuid = "b", .index = 1, .finger_print = 20 },
    });
    const new_root = try makeTree(arena.allocator(), &.{});

    Reconciler.traverseNodes(old_root, new_root);

    try std.testing.expect(Vapor.lib.has_dirty);
    try std.testing.expectEqual(@as(usize, 2), Vapor.Animation.removalCount());
    try expectRemovalId(0, "a");
    try expectRemovalId(1, "b");
}

const RenderVariant = enum { stable, updated, removed };
var render_variant: RenderVariant = .stable;

fn textElement(value: []const u8, element_id: []const u8) void {
    const text_node = Vapor.Text(value).id(element_id);
    text_node.end();
}

fn RenderCyclePage() void {
    const app = Vapor.Stack().id("app");
    app.children({
        switch (render_variant) {
            .stable => {
                textElement("Alpha", "alpha");
                textElement("Beta", "beta");
            },
            .updated => {
                textElement("Alpha changed", "alpha");
                textElement("Beta", "beta");
            },
            .removed => {
                textElement("Alpha changed", "alpha");
            },
        }
    });
}

fn initRenderCycleRuntime(route: []const u8) void {
    Vapor.init(.{});
    Vapor.Animation.new();
    Vapor.lib.resetRerender();
    Vapor.Animation.removal_queue.clearRetainingCapacity();
    render_variant = .stable;
    Vapor.Page(.{ .route = route }, RenderCyclePage, null);
}

fn renderRoute(route: []const u8) !*UINode {
    const owned_route = try Vapor.lib.allocator_global.dupeZ(u8, route);
    try Vapor.lib.renderCycle(owned_route.ptr);
    return Vapor.lib.getRenderUINodeRootPtr() orelse error.MissingRenderRoot;
}

fn renderApp(route: []const u8) !*UINode {
    const root = try renderRoute(route);
    try std.testing.expectEqual(@as(usize, 1), Vapor.lib.getUINodeChildrenCount(root));
    return Vapor.lib.getUINodeChild(root, 0) orelse error.MissingAppNode;
}

test "renderCycle exposes rendered UINode tree for a registered page" {
    initRenderCycleRuntime("/cycle-tree");

    const app = try renderApp("/root/cycle-tree");
    try std.testing.expectEqual(Vapor.Types.ElementType.FlexBox, app.type);
    try std.testing.expectEqualStrings("app", app.uuid);
    try std.testing.expectEqual(@as(usize, 2), Vapor.lib.getUINodeChildrenCount(app));

    const alpha = Vapor.lib.getUINodeChild(app, 0) orelse return error.MissingAlphaNode;
    const beta = Vapor.lib.getUINodeChild(app, 1) orelse return error.MissingBetaNode;
    try std.testing.expectEqual(Vapor.Types.ElementType.Text, alpha.type);
    try std.testing.expectEqual(Vapor.Types.ElementType.Text, beta.type);
    try std.testing.expectEqualStrings("alpha", alpha.uuid);
    try std.testing.expectEqualStrings("beta", beta.uuid);
    try std.testing.expectEqualStrings("Alpha", alpha.text.?);
    try std.testing.expectEqualStrings("Beta", beta.text.?);
}

test "renderCycle leaves stable same-route rerenders clean" {
    initRenderCycleRuntime("/cycle-stable");

    _ = try renderApp("/root/cycle-stable");
    Vapor.lib.resetRerender();
    Vapor.Animation.removal_queue.clearRetainingCapacity();

    const app = try renderApp("/root/cycle-stable");
    try std.testing.expectEqual(@as(usize, 2), Vapor.lib.getUINodeChildrenCount(app));
    try std.testing.expect(!Vapor.lib.hasDirty());
    try std.testing.expectEqual(@as(usize, 0), Vapor.Animation.removalCount());
}

test "renderCycle marks updated rendered text dirty without removals" {
    initRenderCycleRuntime("/cycle-update");

    _ = try renderApp("/root/cycle-update");
    Vapor.lib.resetRerender();
    Vapor.Animation.removal_queue.clearRetainingCapacity();

    render_variant = .updated;
    const app = try renderApp("/root/cycle-update");
    const alpha = Vapor.lib.getUINodeChild(app, 0) orelse return error.MissingAlphaNode;
    const beta = Vapor.lib.getUINodeChild(app, 1) orelse return error.MissingBetaNode;

    try std.testing.expect(Vapor.lib.hasDirty());
    try std.testing.expect(alpha.dirty);
    try std.testing.expect(!beta.dirty);
    try std.testing.expectEqualStrings("Alpha changed", alpha.text.?);
    try std.testing.expectEqual(@as(usize, 0), Vapor.Animation.removalCount());
}

test "renderCycle queues removals from rendered child deletions" {
    initRenderCycleRuntime("/cycle-remove");

    render_variant = .updated;
    _ = try renderApp("/root/cycle-remove");
    Vapor.lib.resetRerender();
    Vapor.Animation.removal_queue.clearRetainingCapacity();

    render_variant = .removed;
    const app = try renderApp("/root/cycle-remove");

    try std.testing.expect(Vapor.lib.hasDirty());
    try std.testing.expectEqual(@as(usize, 1), Vapor.lib.getUINodeChildrenCount(app));
    const alpha = Vapor.lib.getUINodeChild(app, 0) orelse return error.MissingAlphaNode;
    try std.testing.expectEqualStrings("alpha", alpha.uuid);
    try std.testing.expectEqual(@as(usize, 1), Vapor.Animation.removalCount());
    try expectRemovalId(0, "beta");
}
