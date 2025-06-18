This is a starting point for Zig solutions to the
["Build Your Own Shell" Challenge](https://app.codecrafters.io/courses/shell/overview).

# Custom shell in Zig
A simple shell program written in zig

## ✨ Features

### Built-in Commands
- **`echo`** - Print text to stdout
- **`exit`** - Terminate the shell (with optional exit code)
- **`type`** - Determine command type (builtin or executable)

### Advanced Functionality
- **Smart argument parsing** with support for:
  - Single and double quotes
  - Backslash escape sequences
  - Proper whitespace handling
- **Automatic PATH resolution** for external commands
- **External program execution** with argument passing
- **Environment variable handling**
- **Optimized memory management** with arena allocator per command cycle

## 💾 Memory Management

Two-tier allocation strategy for optimal performance:

```zig
var debug_allocator = std.heap.DebugAllocator(.{}).init;
var arena_allocator = std.heap.ArenaAllocator.init(gpa);
```

- **Debug Allocator**: Detects memory leaks in development
- **Arena Allocator**: Automatic cleanup after each command execution

## 📋 Usage Examples

```bash
$ echo "Hello, World!"
Hello, World!

$ echo 'Single quotes preserve everything'
Single quotes preserve everything

$ type echo
echo is a shell builtin

$ type ls
ls is /bin/ls

$ exit 0
```
## 📝 License

This project is part of the CodeCrafters Shell challenge implementation.
