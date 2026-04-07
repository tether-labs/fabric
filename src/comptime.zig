const types = @import("lib/types.zig");
const std = @import("std");
pub const lib = @import("lib/Vapor.zig");
pub const IconTokens = @import("config").IconTokens;
pub const init = lib.init;
pub const Wasm = lib.Wasm;
pub const Arena = lib.Arena;
pub const IconType = *const IconTokens;
pub const Bounds = lib.Bounds;
const Rune = @import("lib/Rune.zig");
const TransitionState = @import("lib/Transition.zig").TransitionState;
pub const Binded = @import("lib/Element.zig").Element;
pub const Draggable = @import("lib/Draggable.zig").Draggable;
pub const KeyStone = @import("lib/keystone/KeyStone.zig");
pub const utils = @import("lib/utils.zig");

// vapor.zig
pub const ArrayArena = @import("lib/Array.zig").Array;

pub const persist = struct {
    pub fn dupe(value: []const u8) []const u8 {
        const allocator = lib.arena(.persist);
        const buf = allocator.dupe(u8, value) catch |err| {
            println("Formatting, Error Could not format argument alloc Error details: {any}\n", .{err});
            return "";
        };
        return buf;
    }
    pub fn fmt(comptime _fmt: []const u8, args: anytype) []const u8 {
        const allocator = lib.arena(.persist);
        const buf = std.fmt.allocPrint(allocator, _fmt, args) catch |err| {
            println("Formatting, Error Could not format argument alloc Error details: {any}\n", .{err});
            return "";
        };
        return buf;
    }
    pub fn array(comptime T: type) std.array_list.Managed(T) {
        var array_list: std.array_list.Managed(T) = undefined;
        const allocator = lib.arena(.persist);
        array_list = std.array_list.Managed(T).init(allocator);
        return array_list;
    }

    pub fn arena() std.mem.Allocator {
        return lib.arena(.persist);
    }

    pub fn Array(comptime T: type) ArrayArena(T) {
        return ArrayArena(T).init(.persist);
    }

    // Join slices: &.{"a", "b", "c"} with ", " -> "a, b, c"
    pub fn join(parts: []const []const u8, separator: []const u8) []const u8 {
        const allocator = lib.arena(.persist);
        return std.mem.join(allocator, separator, parts) catch unreachable;
    }

    // Split string into slice of slices
    pub fn split(str: []const u8, delimiter: []const u8) std.mem.SplitIterator([]const u8, .sequence) {
        const allocator = lib.arena(.persist);
        var buffer = allocator.alloc(u8, str.len) catch unreachable;
        @memcpy(buffer[0..], str);
        return std.mem.splitSequence(u8, buffer[0..], delimiter) catch unreachable;
    }

    // Repeat: repeat("ha", 3) -> "hahaha"
    pub fn repeat(str: []const u8, count: usize) []const u8 {
        const allocator = lib.arena(.persist);
        var list = allocator.alloc([]const u8, count) catch unreachable;
        @memset(list, str);
        return std.mem.join(allocator, "", &list) catch unreachable;
    }

    pub fn toLowerCase(str: []const u8) []const u8 {
        return utils.toLowerCase(str, .persist);
    }

    pub fn toUpperCase(str: []const u8) []const u8 {
        return utils.toUpperCase(str, .persist);
    }

    pub fn firstLetterToUpper(str: []const u8) []const u8 {
        return utils.firstLetterToUpper(str, .persist);
    }

    pub fn contains(str: []const u8, needle: []const u8) bool {
        return utils.contains(str, needle);
    }

    pub fn startsWith(str: []const u8, prefix: []const u8) bool {
        return utils.startsWith(str, prefix);
    }
};

