// fluxsort 1.2.1.3

const std = @import("std");
const config = @import("config");

const quadsort = @import("quadsort.zig");
const blitsort = @import("blitsort.zig");

const flux_aux = 512;
const flux_out = 96; // <= flux_aux

fn o(comptime fmt: []const u8, args: anytype) void {
    if (config.trace) std.debug.print("|flux| " ++ fmt, args);
}

pub fn sort(
    comptime T: type,
    maybe_allocator: ?std.mem.Allocator,
    a: []T,
    context: anytype,
    comptime cmp: fn (context: @TypeOf(context), l: T, r: T) bool,
) !void {
    o("fluxsort: n={}\n", .{a.len}); //

    if (a.len <= 132) {
        var swap: [132 * @sizeOf(T)]u8 = undefined;
        var fba = std.heap.FixedBufferAllocator.init(&swap);
        const allocator = fba.allocator();
        @import("quadsort.zig").sort(T, allocator, a, context, cmp) catch unreachable; // no swap allocated <= 132
    } else {
        if (maybe_allocator) |allocator| {
            o("sort: branch1 with allocator\n", .{});
            const s = try allocator.alloc(T, a.len);
            defer allocator.free(s);
            fluxAnalyze(T, a, s, context, cmp);
        } else {
            o("sort: branch2 no allocator\n", .{});
            quadsort.sort(T, null, a, context, cmp) catch unreachable; // no allocator given
        }
    }
}

pub fn sortWithSwap(
    comptime T: type,
    a: []T,
    s: []T,
    context: anytype,
    comptime cmp: fn (context: @TypeOf(context), l: T, r: T) bool,
) void {
    o("fluxsort_swap: ss={}, n={}\n", .{ s.len, a.len });
    std.debug.assert(s.len >= a.len);

    if (a.len <= 132) {
        quadsort.sortWithSwap(T, a, s, context, cmp);
    } else {
        fluxAnalyze(T, a, s, context, cmp);
    }
}

