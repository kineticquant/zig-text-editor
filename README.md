# zig-text-editor

![In Development](https://img.shields.io/badge/status-In%20Development-yellow)

Zig 	[![Zig](https://img.shields.io/badge/Zig-F7A41D?logo=zig&logoColor=fff)](#)

### Overview
This application is a simple Zig-based notepad. 

### Use Case
Through monitoring my own network traffic, I've found the default notepad in Windows 11 is calling numerous Microsoft endpoints when launching and saving. This felt wrong to me, thus I wanted to use an alternative product for simple, quick notes. I didn't want to utilize something heavier like Notepad++, Sublime, or a true IDE, thus I decided to start making my own while also trying to learn zig.

This application is being enhanced as I get time and is not a complete product. Right now it simply launches a dark-mode notepad that allows text entry with very basic syntax highlighting. It was created to assist in my learning zig, so I will add to it as I learn more.

### Dependencies
- Built upon zig 0.12.0 (latest stable version with zigwyn32)
- Uses zigwyn32 to interact with Windows OS
 
### To Do
- Apply copy, paste, and cut logic with key bindings using zigwyn32.
- Create open file dialogue logic.
- Create save file dialogue, autosave, and CTRL+S save logic.
- Fix VK RETURN logic which only sometimes forces the Enter key to move to a new line.
- Create theme designs.
- Enhance syntax highlighting for various programmatic file types. This must be done manually and by language to retain speed in the application. Using an external library will add bloat and lead to subpar performance. 
