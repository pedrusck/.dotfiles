# Zellij Configuration

Zellij is a **session-persistence layer** (detach / reattach so your processes
survive closing the Ghostty window) with a single, conflict-free **modal gateway**
for managing co-persisting panes the Vim way.

## The one gateway: `Ctrl+g`

`Ctrl+g` is the **only** key bound in Locked mode (the always-active base mode).
It is free across macOS, EurKEY, the shell and Neovim, so it is the single
intentionally-consumed key. Every other `Ctrl+key` chord passes straight through
to Neovim / the shell / TUI apps.

Pressing `Ctrl+g` enters **Zellij mode**. Every action there is **one-shot**: it
performs the action and immediately returns to Locked. Panes created this way are
real Zellij panes, so they **co-persist** in the session.

| Key | Action | Vim parallel |
|-----|--------|--------------|
| `s` | Split down | `:split` |
| `v` | Split right | `:vsplit` |
| `n` | New pane (auto direction) | — |
| `h` / `j` / `k` / `l` | Focus pane left / down / up / right | `Ctrl+w h/j/k/l` |
| `H` / `J` / `K` / `L` | Move / swap pane left / down / up / right | `Ctrl+w H/J/K/L` |
| `+` (or `=`) | Increase focused pane size | `Ctrl+w +` |
| `-` | Decrease focused pane size | `Ctrl+w -` |
| `x` | Close focused pane | `:close` |
| `t` | New tab | `:tabnew` |
| `X` (Shift+x) | Close current tab | `:tabclose` |
| `]` | Next tab | `gt` |
| `[` | Previous tab | `gT` |
| `w` | Session-manager (switch / create / kill) | — |
| `Esc` / `Ctrl+g` | Exit back to Locked | — |

Tabs are shown in the slim compact-bar at the bottom, so you can see which tab is
active. Tab actions are one-shot too: repeat the gateway to switch several tabs,
e.g. `Ctrl+g ]`, `Ctrl+g ]`.

Because every key is one-shot, to make several focus hops or resize steps you
repeat the gateway, e.g. `Ctrl+g l`, `Ctrl+g l`, or `Ctrl+g +`, `Ctrl+g +`.

## Visual indicators

There are two cues:

1. **Session name** — shown in a **slim one-row `compact-bar`** at the bottom. In
   Zellij the session name is rendered by a bar plugin, not by the pane frame, so
   this single row is the minimal chrome needed to keep the session name visible.
2. **Pane frame color** — a **rounded frame** whose color marks focus and mode:

| Color | Meaning |
|-------|---------|
| **green** `#98971a` (gruvbox green, as in Lazygit) | the focused pane |
| **gray** `#928374` (gruvbox light gray) | other (unfocused) panes |
| **orange** `#d65d0e` (gruvbox orange) | shown while **Zellij mode is active** |

So when you press `Ctrl+g` the border turns orange (you're in the mode); after a
one-shot action it returns to green. With multiple panes, the green border marks
which pane has focus.

This is configured in `config.kdl` (the `ui` block, the `themes` override setting
the three `frame_*` components) and `layouts/default.kdl` (one pane plus the
compact-bar).

## Architecture (who owns what)

| Layer | Owner | Mechanism |
|-------|-------|-----------|
| OS windows / spaces | Amethyst | `Opt+Cmd` / `Opt+Cmd+Shift` |
| Non-persistent terminal splits | Ghostty | `Cmd`-based built-ins (see `ghostty/pane_cheatsheet.md`) |
| **Co-persisting panes + session persistence** | **Zellij** | `Ctrl+g` mode + CLI aliases |
| Editor (splits, buffers, files) | Neovim | `<leader>` + `Ctrl` |
| European characters | EurKEY | `Opt+key` |

Note there are two ways to split: **Ghostty splits** are independent shells that
do *not* co-persist; **Zellij panes** (`Ctrl+g s` / `v` / `n`) co-persist in the
session. Use Zellij panes when you want them to survive detach/reattach.

## Session control (CLI)

Shell aliases defined in `zsh/zsh_aliases`:

| Alias | Command | What it does |
|-------|---------|--------------|
| `za <name>` | `zellij attach -c <name>` | Attach to a session, creating it if missing |
| `zai` | `zellij_attach_interactive` | Interactively pick an existing session to attach to |
| `zl` | `zellij list-sessions` | List active sessions |
| `zd` | `zellij action detach` | Detach from the current session |
| `zk <name>` | `zellij kill-session <name>` | Kill a named session |
| `zka` | `zellij kill-all-sessions` | Kill every session |

### Typical workflow

```sh
za main              # start (or resume) the "main" session
Ctrl+g v             # split right -> a second co-persisting pane
Ctrl+g l / Ctrl+g h  # focus between panes
zd                   # detach — all panes keep running in the background
# close the Ghostty window, reboot the GUI, etc.
za main              # reattach later; every pane is exactly as you left it
Ctrl+g w             # any time: fuzzy switch / create / kill sessions
```

Sessions are started explicitly with `za` (no auto-attach on shell start).

`zai` is the out-of-session counterpart to the in-session `Ctrl+g w` gateway: run
it from a plain shell to fuzzy-pick (skim, falling back to a builtin `select`
menu) one of the existing sessions and attach. It only *selects* — create
sessions with `za <name>`. It refuses to run inside a session (detach with `zd`
first) and prints a hint when no sessions exist yet.

## Configuration files

- `zellij/config.kdl` → `~/.config/zellij/config.kdl`. Holds the `Ctrl+g` gateway
  and one-shot `pane` mode, the `ui` frame settings, `default_layout "default"`,
  and the `gruvbox-dark` theme override with the three frame colors. `default_mode`
  is `locked`.
- `zellij/layouts/default.kdl` → `~/.config/zellij/layouts/default.kdl` (symlinked
  by the setup script). One pane plus a slim 1-row compact-bar (session name).
