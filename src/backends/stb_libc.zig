const std = @import("std");
const builtin = @import("builtin");

pub fn Provider(
    comptime allocator: fn () std.mem.Allocator,
    comptime panic: fn ([*c]const u8) callconv(.c) noreturn,
) type {
    return struct {
        pub fn alloc(size: usize) callconv(.c) ?*anyopaque {
            const len = std.math.add(usize, size, 8) catch return null;
            const buffer = allocator().alignedAlloc(u8, .@"8", len) catch return null;
            std.mem.writeInt(u64, buffer[0..8], buffer.len, builtin.target.cpu.arch.endian());
            return buffer.ptr + 8;
        }

        pub fn free(ptr: ?*anyopaque) callconv(.c) void {
            const buffer = @as([*]align(8) u8, @ptrCast(@alignCast(ptr orelse return))) - 8;
            const len = std.mem.readInt(u64, buffer[0..8], builtin.target.cpu.arch.endian());
            allocator().free(buffer[0..@intCast(len)]);
        }

        pub fn reallocSized(ptr: ?*anyopaque, oldsize: usize, newsize: usize) callconv(.c) ?*anyopaque {
            const newptr = alloc(newsize) orelse return null;
            if (ptr) |oldptr| {
                const len = @min(oldsize, newsize);
                @memcpy(@as([*]u8, @ptrCast(newptr))[0..len], @as([*]const u8, @ptrCast(oldptr))[0..len]);
                free(oldptr);
            }
            return newptr;
        }

        pub fn exportSymbols() void {
            @export(&alloc, .{ .name = "dvui_c_alloc" });
            @export(&free, .{ .name = "dvui_c_free" });
            @export(&reallocSized, .{ .name = "dvui_c_realloc_sized" });
            @export(&panic, .{ .name = "dvui_c_panic" });
            @export(&sqrt, .{ .name = "dvui_c_sqrt" });
            @export(&pow, .{ .name = "dvui_c_pow" });
            if (builtin.mode == .debug) @export(&ldexp, .{ .name = "dvui_c_ldexp" });
            @export(&floor, .{ .name = "dvui_c_floor" });
            @export(&ceil, .{ .name = "dvui_c_ceil" });
            @export(&fmod, .{ .name = "dvui_c_fmod" });
            @export(&cos, .{ .name = "dvui_c_cos" });
            @export(&acos, .{ .name = "dvui_c_acos" });
            @export(&fabs, .{ .name = "dvui_c_fabs" });
            @export(&strlen, .{ .name = "dvui_c_strlen" });
        }

        pub fn sqrt(x: f64) callconv(.c) f64 {
            return @sqrt(x);
        }
        pub fn pow(x: f64, y: f64) callconv(.c) f64 {
            return @exp(@log(x) * y);
        }
        pub fn ldexp(x: f64, n: c_int) callconv(.c) f64 {
            return x * @exp2(@as(f64, @floatFromInt(n)));
        }
        pub fn floor(x: f64) callconv(.c) f64 {
            return @floor(x);
        }
        pub fn ceil(x: f64) callconv(.c) f64 {
            return @ceil(x);
        }
        pub fn fmod(x: f64, y: f64) callconv(.c) f64 {
            return @mod(x, y);
        }
        pub fn cos(x: f64) callconv(.c) f64 {
            return @cos(x);
        }
        pub fn acos(x: f64) callconv(.c) f64 {
            return std.math.acos(x);
        }
        pub fn fabs(x: f64) callconv(.c) f64 {
            return @abs(x);
        }
        pub fn strlen(x: [*c]const u8) callconv(.c) usize {
            return std.mem.len(x);
        }
    };
}

fn testPanic(message: [*c]const u8) callconv(.c) noreturn {
    std.debug.panic("STB assertion: {s}", .{std.mem.span(message)});
}

test "STB provider retains data when reallocating larger and smaller blocks" {
    const State = struct {
        var fixed: std.heap.FixedBufferAllocator = undefined;
        fn allocator() std.mem.Allocator {
            return fixed.allocator();
        }
    };
    var storage: [128]u8 = @splat(0xaf);
    State.fixed = .init(&storage);
    const P = Provider(State.allocator, testPanic);
    const original = P.alloc(4).?;
    @memcpy(@as([*]u8, @ptrCast(original))[0..4], "dvui");
    const larger = P.reallocSized(original, 4, 16).?;
    try std.testing.expectEqualStrings("dvui", @as([*]u8, @ptrCast(larger))[0..4]);
    const smaller = P.reallocSized(larger, 16, 2).?;
    defer P.free(smaller);
    try std.testing.expectEqualStrings("dv", @as([*]u8, @ptrCast(smaller))[0..2]);
    try std.testing.expectEqual(@as(u8, 0xaf), storage[State.fixed.end_index]);
}

test "STB provider leaves the original allocation intact on realloc failure" {
    const State = struct {
        var failing: std.testing.FailingAllocator = undefined;
        fn allocator() std.mem.Allocator {
            return failing.allocator();
        }
    };
    State.failing = .init(std.testing.allocator, .{ .fail_index = 1 });
    const P = Provider(State.allocator, testPanic);
    const original = P.alloc(4).?;
    defer P.free(original);
    @memcpy(@as([*]u8, @ptrCast(original))[0..4], "dvui");
    try std.testing.expectEqual(null, P.reallocSized(original, 4, 16));
    try std.testing.expectEqualStrings("dvui", @as([*]u8, @ptrCast(original))[0..4]);
}