pub const view = struct {
    pub fn dupe(value: []const u8) []const u8 {
        const allocator = lib.arena(.view);
        const buf = allocator.dupe(u8, value) catch |err| {
            println("Formatting, Error Could not format argument alloc Error details: {any}\n", .{err});
            return "";
        };
        return buf;
    }
    pub fn fmt(comptime _fmtln: []const u8, args: anytype) []const u8 {
        const allocator = lib.arena(.view);
        const buf = std.fmt.allocPrint(allocator, _fmtln, args) catch |err| {
            println("Formatting, Error Could not format argument alloc Error details: {any}\n", .{err});
            return "";
        };
        return buf;
    }

    pub fn array(comptime T: type) std.array_list.Managed(T) {
        var array_list: std.array_list.Managed(T) = undefined;
        const allocator = lib.arena(.view);
        array_list = std.array_list.Managed(T).init(allocator);
        return array_list;
    }

    pub fn Array(comptime T: type) ArrayArena(T) {
        return ArrayArena(T).init(.view);
    }

    pub fn arena() std.mem.Allocator {
        return lib.arena(.view);
    }

    pub fn toLowerCase(str: []const u8) []const u8 {
        return utils.toLowerCase(str, .view);
    }

    pub fn toUpperCase(str: []const u8) []const u8 {
        return utils.toUpperCase(str, .view);
    }

    pub fn firstLetterToUpper(str: []const u8) []const u8 {
        return utils.firstLetterToUpper(str, .view);
    }

    pub fn contains(str: []const u8, needle: []const u8) bool {
        return utils.contains(str, needle);
    }

    pub fn startsWith(str: []const u8, prefix: []const u8) bool {
        return utils.startsWith(str, prefix);
    }
};

pub const frame = struct {
    pub fn dupe(value: []const u8) []const u8 {
        const allocator = lib.arena(.frame);
        const buf = allocator.dupe(u8, value) catch |err| {
            println("Formatting, Error Could not format argument alloc Error details: {any}\n", .{err});
            return "";
        };
        return buf;
    }
    pub fn fmt(comptime _fmtln: []const u8, args: anytype) []const u8 {
        const allocator = lib.arena(.frame);
        const buf = std.fmt.allocPrint(allocator, _fmtln, args) catch |err| {
            println("Formatting, Error Could not format argument alloc Error details: {any}\n", .{err});
            return "";
        };
        return buf;
    }

    pub fn array(comptime T: type) std.array_list.Managed(T) {
        var array_list: std.array_list.Managed(T) = undefined;
        const allocator = lib.arena(.frame);
        array_list = std.array_list.Managed(T).init(allocator);
        return array_list;
    }

    pub fn Array(comptime T: type) ArrayArena(T) {
        return ArrayArena(T).init(.frame);
    }

    pub fn arena() std.mem.Allocator {
        return lib.arena(.frame);
    }

    // Join slices: &.{"a", "b", "c"} with ", " -> "a, b, c"
    pub fn join(parts: []const []const u8, separator: []const u8) []const u8 {
        const allocator = lib.arena(.frame);
        return std.mem.join(allocator, separator, parts) catch unreachable;
    }

    // Split string into slice of slices
    pub fn split(str: []const u8, delimiter: []const u8) std.mem.SplitIterator([]const u8, .sequence) {
        return std.mem.splitSequence(u8, str, delimiter) catch unreachable;
    }

    // Repeat: repeat("ha", 3) -> "hahaha"
    pub fn repeat(str: []const u8, count: usize) []const u8 {
        const allocator = lib.arena(.frame);
        var list = allocator.alloc([]const u8, count) catch unreachable;
        @memset(list, str);
        return std.mem.join(allocator, "", &list) catch unreachable;
    }

    pub fn toLowerCase(str: []const u8) []const u8 {
        return utils.toLowerCase(str, .frame);
    }

    pub fn toUpperCase(str: []const u8) []const u8 {
        return utils.toUpperCase(str, .frame);
    }

    pub fn firstLetterToUpper(str: []const u8) []const u8 {
        return utils.firstLetterToUpper(str, .frame);
    }

    pub fn contains(str: []const u8, needle: []const u8) bool {
        return utils.contains(str, needle);
    }

    pub fn startsWith(str: []const u8, prefix: []const u8) bool {
        return utils.startsWith(str, prefix);
    }
};

