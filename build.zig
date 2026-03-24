const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    // Common protocol module (src/root.zig)
    const proto_mod = b.addModule("client_server", .{
        .root_source_file = b.path("src/root.zig"),
        .target = target,
    });

    // Server executable
    const server_exe = b.addExecutable(.{
        .name = "server",
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/server.zig"),
            .target = target,
            .optimize = optimize,
            .imports = &.{
                .{ .name = "client_server", .module = proto_mod },
            },
        }),
    });
    b.installArtifact(server_exe);

    const run_server_cmd = b.addRunArtifact(server_exe);
    run_server_cmd.step.dependOn(b.getInstallStep());
    const run_server_step = b.step("run-server", "Build and run the TCP server");
    run_server_step.dependOn(&run_server_cmd.step);

    // Client executable
    const client_exe = b.addExecutable(.{
        .name = "client",
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/client.zig"),
            .target = target,
            .optimize = optimize,
            .imports = &.{
                .{ .name = "client_server", .module = proto_mod },
            },
        }),
    });
    b.installArtifact(client_exe);

    const run_client_cmd = b.addRunArtifact(client_exe);
    run_client_cmd.step.dependOn(b.getInstallStep());
    const run_client_step = b.step("run-client", "Build and run the TCP client");
    run_client_step.dependOn(&run_client_cmd.step);

    // Unit tests (protocol parsing logic in src/root.zig)
    const proto_tests = b.addTest(.{
        .root_module = proto_mod,
    });
    const run_proto_tests = b.addRunArtifact(proto_tests);

    const test_step = b.step("test", "Run protocol unit tests");
    test_step.dependOn(&run_proto_tests.step);
}
