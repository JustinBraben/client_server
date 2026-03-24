//! Common protocol definitions shared by client and server.
const std = @import("std");

pub const PORT: u16 = 7777;
pub const HOST: []const u8 = "127.0.0.1";
pub const MAX_MESSAGE_LEN: usize = 4096;

/// A parsed client command.
pub const Command = union(enum) {
    ping,
    echo: []const u8,
    quit,
    unknown: []const u8,

    /// Parse a line received from the network (may contain a trailing \r).
    /// The returned slice borrows from `line`.
    pub fn parse(line: []const u8) Command {
        const trimmed = std.mem.trimRight(u8, line, "\r\n");
        if (std.mem.eql(u8, trimmed, "PING")) return .ping;
        if (std.mem.eql(u8, trimmed, "QUIT")) return .quit;
        if (std.mem.startsWith(u8, trimmed, "ECHO ") and trimmed.len > 5)
            return .{ .echo = trimmed[5..] };
        return .{ .unknown = trimmed };
    }
};

test "parse PING" {
    try std.testing.expect(Command.parse("PING") == .ping);
}

test "parse PING with CRLF" {
    try std.testing.expect(Command.parse("PING\r\n") == .ping);
}

test "parse PING with LF" {
    try std.testing.expect(Command.parse("PING\n") == .ping);
}

test "parse QUIT" {
    try std.testing.expect(Command.parse("QUIT") == .quit);
}

test "parse ECHO with payload" {
    const cmd = Command.parse("ECHO hello world");
    try std.testing.expect(cmd == .echo);
    try std.testing.expectEqualStrings("hello world", cmd.echo);
}

test "parse ECHO with payload and CRLF" {
    const cmd = Command.parse("ECHO hello world\r\n");
    try std.testing.expect(cmd == .echo);
    try std.testing.expectEqualStrings("hello world", cmd.echo);
}

test "parse bare ECHO without payload is unknown" {
    try std.testing.expect(Command.parse("ECHO") == .unknown);
}

test "parse ECHO with only a space is unknown" {
    // "ECHO " has length 5, not > 5, so treated as unknown
    try std.testing.expect(Command.parse("ECHO ") == .unknown);
}

test "parse unknown command" {
    const cmd = Command.parse("INVALID");
    try std.testing.expect(cmd == .unknown);
    try std.testing.expectEqualStrings("INVALID", cmd.unknown);
}

test "parse empty line is unknown" {
    try std.testing.expect(Command.parse("") == .unknown);
    try std.testing.expect(Command.parse("\r\n") == .unknown);
}
