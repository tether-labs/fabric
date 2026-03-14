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

    // These options will receive values from the parent build
    const static_mode = b.option(bool, "static", "Enable static mode") orelse false;
    const enable_atomic = b.option(bool, "atomic", "Enable atomic operations") orelse true;

    // var generator: std.Build.Step.Run = undefined;

    // Create build_options module
    const build_options = b.addOptions();
    build_options.addOption(bool, "static_mode", static_mode);
    build_options.addOption(bool, "enable_atomic", enable_atomic); // 2. Create a module from the user's file path only if provided

    // This creates a "module", which represents a collection of source files alongside
    // some compilation options, such as optimization mode and linked system libraries.
    // Every executable or library we compile will be based on one or more modules.
    var vapor_imports = std.array_list.Managed(std.Build.Module.Import).init(b.allocator);
    vapor_imports.append(.{ .name = "build_options", .module = build_options.createModule() }) catch @panic("OOM");

    const vapor_runtime = b.addLibrary(.{
        .name = "vapor_runtime",
        .linkage = .static,
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/runtime.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });

    b.installArtifact(vapor_runtime);

    const mod = b.addModule("vapor", .{
        // `root_source_file` is the Zig "entry point" of the module. If a module
        // only contains e.g. external object files, you can make this `null`.
        // In this case the main source file is merely a path, however, in more
        // complicated build scripts, this could be a generated file.
        .root_source_file = b.path("src/comptime.zig"),
        .target = target,
        .optimize = optimize,
        // Add user_config as an import to the vapor module if it exists
        .imports = vapor_imports.items,
    });
    // mod.linkLibrary(vapor_runtime);

    // // We will also create a module for our other entry point, 'main.zig'.
    var exe_imports = std.array_list.Managed(std.Build.Module.Import).init(b.allocator);
    exe_imports.append(.{ .name = "vapor", .module = mod }) catch @panic("OOM");
    // exe_imports.append(.{ .name = "build_options", .module = build_options.createModule() }) catch @panic("OOM");
    // exe_imports.append(.{ .name = "user_config", .module = vapor_config }) catch @panic("OOM");

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
    // This compiles the code to object files (.a / .lib)
    const lib = b.addLibrary(.{
        .name = "vapor_lib",
        .linkage = .static,
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/root.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });

    // This creates another `std.Build.Step.Compile`, but this one builds an executable
    // rather than a static library.
    const exe = b.addExecutable(.{
        .name = "vapor",
        .root_module = exe_mod,
    });

    exe.linkLibrary(lib);

    // if (static_mode) {
    //     exe.step.dependOn(&generator.step);
    // }

    b.installArtifact(lib);
    b.installArtifact(exe);
}
