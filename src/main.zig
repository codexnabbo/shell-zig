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
        } else if(std.mem.eql(u8, cmd, "type")) {
            if(
                std.mem.eql(u8,pieces.rest(), "exit") or 
                std.mem.eql(u8,pieces.rest(), "echo") or 
                std.mem.eql(u8,pieces.rest(), "type")
            ){
                try stdout.print("{s} is a shell builtin\n" , .{pieces.rest()});
            } else {
                try stdout.print("{s}: not found\n",.{pieces.rest()});
            }
            
        } else {
            try stdout.print("{s}: command not found\n", .{user_input});
        }
    }
}
