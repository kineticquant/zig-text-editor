const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const exe = b.addExecutable(.{
        .name = "lw-zig-editor",
        .root_source_file = b.path("src/main.zig"), // Correct usage
        .target = target,
        .optimize = optimize,
    });

    // Add zigwin32 dependency
    const zigwin32 = b.dependency("zigwin32", .{}); // Remove target and optimize options

    // Add the zigwin32 module to the executable
    exe.root_module.addImport("zigwin32", zigwin32.module("zigwin32"));

    // Link system libraries
    exe.linkSystemLibrary("user32");
    exe.linkSystemLibrary("gdi32");

    // Install the executable
    b.installArtifact(exe);

    // Add a run step
    const run_cmd = b.addRunArtifact(exe);
    run_cmd.step.dependOn(b.getInstallStep());

    if (b.args) |args| {
        run_cmd.addArgs(args);
    }

    const run_step = b.step("run", "Run the app");
    run_step.dependOn(&run_cmd.step);
}