fn fluxAnalyze(
    comptime T: type,
    a: []T,
    s: []T,
    context: anytype,
    comptime cmp: fn (context: @TypeOf(context), l: T, r: T) bool,
) void {
    const A = 0;
    const B = 1;
    const C = 2;
    const D = 3;

    const half1 = a.len / 2;
    const quad1 = half1 / 2;
    const quad2 = half1 - quad1;
    const half2 = a.len - half1;
    const quad3 = half2 / 2;
    const quad4 = half2 - quad3;

    o("flux_analyze: ss={}, n={}, half1={}, quad1={}, quad2={}, half2={}, quad3={}, quad4={}\n", .{
        s.len, a.len, half1, quad1, quad2, half2, quad3, quad4,
    });

    const quad: [4]usize = .{ quad1, quad2, quad3, quad4 };
    var p: [4]usize = .{ 0, quad1, half1, half1 + quad3 };
    var streaks = [1]usize{0} ** 4;
    var balance = [1]usize{0} ** 4;
    var sum = [1]usize{0} ** 4;

    inline for (1..4) |x| {
        if (quad1 < quad[x]) {
            balance[x] += @intFromBool(!cmp(context, a[p[x]], a[p[x] + 1]));
            p[x] += 1;
        }
    }

    var count = a.len;
    while (count > 132) : (count -= 128) {
        @memset(sum[0..], 0);
        for (0..32) |_| {
            inline for (0..4) |x| {
                sum[x] += @intFromBool(!cmp(context, a[p[x]], a[p[x] + 1]));
                p[x] += 1;
            }
        }

        inline for (0..4) |x| {
            balance[x] += sum[x];
            sum[x] = @intFromBool(sum[x] == 0) | @intFromBool(sum[x] == 32);
            streaks[x] += sum[x];
        }

        if (count > 516 and sum[A] + sum[B] + sum[C] + sum[D] == 0) {
            inline for (0..4) |x| {
                balance[x] += 48;
                p[x] += 96;
            }
            count -= 384;
        }
    }
    while (count > 7) : (count -= 4) {
        inline for (0..4) |x| {
            balance[x] += @intFromBool(!cmp(context, a[p[x]], a[p[x] + 1]));
            p[x] += 1;
        }
    }

    o("flux_analyze: abal={}, bbal={}, cbal={}, dbal={}\n", .{ balance[A], balance[B], balance[C], balance[D] });
    o("flux_analyze: quad1={}, quad2={}, quad3={}, quad4={}\n", .{ quad1, quad2, quad3, quad4 });
    count = balance[A] + balance[B] + balance[C] + balance[D];
    if (count == 0) {
        if (cmp(context, a[p[A]], a[p[A] + 1]) and
            cmp(context, a[p[B]], a[p[B] + 1]) and
            cmp(context, a[p[C]], a[p[C] + 1]))
        {
            o("flux_analyze: branch1\n", .{});
            return;
        }
    }

    inline for (0..4) |x| {
        sum[x] = @intFromBool(quad[x] - balance[x] == 1);
    }

    o("flux_analyze: init sum: asum={}, bsum={}, csum={}, dsum={}\n", .{ sum[A], sum[B], sum[C], sum[D] });
    if (sum[A] | sum[B] | sum[C] | sum[D] != 0) {
        const span1: u3 = @intFromBool(sum[A] != 0 and sum[B] != 0) * @intFromBool(cmp(context, a[p[A]], a[p[A] + 1]));
        const span2: u3 = @intFromBool(sum[B] != 0 and sum[C] != 0) * @intFromBool(cmp(context, a[p[B]], a[p[B] + 1]));
        const span3: u3 = @intFromBool(sum[C] != 0 and sum[D] != 0) * @intFromBool(cmp(context, a[p[C]], a[p[C] + 1]));

        o("flux_analyze: branch2: span1={}, span2={}, span3={}\n", .{ span1, span2, span3 });
        switch (span1 | span2 * 2 | span3 * 4) {
            0 => {},
            1 => {
                quadsort.quadReversal(T, a, 0, p[B]);
                balance[A] = 0;
                balance[B] = 0;
            },
            2 => {
                quadsort.quadReversal(T, a, p[A] + 1, p[C]);
                balance[B] = 0;
                balance[C] = 0;
            },
            3 => {
                quadsort.quadReversal(T, a, 0, p[C]);
                balance[A] = 0;
                balance[B] = 0;
                balance[C] = 0;
            },
            4 => {
                quadsort.quadReversal(T, a, p[B] + 1, p[D]);
                balance[C] = 0;
                balance[D] = 0;
            },
            5 => {
                quadsort.quadReversal(T, a, 0, p[B]);
                quadsort.quadReversal(T, a, p[B] + 1, p[D]);
                balance[A] = 0;
                balance[B] = 0;
                balance[C] = 0;
                balance[D] = 0;
            },
            6 => {
                quadsort.quadReversal(T, a, p[A] + 1, p[D]);
                balance[B] = 0;
                balance[C] = 0;
                balance[D] = 0;
            },
            7 => {
                quadsort.quadReversal(T, a, 0, p[D]);
            },
        }

        inline for (0..4) |x| {
            if (sum[x] != 0 and balance[x] != 0) {
                const start = if (x == 0) 0 else p[x - 1] + 1;
                quadsort.quadReversal(T, a, start, p[x]);
                balance[x] = 0;
            }
        }
    }

    count = a.len / 512; // more than 25% ordered
    inline for (0..4) |x| {
        sum[x] = @intFromBool(streaks[x] > count);
    }

    const sumu4: u4 = @intCast(sum[A] + sum[B] * 2 + sum[C] * 4 + sum[D] * 8);
    o("flux_analyze: branch3: asum={}, bsum={}, csum={}, dsum={}: sum={}\n", .{ sum[A], sum[B], sum[C], sum[D], sumu4 });
    o("flux_analyze: branch3: abal={}, bbal={}, cbal={}, dbal={}\n", .{ balance[A], balance[B], balance[C], balance[D] });
    switch (sumu4) {
        0 => {
            fluxPartition2(T, a, s, s, a.len, context, cmp);
            return;
        },
        1 => {
            if (balance[A] != 0) quadsort.sortWithSwap(T, a[0..quad1], s, context, cmp);
            fluxPartition2(T, a[p[A] + 1 ..][0 .. quad2 + half2], s, s, quad2 + half2, context, cmp);
        },
        2 => {
            fluxPartition2(T, a[0..quad1], s, s, quad1, context, cmp);
            if (balance[B] != 0) quadsort.sortWithSwap(T, a[p[A] + 1 ..][0..quad2], s, context, cmp);
            fluxPartition2(T, a[p[B] + 1 ..][0..half2], s, s, half1, context, cmp);
        },
        3 => {
            if (balance[A] != 0) quadsort.sortWithSwap(T, a[0..quad1], s, context, cmp);
            if (balance[B] != 0) quadsort.sortWithSwap(T, a[p[A] + 1 ..][0..quad2], s, context, cmp);
            fluxPartition2(T, a[p[B] + 1 ..][0..half2], s, s, half2, context, cmp);
        },
        4 => {
            fluxPartition2(T, a[0..half1], s, s, half1, context, cmp);
            if (balance[C] != 0) quadsort.sortWithSwap(T, a[p[B] + 1 ..][0..quad3], s, context, cmp);
            fluxPartition2(T, a[p[C] + 1 ..][0..quad4], s, s, quad4, context, cmp);
        },
        8 => {
            fluxPartition2(T, a[0 .. half1 + quad3], s, s, half1 + quad3, context, cmp);
            if (balance[D] != 0) quadsort.sortWithSwap(T, a[p[C] + 1 ..][0..quad4], s, context, cmp);
        },
        9 => {
            if (balance[A] != 0) quadsort.sortWithSwap(T, a[0..quad1], s, context, cmp);
            fluxPartition2(T, a[p[A] + 1 ..][0 .. quad2 + quad3], s, s, quad2 + quad3, context, cmp);
            if (balance[D] != 0) quadsort.sortWithSwap(T, a[p[C] + 1 ..][0..quad4], s, context, cmp);
        },
        12 => {
            fluxPartition2(T, a[0..half1], s, s, half1, context, cmp);
            if (balance[C] != 0) quadsort.sortWithSwap(T, a[p[B] + 1 ..][0..quad3], s, context, cmp);
            if (balance[D] != 0) quadsort.sortWithSwap(T, a[p[C] + 1 ..][0..quad4], s, context, cmp);
        },
        5, 6, 7, 10, 11, 13, 14, 15 => {
            if (sum[A] != 0) {
                if (balance[A] != 0) quadsort.sortWithSwap(T, a[0..quad1], s, context, cmp);
            } else {
                fluxPartition2(T, a[0..quad1], s, s, quad1, context, cmp);
            }
            if (sum[B] != 0) {
                if (balance[B] != 0) quadsort.sortWithSwap(T, a[p[A] + 1 ..][0..quad2], s, context, cmp);
            } else {
                fluxPartition2(T, a[p[A] + 1 ..][0..quad2], s, s, quad2, context, cmp);
            }
            if (sum[C] != 0) {
                if (balance[C] != 0) quadsort.sortWithSwap(T, a[p[B] + 1 ..][0..quad3], s, context, cmp);
            } else {
                fluxPartition2(T, a[p[B] + 1 ..][0..quad3], s, s, quad3, context, cmp);
            }
            if (sum[D] != 0) {
                if (balance[D] != 0) quadsort.sortWithSwap(T, a[p[C] + 1 ..][0..quad4], s, context, cmp);
            } else {
                fluxPartition2(T, a[p[C] + 1 ..][0..quad4], s, s, quad4, context, cmp);
            }
        },
    }

    o("flux_analyze: final; pa={}, pb={}, pc={}, pd={}\n", .{ p[A], p[B], p[C], p[D] });

    if (cmp(context, a[p[A]], a[p[A] + 1])) {
        if (cmp(context, a[p[C]], a[p[C] + 1])) {
            if (cmp(context, a[p[B]], a[p[B] + 1])) {
                return;
            }
            @memcpy(s[0..a.len], a);
        } else {
            quadsort.crossMerge(T, s[half1..], a[half1..], quad3, quad4, context, cmp);
            @memcpy(s[0..half1], a[0..half1]);
        }
    } else {
        if (cmp(context, a[p[C]], a[p[C] + 1])) {
            @memcpy(s[half1..][0..half2], a[half1..][0..half2]);
            quadsort.crossMerge(T, s, a, quad1, quad2, context, cmp);
        } else {
            quadsort.crossMerge(T, s[half1..], a[p[B] + 1 ..], quad3, quad4, context, cmp);
            quadsort.crossMerge(T, s, a, quad1, quad2, context, cmp);
        }
    }
    quadsort.crossMerge(T, a, s, half1, half2, context, cmp);
}

