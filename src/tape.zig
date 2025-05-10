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

            const chidx = word.len - 1;
            const ich = word[chidx];

            const ch: usize = @intCast(if (ich >= 'a' or ich <= 'z')
                ich - 'a'
            else if (ich >= 'A' or ich <= 'Z')
                ich - 'A'
            else
                return error.InvalidCharInWord);

            if (self.next[ch] == null) {
                const new_node = try self.allocator.create(Node);
                new_node.* = .{ .allocator = self.allocator };

                self.next[ch] = new_node;
            }

            return self.next[ch].?.push(word[0..chidx], output);
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
        data: ?[]const u8,
        goto: usize,
        choice: struct { offset: usize, count: usize },

        pub fn format(
            self: TapeInst,
            comptime _: []const u8,
            _: std.fmt.FormatOptions,
            writer: anytype,
        ) !void {
            try switch (self) {
                .data => std.fmt.format(writer, "data'{?s}'", .{self.data}),
                .goto => std.fmt.format(writer, "goto'+{}'", .{self.goto}),
                .choice => std.fmt.format(writer, "goto'+{}%{}'", .{ self.choice.offset, self.choice.count }),
            };
        }
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
            tape[0] = TapeInst{ .data = node.output orelse null };

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
            .{ .data = node.output },
        });
        try all_tapes.append(.{
            .tape = tmp_tape,
            .offset = 0,
        });

        var offset: usize = 1;
        for (node.next) |next_node| {
            if (next_node) |n| {
                const tape = try tape_from_node(n);

                try all_tapes.append(.{
                    .tape = tape,
                    .offset = offset,
                });

                offset += tape.len;
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
            const start = all_tapes.items.len - goto_idx + 1;
            output[goto_idx] = TapeInst{ .goto = tape.offset + start };
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

    fn divModHelper(allocator: std.mem.Allocator, input: *[]u8, number: usize) !usize {
        if (number == 0) return 0;
        if (input.len == 0) return 0;
        if (number == 27) {
            const result = input.*[input.*.len - 1] - ('a' - 1);
            input.* = try allocator.realloc(input.*, input.*.len - 1);

            return result;
        }

        const old_input = input.*;
        defer allocator.free(old_input);

        input.* = try allocator.dupe(u8, input.*);

        var carry: usize = 0;
        var i: usize = 0;
        for (old_input) |ch| {
            const d: usize = @as(usize, @intCast(if (ch >= 'a' or ch <= 'z')
                ch - ('a' - 1)
            else if (ch >= 'A' or ch <= 'Z')
                ch - ('A' - 1)
            else
                0)) + 27 * carry;
            carry = d % number;
            const new_d = (d / number);
            if (new_d != 0 or i != 0) {
                input.*[i] = @intCast(new_d + 'a' - 1);
                i += 1;
            }
        }

        input.* = try allocator.realloc(input.*, i);

        return carry;
    }

    pub fn get(self: *const Self, input: []const u8) !?[]const u8 {
        var value = try self.allocator.dupe(u8, input);
        defer self.allocator.free(value);

        // std.mem.reverse(u8, value);

        var idx: usize = 0;

        while (idx < self.tape.len) {
            switch (self.tape[idx]) {
                .choice => |c| {
                    idx = idx + c.offset + try divModHelper(self.allocator, &value, c.count);
                },
                .goto => |g| idx += g,
                .data => |d| return d,
            }
        }

        return null;
    }
};
