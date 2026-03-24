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

    var reader_buf: [proto.MAX_MESSAGE_LEN]u8 = undefined;
    var writer_buf: [1024]u8 = undefined;
    var net_reader = stream.reader(&reader_buf);
    var net_writer = stream.writer(&writer_buf);
    // reader.interface() is a method returning *Io.Reader
    // writer.interface is a field of type Io.Writer
    const r = net_reader.interface();
    const w = &net_writer.interface;

    try exchange(w, r, "PING\n");
    try exchange(w, r, "ECHO Hello from Zig client!\n");
    try exchange(w, r, "ECHO Cross-platform: Windows & macOS\n");
    try exchange(w, r, "QUIT\n");

    std.debug.print("\nSession complete.\n", .{});
}

/// Send a message and print the server's response.
fn exchange(w: *std.Io.Writer, r: *std.Io.Reader, message: []const u8) !void {
    const trimmed = std.mem.trimRight(u8, message, "\n");
    std.debug.print("> {s}\n", .{trimmed});

    try w.writeAll(message);
    // Don't forget to flush so the server actually receives the data
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
    // takeDelimiter excludes '\n'; trim any '\r' for CRLF tolerance
    std.debug.print("< {s}\n", .{std.mem.trimRight(u8, resp, "\r")});
}
