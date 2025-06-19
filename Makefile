# Variables
ZIG=zig
# SRC=main.zig

# Default target: Build and run
all: build 

# Build the Zig codebase
build:
	# $(ZIG) build 
  # $(ZIG) build -Dno-bin -fincremental --watch
	# $(ZIG) build -fincremental --watch
	# $(ZIG) build-exe src/main.zig -target wasm32-wasi -O Debug -femit-bin=zig-out/bin/fabric.wasm
  # $(ZIG) build-exe src/main.zig -target wasm32-wasi -O Debug -g -o zig-out/bin/fabric.wasm 
  # $(ZIG) build-exe src/main.zig -target wasm32-wasi -O ReleaseFast -g -o zig-out/bin/fabric.wasm
	$(ZIG) build --release=small
	# $(ZIG) build-exe src/main.zig -target wasm32-wasi -O ReleaseFast -o zig-out/bin/fabric.wasm
	# $(ZIG) build --release=safe 
# Build the Zig PGSQL 
buildrel:
	$(ZIG) build-exe src/main.zig -O ReleaseFast

buildios:
	$(ZIG) build -Dtarget=aarch64-ios-simulator 



# Run the built executable
# ./zig-out/bin/app
run:
	./zig-out/bin/fabric
  # WASMTIME_BACKTRACE_DETAILS=1 wasmtime zig-out/bin/fabric.wasm

runrel:
	./main

server: 
	python3 -m http.server
# Clean up the built executable
clean:
	rm -f $(OUT)

.PHONY: all build run clean
