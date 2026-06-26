# Migration Guide: Amethyst xmonad-style Keybindings

## What Changed

**Modifiers**

| | Old | New |
|---|---|---|
| mod1 | `Option + Control` | `Opt + Cmd` |
| mod2 | `Option + Control + Command` | `Opt + Cmd + Shift` |

The keys you press alongside the modifier are mostly the same -- your muscle memory for `h/j/k/l`, `Enter`, `Space`, `,`, `.` all carries over. The main shift is moving from the Control key (far-left corner, hard to reach) to a thumb roll across the adjacent Option and Command keys.

## Step-by-Step Migration

### 1. Apply macOS settings BEFORE switching the config

Do these first so the new keybindings work immediately once Amethyst picks up the config:

**Override 3 application-level shortcuts** (System Settings > Keyboard > Keyboard Shortcuts > App Shortcuts > All Applications):

1. **"Hide Others"** -- remap to a dummy shortcut (e.g. `Ctrl+Opt+Cmd+Shift+H`) to free `Opt+Cmd+H` for shrink-main
2. **"Minimize All"** -- remap to a dummy shortcut (e.g. `Ctrl+Opt+Cmd+Shift+M`) to free `Opt+Cmd+M` for focus-main
3. **"Close All"** -- remap to a dummy shortcut (e.g. `Ctrl+Opt+Cmd+Shift+W`) to free `Opt+Cmd+W` for focus-screen-1

**Disable 2 system shortcuts**:

4. **Dock toggle** -- System Settings > Keyboard > Keyboard Shortcuts > Launchpad & Dock > uncheck "Turn Dock Hiding On/Off" (frees `Opt+Cmd+D`)
5. **Spotlight** -- System Settings > Keyboard > Keyboard Shortcuts > Spotlight > uncheck "Show Finder search window" (frees `Opt+Cmd+Space`)

**Enable workspace switching**:

6. **Desktop switching** -- System Settings > Keyboard > Keyboard Shortcuts > Mission Control > enable "Switch to Desktop 1" through "Switch to Desktop 9" (`Ctrl+1..9`)
7. **Create desktops** -- open Mission Control (`Ctrl+Up`), click "+" in the top-right to create desktops 1 through however many you need
8. **Disable auto-rearrange** -- System Settings > Desktop & Dock > Mission Control > "Automatically rearrange Spaces based on most recent use" must be disabled

### 2. Restart Amethyst

After the config symlink is in place (`~/.config/amethyst/amethyst.yml`), restart Amethyst. If keybindings don't take effect:

```sh
defaults delete com.amethyst.Amethyst.plist
```

Then relaunch Amethyst.

### 3. Learn in layers

Don't try to learn everything at once. Focus on these groups in order:

**Day 1 -- Core navigation (you already know these keys)**

| Action | Old | New | Same key? |
|--------|-----|-----|-----------|
| Focus next window | `Opt+Ctrl + J` | `Opt+Cmd + J` | Yes |
| Focus previous window | `Opt+Ctrl + K` | `Opt+Cmd + K` | Yes |
| Swap with main | `Opt+Ctrl + Enter` | `Opt+Cmd + Enter` | Yes |
| Shrink/expand main | `Opt+Ctrl + H/L` | `Opt+Cmd + H/L` | Yes |
| Cycle layout | `Opt+Ctrl + Space` | `Opt+Cmd + Space` | Yes |

The only change is the modifier. Practice by doing your normal workflow -- focus, swap, resize -- just with `Opt+Cmd` instead of `Opt+Ctrl`.

**Day 2 -- Window swapping and floating**

| Action | Old | New |
|--------|-----|-----|
| Swap next | `Opt+Ctrl+Cmd + J` | `Opt+Cmd+Shift + J` |
| Swap previous | `Opt+Ctrl+Cmd + K` | `Opt+Cmd+Shift + K` |
| Toggle float | `Opt+Ctrl + T` | `Opt+Cmd + T` |
| Toggle tiling | `Opt+Ctrl + T` (was same!) | `Opt+Cmd+Shift + T` |

Note: `toggle-float` and `toggle-tiling` were previously both bound to `mod1+T` (a bug). They now have separate bindings.

**Day 3 -- Screen focus (new feature)**

| Action | Old | New |
|--------|-----|-----|
| Focus screen 1 | -- (was cycling with N/P) | `Opt+Cmd + W` |
| Focus screen 2 | -- | `Opt+Cmd + E` |
| Focus screen 3 | -- | `Opt+Cmd + R` |
| Throw to screen 1 | -- (was arrows) | `Opt+Cmd+Shift + W` |
| Throw to screen 2 | -- | `Opt+Cmd+Shift + E` |
| Throw to screen 3 | -- | `Opt+Cmd+Shift + R` |

This replaces the old `mod1+N/P` cycling and `mod2+Left/Right` throwing. Direct access is faster once you know which screen is which.

**Day 4 -- Workspace management (new feature)**

| Action | Shortcut |
|--------|----------|
| Switch to desktop N | `Ctrl + N` (macOS native) |
| Throw window to space N | `Opt+Cmd+Shift + N` (1-9, 0 for space 10) |
| Throw window to space left/right | `Opt+Cmd+Shift + H/L` |

Typical workflow: `Opt+Cmd+Shift + 3` throws the focused window to space 3, then `Ctrl + 3` follows it there.

## Removed Bindings

| Old Binding | Old Action | Replacement |
|-------------|------------|-------------|
| `mod1 + N` | Focus screen clockwise | `mod1 + W/E/R` (direct) |
| `mod1 + P` | Focus screen counter-clockwise | `mod1 + W/E/R` (direct) |
| `mod2 + Left` | Swap screen counter-clockwise | `mod2 + W/E/R` (direct) |
| `mod2 + Right` | Swap screen clockwise | `mod2 + W/E/R` (direct) |

## Cheat Sheet

Print or keep this nearby for the first week:

```
Opt+Cmd + ...                     Opt+Cmd+Shift + ...
  J/K     focus next/prev           J/K     swap next/prev
  H/L     shrink/expand main        H/L     throw space left/right
  M       focus main                W/E/R   throw to screen 1/2/3
  Enter   swap with main            1..9,0  throw to space N
  Space   cycle layout              Space   cycle layout backward
  W/E/R   focus screen 1/2/3        T       toggle tiling
  ,/.     inc/dec main count        X       toggle focus-follows-mouse
  T       toggle float              Z       relaunch Amethyst
  A/S/D/C/B select layout
  I       show layout HUD
  N       re-evaluate windows

macOS native:
  Ctrl + 1..9   switch to desktop N
```
