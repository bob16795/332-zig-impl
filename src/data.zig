const std = @import("std");

pub const Map = struct {
    var ranges: [256]Range = ([_]Range{.{}}) ** 256;

    const Self = @This();

    const Word = struct {
        word: []const u8,
        outputWord: []const u8,
        value: f128 = 0.5,

        low: f128 = 0,
        high: f128 = 1,

        fn lessThan(_: void, a: Word, b: Word) bool {
            return (a.value < b.value);
        }

        fn compare(a: f128, b: Word) std.math.Order {
            if (a < b.value) return .lt;
            if (a > b.value) return .gt;
            return .eq;
        }
    };

    const Range = struct {
        prob: f128 = 0,
        low: f128 = 0,
        high: f128 = 1,
    };

    words: std.ArrayList(Word),

    uniqueChars: usize = 0,
    charCount: usize = 0,

    //realized its a huge waste of time to find the number every single time
    fn findValueFor(input: []const u8) f128 {
        var wordRange = Range{};
        for (input) |ch| {
            const currentRange = wordRange.high - wordRange.low;
            const chRange = ranges[@intCast(ch)];
            wordRange.high = wordRange.low + (currentRange * chRange.high);
            wordRange.low = wordRange.low + (currentRange * chRange.low);
        }
        return (wordRange.high + wordRange.low) / 2;
    }

    pub fn init(
        allocator: std.mem.Allocator,
        input: []const []const u8,
        output: []const usize,
    ) !Self {
        var words = std.ArrayList(Word).init(allocator);

        for (input, output) |input_word, output_index| {
            const output_word = input[output_index];
            try words.append(.{
                .word = input_word,
                .outputWord = output_word,
            });
        }

        var result = Self{ .words = words };
        for (words.items) |word| {
            for (word.word) |ch| {
                ranges[@intCast(ch)].prob += 1;
                result.charCount += 1;
            }
        }

        for (&ranges) |*range| {
            if (range.prob != 0) result.uniqueChars += 1;
        }

        if (result.uniqueChars == 0) return error.EmptyDictionary;

        for (&ranges, 0..) |*range, i| {
            range.prob /= @floatFromInt(result.charCount);
            std.log.info("{c} {}", .{ @as(u8, @intCast(i)), range.prob });
        }

        var lowInterval: f128 = 0;

        for (&ranges) |*range| {
            //ignore empty values they don't have a character
            if (range.prob == 0) continue;

            //set the ranges
            range.low = lowInterval;
            range.high = lowInterval + range.prob;

            //reset the lowest available interval value
            lowInterval = lowInterval + range.prob;
        }

        for (words.items) |*word| {
            var wordRange = Range{};

            for (word.word) |ch| {
                const currentRange = wordRange.high - wordRange.low;
                const chRange = ranges[@intCast(ch)];

                //Shrink the range
                wordRange.high = wordRange.low + (currentRange * chRange.high);
                wordRange.low = wordRange.low + (currentRange * chRange.low);
            }

            word.low = wordRange.low;
            word.high = wordRange.high;

            word.value = ((word.low + word.high) / 2);
        }

        std.mem.sort(Word, result.words.items, {}, Word.lessThan);

        for (words.items) |word| {
            std.log.info("{s} || [{}, {})", .{ word.word, word.low, word.high });
        }

        return result;
    }

    pub fn deinit(self: *Self) void {
        self.words.deinit();
    }

    pub fn get(self: *const Self, input: []const u8) ![]const u8 {
        //sanity check linear search
        // for (self.words.items) |word| {
        //     if (std.mem.eql(u8, input, word.word)) {
        //         return word.outputWord;
        //     }
        // }

        //Get the interval/value for the word
        const target = findValueFor(input);
        const index = std.sort.binarySearch(
            Word,
            self.words.items,
            target,
            Word.compare,
        ) orelse return error.WordNotFound;

        return self.words.items[index].outputWord;
    }
};
