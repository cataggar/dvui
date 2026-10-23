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

test "backend provisions decode a real raster image" {
    const image = try dvui.Color.PMAImage.fromImageFile("zig-favicon", std.testing.allocator, dvui.Examples.zig_favicon);
    defer std.testing.allocator.free(image.pma);
    try std.testing.expectEqual(@as(u32, 16), image.width);
    try std.testing.expectEqual(@as(u32, 16), image.height);
    try std.testing.expectEqual(@as(usize, image.width) * image.height, image.pma.len);
}

test "disabled TVG conversion reports an explicit error" {
    if (dvui.useTvg) return error.SkipZigTest;
    var t = try dvui.testing.init(.{});
    defer t.deinit();
    try std.testing.expectError(error.tvgError, dvui.svgToTvg(std.testing.allocator, ""));
    try std.testing.expectError(error.tvgError, dvui.Color.PMAImage.fromTvgFile(
        "disabled",
        std.testing.allocator,
        std.testing.allocator,
        "",
        1,
        .{},
    ));
    const width = try dvui.iconWidth("disabled", "", 24);
    try std.testing.expect(width > 0);
    try std.testing.expectEqual(width, try dvui.iconWidth("disabled", "not TinyVG", 24));
}
