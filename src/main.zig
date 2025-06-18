const std = @import("std");
const builtin = @import("builtin");

const ActionType = enum {
    not_found,
    builtin,
    executable,
};

const Action = union(ActionType) {
    not_found: []const u8,
    builtin: BuiltInCommand,
    executable: Executable,
};


const BuiltInCommandType = enum{
    exit,
    echo,
    type,
};

const BuiltInCommand = union(BuiltInCommandType) {
    exit: ?u8,
    echo: []const u8,
    type: []const u8,
};

const Executable = struct {
    cmd: []const u8,
    path: []const u8,
    args: [][]const u8,
};

const ENV_SEP = if(builtin.target.os.tag == .windows) ';' else ':';
const PATH_NAME = if(builtin.target.os.tag == .windows) "Path" else "PATH";

pub fn main() !void {
    var debug_allocator = std.heap.DebugAllocator(.{}).init;
    defer {
        const check = debug_allocator.deinit();
        switch (check) {
            .leak => std.debug.print("Memory leak detected", .{}),
            .ok => {},
        }
    }
    const gpa = debug_allocator.allocator();

    const stdout = std.io.getStdOut().writer();
    const stderr = std.io.getStdErr().writer();
    const stdin = std.io.getStdIn().reader();
    var stdin_buffer: [1024]u8 = undefined;

    var env = try std.process.getEnvMap(gpa);
    defer env.deinit();


    while (true) {
        // I use another allocator so when the iteration end i don't have to manage
        // the deallocation manually. Everything got deallocated when a cicle end.
        var arena_allocator = std.heap.ArenaAllocator.init(gpa);
        defer arena_allocator.deinit();
        const arena = arena_allocator.allocator();

        try stdout.print("\x1b[36m$\x1b[0m ", .{});

        const user_input = try stdin.readUntilDelimiter(&stdin_buffer, '\n');
        if (user_input.len == 0) continue;
        const action  = try parseArgs(arena, &env, user_input);


        switch (action) {
            .not_found => |cmd| try stdout.print("{s}: not found\n", .{cmd}),
            .builtin => |builtin_cmd| switch (builtin_cmd) {
                .echo => |what| try stdout.print("{s}\n", .{what}),
                .exit => |status| try std.process.exit(status orelse 0),
                .type => |what| try handleType(arena,stdout,stderr,&env,what),
            },
            .executable => |exe| try runExe(arena ,exe, &env),


        }
    }
}


fn parseArgs(allocator: std.mem.Allocator,env_map: *std.process.EnvMap, args: []const u8) !Action {

    var command_parts = try customParse(allocator, args);
    if (command_parts.len == 0) return .{ .not_found = "" };
    
    const command = command_parts[0];
    var cmd_args = std.ArrayList([]const u8).init(allocator);
    defer cmd_args.deinit();
    for (command_parts[1..]) |value| {
        try cmd_args.append(value);
    }
    if(std.meta.stringToEnum(BuiltInCommandType,command)) |builtin_cmd_type|{
        const bi: BuiltInCommand  = switch (builtin_cmd_type) {
            .exit => ex: {
                    const exit_code = if (cmd_args.items.len > 0) try std.fmt.parseInt(u8, cmd_args.items[0], 10) else null;
                    break :ex .{ .exit = exit_code};
            },
            .echo => .{ .echo = try std.mem.join(allocator, " ", cmd_args.items) },
            .type => .{ .type = if(cmd_args.items.len > 0) cmd_args.items[0] else ""},
        };

        return .{ .builtin = bi };
    }
    if(findInPath(allocator, env_map, command)) |path_to_cmd| {
        return .{
            .executable = .{
                .cmd = command,
                .path = path_to_cmd,
                .args = try cmd_args.toOwnedSlice(),
            }
        };
    }
    return .{ .not_found = command};

}

fn findInPath(allocator: std.mem.Allocator, env_map: *std.process.EnvMap, cmd: []const u8) ?[]const u8 {
    const path = env_map.get(PATH_NAME) orelse return null;
    var path_parts = std.mem.splitScalar(u8, path, ENV_SEP);
    while(path_parts.next()) |folder| {
        var dir=  std.fs.openDirAbsolute(folder, .{.iterate = true}) catch continue;
        defer dir.close();
        var dir_iterator = dir.iterate();

        while(true) {
            const entry_file = dir_iterator.next() catch continue orelse break;
            if(entry_file.kind == .directory) continue;
            if(std.mem.eql(u8, entry_file.name , cmd)){
                const segment = [_][]const u8{ folder, entry_file.name};
                const file_path = std.fs.path.join(allocator, &segment) catch return null;
                return file_path;
            }
        }
    }
    return null;
}

fn handleType(allocator: std.mem.Allocator,stdout: anytype,stderr: anytype,env_map: *std.process.EnvMap, args: []const u8) !void {
    const action = try parseArgs(allocator, env_map, args);
    switch(action) {
        .not_found => |cmd| try stderr.print("{s}: not found\n",.{cmd}),
        .builtin => |bi| try stdout.print("{s} is a shell builtin\n",.{@tagName(bi)}),
        .executable => |ex| try stdout.print("{s} is {s}\n", .{ex.cmd, ex.path}),
    }
}

fn runExe(allocator: std.mem.Allocator, exe: Executable, env_map: *std.process.EnvMap) !void {

    var argument_list = std.ArrayList([]const u8).init(allocator);
    defer argument_list.deinit();

    try argument_list.append(exe.cmd);
    var i: usize = 0;
    while (i < exe.args.len) : (i+=1) {
        try argument_list.append(exe.args[i]);

    }
    

    var child = std.process.Child.init(argument_list.items,allocator);

    child.stdout = std.io.getStdOut();
    child.stdin = std.io.getStdIn();
    child.stderr = std.io.getStdErr();
    child.env_map = env_map;

    _ = try child.spawnAndWait();
}

fn customParse(allocator: std.mem.Allocator, input: []const u8) ![][]const u8 {

  
    var args = std.ArrayList([]const u8).init(allocator);
    defer args.deinit();
    var i: usize = 0;


    while (i < input.len) : (i += 1) {

        while (i < input.len and std.ascii.isWhitespace(input[i])) {i += 1;}

        if(i >= input.len) break;

        var in_quotes = false;
        var in_double_quotes = false;
        var arg_content = std.ArrayList(u8).init(allocator);
        defer arg_content.deinit();
        var already_added = false;

        while (i < input.len) : (i += 1){
            already_added = false;
            const char = input[i];

            if(char == '\"' and !in_double_quotes and !in_quotes){
                in_double_quotes = true;
                continue;
            }else if(char == '\"' and in_double_quotes){
                in_double_quotes = false;
                continue;
            } else if(char == '\"' and in_quotes and !in_double_quotes){
                try arg_content.append(char);
            } else if( char == '\'' and !in_quotes and !in_double_quotes){

                in_quotes = true;
            continue;
            } else if(char == '\'' and in_quotes and !in_double_quotes){
                in_quotes = false;
                continue;
            } else if (std.ascii.isWhitespace(input[i]) and !in_double_quotes and !in_quotes){
                break;
            } else {
                try arg_content.append( char);
                already_added = true;
            }

            
        }
        if(arg_content.items.len > 0){
            const arg = try allocator.dupe(u8, arg_content.items);
            try args.append( arg);
        }
    }

    // try std.io.getStdOut().writer().print("{s}", .{args.items});
    return try args.toOwnedSlice();
}
