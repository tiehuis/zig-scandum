const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});
    const trace = b.option(bool, "trace", "Trace execution during sort") orelse false;

    const exe = b.addExecutable(.{
        .name = "zig-scandum",
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
    });
    exe.addCSourceFiles(.{ .files = &.{
        "src/sorts/piposort.h.c",
        "src/sorts/quadsort.h.c",
        "src/sorts/blitsort.h.c",
        "src/sorts/crumsort.h.c",
        "src/sorts/fluxsort.h.c",
    }, .flags = if (trace) &.{"-DTRACE"} else &.{""} });
    exe.addIncludePath(b.path("src"));
    exe.linkLibC();
    b.installArtifact(exe);

    const fuzz_exe = b.addExecutable(.{
        .name = "zig-fuzz",
        .root_source_file = b.path("src/main_fuzz.zig"),
        .target = target,
        .optimize = optimize,
    });
    fuzz_exe.linkLibC();
    b.installArtifact(fuzz_exe);

    const options = b.addOptions();
    options.addOption(bool, "trace", trace);
    exe.root_module.addOptions("config", options);
    fuzz_exe.root_module.addOptions("config", options);

    const run_cmd = b.addRunArtifact(exe);
    run_cmd.step.dependOn(b.getInstallStep());
    if (b.args) |args| {
        run_cmd.addArgs(args);
    }
    const run_step = b.step("run", "Run the app");
    run_step.dependOn(&run_cmd.step);

    const exe_unit_tests = b.addTest(.{
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
    });

    const run_exe_unit_tests = b.addRunArtifact(exe_unit_tests);

    const test_step = b.step("test", "Run unit tests");
    test_step.dependOn(&run_exe_unit_tests.step);
}
