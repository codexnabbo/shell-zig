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
            const arg = try std.fmt.parseUnsigned(u8, pieces.rest(), 10);
            std.process.exit(arg);
        } else if (std.mem.eql(u8, cmd,"echo")) {
            try stdout.print("{s}\n", .{pieces.rest()});
        } else if(std.mem.eql(u8, cmd, "type")) {
            
            const allocator = std.heap.page_allocator;
            const env = try std.process.getEnvMap(allocator);
            var paths = std.mem.splitScalar(u8, env.get("PATH") orelse return error.OptionalValueIsNull, ':');
            if(

                std.mem.eql(u8,pieces.rest(), "exit") or 
                std.mem.eql(u8,pieces.rest(), "echo") or 
                std.mem.eql(u8,pieces.rest(), "type")
            ){
                try stdout.print("{s} is a shell builtin\n" , .{pieces.rest()});
            } else {
                var findFiles = false;
                while(paths.next()) |path|{
                    const abs_path = try std.fmt.allocPrint(allocator, "{s}/{s}", .{path, pieces.rest()});
                    defer allocator.free(abs_path);
                    _ = std.fs.openFileAbsolute(abs_path, .{}) catch continue;
                    try stdout.print("{s} is {s}\n", .{pieces.rest(), abs_path});
                    findFiles = true;
                    break;
                }
                
                if(!findFiles) try stdout.print("{s}: not found\n",.{pieces.rest()});
            }
        } else {
            var findCommand = false;
            const allocator = std.heap.page_allocator;
            const env = try std.process.getEnvMap(allocator);
            var paths = std.mem.splitScalar(u8, env.get("PATH") orelse return error.OptionalValueIsNull, ':');
            var args = std.ArrayList([]const u8).init(allocator);
            defer args.deinit();
            pieces.reset();
            while(pieces.next()) |arg| { try args.append(arg);}
            while(paths.next()) |path| {
                const abs_path = try std.fmt.allocPrint(allocator, "{s}/{s}", .{path, cmd});
                defer allocator.free(abs_path);
                _ = std.fs.openFileAbsolute(abs_path, .{}) catch continue;
                var child = std.process.Child.init(args.items, allocator);
                child.stdout = std.io.getStdOut();
                child.stderr = std.io.getStdErr();
                child.stdin = std.io.getStdIn();

                _ = try child.spawnAndWait();
                findCommand = true;
                break;
            }


            if(!findCommand) try stdout.print("{s}: command not found\n", .{user_input});
        }
    }
}
