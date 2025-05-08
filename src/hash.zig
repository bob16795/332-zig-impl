const std = @import("std");

pub const Map = struct {
    const Self = @This();

    const BaseMap = std.StringHashMap([]const u8);

    data: BaseMap,

    pub fn init(
        allocator: std.mem.Allocator,
        input: []const []const u8,
        output: []const usize,
    ) !Self {
        var data = BaseMap.init(allocator);
        for (input, output) |input_word, output_index| {
            const output_word = input[output_index];

            try data.put(input_word, output_word);
        }

        return .{
            .data = data,
        };
    }

    pub fn deinit(self: *Self) void {
        // BUG: might leak, keys are parent managed
        self.data.deinit();
    }

    pub fn get(self: *const Self, input: []const u8) ![]const u8 {
        return self.data.get(input) orelse error.BadIndex;
    }
};