// pub const renderCycle = @import("lib/Vapor.zig").renderCycle;
pub const LifeCycle = @import("lib/Vapor.zig").LifeCycle;
pub const ElementType = @import("lib/Vapor.zig").ElementType;
pub const ElementDecl = @import("lib/Vapor.zig").ElementDecl;
pub const StateType = @import("lib/Vapor.zig").StateType;
pub const Kit = @import("lib/kit/Kit.zig");
pub const Page = lib.Page;
pub const println = lib.println;
pub const printlnSrc = lib.printlnSrc;
pub const transparentizeHex = lib.transparentize;
pub const setGlobalStyleVariables = lib.setGlobalStyleVariables;
pub const ThemeType = lib.ThemeType;
pub const hexToRgba = lib.hexToRgba;
pub const Bridge = @import("lib/Bridge.zig");
pub const isMobile = utils.isMobile;
pub const isDesktop = utils.isDesktop;
pub const cycle = lib.cycle;
pub const Clipboard = lib.Clipboard;
pub const registerTimeout = lib.registerTimeout;
pub const timeout = lib.timeout;
pub const Event = lib.Event;
pub const fmtln = lib.fmtln;
pub const fmtArena = lib.fmtArena;
pub const dupe = lib.dupe;
pub const pin = lib.pin;
pub const unpin = lib.unpin;
pub const compact = lib.compact;
pub const cloneFrame = lib.cloneFrame;
pub const arena = lib.arena;
pub const Style = types.Style;
pub const Signal = Rune.Signal;
pub const Types = types;
pub const DateTime = @import("lib/DateTime.zig");
pub const Animation = @import("lib/Animation.zig");
pub const Edges = @import("lib/Edges.zig").Edges;
pub const Transition = @import("lib/Transition.zig");
pub const ThemeDefinition = Types.ThemeDefinition;
pub const FileReader = @import("lib/File.zig").FileReader;
pub const Polygons = @import("lib/Polygon.zig").Polygons;

const ComponentBuilder = @import("lib/NewComponent.zig").Builder;
const ComponentBuilderClose = @import("lib/NewComponent.zig").BuilderClose;
const StaticComponent = ComponentBuilder(.static);
const StaticComponentClose = ComponentBuilderClose(.static);
pub const Accessibility = @import("lib/Accessibility.zig").Accessibility;

const StaticHooks = @import("lib/Static.zig").Hooks;
const StaticHooksCtx = @import("lib/Static.zig").CtxHooks;
pub const registerHook = lib.registerHook;
pub const queryComponentIds = lib.queryComponentIds;
pub const queryByUUID = lib.queryByUUID;
pub const getComponentBounds = lib.getComponentBounds;
pub const getComponentOffsets = lib.getComponentOffsets;
pub const onEnd = lib.onEnd;
pub const onPopState = lib.onPopState;
pub const scrollIntoView = Event.scrollIntoView;
pub const Writer = @import("lib/Writer.zig");
pub const onCommit = lib.onCommit;
pub const mutateById = lib.mutateById;
pub const print = lib.print;
pub const printSrcErr = lib.printlnSrcErr;
pub const cast = utils.cast;
pub const alert = lib.alert;
pub const Static = struct {
    pub const Box = StaticComponent.Box;
    pub const Text = StaticComponentClose.Text;
    pub const Link = StaticComponent.Link;
    pub const Image = StaticComponentClose.Image;
    pub const Button = ButtonBuilder(.static).Button;
    pub const List = StaticComponent.List;
    pub const ListItem = StaticComponent.ListItem;
    pub const Graphic = StaticComponentClose.Graphic;
    pub const Svg = StaticComponentClose.Svg;
    pub const HooksCtx = StaticHooksCtx;
    pub const RedirectLink = StaticComponent.RedirectLink;
    pub const Icon = StaticComponentClose.Icon;
    pub const Stack = StaticComponent.Stack;
    pub const Center = StaticComponent.Center;
    pub const CtxButton = ButtonBuilder(.static).CtxButton;
    pub const TextFmt = StaticComponentClose.TextFmt;
    pub const Hooks = StaticHooks;
    pub const Heading = StaticComponentClose.Heading;
    pub const Code = StaticComponentClose.Code;
    pub const Section = StaticComponent.Section;
    pub const Video = StaticComponentClose.Video;
    pub const Null = StaticComponentClose.Null;
};

