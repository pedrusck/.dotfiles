# Amethyst Keybindings

xmonad-style keybindings for [Amethyst](https://github.com/ianyh/Amethyst) on macOS.

## Modifier Keys

| Modifier | Keys                | xmonad Equivalent |
|----------|---------------------|-------------------|
| **mod1** | `Opt + Cmd`         | mod (Super)       |
| **mod2** | `Opt + Cmd + Shift` | mod + Shift       |

### Why Opt+Cmd?

- **Ergonomic on MacBook**: Opt and Cmd are adjacent keys under the thumb. You can press both with a thumb roll, leaving all fingers free for any key. By contrast, Ctrl is in the far-left corner of the MacBook keyboard and makes left-side keys (1-5, W, E, R, S) painful to reach simultaneously.
- **EurKEY compatible**: when Cmd is held, macOS processes the keypress as a hotkey chord _before_ the keyboard layout's Option layer activates. `Opt+Cmd+key` never produces European characters -- only `Opt+key` (without Cmd) does. This was confirmed by testing and by inspecting the EurKEY `.keylayout` modifier map.
- **Matches xmonad's two-modifier pattern**: mod1 for actions, mod2 (mod1 + Shift) for the "move/shift" variant of those actions.

### Alternatives considered

| Combination   | Why rejected                                                                                                            |
|---------------|----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| `Ctrl + Cmd`  | Ctrl is in the MacBook's far-left corner -- pressing Ctrl+Cmd+{1..5,W,E,R,S} is ergonomically difficult with one hand |
| `Ctrl + Opt`  | Conflicts with the EurKEY Option layer on every key                                                                     |
| `Opt + Shift` | Conflicts with the EurKEY Option+Shift layer (uppercase European characters)                                       |
| `Cmd + Shift` | Heavily used by macOS (screenshots Cmd+Shift+3/4/5, redo Cmd+Shift+Z, etc.)                                          |

## Keybinding Reference

### Layout

| Shortcut       | Action                     | xmonad          |
|----------------|----------------------------|-----------------|
| `mod1 + Space` | Cycle to next layout       | mod-space       |
| `mod2 + Space` | Cycle to previous layout   | mod-shift-space |
| `mod1 + A`     | Select tall layout         | --              |
| `mod1 + S`     | Select wide layout         | --              |
| `mod1 + D`     | Select fullscreen layout   | --              |
| `mod1 + C`     | Select column layout       | --              |
| `mod1 + B`     | Select BSP layout          | --              |

### Window Focus

| Shortcut   | Action                                    | xmonad |
|------------|-------------------------------------------|--------|
| `mod1 + J` | Focus next window (clockwise)             | mod-j  |
| `mod1 + K` | Focus previous window (counter-clockwise) | mod-k  |
| `mod1 + M` | Focus main window                         | mod-m  |

### Window Swap

| Shortcut       | Action                            | xmonad      |
|----------------|-----------------------------------|-------------|
| `mod1 + Enter` | Swap focused window with main     | mod-return  |
| `mod2 + J`     | Swap focused with next window     | mod-shift-j |
| `mod2 + K`     | Swap focused with previous window | mod-shift-k |

### Main Pane

| Shortcut   | Action                        | xmonad     |
|------------|-------------------------------|------------|
| `mod1 + H` | Shrink main pane              | mod-h      |
| `mod1 + L` | Expand main pane              | mod-l      |
| `mod1 + ,` | Increase windows in main pane | mod-comma  |
| `mod1 + .` | Decrease windows in main pane | mod-period |

### Screen Focus (Multi-Monitor)

| Shortcut   | Action         | xmonad |
|------------|----------------|--------|
| `mod1 + W` | Focus screen 1 | mod-w  |
| `mod1 + E` | Focus screen 2 | mod-e  |
| `mod1 + R` | Focus screen 3 | mod-r  |

### Throw Window to Screen

| Shortcut   | Action                  | xmonad      |
|------------|-------------------------|-------------|
| `mod2 + W` | Move window to screen 1 | mod-shift-w |
| `mod2 + E` | Move window to screen 2 | mod-shift-e |
| `mod2 + R` | Move window to screen 3 | mod-shift-r |

### Throw Window to Space

| Shortcut      | Action                            | xmonad           |
|---------------|-----------------------------------|------------------|
| `mod2 + H`    | Move window to space on the left  | --               |
| `mod2 + L`    | Move window to space on the right | --               |
| `mod2 + 1..9` | Move window to space N            | mod-shift-[1..9] |
| `mod2 + 0`    | Move window to space 10           | --               |

### Floating and Tiling

| Shortcut   | Action                          | xmonad |
|------------|---------------------------------|--------|
| `mod1 + T` | Toggle float for focused window | mod-t  |
| `mod2 + T` | Toggle tiling on/off entirely   | --     |

### System

| Shortcut   | Action                               | xmonad           |
|------------|--------------------------------------|------------------|
| `mod1 + N` | Re-evaluate windows (refresh layout) | mod-n            |
| `mod2 + X` | Toggle focus-follows-mouse           | --               |
| `mod2 + Z` | Relaunch Amethyst                    | mod-q (remapped) |

## Space Switching (macOS Native)

Amethyst cannot switch between spaces -- it can only throw windows to them. Space switching is handled natively by macOS:

| Shortcut            | Action                   |
|---------------------|--------------------------|
| `Ctrl + 1..9`       | Switch to Desktop N      |
| `Ctrl + Left/Right` | Switch to adjacent space |

This pairs naturally with the Amethyst throw commands: `mod2 + 3` throws a window to space 3, then `Ctrl + 3` follows it there.

## Enabled Layouts

The following layouts are enabled (cycled through with `mod1 + Space`):

1. **widescreen-tall** -- tall layout optimized for widescreen monitors
2. **fullscreen** -- single window fills the screen
3. **two-pane** -- two equal panes side by side
4. **wide** -- main pane on top, others on bottom
5. **3column-left** -- three columns, main on the left
6. **3column-middle** -- three columns, main in the center
7. **column** -- all windows in equal columns
8. **bsp** -- binary space partitioning (recursive splitting, like i3/bspwm)

## Required macOS Settings

These settings must be changed in macOS for all keybindings to work correctly. See `macOS_configuration_steps.md` for bilingual (English/German) navigation paths.

### 1. Disable "Hide Others" shortcut (Opt+Cmd+H) -- required

macOS binds `Opt+Cmd+H` to "Hide Other Applications", which conflicts with `shrink-main`. Override it by creating an App Shortcut for "All Applications" that remaps "Hide Others" to an unused key combination:

> System Settings > Keyboard > Keyboard Shortcuts > App Shortcuts > All Applications > add "Hide Others" with a dummy shortcut (e.g. `Ctrl+Opt+Cmd+Shift+H`)

### 2. Disable "Minimize All" shortcut (Opt+Cmd+M) -- required

macOS binds `Opt+Cmd+M` to "Minimize All Windows", which conflicts with `focus-main`. Override the same way:

> System Settings > Keyboard > Keyboard Shortcuts > App Shortcuts > All Applications > add "Minimize All" with a dummy shortcut (e.g. `Ctrl+Opt+Cmd+Shift+M`)

### 3. Disable "Close All Windows" shortcut (Opt+Cmd+W) -- required

macOS binds `Opt+Cmd+W` to "Close All Windows", which conflicts with `focus-screen-1`. This is especially critical because the macOS shortcut is destructive. Override the same way:

> System Settings > Keyboard > Keyboard Shortcuts > App Shortcuts > All Applications > add "Close All" with a dummy shortcut (e.g. `Ctrl+Opt+Cmd+Shift+W`)

### 4. Disable Dock auto-show shortcut (Opt+Cmd+D) -- required

macOS binds `Opt+Cmd+D` to toggle Dock visibility, which conflicts with `select-fullscreen-layout`. Disable it in:

> System Settings > Keyboard > Keyboard Shortcuts > Launchpad & Dock > uncheck "Turn Dock Hiding On/Off"

### 5. Disable Spotlight shortcut (Opt+Cmd+Space) -- required

macOS may bind `Opt+Cmd+Space` to "Show Finder search window", which conflicts with `cycle-layout`. Disable it in:

> System Settings > Keyboard > Keyboard Shortcuts > Spotlight > uncheck "Show Finder search window"

### 6. Enable "Switch to Desktop N" shortcuts (required)

Enable `Ctrl+1` through `Ctrl+9` for xmonad-style workspace switching:

> System Settings > Keyboard > Keyboard Shortcuts > Mission Control > enable "Switch to Desktop 1" through "Switch to Desktop 9"

The desktops must exist first -- create them in Mission Control (`Ctrl+Up`, then click "+" in the top-right corner).

### 7. Disable automatic space rearrangement (required)

Without this, macOS reorders spaces by recent use, making numbered shortcuts unpredictable:

> System Settings > Desktop & Dock > Mission Control > deactivate "Automatically rearrange Spaces based on most recent use"

## Known macOS Conflicts (Accepted)

The following application-level shortcuts share a modifier+key combination with Amethyst bindings. Amethyst intercepts them globally before the app can act on them, so they are effectively overridden. These are Finder-only or rarely-used features and the trade-off is acceptable:

| Amethyst Binding                  | Overridden App Shortcut                |
|-----------------------------------|----------------------------------------|
| `mod1 + L` (expand main)          | Finder: Go to Downloads (`Opt+Cmd+L`)  |
| `mod1 + N` (re-evaluate windows)  | Finder: New Smart Folder (`Opt+Cmd+N`) |
| `mod1 + S` (select wide layout)   | Finder: Toggle Sidebar (`Opt+Cmd+S`)   |
| `mod1 + T` (toggle float)         | Finder: Toggle Toolbar (`Opt+Cmd+T`)   |
| `mod1 + C` (select column layout) | Copy Style (`Opt+Cmd+C`) in some apps  |

## Design Decisions

### Why not mod1+Q for relaunch?

Relaunch is a rare, potentially disruptive action. Placing it on a prominent key (`Q`) risks accidental triggers. It is mapped to `mod2+Z` instead -- a deliberate, hard-to-hit binding that requires Shift.

### Why no mod1+[1..9] for switching spaces?

Amethyst has no "switch to space N" command. macOS handles space switching natively via `Ctrl+[1..9]` (configured in Mission Control keyboard shortcuts). This is actually closer to the xmonad experience, where the window manager and the display server cooperate on workspace management.

### Why are 5 macOS shortcuts overridden?

Every two-key modifier combination on macOS has _some_ system shortcuts. `Opt+Cmd` has fewer conflicts than `Cmd+Shift` (screenshots, redo) and is far more ergonomic than `Ctrl+Cmd` (corner key). The 5 overrides are all either safety improvements (disabling the destructive "Close All Windows") or cosmetic (Dock toggle when Dock is auto-hidden anyway).

## Troubleshooting

- **Keybindings not working after editing config**: restart Amethyst. If that does not help, quit Amethyst and run `defaults delete com.amethyst.Amethyst.plist`, then relaunch.
- **A keybinding triggers a macOS action instead of Amethyst**: check the [Required macOS Settings](#required-macos-settings) section above and verify the conflicting shortcut is disabled.
- **Config values not applying**: due to [Amethyst issue #1419](https://github.com/ianyh/Amethyst/issues/1419), values that match Amethyst's internal defaults may be ignored. Comment out the conflicting entry in `amethyst.yml` to let the default take effect.

## Configuration File

The config file is located at `amethyst/amethyst.yml` in this dotfiles repo and is symlinked to `~/.config/amethyst/amethyst.yml` by the setup script.
