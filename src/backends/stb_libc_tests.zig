const std = @import("std");
const libc = @import("stb_libc.zig");

fn allocator() std.mem.Allocator {
    return std.testing.allocator;
}

fn panic(message: [*c]const u8) callconv(.c) noreturn {
    std.debug.panic("STB assertion: {s}", .{std.mem.span(message)});
}

comptime {
    libc.Provider(allocator, panic).exportSymbols();
}

test {
    std.testing.refAllDecls(libc);
}
