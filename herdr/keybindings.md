# Herdr Configuration

Herdr is an **agent-aware terminal workspace manager** (a multiplexer like
tmux): a background server owns real terminal processes, clients attach to
render them, and panes survive detach / closing the terminal. Herdr **detects
coding agents** (claude, opencode, pi, …) inside panes and shows each one's
state (`working`, `blocked`, `done`, `idle`) in a per-workspace sidebar.

The configuration here follows the conventions used across these dotfiles:
gruvbox theme and Vim-style `h/j/k/l` pane movement, plus detach/reattach
persistence. Herdr is **prefix-first** (a tmux-style `ctrl+b` prefix), so rather
than remapping keys, this config keeps Herdr's vetted defaults and documents
them.

> Herdr is **mouse-first**: panes, tabs, workspaces, split borders and
> right-click menus are all clickable. None of the keybindings below are
> required — they are the keyboard layer on top.

## The prefix: `ctrl+b`

A multiplexer sits between your terminal and the programs inside it, which
already claim most key chords. The **prefix** solves the conflict: press
`ctrl+b`, release, then press one action key. `prefix+c` means `ctrl+b` then
`c`. One reserved chord instead of dozens.

Press **`prefix+?`** at any time to see every active binding live.

## Why `Ctrl+B` is safe

No other layer in this setup claims `Ctrl+B`, so the prefix always reaches Herdr:

| Layer | `Ctrl+B`? |
|-------|-----------|
| macOS (Tahoe) | free — Cmd family owns global shortcuts, not Ctrl |
| Amethyst | free — uses `Opt+Cmd`; `b` is only `Opt+Cmd+B` (bsp layout) |
| Ghostty | free — passes `Ctrl`-letter chords through to the pane |

Inside a pane, Herdr does shadow a few low-value defaults, each easily replaced:

- **zsh** — `backward-char` (cursor left) → use Left Arrow or `Esc h`
- **Neovim** — page-up (unused; this config scrolls with `<C-d>`/`<C-u>`) and
  blink.cmp doc-scroll-up (minor; docs `auto_show = false`)
- **lazygit** — nothing (binds no `<c-b>`)

## Learn these five first

| Action | Key |
|--------|-----|
| New tab | `prefix+c` |
| Split right / down | `prefix+v` / `prefix+minus` |
| Move between panes | `prefix+h/j/k/l` |
| Workspace picker | `prefix+w` |
| Detach, leave everything running | `prefix+q` |

## Full mapping (Vim philosophy)

Every pane action follows the Vim model used across this setup.

| Key | Action | Vim parallel |
|-----|--------|--------------|
| `prefix+minus` | Split down | `:split` |
| `prefix+v` | Split right | `:vsplit` |
| `prefix+h` / `j` / `k` / `l` | Focus pane left / down / up / right | `Ctrl+w h/j/k/l` |
| `prefix+H` / `J` / `K` / `L` | Swap pane left / down / up / right | `Ctrl+w H/J/K/L` |
| `prefix+z` | Zoom (fullscreen) the focused pane | — |
| `prefix+r` | Resize mode | `Ctrl+w` + resize |
| `prefix+x` | Close focused pane | `:close` |
| `prefix+[` | Copy mode (`h/j/k/l`, `v`/space select, `y`/enter copy, `q`/esc leave) | Visual / yank |
| `prefix+c` | New tab | `:tabnew` |
| `prefix+n` / `prefix+p` | Next / previous tab | `gt` / `gT` |
| `prefix+1..9` | Jump to tab 1–9 | `{n}gt` |
| `prefix+shift+t` | Rename tab | — |
| `prefix+shift+x` | Close tab | `:tabclose` |
| `prefix+w` | Workspace picker | — |
| `prefix+shift+n` | New workspace | — |
| `prefix+shift+w` | Rename workspace | — |
| `prefix+shift+d` | Close workspace | — |
| `prefix+g` | Goto picker | — |
| `prefix+b` | Toggle sidebar | — |
| `prefix+q` | Detach (everything keeps running) | — |
| `prefix+alt+g` | Open **lazygit** in a temporary pane | (matches `lg` alias) |

