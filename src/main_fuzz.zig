const std = @import("std");
const gen = @import("generator.zig");

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

    const count = 5;

    fn name(s: SortStyle) []const u8 {
        return switch (s) {
            .random => "random",
            .sorted_asc => "sorted-asc",
            .sorted_desc => "sorted-desc",
            .saw_asc => "saw-asc",
            .saw_desc => "saw-desc",
        };
    }
};

const Sort = enum {
    piposort,
    quadsort,
    blitsort,
    crumsort,
    fluxsort,

    const count = 5;

    fn name(s: Sort) []const u8 {
        return @tagName(s);
    }
};

fn fillArray(comptime T: type, sort_style: SortStyle, seed: u64, a: []T) void {
    switch (sort_style) {
        .random => gen.fillRandom(T, seed, a),
        .sorted_asc => gen.fillSorted(T, seed, a),
        .sorted_desc => gen.fillReverse(T, seed, a),
        .saw_asc => gen.fillAscSaw(T, seed, a),
        .saw_desc => gen.fillDescSaw(T, seed, a),
    }
}

fn sortArray(comptime T: type, comptime order: Order, sort: Sort, a: []T) !void {
    try switch (sort) {
        .piposort => piposort_zig(T, order, a),
        .quadsort => quadsort_zig(T, order, a),
        .blitsort => blitsort_zig(T, order, a),
        .crumsort => crumsort_zig(T, order, a),
        .fluxsort => fluxsort_zig(T, order, a),
    };
}

fn isSorted(comptime T: type, comptime order: Order, a: []const T) bool {
    if (a.len == 0) return true;
    var i: usize = 0;
    while (i < a.len - 1) : (i += 1) {
        const is_ordered = switch (order) {
            .asc => a[i] <= a[i + 1],
            .desc => a[i] >= a[i + 1],
        };
        if (!is_ordered) return false;
    }
    return true;
}

// TODO: Use a instrumented fuzzer instead (try integrate with the zig fuzzing framework here).
pub fn main() !void {
    const T = u64; // we use %zu in C code so don't change without changing formatting output
    const order = .asc; // fixed

    var args = try std.process.argsWithAllocator(allocator);
    _ = args.next();

    var sort: Sort = undefined;
    if (args.next()) |arg_sort| {
        if (std.mem.eql(u8, arg_sort, "piposort")) {
            sort = .piposort;
        } else if (std.mem.eql(u8, arg_sort, "quadsort")) {
            sort = .quadsort;
        } else if (std.mem.eql(u8, arg_sort, "blitsort")) {
            sort = .blitsort;
        } else if (std.mem.eql(u8, arg_sort, "crumsort")) {
            sort = .crumsort;
        } else if (std.mem.eql(u8, arg_sort, "fluxsort")) {
            sort = .fluxsort;
        } else {
            std.debug.print("unknown sort: '{s}'\n", .{arg_sort});
            std.process.exit(1);
        }
    } else {
        std.debug.print("fuzz <sort>\n", .{});
        std.process.exit(1);
    }

    const max_length = 10000;
    const seed = std.crypto.random.int(u64);
    var prng = std.Random.DefaultPrng.init(seed);
    const rand = prng.random();

    var a_storage = try allocator.alloc(T, max_length);
    defer allocator.free(a_storage);

    var i: usize = 1;
    while (true) : (i += 1) {
        if (i % 10_000 == 0) std.debug.print("{}\n", .{i});

        const sort_style: SortStyle = @enumFromInt(rand.intRangeAtMost(usize, 0, SortStyle.count - 1));
        const length = rand.intRangeAtMost(usize, 1, max_length);
        const a_seed = rand.int(u64);
        const a = a_storage[0..length];
        fillArray(T, sort_style, a_seed, a);

        try sortArray(T, order, sort, a);
        if (!isSorted(T, order, a)) {
            std.debug.print(
                \\ # not sorted!
                \\
                \\ iteration:  {}
                \\ sort:       {s}
                \\ sort_style: {s}
                \\ order:      {s}
                \\ seed:       {}
                \\ length:     {}
                \\
                \\
                \\ ./diff {s} {} {s} {}
                \\
            , .{
                i,
                @tagName(sort),
                @tagName(sort_style),
                @tagName(order),
                a_seed,
                a.len,

                sort.name(),
                a.len,
                sort_style.name(),
                a_seed,
            });
            return;
        }
    }
}
