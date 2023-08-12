const std = @import("std");
const data = @embedFile("./assets/Chip8Test");
const rnd = std.rand.DefaultPrng;

pub fn main() !void {
    var lines = std.mem.tokenize(u8, data, "\n");
    const allocator = std.heap.page_allocator;

    const memory = try allocator.alloc(u8, 100);
    defer allocator.free(memory);

    var rand_impl = std.rand.DefaultPrng.init(blk: {
        var seed: u8 = undefined;
        try std.os.getrandom(std.mem.asBytes(&seed));
        break :blk seed;
    });

    while (lines.next()) |line| {
        var bytes = std.ArrayList([]u8).init(allocator);
        defer bytes.deinit();

        const hex = try std.fmt.allocPrint(allocator, "{s}", .{std.fmt.fmtSliceHexLower(line)});
        defer allocator.free(hex);

        var i: usize = 0;
        const offset: u8 = 4;
        while (i < hex.len) : (i += offset) {
            try bytes.append(hex[i..(i + offset)]);
        }

        var registers: [16]u8 = std.mem.zeroes([16]u8);

        for (bytes.items) |byte| {
            switch (byte[0]) {
                '0' => {
                    std.debug.print("~GoodBye~\n", .{});
                    break;
                },
                '1' => {},
                '3' => {},
                '6' => {
                    getRegister(&registers, byte[1]).* = hexPairToDec(byte[2..4]);
                },
                '7' => {
                    getRegister(&registers, byte[1]).* += try std.fmt.parseInt(u8, byte[2..4], 10);
                },
                '8' => {
                    switch (byte[3]) {
                        '0' => {
                            getRegister(&registers, byte[1]).* = registers[charToDigit(byte[2])];
                        },
                        '1' => {
                            getRegister(&registers, byte[1]).* |= getRegister(&registers, byte[2]).*;
                        },
                        '2' => {
                            getRegister(&registers, byte[1]).* &= getRegister(&registers, byte[2]).*;
                        },
                        '3' => {
                            getRegister(&registers, byte[1]).* ^= getRegister(&registers, byte[2]).*;
                        },
                        '4' => {
                            var add = @addWithOverflow(getRegister(&registers, byte[1]).*, getRegister(&registers, byte[2]).*);
                            getRegister(&registers, byte[1]).* = add[0];
                            getRegister(&registers, 'f').* = add[1];
                        },
                        '5' => {
                            var sub = @subWithOverflow(getRegister(&registers, byte[1]).*, getRegister(&registers, byte[2]).*);
                            getRegister(&registers, byte[1]).* = sub[0];
                            getRegister(&registers, 'f').* = if (sub[1] == 0) 1 else 0;
                        },
                        '6' => {
                            getRegister(&registers, 'f').* &= 1;
                            getRegister(&registers, byte[1]).* >>= 1;
                        },
                        '7' => {
                            var sub = @subWithOverflow(getRegister(&registers, byte[2]).*, getRegister(&registers, byte[1]).*);
                            getRegister(&registers, byte[1]).* = sub[0];
                            getRegister(&registers, 'f').* = if (sub[1] == 0) 1 else 0;
                        },
                        'e' => {
                            getRegister(&registers, 'f').* &= (getRegister(&registers, byte[1]).* >> 7) & 1;
                            getRegister(&registers, byte[1]).* <<= 1;
                        },
                        else => {},
                    }
                },
                'c' => {
                    getRegister(&registers, '4').* = rand_impl.random().intRangeAtMost(u8, 1, std.math.maxInt(u8));
                },
                else => {},
            }
        }

        for (registers, 0..) |r, k| {
            if (r != 0)
                std.debug.print("register({d}): {b:0>8}\n", .{ k, r });
        }
    }
}

fn getRegister(registers: []u8, i: u8) *u8 {
    return &registers[charToDigit(i)];
}

fn charToDigit(c: u8) u8 {
    return switch (c) {
        '0'...'9' => c - '0',
        'A'...'Z' => c - 'A' + 10,
        'a'...'z' => c - 'a' + 10,
        else => std.math.maxInt(u8),
    };
}

fn hexPairToDec(hex: []const u8) u8 {
    const left = charToDigit(hex[0]);
    const right = charToDigit(hex[1]);

    return left * 16 + right;
}

test "simple test" {
    var list = std.ArrayList(i32).init(std.testing.allocator);
    defer list.deinit(); // try commenting this out and see if zig detects the memory leak!
    try list.append(42);
    try std.testing.expectEqual(@as(i32, 42), list.pop());
}
