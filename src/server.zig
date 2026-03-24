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
            std.debug.print("accept error: {}\n", .{err});
            continue;
        };
        std.debug.print("[+] client connected from {}\n", .{conn.address});
        handleClient(conn.stream) catch |err| {
            std.debug.print("[!] client handler error: {}\n", .{err});
        };
        conn.stream.close();
        std.debug.print("[-] client disconnected\n", .{});
    }
}

fn handleClient(stream: std.net.Stream) !void {
    var buf: [proto.MAX_MESSAGE_LEN]u8 = undefined;
    const reader = stream.reader();
    const writer = stream.writer();

    while (true) {
        // readUntilDelimiterOrEof returns the data before '\n', or null on EOF.
        const maybe_line = reader.readUntilDelimiterOrEof(&buf, '\n') catch |err| switch (err) {
            error.StreamTooLong => {
                try writer.writeAll("ERROR: message too long\n");
                continue;
            },
            else => return err,
        };
        const line = maybe_line orelse break; // client closed connection

        const cmd = proto.Command.parse(line);
        switch (cmd) {
            .ping => {
                std.debug.print("  < PING\n", .{});
                try writer.writeAll("PONG\n");
                std.debug.print("  > PONG\n", .{});
            },
            .echo => |payload| {
                std.debug.print("  < ECHO {s}\n", .{payload});
                try writer.print("ECHO: {s}\n", .{payload});
                std.debug.print("  > ECHO: {s}\n", .{payload});
            },
            .quit => {
                std.debug.print("  < QUIT\n", .{});
                try writer.writeAll("BYE\n");
                std.debug.print("  > BYE\n", .{});
                break;
            },
            .unknown => |raw| {
                std.debug.print("  < UNKNOWN: '{s}'\n", .{raw});
                try writer.print("ERROR: unknown command '{s}'\n", .{raw});
            },
        }
    }
}
