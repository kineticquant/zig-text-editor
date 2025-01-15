const std = @import("std");
const win32 = @import("zigwin32"); // Import the entire win32 module
const foundation = win32.foundation; // Import the foundation module for basic types
const windows_and_messaging = win32.ui.windows_and_messaging; // Import the specific module for WNDCLASS
const library_loader = win32.system.library_loader; // Import the library_loader module for GetModuleHandleA
const gdi = win32.graphics.gdi; // Import the graphics.gdi module for GetStockObject and UpdateWindow
const shell = win32.ui.shell; // Import the shell module for HDROP
const edit = win32.ui.controls.rich_edit; // Import the edit module for EM_SETBKGNDCOLOR
const exit = win32.system.threading;
const messaging = win32.ui.windows_and_messaging;
const ui_controls = win32.ui.controls;

// Define UNICODE to true or false
const UNICODE = false; // Set to true for Unicode (WNDCLASSW), false for ANSI (WNDCLASSA)

var gpa = std.heap.GeneralPurposeAllocator(.{}){};
const allocator = gpa.allocator();

var window_handle: foundation.HWND = undefined;
var edit_handle: foundation.HWND = undefined;
var file_content = std.ArrayList(u8).init(allocator);

const ID_EDIT = 1;

// Manually define CHARFORMAT2A
const CHARFORMAT2A = extern struct {
    cbSize: u32,
    dwMask: u32,
    dwEffects: u32,
    yHeight: i32,
    yOffset: i32,
    crTextColor: u32,
    bCharSet: u8,
    bPitchAndFamily: u8,
    szFaceName: [32]u8,
    wWeight: u16,
    sSpacing: i16,
    crBackColor: u32,
    lcid: u32,
    dwReserved: u32,
    sStyle: i16,
    wKerning: u16,
    bUnderlineType: u8,
    bAnimation: u8,
    bRevAuthor: u8,
    bReserved1: u8,
};

pub fn main() !void {
    defer _ = gpa.deinit();
    defer file_content.deinit();

    try initWindow();
    messageLoop(window_handle); // Use custom message loop
    exit.ExitProcess(0); // Ensure this is the correct function
}

fn initWindow() !void {
    const class_name = "ZigNotepad";
    const window_name = "Zig Notepad";

    // Load the RichEdit library
    // const rich_edit_lib = library_loader.LoadLibraryA("msftedit.dll") orelse {
    //     std.debug.print("Failed to load msftedit.dll\n", .{});
    //     return error.LoadLibraryFailed;
    // };

    // _ = rich_edit_lib;

    // _ = library_loader.LoadLibraryA("Msftedit.dll") orelse return error.LoadLibraryFailed;
    _ = library_loader.LoadLibraryA("msftedit.dll") orelse return error.LoadLibraryFailed;

    var wc = windows_and_messaging.WNDCLASSA{ // Use WNDCLASSA from the specific module
        .style = .{}, // Initialize WNDCLASS_STYLES with default values
        .lpfnWndProc = wndProc,
        .cbClsExtra = 0,
        .cbWndExtra = 0,
        .hInstance = library_loader.GetModuleHandleA(null), // Use GetModuleHandleA from library_loader
        .hIcon = null,
        .hCursor = windows_and_messaging.LoadCursorA(null, @as([*:0]const u8, @ptrCast("IDC_ARROW"))), // Use ANSI string for LoadCursorA
        .hbrBackground = @as(?gdi.HBRUSH, @ptrFromInt(@intFromEnum(windows_and_messaging.COLOR_WINDOW) + 1)), // Use @intFromEnum to get the underlying integer value
        .lpszMenuName = null,
        .lpszClassName = class_name,
    };

    if (windows_and_messaging.RegisterClassA(&wc) == 0) {
        std.debug.print("Failed to register window class\n", .{});
        return error.RegisterClassFailed;
    }

    window_handle = windows_and_messaging.CreateWindowExA(
        .{}, // Initialize WINDOW_EX_STYLE with default values
        class_name,
        window_name,
        windows_and_messaging.WS_OVERLAPPEDWINDOW,
        windows_and_messaging.CW_USEDEFAULT,
        windows_and_messaging.CW_USEDEFAULT,
        800,
        600,
        null,
        null,
        wc.hInstance,
        null,
    ) orelse {
        const last_error = foundation.GetLastError();
        std.debug.print("CreateWindowExA failed with error code: {}\n", .{last_error});
        return error.CreateWindowFailed;
    };

    const style = windows_and_messaging.WINDOW_STYLE{
        .CHILD = 1, // WS_CHILD
        .VISIBLE = 1, // WS_VISIBLE
        .VSCROLL = 1, // WS_VSCROLL
        // Add other flags as needed
    };

    edit_handle = windows_and_messaging.CreateWindowExA(
        windows_and_messaging.WS_EX_CLIENTEDGE,
        // "RichEdit20A", // Use RichEdit20A instead of EDIT
        "RichEdit50W", // Use RichEdit50A instead of RichEdit20A
        //edit.RICHEDIT_CLASSA,
        "",
        style,
        0,
        0,
        800,
        600,
        window_handle,
        @as(windows_and_messaging.HMENU, @ptrFromInt(ID_EDIT)),
        wc.hInstance,
        null,
    ) orelse {
        const last_error = foundation.GetLastError();
        std.debug.print("CreateWindowExA (RichEdit) failed with error code: {}\n", .{last_error});
        return error.CreateWindowFailed;
    };

    applyDarkTheme();

    _ = windows_and_messaging.ShowWindow(window_handle, windows_and_messaging.SW_SHOWDEFAULT);
    _ = gdi.UpdateWindow(window_handle); // Use gdi.UpdateWindow
}

