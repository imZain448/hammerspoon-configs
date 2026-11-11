# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this is

A personal Hammerspoon config (`~/.hammerspoon`) implementing "Harpoon for macOS": a Neovim-Harpoon-style system for pinning up to 5 windows to numbered slots and jumping between them with hotkeys. The header comment of `init.lua` lists all keybindings (Hyper = cmd+alt+ctrl+shift).

There is no build, lint, or test setup. Changes take effect on config reload:

```sh
hs -c "hs.reload()"     # reload config via the hs CLI (installed at /opt/homebrew/bin/hs)
hs -c "<lua expr>"      # evaluate Lua in the running Hammerspoon instance for quick checks
```

Errors from a bad reload appear in the Hammerspoon Console, not in the terminal. `hs -c` requires `require("hs.ipc")` to be loaded in the running config; `init.lua` does not currently load it, so if `hs -c` fails, ask the user to reload from the Hammerspoon menu bar instead.

## Architecture

- `init.lua` — the keymap only: requires the modules and binds every hotkey, including the slot-number leader modes. Nothing else should bind hotkeys.
- `harpoon/core.lua` — returns a module table holding `slots`, `maxSlots`, `hyper`, the toast HUD (`showToast`), window resolution and all slot operations. Has no dependency on the picker.
- `harpoon/picker.lua` — requires `harpoon.core`; owns the `hs.webview` and the JS message handler. Exposes `toggle` and `close`.
- `harpoon/picker.html` — the picker UI.

Modules are loaded with `require("harpoon.core")`, which works because Hammerspoon puts `~/.hammerspoon/?.lua` on `package.path`. Key cross-cutting points:

- **State is in-memory only.** `core.slots` is a table keyed by string slot numbers (`"1"`–`"5"`, not integers); each entry stores `name`, `title`, `bundle`, `windowId`. Slots are lost on reload. When adding a slot and all are full, slot `"1"` is overwritten.
- **Window resolution** (`resolveWindow`) tries `hs.window.get(windowId)` first, then falls back to `hs.application.get(bundle):findWindow(title)` and updates the stored `windowId` on success. All jump paths go through `core.focusSlot`.
- **Toasts** (`showToast`) are a single reusable `hs.canvas`; a new toast always replaces the previous one. Line count drives height, so multi-line messages use `\n`.
- **Leader modes** (Hyper+A jump, Hyper+D delete) are built by `slotLeader(onSlot, timeout)` in `init.lua`: an `hs.hotkey.modal` with an auto-exit timer started in `modal:entered()`; escape/space also exit.
- **WebView picker** (Hyper+[) bridges Lua ↔ JS:
  - Lua reads `harpoon/picker.html` from disk on every open and recreates the `hs.webview`, so HTML/CSS edits apply without reload.
  - Lua → JS: after `didFinishNavigation`, calls the global `setWindows([{slot, name, title}, ...])`.
  - JS → Lua: `window.webkit.messageHandlers.harpoon.postMessage({action, slot})` with `action` of `"select"` or `"close"`. The handler name `"harpoon"` must match `hs.webview.usercontent.new("harpoon")`. Lua validates `slot` is an integer in `1..maxSlots`.
  - Picker height is computed in Lua from `pickerConfig` (`baseHeight + n * rowHeight`, capped at `maxHeight`); if you change row/padding sizes in the CSS, update `pickerConfig` to match.
  - The picker hides itself on focus loss via `windowCallback`.

## Conventions

- Lua uses tabs for indentation; HTML/JS uses 2 spaces.
- Toast messages use emoji / Nerd Font glyph prefixes (e.g. `󰛢`, `⚠️`, `🗑️`) — keep that style for new messages.
