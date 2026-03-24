const std = @import("std");
const proto = @import("client_server");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    std.debug.print("Connecting to {s}:{d}...\n", .{ proto.HOST, proto.PORT });

    const stream = try std.net.tcpConnectToHost(allocator, proto.HOST, proto.PORT);
    defer stream.close();

    std.debug.print("Connected!\n\n", .{});

    var buf: [proto.MAX_MESSAGE_LEN]u8 = undefined;
    var reader_buf: [1024]u8 = undefined;
    var writer_buf: [1024]u8 = undefined;
    const reader = stream.reader(&reader_buf);
    const writer = stream.writer(&writer_buf);

    // PING
    try sendAndReceive(writer, reader, &buf, "PING\n");

    // ECHO messages
    try sendAndReceive(writer, reader, &buf, "ECHO Hello from Zig client!\n");
    try sendAndReceive(writer, reader, &buf, "ECHO Cross-platform: Windows & macOS\n");

    // QUIT
    try sendAndReceive(writer, reader, &buf, "QUIT\n");

    std.debug.print("\nSession complete.\n", .{});
}

fn sendAndReceive(
    writer: anytype,
    reader: anytype,
    buf: []u8,
    message: []const u8,
) !void {
    const trimmed = std.mem.trimRight(u8, message, "\n");
    std.debug.print("> {s}\n", .{trimmed});
    try writer.interface.writeAll(message);

    const maybe_resp = try reader.readUntilDelimiterOrEof(buf, '\n');
    const resp = maybe_resp orelse {
        std.debug.print("< (server closed connection)\n", .{});
        return;
    };
    std.debug.print("< {s}\n", .{std.mem.trimRight(u8, resp, "\r\n")});
}
