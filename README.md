# Fabric 🚧 Under heavy development 🚧

A modern, lightweight web framework for building WebAssembly applications with Zig. Fabric enables developers to create fast, efficient web applications by compiling Zig code directly to WebAssembly, bringing systems programming performance to the browser.

## ✨ Features

- **WebAssembly First**: Built specifically for WebAssembly compilation with optimal performance
- **Zig Native**: Leverages Zig's safety, performance, and compile-time guarantees
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
2. [Learn Zig](https://www.openmymind.net/learning_zig/language_overview_1/)

# Install Fabric CLI

Run this command to install fabric-cli on your macOS (Apple Silicon):

```bash
curl -sSL https://raw.githubusercontent.com/vic-Rokx/fabric-cli/main/install.sh | bash
```

## What this does:

- Downloads the latest version of fabric-cli
- Installs it to `/usr/local/bin/fabric`
- Makes it executable and available in your PATH

## Requirements:

- macOS with Apple Silicon (M1/M2/M3)
- Administrator privileges (for `sudo` during installation)

After installation, you can run:

```bash
fabric --help
```

```bash
fabric create myapp
```

## 📖 Documentation

### Core Concepts

#### Fabric Instance

The global Fabric instance manages your application state and rendering:

```zig
var fb: fabric.lib = undefined;
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
## 🛠️ Development
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
    ...
```

## 🔧 Configuration

### Build Options

Fabric supports various build configurations:

```zig
// Optimize for size (recommended for web)
.preferred_optimize_mode = .ReleaseSmall,
```

### Target Options

```zig
// Standard WebAssembly with WASI
.default_target = .{ .cpu_arch = .wasm32, .os_tag = .wasi },
```

## 📊 Performance

Fabric is designed for optimal WebAssembly performance:

- **Small Bundle Size**: Base wasm is 150kb 
- **Fast Startup**: Quick initialization times
- **Efficient Memory**: Careful memory management for WASM constraints
- **Zero-Cost Abstractions**: Zig's compile-time optimizations

## 🤝 Contributing

Contributions are welcome! Please feel free to submit a Pull Request. For major changes, please open an issue first to discuss what you would like to change.

### Development Setup

1. Fork the repository
2. Clone your fork: `git clone https://github.com/vic-Rokx/fabric.git`
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

**Built with Zig and WebAssembly**
