const Vapor = @import("vapor");
const Color = Vapor.Types.Color;

pub const ThemeTokens = enum(u8) {
    none,
    text,
    background,
    primary,
};

pub const Colors = struct {
    text: Color = .black,
    background: Color = .white,
    primary: Color = .vapor_blue,
};
