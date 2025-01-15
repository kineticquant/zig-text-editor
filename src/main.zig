const std = @import("std");
const win32 = @import("zigwin32");
const foundation = win32.foundation;
const windows_and_messaging = win32.ui.windows_and_messaging;
const library_loader = win32.system.library_loader;
const gdi = win32.graphics.gdi;
const shell = win32.ui.shell;
const edit = win32.ui.controls.rich_edit;
const exit = win32.system.threading;
const messaging = win32.ui.windows_and_messaging;
const ui_controls = win32.ui.controls;
const graphics_dwm = win32.graphics.dwm;
const interactivity = win32.ui.input.keyboard_and_mouse;

var gpa = std.heap.GeneralPurposeAllocator(.{}){};
const allocator = gpa.allocator();

var window_handle: foundation.HWND = undefined;
var edit_handle: foundation.HWND = undefined;
var file_content = std.ArrayList(u8).init(allocator);

const ID_EDIT = 1;

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
    messageLoop(window_handle);
    exit.ExitProcess(0);
}

fn initWindow() !void {
    const class_name = "ZigNotepad";
    const window_name = "Shockwave";

    // Load the RichEdit library
    _ = library_loader.LoadLibraryA("msftedit.dll") orelse return error.LoadLibraryFailed;

    var wc = windows_and_messaging.WNDCLASSA{
        .style = .{},
        .lpfnWndProc = wndProc,
        .cbClsExtra = 0,
        .cbWndExtra = 0,
        .hInstance = library_loader.GetModuleHandleA(null),
        .hIcon = null,
        .hCursor = windows_and_messaging.LoadCursorA(null, @as([*:0]const u8, @ptrCast("IDC_ARROW"))),
        .hbrBackground = gdi.CreateSolidBrush(0x1E1E1E), // Dark background
        .lpszMenuName = null,
        .lpszClassName = class_name,
    };

    if (windows_and_messaging.RegisterClassA(&wc) == 0) {
        std.debug.print("Failed to register window class\n", .{});
        return error.RegisterClassFailed;
    }

    // Combine WS_OVERLAPPEDWINDOW and WS_BORDER using bitwise OR
    const ws_overlappedwindow = @as(u32, @bitCast(windows_and_messaging.WS_OVERLAPPEDWINDOW));
    const ws_border = @as(u32, @bitCast(windows_and_messaging.WS_BORDER));
    const window_style = @as(windows_and_messaging.WINDOW_STYLE, @bitCast(ws_overlappedwindow | ws_border));

    window_handle = windows_and_messaging.CreateWindowExA(
        .{},
        class_name,
        window_name,
        window_style, // Use the combined style
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

    // Enable dark mode for the entire application
    enableDarkMode(window_handle);

    // Set the border color to black using DWM
    setBorderColor(window_handle, 0x000000); // Black color

    const style = windows_and_messaging.WINDOW_STYLE{
        .CHILD = 1, // WS_CHILD
        .VISIBLE = 1, // WS_VISIBLE
        .VSCROLL = 1, // WS_VSCROLL
    };

    edit_handle = windows_and_messaging.CreateWindowExA(
        windows_and_messaging.WS_EX_CLIENTEDGE,
        "RichEdit50W",
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

    // edit_handle = windows_and_messaging.CreateWindowExA(
    //     windows_and_messaging.WS_EX_CLIENTEDGE,
    //     "RichEdit50W",
    //     "",
    //     style,
    //     0,
    //     0,
    //     800,
    //     600,
    //     window_handle,
    //     @as(windows_and_messaging.HMENU, @ptrFromInt(ID_EDIT)),
    //     wc.hInstance,
    //     null,
    // ) orelse {
    //     const last_error = foundation.GetLastError();
    //     std.debug.print("CreateWindowExA (RichEdit) failed with error code: {}\n", .{last_error});
    //     return error.CreateWindowFailed;
    // };

    // Set focus to the RichEdit control

    _ = interactivity.SetFocus(edit_handle);

    applyDarkTheme();

    _ = windows_and_messaging.ShowWindow(window_handle, windows_and_messaging.SW_SHOWDEFAULT);
    _ = gdi.UpdateWindow(window_handle);
}

fn enableDarkMode(hwnd: foundation.HWND) void {
    const DWMWA_USE_IMMERSIVE_DARK_MODE: graphics_dwm.DWMWINDOWATTRIBUTE = @enumFromInt(20);
    const TRUE = 1;

    _ = graphics_dwm.DwmSetWindowAttribute(
        hwnd,
        DWMWA_USE_IMMERSIVE_DARK_MODE,
        &TRUE,
        @sizeOf(@TypeOf(TRUE)),
    );
}

// fn setBorderColor(hwnd: foundation.HWND, color: u32) void {
//     const DWMWA_BORDER_COLOR: graphics_dwm.DWMWINDOWATTRIBUTE = @enumFromInt(34);
//     _ = graphics_dwm.DwmSetWindowAttribute(
//         hwnd,
//         DWMWA_BORDER_COLOR,
//         &color,
//         @sizeOf(@TypeOf(color)),
//     );
// }

fn setBorderColor(hwnd: foundation.HWND, color: u32) void {
    const DWMWA_BORDER_COLOR: graphics_dwm.DWMWINDOWATTRIBUTE = @enumFromInt(34);
    _ = graphics_dwm.DwmSetWindowAttribute(
        hwnd,
        DWMWA_BORDER_COLOR,
        &color,
        @sizeOf(@TypeOf(color)),
    );
}

fn applyDarkTheme() void {
    // Set background color of the RichEdit control
    _ = windows_and_messaging.SendMessageA(edit_handle, edit.EM_SETBKGNDCOLOR, 0, @as(u32, 0x1E1E1E)); // Dark background

    // Set text color using EM_SETCHARFORMAT
    var cf: CHARFORMAT2A = undefined;
    cf.cbSize = @sizeOf(CHARFORMAT2A);
    cf.dwMask = @as(u32, @bitCast(edit.CFM_COLOR));
    cf.crTextColor = 0xD4D4D4; // Light gray text color
    _ = windows_and_messaging.SendMessageA(edit_handle, edit.EM_SETCHARFORMAT, edit.SCF_ALL, @as(isize, @intCast(@intFromPtr(&cf))));
}

fn applySyntaxHighlighting() void {
    // Example: Highlight the word "fn" in blue
    const keyword = "fn";
    const keywordColor = 0x569CD6; // Blue color

    var cf: CHARFORMAT2A = undefined;
    cf.cbSize = @sizeOf(CHARFORMAT2A);
    cf.dwMask = @as(u32, @bitCast(edit.CFM_COLOR));
    cf.crTextColor = keywordColor;

    // Find and highlight the keyword
    const textLength = windows_and_messaging.SendMessageA(edit_handle, edit.EM_GETTEXTLENGTH, 0, 0);
    var text = try allocator.alloc(u8, textLength + 1);
    defer allocator.free(text);
    _ = windows_and_messaging.SendMessageA(edit_handle, edit.EM_GETTEXT, textLength + 1, @as(isize, @intCast(@intFromPtr(text.ptr))));

    var pos = std.mem.indexOf(u8, text, keyword);
    while (pos) |p| {
        _ = windows_and_messaging.SendMessageA(edit_handle, edit.EM_SETSEL, p, p + keyword.len);
        _ = windows_and_messaging.SendMessageA(edit_handle, edit.EM_SETCHARFORMAT, edit.SCF_SELECTION, @as(isize, @intCast(@intFromPtr(&cf))));
        pos = std.mem.indexOf(u8, text[p + keyword.len ..], keyword);
    }
}

fn messageLoop(hwnd: foundation.HWND) void {
    _ = hwnd;
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
            const width = @as(u16, @truncate(@as(usize, @bitCast(lParam))));
            const height = @as(u16, @truncate(@as(usize, @bitCast(lParam)) >> 16));
            _ = windows_and_messaging.MoveWindow(edit_handle, 0, 0, width, height, 1);
            return 0;
        },
        windows_and_messaging.WM_DROPFILES => {
            const hDrop: ?shell.HDROP = @ptrFromInt(@as(usize, wParam));
            var buff: [1024:0]u8 = undefined;
            _ = shell.DragQueryFileA(hDrop, 0, @as([*:0]u8, @ptrCast(&buff)), buff.len);
            openFile(@as([*:0]const u8, @ptrCast(&buff))) catch |err| {
                std.debug.print("Failed to open file: {}\n", .{err});
            };
            shell.DragFinish(hDrop);
        },
        windows_and_messaging.WM_GETDLGCODE => {
            return windows_and_messaging.DLGC_WANTALLKEYS | windows_and_messaging.DLGC_WANTARROWS | windows_and_messaging.DLGC_WANTCHARS;
        },
        windows_and_messaging.WM_KEYDOWN => {
            if (wParam == @intFromEnum(interactivity.VK_RETURN)) { // Check for Enter key
                return windows_and_messaging.DefWindowProcA(hwnd, msg, wParam, lParam); // Allow default processing
            }
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