pub const Builder = ComponentBuilder;
pub const BuilderClose = ComponentBuilderClose;

pub const printErrSrc = lib.printlnSrcErr;
pub const printErr = lib.printlnErr;

pub const addGlobalListener = lib.addGlobalListener;
pub const addGlobalListenerCtx = lib.addGlobalListenerCtx;
pub const removeGlobalListener = lib.removeGlobalListener;

pub const onEndCtx = lib.onEndCtx;
pub const Array = lib.Array;
pub const array = lib.array;
pub const getStatus = lib.getStatus;

pub const ButtonBuilder = @import("lib/Button.zig").Builder;

pub const PureComponent = ComponentBuilder(.pure);
pub const PureComponentClose = ComponentBuilderClose(.pure);
pub const TextField = @import("lib/TextField.zig").BuilderClose(.pure).TextField;
pub const TextFieldBuilder = @import("lib/TextField.zig").BuilderClose;
pub const TextAreaBuilder = @import("lib/TextField.zig").BuilderClose;
pub const registerLayout = lib.registerLayout;
pub const PageFn = lib.PageFn;
pub const Box = PureComponent.Box;
pub const Row = PureComponent.Row;
pub const Text = PureComponentClose.Text;
pub const Link = PureComponent.Link;
pub const Image = PureComponentClose.Image;
pub const Spacer = PureComponentClose.Spacer;
pub const Divider = PureComponentClose.Divider;
pub const Iframe = PureComponentClose.Iframe;
pub const load = lib.getStore;
pub const store = lib.store;
// pub const Button = ButtonBuilder(.pure).Button;
pub const List = PureComponent.List;
pub const ListItem = PureComponent.ListItem;
pub const Graphic = PureComponentClose.Graphic;
pub const Svg = PureComponentClose.Svg;
pub const RedirectLink = PureComponent.RedirectLink;
pub const Icon = PureComponentClose.Icon;
pub const Stack = PureComponent.Stack;
pub const Center = PureComponent.Center;
pub const CtxButton = ButtonBuilder(.pure).CtxButton;
pub const Button =  PureComponent.Button;
pub const TextFmt = PureComponentClose.TextFmt;
pub const TextArea = @import("lib/TextField.zig").BuilderClose(.pure).TextArea;
pub const Heading = PureComponentClose.Heading;
pub const Section = PureComponent.Section;
pub const Video = PureComponentClose.Video;
pub const Null = PureComponentClose.Null;
pub const Null2 = PureComponentClose.Null2;
pub const Form = PureComponent.Form;
pub const Label = PureComponentClose.Label;
pub const SubmitButton = ButtonBuilder(.pure).SubmitButton;
pub const Html = PureComponentClose.Html;
pub const Table = PureComponent.Table;
pub const TableRow = PureComponent.TableRow;
pub const TableCell = PureComponent.TableCell;
pub const TableBody = PureComponent.TableBody;
pub const TableHeader = PureComponent.TableHeader;
pub const TableHead = PureComponent.TableHead;
pub const Anchor = PureComponent.Anchor;
pub const Code = PureComponentClose.Code;
pub const Number = PureComponentClose.Number;
pub const Inert = @import("lib/Inert.zig").InertBuilder;
