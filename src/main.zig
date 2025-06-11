const std = @import("std");

pub fn main() !void {

    const stdout = std.io.getStdOut().writer();

    const stdin = std.io.getStdIn().reader();
    
    while (true) {
        try stdout.print("$ ", .{});
        var buffer: [1024]u8 = undefined;
        const user_input = try stdin.readUntilDelimiter(&buffer, '\n');

        if (std.mem.eql(u8,user_input,"exit 0")) break;
        try stdout.print("{s}: command not found\n", .{user_input});
    }
}
