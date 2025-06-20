# Fabric

A modern, lightweight web framework for building WebAssembly applications with Zig. Fabric enables developers to create fast, efficient web applications by compiling Zig code directly to WebAssembly, bringing systems programming performance to the browser.

## ✨ Features

- **WebAssembly First**: Built specifically for WebAssembly compilation with optimal performance
- **Zig Native**: Leverages Zig's safety, performance, and compile-time guarantees
- **Minimal Runtime**: Small bundle sizes with efficient memory management
- **Component System**: Modular architecture for building reusable UI components
- **Theme Support**: Built-in theming system for consistent styling
- **Hot Reload**: Development-friendly with auto-rebuild capabilities
- **WASI Compatible**: Supports WebAssembly System Interface for enhanced capabilities

## 🚀 Quick Start

### Prerequisites

- [Zig](https://ziglang.org/) (latest stable version)
- Basic knowledge of Zig programming

### Installation

1. **Install Zig** (recommended: use [ZVM](https://www.zvm.app/) for version management)
2. **Create a new project**:
   ```bash
   mkdir my-fabric-app
   cd my-fabric-app
   zig init
   ```

3. **Add Fabric dependency**:
   ```bash
   zig fetch https://github.com/vic-Rokx/fabric/archive/refs/tags/v1.0.0.tar.gz
   ```

4. **Configure `build.zig.zon`**:
   ```zig
   .{
       .name = "my-fabric-app",
       .version = "0.1.0",
       .dependencies = .{
           .fabric = .{
               .url = "https://github.com/vic-Rokx/fabric/archive/refs/tags/v1.0.0.tar.gz",
               .hash = "YOUR_HASH_HERE", // Replace with hash from zig fetch
           },
       },
   }
   ```

5. **Update `build.zig`**:
   ```zig
   const std = @import("std");

   pub fn build(b: *std.Build) void {
       const target = b.standardTargetOptions(.{
           .default_target = .{ .cpu_arch = .wasm32, .os_tag = .wasi },
       });

       const optimize = b.standardOptimizeOption(.{
           .preferred_optimize_mode = .ReleaseSmall,
       });

       const fabric = b.dependency("fabric", .{
           .target = target,
           .optimize = optimize,
       });

       const fabric_module = fabric.module("fabric");
       fabric_module.addImport("fabric", fabric_module);

       const exe_mod = b.createModule(.{
           .root_source_file = b.path("src/main.zig"),
           .target = target,
           .optimize = optimize,
           .imports = &.{.{ .name = "fabric", .module = fabric_module }},
       });

       const exe = b.addExecutable(.{
           .name = "fabric",
           .root_module = exe_mod,
       });

       exe.rdynamic = true;
       b.installArtifact(exe);
   }
   ```

6. **Create your application** (`src/main.zig`):
   ```zig
   const std = @import("std");
   const fabric = @import("fabric");

   var fb: fabric.lib = undefined;
   var allocator: std.mem.Allocator = undefined;

   export fn deinit() void {
       fb.deinit();
   }

   export fn instantiate(window_width: i32, window_height: i32) void {
       fb.init(.{
           .screen_width = window_width,
           .screen_height = window_height,
           .allocator = &allocator,
       });
   }

   export fn renderCommands(route_ptr: [*:0]u8) i32 {
       const route = std.mem.span(route_ptr);
       fabric.renderCycle(route);
       fabric.lib.allocator_global.free(route);
       return 0;
   }

   pub fn main() !void {
       allocator = std.heap.wasm_allocator;
   }
   ```

7. **Build and run**:
   ```bash
   zig build
   ./main
   ```

   Open your browser and navigate to `http://localhost:5173/`

## 📖 Documentation

### Core Concepts

#### Fabric Instance
The global Fabric instance manages your application state and rendering:

```zig
var fb: fabric.lib = undefined;

// Initialize with screen dimensions
fb.init(.{
    .screen_width = 800,
    .screen_height = 600,
    .allocator = &allocator,
});
```

#### Render Cycle
Fabric uses a render cycle approach for updating the UI:

```zig
export fn renderCommands(route_ptr: [*:0]u8) i32 {
    const route = std.mem.span(route_ptr);
    fabric.renderCycle(route);
    return 0;
}
```

#### Memory Management
Fabric is designed to work with WebAssembly's memory model:

```zig
pub fn main() !void {
    // Use WASM allocator for optimal performance
    allocator = std.heap.wasm_allocator;
}
```

### Component System

Fabric provides a component-based architecture for building reusable UI elements:

```zig
// Example component structure
const MyComponent = struct {
    // Component state
    title: []const u8,
    visible: bool = true,
    
    // Component methods
    pub fn render(self: *MyComponent) void {
        // Rendering logic here
    }
    
    pub fn update(self: *MyComponent) void {
        // Update logic here
    }
};
```

### Theming

Fabric includes a theming system for consistent styling across your application:

```zig
const Theme = @import("Theme.zig");

// Apply theme to components
const my_theme = Theme.init(.{
    .primary_color = "#3366cc",
    .background_color = "#ffffff",
    .text_color = "#333333",
});
```

## 🛠️ Development

### Hot Reload with Air

For an improved development experience, install [Air](https://github.com/cosmtrek/air) for automatic rebuilds:

```bash
# Install Air (requires Go)
go install github.com/cosmtrek/air@latest

# Create .air.toml configuration
# Configure to watch .zig files and run 'zig build'
```

### Project Structure

```
my-fabric-app/
├── build.zig
├── build.zig.zon
├── src/
│   ├── main.zig
│   ├── Theme.zig
│   └── components/
│       └── *.zig
└── web/
    └── index.html
```

## 🔧 Configuration

### Build Options

Fabric supports various build configurations:

```zig
// Optimize for size (recommended for web)
.preferred_optimize_mode = .ReleaseSmall,

// Optimize for speed
.preferred_optimize_mode = .ReleaseFast,

// Debug build
.preferred_optimize_mode = .Debug,
```

### Target Options

```zig
// Standard WebAssembly with WASI
.default_target = .{ .cpu_arch = .wasm32, .os_tag = .wasi },

// Freestanding WebAssembly
.default_target = .{ .cpu_arch = .wasm32, .os_tag = .freestanding },
```

## 📊 Performance

Fabric is designed for optimal WebAssembly performance:

- **Small Bundle Size**: Minimal runtime overhead
- **Fast Startup**: Quick initialization times
- **Efficient Memory**: Careful memory management for WASM constraints
- **Zero-Cost Abstractions**: Zig's compile-time optimizations

## 🤝 Contributing

Contributions are welcome! Please feel free to submit a Pull Request. For major changes, please open an issue first to discuss what you would like to change.

### Development Setup

1. Fork the repository
2. Clone your fork: `git clone https://github.com/YOUR_USERNAME/fabric.git`
3. Create a feature branch: `git checkout -b feature/amazing-feature`
4. Make your changes and test them
5. Commit your changes: `git commit -m 'Add amazing feature'`
6. Push to the branch: `git push origin feature/amazing-feature`
7. Open a Pull Request

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## 🙏 Acknowledgments

- Built with [Zig](https://ziglang.org/) - A general-purpose programming language
- Inspired by modern web frameworks and WebAssembly capabilities
- Special thanks to the Zig community for their support and contributions

## 📞 Support

- **Issues**: [GitHub Issues](https://github.com/vic-Rokx/fabric/issues)
- **Discussions**: [GitHub Discussions](https://github.com/vic-Rokx/fabric/discussions)
- **Documentation**: [Wiki](https://github.com/vic-Rokx/fabric/wiki)

---

**Built with ❤️ using Zig and WebAssembly**