fn fluxReversePartitionPivot(
    comptime T: type,
    a: []T,
    s: []T,
    x: []T, // always = a
    pivot: []T,
    pivot_i: usize,
    context: anytype,
    comptime cmp: fn (context: @TypeOf(context), l: T, r: T) bool,
) void {
    o("flux_reverse_partition: n={}, pivot={}\n", .{ a.len, pivot[pivot_i] });

    var ax: usize = 0;
    var ai: usize = 0;
    var si: usize = 0;

    for (0..a.len / 8) |_| {
        inline for (0..8) |_| {
            if (!cmp(context, pivot[pivot_i], x[ax])) {
                a[ai] = x[ax];
                ai += 1;
                ax += 1;
            } else {
                s[si] = x[ax];
                si += 1;
                ax += 1;
            }
        }
    }
    for (0..a.len % 8) |_| {
        if (!cmp(context, pivot[pivot_i], x[ax])) {
            a[ai] = x[ax];
            ai += 1;
            ax += 1;
        } else {
            s[si] = x[ax];
            si += 1;
            ax += 1;
        }
    }

    const a_size = ai;
    const s_size = si;

    @memcpy(a[a_size..][0..s_size], s[0..s_size]);
    if (s_size <= a_size / 16 or a_size <= flux_out) {
        quadsort.sortWithSwap(T, a[0..a_size], s[0..s_size], context, cmp);
        return;
    }
    fluxPartition(T, a[0..a_size], s[0..a_size], a[0..a_size], pivot, pivot_i, context, cmp);
}

