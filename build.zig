const std = @import("std");
// Although this function looks imperative, note that its job is to
// declaratively construct a build graph that will be executed by an external
// runner.
pub fn build(b: *std.Build) void {
    // Standard target options allows the person running `zig build` to choose
    // what target to build for. Here we do not override the defaults, which
    // means any target is allowed, and the default is native. Other options
    // for restricting supported target set are available.
    const target = b.standardTargetOptions(.{});
    // Standard optimization options allow the person running `zig build` to select
    // between Debug, ReleaseSafe, ReleaseFast, and ReleaseSmall. Here we do not
    // set a preferred release mode, allowing the user to decide how to optimize.
    const optimize = b.standardOptimizeOption(.{});
    
    // 1. Expose an option for the user's config file - this will be passed from the user's build.zig
    const user_config_path = b.option([]const u8, "user_config", "Path to the user's configuration file");
    
    // 2. Create a module from the user's file path only if provided
    var user_config_module: ?*std.Build.Module = null;
    if (user_config_path) |path| {
        user_config_module = b.addModule("user_config", .{
            .root_source_file = b.path(path),
            .target = target,
            .optimize = optimize,
        });
    }
    
    // This creates a "module", which represents a collection of source files alongside
    // some compilation options, such as optimization mode and linked system libraries.
    // Every executable or library we compile will be based on one or more modules.
    var fabric_imports = std.ArrayList(std.Build.Module.Import).init(b.allocator);
    if (user_config_module) |ucm| {
        fabric_imports.append(.{ .name = "user_config", .module = ucm }) catch @panic("OOM");
    }
    
    const mod = b.addModule("fabric", .{
        // `root_source_file` is the Zig "entry point" of the module. If a module
        // only contains e.g. external object files, you can make this `null`.
        // In this case the main source file is merely a path, however, in more
        // complicated build scripts, this could be a generated file.
        .root_source_file = b.path("src/root.zig"),
        .target = target,
        .optimize = optimize,
        // Add user_config as an import to the fabric module if it exists
        .imports = fabric_imports.items,
    });
    
    // // We will also create a module for our other entry point, 'main.zig'.
    var exe_imports = std.ArrayList(std.Build.Module.Import).init(b.allocator);
    exe_imports.append(.{ .name = "fabric", .module = mod }) catch @panic("OOM");
    if (user_config_module) |ucm| {
        exe_imports.append(.{ .name = "user_config", .module = ucm }) catch @panic("OOM");
    }
    
    const exe_mod = b.createModule(.{
        // `root_source_file` is the Zig "entry point" of the module. If a module
        // only contains e.g. external object files, you can make this `null`.
        // In this case the main source file is merely a path, however, in more
        // complicated build scripts, this could be a generated file.
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
        .imports = exe_imports.items,
    });
    // This creates another `std.Build.Step.Compile`, but this one builds an executable
    // rather than a static library.
    const exe = b.addExecutable(.{
        .name = "fabric",
        .root_module = exe_mod,
    });
    b.installArtifact(exe);
}
