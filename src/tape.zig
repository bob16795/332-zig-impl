const std = @import("std");

pub const Map = struct {
    pub const name = "TapeMap";

    const Self = @This();

    const Node = struct {
        next: [26]?*Node = ([_]?*Node{null}) ** 26,
        output: ?[]const u8 = null,

        allocator: std.mem.Allocator,

        pub fn push(self: *Node, word: []const u8, output: []const u8) !void {
            if (word.len == 0) {
                self.output = output;
                return;
            }

            const ch: usize = @intCast(if (word[0] >= 'a' or word[0] <= 'z')
                word[0] - 'a'
            else if (word[0] >= 'A' or word[0] <= 'Z')
                word[0] - 'A'
            else
                return error.InvalidCharInWord);

            if (self.next[ch] == null) {
                const new_node = try self.allocator.create(Node);
                new_node.* = .{ .allocator = self.allocator };

                self.next[ch] = new_node;
            }

            return self.next[ch].?.push(word[1..], output);
        }

        pub fn deinit(self: *Node) void {
            for (self.next) |entry|
                if (entry) |e|
                    e.deinit();

            self.allocator.destroy(self);
        }
    };

    const InstKind = enum { data, goto, choice };

    const TapeInst = union(InstKind) {
        data: []const u8,
        goto: usize,
        choice: struct { offset: usize, count: usize },
    };

    tape: []TapeInst,

    allocator: std.mem.Allocator,

    pub fn tape_from_node(node: *const Node) ![]TapeInst {
        var has_children = false;
        for (node.next) |n| {
            if (n) |_|
                has_children = true;
        }

        if (!has_children) {
            const tape = try node.allocator.alloc(TapeInst, 1);
            tape[0] = TapeInst{ .data = node.output orelse "" };

            return tape;
        }

        var all_tapes = std.ArrayList(struct { tape: []TapeInst, offset: usize }).init(node.allocator);
        defer {
            for (all_tapes.items) |tape|
                node.allocator.free(tape.tape);

            all_tapes.deinit();
        }

        var tape_data = std.ArrayList(TapeInst).init(node.allocator);
        defer tape_data.deinit();

        const tmp_tape = try node.allocator.dupe(TapeInst, &.{
            .{ .data = node.output orelse &.{} },
        });
        try all_tapes.append(.{
            .tape = tmp_tape,
            .offset = 0,
        });

        var offset: usize = 1;
        for (node.next) |next_node| {
            if (next_node) |n| {
                const tape = try tape_from_node(n);
                offset += tape.len;

                try all_tapes.append(.{
                    .tape = tape,
                    .offset = offset,
                });
            } else {
                try all_tapes.append(.{
                    .tape = &.{},
                    .offset = offset,
                });
            }
        }

        const output_length = 1 + all_tapes.items.len + offset;
        const output = try node.allocator.alloc(TapeInst, output_length);
        output[0] = .{ .choice = .{
            .offset = 1,
            .count = all_tapes.items.len,
        } };
        var node_idx: usize = all_tapes.items.len + 1;
        for (all_tapes.items, 1..) |tape, goto_idx| {
            const start = all_tapes.items.len + 1 - goto_idx;
            output[goto_idx] = TapeInst{ .goto = offset + start };
            @memcpy(output[node_idx .. node_idx + tape.tape.len], tape.tape);

            node_idx += tape.tape.len;
        }

        return output;
    }

    pub fn init(
        allocator: std.mem.Allocator,
        input: []const []const u8,
        output: []const usize,
    ) !Self {
        var root = try allocator.create(Node);
        defer root.deinit();

        root.* = Node{
            .allocator = allocator,
        };

        for (input, output) |input_word, output_index| {
            const output_word = input[output_index];

            try root.push(input_word, output_word);
        }

        const tape = try tape_from_node(root);

        return .{
            .allocator = allocator,

            .tape = tape,
        };
    }

    pub fn deinit(self: *Self) void {
        self.allocator.free(self.tape);
    }

    pub fn get(self: *const Self, input: []const u8) ![]const u8 {
        var value: usize = 0;

        for (input) |ich| {
            const ch: usize = @intCast(if (ich >= 'a' or ich <= 'z')
                ich - 'a' + 1
            else if (ich >= 'A' or ich <= 'Z')
                ich - 'A' + 1
            else
                return error.InvalidCharInWord);

            value *= 256;
            value += ch;
        }

        var idx: usize = 0;

        while (idx < self.tape.len) {
            switch (self.tape[idx]) {
                .choice => |c| {
                    idx = idx + c.offset + (value % c.count);
                    value /= c.count;
                },
                .goto => |g| idx += g,
                .data => |d| return d,
            }
        }

        return error.WordNotFound;
    }
};
