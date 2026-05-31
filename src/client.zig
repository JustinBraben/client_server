const std = @import("std");
const proto = @import("client_server");

pub fn main(init: std.process.Init) !void {
    const io = init.io;

    std.debug.print("Connecting to {s}:{d}...\n", .{ proto.HOST, proto.PORT });

    const address = try std.Io.net.IpAddress.parseIp4(proto.HOST, proto.PORT);
    const stream = try address.connect(io, .{ .mode = .stream });
    defer stream.close(io);

    std.debug.print("Connected!\n\n", .{});

    var reader_buf: [proto.MAX_MESSAGE_LEN]u8 = undefined;
    var writer_buf: [1024]u8 = undefined;
    var net_reader = stream.reader(io, &reader_buf);
    var net_writer = stream.writer(io, &writer_buf);
    const r = &net_reader.interface;
    const w = &net_writer.interface;

    try exchange(w, r, "PING\n");
    try exchange(w, r, "ECHO Hello from Zig client!\n");
    try exchange(w, r, "ECHO Cross-platform: Windows & macOS\n");
    try exchange(w, r, "QUIT\n");

    std.debug.print("\nSession complete.\n", .{});
}

fn exchange(w: *std.Io.Writer, r: *std.Io.Reader, message: []const u8) !void {
    const trimmed = std.mem.trimEnd(u8, message, "\n");
    std.debug.print("> {s}\n", .{trimmed});

    try w.writeAll(message);
    try w.flush();

    const maybe_resp = r.takeDelimiter('\n') catch |err| switch (err) {
        error.StreamTooLong => {
            std.debug.print("< ERROR: response too long\n", .{});
            return;
        },
        error.ReadFailed => return error.ReadFailed,
    };
    const resp = maybe_resp orelse {
        std.debug.print("< (server closed connection)\n", .{});
        return;
    };
    std.debug.print("< {s}\n", .{std.mem.trimEnd(u8, resp, "\r")});
}
