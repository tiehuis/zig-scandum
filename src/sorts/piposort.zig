// piposort 1.1.5.4
//
// This document describes a stable top-down adaptive branchless merge sort named piposort.
// It is intended as a simplified quadsort with reduced adaptivity, but a great reduction in
// lines of code and overall complexity. The name stands for ping-pong.

const std = @import("std");
const config = @import("config");

fn o(comptime fmt: []const u8, args: anytype) void {
    if (config.trace) std.debug.print("|pipo| " ++ fmt, args);
}

pub fn sort(
    comptime T: type,
    allocator: std.mem.Allocator,
    a: []T,
    context: anytype,
    comptime cmp: fn (context: @TypeOf(context), l: T, r: T) bool,
) !void {
    o("piposort: n={}\n", .{a.len});
    const s = try allocator.alloc(T, a.len);
    defer allocator.free(s);
    pingPongMerge(T, a, s, context, cmp);
}

fn pingPongMerge(
    comptime T: type,
    a: []T,
    s: []T,
    context: anytype,
    comptime cmp: fn (context: @TypeOf(context), l: T, r: T) bool,
) void {
    o("ping_pong_merge: n={}\n", .{a.len});

    if (a.len <= 7) {
        o("ping_pong_merge: n < 7\n", .{});
        branchlessOddEvenSort(T, a, context, cmp);
        return;
    }

    const half1 = a.len / 2;
    const quad1 = half1 / 2;
    const quad2 = half1 - quad1;
    const half2 = a.len - half1;
    const quad3 = half2 / 2;
    const quad4 = half2 - quad3;

    pingPongMerge(T, a[0..quad1], s, context, cmp);
    pingPongMerge(T, a[quad1..][0..quad2], s, context, cmp);
    pingPongMerge(T, a[half1..][0..quad3], s, context, cmp);
    pingPongMerge(T, a[half1 + quad3 ..][0..quad4], s, context, cmp);

    if (cmp(context, a[quad1 - 1], a[quad1]) and
        cmp(context, a[half1 - 1], a[half1]) and
        cmp(context, a[half1 + quad3 - 1], a[half1 + quad3]))
    {
        o("ping_pong_merge: branch 1\n", .{});
        return;
    }

    if (!cmp(context, a[0], a[half1 - 1]) and
        !cmp(context, a[quad1], a[half1 + quad3 - 1]) and
        !cmp(context, a[half1], a[a.len - 1]))
    {
        o("ping_pong_merge: branch 2\n", .{});
        auxiliaryRotation(T, a, s, quad1, quad2 + half2);
        auxiliaryRotation(T, a, s, quad2, half2);
        auxiliaryRotation(T, a, s, quad3, quad4);
        return;
    }

    oddevenParityMerge(T, a, s, quad1, quad2, context, cmp);
    oddevenParityMerge(T, a[half1..], s[half1..], quad3, quad4, context, cmp);
    oddevenParityMerge(T, s, a, half1, half2, context, cmp);
}

fn auxiliaryRotation(comptime T: type, a: []T, s: []T, l: usize, r: usize) void {
    o("auxiliary_rotation: l={}, r={}\n", .{ l, r });
    @memcpy(s[0..l], a[0..l]);
    std.mem.copyForwards(T, a[0..r], a[l..][0..r]);
    @memcpy(a[r..][0..l], s[0..l]);
}

fn oddevenParityMerge(
    comptime T: type,
    src: []T,
    dst: []T,
    l_: usize,
    r: usize,
    context: anytype,
    comptime cmp: fn (context: @TypeOf(context), l: T, r: T) bool,
) void {
    var l = l_;
    o("oddeven_parity_merge: l={}, r={}\n", .{ l, r });

    var s_ptl: usize = 0;
    var s_ptr: usize = l;
    var d_ptd: usize = 0;
    var s_tpl: usize = l - 1;
    var s_tpr: usize = l + r - 1;
    var d_tpd: usize = l + r - 1;

    if (l < r) {
        o("oddeven_parity_merge: l<r l={}, r={}\n", .{ src[s_ptl], src[s_ptr] });
        if (cmp(context, src[s_ptl], src[s_ptr])) {
            dst[d_ptd] = src[s_ptl];
            s_ptl += 1;
        } else {
            dst[d_ptd] = src[s_ptr];
            s_ptr += 1;
        }
        d_ptd += 1;
        o("oddeven_parity_merge: l<r end d={}, l={}, r={}\n", .{ d_ptd, s_ptl, s_ptr });
    }

    o("array: {any}\n", .{src[s_ptl .. s_ptr + 1]});
    while (true) {
        l -= 1;
        if (l == 0) break;

        o("oddeven_parity_merge:cmp1 l={}, r={}\n", .{ src[s_ptl], src[s_ptr] });
        const x = @intFromBool(cmp(context, src[s_ptl], src[s_ptr]));
        o("oddeven_parity_merge: x={}, l={}, r={}\n", .{ x, s_ptl, s_ptr });
        dst[d_ptd] = src[s_ptl];
        s_ptl += x;
        dst[d_ptd + x] = src[s_ptr];
        s_ptr += x ^ 1;
        d_ptd += 1;

        o("oddeven_parity_merge:cmp2 l={}, r={}\n", .{ src[s_tpl], src[s_tpr] });
        const y = @intFromBool(cmp(context, src[s_tpl], src[s_tpr]));
        o("oddeven_parity_merge: y={}, l={}, r={}\n", .{ y, s_tpl, s_tpr });
        dst[d_tpd] = src[s_tpl];
        s_tpl -= y ^ 1;
        d_tpd -= 1;
        dst[d_tpd + y] = src[s_tpr];
        s_tpr -= y;
    }

    dst[d_tpd] = if (!cmp(context, src[s_tpl], src[s_tpr])) src[s_tpl] else src[s_tpr];
    dst[d_ptd] = if (cmp(context, src[s_ptl], src[s_ptr])) src[s_ptl] else src[s_ptr];
}

inline fn branchlessSwap(
    comptime T: type,
    a: []T,
    context: anytype,
    comptime cmp: fn (context: @TypeOf(context), lhs: T, rhs: T) bool,
) u1 {
    std.debug.assert(a.len >= 2);
    const x = @intFromBool(!cmp(context, a[0], a[1]));
    const y = x ^ 1;
    const s = a[y];
    a[0] = a[x];
    a[1] = s;
    return x;
}

fn branchlessOddEvenSort(
    comptime T: type,
    a: []T,
    context: anytype,
    comptime cmp: fn (context: @TypeOf(context), lhs: T, rhs: T) bool,
) void {
    o("branchless_oddeven_sort: n={}\n", .{a.len});
    switch (a.len) {
        4...7 => {
            const e = a.len - 3;
            var w: u1 = 1;
            var z: u1 = 1;
            for (0..a.len) |_| {
                var b = e + z;
                z ^= 1;

                while (true) {
                    w |= branchlessSwap(T, a[b..], context, cmp);
                    if (b < 2) break;
                    b -= 2;
                }
                if (w == 0) break;
                w -= 1;
            }
        },
        3 => {
            _ = branchlessSwap(T, a[0..], context, cmp);
            if (branchlessSwap(T, a[1..], context, cmp) != 0) {
                _ = branchlessSwap(T, a[0..], context, cmp);
            }
        },
        2 => {
            _ = branchlessSwap(T, a[0..], context, cmp);
        },
        0, 1 => {},

        else => unreachable,
    }
}