fn fluxDefaultPartitionPivot(
    comptime T: type,
    a: []T,
    s: []T,
    x: []T,
    pivot: T,
    context: anytype,
    comptime cmp: fn (context: @TypeOf(context), l: T, r: T) bool,
) usize {
    o("flux_default_partition: n={}, pivot={}\n", .{ a.len, pivot });

    var ai: usize = 0;
    var si: usize = 0;
    var xi: usize = 0;
    var run: usize = 0;

    var r: usize = 8;
    while (r <= a.len) : (r += 8) {
        inline for (0..8) |_| {
            if (cmp(context, x[xi], pivot)) {
                a[ai] = x[xi];
                ai += 1;
                xi += 1;
            } else {
                s[si] = x[xi];
                si += 1;
                xi += 1;
            }
        }
        if (ai == 0 or si == 0) run = r;
    }
    for (0..a.len % 8) |_| {
        if (cmp(context, x[xi], pivot)) {
            a[ai] = x[xi];
            ai += 1;
            xi += 1;
        } else {
            s[si] = x[xi];
            si += 1;
            xi += 1;
        }
    }

    const m = ai;
    o("flux_default_partition: run={}, m={}\n", .{ run, m });
    if (run <= a.len / 4 or m == a.len) {
        return m;
    }

    ai = a.len - m;
    @memcpy(a[m..][0..ai], s[0..ai]);
    quadsort.sortWithSwap(T, a[m..][0..ai], s[0..ai], context, cmp);
    quadsort.sortWithSwap(T, a[0..m], s[0..m], context, cmp);
    return 0;
}

