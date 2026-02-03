const std = @import("std");

/// A string interning table that stores unique strings and returns stable u32 indices.
/// Useful for replacing pointers in packed structs to ensure consistent hashing across platforms.
pub const StringTable = struct {
    const Self = @This();

    /// Entry stored in the table
    const Entry = struct {
        offset: u32,
        len: u32,
    };

    /// Backing storage for all string data
    string_data: std.array_list.Managed(u8),
    /// Map from string hash to entry index
    index_map: std.AutoHashMap(u64, u32),
    /// List of all entries (index = handle returned to user)
    entries: std.array_list.Managed(Entry),
    /// Allocator used for internal structures
    allocator: std.mem.Allocator,

    /// Special value indicating no string / null
    pub const null_handle: u32 = std.math.maxInt(u32);

    pub fn init(allocator: std.mem.Allocator) Self {
        return .{
            .string_data = std.array_list.Managed(u8).init(allocator),
            .index_map = std.AutoHashMap(u64, u32).init(allocator),
            .entries = std.array_list.Managed(Entry).init(allocator),
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *Self) void {
        self.string_data.deinit();
        self.index_map.deinit();
        self.entries.deinit();
    }

    /// Interns a string and returns a stable u32 handle.
    /// If the string already exists, returns the existing handle.
    /// Returns `null_handle` if the input is null or empty.
    pub fn intern(self: *Self, str: ?[]const u8) !u32 {
        const s = str orelse return null_handle;
        if (s.len == 0) return null_handle;

        const hash = std.hash.Wyhash.hash(0, s);

        // Check if already interned
        if (self.index_map.get(hash)) |existing_index| {
            // Verify it's actually the same string (hash collision check)
            const entry = self.entries.items[existing_index];
            const existing = self.string_data.items[entry.offset..][0..entry.len];
            if (std.mem.eql(u8, existing, s)) {
                return existing_index;
            }
            // Hash collision - fall through to add new entry
        }

        // Add new string
        const offset: u32 = @intCast(self.string_data.items.len);
        try self.string_data.appendSlice(s);

        const index: u32 = @intCast(self.entries.items.len);
        try self.entries.append(.{
            .offset = offset,
            .len = @intCast(s.len),
        });

        try self.index_map.put(hash, index);

        return index;
    }

    /// Retrieves a string by its handle.
    /// Returns null if the handle is invalid or null_handle.
    pub fn get(self: *const Self, handle: u32) ?[]const u8 {
        if (handle == null_handle) return null;
        if (handle >= self.entries.items.len) return null;

        const entry = self.entries.items[handle];
        return self.string_data.items[entry.offset..][0..entry.len];
    }

    /// Returns the number of unique strings stored.
    pub fn count(self: *const Self) u32 {
        return @intCast(self.entries.items.len);
    }

    /// Returns total bytes used for string storage.
    pub fn totalStringBytes(self: *const Self) usize {
        return self.string_data.items.len;
    }

    /// Clears all strings. Existing handles become invalid.
    pub fn clear(self: *Self) void {
        self.string_data.clearRetainingCapacity();
        self.index_map.clearRetainingCapacity();
        self.entries.clearRetainingCapacity();
    }
};

// ============================================================================
// Tests
// ============================================================================

test "basic intern and retrieve" {
    var table = StringTable.init(std.testing.allocator);
    defer table.deinit();

    const handle1 = try table.intern("hello");
    const handle2 = try table.intern("world");
    const handle3 = try table.intern("hello"); // duplicate

    try std.testing.expect(handle1 != handle2);
    try std.testing.expectEqual(handle1, handle3); // same string = same handle

    try std.testing.expectEqualStrings("hello", table.get(handle1).?);
    try std.testing.expectEqualStrings("world", table.get(handle2).?);
}

test "null and empty strings" {
    var table = StringTable.init(std.testing.allocator);
    defer table.deinit();

    const null_h = try table.intern(null);
    const empty_h = try table.intern("");

    try std.testing.expectEqual(StringTable.null_handle, null_h);
    try std.testing.expectEqual(StringTable.null_handle, empty_h);
    try std.testing.expectEqual(@as(?[]const u8, null), table.get(StringTable.null_handle));
}

test "invalid handle" {
    var table = StringTable.init(std.testing.allocator);
    defer table.deinit();

    try std.testing.expectEqual(@as(?[]const u8, null), table.get(999));
}
