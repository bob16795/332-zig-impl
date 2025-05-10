const std = @import("std");
const builtin = @import("builtin");

const Maps = .{
    @import("hash.zig").Map,
    @import("data.zig").Map,
    @import("tape.zig").Map,
};

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{ .stack_trace_frames = 10 }){};
    const allocator = gpa.allocator();

    const file = try std.fs.cwd().openFile("words.txt", .{});
    defer file.close();

    var words = std.ArrayList([]const u8).init(allocator);
    var output = std.ArrayList(usize).init(allocator);
    defer {
        for (words.items) |word|
            allocator.free(word);
        words.deinit();
        output.deinit();
    }

    {
        var got_map = std.StringHashMap(u0).init(allocator);
        defer got_map.deinit();

        const file_reader = file.reader();
        while (try file_reader.readUntilDelimiterOrEofAlloc(allocator, '\n', 100)) |line| {
            if (got_map.get(line)) |_|
                continue;

            try got_map.put(line, 0);

            try output.append(words.items.len);
            try words.append(line);
        }
    }

    const rand = std.crypto.random;
    rand.shuffle(usize, output.items);

    std.debug.print("All Words\n", .{});
    std.debug.print("=" ** (8 + 1 + 8 + 1 + 8) ++ "\n", .{});
    std.debug.print("{s: <8} {s: <8} {s: <8}\n", .{ "Name", "Init", "Fetch" });
    std.debug.print("=" ** (8 + 1 + 8 + 1 + 8) ++ "\n", .{});

    // comptime for, will unwrap
    inline for (Maps) |Map| {
        const init_start = try std.time.Instant.now();

        var map = try Map.init(allocator, words.items, output.items);
        defer map.deinit();

        const init_end = try std.time.Instant.now();
        const fetch_start = try std.time.Instant.now();

        inner: for (words.items, output.items) |input_word, output_index| {
            const target_output = words.items[output_index];

            const output_word = try map.get(input_word) orelse {
                std.log.err("Map type {s} Missing Word {s}", .{ Map.name, input_word });

                break :inner;
            };

            if (!std.mem.eql(u8, output_word, target_output)) {
                std.log.err("Map type {s} get {s} found word {s} wanted {s}", .{ Map.name, input_word, output_word, target_output });

                //break :inner;
            }
        }

        const fetch_end = try std.time.Instant.now();

        const init_time: f64 = @floatFromInt(init_end.since(init_start));
        const fetch_time: f64 = @floatFromInt(fetch_end.since(fetch_start));

        std.debug.print("{s: <8} {d: <1.5}s {d: <1.5}s\n", .{
            Map.name,
            init_time / std.time.ns_per_s,
            fetch_time / std.time.ns_per_s,
        });
    }

    var speare = std.ArrayList([]const u8).init(allocator);
    defer {
        for (speare.items) |word|
            allocator.free(word);
        speare.deinit();
    }

    {
        const s_file = try std.fs.cwd().openFile("shakespeare.txt", .{});
        defer s_file.close();

        const s_file_reader = s_file.reader();
        while (try s_file_reader.readUntilDelimiterOrEofAlloc(allocator, '\n', 100)) |line| : (allocator.free(line)) {
            var iter = std.mem.splitAny(u8, line, &std.ascii.whitespace);

            while (iter.next()) |word| {
                var w = word;
                while (w.len > 0 and !std.ascii.isAlphabetic(w[0])) {
                    w = w[1..];
                }

                while (w.len > 0 and !std.ascii.isAlphabetic(w[w.len - 1])) {
                    w = w[0 .. w.len - 1];
                }

                if (w.len == 0) continue;

                const copy = try allocator.dupe(u8, w);

                try speare.append(copy);
            }
        }
    }

    std.debug.print("\n", .{});
    std.debug.print("Shakespear\n", .{});
    std.debug.print("=" ** (8 + 1 + 8 + 1 + 8) ++ "\n", .{});
    std.debug.print("{s: <8} {s: <8} {s: <8}\n", .{ "Name", "Init", "Fetch" });
    std.debug.print("=" ** (8 + 1 + 8 + 1 + 8) ++ "\n", .{});

    inline for (Maps) |Map| {
        const init_start = try std.time.Instant.now();

        var map = try Map.init(allocator, words.items, output.items);
        defer map.deinit();

        const init_end = try std.time.Instant.now();
        const fetch_start = try std.time.Instant.now();

        const output_path = Map.name ++ "speare.txt";
        const o_file = try std.fs.cwd().createFile(output_path, .{});

        var length: usize = 0;

        inner: for (speare.items) |input_word| {
            const output_word = try map.get(input_word) orelse {
                //std.log.err("Map type {s} Missing Word {s}", .{ Map.name, input_word });
                const output_word = try std.fmt.allocPrint(allocator, "`{s}`", .{input_word});
                defer allocator.free(output_word);

                if (length + output_word.len > 80) {
                    try o_file.writer().print("\n{s} ", .{output_word});
                    length = output_word.len + 1;
                } else {
                    try o_file.writer().print("{s} ", .{output_word});
                    length += output_word.len + 1;
                }

                continue :inner;
            };

            if (length + output_word.len > 80) {
                try o_file.writer().print("\n{s} ", .{output_word});
                length = output_word.len + 1;
            } else {
                try o_file.writer().print("{s} ", .{output_word});
                length += output_word.len + 1;
            }
        }

        const fetch_end = try std.time.Instant.now();

        const init_time: f64 = @floatFromInt(init_end.since(init_start));
        const fetch_time: f64 = @floatFromInt(fetch_end.since(fetch_start));

        std.debug.print("{s: <8} {d: <1.5}s {d: <1.5}s\n", .{
            Map.name,
            init_time / std.time.ns_per_s,
            fetch_time / std.time.ns_per_s,
        });
    }
}