fn applyDarkTheme() void {
    // Set background color
    _ = windows_and_messaging.SendMessageA(edit_handle, edit.EM_SETBKGNDCOLOR, 0, @as(u32, 0x282828));

    // Set text color using EM_SETCHARFORMAT
    var cf: CHARFORMAT2A = undefined;
    cf.cbSize = @sizeOf(CHARFORMAT2A);
    cf.dwMask = @as(u32, @bitCast(edit.CFM_COLOR)); // Use @bitCast to convert packed struct to u32
    cf.crTextColor = 0xE2E2E2; // Light gray text color
    _ = windows_and_messaging.SendMessageA(edit_handle, edit.EM_SETCHARFORMAT, edit.SCF_ALL, @as(isize, @intCast(@intFromPtr(&cf))));
}

fn messageLoop(hwnd: foundation.HWND) void {
    _ = hwnd; // Mark hwnd as unused
    var msg: messaging.MSG = undefined;
    while (windows_and_messaging.GetMessageA(&msg, null, 0, 0) > 0) {
        _ = windows_and_messaging.TranslateMessage(&msg);
        _ = windows_and_messaging.DispatchMessageA(&msg);
    }
}

fn update(hwnd: foundation.HWND, msg: u32, wParam: foundation.WPARAM, lParam: foundation.LPARAM) foundation.LRESULT {
    switch (msg) {
        windows_and_messaging.WM_DESTROY => {
            windows_and_messaging.PostQuitMessage(0);
            return 0;
        },
        windows_and_messaging.WM_SIZE => {
            const width = @as(u16, @truncate(@as(usize, @bitCast(lParam)))); // Extract low word (width)
            const height = @as(u16, @truncate(@as(usize, @bitCast(lParam)) >> 16)); // Extract high word (height)
            _ = windows_and_messaging.MoveWindow(edit_handle, 0, 0, width, height, 1); // Use 1 instead of foundation.TRUE
            return 0;
        },
        windows_and_messaging.WM_DROPFILES => {
            const hDrop: ?shell.HDROP = @ptrFromInt(@as(usize, wParam)); // Correctly cast wParam to HDROP
            var buff: [1024:0]u8 = undefined; // Ensure the buffer is null-terminated
            _ = shell.DragQueryFileA(hDrop, 0, @as([*:0]u8, @ptrCast(&buff)), buff.len); // Pass the buffer correctly
            openFile(@as([*:0]const u8, @ptrCast(&buff))) catch |err| {
                std.debug.print("Failed to open file: {}\n", .{err});
            };
            shell.DragFinish(hDrop);
        },
        windows_and_messaging.WM_GETDLGCODE => {
            return windows_and_messaging.DLGC_WANTALLKEYS; // Allow ENTER key to be processed by the control
        },
        windows_and_messaging.WM_KEYDOWN => {
            if (wParam == 'A' and (lParam & windows_and_messaging.MK_CONTROL) != 0) { // Check for CTRL+A
                _ = windows_and_messaging.SendMessageA(edit_handle, ui_controls.EM_SETSEL, 0, @as(isize, @intCast(-1))); // Select all text
            }
            return 0;
        },
        else => {},
    }
    return windows_and_messaging.DefWindowProcA(hwnd, msg, wParam, lParam);
}

fn openFile(path: [*:0]const u8) !void {
    const file = try std.fs.cwd().openFile(std.mem.span(path), .{});
    defer file.close();

    file_content.clearRetainingCapacity();
    try file.reader().readAllArrayList(&file_content, std.math.maxInt(usize));
    _ = windows_and_messaging.SendMessageA(edit_handle, windows_and_messaging.WM_SETTEXT, 0, @as(isize, @intCast(@intFromPtr(@as([*:0]const u8, @ptrCast(file_content.items.ptr))))));
}

fn wndProc(hwnd: foundation.HWND, msg: u32, wParam: foundation.WPARAM, lParam: foundation.LPARAM) callconv(.C) foundation.LRESULT {
    return update(hwnd, msg, wParam, lParam);
}
