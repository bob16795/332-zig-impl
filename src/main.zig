const std = @import("std");
const builtin = @import("builtin");

const Map = @import("hash.zig").Map;
// const Map = @import("tape.zig").Map;

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

    var map = try Map.init(allocator, words.items, output.items);
    defer map.deinit();

    for (words.items, output.items) |input_word, output_index| {
        const output_word = try map.get(input_word);

        if (!std.mem.eql(u8, output_word, words.items[output_index]))
            return error.WordMismatch;
    }
}
