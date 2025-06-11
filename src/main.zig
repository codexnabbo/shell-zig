const std = @import("std");

pub fn main() !void {

    const stdout = std.io.getStdOut().writer();

    const stdin = std.io.getStdIn().reader();
    var buffer: [1024]u8 = undefined;

    while (true) {
        try stdout.print("$ ", .{});
        const user_input = try stdin.readUntilDelimiter(&buffer, '\n');
        var pieces = std.mem.splitScalar(u8,user_input,' ');
        const cmd = pieces.first();

        if (std.mem.eql(u8, cmd,"exit")) {
            break;
        } else if (std.mem.eql(u8, cmd,"echo")) {
            try stdout.print("{s}\n", .{pieces.rest()});
        } else {
            try stdout.print("{s}: command not found\n", .{user_input});
        }
    }
}
