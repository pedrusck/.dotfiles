# Migration Guide: Zellij as a Session Layer with a Vim Pane Mode

This configuration uses Zellij as a **session-persistence layer** with a single,
conflict-free **modal gateway** (`Ctrl+g`) for managing co-persisting panes the
Vim way. It previously shipped a full Vim-style modal keymap (many `Ctrl` mode
switches); that was removed in favor of a minimal, single-gateway design.

## What changed

| Category | Old full keymap | Now |
|----------|-----------------|-----|
| Mode switches | `Ctrl+g/p/t/r/s/w/o/q` | **only `Ctrl+g`** (enters "Zellij mode") |
| Pane ops | spread across Pane/Resize/Move modes | one-shot keys inside Zellij mode |
| Tabs | full Tab mode | create/close/next/prev inside Zellij mode (no rename/move) |
| Scroll / search modes | bound | **removed** (not used here) |
| Session control | `Ctrl+g` → `Ctrl+o` → `d` | `Ctrl+g w` (manager) + CLI aliases |
| `stty -ixon` | required | not needed (no `Ctrl+s` binding) |
| Non-persistent splits | Zellij | Ghostty built-ins (`ghostty/pane_cheatsheet.md`) |
| Frame | n/a | rounded, green/gray/orange (focus + mode indicator) |
| Session name | status-bar | slim 1-row compact-bar (only remaining chrome) |

## Why this design

The terminal only receives `Ctrl+key` chords — the same layer Neovim and the shell
need. Binding only `Ctrl+g` (which nothing else uses) means every other keystroke
reaches your application untouched, while a single gateway still gives you full,
Vim-flavored pane management. See `keybindings.md` for the complete reference.

## Zellij mode (`Ctrl+g`)

All actions are **one-shot** (perform, then return to Locked):

```
s split-down   v split-right   n new-pane
h/j/k/l focus  H/J/K/L move    + grow   - shrink
x close-pane   t new-tab   X close-tab   [ prev-tab   ] next-tab
w session-manager           Esc / Ctrl+g  exit
```

Panes created with `s` / `v` / `n` are real Zellij panes and **co-persist** in the
session (they survive detach/reattach). Ghostty splits, by contrast, are
independent shells that do not co-persist.

## How to use it

1. **Apply the config** — `zellij/setup.sh` symlinks `config.kdl` and
   `layouts/default.kdl`; restart any running session to pick up changes.
2. **Start / resume**: `za main`
3. **Split / navigate**: `Ctrl+g v`, `Ctrl+g s`, `Ctrl+g h/j/k/l`
4. **Detach** (keep everything running): `zd`
5. **Reattach**: `za main`
6. **Switch sessions**: `Ctrl+g w` (or `za` / `zl` from the shell)

## Visual indicators

- **Session name**: shown in a slim one-row `compact-bar` at the bottom (in
  Zellij the session name is rendered by a bar plugin, not the pane frame).
- **Pane frame color**:
  - **green** border = focused pane
  - **gray** border = other panes
  - **orange** border = you are currently in Zellij mode (after `Ctrl+g`)

## Restoring the old full keymap

If you ever want the old multi-mode keymap back, restore a previous `config.kdl`
from version control — but note that any `Ctrl+key` bound in a non-locked mode will
shadow the corresponding Neovim/shell binding while that mode is active.
