const std = @import("std");
const svg2tvg = @import("svg2tvg");

pub fn main(init: std.process.Init) !void {
    return impl(init);
}

fn impl(init: std.process.Init) !void {
    const allocator = init.arena.allocator();
    const args = try init.minimal.args.toSlice(allocator);

    const input_path = if (args.len > 1) args[1] else {
        std.debug.print("Usage: svg2tvg <svg file> -o <output file>\n", .{});
        return error.NoInputArg;
    };
    // this should be '-o' but we just ignore it
    if (args.len < 3) return error.NoOutputFlag;
    const output_path = if (args.len > 3) args[3] else {
        std.debug.print("Usage: svg2tvg <svg file> -o <output file>\n", .{});
        return error.NoOutputArg;
    };

    errdefer {
        var path_buf: [1024]u8 = undefined;
        std.debug.print("error: input_path='{s}' output_path='{s}'", .{ input_path, output_path });
        const cwd = blk: {
            const len = std.process.currentPath(init.io, &path_buf) catch break :blk "CWD TOO LONG";
            break :blk path_buf[0..len];
        };
        std.debug.print(" cwd='{s}'\n", .{cwd});
    }

    const svg_bytes = try std.Io.Dir.cwd().readFileAlloc(init.io, input_path, allocator, .limited(1 << 16));
    const tvg_bytes = try svg2tvg.tvg_from_svg(allocator, svg_bytes, .{});

    const output_file = try std.Io.Dir.cwd().createFile(init.io, output_path, .{});
    defer output_file.close(init.io);
    var buf: [8192]u8 = undefined;
    var writer = output_file.writer(init.io, &buf);
    try writer.interface.writeAll(tvg_bytes);
    try writer.interface.flush();
    // REPORTME: would be nice to have a
}
