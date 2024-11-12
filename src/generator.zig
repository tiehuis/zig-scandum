// from https://github.com/alichraghi/zort
const std = @import("std");

/// Generate `limit` number or random items
pub fn random(comptime T: type, seed: usize, allocator: std.mem.Allocator, limit: usize) std.mem.Allocator.Error![]T {
    var rnd = std.Random.DefaultPrng.init(seed);

    var array = try std.ArrayList(T).initCapacity(allocator, limit);

    switch (@typeInfo(T)) {
        .Int => {
            var i: usize = 0;
            while (i < limit) : (i += 1) {
                const item: T = rnd.random()
                    .intRangeAtMostBiased(T, std.math.minInt(T), @as(T, @intCast(limit)));
                array.appendAssumeCapacity(item);
            }
        },
        else => unreachable,
    }

    return array.toOwnedSlice();
}

pub fn sorted(comptime T: type, seed: usize, allocator: std.mem.Allocator, limit: usize) std.mem.Allocator.Error![]T {
    const ret = try random(T, seed, allocator, limit);

    std.mem.sort(T, ret, {}, comptime std.sort.asc(T));

    return ret;
}

pub fn reverse(comptime T: type, seed: usize, allocator: std.mem.Allocator, limit: usize) std.mem.Allocator.Error![]T {
    const ret = try random(T, seed, allocator, limit);

    std.mem.sort(T, ret, {}, comptime std.sort.desc(T));

    return ret;
}

pub fn ascSaw(comptime T: type, seed: usize, allocator: std.mem.Allocator, limit: usize) std.mem.Allocator.Error![]T {
    const TEETH = 10;
    var ret = try random(T, seed, allocator, limit);

    var offset: usize = 0;
    while (offset < TEETH) : (offset += 1) {
        const start = ret.len / TEETH * offset;
        std.mem.sort(T, ret[start .. start + ret.len / TEETH], {}, comptime std.sort.asc(T));
    }

    return ret;
}

pub fn descSaw(comptime T: type, seed: usize, allocator: std.mem.Allocator, limit: usize) std.mem.Allocator.Error![]T {
    const TEETH = 10;
    var ret = try random(T, seed, allocator, limit);

    var offset: usize = 0;
    while (offset < TEETH) : (offset += 1) {
        const start = ret.len / TEETH * offset;
        std.mem.sort(T, ret[start .. start + ret.len / TEETH], {}, comptime std.sort.desc(T));
    }

    return ret;
}

// Non-allocating; fill existing array

pub fn fillRandom(comptime T: type, seed: usize, a: []T) void {
    var rnd = std.Random.DefaultPrng.init(seed);
    const limit = a.len;

    switch (@typeInfo(T)) {
        .Int => {
            var i: usize = 0;
            while (i < limit) : (i += 1) {
                const item: T = rnd.random()
                    .intRangeAtMostBiased(T, std.math.minInt(T), @as(T, @intCast(limit)));
                a[i] = item;
            }
        },
        else => unreachable,
    }
}

pub fn fillSorted(comptime T: type, seed: usize, a: []T) void {
    fillRandom(T, seed, a);
    std.mem.sort(T, a, {}, comptime std.sort.asc(T));
}

pub fn fillReverse(comptime T: type, seed: usize, a: []T) void {
    fillRandom(T, seed, a);
    std.mem.sort(T, a, {}, comptime std.sort.desc(T));
}

pub fn fillAscSaw(comptime T: type, seed: usize, a: []T) void {
    fillRandom(T, seed, a);

    const TEETH = 10;
    var offset: usize = 0;
    while (offset < TEETH) : (offset += 1) {
        const start = a.len / TEETH * offset;
        std.mem.sort(T, a[start .. start + a.len / TEETH], {}, comptime std.sort.asc(T));
    }
}

pub fn fillDescSaw(comptime T: type, seed: usize, a: []T) void {
    fillRandom(T, seed, a);

    const TEETH = 10;
    var offset: usize = 0;
    while (offset < TEETH) : (offset += 1) {
        const start = a.len / TEETH * offset;
        std.mem.sort(T, a[start .. start + a.len / TEETH], {}, comptime std.sort.desc(T));
    }
}
