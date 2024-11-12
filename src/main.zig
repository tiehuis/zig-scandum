const std = @import("std");
const gen = @import("generator.zig");
const config = @import("config");

const c = @cImport({
    @cInclude("sorts/sort.h");
});

// TODO: Only support lessThan for comparison but re-structure comparisons in the
// algorithm so they are reversed.
// TODO: Check weak-ordering constraint, likely need to change a lot of code to
// handle correctly as there are some implicit assumptions.
fn desc(comptime T: type) fn (void, T, T) bool {
    return struct {
        pub fn inner(_: void, a: T, b: T) bool {
            return a >= b;
        }
    }.inner;
}

fn asc(comptime T: type) fn (void, T, T) bool {
    return struct {
        pub fn inner(_: void, a: T, b: T) bool {
            return a <= b;
        }
    }.inner;
}

var allocator = std.heap.c_allocator;

const Order = enum { asc, desc };
const CmpFunc = fn (a: ?*const anyopaque, b: ?*const anyopaque) callconv(.C) c_int;

fn compare(comptime T: type, order: Order) CmpFunc {
    return struct {
        fn func(a: ?*const anyopaque, b: ?*const anyopaque) callconv(.C) c_int {
            const at: ?*const T = @ptrCast(@alignCast(a));
            const bt: ?*const T = @ptrCast(@alignCast(b));
            const av = at.?.*;
            const bv = bt.?.*;

            return switch (order) {
                .asc => if (av > bv) 1 else if (av < bv) -1 else 0,
                .desc => if (av > bv) -1 else if (av < bv) 1 else 0,
            };
        }
    }.func;
}

fn piposort_c(comptime T: type, comptime order: Order, a: []T) !void {
    c.piposort(a.ptr, a.len, @sizeOf(T), compare(T, order));
}

fn quadsort_c(comptime T: type, comptime order: Order, a: []T) !void {
    c.quadsort(a.ptr, a.len, @sizeOf(T), compare(T, order));
}

fn blitsort_c(comptime T: type, comptime order: Order, a: []T) !void {
    c.blitsort(a.ptr, a.len, @sizeOf(T), compare(T, order));
}

fn crumsort_c(comptime T: type, comptime order: Order, a: []T) !void {
    c.crumsort(a.ptr, a.len, @sizeOf(T), compare(T, order));
}

fn fluxsort_c(comptime T: type, comptime order: Order, a: []T) !void {
    c.fluxsort(a.ptr, a.len, @sizeOf(T), compare(T, order));
}

fn zigOrder(comptime T: type, order: Order) fn (void, T, T) bool {
    return switch (order) {
        .asc => asc(T),
        .desc => desc(T),
    };
}

fn piposort_zig(comptime T: type, comptime order: Order, a: []T) !void {
    try @import("sorts/piposort.zig").sort(T, allocator, a, {}, zigOrder(T, order));
}

fn quadsort_zig(comptime T: type, comptime order: Order, a: []T) !void {
    try @import("sorts/quadsort.zig").sort(T, allocator, a, {}, zigOrder(T, order));
}

fn blitsort_zig(comptime T: type, comptime order: Order, a: []T) void {
    @import("sorts/blitsort.zig").sort(T, a, {}, zigOrder(T, order));
}

fn fluxsort_zig(comptime T: type, comptime order: Order, a: []T) !void {
    try @import("sorts/fluxsort.zig").sort(T, allocator, a, {}, zigOrder(T, order));
}

fn crumsort_zig(comptime T: type, comptime order: Order, a: []T) !void {
    @import("sorts/crumsort.zig").sort(T, a, {}, zigOrder(T, order));
}

const SortStyle = enum {
    random,
    sorted_asc,
    sorted_desc,
    saw_asc,
    saw_desc,
};

// Sorts a list using the specified algorithm. This program is intended to be run as part of
// a fuzzing framework.
pub fn main() !void {
    // zig-scandum <sort> <length> <seed>

    var args = try std.process.argsWithAllocator(allocator);
    _ = args.next();

    const T = u64; // we use %zu in C code so don't change without changing formatting output
    const order = .asc; // fixed

    var sort: []const u8 = "piposort-zig";
    var seed: u64 = 0;
    var length: usize = 16;
    var sort_style: SortStyle = .random;
    var a: []T = undefined;

    if (args.next()) |arg_sort| {
        sort = arg_sort;
    }
    if (args.next()) |arg_length| {
        length = try std.fmt.parseInt(usize, arg_length, 10);
    }
    if (args.next()) |style| {
        if (std.mem.eql(u8, style, "random")) {
            sort_style = .random;
        } else if (std.mem.eql(u8, style, "sorted-asc")) {
            sort_style = .sorted_asc;
        } else if (std.mem.eql(u8, style, "sorted-desc")) {
            sort_style = .sorted_desc;
        } else if (std.mem.eql(u8, style, "saw-asc")) {
            sort_style = .saw_asc;
        } else if (std.mem.eql(u8, style, "saw-desc")) {
            sort_style = .saw_desc;
        } else {
            return error.UnknownStyle;
        }
    }
    if (args.next()) |arg_seed| {
        seed = try std.fmt.parseInt(u64, arg_seed, 10);
    }

    a = try switch (sort_style) {
        .random => gen.random(T, seed, allocator, length),
        .sorted_asc => gen.sorted(T, seed, allocator, length),
        .sorted_desc => gen.reverse(T, seed, allocator, length),
        .saw_asc => gen.ascSaw(T, seed, allocator, length),
        .saw_desc => gen.descSaw(T, seed, allocator, length),
    };

    std.debug.print("N: {}\n", .{length});
    if (config.trace) std.debug.print("before: {any}\n", .{a});

    // zig
    if (std.mem.eql(u8, sort, "piposort-zig")) {
        try piposort_zig(T, order, a);
    } else if (std.mem.eql(u8, sort, "quadsort-zig")) {
        try quadsort_zig(T, order, a);
    } else if (std.mem.eql(u8, sort, "blitsort-zig")) {
        blitsort_zig(T, order, a);
    } else if (std.mem.eql(u8, sort, "crumsort-zig")) {
        try crumsort_zig(T, order, a);
    } else if (std.mem.eql(u8, sort, "fluxsort-zig")) {
        try fluxsort_zig(T, order, a);
    }
    // c
    else if (std.mem.eql(u8, sort, "piposort-c")) {
        try piposort_c(T, order, a);
    } else if (std.mem.eql(u8, sort, "quadsort-c")) {
        try quadsort_c(T, order, a);
    } else if (std.mem.eql(u8, sort, "blitsort-c")) {
        try blitsort_c(T, order, a);
    } else if (std.mem.eql(u8, sort, "crumsort-c")) {
        try crumsort_c(T, order, a);
    } else if (std.mem.eql(u8, sort, "fluxsort-c")) {
        try fluxsort_c(T, order, a);
    } else {
        return error.UnknownSort;
    }

    if (config.trace) std.debug.print(" after: {any}\n", .{a});
    try assertSorted(T, order, a);
}

fn assertSorted(comptime T: type, comptime order: Order, a: []const T) !void {
    if (a.len == 0) return;

    var i: usize = 0;
    while (i < a.len - 1) : (i += 1) {
        const is_ordered = switch (order) {
            .asc => a[i] <= a[i + 1],
            .desc => a[i] >= a[i + 1],
        };
        if (!is_ordered) {
            std.debug.print("not in correct order a[{}] = {} and a[{}] = {}\n", .{ i, a[i], i + 1, a[i + 1] });
            return error.NotSorted;
        }
    }
}
