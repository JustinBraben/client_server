const std = @import("std");
const proto = @import("client_server");

pub fn main() !void {
    const address = try std.net.Address.parseIp4("0.0.0.0", proto.PORT);
    var server = try address.listen(.{ .reuse_address = true });
    defer server.deinit();

    std.debug.print("Server listening on 0.0.0.0:{d}\n", .{proto.PORT});
    std.debug.print("Press Ctrl+C to stop.\n", .{});

    while (true) {
        const conn = server.accept() catch |err| {
            std.debug.print("accept error: {any}\n", .{err});
            continue;
        };
        std.debug.print("[+] client connected from {any}\n", .{conn.address});
        handleClient(conn.stream) catch |err| {
            std.debug.print("[!] client handler error: {any}\n", .{err});
        };
        conn.stream.close();
        std.debug.print("[-] client disconnected\n", .{});
    }
}

fn handleClient(stream: std.net.Stream) !void {
    var reader_buf: [proto.MAX_MESSAGE_LEN]u8 = undefined;
    var writer_buf: [512]u8 = undefined;
    var net_reader = stream.reader(&reader_buf);
    var net_writer = stream.writer(&writer_buf);
    // reader.interface() is a method that returns *Io.Reader
    // writer.interface is a field of type Io.Writer
    const r = net_reader.interface();
    const w = &net_writer.interface;

    while (true) {
        // takeDelimiter reads up to (but not including) '\n', returns null on EOF.
        const maybe_line = r.takeDelimiter('\n') catch |err| switch (err) {
            error.StreamTooLong => {
                // Line exceeded reader buffer — tell client and skip the rest of the line.
                try w.writeAll("ERROR: message too long\n");
                try w.flush();
                _ = r.discardDelimiterInclusive('\n') catch {};
                continue;
            },
            error.ReadFailed => return error.ReadFailed,
        };
        const line = maybe_line orelse break; // null = client closed connection (EOF)

        const cmd = proto.Command.parse(line);
        switch (cmd) {
            .ping => {
                std.debug.print("  < PING\n", .{});
                try w.writeAll("PONG\n");
                try w.flush();
                std.debug.print("  > PONG\n", .{});
            },
            .echo => |payload| {
                std.debug.print("  < ECHO {s}\n", .{payload});
                try w.print("ECHO: {s}\n", .{payload});
                try w.flush();
                std.debug.print("  > ECHO: {s}\n", .{payload});
            },
            .quit => {
                std.debug.print("  < QUIT\n", .{});
                try w.writeAll("BYE\n");
                try w.flush();
                std.debug.print("  > BYE\n", .{});
                break;
            },
            .unknown => |raw| {
                std.debug.print("  < UNKNOWN: '{s}'\n", .{raw});
                try w.print("ERROR: unknown command '{s}'\n", .{raw});
                try w.flush();
            },
        }
    }
}