When the **navigate surface** is open, bare `h/j/k/l` move between panes
directly (no prefix), keeping the Vim feel for quick hops.

## Theme / visual indicators

- **Theme:** `gruvbox`, matching Alacritty and Lazygit across these dotfiles.
  `auto_switch` follows the host terminal's light/dark appearance and swaps
  between the gruvbox dark/light siblings.
- **Accent:** gruvbox green `#98971a` (`[theme.custom] accent`) — the same color
  Lazygit uses as its accent — for highlights, borders and navigation UI.
- **Sidebar:** agent state (`working` / `blocked` / `done` / `idle`) is rolled
  up per workspace — the agent-aware feature unique to Herdr here.

## Architecture (who owns what)

| Layer | Owner | Mechanism |
|-------|-------|-----------|
| OS windows / spaces | Amethyst | `Opt+Cmd` / `Opt+Cmd+Shift` |
| Non-persistent terminal splits | Ghostty | `Cmd`-based built-ins (`ghostty/pane_cheatsheet.md`) |
| **Session-persistent, agent-aware panes** | **Herdr** | `ctrl+b` prefix + `herdr` CLI |
| Editor (splits, buffers, files) | Neovim | `<leader>` + `Ctrl` |
| European characters | EurKEY | `Opt+key` |

Reach for **Herdr panes** (`prefix+v`) when you want a split to persist across
detach/reboot or you are running a coding agent worth keeping alive; use quick
**Ghostty splits** (`Cmd+D`) for throwaway side-by-side views.

## Notifications & agents

- **Notifications** (`[ui.toast]`): set to `delivery = "terminal"` so Ghostty
  shows a native desktop notification when a background agent finishes or needs
  input (active-tab agents are not announced). Sound is **off** (`[ui.sound]`) —
  the sidebar plus terminal notifications are enough.
- **Agent integrations**: install once per agent for authoritative
  `working` / `blocked` / `done` state instead of screen detection:

  ```sh
  herdr integration install pi        # Pi Coding Agent
  herdr integration install claude    # Claude Code
  herdr integration install opencode  # OpenCode
  herdr integration status            # see what's installed
  ```

  `claude` and `opencode` are already installed; `pi` is added here.
- **Session restore** (`[session] resume_agents_on_restore = true`): after a
  server restart, Pi / OpenCode / Claude Code panes resume their native
  conversation sessions.

## Session control (CLI)

Shell aliases defined in `zsh/zsh_aliases` (all guarded by `herdr` being
installed):

| Alias | Command | What it does |
|-------|---------|--------------|
| `hh` | `herdr` | Launch or attach to the default persistent session |
| `ha <name>` | `herdr session attach <name>` | Attach to (or create) a named session |
| `hl` | `herdr session list` | List named sessions |
| `hs` | `herdr status` | Show client + server status |
| `hk` | `herdr server stop` | Stop the running server (kills all panes) |
| `hu` | `herdr update` | Update Herdr to the latest version |
| `hrc` | `herdr server reload-config` | Reload `config.toml` in the running server |

Detaching is done from **inside** Herdr with `prefix+q` (or by closing the
terminal); there is no detach subcommand — everything keeps running in the
background until `hk` (`herdr server stop`).

### Typical workflow

```sh
cd some/project
hh                   # launch / attach the default session; a workspace is created
claude               # start a coding agent in the pane; Herdr detects its state
prefix+v             # split right -> a second pane
prefix+h / prefix+l  # focus between panes
prefix+q             # detach — all panes (and agents) keep running
# close the Ghostty window, reboot the GUI, etc.
hh                   # reattach later; every pane is as you left it
hk                   # when you actually want to stop everything
```

(For agent-state detection integrations, see **Notifications & agents** above.)

## Configuration files

- `herdr/config.toml` → `~/.config/herdr/config.toml` (symlinked by
  `herdr/setup.sh`). Holds `onboarding = false`, the `gruvbox` theme with
  `auto_switch` and the green accent, the documented prefix-first `[keys]` map,
  and the lazygit custom command.
- Print the full upstream default with `herdr --default-config`; apply edits to
  a running server with `herdr server reload-config` (alias `hrc`).
