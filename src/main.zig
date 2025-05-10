const std = @import("std");
const builtin = @import("builtin");

const Maps = .{
    @import("hash.zig").Map,
    @import("tape.zig").Map,
    @import("data.zig").Map,
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
    }

    const file_reader = file.reader();
    while (try file_reader.readUntilDelimiterOrEofAlloc(allocator, '\n', 100)) |line| {
        try output.append(words.items.len);
        try words.append(line);
    }

    inline for (Maps) |Map| {
        var map = try Map.init(allocator, words.items, output.items);
        defer map.deinit();

        inner: for (words.items, output.items) |input_word, output_index| {
            const output_word = map.get(input_word) orelse {
                std.log.err("Map type {s} Missing Word {s}", .{ Map.name, input_word });

                break :inner;
            };

            if (!std.mem.eql(u8, output_word, words.items[output_index])) {
                std.log.err("Map type {s} get {s} found word {s} wanted {s}", .{ Map.name, input_word, output_word, words.items[output_index] });

                break :inner;
            }
        }
    }
}
