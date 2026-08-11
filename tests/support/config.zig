pub const IconTokens = struct {
    web: ?[]const u8 = null,
    svg: ?[]const u8 = null,

    pub const test_icon = IconTokens{ .web = "test-icon", .svg = "<svg></svg>" };
};

pub const Experimental = struct {
    pub const enabled = false;
};
