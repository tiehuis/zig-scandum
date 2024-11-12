// crumsort 1.2.1.3

const std = @import("std");
const config = @import("config");

const quadsort = @import("quadsort.zig");

const crum_aux = 512;
const crum_out = 96; // <= crum_aux

fn o(comptime fmt: []const u8, args: anytype) void {
    if (config.trace) std.debug.print("|crum| " ++ fmt, args);
}

pub fn sort(
    comptime T: type,
    a: []T,
    context: anytype,
    comptime cmp: fn (context: @TypeOf(context), l: T, r: T) bool,
) void {
    o("crumsort: n={}\n", .{a.len});

    if (a.len <= 256) {
        var swap: [256 * @sizeOf(T)]u8 = undefined;
        var fba = std.heap.FixedBufferAllocator.init(&swap);
        const allocator = fba.allocator();
        @import("quadsort.zig").sort(T, allocator, a, context, cmp) catch unreachable; // swap allocated <= 132
    } else {
        var s: [crum_aux]T = undefined;
        crumAnalyze(T, a, s[0..], context, cmp);
    }
}

pub fn crumAnalyze(
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

    o("crum_analyze: ss={}, n={}, half1={}, quad1={}, quad2={}, half2={}, quad3={}, quad4={}\n", .{
        s.len, a.len, half1, quad1, quad2, half2, quad3, quad4,
    });

    const quad: [4]usize = .{ quad1, quad2, quad3, quad4 };
    var p: [4]usize = .{ 0, quad1, half1, half1 + quad3 };
    var streaks = [1]usize{0} ** 4;
    var balance = [1]usize{0} ** 4;
    var sum = [1]usize{0} ** 4;

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

    inline for (1..4) |x| {
        if (quad1 < quad[x]) {
            balance[x] += @intFromBool(!cmp(context, a[p[x]], a[p[x] + 1]));
            p[x] += 1;
        }
    }

    o("crum_analyze: abal={}, bbal={}, cbal={}, dbal={}\n", .{ balance[A], balance[B], balance[C], balance[D] });
    o("crum_analyze: quad1={}, quad2={}, quad3={}, quad4={}\n", .{ quad1, quad2, quad3, quad4 });
    count = balance[A] + balance[B] + balance[C] + balance[D];
    if (count == 0) {
        if (cmp(context, a[p[A]], a[p[A] + 1]) and
            cmp(context, a[p[B]], a[p[B] + 1]) and
            cmp(context, a[p[C]], a[p[C] + 1]))
        {
            o("crum_analyze: branch1\n", .{});
            return;
        }
    }

    inline for (0..4) |x| {
        sum[x] = @intFromBool(quad[x] - balance[x] == 1);
    }

    o("crum_analyze: init sum: asum={}, bsum={}, csum={}, dsum={}\n", .{ sum[A], sum[B], sum[C], sum[D] });
    if (sum[A] | sum[B] | sum[C] | sum[D] != 0) {
        const span1: u3 = @intFromBool(sum[A] != 0 and sum[B] != 0) * @intFromBool(cmp(context, a[p[A]], a[p[A] + 1]));
        const span2: u3 = @intFromBool(sum[B] != 0 and sum[C] != 0) * @intFromBool(cmp(context, a[p[B]], a[p[B] + 1]));
        const span3: u3 = @intFromBool(sum[C] != 0 and sum[D] != 0) * @intFromBool(cmp(context, a[p[C]], a[p[C] + 1]));

        o("crum_analyze: branch2: span1={}, span2={}, span3={}\n", .{ span1, span2, span3 });
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

    o("crum_analyze: branch3: asum={}, bsum={}, csum={}, dsum={}\n", .{ sum[A], sum[B], sum[C], sum[D] });
    const sumu4: u4 = @intCast(sum[A] + sum[B] * 2 + sum[C] * 4 + sum[D] * 8);
    switch (sumu4) {
        0 => {
            fulcrumPartition(T, a, s, null, context, cmp);
            return;
        },
        1 => {
            if (balance[A] != 0) quadsort.sortWithSwap(T, a[0..quad1], s, context, cmp);
            fulcrumPartition(T, a[p[A] + 1 ..][0 .. quad2 + half2], s[0..], null, context, cmp);
        },
        2 => {
            fulcrumPartition(T, a[0..quad1], s, null, context, cmp);
            if (balance[B] != 0) quadsort.sortWithSwap(T, a[p[A] + 1 ..][0..quad2], s, context, cmp);
            fulcrumPartition(T, a[p[B] + 1 ..][0..half2], s, null, context, cmp);
        },
        3 => {
            if (balance[A] != 0) quadsort.sortWithSwap(T, a[0..quad1], s, context, cmp);
            if (balance[B] != 0) quadsort.sortWithSwap(T, a[p[A] + 1 ..][0..quad2], s, context, cmp);
            fulcrumPartition(T, a[p[B] + 1 ..][0..half2], s, null, context, cmp);
        },
        4 => {
            fulcrumPartition(T, a[0..half1], s, null, context, cmp);
            if (balance[C] != 0) quadsort.sortWithSwap(T, a[p[B] + 1 ..][0..quad3], s, context, cmp);
            fulcrumPartition(T, a[p[C] + 1 ..][0..quad4], s, null, context, cmp);
        },
        8 => {
            fulcrumPartition(T, a[0 .. half1 + quad3], s, null, context, cmp);
            if (balance[D] != 0) quadsort.sortWithSwap(T, a[p[C] + 1 ..][0..quad4], s, context, cmp);
        },
        9 => {
            if (balance[A] != 0) quadsort.sortWithSwap(T, a[0..quad1], s, context, cmp);
            fulcrumPartition(T, a[p[A] + 1 ..][0 .. quad2 + quad3], s, null, context, cmp);
            if (balance[D] != 0) quadsort.sortWithSwap(T, a[p[C] + 1 ..][0..quad4], s, context, cmp);
        },
        12 => {
            fulcrumPartition(T, a[0..half1], s, null, context, cmp);
            if (balance[C] != 0) quadsort.sortWithSwap(T, a[p[B] + 1 ..][0..quad3], s, context, cmp);
            if (balance[D] != 0) quadsort.sortWithSwap(T, a[p[C] + 1 ..][0..quad4], s, context, cmp);
        },
        5, 6, 7, 10, 11, 13, 14, 15 => {
            if (sum[A] != 0) {
                if (balance[A] != 0) quadsort.sortWithSwap(T, a[0..quad1], s, context, cmp);
            } else {
                fulcrumPartition(T, a[0..quad1], s, null, context, cmp);
            }
            if (sum[B] != 0) {
                if (balance[B] != 0) quadsort.sortWithSwap(T, a[p[A] + 1 ..][0..quad2], s, context, cmp);
            } else {
                fulcrumPartition(T, a[p[A] + 1 ..][0..quad2], s, null, context, cmp);
            }
            if (sum[C] != 0) {
                if (balance[C] != 0) quadsort.sortWithSwap(T, a[p[B] + 1 ..][0..quad3], s, context, cmp);
            } else {
                fulcrumPartition(T, a[p[B] + 1 ..][0..quad3], s, null, context, cmp);
            }
            if (sum[D] != 0) {
                if (balance[D] != 0) quadsort.sortWithSwap(T, a[p[C] + 1 ..][0..quad4], s, context, cmp);
            } else {
                fulcrumPartition(T, a[p[C] + 1 ..][0..quad4], s, null, context, cmp);
            }
        },
    }

    o("crum_analyze: final; pa={}, pb={}, pc={}, pd={}\n", .{ p[A], p[B], p[C], p[D] });

    if (cmp(context, a[p[A]], a[p[A] + 1])) {
        if (cmp(context, a[p[C]], a[p[C] + 1])) {
            if (cmp(context, a[p[B]], a[p[B] + 1])) {
                return;
            }
        } else {
            quadsort.rotateMergeBlock(T, a[half1..], s, quad3, quad4, context, cmp);
        }
    } else {
        quadsort.rotateMergeBlock(T, a, s, quad1, quad2, context, cmp);
        if (!cmp(context, a[p[C]], a[p[C] + 1])) {
            quadsort.rotateMergeBlock(T, a[half1..], s, quad3, quad4, context, cmp);
        }
    }
    quadsort.rotateMergeBlock(T, a, s, half1, half2, context, cmp);
}

pub fn crumBinaryMedian(
    comptime T: type,
    a: []T,
    b: []T,
    len_: usize,
    context: anytype,
    comptime cmp: fn (context: @TypeOf(context), l: T, r: T) bool,
) T {
    var len = len_;
    o("crum_binary_median: l={}\n", .{len});

    var ai: usize = 0;
    var bi: usize = 0;
    while (len != 0) : (len /= 2) {
        if (cmp(context, a[ai..][len], b[bi..][len])) {
            ai += len;
        } else {
            bi += len;
        }
    }

    const r = if (!cmp(context, a[ai], b[bi])) a[ai] else b[bi];
    o("crum_binary_median: result={}\n", .{r});
    return r;
}

pub fn crumTrimFour(
    comptime T: type,
    a: []T,
    context: anytype,
    comptime cmp: fn (context: @TypeOf(context), l: T, r: T) bool,
) void {
    o("crum_trim_four\n", .{});
    std.debug.assert(a.len >= 4);

    quadsort.branchlessSwap(T, a[0..], context, cmp);
    quadsort.branchlessSwap(T, a[2..], context, cmp);

    const x: u2 = @intFromBool(cmp(context, a[0], a[2]));
    a[2] = a[2 * x];
    const y: u2 = @intFromBool(!cmp(context, a[1], a[3]));
    a[1] = a[1 + 2 * y];
}

fn crumMedianOfThree(
    comptime T: type,
    a: []T,
    v0: usize,
    v1: usize,
    v2: usize,
    context: anytype,
    comptime cmp: fn (context: @TypeOf(context), l: T, r: T) bool,
) usize {
    o("crum_median_of_three: v0={}, v1={}, v2={}\n", .{ v0, v1, v2 });

    const x: u2 = @intFromBool(cmp(context, a[v0], a[v1]));
    const y: u2 = @intFromBool(cmp(context, a[v0], a[v2]));
    const z: u2 = @intFromBool(cmp(context, a[v1], a[v2]));

    const r: [3]usize = .{ v0, v1, v2 };
    return r[@intFromBool(x == y) + (y ^ z)];
}

pub fn crumMedianOfNine(
    comptime T: type,
    a: []T,
    context: anytype,
    comptime cmp: fn (context: @TypeOf(context), l: T, r: T) bool,
) usize {
    o("crum_median_of_nine: n={}\n", .{a.len});
    const div = a.len / 16;

    const x = crumMedianOfThree(T, a, div * 2, div * 1, div * 4, context, cmp);
    const y = crumMedianOfThree(T, a, div * 8, div * 6, div * 10, context, cmp);
    const z = crumMedianOfThree(T, a, div * 14, div * 12, div * 15, context, cmp);

    const p = crumMedianOfThree(T, a, x, y, z, context, cmp);
    const r = a[p];
    o("crum_median_of_nine: result={}\n", .{r});
    return p;
}

pub fn crumMedianOfCbrt(
    comptime T: type,
    a: []T,
    s: []T,
    generic: *bool,
    context: anytype,
    comptime cmp: fn (context: @TypeOf(context), l: T, r: T) bool,
) usize {
    o("crum_median_of_cbrt: ss={}, n={}\n", .{ s.len, a.len });

    var cbrt: usize = 32;
    while (cbrt * cbrt * cbrt < a.len and cbrt < s.len) cbrt *= 2;

    const div = a.len / cbrt;
    var ai: usize = 0;
    for (0..cbrt) |i| {
        s[i] = a[ai];
        ai += div;
    }

    var sa: usize = 0;
    var sb = cbrt / 2;

    var i = cbrt / 8;
    while (i != 0) : (i -= 1) {
        crumTrimFour(T, s[sa..], context, cmp);
        crumTrimFour(T, s[sb..], context, cmp);
        s[sa + 0] = s[sb + 1];
        s[sa + 3] = s[sb + 2];
        sa += 4;
        sb += 4;
    }
    cbrt /= 4;

    quadsort.sortWithSwap(T, s[0..cbrt], s[cbrt * 2 ..][0..cbrt], context, cmp);
    quadsort.sortWithSwap(T, s[cbrt..][0..cbrt], s[cbrt * 2 ..][0..cbrt], context, cmp);
    generic.* = cmp(context, s[cbrt * 2 - 1], s[0]);
    const r = crumBinaryMedian(T, s, s[cbrt..], cbrt, context, cmp);
    o("crum_median_of_cbrt: result={}\n", .{s[r]});
    return r;
}

fn fulcrumPartitionPivot(
    comptime T: type,
    comptime @"type": enum { default, reverse },
    a: []T,
    s: []T,
    pivot: T,
    context: anytype,
    comptime cmp: fn (context: @TypeOf(context), l: T, r: T) bool,
) usize {
    const prefix = switch (@"type") {
        .default => "fulcrum_default_partition: ",
        .reverse => "fulcrum_reverse_partition: ",
    };
    o(prefix ++ "ss={}, n={}, pivot={}\n", .{ s.len, a.len, pivot });

    @memcpy(s[0..32], a[0..32]);
    @memcpy(s[32..][0..32], a[a.len - 32 ..][0..32]);

    const a_ptl: usize = 0; // always start of array
    var a_ptr = a.len - 1;
    var a_pta: usize = 32;
    var a_tpa = a.len - 33;

    var count = a.len / 16 - 4;
    var m: usize = 0;

    while (true) {
        if (a_pta - a_ptl - m <= 48) {
            if (count == 0) break;
            count -= 1;

            for (0..16) |_| {
                const v = @intFromBool(switch (@"type") {
                    .default => cmp(context, a[a_pta], pivot),
                    .reverse => !cmp(context, a[a_pta], pivot),
                });
                a[a_ptl + m] = a[a_pta];
                a[a_ptr + m] = a[a_pta];
                a_pta += 1;
                m += v;
                a_ptr -= 1;
            }
        }
        if (a_pta - a_ptl - m >= 16) {
            if (count == 0) break;
            count -= 1;

            for (0..16) |_| {
                const v = @intFromBool(switch (@"type") {
                    .default => cmp(context, a[a_tpa], pivot),
                    .reverse => !cmp(context, a[a_tpa], pivot),
                });
                a[a_ptl + m] = a[a_tpa];
                a[a_ptr + m] = a[a_tpa];
                a_tpa -= 1;
                m += v;
                a_ptr -= 1;
            }
        }
    }

    if (a_pta - a_ptl - m <= 48) {
        for (0..a.len % 16) |_| {
            const v = @intFromBool(switch (@"type") {
                .default => cmp(context, a[a_pta], pivot),
                .reverse => !cmp(context, a[a_pta], pivot),
            });
            a[a_ptl + m] = a[a_pta];
            a[a_ptr + m] = a[a_pta];
            a_pta += 1;
            m += v;
            a_ptr -= 1;
        }
    } else {
        for (0..a.len % 16) |_| {
            const v = @intFromBool(switch (@"type") {
                .default => cmp(context, a[a_tpa], pivot),
                .reverse => !cmp(context, a[a_tpa], pivot),
            });
            a[a_ptl + m] = a[a_tpa];
            a[a_ptr + m] = a[a_tpa];
            a_tpa -= 1;
            m += v;
            a_ptr -= 1;
        }
    }

    var s_pta: usize = 0;
    for (0..16) |_| {
        inline for (0..4) |_| {
            const v = @intFromBool(switch (@"type") {
                .default => cmp(context, s[s_pta], pivot),
                .reverse => !cmp(context, s[s_pta], pivot),
            });
            a[a_ptl + m] = s[s_pta];
            a[a_ptr + m] = s[s_pta];
            s_pta += 1;
            m += v;
            a_ptr -%= 1; // TODO: last iteration will underflow
        }
    }

    o(prefix ++ "m={}\n", .{m});
    return m;
}

fn fulcrumPartition(
    comptime T: type,
    a: []T,
    s: []T,
    max_: ?T,
    context: anytype,
    comptime cmp: fn (context: @TypeOf(context), l: T, r: T) bool,
) void {
    o("fulcrum_partition: ss={}, n={}\n", .{ s.len, a.len });
    var max = max_;

    var a_len = a.len;
    var a_size: usize = 0;
    var s_size: usize = undefined;
    var generic = false;
    var pivot: T = undefined;
    var ptp: usize = 0;

    while (true) {
        o("fulcrum_partition: nmemb={}\n", .{a_len});

        if (a_len <= 2048) {
            ptp = crumMedianOfNine(T, a[0..a_len], context, cmp);
        } else {
            ptp = crumMedianOfCbrt(T, a[0..a_len], s, &generic, context, cmp);
            if (generic) break;
        }
        pivot = a[ptp];

        if (max != null and cmp(context, max.?, pivot)) {
            a_size = fulcrumPartitionPivot(T, .reverse, a[0..a_len], s, pivot, context, cmp);
            s_size = a_len - a_size;
            a_len = a_size;

            if (s_size <= a_size / 32 or a_size <= crum_out) break;

            max = null;
            continue;
        }

        a_len -= 1;
        a[ptp] = a[a_len];

        a_size = fulcrumPartitionPivot(T, .default, a[0..a_len], s, pivot, context, cmp);
        s_size = a_len - a_size;

        ptp = a_size;
        a[a_len] = a[ptp];
        a[ptp] = pivot;

        if (a_size <= s_size / 32 or s_size <= crum_out) {
            quadsort.sortWithSwap(T, a[ptp + 1 ..][0..s_size], s, context, cmp);
        } else {
            o("fulcrum_partition: branch1\n", .{});
            _ = fulcrumPartition(T, a[ptp + 1 ..][0..s_size], s, max, context, cmp);
        }
        a_len = a_size;

        if (s_size <= a_size / 32 or a_size <= crum_out) {
            if (a_size <= crum_out) break;

            a_size = fulcrumPartitionPivot(T, .reverse, a[0..a_len], s[0..s_size], pivot, context, cmp);
            s_size = a_len - a_size;
            a_len = a_size;

            if (s_size <= a_size / 32 or a_size <= crum_out) break;

            max = null;
            continue;
        }
        max = a[ptp];
    }

    quadsort.sortWithSwap(T, a[0..a_len], s, context, cmp);
}
