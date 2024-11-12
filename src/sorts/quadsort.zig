// quadsort 1.2.1.2

const std = @import("std");
const config = @import("config");

fn o(comptime fmt: []const u8, args: anytype) void {
    if (config.trace) std.debug.print("|quad| " ++ fmt, args);
}

pub fn sort(
    comptime T: type,
    maybe_allocator: ?std.mem.Allocator,
    a: []T,
    context: anytype,
    comptime cmp: fn (context: @TypeOf(context), l: T, r: T) bool,
) !void {
    if (a.len < 2) return;

    o("quadsort: n={}\n", .{a.len});

    if (a.len < 32) {
        var s: [32]T = undefined;
        tailSwap(T, a, &s, context, cmp);
    } else if (!quadSwap(T, a, context, cmp)) {
        if (maybe_allocator) |allocator| {
            o("sort: branch1 with allocator\n", .{});
            const s = try allocator.alloc(T, a.len);
            defer allocator.free(s);
            const block = quadMerge(T, a, s, 32, context, cmp);
            rotateMerge(T, a, s, block, context, cmp);
        } else {
            o("sort: branch2 no allocator\n", .{});
            var s: [512]T = undefined;
            tailMerge(T, a, s[0..], 32, context, cmp);
            rotateMerge(T, a, s[0..], 64, context, cmp);
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
    o("quadsort_swap: ss={}, n={}\n", .{ s.len, a.len });

    if (a.len <= 96) {
        tailSwap(T, a, s, context, cmp);
    } else if (!quadSwap(T, a, context, cmp)) {
        const block = quadMerge(T, a, s, 32, context, cmp);
        rotateMerge(T, a, s, block, context, cmp);
    }
}

inline fn branchlessMerge(
    comptime T: type,
    comptime @"type": enum { head, tail },
    d: []T,
    l: []T,
    r: []T,
    context: anytype,
    comptime cmp: fn (context: @TypeOf(context), l: T, r: T) bool,
) enum { l, r } {
    const use_left = switch (@"type") {
        .tail => !cmp(context, l[0], r[0]),
        .head => cmp(context, l[0], r[0]),
    };

    if (use_left) {
        d[0] = l[0];
        return .l;
    } else {
        d[0] = r[0];
        return .r;
    }
}

pub inline fn branchlessSwap(
    comptime T: type,
    a: []T,
    context: anytype,
    comptime cmp: fn (context: @TypeOf(context), lhs: T, rhs: T) bool,
) void {
    std.debug.assert(a.len >= 2);
    const x = @intFromBool(!cmp(context, a[0], a[1]));
    const y = x ^ 1;
    const s = a[y];
    a[0] = a[x];
    a[1] = s;
    // return x; // u1
}

// Large sorting routines

fn rotateMerge(
    comptime T: type,
    a: []T,
    s: []T,
    block_: usize,
    context: anytype,
    comptime cmp: fn (context: @TypeOf(context), l: T, r: T) bool,
) void {
    var block = block_;
    o("rotate_merge: swap_size={}, n={}, block={}\n", .{ s.len, a.len, block });

    if (a.len <= 2 * block and a.len -% block <= s.len) {
        o("rotate_merge: branch1: partial backward merge\n", .{});
        partialBackwardMerge(T, a, s, block, context, cmp);
        return;
    }

    while (block < a.len) {
        var i: usize = 0;
        while (i + block < a.len) : (i += 2 * block) {
            if (i + 2 * block >= a.len) {
                rotateMergeBlock(T, a[i..], s, block, a.len - i - block, context, cmp);
                break;
            }
            rotateMergeBlock(T, a[i..], s, block, block, context, cmp);
        }
        block *= 2;
    }
}

pub fn rotateMergeBlock(
    comptime T: type,
    a: []T,
    s: []T,
    lblock_: usize,
    r_: usize,
    context: anytype,
    comptime cmp: fn (context: @TypeOf(context), l: T, r: T) bool,
) void {
    var lblock = lblock_;
    var r = r_;
    o("rotate_merge_block: swap_size={}, lblock={}, r={}\n", .{ s.len, lblock, r });

    if (cmp(context, a[lblock - 1], a[lblock])) {
        return;
    }

    const rblock = lblock / 2;
    lblock -= rblock;
    const l = monoboundBinaryFirst(T, a[lblock + rblock ..], a[lblock], r, context, cmp);
    o("rotate_merge_block: l={}, r={}\n", .{ l, r });
    r -= l;

    // [ lblock ] [ rblock ] [ l ] [ r ]
    if (l != 0) {
        if (lblock + l <= s.len) {
            @memcpy(s[0..lblock], a[0..lblock]);
            @memcpy(s[lblock..][0..l], a[lblock + rblock ..][0..l]);
            std.mem.copyBackwards(T, a[lblock + l ..][0..rblock], a[lblock..][0..rblock]);
            crossMerge(T, a, s, lblock, l, context, cmp);
        } else {
            trinityRotation(T, a[lblock..][0 .. rblock + l], s, rblock);
            const unbalanced = (@intFromBool(2 * l < lblock) | @intFromBool(2 * lblock < l)) != 0;

            if (unbalanced and l <= s.len) {
                partialBackwardMerge(T, a[0 .. lblock + l], s, lblock, context, cmp);
            } else if (unbalanced and lblock <= s.len) {
                partialForwardMerge(T, a[0 .. lblock + l], s, lblock, context, cmp);
            } else {
                rotateMergeBlock(T, a[0 .. lblock + l], s, lblock, l, context, cmp);
            }
        }
    }

    if (r != 0) {
        const unbalanced = (@intFromBool(2 * r < rblock) | @intFromBool(2 * rblock < r)) != 0;
        if ((unbalanced and r < s.len) or r + rblock < s.len) {
            partialBackwardMerge(T, a[lblock + l ..][0 .. rblock + r], s, rblock, context, cmp);
        } else if (unbalanced and rblock < s.len) {
            partialForwardMerge(T, a[lblock + l ..][0 .. rblock + r], s, rblock, context, cmp);
        } else {
            rotateMergeBlock(T, a[lblock + l ..][0 .. rblock + r], s, rblock, r, context, cmp);
        }
    }
}

fn monoboundBinaryFirst(
    comptime T: type,
    a: []T,
    v: T,
    top_: usize,
    context: anytype,
    comptime cmp: fn (context: @TypeOf(context), l: T, r: T) bool,
) usize {
    var top = top_;
    o("monobound_binary_first: val={}, top={}\n", .{ v, top });

    var end = top;
    while (top > 1) {
        const mid = top / 2;
        if (cmp(context, v, a[end - mid])) {
            end -= mid;
        }
        top -= mid;
    }

    if (cmp(context, v, a[end - 1])) {
        end -= 1;
    }

    return end;
}

pub fn trinityRotation(
    comptime T: type,
    a: []T,
    s: []T,
    l_: usize,
) void {
    var l = l_;
    var r = a.len - l;
    o("trinity_rotation: swap_size={}, n={}, l={}, r={}\n", .{ s.len, a.len, l, r });
    const s_len_clamp = if (s.len > 65536) 65536 else s.len;

    if (l < r) {
        if (l <= s_len_clamp) {
            @memcpy(s[0..l], a[0..l]);
            std.mem.copyForwards(T, a[0..r], a[l..][0..r]);
            @memcpy(a[r..][0..l], s[0..l]);
        } else {
            var pa: usize = 0;
            var pb = l;
            var bridge = r - l;

            if (bridge <= s_len_clamp and bridge > 3) {
                var pc = r;
                var pd = r + l;
                @memcpy(s[0..bridge], a[pb..][0..bridge]);

                while (l != 0) : (l -= 1) {
                    pc -= 1;
                    pd -= 1;
                    a[pc] = a[pd];
                    pb -= 1;
                    a[pd] = a[pb];
                }

                @memcpy(a[0..bridge], s[0..bridge]);
            } else {
                var pc = pb;
                var pd = pb + r;

                bridge = l / 2;
                while (bridge != 0) : (bridge -= 1) {
                    pb -= 1;
                    const t = a[pb];
                    a[pb] = a[pa];
                    a[pa] = a[pc];
                    pa += 1;
                    pd -= 1;
                    a[pc] = a[pd];
                    pc += 1;
                    a[pd] = t;
                }

                bridge = (pd - pc) / 2;
                while (bridge != 0) : (bridge -= 1) {
                    const t = a[pc];
                    pd -= 1;
                    a[pc] = a[pd];
                    pc += 1;
                    a[pd] = a[pa];
                    a[pa] = t;
                    pa += 1;
                }

                bridge = (pd - pa) / 2;
                while (bridge != 0) : (bridge -= 1) {
                    const t = a[pa];
                    pd -= 1;
                    a[pa] = a[pd];
                    pa += 1;
                    a[pd] = t;
                }
            }
        }
    } else if (r < l) {
        if (r <= s_len_clamp) {
            @memcpy(s[0..r], a[l..][0..r]);
            std.mem.copyBackwards(T, a[r..][0..l], a[0..l]);
            @memcpy(a[0..r], s[0..r]);
        } else {
            var pa: usize = 0;
            var pb = l;
            var bridge = l - r;

            if (bridge <= s_len_clamp and bridge > 3) {
                var pc = r;
                const pd = r + l;
                @memcpy(s[0..bridge], a[pc..][0..bridge]);

                while (r != 0) : (r -= 1) {
                    a[pc] = a[pa];
                    pc += 1;
                    a[pa] = a[pb];
                    pa += 1;
                    pb += 1;
                }

                @memcpy(a[pd - bridge ..][0..bridge], s[0..bridge]);
            } else {
                var pc = l;
                var pd = l + r;

                bridge = r / 2;
                while (bridge != 0) : (bridge -= 1) {
                    pb -= 1;
                    const t = a[pb];
                    a[pb] = a[pa];
                    a[pa] = a[pc];
                    pa += 1;
                    pd -= 1;
                    a[pc] = a[pd];
                    pc += 1;
                    a[pd] = t;
                }

                bridge = (pb - pa) / 2;
                while (bridge != 0) : (bridge -= 1) {
                    pb -= 1;
                    const t = a[pb];
                    a[pb] = a[pa];
                    pd -= 1;
                    a[pa] = a[pd];
                    pa += 1;
                    a[pd] = t;
                }

                bridge = (pd - pa) / 2;
                while (bridge != 0) : (bridge -= 1) {
                    const t = a[pa];
                    pd -= 1;
                    a[pa] = a[pd];
                    pa += 1;
                    a[pd] = t;
                }
            }
        }
    } else {
        var pa: usize = 0;
        var pb = l;
        while (l != 0) : (l -= 1) {
            const t = a[pa];
            a[pa] = a[pb];
            pa += 1;
            a[pb] = t;
            pb += 1;
        }
    }
}

fn tailMerge(
    comptime T: type,
    a: []T,
    s: []T,
    block_: usize,
    context: anytype,
    comptime cmp: fn (context: @TypeOf(context), l: T, r: T) bool,
) void {
    var block = block_;
    o("tail_merge: swap_size={}, n={}, block={}\n", .{ s.len, a.len, block });

    while (block < a.len and block <= s.len) {
        var i: usize = 0;
        while (i + block < a.len) : (i += 2 * block) {
            if (i + 2 * block >= a.len) {
                partialBackwardMerge(T, a[i..][0 .. a.len - i], s, block, context, cmp);
                break;
            }
            partialBackwardMerge(T, a[i..][0 .. 2 * block], s, block, context, cmp);
        }
        block *= 2;
    }
}

fn partialBackwardMerge(
    comptime T: type,
    a: []T,
    s: []T,
    block: usize,
    context: anytype,
    comptime cmp: fn (context: @TypeOf(context), l: T, r: T) bool,
) void {
    o("partial_backward_merge: swap_size={}, n={}, block={}\n", .{ s.len, a.len, block });

    if (a.len == block) {
        o("partial_backward_merge: branch 1\n", .{});
        return;
    }

    var a_tpl = block - 1;
    var a_tpa = a.len - 1;
    if (cmp(context, a[a_tpl], a[a_tpl + 1])) {
        o("partial_backward_merge: branch 2\n", .{});
        return;
    }

    const r = a.len - block;

    if (a.len <= s.len and r >= 64) {
        o("partial_backward_merge: branch 3\n", .{});
        crossMerge(T, s, a, block, r, context, cmp);
        @memcpy(a, s[0..a.len]);
        return;
    }

    @memcpy(s[0..r], a[block..][0..r]);
    var s_tpr = r - 1;

    // Check this logic, I think it's incorrect for multi blocks
    blk: while (a_tpl > 16 and s_tpr > 16) {
        while (cmp(context, a[a_tpl], s[s_tpr - 15])) {
            for (0..16) |_| {
                a[a_tpa] = s[s_tpr];
                a_tpa -= 1;
                s_tpr -= 1;
            }
            if (s_tpr <= 16) break :blk;
        }

        while (!cmp(context, a[a_tpl - 15], s[s_tpr])) {
            for (0..16) |_| {
                a[a_tpa] = a[a_tpl];
                a_tpa -= 1;
                a_tpl -= 1;
            }
            if (a_tpl <= 16) break :blk;
        }

        for (0..8) |_| {
            if (cmp(context, a[a_tpl], s[s_tpr - 1])) {
                inline for (0..2) |_| {
                    a[a_tpa] = s[s_tpr];
                    a_tpa -= 1;
                    s_tpr -= 1;
                }
            } else if (!cmp(context, a[a_tpl - 1], s[s_tpr])) {
                inline for (0..2) |_| {
                    a[a_tpa] = a[a_tpl];
                    a_tpa -= 1;
                    a_tpl -= 1;
                }
            } else {
                const c = cmp(context, a[a_tpl], s[s_tpr]);
                const x = @intFromBool(c);
                const y = @intFromBool(!c);
                a_tpa -= 1;
                a[a_tpa + x] = s[s_tpr];
                s_tpr -= 1;
                a[a_tpa + y] = a[a_tpl];
                a_tpl -= 1;
                a_tpa -= 1;

                if (!cmp(context, a[a_tpl], s[s_tpr])) {
                    a[a_tpa] = a[a_tpl];
                    a_tpa -= 1;
                    a_tpl -= 1;
                } else {
                    a[a_tpa] = s[s_tpr];
                    a_tpa -= 1;
                    s_tpr -= 1;
                }
            }
        }
    }
    while (s_tpr > 1 and a_tpl > 1) {
        if (cmp(context, a[a_tpl], s[s_tpr - 1])) {
            inline for (0..2) |_| {
                a[a_tpa] = s[s_tpr];
                a_tpa -= 1;
                s_tpr -= 1;
            }
        } else if (!cmp(context, a[a_tpl - 1], s[s_tpr])) {
            inline for (0..2) |_| {
                a[a_tpa] = a[a_tpl];
                a_tpa -= 1;
                a_tpl -= 1;
            }
        } else {
            const c = cmp(context, a[a_tpl], s[s_tpr]);
            const x = @intFromBool(c);
            const y = @intFromBool(!c);
            a_tpa -= 1;
            a[a_tpa + x] = s[s_tpr];
            s_tpr -= 1;
            a[a_tpa + y] = a[a_tpl];
            a_tpl -= 1;
            a_tpa -= 1;

            if (!cmp(context, a[a_tpl], s[s_tpr])) {
                a[a_tpa] = a[a_tpl];
                a_tpa -= 1;
                a_tpl -= 1;
            } else {
                a[a_tpa] = s[s_tpr];
                a_tpa -= 1;
                s_tpr -= 1;
            }
        }
    }

    // The original uses c pointers and reads one past the start
    // of the array, handle this rudimentarily for now.
    const min = std.math.maxInt(usize);
    while (s_tpr != min and a_tpl != min) {
        if (!cmp(context, a[a_tpl], s[s_tpr])) {
            a[a_tpa] = a[a_tpl];
            a_tpa -%= 1;
            a_tpl -%= 1;
        } else {
            a[a_tpa] = s[s_tpr];
            a_tpa -%= 1;
            s_tpr -%= 1;
        }
    }

    while (s_tpr != min) {
        a[a_tpa] = s[s_tpr];
        a_tpa -%= 1;
        s_tpr -%= 1;
    }
}

fn partialForwardMerge(
    comptime T: type,
    a: []T,
    s: []T,
    block: usize,
    context: anytype,
    comptime cmp: fn (context: @TypeOf(context), l: T, r: T) bool,
) void {
    o("partial_forward_merge: swap_size={}, n={}, block={}\n", .{ s.len, a.len, block });

    if (a.len == block) return;

    var a_ptr = block;
    const a_tpr = a.len - 1;
    if (cmp(context, a[a_ptr - 1], a[a_ptr])) return;

    @memcpy(s[0..block], a[0..block]);
    var s_ptl: usize = 0;
    const s_tpl = block - 1;

    var i: usize = 0;
    while (s_ptl < s_tpl - 1 and a_ptr < a_tpr - 1) {
        if (!cmp(context, s[s_ptl], a[a_ptr + 1])) {
            inline for (0..2) |_| {
                a[i] = a[a_ptr];
                i += 1;
                a_ptr += 1;
            }
        } else if (cmp(context, s[s_ptl + 1], s[s_ptl])) {
            inline for (0..2) |_| {
                a[i] = s[s_ptl];
                i += 1;
                s_ptl += 1;
            }
        } else {
            const c = cmp(context, s[s_ptl], a[a_ptr]);
            const x = @intFromBool(c);
            const y = @intFromBool(!c);
            a[i + x] = a[a_ptr];
            a_ptr += 1;
            a[i + y] = s[s_ptl];
            s_ptl += 1;
            i += 2;

            if (cmp(context, s[s_ptl], a[a_ptr])) {
                a[i] = s[s_ptl];
                i += 1;
                s_ptl += 1;
            } else {
                a[i] = a[a_ptr];
                i += 1;
                a_ptr += 1;
            }
        }
    }

    while (s_ptl <= s_tpl and a_ptr <= a_tpr) {
        if (cmp(context, s[s_ptl], a[a_ptr])) {
            a[i] = s[s_ptl];
            i += 1;
            s_ptl += 1;
        } else {
            a[i] = a[a_ptr];
            i += 1;
            a_ptr += 1;
        }
    }

    while (s_ptl <= s_tpl) {
        a[i] = s[s_ptl];
        i += 1;
        s_ptl += 1;
    }
}

fn quadMerge(
    comptime T: type,
    a: []T,
    s: []T,
    block_: usize,
    context: anytype,
    comptime cmp: fn (context: @TypeOf(context), l: T, r: T) bool,
) usize {
    var block = block_;
    o("quad_merge: swap_size={}, n={}, block={}\n", .{ s.len, a.len, block });

    block *= 4;
    while (block <= a.len and block <= s.len) {
        var i: usize = 0;
        while (true) {
            quadMergeBlock(T, a[i..], s, block / 4, context, cmp);
            i += block;
            if (i + block > a.len) break;
        }

        tailMerge(T, a[i..], s, block / 4, context, cmp);
        block *= 4;
    }

    tailMerge(T, a, s, block / 4, context, cmp);
    return block / 2;
}

fn quadMergeBlock(
    comptime T: type,
    a: []T,
    s: []T,
    block: usize,
    context: anytype,
    comptime cmp: fn (context: @TypeOf(context), l: T, r: T) bool,
) void {
    o("quad_merge_block: block={}\n", .{block});

    const block_x_2 = block * 2;

    const a_pt1 = block;
    const a_pt2 = 2 * block;
    const a_pt3 = 3 * block;

    const s1: u2 = @intFromBool(cmp(context, a[a_pt1 - 1], a[a_pt1]));
    const s2: u2 = @intFromBool(cmp(context, a[a_pt3 - 1], a[a_pt3]));
    switch (s1 | s2 * 2) {
        0 => {
            o("quad_merge_block: branch 1\n", .{});
            crossMerge(T, s, a, block, block, context, cmp);
            crossMerge(T, s[block_x_2..], a[a_pt2..], block, block, context, cmp);
        },
        1 => {
            o("quad_merge_block: branch 2\n", .{});
            @memcpy(s[0..block_x_2], a[0..block_x_2]);
            crossMerge(T, s[block_x_2..], a[a_pt2..], block, block, context, cmp);
        },
        2 => {
            o("quad_merge_block: branch 3\n", .{});
            crossMerge(T, s, a, block, block, context, cmp);
            @memcpy(s[block_x_2..][0..block_x_2], a[a_pt2..][0..block_x_2]);
        },
        3 => {
            if (cmp(context, a[a_pt2 - 1], a[a_pt2])) {
                return;
            }
            o("quad_merge_block: branch 4\n", .{});
            @memcpy(s[0 .. 2 * block_x_2], a[0 .. 2 * block_x_2]);
        },
    }

    crossMerge(T, a, s, block_x_2, block_x_2, context, cmp);
}

pub fn crossMerge(
    comptime T: type,
    a: []T,
    s: []T,
    l: usize,
    r: usize,
    context: anytype,
    comptime cmp: fn (context: @TypeOf(context), l: T, r: T) bool,
) void {
    o("cross_merge: l={}, r={}\n", .{ l, r });

    var s_ptl: usize = 0;
    var s_ptr = l;
    var s_tpl = l - 1;
    var s_tpr = l + r - 1;

    if (l + 1 >= r and r + 1 >= l and l >= 32) {
        if (!cmp(context, s[s_ptl + 15], s[s_ptr]) and
            cmp(context, s[s_ptl], s[s_ptr + 15]) and
            !cmp(context, s[s_tpl], s[s_tpr - 15]) and
            cmp(context, s[s_tpl - 15], s[s_tpr]))
        {
            o("cross_merge: branch 1, parity merge\n", .{});
            parityMerge(T, a, s, l, r, context, cmp);
            return;
        }
    }

    var a_ptd: usize = 0;
    var a_tpd = l + r - 1;

    blk: while (s_tpl -% s_ptl > 8 and s_tpr -% s_ptr > 8) {
        o("cross_merge: s; s_tpl = {}, s_ptl = {}, s_tpr = {}, s_ptr = {}\n", .{ s_tpl, s_ptl, s_tpr, s_ptr });
        while (cmp(context, s[s_ptl + 7], s[s_ptr])) {
            @memcpy(a[a_ptd..][0..8], s[s_ptl..][0..8]);
            a_ptd += 8;
            s_ptl += 8;
            if (s_tpl - s_ptl <= 8) {
                //o("ptl8_ptr break: ptd={}, ptl={}\n", .{ a_ptd, s_ptl });
                break :blk;
            }
        }
        //o("cross_merge: skip1\n", .{});

        while (!cmp(context, s[s_ptl], s[s_ptr + 7])) {
            @memcpy(a[a_ptd..][0..8], s[s_ptr..][0..8]);
            a_ptd += 8;
            s_ptr += 8;
            if (s_tpr - s_ptr <= 8) {
                //o("ptl_ptr8 break: ptd={}, ptr={}\n", .{ a_ptd, s_ptr });
                break :blk;
            }
        }
        //o("cross_merge: skip2\n", .{});

        while (cmp(context, s[s_tpl], s[s_tpr - 7])) {
            a_tpd -= 7;
            s_tpr -= 7;
            @memcpy(a[a_tpd..][0..8], s[s_tpr..][0..8]);
            a_tpd -= 1;
            s_tpr -= 1;
            if (s_tpr - s_ptr <= 8) {
                //o("tpl_tpr8 break: tpd={}, tpr={}\n", .{ a_tpd, s_tpr });
                break :blk;
            }
        }
        //o("cross_merge: skip3\n", .{});

        while (!cmp(context, s[s_tpl - 7], s[s_tpr])) {
            a_tpd -= 7;
            s_tpl -= 7;
            @memcpy(a[a_tpd..][0..8], s[s_tpl..][0..8]);
            a_tpd -= 1;
            s_tpl -= 1;
            if (s_tpl - s_ptl <= 8) {
                //o("tpl8_tpr break: tpd={}, tpl={}\n", .{ a_tpd, s_tpl });
                break :blk;
            }
        }
        //o("cross_merge: skip4\n", .{});

        for (0..8) |_| {
            // zig fmt: off
            _ = switch (branchlessMerge(T, .head, a[a_ptd..], s[s_ptl..], s[s_ptr..], context, cmp)) {
                .l => { a_ptd += 1; s_ptl += 1; },
                .r => { a_ptd += 1; s_ptr += 1; },
            };
            _ = switch (branchlessMerge(T, .tail, a[a_tpd..], s[s_tpl..], s[s_tpr..], context, cmp)) {
                .l => { a_tpd -= 1; s_tpl -= 1; },
                .r => { a_tpd -= 1; s_tpr -= 1; },
            };
            // zig fmt: On
        }
        o("cross_merge: e; s_tpl = {}, s_ptl = {}, s_tpr = {}, s_ptr = {}\n", .{ s_tpl, s_ptl, s_tpr, s_ptr });
    }

    if (cmp(context, s[s_tpl], s[s_tpr])) {
        while (s_ptl <= s_tpl) {
            if (cmp(context, s[s_ptl], s[s_ptr])) {
                a[a_ptd] = s[s_ptl];
                a_ptd += 1;
                s_ptl += 1;
            } else {
                a[a_ptd] = s[s_ptr];
                a_ptd += 1;
                s_ptr += 1;
            }
        }
        while (s_ptr <= s_tpr) {
            a[a_ptd] = s[s_ptr];
            a_ptd += 1;
            s_ptr += 1;
        }
    } else {
        while (s_ptr <= s_tpr) {
            if (cmp(context, s[s_ptl], s[s_ptr])) {
                a[a_ptd] = s[s_ptl];
                a_ptd += 1;
                s_ptl += 1;
            } else {
                a[a_ptd] = s[s_ptr];
                a_ptd += 1;
                s_ptr += 1;
            }
        }
        while (s_ptl <= s_tpl) {
            a[a_ptd] = s[s_ptl];
            a_ptd += 1;
            s_ptl += 1;
        }
    }
}

fn quadSwap(
    comptime T: type,
    a: []T,
    context: anytype,
    comptime cmp: fn (context: @TypeOf(context), l: T, r: T) bool,
) bool {
    o("quad_swap: n={}\n", .{a.len});
    var sa: [32]T = undefined;
    var swap: []T = sa[0..];
    var count = a.len / 8;
    var no_tail_swap = false;

    var pa = a;
    var ia: usize = 0;
    var ps: []T = undefined;
    var is: usize = undefined;

    var state: enum {
        default,
        ordered,
        unordered,
        reversed,
    } = .default;

    // This checks blocks of 8 and identifies what state these are in to give quadsort its
    // adaptive properties. The C code is a tangled mess of goto's/switch fallthroughs so
    // the zig translation is not immediately comparable.
    loop: while (count != 0) {
        count -= 1;
        var p = pa[ia..];
        var v1: u4 = @intFromBool(!cmp(context, p[0], p[1]));
        var v2: u4 = @intFromBool(!cmp(context, p[2], p[3]));
        var v3: u4 = @intFromBool(!cmp(context, p[4], p[5]));
        var v4: u4 = @intFromBool(!cmp(context, p[6], p[7]));

        if (state == .default or state == .unordered) {
            if (state == .default) {
                switch (v1 + v2 * 2 + v3 * 4 + v4 * 8) {
                    0 => {
                        if (cmp(context, p[1], p[2]) and cmp(context, p[3], p[4]) and cmp(context, p[5], p[6])) {
                            o("quad_swap: branch 1: goto ordered\n", .{});
                            state = .ordered;
                            count += 1; // point to same block
                            continue :loop;
                        }
                        quadSwapMerge(T, p, swap, context, cmp);
                    },
                    else => |i| {
                        // mimic fallthrough
                        if (i == 15 and !cmp(context, p[1], p[2]) and !cmp(context, p[3], p[4]) and !cmp(context, p[5], p[6])) {
                            o("quad_swap: branch 2: goto reversed\n", .{});
                            ps = pa;
                            is = ia;
                            state = .reversed;
                            count += 1; // point to same block
                            continue :loop;
                        }

                        state = .unordered;
                        // fallthrough
                    },
                }
            }

            if (state == .unordered) {
                o("quad_swap: label unordered\n", .{});

                inline for (.{ v1, v2, v3, v4 }, 0..) |v, i| {
                    const pi = p[2 * i ..];
                    const iv = v ^ 1;
                    const t = pi[iv];
                    pi[0] = pi[v];
                    pi[1] = t;
                }
                quadSwapMerge(T, p, swap, context, cmp);
            }
            ia += 8;
        } else if (state == .ordered) {
            o("quad_swap: label ordered: count={}\n", .{count});
            ia += 8;
            p = pa[ia..];

            const pre_count = count;
            count -%= 1;

            if (pre_count != 0) {
                v1 = @intFromBool(!cmp(context, p[0], p[1]));
                v2 = @intFromBool(!cmp(context, p[2], p[3]));
                v3 = @intFromBool(!cmp(context, p[4], p[5]));
                v4 = @intFromBool(!cmp(context, p[6], p[7]));

                if (v1 | v2 | v3 | v4 != 0) {
                    if (v1 + v2 + v3 + v4 == 4 and !cmp(context, p[1], p[2]) and !cmp(context, p[3], p[4]) and !cmp(context, p[5], p[6])) {
                        o("quad_swap: branch 3: goto reversed\n", .{});
                        ps = pa;
                        is = ia;
                        state = .reversed;
                        count += 1;
                        continue :loop;
                    }
                    o("quad_swap: branch 3b: goto not_ordered\n", .{});
                    state = .unordered;
                    count += 1;
                    continue :loop;
                }
                if (cmp(context, p[1], p[2]) and cmp(context, p[3], p[4]) and cmp(context, p[5], p[6])) {
                    o("quad_swap: branch 4: goto ordered\n", .{});
                    state = .ordered;
                    count += 1;
                    continue :loop;
                }
                quadSwapMerge(T, p, swap, context, cmp);
                ia += 8;
            } else {
                break :loop;
            }
        } else if (state == .reversed) {
            o("quad_swap: label reversed\n", .{});
            ia += 8;
            p = pa[ia..];

            const pre_count = count;
            count -%= 1;

            if (pre_count != 0) {
                v1 = @intFromBool(cmp(context, p[0], p[1]));
                v2 = @intFromBool(cmp(context, p[2], p[3]));
                v3 = @intFromBool(cmp(context, p[4], p[5]));
                v4 = @intFromBool(cmp(context, p[6], p[7]));

                if (v1 | v2 | v3 | v4 != 0) {
                    // not reversed
                    o("quad_swap: branch 5: not reversed\n", .{});
                } else if (!cmp(context, pa[ia - 1], p[0]) and
                    !cmp(context, p[1], p[2]) and
                    !cmp(context, p[3], p[4]) and
                    !cmp(context, p[5], p[6]))
                {
                    o("quad_swap: branch 6: goto reversed\n", .{});
                    state = .reversed;
                    count += 1;
                    continue :loop;
                }
                std.debug.assert(ps.ptr == pa.ptr);
                quadReversal(T, pa, is, ia - 1);

                if (v1 + v2 + v3 + v4 == 4 and
                    cmp(context, p[1], p[2]) and
                    cmp(context, p[3], p[4]) and
                    cmp(context, p[5], p[6]))
                {
                    o("quad_swap: branch 7: goto ordered\n", .{});
                    state = .ordered;
                    count += 1;
                    continue :loop;
                }

                if (v1 + v2 + v3 + v4 == 0 and
                    !cmp(context, p[1], p[2]) and
                    !cmp(context, p[3], p[4]) and
                    !cmp(context, p[5], p[6]))
                {
                    o("quad_swap: branch 8: goto reversed\n", .{});
                    ps = pa;
                    is = ia;
                    state = .reversed;
                    count += 1;
                    continue :loop;
                }

                inline for (.{ v1, v2, v3, v4 }, 0..) |v, i| {
                    const pi = p[2 * i ..];
                    const iv = v ^ 1;
                    const t = pi[v];
                    pi[0] = pi[iv];
                    pi[1] = t;
                }

                if (!cmp(context, p[1], p[2]) or !cmp(context, p[3], p[4]) or !cmp(context, p[5], p[6])) {
                    o("quad_swap: branch 8b: quad swap merge\n", .{});
                    quadSwapMerge(T, p, swap, context, cmp);
                }

                ia += 8;
                state = .default;
                continue :loop; // cleaner
            } else {
                loop2: while (true) {
                    const alen_mod8: u3 = @truncate(a.len);
                    inline for (1..8) |ri| {
                        const i = 8 - ri;
                        if (i <= alen_mod8) {
                            if (cmp(context, pa[ia + i - 2..][0], pa[ia + i - 1..][0])) break :loop2;
                        }
                    }
                    o("quad_swap: alen_mod8 = {}\n", .{alen_mod8});
                    std.debug.assert(ps.ptr == pa.ptr);
                    quadReversal(T, pa, is, ia + alen_mod8 - 1);
                    if (ps[is..].ptr == a.ptr) return true;
                    o("quad_swap: goto reverse_end\n", .{});
                    no_tail_swap = true;
                    break :loop;
                }
                o("quad_swap: break1\n", .{});
                std.debug.assert(ps.ptr == pa.ptr);
                quadReversal(T, pa, is, ia - 1);
                break :loop;
            }
        }

        state = .default;
    }

    if (!no_tail_swap) {
        tailSwap(T, pa[ia..][0 .. a.len % 8], swap, context, cmp);
    }

    o("quad_swap: label reverse_end\n", .{});
    std.debug.assert(pa.ptr == a.ptr);

    ia = 0;
    while (ia + 32 <= a.len) : (ia += 32) {
        const p = a[ia..];
        if (cmp(context, p[7], p[8]) and cmp(context, p[15], p[16]) and cmp(context, p[23], p[24])) continue;
        parityMerge(T, swap, p, 8, 8, context, cmp);
        parityMerge(T, swap[16..], p[16..], 8, 8, context, cmp);
        parityMerge(T, p, swap, 16, 16, context, cmp);
    }

    if (a.len % 32 > 8) {
        tailMerge(T, a[ia..][0 .. a.len % 32], swap, 8, context, cmp);
    }

    return false;
}

fn quadSwapMerge(
    comptime T: type,
    a: []T,
    s: []T,
    context: anytype,
    comptime cmp: fn (context: @TypeOf(context), l: T, r: T) bool,
) void {
    o("quad_swap_merge\n", .{});
    parityMergeTwo(T, a, s, context, cmp);
    parityMergeTwo(T, a[4..], s[4..], context, cmp);
    parityMergeFour(T, s, a, context, cmp);
}

// Everything below is for len <= 32 routines.

pub fn quadReversal(
    comptime T: type,
    a: []T,
    a_offset: usize,
    z_offset: usize,
) void {
    var ai = a_offset;
    var zi = z_offset;
    var loop = (z_offset - a_offset) / 2;
    var bi = a_offset + loop;
    var yi = z_offset - loop;
    o("quad_reversal: loop={}, pta={}, ptz={}\n", .{loop, a_offset, z_offset});

    if (loop % 2 == 0) {
        o("quad_reversal: branch 1\n", .{});
        const t = a[bi];
        a[bi] = a[yi];
        bi -= 1;
        a[yi] = t;
        yi += 1;
        loop -= 1;
    }
    loop /= 2;

    while (true) {
        const t1 = a[ai];
        a[ai] = a[zi];
        ai += 1;
        a[zi] = t1;
        zi -= 1;

        const t2 = a[bi];
        a[bi] = a[yi];
        bi -= 1;
        a[yi] = t2;
        yi += 1;

        if (loop == 0) break;
        loop -= 1;
    }
}

fn tailSwap(
    comptime T: type,
    a: []T,
    s: []T,
    context: anytype,
    comptime cmp: fn (context: @TypeOf(context), l: T, r: T) bool,
) void {
    o("tail_swap: n={}\n", .{a.len});

    if (a.len < 5) {
        tinySort(T, a, context, cmp);
        return;
    } else if (a.len < 8) {
        quadSwapFour(T, a, context, cmp);
        twiceUnguardedInsert(T, a, 4, context, cmp);
        return;
    } else if (a.len < 12) {
        paritySwapEight(T, a, s, context, cmp);
        twiceUnguardedInsert(T, a, 8, context, cmp);
        return;
    } else if (16 <= a.len and a.len < 24) {
        paritySwapSixteen(T, a, s, context, cmp);
        twiceUnguardedInsert(T, a, 16, context, cmp);
        return;
    }

    const half1 = a.len / 2;
    const quad1 = half1 / 2;
    const quad2 = half1 - quad1;

    const half2 = a.len - half1;
    const quad3 = half2 / 2;
    const quad4 = half2 - quad3;

    tailSwap(T, a[0..][0..quad1], s, context, cmp);
    tailSwap(T, a[quad1..][0..quad2], s, context, cmp);
    tailSwap(T, a[quad1 + quad2 ..][0..quad3], s, context, cmp);
    tailSwap(T, a[quad1 + quad2 + quad3 ..][0..quad4], s, context, cmp);

    if (cmp(context, a[quad1 - 1], a[quad1]) and
        cmp(context, a[half1 - 1], a[half1]) and
        cmp(context, a[quad1 + quad2 + quad3 - 1], a[quad1 + quad2 + quad3]))
    {
        o("tail_swap: branch 1\n", .{});
        return;
    }

    parityMerge(T, s, a, quad1, quad2, context, cmp);
    parityMerge(T, s[half1..], a[half1..], quad3, quad4, context, cmp);
    parityMerge(T, a, s, half1, half2, context, cmp);
}

fn paritySwapEight(
    comptime T: type,
    a: []T,
    s: []T,
    context: anytype,
    comptime cmp: fn (context: @TypeOf(context), l: T, r: T) bool,
) void {
    o("parity_swap_eight\n", .{});

    branchlessSwap(T, a[0..], context, cmp);
    branchlessSwap(T, a[2..], context, cmp);
    branchlessSwap(T, a[4..], context, cmp);
    branchlessSwap(T, a[6..], context, cmp);

    if (cmp(context, a[1], a[2]) and cmp(context, a[3], a[4]) and cmp(context, a[5], a[6])) {
        o("parity_swap_eight: branch 1\n", .{});
        return;
    }

    parityMergeTwo(T, a[0..], s[0..], context, cmp);
    parityMergeTwo(T, a[4..], s[4..], context, cmp);
    parityMergeFour(T, s[0..], a[0..], context, cmp);
}

fn paritySwapSixteen(
    comptime T: type,
    a: []T,
    s: []T,
    context: anytype,
    comptime cmp: fn (context: @TypeOf(context), l: T, r: T) bool,
) void {
    o("parity_swap_sixteen\n", .{});

    quadSwapFour(T, a[0..], context, cmp);
    quadSwapFour(T, a[4..], context, cmp);
    quadSwapFour(T, a[8..], context, cmp);
    quadSwapFour(T, a[12..], context, cmp);

    if (cmp(context, a[3], a[4]) and cmp(context, a[7], a[8]) and cmp(context, a[11], a[12])) {
        o("parity_swap_sixteen: branch 1\n", .{});
        return;
    }

    parityMergeFour(T, a[0..], s[0..], context, cmp);
    parityMergeFour(T, a[8..], s[8..], context, cmp);
    parityMerge(T, a[0..], s[0..], 8, 8, context, cmp);
}

fn parityMergeTwo(
    comptime T: type,
    a: []T,
    s: []T,
    context: anytype,
    comptime cmp: fn (context: @TypeOf(context), l: T, r: T) bool,
) void {
    // zig fmt: off
    {
        var si: usize = 0;
        var li: usize = 0;
        var ri: usize = 2;

        inline for (0..2) |i| {
            _ = switch (branchlessMerge(T, .head, s[si..], a[li..], a[ri..], context, cmp)) {
                .l => if (i < 1) { si += 1; li += 1; },
                .r => if (i < 1) { si += 1; ri += 1; },
            };
        }
    }
    {
        var si: usize = 3;
        var li: usize = 1;
        var ri: usize = 3;

        inline for (0..2) |i| {
            _ = switch (branchlessMerge(T, .tail, s[si..], a[li..], a[ri..], context, cmp)) {
                .l => if (i < 1) { si -= 1; li -= 1; },
                .r => if (i < 1) { si -= 1; ri -= 1; },
            };
        }
    }
    // zig fmt: on
}

fn parityMergeFour(
    comptime T: type,
    a: []T,
    s: []T,
    context: anytype,
    comptime cmp: fn (context: @TypeOf(context), l: T, r: T) bool,
) void {
    // zig fmt: off
    {
        var si: usize = 0;
        var li: usize = 0;
        var ri: usize = 4;

        inline for (0..4) |i| {
            _ = switch (branchlessMerge(T, .head, s[si..], a[li..], a[ri..], context, cmp)) {
                .l => if (i < 3) { si += 1; li += 1; },
                .r => if (i < 3) { si += 1; ri += 1; },
            };
        }
    }
    {
        var si: usize = 7;
        var li: usize = 3;
        var ri: usize = 7;

        inline for (0..4) |i| {
            _ = switch (branchlessMerge(T, .tail, s[si..], a[li..], a[ri..], context, cmp)) {
                .l => if (i < 3) { si -= 1; li -= 1; },
                .r => if (i < 3) { si -= 1; ri -= 1; },
            };
        }
    }
    // zig fmt: on
}

fn parityMerge(
    comptime T: type,
    d: []T,
    s: []T,
    l_: usize,
    r: usize,
    context: anytype,
    comptime cmp: fn (context: @TypeOf(context), l: T, r: T) bool,
) void {
    // zig fmt: off
    var l = l_;
    o("parity_merge: l={}, r={}\n", .{ l, r });
    std.debug.assert(l == r or l == r - 1 or l == r + 1);

    var head_di: usize = 0;
    var head_li: usize = 0;
    var head_ri: usize = l;

    var tail_di: usize = l + r - 1;
    var tail_li: usize = l - 1;
    var tail_ri: usize = l + r - 1;

    if (l < r) {
        o("parity_merge: branch l < r\n", .{});
        _ = switch (branchlessMerge(T, .head, d[head_di..], s[head_li..], s[head_ri..], context, cmp)) {
            .l => { head_di += 1; head_li += 1; },
            .r => { head_di += 1; head_ri += 1; },
        };
    }

    _ = switch (branchlessMerge(T, .head, d[head_di..], s[head_li..], s[head_ri..], context, cmp)) {
        .l => { head_di += 1; head_li += 1; },
        .r => { head_di += 1; head_ri += 1; },
    };

    while (true) {
        l -= 1;
        if (l == 0) break;

        _ = switch (branchlessMerge(T, .head, d[head_di..], s[head_li..], s[head_ri..], context, cmp)) {
            .l => { head_di += 1; head_li += 1; },
            .r => { head_di += 1; head_ri += 1; },
        };
        _ = switch (branchlessMerge(T, .tail, d[tail_di..], s[tail_li..], s[tail_ri..], context, cmp)) {
            .l => { tail_di -= 1; tail_li -= 1; },
            .r => { tail_di -= 1; tail_ri -= 1; },
        };
    }

    _ = branchlessMerge(T, .tail, d[tail_di..], s[tail_li..], s[tail_ri..], context, cmp);
    // zig fmt: on
}

fn quadSwapFour(
    comptime T: type,
    a: []T,
    context: anytype,
    comptime cmp: fn (context: @TypeOf(context), l: T, r: T) bool,
) void {
    o("quad_swap_four\n", .{});
    branchlessSwap(T, a[0..], context, cmp);
    branchlessSwap(T, a[2..], context, cmp);

    if (!cmp(context, a[1], a[2])) {
        o("quad_swap_four: branch 1\n", .{});
        std.mem.swap(T, &a[1], &a[2]);
        branchlessSwap(T, a[0..], context, cmp);
        branchlessSwap(T, a[2..], context, cmp);
        branchlessSwap(T, a[1..], context, cmp);
    }
}

fn twiceUnguardedInsert(
    comptime T: type,
    a: []T,
    offset: usize,
    context: anytype,
    comptime cmp: fn (context: @TypeOf(context), l: T, r: T) bool,
) void {
    o("twice_unguarded_insert: o={}, n={}\n", .{ offset, a.len });

    for (offset..a.len) |i| {
        var e = i;
        var p = i - 1;

        if (cmp(context, a[p], a[e])) continue;

        const k = a[e];
        //o("twice_unguarded_insert: k={}\n", .{k});

        if (!cmp(context, a[1], k)) {
            //o("twice_unguarded_insert: branch 1\n", .{});
            for (0..i - 1) |_| {
                a[e] = a[p];
                e -= 1;
                p -= 1;
            }
            a[e] = k;
            e -= 1;
        } else {
            //o("twice_unguarded_insert: branch 2\n", .{});
            while (true) {
                inline for (0..2) |_| {
                    a[e] = a[p];
                    e -= 1;
                    p -= 1;
                }

                if (cmp(context, a[p], k)) break;
            }

            a[e] = a[e + 1];
            a[e + 1] = k;
        }

        const x = @intFromBool(!cmp(context, a[e], a[e + 1]));
        const y = x ^ 1;
        const key = a[e + y];
        a[e] = a[e + x];
        a[e + 1] = key;
    }
}

fn tinySort(
    comptime T: type,
    a: []T,
    context: anytype,
    comptime cmp: fn (context: @TypeOf(context), l: T, r: T) bool,
) void {
    o("tiny_sort: n={}\n", .{a.len});
    std.debug.assert(a.len <= 4);

    switch (a.len) {
        4 => {
            branchlessSwap(T, a[0..], context, cmp);
            branchlessSwap(T, a[2..], context, cmp);

            if (!cmp(context, a[1], a[2])) {
                std.mem.swap(T, &a[1], &a[2]);
                branchlessSwap(T, a[0..], context, cmp);
                branchlessSwap(T, a[2..], context, cmp);
                branchlessSwap(T, a[1..], context, cmp);
            }
        },
        3 => {
            branchlessSwap(T, a[0..], context, cmp);
            branchlessSwap(T, a[1..], context, cmp);
            branchlessSwap(T, a[0..], context, cmp);
        },
        2 => {
            branchlessSwap(T, a[0..], context, cmp);
        },
        0, 1 => {},

        else => unreachable,
    }
}
