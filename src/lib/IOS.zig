const std = @import("std");
const log = std.log;
const objc = @import("objc");

pub const c = @cImport({
    @cInclude("objc/runtime.h");
    @cInclude("objc/message.h");
});

fn cString(zig_string: []const u8) [:0]const u8 {
    return std.heap.c_allocator.dupeZ(u8, zig_string) catch unreachable;
}

pub const UIView = struct {
    pub fn init() void {
        // const cls = objc.getClass("UIView").?;
        // const sel = objc.Sel.registerName("alloc");
        // const instance = cls.msgSend(objc.Object, sel, .{});
        // const initSel = objc.Sel.registerName("init");
        // const initialized = instance.msgSend(objc.Object, initSel, .{});
        // Get the objc class from the runtime
        const NSProcessInfo = objc.getClass("NSClassFromString").?;

        // Call a class method with no arguments that returns another objc object.
        const info = NSProcessInfo.msgSend(objc.Object, "processInfo", .{});
        log.debug("{any}", .{info});
        // return UIView{ .ptr = initialized };
    }

    // fn setBackgroundColor(self: UIView, color: UIColor) void {
    //     const sel = c.sel_registerName("setBackgroundColor:");
    //     _ = c.objc_msgSend(self.ptr, sel, color.ptr);
    // }
    //
    // fn addSubview(self: UIView, subview: UIView) void {
    //     const sel = c.sel_registerName("addSubview:");
    //     _ = c.objc_msgSend(self.ptr, sel, subview.ptr);
    // }
};

pub fn macosVersionAtLeast(major: i64, minor: i64, patch: i64) bool {
    // Get the objc class from the runtime
    const NSProcessInfo = objc.getClass("NSProcessInfo").?;

    // Call a class method with no arguments that returns another objc object.
    const info = NSProcessInfo.msgSend(objc.Object, "processInfo", .{});

    // Call an instance method that returns a boolean and takes a single
    // argument.
    return info.msgSend(bool, "isOperatingSystemAtLeastVersion:", .{
        NSOperatingSystemVersion{ .major = major, .minor = minor, .patch = patch },
    });
}

/// This extern struct matches the Cocoa headers for layout.
const NSOperatingSystemVersion = extern struct {
    major: i64,
    minor: i64,
    patch: i64,
};
