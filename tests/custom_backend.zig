const std = @import("std");
const dvui = @import("dvui");

test "custom backend retains typed data and option overrides" {
    var t = try dvui.testing.init(.{});
    defer t.deinit();
    dvui.dataSetSliceCopies(null, .zero, "copies", &[_:1234]u16{ 1, 2 }, 2);
    try std.testing.expectEqualSlices(u16, &.{ 1, 2, 1, 2 }, dvui.dataGetSlice(null, .zero, "copies", [:1234]u16).?);
    const opts = (dvui.Options{ .min_size_content = .{ .w = 12, .h = 8 }, .gravity_x = 0 }).override(.{ .gravity_x = 1 });
    try std.testing.expectEqual(@as(f32, 1), opts.gravity_x);
    try std.testing.expectEqual(@as(f32, 12), opts.min_size_content.?.w);
}

test "custom backend forwards text into caller-owned storage" {
    var t = try dvui.testing.init(.{});
    defer t.deinit();
    var buffer: [32]u8 = @splat(0);
    var entry = dvui.textEntry(@src(), .{ .text = .{ .buffer = &buffer } }, .{});
    defer entry.deinit();
    entry.textSet("hello", false);
    try std.testing.expectEqualStrings("hello", entry.textGet());
}
