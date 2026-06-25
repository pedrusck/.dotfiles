# Ghostty Panes & Splits — Cheatsheet

A learning reference for managing **splits (panes)**, **tabs**, and **windows** in
Ghostty using its built-in default keybindings. On this machine Ghostty owns all
interactive terminal splitting (Zellij is session-persistence only, Amethyst
handles OS windows).

> `Cmd` = `⌘` (Ghostty calls it `super`). `Opt` = `⌥` (alt). `Ctrl` = `⌃`.

## Splits (panes)

These are the ones to learn first.

| Shortcut | Action |
|----------|--------|
| `Cmd + D` | New split to the **right** |
| `Cmd + Shift + D` | New split **down** |
| `Cmd + [` | Focus **previous** split (order of creation) |
| `Cmd + ]` | Focus **next** split |
| `Cmd + Opt + ←/↓/↑/→` | Focus split by **direction** |
| `Cmd + Ctrl + ←/↓/↑/→` | **Resize** the focused split (10 px steps) |
| `Cmd + Ctrl + =` | **Equalize** all splits in the tab |
| `Cmd + Shift + Enter` | **Zoom** the focused split (toggle full-tab) |
| `Cmd + W` | **Close** the focused split (surface) |

### Suggested first exercise

1. `Cmd + D` — you now have two side-by-side panes.
2. `Cmd + Shift + D` — split the focused one downward (an L-shape).
3. `Cmd + Opt + ←` / `→` / `↑` / `↓` — hop between them by direction.
4. `Cmd + Shift + Enter` — zoom the current pane, then again to un-zoom.
5. `Cmd + Ctrl + →` a few times — widen the pane; `Cmd + Ctrl + =` to reset.
6. `Cmd + W` — close the pane you no longer need.

## Tabs

| Shortcut | Action |
|----------|--------|
| `Cmd + T` | New tab |
| `Cmd + 1`…`Cmd + 8` | Go to tab 1–8 |
| `Cmd + 9` | Go to the **last** tab |
| `Ctrl + Tab` | Next tab |
| `Ctrl + Shift + Tab` | Previous tab |
| `Cmd + Shift + [` | Previous tab |
| `Cmd + Shift + ]` | Next tab |
| `Cmd + Opt + W` | Close the current tab |

## Windows

| Shortcut | Action |
|----------|--------|
| `Cmd + N` | New window |
| `Cmd + Enter` | Toggle fullscreen |
| `Cmd + Ctrl + F` | Toggle fullscreen (alt binding) |
| `Cmd + Shift + W` | Close the window (all tabs/splits in it) |
| `Cmd + Opt + Shift + W` | Close all windows |

## Ghostty splits vs. Zellij panes

There are two ways to split the terminal, and they behave differently:

| | **Ghostty splits** (this doc) | **Zellij panes** (`Ctrl+g` mode) |
|---|---|---|
| Created with | `Cmd+D`, `Cmd+Shift+D`, … | `Ctrl+g s` / `v` / `n` |
| Each pane is | an independent shell | part of the Zellij session |
| Survives detach/reattach? | **No** | **Yes** (co-persists) |
| Best for | quick, throwaway side-by-side views | panes you want to keep across window close / reboot |

Rule of thumb: if you want the split to **persist with the session**, create it
as a Zellij pane (`Ctrl+g v`); otherwise a Ghostty split is fine. See
`zellij/keybindings.md` for the full Zellij pane-mode reference.

## Notes on conflicts / this setup

- **`Cmd + S` is free** — it keeps its native **Save** meaning (the old custom
  split leader was removed).
- **`Cmd + Opt + W`** (close tab) shares a chord with Amethyst's `focus-screen-1`
  (`Opt + Cmd + W`). Amethyst intercepts global hotkeys, so prefer closing tabs
  with `Cmd + W` on a single-tab surface, or via the menu, to avoid surprises.
- **`Cmd + Opt + arrows`** (directional split focus) uses the same modifier family
  as Amethyst (`Opt + Cmd`), but Amethyst binds only letters/space/enter — never
  arrows — so there is no collision.
- Splits live **inside a single Ghostty window**, which Amethyst treats as one
  tiled window. Use Amethyst (`Opt + Cmd + …`) to move/manage the window itself.
- To see every default binding for your installed version:
  `ghostty +list-keybinds --default`

## Reference

- Ghostty keybind docs: https://ghostty.org/docs/config/keybind
- Action reference: https://ghostty.org/docs/config/keybind/reference