// fluxPartition where x == a
fn fluxPartition2(
    comptime T: type,
    a: []T,
    s: []T,
    pivot: []T,
    pivot_i: usize,
    context: anytype,
    comptime cmp: fn (context: @TypeOf(context), l: T, r: T) bool,
) void {
    return fluxPartition(T, a, s, a, pivot, pivot_i, context, cmp);
}

fn fluxPartition(
    comptime T: type,
    a: []T,
    s: []T,
    x_: []T,
    pivot: []T,
    pivot_i_: usize,
    context: anytype,
    comptime cmp: fn (context: @TypeOf(context), l: T, r: T) bool,
) void {
    var pivot_i = pivot_i_;
    var x = x_;
    o("flux_partition: n={}\n", .{a.len});

    var len = a.len;
    var generic = false;
    var a_size: usize = 0;
    var s_size: usize = undefined;

    while (true) {
        pivot_i -= 1;

        if (len <= 2048) {
            pivot[pivot_i] = blitsort.blitMedianOfNine(T, x[0..len], context, cmp);
        } else {
            pivot[pivot_i] = if (x.ptr == s.ptr)
                blitsort.blitMedianOfCbrt(T, a, s, &generic, context, cmp)
            else
                blitsort.blitMedianOfCbrt(T, a, a, &generic, context, cmp);

            if (generic) {
                if (x.ptr == s.ptr) {
                    @memcpy(a[0..len], s[0..len]);
                }
                quadsort.sortWithSwap(T, a[0..len], s[0..len], context, cmp);
                return;
            }
        }
        o("flux_partition: pivot={}\n", .{pivot[pivot_i]});

        if (a_size != 0 and cmp(context, pivot[pivot_i + 1], pivot[pivot_i])) {
            fluxReversePartitionPivot(T, a[0..len], s, a[0..len], pivot, pivot_i, context, cmp);
            return;
        }
        a_size = fluxDefaultPartitionPivot(T, a[0..len], s, x, pivot[pivot_i], context, cmp);
        s_size = len - a_size;
        o("flux_partition: a_size={}, s_size={}\n", .{ a_size, s_size });

        if (a_size <= s_size / 32 or s_size <= flux_out) {
            if (a_size == 0) {
                return;
            }
            if (s_size == 0) {
                fluxReversePartitionPivot(T, a[0..a_size], s[0..a_size], a[0..a_size], pivot, pivot_i, context, cmp);
                return;
            }
            @memcpy(a[a_size..][0..s_size], s[0..s_size]);
            quadsort.sortWithSwap(T, a[a_size..][0..s_size], s[0..s_size], context, cmp);
        } else {
            fluxPartition(T, a[a_size..][0..s_size], s[0..s_size], s[0..s_size], pivot, pivot_i, context, cmp);
        }

        if (s_size <= a_size / 32 or a_size <= flux_out) {
            if (a_size <= flux_out) {
                quadsort.sortWithSwap(T, a[0..a_size], s[0..a_size], context, cmp);
            } else {
                fluxReversePartitionPivot(T, a[0..a_size], s[0..a_size], a[0..a_size], pivot, pivot_i, context, cmp);
            }
            return;
        }

        len = a_size;
        x = a;
    }
}
