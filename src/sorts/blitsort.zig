// blitsort 1.2.1.2

const std = @import("std");
const config = @import("config");

const quadsort = @import("quadsort.zig");

const blit_aux = 512;
const blit_out = 96; // <= blit_aux

fn o(comptime fmt: []const u8, args: anytype) void {
    if (config.trace) std.debug.print("|blit| " ++ fmt, args);
}

pub fn sort(
    comptime T: type,
    a: []T,
    context: anytype,
    comptime cmp: fn (context: @TypeOf(context), l: T, r: T) bool,
) void {
    o("blitsort: n={}\n", .{a.len});

    if (a.len <= 132) {
        var swap: [132 * @sizeOf(T)]u8 = undefined;
        var fba = std.heap.FixedBufferAllocator.init(&swap);
        const allocator = fba.allocator();
        @import("quadsort.zig").sort(T, allocator, a, context, cmp) catch unreachable; // swap allocated <= 132
    } else {
        var s: [blit_aux]T = undefined;
        blitAnalyze(T, a, s[0..], context, cmp);
    }
}

pub fn blitAnalyze(
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

    o("blit_analyze: ss={}, n={}, half1={}, quad1={}, quad2={}, half2={}, quad3={}, quad4={}\n", .{
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

    o("blit_analyze: abal={}, bbal={}, cbal={}, dbal={}\n", .{ balance[A], balance[B], balance[C], balance[D] });
    o("blit_analyze: quad1={}, quad2={}, quad3={}, quad4={}\n", .{ quad1, quad2, quad3, quad4 });
    count = balance[A] + balance[B] + balance[C] + balance[D];
    if (count == 0) {
        if (cmp(context, a[p[A]], a[p[A] + 1]) and
            cmp(context, a[p[B]], a[p[B] + 1]) and
            cmp(context, a[p[C]], a[p[C] + 1]))
        {
            o("blit_analyze: branch1\n", .{});
            return;
        }
    }

    inline for (0..4) |x| {
        sum[x] = @intFromBool(quad[x] - balance[x] == 1);
    }

    o("blit_analyze: init sum: asum={}, bsum={}, csum={}, dsum={}\n", .{ sum[A], sum[B], sum[C], sum[D] });
    if (sum[A] | sum[B] | sum[C] | sum[D] != 0) {
        const span1: u3 = @intFromBool(sum[A] != 0 and sum[B] != 0) * @intFromBool(cmp(context, a[p[A]], a[p[A] + 1]));
        const span2: u3 = @intFromBool(sum[B] != 0 and sum[C] != 0) * @intFromBool(cmp(context, a[p[B]], a[p[B] + 1]));
        const span3: u3 = @intFromBool(sum[C] != 0 and sum[D] != 0) * @intFromBool(cmp(context, a[p[C]], a[p[C] + 1]));

        o("blit_analyze: branch2: span1={}, span2={}, span3={}\n", .{ span1, span2, span3 });
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

    o("blit_analyze: branch3: asum={}, bsum={}, csum={}, dsum={}\n", .{ sum[A], sum[B], sum[C], sum[D] });
    const sumu4: u4 = @intCast(sum[A] + sum[B] * 2 + sum[C] * 4 + sum[D] * 8);
    switch (sumu4) {
        0 => {
            blitPartition(T, a, s, context, cmp);
            return;
        },
        1 => {
            if (balance[A] != 0) quadsort.sortWithSwap(T, a[0..quad1], s, context, cmp);
            blitPartition(T, a[p[A] + 1 ..][0 .. quad2 + half2], s[0..], context, cmp);
        },
        2 => {
            blitPartition(T, a[0..quad1], s, context, cmp);
            if (balance[B] != 0) quadsort.sortWithSwap(T, a[p[A] + 1 ..][0..quad2], s, context, cmp);
            blitPartition(T, a[p[B] + 1 ..][0..half2], s, context, cmp);
        },
        3 => {
            if (balance[A] != 0) quadsort.sortWithSwap(T, a[0..quad1], s, context, cmp);
            if (balance[B] != 0) quadsort.sortWithSwap(T, a[p[A] + 1 ..][0..quad2], s, context, cmp);
            blitPartition(T, a[p[B] + 1 ..][0..half2], s, context, cmp);
        },
        4 => {
            blitPartition(T, a[0..half1], s, context, cmp);
            if (balance[C] != 0) quadsort.sortWithSwap(T, a[p[B] + 1 ..][0..quad3], s, context, cmp);
            blitPartition(T, a[p[C] + 1 ..][0..quad4], s, context, cmp);
        },
        8 => {
            blitPartition(T, a[0 .. half1 + quad3], s, context, cmp);
            if (balance[D] != 0) quadsort.sortWithSwap(T, a[p[C] + 1 ..][0..quad4], s, context, cmp);
        },
        9 => {
            if (balance[A] != 0) quadsort.sortWithSwap(T, a[0..quad1], s, context, cmp);
            blitPartition(T, a[p[A] + 1 ..][0 .. quad2 + quad3], s, context, cmp);
            if (balance[D] != 0) quadsort.sortWithSwap(T, a[p[C] + 1 ..][0..quad4], s, context, cmp);
        },
        12 => {
            blitPartition(T, a[0..half1], s, context, cmp);
            if (balance[C] != 0) quadsort.sortWithSwap(T, a[p[B] + 1 ..][0..quad3], s, context, cmp);
            if (balance[D] != 0) quadsort.sortWithSwap(T, a[p[C] + 1 ..][0..quad4], s, context, cmp);
        },
        5, 6, 7, 10, 11, 13, 14, 15 => {
            if (sum[A] != 0) {
                if (balance[A] != 0) quadsort.sortWithSwap(T, a[0..quad1], s, context, cmp);
            } else {
                blitPartition(T, a[0..quad1], s, context, cmp);
            }
            if (sum[B] != 0) {
                if (balance[B] != 0) quadsort.sortWithSwap(T, a[p[A] + 1 ..][0..quad2], s, context, cmp);
            } else {
                blitPartition(T, a[p[A] + 1 ..][0..quad2], s, context, cmp);
            }
            if (sum[C] != 0) {
                if (balance[C] != 0) quadsort.sortWithSwap(T, a[p[B] + 1 ..][0..quad3], s, context, cmp);
            } else {
                blitPartition(T, a[p[B] + 1 ..][0..quad3], s, context, cmp);
            }
            if (sum[D] != 0) {
                if (balance[D] != 0) quadsort.sortWithSwap(T, a[p[C] + 1 ..][0..quad4], s, context, cmp);
            } else {
                blitPartition(T, a[p[C] + 1 ..][0..quad4], s, context, cmp);
            }
        },
    }

    o("blit_analyze: final; pa={}, pb={}, pc={}, pd={}\n", .{ p[A], p[B], p[C], p[D] });

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

pub fn blitBinaryMedian(
    comptime T: type,
    a: []T,
    b: []T,
    len_: usize,
    context: anytype,
    comptime cmp: fn (context: @TypeOf(context), l: T, r: T) bool,
) T {
    var len = len_;
    o("blit_binary_median: l={}\n", .{len});

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
    o("blit_binary_median: result={}\n", .{r});
    return r;
}

pub fn blitTrimFour(
    comptime T: type,
    a: []T,
    context: anytype,
    comptime cmp: fn (context: @TypeOf(context), l: T, r: T) bool,
) void {
    o("blit_trim_four\n", .{});
    std.debug.assert(a.len >= 4);

    quadsort.branchlessSwap(T, a[0..], context, cmp);
    quadsort.branchlessSwap(T, a[2..], context, cmp);

    const x: u2 = @intFromBool(cmp(context, a[0], a[2]));
    a[2] = a[2 * x];
    const y: u2 = @intFromBool(!cmp(context, a[1], a[3]));
    a[1] = a[1 + 2 * y];
}

pub fn blitMedianOfNine(
    comptime T: type,
    a: []T,
    context: anytype,
    comptime cmp: fn (context: @TypeOf(context), l: T, r: T) bool,
) T {
    o("blit_median_of_nine: n={}\n", .{a.len});
    var s: [9]T = undefined;

    const div = a.len / 9;
    var ai: usize = 0;
    for (0..9) |i| {
        s[i] = a[ai];
        ai += div;
    }

    blitTrimFour(T, s[0..], context, cmp);
    blitTrimFour(T, s[4..], context, cmp);
    s[0] = s[5];
    s[3] = s[8];
    blitTrimFour(T, s[0..], context, cmp);
    s[0] = s[6];

    const x: u2 = @intFromBool(!cmp(context, s[0], s[1]));
    const y: u2 = @intFromBool(!cmp(context, s[0], s[2]));
    const z: u2 = @intFromBool(!cmp(context, s[1], s[2]));
    const r = s[@intFromBool(x == y) + (y ^ z)];
    o("blit_median_of_nine: result={}\n", .{r});
    return r;
}

pub fn blitMedianOfCbrt(
    comptime T: type,
    a: []T,
    s: []T,
    generic: *bool,
    context: anytype,
    comptime cmp: fn (context: @TypeOf(context), l: T, r: T) bool,
) T {
    o("blit_median_of_cbrt: ss={}, n={}\n", .{ s.len, a.len });

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

    for (0..cbrt / 8) |_| {
        blitTrimFour(T, s[sa..], context, cmp);
        blitTrimFour(T, s[sb..], context, cmp);
        s[sa + 0] = s[sb + 1];
        s[sa + 3] = s[sb + 2];
        sa += 4;
        sb += 4;
    }
    cbrt /= 4;

    quadsort.sortWithSwap(T, s[0..cbrt], s[cbrt * 2 ..][0..cbrt], context, cmp);
    quadsort.sortWithSwap(T, s[cbrt..][0..cbrt], s[cbrt * 2 ..][0..cbrt], context, cmp);
    generic.* = cmp(context, s[cbrt * 2 - 1], s[0]);
    const r = blitBinaryMedian(T, s, s[cbrt..], cbrt, context, cmp);
    o("blit_median_of_cbrt: result={}\n", .{r});
    return r;
}

fn blitPartitionPivot(
    comptime T: type,
    comptime @"type": enum { default, reverse },
    a: []T,
    s: []T,
    pivot: T,
    context: anytype,
    comptime cmp: fn (context: @TypeOf(context), l: T, r: T) bool,
) usize {
    const prefix = switch (@"type") {
        .default => "blit_default_partition: ",
        .reverse => "blit_reverse_partition: ",
    };
    o(prefix ++ "ss={}, n={}, pivot={}\n", .{ s.len, a.len, pivot });

    if (a.len > s.len) {
        const h = a.len / 2;
        const l = blitPartitionPivot(T, @"type", a[0..h], s, pivot, context, cmp);
        const r = blitPartitionPivot(T, @"type", a[h..], s, pivot, context, cmp);
        quadsort.trinityRotation(T, a[l..][0 .. h - l + r], s, h - l);
        return l + r;
    }

    var ax: usize = 0;
    var ai: usize = 0;
    var si: usize = 0;

    for (0..a.len / 4) |_| {
        inline for (0..4) |_| {
            const pred = switch (@"type") {
                .default => cmp(context, a[ax], pivot),
                .reverse => !cmp(context, a[ax], pivot),
            };
            if (pred) {
                a[ai] = a[ax];
                ai += 1;
                ax += 1;
            } else {
                s[si] = a[ax];
                si += 1;
                ax += 1;
            }
        }
    }
    for (0..a.len % 4) |_| {
        const pred = switch (@"type") {
            .default => cmp(context, a[ax], pivot),
            .reverse => !cmp(context, a[ax], pivot),
        };
        if (pred) {
            a[ai] = a[ax];
            ai += 1;
            ax += 1;
        } else {
            s[si] = a[ax];
            si += 1;
            ax += 1;
        }
    }

    const clen = a.len - ai;
    @memcpy(a[ai..][0..clen], s[0..clen]);
    return ai;
}

fn blitPartition(
    comptime T: type,
    a: []T,
    s: []T,
    context: anytype,
    comptime cmp: fn (context: @TypeOf(context), l: T, r: T) bool,
) void {
    o("blit_partition: ss={}, n={}\n", .{ s.len, a.len });

    var a_len = a.len;
    var a_size: usize = 0;
    var s_size: usize = undefined;
    var generic = false;
    var pivot: T = undefined;
    var max: ?T = null;

    while (true) {
        o("blit_partition: nmemb={}\n", .{a_len});
        if (a_len <= 2048) {
            pivot = blitMedianOfNine(T, a[0..a_len], context, cmp);
        } else {
            pivot = blitMedianOfCbrt(T, a[0..a_len], s, &generic, context, cmp);
            if (generic) {
                quadsort.sortWithSwap(T, a[0..a_len], s, context, cmp);
                return;
            }
        }

        if (a_size != 0 and (max == null or cmp(context, max.?, pivot))) {
            a_size = blitPartitionPivot(T, .reverse, a[0..a_len], s, pivot, context, cmp);
            s_size = a_len - a_size;

            if (s_size <= a_size / 16 or a_size <= blit_out) {
                quadsort.sortWithSwap(T, a[0..a_size], s, context, cmp);
                return;
            }

            a_len = a_size;
            a_size = 0;
            continue;
        }

        a_size = blitPartitionPivot(T, .default, a[0..a_len], s, pivot, context, cmp);
        s_size = a_len - a_size;
        if (a_size <= s_size / 16 or s_size <= blit_out) {
            if (s_size == 0) {
                a_size = blitPartitionPivot(T, .reverse, a[0..a_size], s, pivot, context, cmp);
                s_size = a_len - a_size;

                if (s_size <= a_size / 16 or a_size <= blit_out) {
                    quadsort.sortWithSwap(T, a[0..a_size], s, context, cmp);
                    return;
                }

                a_len = a_size;
                a_size = 0;
                continue;
            }
            quadsort.sortWithSwap(T, a[a_size..][0..s_size], s, context, cmp);
        } else {
            blitPartition(T, a[a_size..][0..s_size], s, context, cmp);
        }

        if (s_size <= a_size / 16 or a_size <= blit_out) {
            quadsort.sortWithSwap(T, a[0..a_size], s, context, cmp);
            return;
        }

        a_len = a_size;
        max = pivot;
    }
}
